from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from app.schemas.bus_position import BusPositionResponse


class TrackingSessionCreate(BaseModel):
    device_id: str
    nickname: str = Field(..., min_length=1, max_length=128)
    share_url: str = Field(..., min_length=10)
    poll_interval_seconds: int = Field(default=10, ge=5, le=60)


class TrackingSessionResponse(BaseModel):
    id: str
    device_id: str
    nickname: str
    provider: str
    status: str
    expires_at: Optional[datetime] = None
    poll_interval_seconds: int
    last_polled_at: Optional[datetime] = None
    last_success_at: Optional[datetime] = None
    last_error_code: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    last_position: Optional[BusPositionResponse] = None


class TrackingSessionStateChangeResponse(BaseModel):
    session_id: str
    status: str
    message: str

