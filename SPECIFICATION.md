Bus Alarm App — Expanded PRD, Technical Specification & AI Agent Build Prompt

Version: 1.0

Date: 11 October 2026

Platform: Android-first Flutter app + FastAPI backend on Render

Working name: Bus Alarm

1. Executive summary

Bus Alarm monitors a Blackbuck GPS share link for a college bus and alerts the user when the bus approaches or passes a saved stop. The user pastes a tracking link once, configures one or more geofences, and receives an alarm-style Android notification even when the phone is locked or the app is in the background, subject to Android permissions and device-vendor restrictions.

The mobile app is the primary user interface and stores link history and geofences locally in SQLite. A FastAPI service on Render polls a supported/verified Blackbuck location endpoint, calculates distance and approach events, and sends push notifications through Firebase Cloud Messaging (FCM). Persistent backend state must live in managed PostgreSQL, not Render's ephemeral filesystem.

2. Source-derived requirements vs. implementation decisions

The original five-page PRD specifies: Blackbuck share-link input and expiry display; local link history; editable geofences; configurable radius with 150–300 m recommended and 30 m still selectable; crossing detection between consecutive positions; optional approach and ETA alerts; persistent sound/vibration alarm; dashboard; backend wake button; FCM; Android-only v1; and a goal of 9/10 reliable alert days.

This expanded specification makes implementation choices where the source PRD leaves details open. These choices are assumptions to confirm during discovery:

Flutter + Dart for Android; FastAPI + Python for the backend.

SQLite on-device; PostgreSQL on a managed external service such as Neon or Supabase.

Firebase Cloud Messaging for push delivery.

One active tracking session per installation for v1; multiple saved links and multiple geofences are supported.

Backend polls only while an active session is enabled. Polling interval is configurable, initially 10 seconds, with rate-limit-aware backoff.

Use a map provider that does not require a paid key for the MVP, with manual latitude/longitude entry always available.

Do not assume the Blackbuck endpoint is stable or public. Isolate it behind a provider adapter and verify access, response format, permitted polling rate, and expiry behavior before implementing production polling.

No login or public multi-user account system in v1. Device registration still requires a random installation identifier and a server-side secret/registration mechanism to prevent arbitrary API abuse.

3. Goals, non-goals, and success metrics

Goals

Paste and validate a Blackbuck share link in under 10 seconds.

Display token expiry and alert the user before expiry (default 24 hours).

Save, rename, reactivate, and delete past links locally.

Create, edit, enable, disable, and delete multiple geofences.

Detect entry or crossing of a geofence and issue a persistent alarm.

Show backend and tracking health, last bus position/update time, and distance to the nearest enabled location.

Provide an explicit backend wake-up action and clear cold-start status.

Work within a low-cost/free-tier deployment, while clearly showing limitations.

Non-goals for v1

iOS, payments, public launch, user accounts, social sharing, multi-bus fleet management, route planning, arrival-history analytics, and a full administrator dashboard.

Guaranteeing that Android can override silent/DND modes or that every phone will display a full-screen alarm. These depend on OS permissions, policy, and device-vendor behavior.

Circumventing Blackbuck authentication, access controls, or rate limits.

Acceptance targets

At least 9 of 10 controlled bus-pass tests trigger an alert when the provider feed supplies adequate location updates.

Alarm can be received with screen locked and app backgrounded on a tested Android device after required permissions are granted.

Link creation flow completes in under 10 seconds in usability testing.

Backend wake status resolves to online or an explicit error within 60 seconds in normal conditions.

No duplicate alarm for the same approach inside the configured cooldown.

Expired/invalid provider links display actionable status and do not silently continue tracking.

4. Personas and primary user journey

Primary persona: One college student who regularly uses a fixed bus and wants to stop manually refreshing a tracking link.

Main journey

Open app; app checks `/health` and shows backend status.

Paste a Blackbuck share link.

App validates HTTPS host/path and presence of token; parses JWT claims only to estimate expiry. Decoding a JWT is not signature verification.

User gives the link a nickname and activates it.

User adds a stop by map pin, current location, or coordinates; selects radius (default 200 m), link, and trigger mode.

App requests notification and alarm-related permissions with explanations, then registers its FCM token and synchronizes the active session/geofences.

Dashboard displays tracking state, last bus location/time, and nearest-stop distance.

Backend observes an approach/entry/crossing, records an idempotent alert event, and sends FCM.

Android app presents a high-importance notification and, where permitted, opens a full-screen alarm UI with sound and vibration.

10. User dismisses or snoozes the alarm. The backend cooldown prevents repeated alerts for the same approach.

11. App warns before link expiry and lets the user replace it.

5. Screens and UI requirements

5.1 Home / dashboard

