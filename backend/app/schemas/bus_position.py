from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class BusPositionResponse(BaseModel):
    session_id: str
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    observed_at: datetime
    received_at: datetime
    accuracy_meters: Optional[float] = None
    speed_mps: Optional[float] = None
    heading_degrees: Optional[float] = None
    freshness_seconds: int = Field(default=0, description="Seconds elapsed since observed_at")
