---
type: file-note
domain: projection
path: flutter_app/lib/application/services/projection_output_screencast.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `projection_output_screencast.dart`

> [!abstract] Primary Purpose
> Mobile/external-display `ProjectionOutput` implementation that drives the OS Presentation API (Android `DisplayManager` + `Presentation`; iOS `UIScreen` + `UIWindow`) via a `ScreencastPlatform` platform-channel wrapper. No IPC is needed — the hosted presentation FlutterEngine receives state as JSON over the channel.

## Inputs / Outputs
**Inputs**
- Constructor deps: `targetDisplayId` (`String`, required — the display to present on), optional injectable `ScreencastPlatform platform` (defaults to a real instance).
- Reads: none (DAOs/tables).
- Supabase / CDC subscribed: none.
- Events consumed: `_platform.onDisplayDisconnected` stream (drives `_markDead()`).
- Triggers: display-disconnect event from the platform side.

**Outputs**
- Public API: implements `ProjectionOutput`.
- Platform calls: `ScreencastPlatform.startPresentation(displayId)`, `startListening()`, `pushState(json)`, `pushBattleMapPatch(itemId, patch)`, `stopPresentation()`, `dispose()`.
- Events emitted: `onExternalClose` via `_markDead()` on display disconnect.

## Dependencies & Links
- Depends on: [[projection_output]], [[projection_state]]; `screencast_platform.dart` (`ScreencastPlatform`, not in allow-list)
- Used by: `ProjectionController` (`projection_provider.dart`) when `ProjectionOutputMode.screencast` is active
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Screencast-Presentation-API]], [[Platform-Targets]]

## Key Logic / Variables
- `_active` (`bool`) is the sole liveness flag; `_disconnectSub` holds the disconnect subscription.
- `activate()`: `startPresentation(targetDisplayId)`; on success sets `_active`, calls `startListening()`, subscribes to `onDisplayDisconnected`.
- `pushFull(state)` → `_platform.pushState(state.toJson())`.
- `pushPatch(patch)` → `_platform.pushState({'type':'patch','payload':patch})` (screencast has no dedicated patch channel for the full state, so it reuses `pushState` with a type marker — the receiver in [[screencast_main]] branches on `type`).
- `pushBattleMapPatch(itemId, patch)` → dedicated `_platform.pushBattleMapPatch(itemId, patch)`.
- Any push returning `false` → `_markDead()` (sets `_active=false`, cancels sub, emits `onExternalClose`).

## Notes
- Receiving side is [[screencast_main]] running in the native-hosted FlutterEngine, listening on channel `com.elymsyr.dungeon_master_tool/screencast_render`.
