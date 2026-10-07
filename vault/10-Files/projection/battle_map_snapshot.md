---
type: file-note
domain: projection
path: flutter_app/lib/domain/entities/projection/battle_map_snapshot.dart
layer: domain
language: dart
status: stable
updated: 2026-10-07
tags: [file]
---

# `battle_map_snapshot.dart`

> [!abstract] Primary Purpose
> JSON-clean, IPC/CDC-transportable snapshot of a battle map's player-visible state. Deliberately excludes `ui.Image`/`Path` objects — only file paths, base64 fog bitmap, and primitive token/stroke/shape/measurement data. The DM rebuilds it whenever combat/battle-map state changes (via [[battle_map_snapshot_builder]]); the player decodes it once per push and renders.

## Inputs / Outputs
**Inputs**
- Constructor fields (all primitives): `mapPath?`, `fogDataBase64?`, `canvasWidth/Height` (def 2048), `gridSize` (50), `gridVisible`, `feetPerCell` (5), `diagonalRule` (index, 0=euclidean), `sceneVectorJson`, `showAllHp`, `hideTokenHud`, `tokenSize` (50), `tokenSizeMultipliers`, `tokens`, `turnIndex` (-1), `strokes`, `measurements`, `shapes`, `trails`, `moveAck?`, `viewportNormalized?`.
- `fromJson(Map)`: tolerant — missing keys default; reads legacy `conditionNames` flat list too.

**Outputs**
- Public API: `copyWith` (with `clearViewport`/`clearFog` flags), `toJson` (omits defaults/empties to shrink payload), nested `toJson`/`fromJson` on each sub-class.
- Sub-types: `TokenSnapshot`, `ConditionSnapshot`, `StrokeSnapshot`, `MeasurementSnapshot`, `ShapeSnapshot`, `TrailSnapshot`, `NormalizedRect`.

## Dependencies & Links
- Depends on: none (pure value object, no imports beyond Dart)
- Used by: [[battle_map_snapshot_builder]] (producer), [[projection_output_online]], [[projection_ipc]], [[screencast_main]], the player battle-map renderer, [[projection_state]] (carried inside `BattleMapProjection`)
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Combat-and-VTT]]

## Key Logic / Variables
- `schemaVersion = 6` (emitted as `_v`). Version ladder: v1 mixed raw-path/AssetRef; v2 AssetRef-only (player resolver falls back for v1); v3 additive `sceneVectorJson`; v4 additive typed `shapes`; v5 additive `trail`; v6 `trails` (list) replaces `trail` — a v5 client shows no trails, a v6 client ignores a v5 DM's `trail`. Otherwise additive → older clients tolerate missing keys.
- `TrailSnapshot` (`i` id, `p` flat path ending at the token, `s` stops = path indexes where each drag began, `c` colour): one token's movement trail; `trails` holds every token moved this round ([[grid_canvas]] `tokenMoves`), least recent first. Pushed by `BattleMapNotifier._pushTrailToProjection` (50 ms throttle, held back while the DM is still dragging any token; per-drag RDP + 0.1 px rounding via `trailSnapshotOf`, stops kept exact) through `ProjectionController.updateBattleMapTrails` as a `{'trails': [...]}` patch — every push re-sends all of them. Trails whose token is not in `tokens` (hidden/removed) are never sent and are dropped when the token disappears (`updateBattleMapSnapshot`). `tryParse`/`parseList` drop malformed trails and out-of-range stops. Player window `_mergePatch` replaces `trails` wholesale. Value equality (`==`) so unchanged trails are not re-pushed.
- `MoveAck` (`moveAck`: `i` combatant id, `s` seq): the last owner move (migration 108 `p_seq`) the DM applied, sent in the same `updateBattleMapTrails` patch as the trail it produced (`trails: null` = ack only, e.g. while the DM is dragging). The owning player keeps its optimistic position/trail until this reaches its last call's number, then shows the DM's state.
- `viewportNormalized` (`NormalizedRect`, 0..1 `left/top/w/h`): the canvas sub-rect the player should show. `null` = fit whole canvas. Player computes its own scale+offset (BoxFit.contain), so DM/player aspect ratios can differ and still mirror in proportion. [[projection_output_online]] clears it per-push so remote viewers pan freely.
- `showAllHp`: reveals monster/NPC HP (bar + numeric); default only `isPlayer` tokens show HP. `hideTokenHud`: drops HP bar + condition badge (name stays).
- `StrokeSnapshot`: flat `[x0,y0,...]` polyline (smaller JSON), colorHex, width — only committed *reveal* strokes (erase strokes not projected).
- `MeasurementSnapshot`: type `ruler`/`circle`/`cone`/`line`/`aoeCircle`/`square`/`sector`, two canvas-space endpoints, optional `colorHex`, optional `sweepDeg` (sector only). Commit-time only.
- `ShapeSnapshot`: stable enum indexes `kind`/`layer` (ShapeKind/ShapeLayer), flat points, colorHex (`#ffca28`), strokeWidth, filled, text/fontSize (text kind). GM-layer filtered out *before* projection in the builder.
- `TokenSnapshot`: id, name, x, y, imagePath?, colorHex (`#888888`), isPlayer, hp/maxHp/init, `conditions` (with `conditionNames` legacy getter).
- `ConditionSnapshot`: name, turns? (null = indefinite), imagePath? (condition entity art).

## Notes
- All `toJson` use short keys (`p`,`c`,`w`,`a`,`b`,`t`,`s`,`k`,`l`,`f`,`fs`,`n`,`i`) to keep fog-heavy payloads small over IPC/CDC.