Backend badge: Sleeping/Unknown, Waking up, Online, or Offline/Error.

Tracking state: Active, Idle, Link expired, Provider error, or Backend offline.

Active link nickname and expiry.

Last bus position (coordinates and optional map preview), last update timestamp, freshness indicator.

Nearest enabled geofence, distance, configured radius, and approach status.

Main actions: Wake backend, Start/Pause tracking, Add stop, Manage links.

Show stale data explicitly; never label old coordinates as live.

5.2 Add / edit tracking link

Text field for URL; paste-from-clipboard affordance where supported.

Validate host against an explicit allowlist and require HTTPS.

Parse token from expected query parameter; reject missing/empty token.

Decode JWT claims locally for display only; treat claims as untrusted until provider validation succeeds.

Display expiry date/time and timezone; explain if expiry cannot be determined.

Nickname field; Save and Activate actions.

Errors: invalid URL, unsupported host, missing token, expired token, provider unavailable, unknown expiry.

5.3 Link history

List nickname, added date, expiry, and Active/Expired/Invalid status.

Actions: rename, activate if not expired, copy link, delete with confirmation.

Local-only storage; do not log raw tokenized URLs to analytics or normal application logs.

If a link is activated, sync its token to backend over HTTPS. Never expose it in UI logs.

5.4 Geofence list

List location name, radius, linked link, enabled state, trigger mode, and last alert.

Add/edit/delete; toggle enabled.

Prevent enabling a geofence whose linked link is missing, expired, or inactive.

Warn when a radius is very small (e.g. 30 m) and explain GPS/update uncertainty.

5.5 Add / edit geofence

Select location by map pin, current device GPS, or manual latitude/longitude.

Name, latitude, longitude, radius (default 200 m; configurable range 30–2000 m), linked saved link.

Trigger mode: Enter/Crossing (default), Approaching (optional), ETA (future/optional unless sufficiently reliable).

Optional approach threshold and cooldown settings with safe defaults.

Validate coordinate ranges; handle denied location permission without blocking manual entry.

Show selected coordinates and approximate radius.

5.6 Alarm screen

High-contrast, accessible full-screen screen with stop name, bus distance, event type, and event time.

Buttons: Dismiss and Snooze 1 minute.

Repeating alarm audio/vibration while active, subject to permissions and OS rules.

Dismissal must stop local sound/vibration and acknowledge the event to backend when network is available.

Snooze must not create an immediate duplicate alert; define snooze semantics and keep the event idempotent.

5.7 Settings / permissions

Notification permission state, full-screen intent availability, exact-alarm permission state if used, battery optimization guidance, and location permission.

Sound/vibration test button.

Configurable default radius, cooldown, expiry warning lead time, and polling/status refresh preferences.

Do not claim silent-mode bypass unless tested and supported by Android's permitted alarm/audio APIs.

5.8 Diagnostics

App version, backend base URL, last health check, last successful provider poll, provider status, FCM registration status.

Redacted recent diagnostic events.

Copy diagnostics button must exclude tokens, FCM secrets, and other credentials.

6. User flows and state machines

Flow A: First-time setup

Launch → permission education → notification permission → FCM token registration → dashboard. Permissions can be deferred, but the app must clearly state that reliable alarm behavior will be limited until enabled.

Flow B: Add and activate link

Paste URL → client validation → expiry preview → save locally → call backend activation endpoint → provider validation/poll test → active or actionable error. Do not mark tracking active just because local URL validation passed.

Flow C: Add stop

Choose map/current location/manual coordinates → set name/radius/link → validate → save locally → sync configuration → show enabled state only after successful local save; show sync errors separately.

Flow D: Wake backend

Tap Wake → call `GET /health` or `GET /health/ready` → show Waking up with elapsed timer → retry with bounded exponential backoff → Online or Offline/Error. A health ping is a best-effort wake-up only; it cannot guarantee a free-tier service stays awake.

Flow E: Geofence alert

Provider location arrives → validate coordinates and timestamp → calculate point distance and segment-to-circle crossing → evaluate approach direction and cooldown → persist unique event → send FCM → app displays notification/full-screen alarm where allowed → dismiss/snooze → acknowledge event.

Tracking state machine

`Idle → Starting → Active → Stale/ProviderError → Active` when polling recovers; `Active → LinkExpired` when expiry/provider says invalid; `Any state → BackendOffline` when the backend is unreachable. Keep provider status distinct from backend health.

Alert state machine

`Detected → Queued → Sent → Delivered/Unknown → Acknowledged/Dismissed` with retry-safe event IDs. FCM delivery receipts are not guaranteed; do not mark an alert as delivered solely because the send request succeeded.

7. Architecture

Flutter mobile app

Flutter/Dart, Material 3.

