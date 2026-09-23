---
type: file-note
domain: projection
path: flutter_app/lib/application/services/projection_output_online.dart
layer: application
language: dart
status: stable
updated: 2026-09-23
tags: [file]
---

# `projection_output_online.dart`

> [!abstract] Primary Purpose
> Online `ProjectionOutput` that mirrors the projection manifest into the Supabase `world_projection` table (one row per world, single JSON `state_json` blob). Remote players receive the row via the world CDC channel and render it in `PlayerSecondScreenTab`. There is no local surface and no external-close signal — `deactivate` deletes the row so a late joiner sees "nothing shared".

## Inputs / Outputs
**Inputs**
- Constructor deps: `SupabaseClient client`, `String worldId`, `SharedMediaCourier courier`.
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
- Spec / reference: [[Share-Broadcast-Flow]], [[Media-Storage-Tiers]]

## Key Logic / Variables
- `pushFull` stores `_last` then `_upsert`s. `pushPatch` merges the patch onto `_last.toJson()` (`addAll(patch)`), re-parses, re-upserts (whole blob re-uploaded — patches are not partial DB writes).
- **Tiered battle-map debounce**: `_fastBmDebounce = 120ms`, `_slowBmDebounce = 500ms`. A patch is "heavy" if it contains `strokes`, `measurements`, `shapes`, or `fogDataBase64` → 500ms; otherwise (viewport/token moves) → 120ms. Each call cancels and resets `_bmCoalesceTimer`, so at most ~8 writes/sec reach `world_projection` even under continuous token dragging. The merged snapshot is held in `_last` and flushed when the timer fires.
- `_stripNavState(state)`: before every upsert, resets `ImageProjection.viewState` to default and `BattleMapProjection.snapshot.copyWith(clearViewport: true)` so the remote viewer pans/zooms locally without being yanked by the DM's viewport.
- **`withPublishedMedia(json, publish)` (top-level, pure walk) — the send-side media gate.** Was `_warnRawPaths`: an assert-only debug log that *noticed* raw filesystem paths in `state_json` and left them there, on the assumption that every caller had run its own prepare step first. Battle map projection never had one, so `mapPath`, token portraits and condition art went out as `C:\…\media\x.png` and every remote player rendered a broken image. The walk now rewrites each local media path to the `dmt-content://` ref returned by `_publishMedia` (→ [[world_media_sync]] `publish`, Faz 5d: a path already in the world's cloud media — every image a row mentions, uploaded by the push round — returns its ref without touching the network; only images no row mentions, like a package monster's token, are uploaded), and only falls back to the raw path (with a `debugPrint`) when the upload fails or no worker is configured. Doing it here — the single exit to the cloud — covers every item type at once, so `projectableMapImage` / `prepareEntityImagesForProjection` at the call sites are now belt-and-suspenders (they return refs, which the walk skips). `isProjectableLocalMedia` is the filter: non-empty, ≤1024 chars (keeps the fog base64 blob out of the regex), image extension, `AssetRef.isLocal`. `_publishCache` memoizes per path *including failures* — `_upsert` fires ~8×/s under token drag and re-hashing the same background every tick would be absurd. Covered by `test/application/services/projection_media_publish_test.dart`.
- **Failure semantics**: a failed `_upsert` does NOT kill the output (last-write-wins; next push reconciles). Only explicit `deactivate` ends the session.

## Notes
- Live battle-map collab data (token moves, drawings) flows through the separate Faz-D `world_battlemap_marks` layer — `pushBattleMapPatch` here only mutates the manifest blob (which item active + coalesced snapshot), kept low-frequency on purpose.
