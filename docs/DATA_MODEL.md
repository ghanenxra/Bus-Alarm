# Data Model Specification — Bus Alarm

Version: 1.0  
Date: 11 October 2026

---

## 1. Backend PostgreSQL Schema (Alembic Managed)

### 1.1 `devices`
Represents an installed instance of the mobile app.
- `id` (UUID, Primary Key, default `gen_random_uuid()`)
- `installation_id` (UUID, Unique, Indexed, Not Null)
- `credential_hash` (VARCHAR(255), Not Null) - SHA-256 hash of device secret
- `platform` (VARCHAR(32), Default `'android'`, Not Null)
- `app_version` (VARCHAR(32), Nullable)
- `fcm_token_encrypted` (TEXT, Nullable)
- `created_at` (TIMESTAMPTZ, Default `now()`, Not Null)
- `last_seen_at` (TIMESTAMPTZ, Nullable)
- `is_active` (BOOLEAN, Default `TRUE`, Not Null)

### 1.2 `tracking_sessions`
Represents an ingested Blackbuck tracking link.
- `id` (UUID, Primary Key, default `gen_random_uuid()`)
- `device_id` (UUID, Foreign Key `devices(id)` ON DELETE CASCADE, Not Null)
- `nickname` (VARCHAR(128), Not Null)
- `provider` (VARCHAR(64), Default `'blackbuck'`, Not Null)
- `provider_token_encrypted` (TEXT, Not Null)
- `expires_at` (TIMESTAMPTZ, Nullable)
- `status` (VARCHAR(32), Default `'active'`, Not Null) - `active`, `paused`, `expired`, `invalid`, `provider_error`
- `poll_interval_seconds` (INTEGER, Default 10, Not Null)
- `last_polled_at` (TIMESTAMPTZ, Nullable)
- `last_success_at` (TIMESTAMPTZ, Nullable)
- `last_error_code` (VARCHAR(64), Nullable)
- `created_at` (TIMESTAMPTZ, Default `now()`, Not Null)
- `updated_at` (TIMESTAMPTZ, Default `now()`, Not Null)
- *Indexes*: `(device_id, status)`

### 1.3 `geofences`
Geographic circular boundary tied to a tracking session.
- `id` (UUID, Primary Key, default `gen_random_uuid()`)
- `device_id` (UUID, Foreign Key `devices(id)` ON DELETE CASCADE, Not Null)
- `session_id` (UUID, Foreign Key `tracking_sessions(id)` ON DELETE CASCADE, Not Null)
- `name` (VARCHAR(128), Not Null)
- `latitude` (DOUBLE PRECISION, Not Null) - Constraint: `-90 <= latitude <= 90`
- `longitude` (DOUBLE PRECISION, Not Null) - Constraint: `-180 <= longitude <= 180`
- `radius_meters` (INTEGER, Default 200, Not Null) - Constraint: `30 <= radius_meters <= 2000`
- `enabled` (BOOLEAN, Default `TRUE`, Not Null)
- `trigger_mode` (VARCHAR(32), Default `'crossing'`, Not Null) - `'crossing'`, `'approaching'`
- `cooldown_seconds` (INTEGER, Default 900, Not Null)
- `last_triggered_at` (TIMESTAMPTZ, Nullable)
- `created_at` (TIMESTAMPTZ, Default `now()`, Not Null)
- `updated_at` (TIMESTAMPTZ, Default `now()`, Not Null)
- *Indexes*: `(session_id, enabled)`

### 1.4 `bus_positions`
Historical location stream recorded for an active session (bounded retention).
- `id` (BIGSERIAL, Primary Key)
- `session_id` (UUID, Foreign Key `tracking_sessions(id)` ON DELETE CASCADE, Not Null)
- `latitude` (DOUBLE PRECISION, Not Null)
- `longitude` (DOUBLE PRECISION, Not Null)
- `observed_at` (TIMESTAMPTZ, Not Null)
- `received_at` (TIMESTAMPTZ, Default `now()`, Not Null)
- `accuracy_meters` (DOUBLE PRECISION, Nullable)
- `speed_mps` (DOUBLE PRECISION, Nullable)
- `heading_degrees` (DOUBLE PRECISION, Nullable)
- *Indexes*: `(session_id, observed_at DESC)`

### 1.5 `alert_events`
Audit log and idempotency tracking of fired alerts.
- `id` (UUID, Primary Key, default `gen_random_uuid()`)
- `device_id` (UUID, Foreign Key `devices(id)` ON DELETE CASCADE, Not Null)
- `session_id` (UUID, Foreign Key `tracking_sessions(id)` ON DELETE CASCADE, Not Null)
- `geofence_id` (UUID, Foreign Key `geofences(id)` ON DELETE CASCADE, Not Null)
- `event_key` (VARCHAR(128), Unique, Not Null)
- `event_type` (VARCHAR(32), Not Null) - `'crossing'`, `'approaching'`
- `distance_meters` (DOUBLE PRECISION, Nullable)
- `occurred_at` (TIMESTAMPTZ, Not Null)
- `push_status` (VARCHAR(32), Default `'queued'`, Not Null) - `'queued'`, `'sent'`, `'failed'`
- `push_attempts` (INTEGER, Default 0, Not Null)
- `acknowledged_at` (TIMESTAMPTZ, Nullable)
- `user_action` (VARCHAR(32), Nullable) - `'dismiss'`, `'snooze'`
- `created_at` (TIMESTAMPTZ, Default `now()`, Not Null)
- *Indexes*: `(device_id, occurred_at DESC)`

---

## 2. Mobile SQLite Schema (sqflite)

### 2.1 `saved_links`
- `id` TEXT PRIMARY KEY
- `nickname` TEXT NOT NULL
- `share_url_encrypted` TEXT NOT NULL
- `token_expiry_utc` TEXT NULL
- `added_at_utc` TEXT NOT NULL
- `updated_at_utc` TEXT NOT NULL
- `is_favorite` INTEGER NOT NULL DEFAULT 0
- `last_known_status` TEXT NOT NULL DEFAULT 'unknown'
- `last_activated_at_utc` TEXT NULL

### 2.2 `geofences`
- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL
- `latitude` REAL NOT NULL
- `longitude` REAL NOT NULL
- `radius_meters` INTEGER NOT NULL DEFAULT 200
- `linked_saved_link_id` TEXT NOT NULL REFERENCES saved_links(id) ON DELETE CASCADE
- `enabled` INTEGER NOT NULL DEFAULT 1
- `trigger_mode` TEXT NOT NULL DEFAULT 'crossing'
- `cooldown_seconds` INTEGER NOT NULL DEFAULT 900
- `created_at_utc` TEXT NOT NULL
- `updated_at_utc` TEXT NOT NULL

### 2.3 `app_settings`
- `key` TEXT PRIMARY KEY
- `value_json` TEXT NOT NULL
- `updated_at_utc` TEXT NOT NULL

### 2.4 `local_alert_history`
- `id` TEXT PRIMARY KEY
- `backend_alert_id` TEXT NULL
- `geofence_id` TEXT NOT NULL
- `event_type` TEXT NOT NULL
- `distance_meters` REAL NULL
- `occurred_at_utc` TEXT NOT NULL
- `dismissed_at_utc` TEXT NULL
- `action` TEXT NULL
