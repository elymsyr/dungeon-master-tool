---
type: file-note
domain: projection
path: flutter_app/lib/application/services/projection_output_window.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `projection_output_window.dart`

> [!abstract] Primary Purpose
> Desktop second-window `ProjectionOutput` implementation using the `desktop_multi_window` package. Owns the player sub-window's lifecycle (open on a preferred non-primary monitor, cooperative + forced close) and delegates all serialized state transport to [[projection_ipc]].

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none (instantiated by the controller). Listens to global `playerWindowClosedSignal` `ValueNotifier` from `main.dart`.
- Reads: `screenRetriever.getAllDisplays()` / `getPrimaryDisplay()` to choose the target monitor.
- Supabase / CDC subscribed: none.
- Events consumed: `playerWindowClosedSignal` (reverse-IPC bridge — the player's native close button signals here).
- Triggers: 200ms `Timer` after `deactivate` for the forced-close fallback.

**Outputs**
- Public API: implements `ProjectionOutput` (`activate`, `deactivate`, `pushFull`, `pushPatch`, `pushBattleMapPatch`, `onExternalClose`, `dispose`).
- Writes / Supabase: none.
- Events emitted: `onExternalClose` fires via `_markDead()` when the window dies.

## Dependencies & Links
- Depends on: [[projection_output]], [[projection_ipc]], [[projection_state]]
- Used by: `ProjectionController` (`projection_provider.dart`) when `ProjectionOutputMode.secondWindow` is active
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Multi-Window-IPC]]

## Key Logic / Variables
- `_windowId` (`int?`) is the single piece of state; `isActive == _windowId != null`.
- `activate()`: resolves target frame via `_resolveTargetFrame()`, calls `DesktopMultiWindow.createWindow(jsonEncode({'type':'player_window'}))`, sets frame/title ("Player View — Second Screen")/shows, stores `windowId`, registers the `playerWindowClosedSignal` listener.
- `_resolveTargetFrame()`: prefers the first display whose `id != primary.id` (full external monitor); fallback is a centered `Rect.fromLTWH(120, 120, 1280, 720)` on the primary.
- `deactivate()`: clears `_windowId` first, sends `ProjectionIpc.requestClose(id)` (cooperative, lets player run dispose), then a 200ms `Timer` forces `WindowController.fromWindowId(id).close()` to defeat a wedged player isolate.
- `_markDead()`: idempotent — nulls `_windowId`, removes the signal listener, emits `onExternalClose`. Called both when a push fails and when the close-signal fires.
- Each push delegates to `ProjectionIpc`; a `false` return triggers `_markDead()`.

## Notes
- The reverse close-signal path (`playerWindowClosedSignal`) is what flips the DM cast icon immediately instead of waiting for the next push to fail.