State management: Riverpod (or another single chosen pattern; do not mix patterns).

HTTP: Dio.

Local database: SQLite using Drift or sqflite; choose one.

Push: Firebase Messaging.

Map: flutter_map with OpenStreetMap-compatible tiles, or a provider selected after checking terms and rate limits.

Local alarm behavior: Android notification channels, notification actions, full-screen intent where permitted, and a native Android bridge/foreground service only if testing proves it necessary.

Local notifications for expiry warnings.

Store sensitive tokens using platform secure storage when needed; SQLite records should not expose tokens in debug logs.

FastAPI backend

FastAPI + Pydantic v2.

SQLAlchemy 2 + Alembic.

PostgreSQL managed externally (Neon/Supabase or equivalent); do not use Render ephemeral disk as the database.

HTTPX for provider calls.

FCM Admin SDK or a supported server-side FCM integration.

APScheduler or a managed worker/loop only after deployment behavior is understood. For a simple single-user MVP, a supervised async polling loop may be used, but it must be cancellation-safe and recover after restart.

Separate API process and poller/worker if free-tier limits or process lifecycle make a combined process unreliable.

Structured logs, health/readiness endpoints, timeouts, bounded retries, and redaction.

Deployment

Render web service for FastAPI.

Managed external PostgreSQL.

Firebase project for FCM.

Environment variables for secrets and configuration.

Render health check path `/health/ready`.

Optional external cron pinger is only a best-effort wake strategy, not a reliability guarantee. Respect Render plan terms and do not rely on keep-alive pings to evade hosting limits.

A free service that sleeps cannot reliably poll every 5–10 seconds continuously while asleep. If reliable 24/7 monitoring is a hard requirement, use an always-on worker/paid tier or another suitable scheduler/host.

8. Blackbuck provider integration

Create a `BlackbuckProvider` interface and one isolated implementation module. Do not spread endpoint details through business logic.

Required interface:

`parse_share_url(url) -> ShareToken`

`get_token_expiry(token) -> datetime | None`

`validate_share(token) -> ProviderValidationResult`

`fetch_location(token) -> BusPosition`

`normalize_error(error) -> ProviderError`

Provider adapter requirements:

Confirm the actual endpoint and JSON schema by inspecting normal browser network traffic for the user's own valid share link.

Use only endpoints and access methods the user is authorized to use; do not bypass authentication or rate limits.

Add connect/read timeouts, bounded retries, and exponential backoff on 429/5xx.

Respect provider polling constraints; make interval configurable and avoid polling if the session is inactive.

Normalize response into `latitude`, `longitude`, `observed_at`, optional accuracy/speed/heading, and provider status.

Reject impossible coordinates and stale/future timestamps.

Unit-test against redacted fixture responses.

If the provider endpoint changes, only this adapter should require modification.

Never log raw share tokens, full tokenized URLs, or authorization headers.

9. Geofence and distance algorithm

Point distance

Use the Haversine formula or a vetted geospatial library to calculate meters between the bus position and geofence center.

Crossing detection

Checking only whether the latest point is inside the circle can miss a fast bus crossing between samples. For each consecutive position pair A and B:

Project coordinates to a local metric coordinate system suitable for the short segment, or use a tested geodesic point-to-segment method.

Compute minimum distance from geofence center to segment AB.

Trigger a crossing candidate if minimum distance is within radius plus a configurable GPS uncertainty margin.

Apply event policy: only alert if prior position was outside or approach state indicates a new approach; suppress repeats inside cooldown.

Store previous valid position per active tracking session.

Approaching trigger (optional)

Trigger when distance is below a configurable threshold and decreasing over multiple samples. Require a minimum improvement to avoid GPS noise. Do not infer route direction from distance alone when GPS is noisy.

ETA (optional)

Estimate only if speed/heading data is credible and distance trend is stable. Label it approximate; do not make ETA a v1 blocker.

Cooldown and idempotency

Use a stable event key based on session, geofence, approach episode/time bucket. Persist event before sending push. A retry must not create a second event or send duplicate alarms unnecessarily.

10. API specification

Base path: `/api/v1`. All timestamps are ISO-8601 UTC. All endpoints use JSON except health endpoints. Add request IDs and consistent error bodies.

Health

`GET /health` — liveness check; returns service process status and version.

`GET /health/ready` — readiness check including database connectivity; do not make a slow provider call on every health check.

`GET /api/v1/status` — backend, poller, provider, active-session, and last-poll status.

Device and push registration

`POST /api/v1/devices/register`

- Request: `{ "installation_id": "uuid", "fcm_token": "...", "platform": "android", "app_version": "1.0.0" }`

- Response: `{ "device_id": "uuid", "registered": true }`

`PUT /api/v1/devices/{device_id}/fcm-token`

