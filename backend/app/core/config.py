from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    APP_NAME: str = "Bus Alarm API"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    API_V1_PREFIX: str = "/api/v1"

    # Database
    DATABASE_URL: str = Field(
        default="sqlite+aiosqlite:///./bus_alarm.db",
        description="Async PostgreSQL or SQLite connection string"
    )
    DATABASE_SYNC_URL: Optional[str] = Field(
        default="sqlite:///./bus_alarm.db",
        description="Sync connection string for Alembic migrations"
    )

    # Security & Encryption
    SECRET_KEY: str = Field(
        default="insecure-dev-secret-key-change-in-production-min32chars",
        description="Master secret key for token encryption"
    )
    DEVICE_AUTH_ENABLED: bool = True

    # Polling defaults
    DEFAULT_POLL_INTERVAL_SECONDS: int = 10
    MIN_POLL_INTERVAL_SECONDS: int = 5
    MAX_POLL_INTERVAL_SECONDS: int = 60
    POLLER_TIMEOUT_SECONDS: float = 8.0

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    # Provider allowlist
    ALLOWED_PROVIDER_HOSTS: List[str] = [
        "trackgps.blackbuck.com",
        "gps.blackbuck.com",
        "mock.busalarm.local"
    ]

    # FCM Configuration
    FCM_ENABLED: bool = False
    FIREBASE_CREDENTIALS_PATH: Optional[str] = None


settings = Settings()
