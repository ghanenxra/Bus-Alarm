from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class AlertAcknowledgeRequest(BaseModel):
    action: str = Field(..., pattern="^(dismiss|snooze)$", description="User action: dismiss or snooze")
    snooze_seconds: int = Field(default=0, ge=0, le=3600)


class AlertAcknowledgeResponse(BaseModel):
    alert_id: str
    status: str
    action: str
    acknowledged_at: datetime


class AlertEventResponse(BaseModel):
    id: str
    device_id: str
    session_id: str
    geofence_id: str
    event_key: str
    event_type: str
    distance_meters: Optional[float] = None
    occurred_at: datetime
    push_status: str
    push_attempts: int
    acknowledged_at: Optional[datetime] = None
    user_action: Optional[str] = None
    created_at: datetime


class TestNotificationResponse(BaseModel):
    success: bool
    message: str
