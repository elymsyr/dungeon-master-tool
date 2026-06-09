---
type: file-note
domain: combat-vtt
path: flutter_app/lib/presentation/screens/battle_map/battle_map_painter.dart
layer: presentation
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `grid_canvas.md` (real file: `battle_map_painter.dart`)

> [!abstract] Primary Purpose
> The main grid/battle-map render widget. There is NO `grid_canvas.dart` in the repo; the canonical grid + map renderer is `battle_map_painter.dart`, holding two `CustomPainter`s. `BattleMapPainter` renders all canvas-space layers (background image, grid, background vector shapes, annotation strokes, fog, fog draft) plus screen-space measurements/AoE templates. `BattleMapForegroundPainter` renders DM-only object/GM vector shapes + the live shape draft ABOVE the token widget layer. Repaint is driven by `Listenable`s so pan/zoom and in-progress strokes bypass widget rebuilds.

## Inputs / Outputs
**Inputs**
- Constructor deps: `BattleMapState mapState`, `ValueNotifier<ViewTransform> viewTransform`, `DmToolColors palette`, `bool isDmView`, `BattleMapNotifier notifier`, `ValueNotifier<int> strokeTick`, `ValueNotifier<int> shapeTick`.
- Reads: `mapState` (grid, image, strokes, fog image/draft, shapes, measurements, diagonalRule, gridSize/feetPerCell); live in-progress stroke/shape state read FROM `notifier` at paint-time.
- Providers / Supabase / CDC / Events: none directly — fed by [[combat_provider]] state via `battle_map_notifier`.
- Triggers: `super(repaint: Listenable.merge([viewTransform, strokeTick, shapeTick]))` — repaints on pan/zoom + stroke/shape ticks without rebuilding the painter.

**Outputs**
- Public API: `BattleMapPainter`, `BattleMapForegroundPainter` (both `CustomPainter`); top-level `paintShapeList(...)` helper.
- Writes / Supabase / events: none — render only.

## Dependencies & Links
- Depends on: [[combat_provider]], [[fog_externalizer]]
- Used by: [[battle_map_snapshot_builder]], [[battle_map_snapshot]], [[projection_output]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Layer order in `BattleMapPainter.paint` (all inside `save`/`translate(pan)`/`scale` except measurements): 1 background → 2 grid (if `gridVisible`) → 2.5 background-layer vector shapes → 3 annotation → 4 fog → 5 fog draft; `restore()`; then 6 measurements drawn in SCREEN-space.
- Grid: viewport-clipped for performance — only draws lines within the visible viewport (canvas-space) clamped to canvas bounds + one-cell margin. Cosmetic 1px pen: `strokeWidth = 1.0 / vt.scale`, color `0x37FFFFFF` (55/255 alpha, matches the legacy Python tool). Step = `mapState.gridSize`.
- In-progress strokes are read from `notifier.currentPath/currentColor/currentWidth/currentIsErase` AT PAINT-TIME, not captured at construction — otherwise the first stroke after a Consumer rebuild would be invisible (mouseDown doesn't trigger a Riverpod state change). Same pattern for `notifier.currentShapeDraft` in the foreground painter.
- Erase strokes use `BlendMode.clear` inside a `saveLayer` (only allocated when `hasErase`). A single mutable `strokePaint` is reused across all committed strokes (100+ on a busy map) to avoid per-stroke allocation; reusable `_aoeFill`/`_aoeStroke` Paints likewise.
- Fog: pre-rendered `ui.Image` drawn with opacity 0.5 for DM view, 1.0 for players (`isDmView` flag). Revealed areas are baked into the fog image via `BlendMode.clear`.
- Measurements/AoE (screen-space, post-restore): ruler, circle, and AoE templates (cone/line/circle/square/sector). 5e geometry: `_geoFeet` = euclidean canvas distance / gridSize * feetPerCell; `_geoSideFeet` = max axis side for cube/square. Ruler also shows squares = feet/feetPerCell. AoE sector has a 2-stage draft (radius guide → swept sector). Diagonal rule via `diagonalRuleFromInt(mapState.diagonalRule)` feeding `gridDistanceFeet`.
- AoE color: `m.colorHex ?? defaultAoeColorHex(m.type) ?? '#ff9800'`; default kept here (not in `hexToColor`) so DM/player null-color AoEs stay distinct (player uses literal `#ff9800`).
- Vector shapes split by `ShapeLayer.background` (drawn canvas-space under tokens by `BattleMapPainter`) vs object/GM layers (drawn screen-space ABOVE tokens by `BattleMapForegroundPainter`). GM shapes are DM-only by construction (never sent to players). `paintShapeList` takes a `project` fn + `scaleFactor` (1 inside a canvas transform, else `vt.scale`).
- `shouldRepaint`: only `mapState != old || isDmView != old` (transform/tick handled by the repaint Listenable).

## Notes
- PATH CORRECTION: requested glob `**/battle_map/grid_canvas.dart` does not exist. Note kept as `grid_canvas.md` so existing wikilinks resolve, but it documents `flutter_app/lib/presentation/screens/battle_map/battle_map_painter.dart` (the actual main grid render widget). Related files in the same dir: `battle_map_screen.dart`, `battle_map_notifier.dart`, `render/aoe_render.dart`.
