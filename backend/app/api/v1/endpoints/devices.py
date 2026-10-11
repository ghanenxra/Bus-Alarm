import uuid
from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_authenticated_device
from app.core.security import encrypt_token, hash_device_credential
from app.db.models.device import Device
from app.db.session import get_db
from app.schemas.device import (
    DeviceRegisterRequest,
    DeviceRegisterResponse,
    FCMTokenUpdateRequest,
    FCMTokenUpdateResponse,
)

router = APIRouter(prefix="/devices", tags=["Devices"])


@router.post("/register", response_model=DeviceRegisterResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    payload: DeviceRegisterRequest,
    x_device_secret: Optional[str] = Header(None, alias="X-Device-Secret"),
    db: AsyncSession = Depends(get_db),
) -> DeviceRegisterResponse:
    """Register mobile installation or rotate secret credentials."""
    if not x_device_secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Header X-Device-Secret is required for device registration.",
        )

    cred_hash = hash_device_credential(x_device_secret)
    encrypted_fcm = encrypt_token(payload.fcm_token) if payload.fcm_token else None

    # Check for existing device by installation_id
    stmt = select(Device).where(Device.installation_id == payload.installation_id)
    result = await db.execute(stmt)
    existing_device = result.scalar_one_or_none()

    if existing_device:
        existing_device.credential_hash = cred_hash
        existing_device.platform = payload.platform
        existing_device.app_version = payload.app_version
        if encrypted_fcm:
            existing_device.fcm_token_encrypted = encrypted_fcm
        existing_device.is_active = True
        await db.commit()
        await db.refresh(existing_device)
        return DeviceRegisterResponse(
            device_id=existing_device.id,
            registered=True,
            created_at=existing_device.created_at,
        )

    # Create new device
    device_id = str(uuid.uuid4())
    device = Device(
        id=device_id,
        installation_id=payload.installation_id,
        credential_hash=cred_hash,
        platform=payload.platform,
        app_version=payload.app_version,
        fcm_token_encrypted=encrypted_fcm,
    )
    db.add(device)
    await db.commit()
    await db.refresh(device)

    return DeviceRegisterResponse(
        device_id=device.id,
        registered=True,
        created_at=device.created_at,
    )


@router.put("/{device_id}/fcm-token", response_model=FCMTokenUpdateResponse)
async def update_fcm_token(
    device_id: str,
    payload: FCMTokenUpdateRequest,
    device: Device = Depends(get_authenticated_device),
    db: AsyncSession = Depends(get_db),
) -> FCMTokenUpdateResponse:
    """Update FCM token for registered device."""
    device.fcm_token_encrypted = encrypt_token(payload.fcm_token)
    await db.commit()
    return FCMTokenUpdateResponse(updated=True)


@router.post("/{device_id}/test-notification")
async def send_test_notification(
    device_id: str,
    device: Device = Depends(get_authenticated_device),
    db: AsyncSession = Depends(get_db),
):
    """Trigger a test push notification to verify channels."""
    from app.services.fcm_service import FCMService
    fcm_svc = FCMService()
    success = await fcm_svc.send_test_notification(device)
    return {"success": success, "message": "Test notification queued"}
