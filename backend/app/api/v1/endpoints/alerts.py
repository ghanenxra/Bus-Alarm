from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import verify_device_access
from app.db.models.alert_event import AlertEvent
from app.db.session import get_db
from app.schemas.alert import (
    AlertAcknowledgeRequest,
    AlertAcknowledgeResponse,
    AlertEventResponse,
)

router = APIRouter(prefix="/alerts", tags=["Alerts"])


@router.get("", response_model=List[AlertEventResponse])
async def list_alerts(
    device_id: str = Query(...),
    limit: int = Query(default=50, ge=1, le=100),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> List[AlertEventResponse]:
    """List recent alert events for device."""
    device = await verify_device_access(db, device_id, x_device_secret)

    stmt = (
        select(AlertEvent)
        .where(AlertEvent.device_id == device.id)
        .order_by(desc(AlertEvent.occurred_at))
        .limit(limit)
    )
    res = await db.execute(stmt)
    alerts = res.scalars().all()

    return [
        AlertEventResponse(
            id=a.id,
            device_id=a.device_id,
            session_id=a.session_id,
            geofence_id=a.geofence_id,
            event_key=a.event_key,
            event_type=a.event_type,
            distance_meters=a.distance_meters,
            occurred_at=a.occurred_at,
            push_status=a.push_status,
            push_attempts=a.push_attempts,
            acknowledged_at=a.acknowledged_at,
            user_action=a.user_action,
            created_at=a.created_at,
        )
        for a in alerts
    ]


@router.get("/{alert_id}", response_model=AlertEventResponse)
async def get_alert(
    alert_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> AlertEventResponse:
    """Get single alert event status."""
    device = await verify_device_access(db, device_id, x_device_secret)

    res = await db.execute(
        select(AlertEvent).where(AlertEvent.id == alert_id, AlertEvent.device_id == device.id)
    )
    alert = res.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert event not found")

    return AlertEventResponse(
        id=alert.id,
        device_id=alert.device_id,
        session_id=alert.session_id,
        geofence_id=alert.geofence_id,
        event_key=alert.event_key,
        event_type=alert.event_type,
        distance_meters=alert.distance_meters,
        occurred_at=alert.occurred_at,
        push_status=alert.push_status,
        push_attempts=alert.push_attempts,
        acknowledged_at=alert.acknowledged_at,
        user_action=alert.user_action,
        created_at=alert.created_at,
    )


@router.post("/{alert_id}/acknowledge", response_model=AlertAcknowledgeResponse)
async def acknowledge_alert(
    alert_id: str,
    payload: AlertAcknowledgeRequest,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> AlertAcknowledgeResponse:
    """Acknowledge or snooze alert event from Android notification or alarm UI."""
    device = await verify_device_access(db, device_id, x_device_secret)

    res = await db.execute(
        select(AlertEvent).where(AlertEvent.id == alert_id, AlertEvent.device_id == device.id)
    )
    alert = res.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert event not found")

    now = datetime.now(timezone.utc)
    alert.acknowledged_at = now
    alert.user_action = payload.action

    await db.commit()
    await db.refresh(alert)

    return AlertAcknowledgeResponse(
        alert_id=alert.id,
        status="acknowledged",
        action=alert.user_action,
        acknowledged_at=alert.acknowledged_at,
    )
