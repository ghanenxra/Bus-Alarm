from datetime import datetime, timezone, timedelta
from typing import List, Optional
from app.providers.base import (
    BaseProvider,
    ProviderBusPosition,
    ProviderError,
    ProviderValidationResult,
    ShareToken,
)


class MockBlackbuckProvider(BaseProvider):
    """Deterministic mock provider for testing and development."""

    def __init__(
        self,
        positions: Optional[List[ProviderBusPosition]] = None,
        simulate_error: Optional[str] = None,
    ):
        self._positions = positions or []
        self._current_index = 0
        self._simulate_error = simulate_error
        self._default_lat = 25.1800
        self._default_lon = 75.8300

    def set_positions(self, positions: List[ProviderBusPosition]) -> None:
        self._positions = positions
        self._current_index = 0

    def parse_share_url(self, url: str) -> ShareToken:
        if not url:
            raise ValueError("URL must not be empty")
        return ShareToken(
            token="mock-valid-token-12345",
            host="mock.busalarm.local",
            raw_url=url,
            estimated_expires_at=datetime.now(timezone.utc) + timedelta(hours=24),
        )

    def get_token_expiry(self, token: str) -> Optional[datetime]:
        return datetime.now(timezone.utc) + timedelta(hours=24)

    def normalize_error(self, exc: Exception) -> ProviderError:
        return ProviderError(
            code="MOCK_ERROR",
            message=str(exc),
            is_recoverable=True,
        )

    async def validate_share(self, token: str) -> ProviderValidationResult:
        if self._simulate_error == "expired":
            return ProviderValidationResult(
                is_valid=False,
                status_code=401,
                message="Mock token expired",
            )
        return ProviderValidationResult(
            is_valid=True,
            status_code=200,
            message="Mock session validated successfully",
            expires_at=datetime.now(timezone.utc) + timedelta(hours=24),
            initial_position=await self.fetch_location(token),
        )

    async def fetch_location(self, token: str) -> ProviderBusPosition:
        if self._simulate_error == "rate_limited":
            raise Exception("Mock rate limit 429")
        if self._simulate_error == "expired":
            raise Exception("Mock token expired 401")

        if self._positions:
            pos = self._positions[self._current_index]
            self._current_index = (self._current_index + 1) % len(self._positions)
            return pos

        # Dynamic simulation: bus moves slightly north each call
        self._default_lat += 0.0005
        return ProviderBusPosition(
            latitude=self._default_lat,
            longitude=self._default_lon,
            observed_at=datetime.now(timezone.utc),
            accuracy_meters=5.0,
            speed_mps=12.5,
            heading_degrees=45.0,
            is_live=True,
        )
