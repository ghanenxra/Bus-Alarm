import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import verify_device_access
from app.db.models.device import Device
from app.db.models.geofence import Geofence
from app.db.models.tracking_session import TrackingSession
from app.db.session import get_db
from app.schemas.geofence import (
    GeofenceCreate,
    GeofenceResponse,
    GeofenceUpdate,
)

router = APIRouter(prefix="/geofences", tags=["Geofences"])


@router.post("", response_model=GeofenceResponse, status_code=status.HTTP_201_CREATED)
async def create_geofence(
    payload: GeofenceCreate,
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> GeofenceResponse:
    """Create a new geofence tied to an active tracking session."""
    device = await verify_device_access(db, payload.device_id, x_device_secret)

    # Verify session belongs to device
    stmt_sess = select(TrackingSession).where(
        TrackingSession.id == payload.session_id,
        TrackingSession.device_id == device.id,
    )
    res_sess = await db.execute(stmt_sess)
    session = res_sess.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tracking session '{payload.session_id}' not found for this device.",
        )

    fence_id = str(uuid.uuid4())
    fence = Geofence(
        id=fence_id,
        device_id=device.id,
        session_id=session.id,
        name=payload.name,
        latitude=payload.latitude,
        longitude=payload.longitude,
        radius_meters=payload.radius_meters,
        enabled=payload.enabled,
        trigger_mode=payload.trigger_mode,
        cooldown_seconds=payload.cooldown_seconds,
    )
    db.add(fence)
    await db.commit()
    await db.refresh(fence)

    return GeofenceResponse(
        id=fence.id,
        device_id=fence.device_id,
        session_id=fence.session_id,
        name=fence.name,
        latitude=fence.latitude,
        longitude=fence.longitude,
        radius_meters=fence.radius_meters,
        enabled=fence.enabled,
        trigger_mode=fence.trigger_mode,
        cooldown_seconds=fence.cooldown_seconds,
        last_triggered_at=fence.last_triggered_at,
        created_at=fence.created_at,
        updated_at=fence.updated_at,
    )


@router.get("", response_model=List[GeofenceResponse])
async def list_geofences(
    device_id: str = Query(...),
    session_id: Optional[str] = Query(None),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> List[GeofenceResponse]:
    """List geofences registered for device."""
    device = await verify_device_access(db, device_id, x_device_secret)

    query = select(Geofence).where(Geofence.device_id == device.id)
    if session_id:
        query = query.where(Geofence.session_id == session_id)

    res = await db.execute(query)
    fences = res.scalars().all()

    return [
        GeofenceResponse(
            id=f.id,
            device_id=f.device_id,
            session_id=f.session_id,
            name=f.name,
            latitude=f.latitude,
            longitude=f.longitude,
            radius_meters=f.radius_meters,
            enabled=f.enabled,
            trigger_mode=f.trigger_mode,
            cooldown_seconds=f.cooldown_seconds,
            last_triggered_at=f.last_triggered_at,
            created_at=f.created_at,
            updated_at=f.updated_at,
        )
        for f in fences
    ]


@router.get("/{geofence_id}", response_model=GeofenceResponse)
async def get_geofence(
    geofence_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> GeofenceResponse:
    """Get single geofence configuration."""
    device = await verify_device_access(db, device_id, x_device_secret)

    res = await db.execute(
        select(Geofence).where(Geofence.id == geofence_id, Geofence.device_id == device.id)
    )
    fence = res.scalar_one_or_none()
    if not fence:
        raise HTTPException(status_code=404, detail="Geofence not found")

    return GeofenceResponse(
        id=fence.id,
        device_id=fence.device_id,
        session_id=fence.session_id,
        name=fence.name,
        latitude=fence.latitude,
        longitude=fence.longitude,
        radius_meters=fence.radius_meters,
        enabled=fence.enabled,
        trigger_mode=fence.trigger_mode,
        cooldown_seconds=fence.cooldown_seconds,
        last_triggered_at=fence.last_triggered_at,
        created_at=fence.created_at,
        updated_at=fence.updated_at,
    )


@router.patch("/{geofence_id}", response_model=GeofenceResponse)
async def update_geofence(
    geofence_id: str,
    payload: GeofenceUpdate,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> GeofenceResponse:
    """Update geofence configuration, enable/disable toggle, or coordinates."""
    device = await verify_device_access(db, device_id, x_device_secret)

    res = await db.execute(
        select(Geofence).where(Geofence.id == geofence_id, Geofence.device_id == device.id)
    )
    fence = res.scalar_one_or_none()
    if not fence:
        raise HTTPException(status_code=404, detail="Geofence not found")

    if payload.name is not None:
        fence.name = payload.name
    if payload.latitude is not None:
        fence.latitude = payload.latitude
    if payload.longitude is not None:
        fence.longitude = payload.longitude
    if payload.radius_meters is not None:
        fence.radius_meters = payload.radius_meters
    if payload.enabled is not None:
        fence.enabled = payload.enabled
    if payload.trigger_mode is not None:
        fence.trigger_mode = payload.trigger_mode
    if payload.cooldown_seconds is not None:
        fence.cooldown_seconds = payload.cooldown_seconds

    await db.commit()
    await db.refresh(fence)

    return GeofenceResponse(
        id=fence.id,
        device_id=fence.device_id,
        session_id=fence.session_id,
        name=fence.name,
        latitude=fence.latitude,
        longitude=fence.longitude,
        radius_meters=fence.radius_meters,
        enabled=fence.enabled,
        trigger_mode=fence.trigger_mode,
        cooldown_seconds=fence.cooldown_seconds,
        last_triggered_at=fence.last_triggered_at,
        created_at=fence.created_at,
        updated_at=fence.updated_at,
    )


@router.delete("/{geofence_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_geofence(
    geofence_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
):
    """Delete geofence."""
    device = await verify_device_access(db, device_id, x_device_secret)

    res = await db.execute(
        select(Geofence).where(Geofence.id == geofence_id, Geofence.device_id == device.id)
    )
    fence = res.scalar_one_or_none()
    if not fence:
        raise HTTPException(status_code=404, detail="Geofence not found")

    await db.delete(fence)
    await db.commit()
