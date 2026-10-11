from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class GeofenceCreate(BaseModel):
    device_id: str
    session_id: str
    name: str = Field(..., min_length=1, max_length=128)
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    radius_meters: int = Field(default=200, ge=30, le=2000)
    enabled: bool = Field(default=True)
    trigger_mode: str = Field(default="crossing")
    cooldown_seconds: int = Field(default=900, ge=60, le=86400)


class GeofenceUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=128)
    latitude: Optional[float] = Field(default=None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(default=None, ge=-180.0, le=180.0)
    radius_meters: Optional[int] = Field(default=None, ge=30, le=2000)
    enabled: Optional[bool] = None
    trigger_mode: Optional[str] = None
    cooldown_seconds: Optional[int] = Field(default=None, ge=60, le=86400)


class GeofenceResponse(BaseModel):
    id: str
    device_id: str
    session_id: str
    name: str
    latitude: float
    longitude: float
    radius_meters: int
    enabled: bool
    trigger_mode: str
    cooldown_seconds: int
    last_triggered_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

