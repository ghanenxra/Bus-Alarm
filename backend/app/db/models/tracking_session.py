import uuid
from datetime import datetime
from typing import List, Optional
from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.db.models.base import TimestampMixin


class TrackingSession(Base, TimestampMixin):
    __tablename__ = "tracking_sessions"

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
    nickname: Mapped[str] = mapped_column(
        String(128),
        nullable=False,
    )
    provider: Mapped[str] = mapped_column(
        String(64),
        default="blackbuck",
        nullable=False,
    )
    provider_token_encrypted: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        default="active",
        nullable=False,
    )
    poll_interval_seconds: Mapped[int] = mapped_column(
        Integer,
        default=10,
        nullable=False,
    )
    last_polled_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_success_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_error_code: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
    )

    # Relationships
    device: Mapped["Device"] = relationship(
        "Device",
        back_populates="tracking_sessions",
    )
    geofences: Mapped[List["Geofence"]] = relationship(
        "Geofence",
        back_populates="session",
        cascade="all, delete-orphan",
    )
    bus_positions: Mapped[List["BusPosition"]] = relationship(
        "BusPosition",
        back_populates="session",
        cascade="all, delete-orphan",
    )
    alert_events: Mapped[List["AlertEvent"]] = relationship(
        "AlertEvent",
        back_populates="session",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("ix_tracking_sessions_device_status", "device_id", "status"),
    )
