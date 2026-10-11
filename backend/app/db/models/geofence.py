import uuid
from datetime import datetime
from typing import List, Optional
from sqlalchemy import Boolean, CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.db.models.base import TimestampMixin


class Geofence(Base, TimestampMixin):
    __tablename__ = "geofences"

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
    name: Mapped[str] = mapped_column(
        String(128),
        nullable=False,
    )
    latitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )
    longitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )
    radius_meters: Mapped[int] = mapped_column(
        Integer,
        default=200,
        nullable=False,
    )
    enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    trigger_mode: Mapped[str] = mapped_column(
        String(32),
        default="crossing",
        nullable=False,
    )
    cooldown_seconds: Mapped[int] = mapped_column(
        Integer,
        default=900,
        nullable=False,
    )
    last_triggered_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    device: Mapped["Device"] = relationship(
        "Device",
        back_populates="geofences",
    )
    session: Mapped["TrackingSession"] = relationship(
        "TrackingSession",
        back_populates="geofences",
    )
    alert_events: Mapped[List["AlertEvent"]] = relationship(
        "AlertEvent",
        back_populates="geofence",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        CheckConstraint("latitude >= -90.0 AND latitude <= 90.0", name="chk_geofence_latitude"),
        CheckConstraint("longitude >= -180.0 AND longitude <= 180.0", name="chk_geofence_longitude"),
        CheckConstraint("radius_meters >= 30 AND radius_meters <= 2000", name="chk_geofence_radius"),
        Index("ix_geofences_session_enabled", "session_id", "enabled"),
    )

