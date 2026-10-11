import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.dependencies import verify_device_access
from app.core.security import decrypt_token, encrypt_token
from app.db.models.bus_position import BusPosition
from app.db.models.tracking_session import TrackingSession
from app.db.session import get_db
from app.providers.blackbuck import BlackbuckProvider
from app.providers.mock_provider import MockBlackbuckProvider
from app.schemas.bus_position import BusPositionResponse
from app.schemas.session import (
    TrackingSessionCreate,
    TrackingSessionResponse,
    TrackingSessionStateChangeResponse,
)

router = APIRouter(prefix="/tracking-sessions", tags=["Tracking Sessions"])


def _get_provider(host: str):
    if "mock" in host or "local" in host or host in ("localhost", "127.0.0.1"):
        return MockBlackbuckProvider()
    return BlackbuckProvider()


def _format_position_response(pos: Optional[BusPosition]) -> Optional[BusPositionResponse]:
    if not pos:
        return None
    now = datetime.now(timezone.utc)
    obs_time = pos.observed_at
    if obs_time.tzinfo is None:
        obs_time = obs_time.replace(tzinfo=timezone.utc)
    freshness = max(0, int((now - obs_time).total_seconds()))

    return BusPositionResponse(
        session_id=pos.session_id,
        latitude=pos.latitude,
        longitude=pos.longitude,
        observed_at=pos.observed_at,
        received_at=pos.received_at or now,
        accuracy_meters=pos.accuracy_meters,
        speed_mps=pos.speed_mps,
        heading_degrees=pos.heading_degrees,
        freshness_seconds=freshness,
    )


@router.post("", response_model=TrackingSessionResponse, status_code=status.HTTP_201_CREATED)
async def create_tracking_session(
    payload: TrackingSessionCreate,
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> TrackingSessionResponse:
    """Validate tracking URL, extract token, and activate tracking session."""
    device = await verify_device_access(db, payload.device_id, x_device_secret)

    try:
        temp_provider = BlackbuckProvider() if "mock" not in payload.share_url else MockBlackbuckProvider()
        share_token = temp_provider.parse_share_url(payload.share_url)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid tracking link: {str(exc)}",
        )

    provider = _get_provider(share_token.host)

    val_result = await provider.validate_share(share_token.token)
    if not val_result.is_valid and settings.ENVIRONMENT != "development":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Provider rejected tracking share link: {val_result.message}",
        )

    encrypted_token = encrypt_token(share_token.token)

    # Check for existing session with this nickname for idempotent activation
    existing_stmt = select(TrackingSession).where(
        TrackingSession.device_id == device.id,
        TrackingSession.nickname == payload.nickname,
    )
    existing_res = await db.execute(existing_stmt)
    existing_session = existing_res.scalar_one_or_none()

    if existing_session:
        session = existing_session
        session.status = "active"
        session.provider_token_encrypted = encrypted_token
        session.poll_interval_seconds = payload.poll_interval_seconds
        session.last_polled_at = datetime.now(timezone.utc)
        if val_result.expires_at or share_token.estimated_expires_at:
            session.expires_at = val_result.expires_at or share_token.estimated_expires_at
        if val_result.initial_position:
            session.last_success_at = datetime.now(timezone.utc)
            session.last_error_code = None
        else:
            session.last_error_code = val_result.message
    else:
        session_id = str(uuid.uuid4())
        session = TrackingSession(
            id=session_id,
            device_id=device.id,
            nickname=payload.nickname,
            provider="blackbuck" if "mock" not in share_token.host else "mock_blackbuck",
            provider_token_encrypted=encrypted_token,
            expires_at=val_result.expires_at or share_token.estimated_expires_at,
            status="active",
            poll_interval_seconds=payload.poll_interval_seconds,
            last_polled_at=datetime.now(timezone.utc),
            last_success_at=datetime.now(timezone.utc) if val_result.initial_position else None,
            last_error_code=None if val_result.initial_position else val_result.message,
        )
        db.add(session)

    initial_pos_resp = None
    if val_result.initial_position:
        bus_pos = BusPosition(
            session_id=session.id,
            latitude=val_result.initial_position.latitude,
            longitude=val_result.initial_position.longitude,
            observed_at=val_result.initial_position.observed_at,
            accuracy_meters=val_result.initial_position.accuracy_meters,
            speed_mps=val_result.initial_position.speed_mps,
            heading_degrees=val_result.initial_position.heading_degrees,
        )
        db.add(bus_pos)
        initial_pos_resp = _format_position_response(bus_pos)

    await db.commit()
    await db.refresh(session)

    return TrackingSessionResponse(
        id=session.id,
        device_id=session.device_id,
        nickname=session.nickname,
        provider=session.provider,
        status=session.status,
        expires_at=session.expires_at,
        poll_interval_seconds=session.poll_interval_seconds,
        last_polled_at=session.last_polled_at,
        last_success_at=session.last_success_at,
        last_error_code=session.last_error_code,
        created_at=session.created_at,
        updated_at=session.updated_at,
        last_position=initial_pos_resp,
    )