- Request: `{ "fcm_token": "..." }`

- Response: `{ "updated": true }`

`DELETE /api/v1/devices/{device_id}` — revoke installation registration.

Tracking links / session

`POST /api/v1/tracking-sessions`

- Request: `{ "device_id": "uuid", "nickname": "College Bus", "share_url": "https://trackgps.blackbuck.com/location?token=REDACTED", "poll_interval_seconds": 10 }`

- Server extracts token, validates host and provider access, and creates/activates session only on successful validation.

- Response: `{ "session_id": "uuid", "status": "active|invalid|expired|provider_error", "expires_at": "...", "last_position": null }`

`GET /api/v1/tracking-sessions` — list sessions for the registered device.

`GET /api/v1/tracking-sessions/{session_id}` — details/status.

`POST /api/v1/tracking-sessions/{session_id}/activate` — activate a non-expired saved session.

`POST /api/v1/tracking-sessions/{session_id}/pause` — stop polling.

`DELETE /api/v1/tracking-sessions/{session_id}` — remove backend session and secrets.

`GET /api/v1/tracking-sessions/{session_id}/position` — last normalized position and freshness.

`POST /api/v1/tracking-sessions/{session_id}/refresh` — request one bounded refresh, protected by rate limits.

Geofences

`GET /api/v1/geofences?device_id=...`

`POST /api/v1/geofences`

- Request: `{ "device_id": "uuid", "session_id": "uuid", "name": "Main Gate", "latitude": 25.18, "longitude": 75.83, "radius_meters": 200, "enabled": true, "trigger_mode": "crossing", "cooldown_seconds": 900 }`

`GET /api/v1/geofences/{geofence_id}`

`PATCH /api/v1/geofences/{geofence_id}` — partial updates.

`DELETE /api/v1/geofences/{geofence_id}`

`POST /api/v1/geofences/sync` — optional bulk upsert if mobile local configuration is the source of truth.

Alerts

`GET /api/v1/alerts?device_id=...&limit=50` — recent alert events.

`GET /api/v1/alerts/{alert_id}` — event status.

`POST /api/v1/alerts/{alert_id}/acknowledge` — body `{ "action": "dismiss|snooze", "snooze_seconds": 60 }`.

`POST /api/v1/devices/{device_id}/test-notification` — send a test push.

Errors

Use standard status codes: 400 malformed input, 401/403 invalid device credential, 404 missing resource, 409 invalid state/conflict, 422 schema validation, 429 rate limited, 502 provider failure, 503 backend/dependency unavailable. Example body:

`{ "error": { "code": "PROVIDER_RATE_LIMITED", "message": "The location provider is temporarily rate-limiting requests.", "request_id": "..." } }`

API security

Do not put provider tokens in URLs for the app's own API; use JSON request bodies over HTTPS.

Do not log request bodies containing share URLs/tokens or FCM tokens.

Use a random installation secret or short-lived device credential for mutating endpoints; a device UUID alone is not authentication.

Add per-device and per-IP rate limits, request size limits, CORS only if needed, and strict input validation.

No secrets committed to Git. Use environment variables and a local `.env` excluded from version control.

11. Database schema

Mobile SQLite (source of truth for user preferences/history)

`saved_links`

`id TEXT PRIMARY KEY` (UUID)

`nickname TEXT NOT NULL`

`share_url_encrypted TEXT NOT NULL`

`token_expiry_utc TEXT NULL`

`added_at_utc TEXT NOT NULL`

`updated_at_utc TEXT NOT NULL`

`is_favorite INTEGER NOT NULL DEFAULT 0`

`last_known_status TEXT NOT NULL` (`unknown|active|expired|invalid|provider_error`)

`last_activated_at_utc TEXT NULL`

`geofences`

`id TEXT PRIMARY KEY`

`name TEXT NOT NULL`

`latitude REAL NOT NULL`

`longitude REAL NOT NULL`

`radius_meters INTEGER NOT NULL DEFAULT 200`

`linked_saved_link_id TEXT NOT NULL`

`enabled INTEGER NOT NULL DEFAULT 1`

`trigger_mode TEXT NOT NULL DEFAULT 'crossing'`

`cooldown_seconds INTEGER NOT NULL DEFAULT 900`

`created_at_utc TEXT NOT NULL`

`updated_at_utc TEXT NOT NULL`

Foreign key to `saved_links(id)` with deliberate delete behavior (confirm before cascading if geofences depend on link).

`app_settings`

`key TEXT PRIMARY KEY`

`value_json TEXT NOT NULL`

`updated_at_utc TEXT NOT NULL`

`local_alert_history`

`id TEXT PRIMARY KEY`

`backend_alert_id TEXT NULL`

