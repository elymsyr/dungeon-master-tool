---
type: file-note
domain: projection
path: flutter_app/lib/application/services/projection_ipc.dart
layer: application
language: dart
status: stable
updated: 2026-10-08
tags: [file]
---

# `projection_ipc.dart`

> [!abstract] Primary Purpose
> Stateless wrapper around `DesktopMultiWindow.invokeMethod` for the desktop second-window transport. Defines the IPC method-name vocabulary (`ProjectionIpcMethods`) and the encode/decode helpers (`ProjectionIpc`) used to ship `ProjectionState` between the DM main window and the player sub-window over `desktop_multi_window`'s window-to-window MethodChannel.

## Inputs / Outputs
**Inputs**
- Constructor deps: none — all static methods, owns no state.
- Reads: none.
- Supabase / CDC: none.
- Events consumed: none directly (the receiver side calls `decodeApply` / `decodeBattleMapPatch`).
- Triggers: none.

**Outputs**
- Public API (static): `pushFull(windowId, state)→Future<bool>`, `pushPatch(windowId, Map)→Future<bool>`, `pushBattleMapPatch(windowId, itemId, Map)→Future<bool>`, `requestClose(windowId)`, decoders `decodeApply(raw)→(String type, Map, String? lang)` (`pushFull(..., {lang})` — DM'in SRD içerik dili, yalnızca tam durumda; alt pencere `projectionContentLanguageProvider`'a yazar), `decodeBattleMapPatch(raw)→(String itemId, Map)`.
- Writes / Supabase / events: none.

## Dependencies & Links
- Depends on: [[projection_state]]; `desktop_multi_window` package
- Used by: [[projection_output_window]] (push side), [[player_window_main]] / player window app (decode side)
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Multi-Window-IPC]]

## Key Logic / Variables
- IPC method names (`MethodCall.method`):
  - `projection.apply` — DM → sub-window; args `{type:'full'|'patch', payload:<json>}`. `full` on connect / item add/remove; `patch` for active-item changes, blackout toggles, per-item view state.
  - `projection.battleMapPatch` — DM → sub-window; args `{itemId, patch:<partial snapshot>}`. Optimization path so a single stroke/fog/token-size change doesn't re-encode the whole `ProjectionState` (hundreds of KB with fog).
  - `projection.ready` — sub-window → DM ack on first paint (reports `windowId`).
  - `projection.player_closed` — sub-window → DM; user closed via native chrome.
  - `projection.close` — DM → sub-window graceful close.
- Every push is wrapped in try/catch returning `false` on error (e.g. window already closed) instead of throwing — lets [[projection_output_window]] clear its stale `windowId`.
- Patch format is intentionally permissive: the receiver merges only keys it understands.

## Notes
- `requestClose` swallows errors (window may already be gone). Encoding is `jsonEncode` of a `Map`; decoders re-parse with `.cast<String, dynamic>()`.
