---
type: file-note
domain: projection
path: flutter_app/lib/domain/entities/projection/projection_state.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `projection_state.dart`

> [!abstract] Primary Purpose
> Top-level immutable projection state owned by `ProjectionController` on the DM side and mirrored to the player sub-window (IPC), screencast engine, and remote players (`world_projection` manifest). Holds the list of open `ProjectionItem`s, which one is active, which output modes are live (fan-out set), and the global blackout override. JSON round-trips with multi-version backward compat.

## Inputs / Outputs
**Inputs**
- Constructor / `copyWith`: `items` (`List<ProjectionItem>`), `activeItemId` (`String?`, sentinel-guarded in copyWith so null can be set explicitly), `outputModes` (`Set<ProjectionOutputMode>`), `blackoutOverride` (`bool`).
- `fromJson(Map)`: parses items, activeItemId, output modes (3-tier compat), blackoutOverride.

**Outputs**
- Public API: getters `isActive` (`outputModes.isNotEmpty`), `primaryMode` (first mode or `none`), `activeItem` (lookup by id), `copyWith`, `toJson`.
- `toJson`: `{items, activeItemId, windowOpen:isActive (IPC compat), outputModes:[names], blackoutOverride}`.

## Dependencies & Links
- Depends on: `projection_item.dart`, `projection_output_mode.dart` (not in allow-list)
- Used by: [[projection_output]] and all impls ([[projection_output_window]], [[projection_output_screencast]], [[projection_output_online]]), [[projection_ipc]], [[screencast_main]], [[player_window_main]], `ProjectionController`
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Multi-Window-IPC]]

## Key Logic / Variables
- The player window renders the active item via an `IndexedStack` for zero-latency switching; multiple items can be open at once.
- `outputModes` is a `Set` because multiple outputs can run simultaneously (e.g. second window + online fan-out). `primaryMode` exists for legacy single-icon status UI.
- **Backward-compat ladder in `_modesFromJson`**: (1) `outputModes` list of names → set; (2) legacy single `outputMode` string; (3) oldest payloads with only `windowOpen:bool` → `{secondWindow}` if true. `none` is always filtered out.
- `copyWith` uses a private `_sentinel` Object so `activeItemId: null` is distinguishable from "not provided".

## Notes
- `windowOpen` is still emitted in `toJson` purely for older player-window code paths that read it.
