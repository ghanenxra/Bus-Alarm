# Technical Specification — Bus Alarm

Version: 1.0  
Date: 11 October 2026  
Status: In Progress

---

## 1. System Architecture

Bus Alarm follows an event-driven, decoupled client-server architecture:

```
[Blackbuck Web Tracking Feed]
          ^
          | (HTTP Polling via Provider Adapter)
[FastAPI Backend on Render]
   |                      |
   +--> [Managed Postgres] (State, Sessions, Geofences, Alerts)
   |
   +--> [Firebase Cloud Messaging]
             |
             v (High Priority Push)
[Android Flutter App] <---> [Local SQLite (sqflite)]
```

### Components:
1. **Flutter Mobile Client (Android)**:
   - UI: Material 3, Riverpod state management.
   - Networking: Dio HTTP client with request timeouts and token handling.
   - Storage: SQLite (`sqflite`) for offline-first local link history, user preferences, and cached stops.
   - Notification & Alarm: `flutter_local_notifications` + native Android Foreground/Alarm intents where required.
   - Map: `flutter_map` with OpenStreetMap raster tiles (no paid API key required).
2. **FastAPI Backend Service**:
   - Web framework: FastAPI + Pydantic v2.
   - ORM: SQLAlchemy 2.0 with async engine support + Alembic migrations.
   - Persistence: Managed external PostgreSQL (Neon, Supabase, or Railway). Render ephemeral filesystem is strictly avoided for state.
   - HTTP Provider Client: HTTPX with connection pooling, timeouts, and exponential backoff.
   - Polling Engine: Async background worker poller with cancellation protection, per-session state tracking, and rate limits.
   - Notification Dispatcher: FCM Admin SDK or HTTP v1 API.

---

## 2. Mathematical Algorithms

### 2.1 Point-to-Point Distance (Haversine Formula)
Given two coordinate pairs $(\phi_1, \lambda_1)$ and $(\phi_2, \lambda_2)$ in radians and Earth radius $R = 6,371,000$ meters:

$$\Delta\phi = \phi_2 - \phi_1$$
$$\Delta\lambda = \lambda_2 - \lambda_1$$
$$a = \sin^2\left(\frac{\Delta\phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta\lambda}{2}\right)$$
$$c = 2 \cdot \operatorname{atan2}\left(\sqrt{a}, \sqrt{1-a}\right)$$
$$d = R \cdot c$$

### 2.2 Segment-to-Point Crossing Detection
Polling intervals (e.g. 10s) mean a fast bus traveling at 60 km/h (16.6 m/s) covers ~166 meters between points. A small geofence (e.g. 150m radius) might have both sample $A$ and sample $B$ outside the circle, while the trajectory segment between $A$ and $B$ intersects the geofence.

To detect crossing between consecutive points $A(lat_A, lon_A)$ and $B(lat_B, lon_B)$ relative to geofence center $C(lat_C, lon_C)$:
1. Project $A$, $B$, and $C$ into an Equirectangular or UTM local planar Cartesian space centered at $C$:
   $$x = R \cdot (\lambda - \lambda_C) \cdot \cos(\phi_C)$$
   $$y = R \cdot (\phi - \phi_C)$$
2. In this local metric frame, $C = (0, 0)$.
3. Let segment vector $\vec{v} = B - A$ and vector $\vec{u} = C - A = -A$.
4. Calculate scalar projection parameter $t$:
   $$t = \frac{\vec{u} \cdot \vec{v}}{\|\vec{v}\|^2} = \frac{-A_x(B_x - A_x) - A_y(B_y - A_y)}{(B_x - A_x)^2 + (B_y - A_y)^2}$$
5. Clamp $t$ to the segment interval $[0, 1]$:
   $$t^* = \max(0, \min(1, t))$$
6. Compute the closest point on segment: $P = A + t^* \vec{v}$.
7. Calculate the minimum distance: $d_{min} = \|P - C\| = \sqrt{P_x^2 + P_y^2}$.
8. A crossing event is triggered if:
   $$d_{min} \le \text{radius} + \text{GPS\_uncertainty\_margin}$$
   provided the bus was previously outside the geofence and the event is outside the cooldown window.

---

## 3. Cooldown & Idempotency Strategy

To prevent repeated alarms if a bus stops inside a geofence or GPS jitters across the boundary:
1. **Event Key Generation**:
   $$\text{event\_key} = \operatorname{hash}(\text{session\_id} + \text{geofence\_id} + \text{episode\_bucket})$$
   where `episode_bucket` represents an epoch divided by `cooldown_seconds` (default 900 seconds).
2. **State Gate**:
   - `last_triggered_at` is persisted on the `geofences` record.
   - An alert event is only written if `now - last_triggered_at > cooldown_seconds`.
   - The event is committed to PostgreSQL before triggering FCM push to guarantee exactly-once persistence.

---

## 4. Blackbuck Provider Adapter Design

The provider integration is isolated in `backend/app/providers/blackbuck.py`:
- Interface: `BlackbuckProvider(BaseProvider)`
  - `parse_share_url(url: str) -> ShareToken`
  - `get_token_expiry(token: str) -> Optional[datetime]`
  - `validate_share(token: str) -> ProviderValidationResult`
  - `fetch_location(token: str) -> BusPosition`
  - `normalize_error(exc: Exception) -> ProviderError`
- Testing: Mock fixtures and simulation mode (`MockBlackbuckProvider`) will be used to simulate bus routes and transit events deterministically during automated testing.
- Security: Raw tokens are redacted in all logs.

---

## 5. Deployment Architecture (Render + Postgres)

- **Web Service**: Render Web Service running Uvicorn (`uvicorn app.main:app --host 0.0.0.0 --port $PORT`).
- **Health Checks**:
  - `GET /health`: Liveness probe (immediate 200).
  - `GET /health/ready`: Readiness probe (verifies database query execution).
- **Polling Loop**: Cancellation-safe background task running inside FastAPI lifespan, polling active sessions at configured intervals.
