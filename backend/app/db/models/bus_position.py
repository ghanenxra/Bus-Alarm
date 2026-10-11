from datetime import datetime
from typing import Optional
from sqlalchemy import DateTime, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.session import Base
from app.db.models.base import utc_now


class BusPosition(Base):
    __tablename__ = "bus_positions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )
    session_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("tracking_sessions.id", ondelete="CASCADE"),
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
    observed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )
    accuracy_meters: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )
    speed_mps: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )
    heading_degrees: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )

    # Relationship
    session: Mapped["TrackingSession"] = relationship(
        "TrackingSession",
        back_populates="bus_positions",
    )

    __table_args__ = (
        Index("ix_bus_positions_session_observed", "session_id", "observed_at"),
    )
