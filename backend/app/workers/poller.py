import asyncio
from datetime import datetime, timezone
from typing import Callable, Optional
from sqlalchemy import desc, select
from app.core.config import settings
from app.core.logging import logger
from app.core.security import decrypt_token
from app.db.models.bus_position import BusPosition
from app.db.models.tracking_session import TrackingSession
from app.db.session import AsyncSessionLocal
from app.providers.blackbuck import BlackbuckProvider
from app.providers.mock_provider import MockBlackbuckProvider


class TrackingPoller:
    """Async background worker polling active tracking sessions with cancellation protection."""

    def __init__(
        self,
        position_callback: Optional[Callable] = None,
        session_factory=None,
    ):
        self._running = False
        self._task: Optional[asyncio.Task] = None
        self._position_callback = position_callback
        self._session_factory = session_factory or AsyncSessionLocal
        self.blackbuck_provider = BlackbuckProvider()
        self.mock_provider = MockBlackbuckProvider()

    def is_running(self) -> bool:
        return self._running

    def start(self) -> None:
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._poll_loop())
        logger.info("Tracking poller worker started.")

    async def stop(self) -> None:
        if not self._running:
            return
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("Tracking poller worker stopped cleanly.")

    async def _poll_loop(self) -> None:
        while self._running:
            try:
                await self.poll_all_active_sessions()
            except asyncio.CancelledError:
                break
            except Exception as exc:
                logger.error(f"Error in poller execution tick: {str(exc)}", exc_info=True)

            try:
                await asyncio.sleep(settings.DEFAULT_POLL_INTERVAL_SECONDS)
            except asyncio.CancelledError:
                break

    async def poll_all_active_sessions(self) -> None:
        """Query database for active sessions and poll each provider feed."""
        async with self._session_factory() as db:
            stmt = select(TrackingSession).where(TrackingSession.status == "active")
            result = await db.execute(stmt)
            active_sessions = result.scalars().all()

            for session in active_sessions:
                await self._poll_single_session(db, session)
            await db.commit()

    async def _poll_single_session(self, db, session: TrackingSession) -> None:
        now = datetime.now(timezone.utc)
        session.last_polled_at = now

        # 1. Expiry check
        if session.expires_at:
            exp_tz = session.expires_at if session.expires_at.tzinfo else session.expires_at.replace(tzinfo=timezone.utc)
            if now > exp_tz:
                logger.info(f"Session {session.id} ({session.nickname}) has expired. Updating status.")
                session.status = "expired"
                session.last_error_code = "TOKEN_EXPIRED"
                return

        # 2. Pick provider adapter
        provider = self.mock_provider if "mock" in session.provider else self.blackbuck_provider

        try:
            token = decrypt_token(session.provider_token_encrypted)
            position = await provider.fetch_location(token)

            # Store new position
            bus_pos = BusPosition(
                session_id=session.id,
                latitude=position.latitude,
                longitude=position.longitude,
                observed_at=position.observed_at,
                received_at=now,
                accuracy_meters=position.accuracy_meters,
                speed_mps=position.speed_mps,
                heading_degrees=position.heading_degrees,
            )
            db.add(bus_pos)

            session.last_success_at = now
            session.last_error_code = None

            # Bounded retention: trim excess history > 100 rows
            await self._prune_old_positions(db, session.id, max_keep=100)

            # Invoke proximity evaluation callback if registered
            if self._position_callback:
                await self._position_callback(db, session, bus_pos)

        except Exception as exc:
            err = provider.normalize_error(exc)
            session.last_error_code = err.code
            logger.warning(f"Polling session {session.id} failed: {err.code} - {err.message}")

            if not err.is_recoverable:
                session.status = "expired" if "EXPIRED" in err.code else "provider_error"

    async def _prune_old_positions(self, db, session_id: str, max_keep: int = 100) -> None:
        """Retain only the latest max_keep positions per session."""
        stmt = (
            select(BusPosition.id)
            .where(BusPosition.session_id == session_id)
            .order_by(desc(BusPosition.observed_at))
            .offset(max_keep)
        )
        old_ids_res = await db.execute(stmt)
        old_ids = old_ids_res.scalars().all()
        if old_ids:
            from sqlalchemy import delete
            del_stmt = delete(BusPosition).where(BusPosition.id.in_(old_ids))
            await db.execute(del_stmt)
