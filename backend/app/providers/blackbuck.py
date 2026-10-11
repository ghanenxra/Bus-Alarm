from datetime import datetime, timezone, timedelta
from typing import Optional
from urllib.parse import parse_qs, urlparse
import httpx
import jwt
from app.core.config import settings
from app.core.logging import logger
from app.providers.base import (
    BaseProvider,
    ProviderBusPosition,
    ProviderError,
    ProviderValidationResult,
    ShareToken,
)


class BlackbuckProvider(BaseProvider):
    """Adapter for Blackbuck GPS tracking links."""

    def __init__(self, http_client: Optional[httpx.AsyncClient] = None):
        self._client = http_client

    def parse_share_url(self, url: str) -> ShareToken:
        """Validate URL structure, host allowlist, and extract share token."""
        if not url or not isinstance(url, str):
            raise ValueError("URL must be a non-empty string")

        parsed = urlparse(url.strip())
        if parsed.scheme.lower() != "https":
            raise ValueError("Tracking link must use secure HTTPS protocol")

        host = parsed.netloc.lower().split(":")[0]
        if host not in settings.ALLOWED_PROVIDER_HOSTS:
            raise ValueError(f"Host '{host}' is not in the allowed provider list: {settings.ALLOWED_PROVIDER_HOSTS}")

        # Extract token from query params or path
        qs = parse_qs(parsed.query)
        token = qs.get("token", [None])[0]

        if not token:
            # Fallback to path segment if token is in path
            path_parts = [p for p in parsed.path.split("/") if p]
            if path_parts:
                token = path_parts[-1]

        if not token:
            raise ValueError("Could not extract tracking token from the provided URL")

        # Estimate expiry from token JWT claims if possible
        estimated_exp = self.get_token_expiry(token)

        return ShareToken(
            token=token,
            host=host,
            raw_url=url,
            estimated_expires_at=estimated_exp,
        )

    def get_token_expiry(self, token: str) -> Optional[datetime]:
        """Inspect unverified JWT claims for 'exp' timestamp."""
        try:
            # Decode without signature verification for display preview only
            payload = jwt.decode(token, options={"verify_signature": False})
            exp_ts = payload.get("exp")
            if exp_ts and isinstance(exp_ts, (int, float)):
                return datetime.fromtimestamp(exp_ts, tz=timezone.utc)
        except Exception:
            # Token may not be a standard JWT or might have custom encoding
            pass
        return None

    def normalize_position(self, data: dict, reference_now: Optional[datetime] = None) -> ProviderBusPosition:
        """Normalize raw provider payload into typed ProviderBusPosition."""
        # Support common telemetry field keys without treating 0.0 as missing
        lat = data.get("latitude")
        if lat is None:
            lat = data.get("lat")

        lon = data.get("longitude")
        if lon is None:
            lon = data.get("lon")
        if lon is None:
            lon = data.get("lng")

        if lat is None or lon is None:
            raise ValueError("Missing latitude or longitude in provider payload")

        lat = float(lat)
        lon = float(lon)

        # Coordinate bounds check
        if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lon <= 180.0):
            raise ValueError(f"Coordinates out of range: lat={lat}, lon={lon}")

        # Reject null island
        if abs(lat) < 0.0001 and abs(lon) < 0.0001:
            raise ValueError("Coordinates indicate invalid Null Island (0,0)")

        # Parse timestamp
        raw_time = data.get("observed_at")
        if raw_time is None:
            raw_time = data.get("timestamp")
        if raw_time is None:
            raw_time = data.get("time")

        if raw_time is not None:
            if isinstance(raw_time, (int, float)):
                # If milliseconds vs seconds
                if raw_time > 1e11:
                    raw_time = raw_time / 1000.0
                observed_at = datetime.fromtimestamp(raw_time, tz=timezone.utc)
            elif isinstance(raw_time, str):
                try:
                    observed_at = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
                except ValueError:
                    observed_at = datetime.now(timezone.utc)
            else:
                observed_at = datetime.now(timezone.utc)
        else:
            observed_at = datetime.now(timezone.utc)

        # Sanity check: not far in the future
        now = reference_now or datetime.now(timezone.utc)
        if observed_at > now + timedelta(minutes=15):
            raise ValueError(f"Observed timestamp is in the future: {observed_at}")

        accuracy = data.get("accuracy") or data.get("accuracy_meters")
        speed = data.get("speed") or data.get("speed_mps")
        heading = data.get("heading") or data.get("heading_degrees") or data.get("bearing")

        return ProviderBusPosition(
            latitude=lat,
            longitude=lon,
            observed_at=observed_at,
            accuracy_meters=float(accuracy) if accuracy is not None else None,
            speed_mps=float(speed) if speed is not None else None,
            heading_degrees=float(heading) if heading is not None else None,
            is_live=True,
        )

    def normalize_error(self, exc: Exception) -> ProviderError:
        """Map exceptions to typed ProviderError."""
        if isinstance(exc, httpx.HTTPStatusError):
            status = exc.response.status_code
            if status in (401, 403):
                return ProviderError(
                    code="TOKEN_EXPIRED_OR_UNAUTHORIZED",
                    message="Provider tracking token has expired or is unauthorized.",
                    is_recoverable=False,
                )
            elif status == 404:
                return ProviderError(
                    code="TRACKING_SESSION_NOT_FOUND",
                    message="The tracking link is no longer available on provider.",
                    is_recoverable=False,
                )
            elif status == 429:
                retry_header = exc.response.headers.get("Retry-After")
                retry_after = int(retry_header) if retry_header and retry_header.isdigit() else 30
                return ProviderError(
                    code="PROVIDER_RATE_LIMITED",
                    message="Provider is rate limiting polling requests.",
                    retry_after_seconds=retry_after,
                    is_recoverable=True,
                )
            else:
                return ProviderError(
                    code="PROVIDER_HTTP_ERROR",
                    message=f"Provider returned HTTP {status}: {exc.response.text[:100]}",
                    is_recoverable=True,
                )
        elif isinstance(exc, httpx.TimeoutException):
            return ProviderError(
                code="PROVIDER_TIMEOUT",
                message="Timeout while contacting location provider.",
                retry_after_seconds=10,
                is_recoverable=True,
            )
        elif isinstance(exc, httpx.RequestError):
            return ProviderError(
                code="PROVIDER_NETWORK_ERROR",
                message=f"Network error contacting provider: {str(exc)}",
                retry_after_seconds=10,
                is_recoverable=True,
            )
        else:
            return ProviderError(
                code="PROVIDER_UNKNOWN_ERROR",
                message=str(exc),
                is_recoverable=False,
            )

    async def validate_share(self, token: str) -> ProviderValidationResult:
        """Query provider endpoint to confirm token validity."""
        # For production live calls when live endpoint schema is verified
        try:
            position = await self.fetch_location(token)
            return ProviderValidationResult(
                is_valid=True,
                status_code=200,
                message="Tracking session validated successfully",
                expires_at=self.get_token_expiry(token),
                initial_position=position,
            )
        except Exception as exc:
            err = self.normalize_error(exc)
            return ProviderValidationResult(
                is_valid=False,
                status_code=400,
                message=err.message,
                expires_at=None,
                initial_position=None,
            )

    async def fetch_location(self, token: str) -> ProviderBusPosition:
        """Fetch real-time location using authorized endpoint."""
        url = f"https://trackgps.blackbuck.com/api/v1/track/{token}"
        timeout = httpx.Timeout(settings.POLLER_TIMEOUT_SECONDS, connect=5.0)

        if self._client:
            response = await self._client.get(url, timeout=timeout)
        else:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, timeout=timeout)

        response.raise_for_status()
        data = response.json()
        return self.normalize_position(data)
