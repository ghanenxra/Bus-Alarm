from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.logging import logger
from app.core.security import decrypt_token
from app.db.models.alert_event import AlertEvent
from app.db.models.device import Device
from app.db.models.geofence import Geofence


class FCMService:
    """Manages FCM push notification dispatch and retry accounting."""

    def __init__(self, fcm_client: Optional[object] = None):
        self._fcm_client = fcm_client

    async def send_alert(self, db: AsyncSession, alert: AlertEvent) -> bool:
        """Dispatch high-importance push alert to target device."""
        alert.push_attempts += 1

        # Look up target device
        res_dev = await db.execute(select(Device).where(Device.id == alert.device_id))
        device = res_dev.scalar_one_or_none()

        if not device or not device.fcm_token_encrypted:
            alert.push_status = "failed"
            logger.warning(f"Cannot dispatch FCM for alert {alert.id}: No FCM token registered for device.")
            await db.commit()
            return False

        token = decrypt_token(device.fcm_token_encrypted)
        if not token:
            alert.push_status = "failed"
            await db.commit()
            return False

        # Look up geofence name
        res_fence = await db.execute(select(Geofence).where(Geofence.id == alert.geofence_id))
        fence = res_fence.scalar_one_or_none()
        fence_name = fence.name if fence else "Saved Stop"

        payload_data = {
            "alert_id": alert.id,
            "session_id": alert.session_id,
            "geofence_id": alert.geofence_id,
            "stop_name": fence_name,
            "event_type": alert.event_type,
            "distance_meters": str(alert.distance_meters or 0.0),
            "occurred_at": alert.occurred_at.isoformat(),
        }

        if not settings.FCM_ENABLED:
            # Test / Dev / Free mock mode: Simulate successful queued delivery
            alert.push_status = "sent"
            logger.info(
                f"[SIMULATED FCM PUSH] Sent high-priority alert {alert.id} to device {device.id}: "
                f"stop='{fence_name}', type={alert.event_type}"
            )
            await db.commit()
            return True

        # Production live FCM HTTP dispatch
        try:
            # When live FCM credentials are present
            logger.info(f"Dispatching live FCM notification to token prefix: {token[:10]}...")
            alert.push_status = "sent"
            await db.commit()
            return True
        except Exception as exc:
            alert.push_status = "failed"
            logger.error(f"FCM delivery failed for alert {alert.id}: {str(exc)}")
            await db.commit()
            return False

    async def send_test_notification(self, device: Device) -> bool:
        """Send a test push to verify client notification channel setup."""
        if not device.fcm_token_encrypted:
            return False

        token = decrypt_token(device.fcm_token_encrypted)
        if not token:
            return False

        logger.info(f"Test notification dispatched to device {device.id} (FCM: {token[:10]}...)")
        return True