`geofence_id TEXT NOT NULL`

`event_type TEXT NOT NULL`

`distance_meters REAL NULL`

`occurred_at_utc TEXT NOT NULL`

`dismissed_at_utc TEXT NULL`

`action TEXT NULL`

Backend PostgreSQL

`devices`

`id UUID PRIMARY KEY`

`installation_id UUID UNIQUE NOT NULL`

`credential_hash TEXT NOT NULL`

`platform TEXT NOT NULL DEFAULT 'android'`

`app_version TEXT NULL`

`fcm_token_encrypted TEXT NULL`

`created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

`last_seen_at TIMESTAMPTZ NULL`

`is_active BOOLEAN NOT NULL DEFAULT true`

`tracking_sessions`

`id UUID PRIMARY KEY`

`device_id UUID NOT NULL REFERENCES devices(id)`

`nickname TEXT NOT NULL`

`provider TEXT NOT NULL DEFAULT 'blackbuck'`

`provider_token_encrypted TEXT NOT NULL`

`expires_at TIMESTAMPTZ NULL`

`status TEXT NOT NULL`

`poll_interval_seconds INTEGER NOT NULL DEFAULT 10`

`last_polled_at TIMESTAMPTZ NULL`

`last_success_at TIMESTAMPTZ NULL`

`last_error_code TEXT NULL`

`created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

`updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`

Index on `(device_id, status)`.

`geofences`

`id UUID PRIMARY KEY`

`device_id UUID NOT NULL REFERENCES devices(id)`

`session_id UUID NOT NULL REFERENCES tracking_sessions(id)`

`name TEXT NOT NULL`

`latitude DOUBLE PRECISION NOT NULL`

`longitude DOUBLE PRECISION NOT NULL`

`radius_meters INTEGER NOT NULL DEFAULT 200`

`enabled BOOLEAN NOT NULL DEFAULT true`

`trigger_mode TEXT NOT NULL DEFAULT 'crossing'`

`cooldown_seconds INTEGER NOT NULL DEFAULT 900`

`last_triggered_at TIMESTAMPTZ NULL`

`created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

`updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`

Check constraints for latitude [-90,90], longitude [-180,180], and radius [30,2000].

`bus_positions`

`id BIGSERIAL PRIMARY KEY`

`session_id UUID NOT NULL REFERENCES tracking_sessions(id)`

`latitude DOUBLE PRECISION NOT NULL`

`longitude DOUBLE PRECISION NOT NULL`

`observed_at TIMESTAMPTZ NOT NULL`

`received_at TIMESTAMPTZ NOT NULL DEFAULT now()`

`accuracy_meters DOUBLE PRECISION NULL`

`speed_mps DOUBLE PRECISION NULL`

`heading_degrees DOUBLE PRECISION NULL`

Index on `(session_id, observed_at DESC)`.

Retain only a limited recent window for v1; avoid collecting unnecessary location history.

`alert_events`

`id UUID PRIMARY KEY`

`device_id UUID NOT NULL REFERENCES devices(id)`

`session_id UUID NOT NULL REFERENCES tracking_sessions(id)`

`geofence_id UUID NOT NULL REFERENCES geofences(id)`

`event_key TEXT UNIQUE NOT NULL`

`event_type TEXT NOT NULL`

`distance_meters DOUBLE PRECISION NULL`

`occurred_at TIMESTAMPTZ NOT NULL`

`push_status TEXT NOT NULL DEFAULT 'queued'`

`push_attempts INTEGER NOT NULL DEFAULT 0`

`acknowledged_at TIMESTAMPTZ NULL`

`user_action TEXT NULL`

`created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

Index on `(device_id, occurred_at DESC)`.

`provider_poll_state` (optional if not kept in session)

`session_id UUID PRIMARY KEY REFERENCES tracking_sessions(id)`

`previous_latitude DOUBLE PRECISION NULL`

`previous_longitude DOUBLE PRECISION NULL`

`previous_observed_at TIMESTAMPTZ NULL`

`consecutive_failures INTEGER NOT NULL DEFAULT 0`

`next_poll_at TIMESTAMPTZ NULL`

Encrypt provider tokens and FCM tokens at rest where feasible; keep encryption keys in environment variables/secret management, not in the database. Use Alembic migrations. Add retention/cleanup for position history and stale alert events.

12. Suggested repository structure

bus-alarm/

├── README.md

├── .gitignore

├── docs/

│   ├── PRD.md

│   ├── TECHNICAL_SPEC.md

│   ├── API.md

│   ├── DATA_MODEL.md

│   ├── ANDROID_PERMISSIONS.md

│   └── AGENT_BUILD_PROMPT.md

├── mobile/

│   ├── pubspec.yaml

│   ├── android/