@router.get("", response_model=List[TrackingSessionResponse])
async def list_tracking_sessions(
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> List[TrackingSessionResponse]:
    """List tracking sessions registered to device."""
    device = await verify_device_access(db, device_id, x_device_secret)

    stmt = (
        select(TrackingSession)
        .where(TrackingSession.device_id == device.id)
        .order_by(desc(TrackingSession.created_at))
    )
    result = await db.execute(stmt)
    sessions = result.scalars().all()

    response_items = []
    for s in sessions:
        pos_stmt = (
            select(BusPosition)
            .where(BusPosition.session_id == s.id)
            .order_by(desc(BusPosition.observed_at))
            .limit(1)
        )
        pos_res = await db.execute(pos_stmt)
        latest_pos = pos_res.scalar_one_or_none()

        response_items.append(
            TrackingSessionResponse(
                id=s.id,
                device_id=s.device_id,
                nickname=s.nickname,
                provider=s.provider,
                status=s.status,
                expires_at=s.expires_at,
                poll_interval_seconds=s.poll_interval_seconds,
                last_polled_at=s.last_polled_at,
                last_success_at=s.last_success_at,
                last_error_code=s.last_error_code,
                created_at=s.created_at,
                updated_at=s.updated_at,
                last_position=_format_position_response(latest_pos),
            )
        )
    return response_items


@router.get("/{session_id}", response_model=TrackingSessionResponse)
async def get_tracking_session(
    session_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> TrackingSessionResponse:
    """Get single tracking session details."""
    device = await verify_device_access(db, device_id, x_device_secret)

    stmt = select(TrackingSession).where(
        TrackingSession.id == session_id,
        TrackingSession.device_id == device.id,
    )
    res = await db.execute(stmt)
    session = res.scalar_one_or_none()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tracking session '{session_id}' not found.",
        )

    pos_stmt = (
        select(BusPosition)
        .where(BusPosition.session_id == session.id)
        .order_by(desc(BusPosition.observed_at))
        .limit(1)
    )
    pos_res = await db.execute(pos_stmt)
    latest_pos = pos_res.scalar_one_or_none()

    return TrackingSessionResponse(
        id=session.id,
        device_id=session.device_id,
        nickname=session.nickname,
        provider=session.provider,
        status=session.status,
        expires_at=session.expires_at,
        poll_interval_seconds=session.poll_interval_seconds,
        last_polled_at=session.last_polled_at,
        last_success_at=session.last_success_at,
        last_error_code=session.last_error_code,
        created_at=session.created_at,
        updated_at=session.updated_at,
        last_position=_format_position_response(latest_pos),
    )


@router.post("/{session_id}/activate", response_model=TrackingSessionStateChangeResponse)
async def activate_tracking_session(
    session_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> TrackingSessionStateChangeResponse:
    """Activate or resume polling for session."""
    device = await verify_device_access(db, device_id, x_device_secret)

    stmt = select(TrackingSession).where(
        TrackingSession.id == session_id,
        TrackingSession.device_id == device.id,
    )
    res = await db.execute(stmt)
    session = res.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Tracking session not found")

    session.status = "active"
    await db.commit()
    return TrackingSessionStateChangeResponse(
        session_id=session.id,
        status="active",
        message="Tracking session activated",
    )


@router.post("/{session_id}/pause", response_model=TrackingSessionStateChangeResponse)
async def pause_tracking_session(
    session_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> TrackingSessionStateChangeResponse:
    """Pause polling for session."""
    device = await verify_device_access(db, device_id, x_device_secret)

    stmt = select(TrackingSession).where(
        TrackingSession.id == session_id,
        TrackingSession.device_id == device.id,
    )
    res = await db.execute(stmt)
    session = res.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Tracking session not found")

    session.status = "paused"
    await db.commit()
    return TrackingSessionStateChangeResponse(
        session_id=session.id,
        status="paused",
        message="Tracking session paused",
    )


@router.get("/{session_id}/position", response_model=BusPositionResponse)
async def get_latest_position(
    session_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> BusPositionResponse:
    """Get the most recent verified bus coordinates."""
    await verify_device_access(db, device_id, x_device_secret)

    pos_stmt = (
        select(BusPosition)
        .where(BusPosition.session_id == session_id)
        .order_by(desc(BusPosition.observed_at))
        .limit(1)
    )
    pos_res = await db.execute(pos_stmt)
    latest_pos = pos_res.scalar_one_or_none()

    if not latest_pos:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No recorded positions found for this tracking session yet.",
        )

    return _format_position_response(latest_pos)  # type: ignore


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tracking_session(
    session_id: str,
    device_id: str = Query(...),
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
):
    """Delete tracking session and all linked geofences and position history."""
    device = await verify_device_access(db, device_id, x_device_secret)

    stmt = select(TrackingSession).where(
        TrackingSession.id == session_id,
        TrackingSession.device_id == device.id,
    )
    res = await db.execute(stmt)
    session = res.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Tracking session not found")

    await db.delete(session)
    await db.commit()
