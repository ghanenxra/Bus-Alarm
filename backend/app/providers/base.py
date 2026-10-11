from abc import ABC, abstractmethod
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class ShareToken(BaseModel):
    token: str
    host: str
    raw_url: str
    estimated_expires_at: Optional[datetime] = None


class ProviderValidationResult(BaseModel):
    is_valid: bool
    status_code: int
    message: str
    expires_at: Optional[datetime] = None
    initial_position: Optional["ProviderBusPosition"] = None


class ProviderBusPosition(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    observed_at: datetime
    accuracy_meters: Optional[float] = None
    speed_mps: Optional[float] = None
    heading_degrees: Optional[float] = None
    is_live: bool = True


class ProviderError(BaseModel):
    code: str
    message: str
    retry_after_seconds: Optional[int] = None
    is_recoverable: bool = True


class BaseProvider(ABC):
    """Abstract interface isolating all location provider details."""

    @abstractmethod
    def parse_share_url(self, url: str) -> ShareToken:
        """Parse and validate tracking URL structure and extract token."""
        pass

    @abstractmethod
    def get_token_expiry(self, token: str) -> Optional[datetime]:
        """Estimate token expiry from token metadata/JWT claims."""
        pass

    @abstractmethod
    async def validate_share(self, token: str) -> ProviderValidationResult:
        """Validate live share viability against provider service."""
        pass

    @abstractmethod
    async def fetch_location(self, token: str) -> ProviderBusPosition:
        """Fetch latest verified vehicle position from provider."""
        pass

    @abstractmethod
    def normalize_error(self, exc: Exception) -> ProviderError:
        """Map provider-specific HTTP/JSON exceptions into standardized ProviderError."""
        pass
