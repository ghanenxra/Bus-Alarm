from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class DeviceRegisterRequest(BaseModel):
    installation_id: str = Field(..., description="Unique client installation UUID")
    fcm_token: Optional[str] = Field(default=None, description="Firebase Cloud Messaging device token")
    platform: str = Field(default="android", description="Client platform")
    app_version: Optional[str] = Field(default="1.0.0", description="App release version")


class DeviceRegisterResponse(BaseModel):
    device_id: str
    registered: bool = True
    created_at: datetime


class FCMTokenUpdateRequest(BaseModel):
    fcm_token: str = Field(..., min_length=1)


class FCMTokenUpdateResponse(BaseModel):
    updated: bool = True