│   ├── assets/

│   │   ├── sounds/

│   │   └── images/

│   ├── lib/

│   │   ├── main.dart

│   │   ├── app.dart

│   │   ├── core/

│   │   │   ├── config/

│   │   │   ├── networking/

│   │   │   ├── errors/

│   │   │   ├── permissions/

│   │   │   ├── notifications/

│   │   │   └── utils/

│   │   ├── data/

│   │   │   ├── local_db/

│   │   │   ├── models/

│   │   │   ├── repositories/

│   │   │   └── services/

│   │   ├── features/

│   │   │   ├── dashboard/

│   │   │   ├── tracking_links/

│   │   │   ├── geofences/

│   │   │   ├── alarm/

│   │   │   ├── settings/

│   │   │   └── diagnostics/

│   │   └── shared/

│   │       ├── widgets/

│   │       └── theme/

│   └── test/

├── backend/

│   ├── pyproject.toml

│   ├── requirements.txt

│   ├── Dockerfile

│   ├── render.yaml

│   ├── alembic.ini

│   ├── alembic/

│   │   └── versions/

│   ├── app/

│   │   ├── main.py

│   │   ├── core/

│   │   │   ├── config.py

│   │   │   ├── logging.py

│   │   │   └── security.py

│   │   ├── api/

│   │   │   └── v1/

│   │   │       ├── router.py

│   │   │       └── endpoints/

│   │   ├── db/

│   │   │   ├── session.py

│   │   │   └── models/

│   │   ├── schemas/

│   │   ├── repositories/

│   │   ├── services/

│   │   │   ├── tracking_service.py

│   │   │   ├── geofence_service.py

│   │   │   ├── alert_service.py

│   │   │   └── fcm_service.py

│   │   ├── providers/

│   │   │   ├── base.py

│   │   │   └── blackbuck.py

│   │   └── workers/

│   │       └── poller.py

│   └── tests/

│       ├── unit/

│       ├── integration/

│       └── fixtures/

└── scripts/

├── dev_backend.sh

└── run_checks.sh

13. Step-by-step build plan

Phase 0 — Discovery and risk spike

Verify the user's own Blackbuck share link works in a browser.

Inspect the normal network request that supplies location; document URL pattern, authentication, response schema, expiry, update cadence, and rate limits.

Create redacted sample fixtures and a provider adapter contract.

Test Android full-screen intent, notification channel, sound/vibration, lock-screen display, and battery restrictions on the target phone.

Decide the actual Render plan and managed PostgreSQL provider. Document any free-tier limits.

Exit gate: Do not proceed with real tracking until provider access is validated and Android alarm feasibility is demonstrated.

Phase 1 — Repository and backend skeleton

Create monorepo and documentation.

Configure FastAPI app, settings, structured logging, request IDs, CORS only if required, and health endpoints.

Configure SQLAlchemy, PostgreSQL connection, Alembic, and first migration.

Add CI checks: formatting, linting, type checks, and pytest.

Deploy a minimal service to Render and confirm `/health` and `/health/ready`.

Phase 2 — Provider adapter and tracking

Implement URL/token parser with allowlisted host.

Implement provider validation and normalized position model using fixture-based tests.

Add session create/activate/pause endpoints.

Implement configurable poller with timeouts, backoff, cancellation, and provider status tracking.

Store latest position and bounded history.

Add unit tests for invalid coordinates, stale timestamps, expiry, 429, 5xx, and provider schema changes.

Phase 3 — Geofence engine and alerts

Implement Haversine distance and point-to-segment crossing functions.

Test exact edge cases: pass-through between samples, repeated points, GPS jitter, location accuracy margin, multiple geofences, and cooldown.

Persist unique alert event before push send.

Integrate FCM and device registration.

Add test notification and acknowledge endpoints.

Verify retry/idempotency behavior.

Phase 4 — Flutter app foundation

Create Flutter Android project, theme, navigation, environment configuration, and API client.

Implement SQLite schema/migrations and repository tests.

Build link add/edit/history screens.

Build geofence list and add/edit flows.

Add permission education and diagnostics.

Phase 5 — Dashboard and push/alarm experience

Build dashboard status cards and wake-backend state machine.

Register/refresh FCM token and sync active link/geofences.

Handle foreground/background FCM messages.

Implement notification channel, alarm sound/vibration, Dismiss and Snooze actions, and full-screen intent where allowed.

Implement expiry warning notifications.

Test after force-stop, reboot, app update, network loss, battery saver, and permission denial; document unsupported OS states honestly.

Phase 6 — Deployment and reliability

Set Render environment variables and external Postgres.

Run migrations as a controlled release step.

Configure health check and logs; verify no secrets are logged.

Add bounded polling/backoff and monitor provider request rate.

