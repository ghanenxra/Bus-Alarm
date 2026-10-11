import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.db.models.base import utc_now


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    installation_id: Mapped[str] = mapped_column(
        String(36),
        unique=True,
        index=True,
        nullable=False,
    )
    credential_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    platform: Mapped[str] = mapped_column(
        String(32),
        default="android",
        nullable=False,
    )
    app_version: Mapped[Optional[str]] = mapped_column(
        String(32),
        nullable=True,
    )
    fcm_token_encrypted: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    # Relationships
    tracking_sessions: Mapped[List["TrackingSession"]] = relationship(
        "TrackingSession",
        back_populates="device",
        cascade="all, delete-orphan",
    )
    geofences: Mapped[List["Geofence"]] = relationship(
        "Geofence",
        back_populates="device",
        cascade="all, delete-orphan",
    )
    alert_events: Mapped[List["AlertEvent"]] = relationship(
        "AlertEvent",
        back_populates="device",
        cascade="all, delete-orphan",
    )

