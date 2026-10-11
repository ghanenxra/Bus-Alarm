from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.db.session import get_db
from app.db.models.tracking_session import TrackingSession
from app.schemas.health import HealthResponse, ReadinessResponse, SystemStatusResponse

router = APIRouter(tags=["Health & Status"])


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Fast liveness check probe for Render."""
    return HealthResponse(
        status="ok",
        version=settings.APP_VERSION,
        service=settings.APP_NAME,
    )


@router.get("/health/ready", response_model=ReadinessResponse)
async def readiness_check(db: AsyncSession = Depends(get_db)) -> ReadinessResponse:
    """Readiness probe that checks database connectivity."""
    try:
        await db.execute(text("SELECT 1"))
        return ReadinessResponse(
            status="ready",
            database="connected",
            timestamp=datetime.now(timezone.utc),
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Database connectivity check failed: {str(exc)}",
        )


@router.get("/api/v1/status", response_model=SystemStatusResponse)
async def system_status(db: AsyncSession = Depends(get_db)) -> SystemStatusResponse:
    """Detailed operational status including active tracking sessions."""
    try:
        query = select(TrackingSession).where(TrackingSession.status == "active")
        result = await db.execute(query)
        active_count = len(result.scalars().all())
    except Exception:
        active_count = 0

    return SystemStatusResponse(
        backend_status="online",
        poller_running=True,
        active_sessions_count=active_count,
        timestamp=datetime.now(timezone.utc),
    )
