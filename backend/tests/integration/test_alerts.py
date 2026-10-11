import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.alert_event import AlertEvent
from app.db.models.geofence import Geofence
from app.db.models.tracking_session import TrackingSession
from app.services.fcm_service import FCMService


@pytest.mark.asyncio
async def test_alerts_and_acknowledgement(client: AsyncClient, db_session: AsyncSession):
    secret = "alert-test-secret-12345"
    install_id = str(uuid.uuid4())

    reg_resp = await client.post(
        "/api/v1/devices/register",
        headers={"X-Device-Secret": secret},
        json={
            "installation_id": install_id,
            "fcm_token": "valid-device-fcm-token",
        },
    )
    device_id = reg_resp.json()["device_id"]

    # Test notification
    test_push_resp = await client.post(
        f"/api/v1/devices/{device_id}/test-notification",
        headers={"X-Device-Secret": secret},
    )
    assert test_push_resp.status_code == 200
    assert test_push_resp.json()["success"] is True

    # Create session and geofence
    sess_resp = await client.post(
        "/api/v1/tracking-sessions",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "nickname": "Alerts Route",
            "share_url": "https://mock.busalarm.local/location?token=mockAlerts",
        },
    )
    session_id = sess_resp.json()["id"]

    fence_resp = await client.post(
        "/api/v1/geofences",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "session_id": session_id,
            "name": "Library Gate",
            "latitude": 25.1820,
            "longitude": 75.8320,
            "radius_meters": 180,
        },
    )
    fence_id = fence_resp.json()["id"]

    # Manually insert an AlertEvent
    alert_id = str(uuid.uuid4())
    alert = AlertEvent(
        id=alert_id,
        device_id=device_id,
        session_id=session_id,
        geofence_id=fence_id,
        event_key=f"{session_id}:{fence_id}:1000",
        event_type="crossing",
        distance_meters=42.5,
        occurred_at=datetime.now(timezone.utc),
        push_status="queued",
    )
    db_session.add(alert)
    await db_session.commit()

    # Dispatch via FCMService
    fcm_svc = FCMService()
    dispatch_success = await fcm_svc.send_alert(db_session, alert)
    assert dispatch_success is True
    assert alert.push_status == "sent"

    # List alerts via API
    list_resp = await client.get(
        "/api/v1/alerts",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert list_resp.status_code == 200
    alerts = list_resp.json()
    assert len(alerts) == 1
    assert alerts[0]["id"] == alert_id
    assert alerts[0]["push_status"] == "sent"

    # Get single alert
    get_resp = await client.get(
        f"/api/v1/alerts/{alert_id}",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == alert_id

    # Acknowledge with dismiss
    ack_resp = await client.post(
        f"/api/v1/alerts/{alert_id}/acknowledge",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
        json={"action": "dismiss"},
    )
    assert ack_resp.status_code == 200
    ack_data = ack_resp.json()
    assert ack_data["status"] == "acknowledged"
    assert ack_data["action"] == "dismiss"

    # Acknowledge with snooze
    snooze_resp = await client.post(
        f"/api/v1/alerts/{alert_id}/acknowledge",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
        json={"action": "snooze", "snooze_seconds": 60},
    )
    assert snooze_resp.status_code == 200
    assert snooze_resp.json()["action"] == "snooze"

