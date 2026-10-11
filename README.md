# Bus Alarm

Bus Alarm monitors Blackbuck GPS share links for college buses and issues persistent Android alarm notifications when the bus approaches or crosses saved geofence stops.

---

## 1. Project Overview

Students waiting for daily buses often rely on fragile browser-based tracking links, constantly refreshing their screens to avoid missing stops. Bus Alarm solves this by:
- Ingesting a Blackbuck tracking URL once and extracting token expiry previews.
- Running a lightweight polling and proximity engine on FastAPI with point-to-segment crossing detection.
- Dispatching high-importance alarm notifications to Android devices via Firebase Cloud Messaging (FCM).
- Preserving user stops and link history locally in SQLite (offline-first).

---

## 2. Repository Layout

```
D:\Extras\Bus alarm\
├── docs/
│   ├── PRD.md                  # Product requirements and metrics
│   ├── TECHNICAL_SPEC.md       # Architectural and mathematical spec
│   ├── API.md                  # REST API contract
│   ├── DATA_MODEL.md           # PostgreSQL & SQLite schemas
│   ├── ANDROID_PERMISSIONS.md  # Android channels & OEM battery guide
│   └── CHECKLIST.md            # Implementation progress checklist
├── backend/
│   ├── app/
│   │   ├── main.py             # FastAPI entrypoint & lifespan
│   │   ├── core/               # Config, logging, security, auth
│   │   ├── api/v1/endpoints/   # Health, devices, sessions, geofences, alerts
│   │   ├── db/                 # Async SQLAlchemy engine & models
│   │   ├── schemas/            # Pydantic v2 validation models
│   │   ├── services/           # Geo distance, geofence engine, FCM dispatch
│   │   ├── providers/          # Blackbuck adapter & mock provider
│   │   └── workers/            # Cancellation-safe async poller
│   ├── alembic/                # Database migrations
│   ├── tests/                  # Unit and integration test suites
│   ├── Dockerfile              # Production container build
│   └── render.yaml             # Render deployment blueprint
├── mobile/
│   ├── lib/
│   │   ├── main.dart           # App entrypoint
│   │   ├── core/               # Theme, tokens, networking, notifications
│   │   ├── data/               # Local SQLite database & repositories
│   │   ├── features/           # Dashboard, links, geofences, alarm, settings
│   │   └── shared/             # Reusable UI widgets
│   ├── android/                # AndroidManifest with alarm permissions
│   └── pubspec.yaml            # Flutter project dependencies
└── scripts/
    ├── dev_backend.ps1         # Launch local backend server
    └── run_checks.ps1          # Execute test suites
```

---

## 3. Quickstart Guide

### 3.1 Backend Setup & Verification

1. Navigate to the backend directory:
   ```powershell
   cd "D:\Extras\Bus alarm\backend"
   ```

2. Install dependencies:
   ```powershell
   python -m pip install -r requirements.txt
   ```

3. Run migrations:
   ```powershell
   python -m alembic upgrade head
   ```

4. Run the full test suite (24 automated tests covering health, auth, provider contract, crossing math, geofences, and alerts):
   ```powershell
   python -m pytest -v
   ```

5. Launch the local development API server:
   ```powershell
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   API interactive documentation is available at `http://localhost:8000/docs`.

---

### 3.2 Mobile App Setup (Flutter)

1. Ensure the Flutter SDK is installed and added to PATH:
   ```powershell
   flutter doctor
   ```

2. Navigate to the mobile directory:
   ```powershell
   cd "D:\Extras\Bus alarm\mobile"
   ```

3. Fetch Flutter packages:
   ```powershell
   flutter pub get
   ```

4. Run on a connected Android device or emulator:
   ```powershell
   flutter run
   ```

---

## 4. Key Mathematical Algorithms

### 4.1 Point-to-Segment Crossing Detection
Checking only whether the latest GPS coordinate falls inside a geofence can miss a bus traveling at 60 km/h between discrete polling samples. Bus Alarm projects consecutive points $A$ and $B$ into a local metric Cartesian plane centered at the geofence and computes the minimum distance $d_{\min}$ from the center to segment $AB$:

$$t^* = \max\left(0, \min\left(1, \frac{-A_x(B_x - A_x) - A_y(B_y - A_y)}{(B_x - A_x)^2 + (B_y - A_y)^2}\right)\right)$$

$$P = A + t^* (B - A), \quad d_{\min} = \|P\|$$

If $d_{\min} \le \text{radius} + 20\text{m}$, a crossing candidate is triggered, ensuring reliable alerts even during high-speed transit.

### 4.2 Idempotent Alert Keys & Cooldown
Every alert event is assigned a deterministic hash key:
$$\text{event\_key} = \text{session\_id} : \text{geofence\_id} : \left\lfloor \frac{\text{epoch}}{\text{cooldown\_seconds}} \right\rfloor$$
This guarantees that retries and GPS jitter across boundary boundaries never trigger duplicate alarms for the same stop.

---

## 5. Deployment Guide (Render & Managed PostgreSQL)

1. Create a managed PostgreSQL database (e.g. Neon, Supabase, Railway).
2. Connect your Git repository to Render.
3. Use the included `backend/render.yaml` blueprint or configure a Web Service:
   - **Environment**: Python 3.11
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Health Check Path**: `/health/ready`
4. Set environment variables on Render:
   - `DATABASE_URL`: `postgresql+asyncpg://user:pass@host/dbname`
   - `DATABASE_SYNC_URL`: `postgresql://user:pass@host/dbname`
   - `SECRET_KEY`: Secure 32-character encryption key
   - `DEVICE_AUTH_ENABLED`: `true`
