---
type: file-note
domain: projection
path: flutter_app/lib/presentation/screens/player_window/screencast_main.dart
layer: presentation
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `screencast_main.dart`

> [!abstract] Primary Purpose
> Flutter entrypoint that runs inside the dedicated `FlutterEngine` the native Presentation API (Android `Presentation` / iOS `UIWindow`) hosts on the external display. Receives projection state from the DM's main engine over the `screencast_render` platform channel (not `desktop_multi_window` IPC) and renders it via `PlayerWindowRoot`, showing a "Waiting for projection state..." placeholder until the first push.

## Inputs / Outputs
**Inputs**
- Channel: `MethodChannel('com.elymsyr.dungeon_master_tool/screencast_render')`, handler set in `initState`.
- Methods received: `applyState` (`{type:'patch',payload}` or a full `ProjectionState` JSON map), `applyBattleMapPatch` (`{itemId, patch}`).
- Reads: `playerProjectionStateProvider.notifier` (Riverpod, local to this engine).
- Supabase / CDC / DAOs: none.
- Triggers: native method calls; sends `engineReady` to native once the handler is registered.

**Outputs**
- Public API: `@pragma('vm:entry-point') void screencastMain()`.
- State: updates `playerProjectionStateProvider` via `applyFull` / `applyPatch` / `applyBattleMapPatch`.
- Channel push out: `invokeMethod('engineReady', null)` (handler-ready signal to native).
- Writes / Supabase: none (read-only surface).

## Dependencies & Links
- Depends on: [[projection_state]], `player_window_root.dart`, `player_window_state_provider.dart` (not in allow-list)
- Used by: native Presentation host; pairs with [[projection_output_screencast]] on the DM side
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Screencast-Presentation-API]], [[Platform-Targets]]

## Key Logic / Variables
- `_handleMethod` branches on `call.method`:
  - `applyState`: if `map['type']=='patch'` → `notifier.applyPatch(payload)`; else parse full `ProjectionState.fromJson(map)` → `notifier.applyFull(state)`. First receipt flips `_hasReceivedState` via `setState` to remove the placeholder.
  - `applyBattleMapPatch`: `notifier.applyBattleMapPatch(itemId, patch)`.
- All handling wrapped in try/catch with verbose `SCREENCAST:` debugPrints (this path is hard to debug on a real external display).
- UI: `MaterialApp` (dark, black scaffold), body = `Stack` of `PlayerWindowRoot` + a centered cast-icon "Waiting for projection state..." overlay shown while `!_hasReceivedState`.

## Notes
- The patch-vs-full discrimination mirrors [[projection_output_screencast]]'s `pushPatch` which wraps patches as `{type:'patch', payload}` over the same channel.
