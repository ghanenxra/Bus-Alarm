# Task Checklist — Bus Alarm MVP

## Step 0: Discovery Report & Setup
- [x] Extract specification and PRD from docx
- [x] Initialize Git repository and .gitignore
- [x] Create project docs: PRD.md, TECHNICAL_SPEC.md, API.md, DATA_MODEL.md, ANDROID_PERMISSIONS.md
- [ ] Inspect environment, Python, Flutter, Node, Docker
- [ ] Produce Step 0 Discovery Report with identified unknowns and blockers

## Step 1: Backend Skeleton
- [ ] Configure FastAPI project structure and pyproject.toml / requirements.txt
- [ ] Add settings via Pydantic BaseSettings, structured logging, request ID middleware
- [ ] Implement GET /health (liveness) and GET /health/ready (readiness)
- [ ] Configure SQLAlchemy 2.0 with PostgreSQL and SQLite fallback for local test
- [ ] Configure Alembic migrations and write initial schema migration
- [ ] Unit tests for health endpoints and configuration

## Step 2: Provider Contract
- [ ] Create BaseProvider interface and BlackbuckProvider implementation
- [ ] Implement URL parsing (allowlisted domain, HTTPS, token extraction)
- [ ] Implement JWT decode for expiry display estimation (untrusted client preview)
- [ ] Implement MockBlackbuckProvider with fixture data
- [ ] Unit tests for URL parser, expiry parsing, fixture response handling, error normalizer

## Step 3: Sessions and Polling
- [ ] Device registration endpoint (POST /api/v1/devices/register)
- [ ] Tracking session endpoints (create, get, activate, pause, get position)
- [ ] Async background poller with cancellation protection, backoff, and state updates
- [ ] Position storage with bounded history
- [ ] Unit tests for device registration, sessions, and polling loop

## Step 4: Geofence Engine
- [ ] Implement Haversine point-to-point distance in backend
- [ ] Implement point-to-segment crossing algorithm with local metric projection
- [ ] Implement cooldown and idempotency key generator
- [ ] Geofence CRUD endpoints (POST, GET, PATCH, DELETE /api/v1/geofences)
- [ ] Unit tests for distance, crossing between samples, duplicate suppression

## Step 5: Push Service
- [ ] FCM service integration with error handling and mock fallback for testing
- [ ] Alert event persistence before push dispatch
- [ ] Alert acknowledge endpoint (POST /api/v1/alerts/{id}/acknowledge)
- [ ] Test notification endpoint (POST /api/v1/devices/{id}/test-notification)
- [ ] Unit tests for alert flow and push dispatch

## Step 6: Flutter Foundation & Local Data
- [ ] Configure Flutter mobile app structure and pubspec.yaml
- [ ] Implement Material 3 tokenized theme, navigation routes, and Dio HTTP client
- [ ] Implement SQLite local database (saved_links, geofences, app_settings, alert_history)
- [ ] Unit / widget tests for local repositories

## Step 7: Link and Geofence Screens
- [ ] Add/Edit link screen with clipboard paste, validation, expiry preview
- [ ] Link history screen (list, rename, activate, delete)
- [ ] Add/Edit geofence screen (map/manual coordinates, radius slider, trigger mode)
- [ ] Geofence list screen with enable/disable toggle
- [ ] Tests for screen states and form validation

## Step 8: Dashboard and Backend Wake-Up
- [ ] Dashboard screen (backend status badge, tracking state, bus coordinates, nearest stop)
- [ ] Wake backend flow with progress timer and exponential backoff retry
- [ ] Stale data warning indicator when last poll age exceeds threshold
- [ ] Tests for dashboard states

## Step 9: Android Alarm Behavior
- [ ] Alarm full-screen UI with high-contrast layout, Dismiss and Snooze actions
- [ ] Notification service integration (FCM background/foreground handler)
- [ ] Permission education and settings screen
- [ ] Diagnostics screen with redacted logs and copy action

## Step 10: Deployment Hardening & Documentation
- [ ] Dockerfile for FastAPI backend
- [ ] render.yaml blueprint configuration
- [ ] README.md with complete setup and deployment instructions
- [ ] Verified test suite and checklist review
