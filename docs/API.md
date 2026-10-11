# REST API Specification — Bus Alarm

Base Path: `/api/v1`  
All timestamps are UTC in ISO-8601 (`YYYY-MM-DDTHH:MM:SSZ`).  
Content-Type: `application/json`

---

## 1. System & Health

### GET `/health`
Liveness probe.
- Response: `200 OK`
```json
{
  "status": "ok",
  "version": "1.0.0",
  "service": "bus-alarm-backend"
}
```

### GET `/health/ready`
Readiness probe including database check.
- Response: `200 OK` (or `503 Service Unavailable` if database check fails)
```json
{
  "status": "ready",
  "database": "connected",
  "timestamp": "2026-10-11T08:00:00Z"
}
```

### GET `/api/v1/status`
Comprehensive operational status.
- Response: `200 OK`
```json
{
  "backend_status": "online",
  "poller_running": true,
  "active_sessions_count": 1,
  "timestamp": "2026-10-11T08:00:00Z"
}
```

---

## 2. Devices

### POST `/api/v1/devices/register`
Register mobile installation.
- Headers:
  - `X-Device-Secret`: `<client-generated-secret>`
- Request Body:
```json
{
  "installation_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "fcm_token": "fcm_token_string_here",
  "platform": "android",
  "app_version": "1.0.0"
}
```
- Response: `201 Created`
```json
{
  "device_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "registered": true,
  "created_at": "2026-10-11T08:00:00Z"
}
```

### PUT `/api/v1/devices/{device_id}/fcm-token`
Update FCM registration token.
- Headers:
  - `X-Device-Secret`: `<secret>`
- Request Body:
```json
{
  "fcm_token": "new_fcm_token_string"
}
```
- Response: `200 OK`
```json
{
  "updated": true
}
```

### POST `/api/v1/devices/{device_id}/test-notification`
Trigger a test push notification.
- Headers:
  - `X-Device-Secret`: `<secret>`
- Response: `200 OK`
```json
{
  "success": true,
  "message": "Test notification queued"
}
```

---

## 3. Tracking Sessions

### POST `/api/v1/tracking-sessions`
Create and validate a new tracking session.
- Headers:
  - `X-Device-Secret`: `<secret>`
- Request Body:
```json
{
  "device_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "nickname": "Morning College Bus",
  "share_url": "https://trackgps.blackbuck.com/location?token=ey...",
  "poll_interval_seconds": 10
}
```
- Response: `201 Created`
```json
{
  "session_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "device_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "nickname": "Morning College Bus",
  "status": "active",
  "expires_at": "2026-10-12T08:00:00Z",
  "poll_interval_seconds": 10,
  "created_at": "2026-10-11T08:00:00Z"
}
```

### GET `/api/v1/tracking-sessions`
List tracking sessions for device.
- Query Parameters: `device_id`
- Response: `200 OK`
```json
[
  {
    "session_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "nickname": "Morning College Bus",
    "status": "active",
    "expires_at": "2026-10-12T08:00:00Z",
    "last_polled_at": "2026-10-11T08:05:00Z"
  }
]
```

### POST `/api/v1/tracking-sessions/{session_id}/activate`
Activate tracking session.
- Response: `200 OK`
```json
{
  "session_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "status": "active"
}
```

### POST `/api/v1/tracking-sessions/{session_id}/pause`
Pause tracking session.
- Response: `200 OK`
```json
{
  "session_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "status": "paused"
}
```

### GET `/api/v1/tracking-sessions/{session_id}/position`
Retrieve latest bus position.
- Response: `200 OK`
```json
{
  "session_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "latitude": 25.1834,
  "longitude": 75.8321,
  "observed_at": "2026-10-11T08:05:12Z",
  "speed_mps": 11.2,
  "heading_degrees": 182.0,
  "freshness_seconds": 4
}
```

---

## 4. Geofences

### GET `/api/v1/geofences?device_id=...`
List geofences for device.

### POST `/api/v1/geofences`
Create a new geofence.
- Request Body:
```json
{
  "device_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "session_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "name": "Hostel Gate Stop",
  "latitude": 25.185,
  "longitude": 75.835,
  "radius_meters": 200,
  "enabled": true,
  "trigger_mode": "crossing",
  "cooldown_seconds": 900
}
```
- Response: `201 Created`

### PATCH `/api/v1/geofences/{geofence_id}`
Update geofence configuration.

### DELETE `/api/v1/geofences/{geofence_id}`
Delete geofence.

---

## 5. Alerts

### GET `/api/v1/alerts?device_id=...&limit=50`
List recent alert records.

### POST `/api/v1/alerts/{alert_id}/acknowledge`
Acknowledge or snooze alert.
- Request Body:
```json
{
  "action": "dismiss",
  "snooze_seconds": 0
}
```
- Response: `200 OK`
```json
{
  "alert_id": "...",
  "status": "acknowledged"
}
```

---

## 6. Error Response Schema

Standard format for all HTTP error responses:
```json
{
  "error": {
    "code": "PROVIDER_RATE_LIMITED",
    "message": "The location provider is temporarily rate-limiting requests.",
    "request_id": "req-987654"
  }
}
```
Common codes:
- `BAD_REQUEST` (400)
- `UNAUTHORIZED` (401)
- `FORBIDDEN` (403)
- `NOT_FOUND` (404)
- `CONFLICT` (409)
- `VALIDATION_ERROR` (422)
- `RATE_LIMITED` (429)
- `PROVIDER_ERROR` (502)
- `SERVICE_UNAVAILABLE` (503)
