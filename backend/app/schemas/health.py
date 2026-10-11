from datetime import datetime
from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = Field(default="ok", examples=["ok"])
    version: str = Field(default="1.0.0", examples=["1.0.0"])
    service: str = Field(default="bus-alarm-backend", examples=["bus-alarm-backend"])


class ReadinessResponse(BaseModel):
    status: str = Field(default="ready", examples=["ready"])
    database: str = Field(default="connected", examples=["connected"])
    timestamp: datetime


class SystemStatusResponse(BaseModel):
    backend_status: str = Field(default="online", examples=["online"])
    poller_running: bool = Field(default=False)
    active_sessions_count: int = Field(default=0)
    timestamp: datetime
