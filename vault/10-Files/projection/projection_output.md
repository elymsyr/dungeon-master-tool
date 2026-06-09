---
type: file-note
domain: projection
path: flutter_app/lib/application/services/projection_output.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `projection_output.dart`

> [!abstract] Primary Purpose
> Defines the abstract `ProjectionOutput` delivery contract. It decouples projection *content management* (the `ProjectionController` deciding which item is active, blackout, item add/remove) from the *transport mechanism* (desktop second window, mobile screencast, or online Supabase mirror). The controller delegates all delivery to whichever output(s) are active.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none (pure abstract interface). Takes a `ProjectionState` in `pushFull`.
- Reads (DAOs / Drift tables): none.
- Supabase / CDC subscribed: none (concrete impls do this).
- Events consumed: none.
- Triggers: none directly; `onExternalClose` stream lets impls report unsolicited closes.

**Outputs**
- Providers / public API exposed: abstract methods `isActive`, `activate()→Future<bool>`, `deactivate()`, `pushFull(ProjectionState)→Future<bool>`, `pushPatch(Map)→Future<bool>`, `pushBattleMapPatch(itemId, Map)→Future<bool>`, `onExternalClose` (`Stream<void>`), `dispose()`.
- Writes / Supabase / events: none (impls do).

## Dependencies & Links
- Depends on: [[projection_state]]
- Used by: [[projection_output_window]], [[projection_output_screencast]], [[projection_output_online]] (concrete impls); `ProjectionController` in `projection_provider.dart` (delegates transport)
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Multi-Window-IPC]], [[Screencast-Presentation-API]]

## Key Logic / Variables
- Three concrete subclasses, each maps to a `ProjectionOutputMode`: `secondWindow` → [[projection_output_window]], `screencast` → [[projection_output_screencast]], online fan-out → [[projection_output_online]].
- Return-value contract: `pushFull`/`pushPatch`/`pushBattleMapPatch` return `false` when the output has died unexpectedly, so the controller can clear its stale handle without crashing. `activate()` returns `true` on success.
- `onExternalClose` fires when the surface is closed *externally* (native window X, Miracast/cast disconnect). The controller listens to flip its own state. The online impl never fires it (no local surface).

## Notes
- Multiple outputs can be active simultaneously (fan-out): see `ProjectionState.outputModes` as a `Set`.