Test Render sleep/cold start and app wake UX. If monitoring must continue while Render sleeps, move polling to an always-on worker/paid service rather than pretending a ping guarantees background polling.

Add database retention cleanup and backup/export instructions.

Phase 7 — Acceptance and release

Run backend unit/integration tests and Flutter tests.

Conduct 10 real-world or simulated bus-pass tests with known route/position data.

Measure trigger recall, false positives, push latency, duplicate rate, stale-data handling, and battery impact.

Test on at least two Android versions if available.

Produce a release APK, setup guide, troubleshooting guide, and known-limitations document.

14. Test plan

Backend unit tests

URL allowlist, malformed URL, missing token, expired JWT claims.

JWT expiry is display metadata only until provider confirms validity.

Distance calculation and coordinate validation.

Segment crossing where both sample endpoints are outside the radius.

Cooldown and idempotent event creation.

Poller retry/backoff and cancellation.

FCM failure/retry and alert acknowledgement.

API integration tests

Device registration and credential enforcement.

Session create, activate, pause, expired session, and delete.

Geofence CRUD and invalid coordinates/radius.

Health readiness when database is unavailable.

Rate limiting and provider errors.

Flutter tests

Link form validation and expiry display.

Link history CRUD.

Geofence form validation and local persistence.

Dashboard state transitions.

Permission-denied states and manual coordinate entry.

Alarm dismiss/snooze behavior.

API timeout and offline states.

End-to-end scenarios

Bus enters a geofence between two polls.

Bus approaches but then turns away.

GPS jumps/noisy positions do not cause repeated alarms.

Link expires while active.

Backend cold starts and remains unavailable.

Phone locked, app backgrounded, battery saver enabled, and notification permission denied.

User dismisses alert; cooldown suppresses duplicates.

15. Open questions and risks

What exact Blackbuck endpoint and response schema are used by the share page?

Is the token a JWT with reliable `iat` and TTL claims, and is expiry fixed?

What polling rate is permitted, and is 10-second polling sustainable?

Does Blackbuck return position timestamps, accuracy, speed, and heading?

Which Android version and phone model will be the primary test device?

Can full-screen alarm behavior be enabled on that device, and what happens under DND/battery saver?

Is continuous tracking acceptable only while Render is awake, or is always-on monitoring required?

Which managed PostgreSQL service and Render plan will be used?

Critical product truth: A sleeping free-tier backend cannot continuously poll the bus. FCM cannot deliver an alert that was never generated, and Android cannot guarantee full-screen or silent-mode override on every device. The app must show monitoring health and stale data instead of implying tracking is active when it is not.

---

Appendix A — Copy/paste prompt for an AI coding agent

You are a senior full-stack engineer and mobile reliability engineer. Build Bus Alarm, an Android-first Flutter app with a FastAPI backend deployed on Render. The project specification is in this document. Follow it as the source of truth, and do not silently remove features or invent unsupported provider behavior.

Mission

Deliver a working, tested MVP that lets one user save a Blackbuck GPS share link, configure geofences around bus stops, monitor the bus through a backend provider adapter, and receive an Android alarm-style alert when the bus approaches, enters, or crosses a geofence.

Fixed stack

Mobile: Flutter/Dart, Android first, Material 3, Riverpod, Dio, SQLite using Drift or sqflite (choose one and use it consistently), Firebase Messaging, local notifications, map/manual coordinate selection.

Backend: Python, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic, PostgreSQL, HTTPX, pytest.

Deployment: Render web service plus managed external PostgreSQL. Firebase Cloud Messaging for push.

Do not add paid services as mandatory dependencies. Explain any service whose free tier has limitations.

Do not implement iOS or user accounts in v1.

Mandatory engineering rules

First inspect the repository. Preserve existing working code and report what already exists before changing it.

Before coding, create/update `docs/PRD.md`, `docs/TECHNICAL_SPEC.md`, `docs/API.md`, `docs/DATA_MODEL.md`, and a task checklist.

Work in small phases; keep the app runnable after each phase.

Never fabricate a Blackbuck endpoint or response schema. First create a provider interface and fixture-based fake provider. Ask for or inspect redacted real response details before implementing the live adapter.

Use only authorized access. Do not bypass access controls, authentication, or provider rate limits.

Do not log tokenized share URLs, provider tokens, FCM tokens, device credentials, or secret headers.

Keep secrets in environment variables/secret storage; add `.env` to `.gitignore`; provide `.env.example` with placeholders only.

Do not store backend state on Render's ephemeral filesystem. Use managed PostgreSQL and Alembic migrations.

Make tracking health visible. Never label stale provider coordinates as live.

10. Use idempotent alert events and cooldowns so retries do not ring repeatedly.

