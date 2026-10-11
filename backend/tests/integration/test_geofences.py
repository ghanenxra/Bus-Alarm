import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.models.bus_position import BusPosition
from app.db.models.tracking_session import TrackingSession
from app.services.geofence_service import GeofenceService


@pytest.mark.asyncio
async def test_geofence_crud_and_validation(client: AsyncClient):
    secret = "device-geofence-test-secret"
    install_id = str(uuid.uuid4())

    reg_resp = await client.post(
        "/api/v1/devices/register",
        headers={"X-Device-Secret": secret},
        json={"installation_id": install_id},
    )
    device_id = reg_resp.json()["device_id"]

    # Create session
    sess_resp = await client.post(
        "/api/v1/tracking-sessions",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "nickname": "Test Route",
            "share_url": "https://mock.busalarm.local/location?token=mock123",
        },
    )
    session_id = sess_resp.json()["id"]

    # 1. Invalid radius (<30) -> 422
    bad_radius_resp = await client.post(
        "/api/v1/geofences",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "session_id": session_id,
            "name": "Invalid Stop",
            "latitude": 25.18,
            "longitude": 75.83,
            "radius_meters": 10,
        },
    )
    assert bad_radius_resp.status_code == 422

    # 2. Valid geofence creation -> 201
    create_resp = await client.post(
        "/api/v1/geofences",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "session_id": session_id,
            "name": "College Gate",
            "latitude": 25.1850,
            "longitude": 75.8350,
            "radius_meters": 200,
            "cooldown_seconds": 600,
        },
    )
    assert create_resp.status_code == 201
    fence_data = create_resp.json()
    assert fence_data["name"] == "College Gate"
    assert fence_data["radius_meters"] == 200
    fence_id = fence_data["id"]

    # 3. List geofences -> 200
    list_resp = await client.get(
        "/api/v1/geofences",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id, "session_id": session_id},
    )
    assert list_resp.status_code == 200
    fences = list_resp.json()
    assert len(fences) == 1
    assert fences[0]["id"] == fence_id

    # 4. Patch geofence (disable) -> 200
    patch_resp = await client.patch(
        f"/api/v1/geofences/{fence_id}",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
        json={"enabled": False, "radius_meters": 300},
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["enabled"] is False
    assert patch_resp.json()["radius_meters"] == 300

    # 5. Delete geofence -> 204
    del_resp = await client.delete(
        f"/api/v1/geofences/{fence_id}",
        headers={"X-Device-Secret": secret},
        params={"device_id": device_id},
    )
    assert del_resp.status_code == 204


@pytest.mark.asyncio
async def test_geofence_service_trigger_and_cooldown(
    client: AsyncClient, db_session: AsyncSession
):
    secret = "geofence-service-test-secret"
    install_id = str(uuid.uuid4())

    reg_resp = await client.post(
        "/api/v1/devices/register",
        headers={"X-Device-Secret": secret},
        json={"installation_id": install_id},
    )
    device_id = reg_resp.json()["device_id"]

    sess_resp = await client.post(
        "/api/v1/tracking-sessions",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "nickname": "Proximity Route",
            "share_url": "https://mock.busalarm.local/location?token=mock456",
        },
    )
    session_id = sess_resp.json()["id"]

    # Create geofence at (25.2500, 75.8300) with radius 200m and 10min cooldown
    fence_resp = await client.post(
        "/api/v1/geofences",
        headers={"X-Device-Secret": secret},
        json={
            "device_id": device_id,
            "session_id": session_id,
            "name": "Hostel Stop",
            "latitude": 25.2500,
            "longitude": 75.8300,
            "radius_meters": 200,
            "cooldown_seconds": 600,
        },
    )
    assert fence_resp.status_code == 201

    session = await db_session.get(TrackingSession, session_id)
    geo_svc = GeofenceService()

    # Position 1: Outside (latitude 25.2200, ~3.3km away from 25.2500)
    now = datetime.now(timezone.utc)
    pos_outside = BusPosition(
        session_id=session_id,
        latitude=25.2200,
        longitude=75.8300,
        observed_at=now,
        received_at=now,
    )
    db_session.add(pos_outside)
    await db_session.commit()
    await db_session.refresh(pos_outside)

    events_1 = await geo_svc.evaluate_session_position(db_session, session, pos_outside)
    assert len(events_1) == 0  # No alert while outside

    # Position 2: Bus enters geofence (dist ~ 22m from 25.2500)
    pos_inside = BusPosition(
        session_id=session_id,
        latitude=25.2502,
        longitude=75.8300,
        observed_at=now,
        received_at=now,
    )
    db_session.add(pos_inside)
    await db_session.commit()
    await db_session.refresh(pos_inside)

    events_2 = await geo_svc.evaluate_session_position(db_session, session, pos_inside)
    assert len(events_2) == 1
    assert events_2[0].event_type == "enter"
    assert events_2[0].push_status == "queued"

    # Position 3: Repeated position inside geofence 10 seconds later
    # Must be suppressed by cooldown!
    pos_repeated = BusPosition(
        session_id=session_id,
        latitude=25.2501,
        longitude=75.8300,
        observed_at=now,
        received_at=now,
    )
    db_session.add(pos_repeated)
    await db_session.commit()
    await db_session.refresh(pos_repeated)

    events_3 = await geo_svc.evaluate_session_position(db_session, session, pos_repeated)
    assert len(events_3) == 0  # Suppressed by cooldown!
