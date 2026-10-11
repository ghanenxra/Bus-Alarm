import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.logging import logger
from app.db.models.alert_event import AlertEvent
from app.db.models.bus_position import BusPosition
from app.db.models.geofence import Geofence
from app.db.models.tracking_session import TrackingSession
from app.services.geo import evaluate_crossing


class GeofenceService:
    """Evaluates bus movements against configured geofences and handles event idempotency."""

    def __init__(self, push_dispatcher: Optional[object] = None):
        self._push_dispatcher = push_dispatcher

    async def evaluate_session_position(
        self,
        db: AsyncSession,
        session: TrackingSession,
        curr_pos: BusPosition,
    ) -> List[AlertEvent]:
        """Check latest position against all active geofences for session."""
        # 1. Fetch previous valid position
        stmt_prev = (
            select(BusPosition)
            .where(
                BusPosition.session_id == session.id,
                BusPosition.id != curr_pos.id,
                BusPosition.observed_at <= curr_pos.observed_at,
            )
            .order_by(desc(BusPosition.observed_at))
            .limit(1)
        )
        res_prev = await db.execute(stmt_prev)
        prev_pos = res_prev.scalar_one_or_none()

        prev_lat = prev_pos.latitude if prev_pos else None
        prev_lon = prev_pos.longitude if prev_pos else None

        # 2. Fetch enabled geofences
        stmt_fences = (
            select(Geofence)
            .where(
                Geofence.session_id == session.id,
                Geofence.enabled.is_(True),
            )
        )
        res_fences = await db.execute(stmt_fences)
        geofences = res_fences.scalars().all()

        triggered_events: List[AlertEvent] = []

        for fence in geofences:
            eval_res = evaluate_crossing(
                prev_lat=prev_lat,
                prev_lon=prev_lon,
                curr_lat=curr_pos.latitude,
                curr_lon=curr_pos.longitude,
                fence_lat=fence.latitude,
                fence_lon=fence.longitude,
                radius_meters=float(fence.radius_meters),
                uncertainty_margin_meters=20.0,
            )

            if not eval_res.is_triggered:
                continue

            # 3. Check Cooldown
            now_dt = curr_pos.observed_at
            if now_dt.tzinfo is None:
                now_dt = now_dt.replace(tzinfo=timezone.utc)

            if fence.last_triggered_at:
                last_tz = (
                    fence.last_triggered_at
                    if fence.last_triggered_at.tzinfo
                    else fence.last_triggered_at.replace(tzinfo=timezone.utc)
                )
                elapsed_sec = (now_dt - last_tz).total_seconds()
                if elapsed_sec < fence.cooldown_seconds:
                    logger.info(
                        f"Geofence {fence.name} ({fence.id}) triggered but suppressed by cooldown: "
                        f"{elapsed_sec:.0f}s < {fence.cooldown_seconds}s"
                    )
                    continue

            # 4. Generate Idempotent Event Key
            epoch_sec = int(now_dt.timestamp())
            cooldown_window = max(60, fence.cooldown_seconds)
            episode_bucket = epoch_sec // cooldown_window
            event_key = f"{session.id}:{fence.id}:{episode_bucket}"

            # Check if event already logged
            stmt_existing = select(AlertEvent).where(AlertEvent.event_key == event_key)
            res_existing = await db.execute(stmt_existing)
            if res_existing.scalar_one_or_none():
                logger.info(f"Duplicate event key {event_key} already recorded. Skipping.")
                continue

            # 5. Persist unique AlertEvent before sending push
            alert = AlertEvent(
                id=str(uuid.uuid4()),
                device_id=session.device_id,
                session_id=session.id,
                geofence_id=fence.id,
                event_key=event_key,
                event_type=eval_res.trigger_type or "crossing",
                distance_meters=eval_res.distance_meters,
                occurred_at=now_dt,
                push_status="queued",
            )
            db.add(alert)
            fence.last_triggered_at = now_dt
            triggered_events.append(alert)

            logger.info(
                f"Recorded alert event for geofence '{fence.name}': "
                f"type={alert.event_type}, distance={alert.distance_meters:.1f}m"
            )

        if triggered_events:
            await db.commit()
            for evt in triggered_events:
                await db.refresh(evt)
                if self._push_dispatcher and hasattr(self._push_dispatcher, "send_alert"):
                    try:
                        await self._push_dispatcher.send_alert(db, evt)
                    except Exception as exc:
                        logger.error(f"Failed to dispatch push for alert {evt.id}: {str(exc)}")

        return triggered_events
