---
type: file-note
domain: projection
path: flutter_app/lib/application/services/projection_output_online.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `projection_output_online.dart`

> [!abstract] Primary Purpose
> Online `ProjectionOutput` that mirrors the projection manifest into the Supabase `world_projection` table (one row per world, single JSON `state_json` blob). Remote players receive the row via the world CDC channel and render it in `PlayerSecondScreenTab`. There is no local surface and no external-close signal — `deactivate` deletes the row so a late joiner sees "nothing shared".

## Inputs / Outputs
**Inputs**
- Constructor deps: `SupabaseClient client`, `String worldId`.
- Reads: in-memory `_last` (`ProjectionState`) — the last full state, used to merge patches since the column is one blob.
- Supabase / CDC subscribed: none on the write side (players subscribe via world CDC elsewhere).
- Events consumed: none.
- Triggers: `_bmCoalesceTimer` (debounce timer) for battle-map patches.

**Outputs**
- Public API: implements `ProjectionOutput`.
- Writes (Supabase): `world_projection` upsert (`world_id`, `state_json`=`jsonEncode(json)`, `updated_by`=auth user id, `updated_at`); `deactivate` does `delete().eq('world_id', worldId)`.
- RPC called: none.
- Events emitted: none (`onExternalClose` never fires).

## Dependencies & Links
- Depends on: [[projection_output]], [[projection_state]], [[battle_map_snapshot]]; `projection_item.dart`, `image_view_state.dart`, `asset_ref.dart` (not in allow-list)
- Used by: `online_projection_provider.dart` / `ProjectionController` when the online fan-out mode is active; consumed remotely by `player_second_screen_tab.dart`
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[CDC-Sync-Flow]], [[Media-Storage-Tiers]]

## Key Logic / Variables
- `pushFull` stores `_last` then `_upsert`s. `pushPatch` merges the patch onto `_last.toJson()` (`addAll(patch)`), re-parses, re-upserts (whole blob re-uploaded — patches are not partial DB writes).
- **Tiered battle-map debounce**: `_fastBmDebounce = 120ms`, `_slowBmDebounce = 500ms`. A patch is "heavy" if it contains `strokes`, `measurements`, `shapes`, or `fogDataBase64` → 500ms; otherwise (viewport/token moves) → 120ms. Each call cancels and resets `_bmCoalesceTimer`, so at most ~8 writes/sec reach `world_projection` even under continuous token dragging. The merged snapshot is held in `_last` and flushed when the timer fires.
- `_stripNavState(state)`: before every upsert, resets `ImageProjection.viewState` to default and `BattleMapProjection.snapshot.copyWith(clearViewport: true)` so the remote viewer pans/zooms locally without being yanked by the DM's viewport.
- `_warnRawPaths(json)` (assert-only, debug): recursively scans `state_json` for raw filesystem paths (slash + `.png/.jpg/.jpeg/.webp/.gif`) that aren't `AssetRef` (`scheme`/`publicScheme`/`transientScheme`). The caller (entity image prepare step) must have uploaded them first; this just logs early.
- **Failure semantics**: a failed `_upsert` does NOT kill the output (last-write-wins; next push reconciles). Only explicit `deactivate` ends the session.

## Notes
- Live battle-map collab data (token moves, drawings) flows through the separate Faz-D `world_battlemap_marks` layer — `pushBattleMapPatch` here only mutates the manifest blob (which item active + coalesced snapshot), kept low-frequency on purpose.
