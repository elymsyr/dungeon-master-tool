---
type: file-note
domain: multiplayer
path: flutter_app/lib/data/services/heartbeat_service.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `heartbeat_service.dart`

> [!abstract] Primary Purpose
> Singleton lifecycle-aware service that keeps `profiles.last_active_at` / `app_version` / `platform` populated (admin-panel columns) for every authenticated session, via a `user_heartbeat` RPC fired on start, on auth events, and on a 15-minute foreground timer.

## Inputs / Outputs
**Inputs**
- Supabase subscribed: `client.auth.onAuthStateChange` (acts on `signedIn`, `tokenRefreshed`, `userUpdated`).
- Triggers: service `start()` at boot (if existing session), 15-minute periodic timer, app-lifecycle resume/background (`WidgetsBindingObserver.didChangeAppLifecycleState`).
- Reads: `appVersion` constant, `Platform.operatingSystem` / `kIsWeb`.

**Outputs**
- Public API: `HeartbeatService.instance`, `start()`, `stop()`, `send()`.
- Supabase RPC called: `user_heartbeat` with params `p_app_version`, `p_platform`.

## Dependencies & Links
- Depends on: `core/constants` (`appVersion`), `core/services/log_buffer` (`LogBuffer`)
- Used by: app bootstrap (started once); reacts to [[auth_provider]] auth events
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: [[migrations-auth-social]], [[rpc-reference]]

## Key Logic / Variables
- Singleton via private `HeartbeatService._()` + `static final instance`. `start()` is idempotent (`_started` guard).
- `_interval = Duration(minutes: 15)`.
- **Triggers** for `send()`: (1) `start()` when `currentUser != null`; (2) auth events `signedIn` / `tokenRefreshed` / `userUpdated`; (3) periodic foreground timer.
- `send()` no-ops if no `currentUser`; errors recorded to `LogBuffer` (context `Heartbeat.send` / `Heartbeat.authStream`) — never throws.
- **Foreground gating**: `_foreground` flag tracked via lifecycle observer. On background the periodic timer is cancelled (so mobile doesn't wake the radio for an idle ping); on resume it sends immediately and restarts the timer. `_startTimer()` is a no-op while backgrounded.

## Notes
- Backs the admin panel's `last_active`/`version` columns; this closed the NULL gap noted in the Admin Heartbeat (May 28) memory.
