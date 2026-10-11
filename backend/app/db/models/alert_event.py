import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import DateTime, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.db.models.base import utc_now


class AlertEvent(Base):
    __tablename__ = "alert_events"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    device_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("devices.id", ondelete="CASCADE"),
        nullable=False,
    )
    session_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("tracking_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    geofence_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("geofences.id", ondelete="CASCADE"),
        nullable=False,
    )
    event_key: Mapped[str] = mapped_column(
        String(128),
        unique=True,
        index=True,
        nullable=False,
    )
    event_type: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
    )
    distance_meters: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    push_status: Mapped[str] = mapped_column(
        String(32),
        default="queued",
        nullable=False,
    )
    push_attempts: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    acknowledged_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    user_action: Mapped[Optional[str]] = mapped_column(
        String(32),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    # Relationships
    device: Mapped["Device"] = relationship(
        "Device",
        back_populates="alert_events",
    )
    session: Mapped["TrackingSession"] = relationship(
        "TrackingSession",
        back_populates="alert_events",
    )
    geofence: Mapped["Geofence"] = relationship(
        "Geofence",
        back_populates="alert_events",
    )

    __table_args__ = (
        Index("ix_alert_events_device_occurred", "device_id", "occurred_at"),
    )
