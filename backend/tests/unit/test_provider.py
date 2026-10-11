import json
import os
import time
import pytest
import jwt
import httpx
from datetime import datetime, timezone, timedelta
from app.providers.blackbuck import BlackbuckProvider
from app.providers.mock_provider import MockBlackbuckProvider


@pytest.fixture
def fixtures_data():
    fixture_path = os.path.join(os.path.dirname(__file__), "..", "fixtures", "blackbuck_responses.json")
    with open(fixture_path, "r", encoding="utf-8") as f:
        return json.load(f)


def test_url_parser_valid():
    provider = BlackbuckProvider()
    valid_url = "https://trackgps.blackbuck.com/location?token=test_token_123"
    result = provider.parse_share_url(valid_url)
    assert result.token == "test_token_123"
    assert result.host == "trackgps.blackbuck.com"
    assert result.raw_url == valid_url


def test_url_parser_rejections():
    provider = BlackbuckProvider()

    # Rejects HTTP (must be HTTPS)
    with pytest.raises(ValueError, match="HTTPS"):
        provider.parse_share_url("http://trackgps.blackbuck.com/location?token=test_token")

    # Rejects disallowed host
    with pytest.raises(ValueError, match="not in the allowed"):
        provider.parse_share_url("https://malicious-domain.com/location?token=test_token")

    # Rejects missing token
    with pytest.raises(ValueError, match="Could not extract"):
        provider.parse_share_url("https://trackgps.blackbuck.com/")


def test_jwt_expiry_extraction():
    provider = BlackbuckProvider()
    future_time = int(time.time()) + 3600
    token = jwt.encode({"sub": "bus123", "exp": future_time}, "a-test-secret-key-32-characters!", algorithm="HS256")
    
    expiry = provider.get_token_expiry(token)
    assert expiry is not None
    assert abs(expiry.timestamp() - future_time) < 2

    # Non-jwt token returns None cleanly without throwing
    assert provider.get_token_expiry("opaque_random_token") is None


def test_normalize_valid_telemetry(fixtures_data):
    provider = BlackbuckProvider()
    data = fixtures_data["valid_telemetry"]
    ref_time = datetime(2026, 10, 11, 8, 5, tzinfo=timezone.utc)
    pos = provider.normalize_position(data, reference_now=ref_time)
    assert pos.latitude == 25.184521
    assert pos.longitude == 75.834125
    assert pos.speed_mps == 11.2
    assert pos.is_live is True


def test_normalize_short_keys(fixtures_data):
    provider = BlackbuckProvider()
    data = fixtures_data["short_keys_telemetry"]
    ref_time = datetime.fromtimestamp(data["timestamp"] + 30, tz=timezone.utc)
    pos = provider.normalize_position(data, reference_now=ref_time)
    assert pos.latitude == 25.191024
    assert pos.longitude == 75.840212
    assert pos.heading_degrees == 90.0


def test_reject_invalid_coordinates(fixtures_data):
    provider = BlackbuckProvider()
    with pytest.raises(ValueError, match="out of range"):
        provider.normalize_position(fixtures_data["invalid_coordinates"])

    with pytest.raises(ValueError, match="Null Island"):
        provider.normalize_position(fixtures_data["null_island"])


def test_reject_future_timestamp():
    provider = BlackbuckProvider()
    future_ts = (datetime.now(timezone.utc) + timedelta(hours=2)).isoformat()
    with pytest.raises(ValueError, match="future"):
        provider.normalize_position({
            "latitude": 25.18,
            "longitude": 75.83,
            "observed_at": future_ts
        })


def test_error_normalization():
    provider = BlackbuckProvider()

    # 401 Unauthorized / Expired
    req = httpx.Request("GET", "https://test")
    resp_401 = httpx.Response(401, request=req)
    err_401 = provider.normalize_error(httpx.HTTPStatusError("401", request=req, response=resp_401))
    assert err_401.code == "TOKEN_EXPIRED_OR_UNAUTHORIZED"
    assert err_401.is_recoverable is False

    # 429 Rate limited with Retry-After header
    resp_429 = httpx.Response(429, headers={"Retry-After": "45"}, request=req)
    err_429 = provider.normalize_error(httpx.HTTPStatusError("429", request=req, response=resp_429))
    assert err_429.code == "PROVIDER_RATE_LIMITED"
    assert err_429.retry_after_seconds == 45
    assert err_429.is_recoverable is True

    # Timeout
    timeout_err = provider.normalize_error(httpx.ReadTimeout("Read timed out"))
    assert timeout_err.code == "PROVIDER_TIMEOUT"
    assert timeout_err.is_recoverable is True


@pytest.mark.asyncio
async def test_mock_provider_flow():
    mock = MockBlackbuckProvider()
    validation = await mock.validate_share("mock-token")
    assert validation.is_valid is True
    assert validation.initial_position is not None
    assert validation.initial_position.latitude > 25.0
