# Android Permissions and Device Reliability Guide — Bus Alarm

Version: 1.0  
Date: 11 October 2026

---

## 1. Required Permissions Matrix

| Permission | API Level | Purpose | Impact if Denied |
|---|---|---|---|
| `POST_NOTIFICATIONS` | 33+ (Tiramisu) | Post high-importance geofence alerts and expiry warnings | Push alerts cannot be displayed to user |
| `ACCESS_FINE_LOCATION` | All | Optional: Center map on current location or create stop at current position | Manual coordinate input still works completely |
| `USE_FULL_SCREEN_INTENT` | 29+ (Q) | Display full-screen alarm over lock screen | Notification falls back to high-priority heads-up banner |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | 31+ (S) | Pre-expiry local alarms | Expiry warnings rely on inexact background jobs |
| `WAKE_LOCK` | All | Wake CPU briefly during alarm sound & vibration playback | Device may sleep during alert playback |
| `VIBRATE` | All | Haptic vibration during alarm ringing | Silent visual-only alerts |

---

## 2. Notification Channels

Bus Alarm configures two distinct Android Notification Channels:
1. `bus_alarm_high_priority`:
   - Name: "Bus Arrival Alarms"
   - Importance: `IMPORTANCE_HIGH` (or `IMPORTANCE_MAX`)
   - Sound: Custom high-decibel alarm audio asset
   - Vibration: Enabled (`[0, 500, 250, 500, 250, 1000]`)
   - Lockscreen visibility: `VISIBILITY_PUBLIC`
   - Actions: `Dismiss`, `Snooze (1 min)`
2. `bus_alarm_service_info`:
   - Name: "Tracking & Expiry Updates"
   - Importance: `IMPORTANCE_LOW`
   - Sound: None
   - Vibration: None

---

## 3. OEM Battery Restrictions & Mitigation

Android OEM vendors (Samsung OneUI, Xiaomi MIUI/HyperOS, OnePlus OxygenOS, Oppo/Vivo ColorOS/Funtouch) enforce aggressive background task management:
- **Doze Mode**: While stationary and unpowered, network access and alarms are batched.
  - *Mitigation*: FCM messages must carry `"priority": "high"` to wake the device immediately.
- **Battery Optimization Whitelist**:
  - The app includes an onboarding settings card linking to `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` or `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- **Honest Limitations**:
  - If a device vendor forcibly terminates background tasks or overrides notification priorities, the app displays a clear warning on the Diagnostics screen rather than promising 100% bypass of custom OEM battery savers.
