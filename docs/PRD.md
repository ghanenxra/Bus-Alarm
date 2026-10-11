# Product Requirements Document (PRD) — Bus Alarm

Version: 1.0  
Platform: Android-first Flutter App + FastAPI Backend (Render)  
Status: Draft / In Progress

---

## 1. Executive Summary

Bus Alarm monitors a Blackbuck GPS share link for a college bus and alerts the user when the bus approaches or passes a saved stop. The user pastes a tracking link once, configures one or more geofences, and receives an alarm-style Android notification even when the phone is locked or the app is backgrounded, subject to Android OS permissions and device-vendor battery management restrictions.

The mobile app acts as the primary user interface and stores link history and geofences locally in SQLite. A FastAPI service on Render polls the Blackbuck location feed, calculates distance and point-to-segment approach/crossing events, and triggers high-priority push notifications via Firebase Cloud Messaging (FCM). Persistent backend state resides in managed external PostgreSQL (e.g. Supabase, Neon) rather than Render's ephemeral filesystem.

---

## 2. Problem Statement & User Persona

### Problem
Students waiting for daily college buses must constantly reopen, refresh, and monitor fragile web tracking links in their mobile browsers. This leads to missed stops, constant anxiety, and unnecessary battery drain from manual screen-on monitoring.

### Target Persona
A college student who rides a fixed bus route daily.
- Needs passive, reliable alerts so they can get ready or head to the stop on time.
- Cannot keep the screen on or constantly refresh browser tabs.
- Experiences varying network conditions and Android battery optimization aggressiveness.

---

## 3. Goals, Non-Goals, and Success Metrics

### Goals
1. **Link Management**: Paste and validate a Blackbuck share link in under 10 seconds.
2. **Expiry Visibility**: Display token expiry and alert the user before expiration (default 24h validity window).
3. **Local History**: Save, rename, reactivate, and delete past tracking links locally on device.
4. **Geofence Management**: Configure multiple geofences with custom radii (default 200m, range 30m–2000m).
5. **Accurate Geofence Detection**: Detect entry and point-to-segment crossing between discrete poll intervals to prevent misses during fast transit.
6. **Persistent Alarm**: Issue high-importance sound and vibration alarm on arrival with Dismiss and Snooze controls.
7. **Transparent System Health**: Clearly indicate backend state (Sleeping, Waking, Online, Offline), last position timestamp, and freshness.
8. **Explicit Backend Wake**: Provide a one-tap wake action for cold starts on free-tier hosting.

### Non-Goals (v1)
- iOS platform support (Android-first MVP).
- Public multi-user account registration, passwords, or social login.
- In-app payments or monetization.
- Multi-bus fleet tracking or public timetable route planning.
- Circumventing Blackbuck authentication, security controls, or rate limits.
- Guaranteeing silent/Do-Not-Disturb (DND) override on all Android OEM ROMs where restricted by OS policy.

### Success Metrics
- **Alert Reliability**: At least 9 of 10 controlled bus-pass test runs trigger an alert when provider data is available.
- **Background Delivery**: Push alert received while device is locked and app is backgrounded on tested hardware.
- **Zero Duplicate Storms**: Zero duplicate alarms for the same approach within the configured cooldown window.
- **Cold-Start Resolution**: Backend wake resolves to Online or an actionable error within 60 seconds.

---

## 4. Key Features & Functional Requirements

### 4.1 Link Ingestion & Validation
- Allowlist validation: Host must match Blackbuck tracking domain with HTTPS enforcement.
- Query parameter token extraction (`token` parameter).
- Local JWT claim inspection for expiration estimate (purely client-side preview; provider validation confirms actual viability).
- Link nickname assignment and local SQLite persistence.

### 4.2 Geofences & Proximity Engine
- Coordinate selection via interactive map pin, device GPS, or manual latitude/longitude entry.
- Configurable radius: Default 200 meters, selectable between 30 and 2000 meters.
- Trigger modes:
  - Crossing/Entry (Default, mandatory for MVP).
  - Approaching (Optional, distance monotonically decreasing below threshold).
- Cooldown: Default 900 seconds (15 minutes) per geofence to prevent repeated triggers on the same stop event.

### 4.3 Alarm & Notification Behavior
- FCM data/high-priority push notification payload.
- Android Notification Channel configured with high importance, dedicated sound, and vibration pattern.
- Full-screen alarm UI when permitted by Android system settings.
- Interactive actions: `Dismiss` and `Snooze (1 minute)`.
- Alarm dismissal sends an acknowledgement to the backend to log user resolution.

### 4.4 Dashboard & Cold-Start Management
- Backend status indicator: Sleeping, Waking up, Online, Offline.
- Tracking status: Active, Idle, Link Expired, Provider Error, Backend Offline.
- Last recorded bus coordinates, observed timestamp, and data freshness age.
- Distance to nearest enabled geofence.
- Manual "Wake Backend" trigger with bounded exponential backoff poll.

---

## 5. Risk Assessment & Limitations

1. **Provider Endpoint Volatility**: The Blackbuck endpoint is a private web app API. Any changes to the web client bundle or request parameters could break ingestion. The architecture isolates the provider behind an interface and requires fixture-driven contract testing.
2. **Free-Tier Backend Sleep**: When deployed on a free-tier Render service, the process sleeps after inactivity. The poller cannot execute while asleep. The app provides manual wake controls and diagnostic statuses to manage expectations transparently.
3. **Android OEM Aggressive Doze/Task Killing**: Custom Android vendor ROMs (MIUI, ColorOS, OneUI) may suppress background push delivery or cancel full-screen alarms. The app must guide users through battery optimization whitelisting and permission settings.
