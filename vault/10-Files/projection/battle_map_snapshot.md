---
type: file-note
domain: projection
path: flutter_app/lib/domain/entities/projection/battle_map_snapshot.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `battle_map_snapshot.dart`

> [!abstract] Primary Purpose
> JSON-clean, IPC/CDC-transportable snapshot of a battle map's player-visible state. Deliberately excludes `ui.Image`/`Path` objects — only file paths, base64 fog bitmap, and primitive token/stroke/shape/measurement data. The DM rebuilds it whenever combat/battle-map state changes (via [[battle_map_snapshot_builder]]); the player decodes it once per push and renders.

## Inputs / Outputs
**Inputs**
- Constructor fields (all primitives): `mapPath?`, `fogDataBase64?`, `canvasWidth/Height` (def 2048), `gridSize` (50), `gridVisible`, `feetPerCell` (5), `diagonalRule` (index, 0=euclidean), `sceneVectorJson`, `showAllHp`, `hideTokenHud`, `tokenSize` (50), `tokenSizeMultipliers`, `tokens`, `turnIndex` (-1), `strokes`, `measurements`, `shapes`, `viewportNormalized?`.
- `fromJson(Map)`: tolerant — missing keys default; reads legacy `conditionNames` flat list too.

**Outputs**
- Public API: `copyWith` (with `clearViewport`/`clearFog` flags), `toJson` (omits defaults/empties to shrink payload), nested `toJson`/`fromJson` on each sub-class.
- Sub-types: `TokenSnapshot`, `ConditionSnapshot`, `StrokeSnapshot`, `MeasurementSnapshot`, `ShapeSnapshot`, `NormalizedRect`.

## Dependencies & Links
- Depends on: none (pure value object, no imports beyond Dart)
- Used by: [[battle_map_snapshot_builder]] (producer), [[projection_output_online]], [[projection_ipc]], [[screencast_main]], the player battle-map renderer, [[projection_state]] (carried inside `BattleMapProjection`)
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Combat-and-VTT]]

## Key Logic / Variables
- `schemaVersion = 4` (emitted as `_v`). Version ladder: v1 mixed raw-path/AssetRef; v2 AssetRef-only (player resolver falls back for v1); v3 additive `sceneVectorJson`; v4 additive typed `shapes`. All additive → older clients tolerate missing keys.
- `viewportNormalized` (`NormalizedRect`, 0..1 `left/top/w/h`): the canvas sub-rect the player should show. `null` = fit whole canvas. Player computes its own scale+offset (BoxFit.contain), so DM/player aspect ratios can differ and still mirror in proportion. [[projection_output_online]] clears it per-push so remote viewers pan freely.
- `showAllHp`: reveals monster/NPC HP (bar + numeric); default only `isPlayer` tokens show HP. `hideTokenHud`: drops HP bar + condition badge (name stays).
- `StrokeSnapshot`: flat `[x0,y0,...]` polyline (smaller JSON), colorHex, width — only committed *reveal* strokes (erase strokes not projected).
- `MeasurementSnapshot`: type `ruler`/`circle`/`cone`/`line`/`aoeCircle`/`square`/`sector`, two canvas-space endpoints, optional `colorHex`, optional `sweepDeg` (sector only). Commit-time only.
- `ShapeSnapshot`: stable enum indexes `kind`/`layer` (ShapeKind/ShapeLayer), flat points, colorHex (`#ffca28`), strokeWidth, filled, text/fontSize (text kind). GM-layer filtered out *before* projection in the builder.
- `TokenSnapshot`: id, name, x, y, imagePath?, colorHex (`#888888`), isPlayer, hp/maxHp/init, `conditions` (with `conditionNames` legacy getter).
- `ConditionSnapshot`: name, turns? (null = indefinite), imagePath? (condition entity art).

## Notes
- All `toJson` use short keys (`p`,`c`,`w`,`a`,`b`,`t`,`s`,`k`,`l`,`f`,`fs`,`n`,`i`) to keep fog-heavy payloads small over IPC/CDC.