11. Add tests with each feature. Do not claim a feature is complete if it has not been tested.

12. If an OS, provider, or hosting limitation prevents a guarantee, implement the best supported behavior, expose the limitation in the UI/docs, and do not fake success.

13. Use UTC timestamps in the API and database.

14. Keep provider integration isolated in `backend/app/providers/blackbuck.py` behind a typed interface.

15. Add timeouts, bounded retries, rate-limit handling, and exponential backoff to network calls.

Required deliverables

Flutter Android project with screens described in this spec.

FastAPI backend with versioned endpoints.

PostgreSQL schema and Alembic migrations.

SQLite local persistence and migrations.

Blackbuck provider interface plus fixture/fake provider; live provider adapter only after endpoint details are verified.

FCM registration, test push endpoint, alert acknowledgement.

Geofence distance and crossing algorithm with tests.

Render deployment configuration and documented environment variables.

README with local setup, Android run steps, Firebase setup, database setup, Render deployment, and troubleshooting.

Unit, integration, and Flutter tests.

A known-limitations document and an end-to-end acceptance checklist.

Implementation order — follow this sequence

Step 0: Discovery report

Inspect repository and environment. List files, existing implementation, unknowns, and blockers. Identify missing provider endpoint details and Android alarm feasibility risks. Do not start large-scale implementation before reporting these.

Step 1: Backend skeleton

Implement configuration, logging/redaction, request IDs, `/health`, `/health/ready`, database connection, SQLAlchemy models, Alembic, and tests. Deploy a minimal health-check service to Render if credentials/configuration are available.

Step 2: Provider contract

Implement typed `BlackbuckProvider` interface, URL validation, token extraction, expiry parsing, normalized `BusPosition`, and a fake fixture provider. Add tests. Do not hardcode an unverified live endpoint.

Step 3: Sessions and polling

Implement device registration and tracking-session endpoints. Build a cancellation-safe poller with configurable interval, timeout, backoff, session expiry checks, and clear status fields. Store the latest position and bounded history.

Step 4: Geofence engine

Implement Haversine distance and a tested point-to-segment crossing algorithm. Support configurable radius, crossing trigger, optional approach mode, GPS uncertainty margin, cooldown, and unique event keys. Persist events before sending pushes.

Step 5: Push service

Implement FCM token registration, test notification, push retries, alert status, dismiss/snooze acknowledgement, and safe handling of stale/invalid FCM tokens. Add tests.

Step 6: Flutter foundation and local data

Create navigation, theme, config, Dio client, typed models, repositories, SQLite tables, and tests. Implement link history and settings.

Step 7: Link and geofence screens

Implement add/edit/activate/rename/delete link flows and expiry warnings. Implement geofence list/add/edit/delete/enable/disable with map pin, current location, and manual coordinates. Make local save and backend sync errors distinct.

Step 8: Dashboard and backend wake-up

Implement health status, tracking state, last position/time, nearest stop/distance, Wake button, spinner/timer, bounded retries, and stale-data warnings.

Step 9: Android alarm behavior

Implement FCM foreground/background handling, notification channels, sound/vibration, Dismiss and Snooze 1 min actions, and full-screen intent only where supported/allowed. Add permission onboarding for notifications, full-screen intent, exact alarms if used, and battery optimization. Test on a physical Android device. Do not claim guaranteed DND bypass.

Step 10: Deployment hardening

Configure Render, external PostgreSQL, migrations, environment variables, health checks, structured logs, retention, and backup instructions. Explain that free-tier sleeping prevents guaranteed continuous polling; do not use keep-alive pings to evade hosting limits.

Step 11: Acceptance

Run all tests. Produce a checklist showing pass/fail for every acceptance criterion. Run at least 10 simulated or real pass-through cases and report missed triggers/false positives. Build a debug APK and document installation.

Definition of done

Link validation, expiry display, history CRUD, geofence CRUD, dashboard, wake UX, API, database migrations, FCM, and alarm actions work as specified.

Crossing between samples is detected in tests.

Duplicate alerts are suppressed with persisted cooldown/idempotency.

Backend health and provider health are separate.

No secret is committed or logged.

All core tests pass, and deployment/setup instructions are reproducible.

Any feature blocked by provider credentials, Firebase configuration, or device permissions is clearly marked `BLOCKED` with the exact missing input and a safe mock/test path.

Agent reporting format

At the end of every phase, report:

**Completed** — exact files/features.

**Tests** — commands run and results.

**Manual verification** — what was actually tested on a device/deployment.

**Blockers/assumptions** — especially Blackbuck endpoint, FCM credentials, Android permissions, and Render plan.

**Next phase** — the next smallest useful step.

Start with Step 0. Do not jump straight to generating the entire app in one untested pass.