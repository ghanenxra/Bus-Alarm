# Task Checklist — Bus Alarm MVP

## Step 0: Discovery Report & Setup
- [x] Extract specification and PRD from docx
- [x] Initialize Git repository and .gitignore
- [x] Create project docs: PRD.md, TECHNICAL_SPEC.md, API.md, DATA_MODEL.md, ANDROID_PERMISSIONS.md
- [x] Inspect environment, Python, Flutter, Node, Docker
- [x] Produce Step 0 Discovery Report with identified unknowns and blockers

## Step 1: Backend Skeleton
- [x] Configure FastAPI project structure and pyproject.toml / requirements.txt
- [x] Add settings via Pydantic BaseSettings, structured logging, request ID middleware
- [x] Implement GET /health (liveness) and GET /health/ready (readiness)
- [x] Configure SQLAlchemy 2.0 with PostgreSQL and SQLite fallback for local test
- [x] Configure Alembic migrations and write initial schema migration
- [x] Unit tests for health endpoints and configuration

## Step 2: Provider Contract
- [x] Create BaseProvider interface and BlackbuckProvider implementation
- [x] Implement URL parsing (allowlisted domain, HTTPS, token extraction)
- [x] Implement JWT decode for expiry display estimation (untrusted client preview)
- [x] Implement MockBlackbuckProvider with fixture data
- [x] Unit tests for URL parser, expiry parsing, fixture response handling, error normalizer

## Step 3: Sessions and Polling
- [x] Device registration endpoint (POST /api/v1/devices/register)
- [x] Tracking session endpoints (create, get, activate, pause, get position)
- [x] Async background poller with cancellation protection, backoff, and state updates
- [x] Position storage with bounded history
- [x] Unit tests for device registration, sessions, and polling loop

## Step 4: Geofence Engine
- [x] Implement Haversine point-to-point distance in backend
- [x] Implement point-to-segment crossing algorithm with local metric projection
- [x] Implement cooldown and idempotency key generator
- [x] Geofence CRUD endpoints (POST, GET, PATCH, DELETE /api/v1/geofences)
- [x] Unit tests for distance, crossing between samples, duplicate suppression

## Step 5: Push Service
- [x] FCM service integration with error handling and mock fallback for testing
- [x] Alert event persistence before push dispatch
- [x] Alert acknowledge endpoint (POST /api/v1/alerts/{id}/acknowledge)
- [x] Test notification endpoint (POST /api/v1/devices/{id}/test-notification)
- [x] Unit tests for alert flow and push dispatch

## Step 6: Flutter Foundation & Local Data
- [x] Configure Flutter mobile app structure and pubspec.yaml
- [x] Implement Material 3 tokenized theme, navigation routes, and Dio HTTP client
- [x] Implement SQLite local database (saved_links, geofences, app_settings, alert_history)
- [x] Repository implementations for links and geofences

## Step 7: Link and Geofence Screens
- [x] Add/Edit link screen with clipboard paste, validation, expiry preview
- [x] Link history screen (list, rename, activate, delete)
- [x] Add/Edit geofence screen (map/manual coordinates, radius slider, trigger mode)
- [x] Geofence list screen with enable/disable toggle

## Step 8: Dashboard and Backend Wake-Up
- [x] Dashboard screen (backend status badge, tracking state, bus coordinates, nearest stop)
- [x] Wake backend flow with progress timer and exponential backoff retry
- [x] Stale data warning indicator when last poll age exceeds threshold

## Step 9: Android Alarm Behavior
- [x] Alarm full-screen UI with high-contrast layout, Dismiss and Snooze actions
- [x] Notification service integration (local notifications, channels, alarms)
- [x] Permission education and settings screen
- [x] Diagnostics screen with redacted logs and copy action

## Step 10: Deployment Hardening & Documentation
- [x] Dockerfile for FastAPI backend
- [x] render.yaml blueprint configuration
- [x] Root README.md with complete setup and deployment instructions
- [x] Verified test suite passing (24 tests, 100% pass)
