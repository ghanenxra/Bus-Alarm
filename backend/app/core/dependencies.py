from datetime import datetime, timezone
from typing import Optional
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.security import verify_device_credential
from app.db.session import get_db
from app.db.models.device import Device


async def verify_device_access(
    db: AsyncSession,
    device_id: str,
    x_device_secret: Optional[str],
) -> Device:
    """Validate device registration and secret credential."""
    result = await db.execute(select(Device).where(Device.id == device_id, Device.is_active.is_(True)))
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID '{device_id}' is not registered or inactive.",
        )

    if settings.DEVICE_AUTH_ENABLED:
        if not x_device_secret:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing required X-Device-Secret authentication header.",
            )
        if not verify_device_credential(x_device_secret, device.credential_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid device credentials.",
            )

    # Touch last seen
    device.last_seen_at = datetime.now(timezone.utc)
    await db.commit()

    return device


async def get_authenticated_device(
    device_id: str,
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> Device:
    """Dependency for routes with {device_id} in URL path."""
    return await verify_device_access(db, device_id, x_device_secret)

