import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.workers.poller import TrackingPoller


@pytest.mark.asyncio
async def test_device_registration_and_auth(client: AsyncClient):
    install_id = str(uuid.uuid4())
    secret = "secret-pass-key-12345"

    # Register without secret header -> 400
    resp_no_secret = await client.post(
        "/api/v1/devices/register",
        json={"installation_id": install_id, "platform": "android"},
    )
    assert resp_no_secret.status_code == 400

    # Register with secret header -> 201
    resp = await client.post(
        "/api/v1/devices/register",
        headers={"X-Device-Secret": secret},
        json={
            "installation_id": install_id,
            "fcm_token": "fcm-sample-token-123",
            "platform": "android",
            "app_version": "1.0.0",
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["registered"] is True
    device_id = data["device_id"]

    # Update FCM token with valid secret
    update_resp = await client.put(
        f"/api/v1/devices/{device_id}/fcm-token",
        headers={"X-Device-Secret": secret},
        json={"fcm_token": "new-fcm-token-456"},
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["updated"] is True

    # Update FCM token with invalid secret -> 401
    bad_secret_resp = await client.put(
        f"/api/v1/devices/{device_id}/fcm-token",
        headers={"X-Device-Secret": "wrong-secret"},
        json={"fcm_token": "new-fcm-token-789"},
    )
    assert bad_secret_resp.status_code == 401


@pytest.mark.asyncio
async def test_tracking_session_lifecycle(client: AsyncClient, db_session: AsyncSession, session_factory):
    install_id = str(uuid.uuid4())
    secret = "device-secret-xyz-987"

    reg_resp = await client.post(
        "/api/v1/devices/register",
        headers={"X-Device-Secret": secret},
        json={"installation_id": install_id},
    )
    device_id = reg_resp.json()["device_id"]

    # Create tracking session with mock URL
    mock_url = "https://mock.busalarm.local/location?token=mock-valid-token-12345"
    create_resp = await client.post(
        "/api/v1/tracking-sessions",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "nickname": "Campus Express",
            "share_url": mock_url,
            "poll_interval_seconds": 10,
        },
    )
    assert create_resp.status_code == 201
    session_data = create_resp.json()
    assert session_data["nickname"] == "Campus Express"
    assert session_data["status"] == "active"
    assert session_data["last_position"] is not None
    session_id = session_data["id"]

    # List sessions
    list_resp = await client.get(
        "/api/v1/tracking-sessions",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert list_resp.status_code == 200
    sessions = list_resp.json()
    assert len(sessions) == 1
    assert sessions[0]["id"] == session_id

    # Get latest position
    pos_resp = await client.get(
        f"/api/v1/tracking-sessions/{session_id}/position",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert pos_resp.status_code == 200
    pos_data = pos_resp.json()
    assert pos_data["latitude"] > 0
    assert pos_data["longitude"] > 0

    # Pause session
    pause_resp = await client.post(
        f"/api/v1/tracking-sessions/{session_id}/pause",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert pause_resp.status_code == 200
    assert pause_resp.json()["status"] == "paused"

    # Activate session
    act_resp = await client.post(
        f"/api/v1/tracking-sessions/{session_id}/activate",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert act_resp.status_code == 200
    assert act_resp.json()["status"] == "active"

    # Run poller pass
    poller = TrackingPoller(session_factory=session_factory)
    await poller.poll_all_active_sessions()

    # Re-fetch position and check freshness
    pos_after_poll = await client.get(
        f"/api/v1/tracking-sessions/{session_id}/position",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert pos_after_poll.status_code == 200
    assert pos_after_poll.json()["freshness_seconds"] >= 0
