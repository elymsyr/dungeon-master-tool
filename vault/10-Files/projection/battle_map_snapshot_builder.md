---
type: file-note
domain: projection
path: flutter_app/lib/application/services/battle_map_snapshot_builder.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `battle_map_snapshot_builder.dart`

> [!abstract] Primary Purpose
> Pure (no Riverpod / no state) builder that converts a live `Encounter` + entity map + `WorldSchema` into a serializable [[battle_map_snapshot]]. It is the send-side gate that enforces player-visibility: hidden tokens and GM-layer shapes are filtered out *here* so they never reach the player at all (defence at the source, not the renderer).

## Inputs / Outputs
**Inputs**
- Args to `build()`: `Encounter encounter` (required), `Map<String,Entity> entities` (required), `WorldSchema? schema`, `Iterable<Character> characters`, `canvasWidth`/`canvasHeight` (default 2048×2048).
- Reads: `Encounter` fields (`combatants`, `tokenPositions`, `hiddenTokenIds`, `gridSize`, `tokenSize`, `tokenSizeMultipliers`, `fogData`, `mapPath`, `sceneVectorJson`, `showAllHp`, `hideTokenHud`, `feetPerCell`, `diagonalRule`, `turnIndex`), entity `imagePath`/`images`/`fields`/`categorySlug`, schema category colors.
- Supabase / CDC / events / triggers: none (pure function).

**Outputs**
- Public API: `static BattleMapSnapshot build({...})`, `static Future<(int,int)> measureCanvas(String? mapPath)`.
- Writes / Supabase / events: none.

## Dependencies & Links
- Depends on: [[battle_map_snapshot]], [[entity]], [[entity_category_schema]] (via `world_schema`), [[world_schema]]; `character.dart`, `session.dart` (Encounter/Combatant), `creature_size.dart`, `map_shape.dart`, `character_provider.dart` (`kPlayerCategorySlugs`) — not in allow-list
- Used by: `combat_provider.dart` / `ProjectionController` to build the snapshot pushed via the outputs
- Domain map: [[Projection-Second-Screen]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Combat-and-VTT]]

## Key Logic / Variables
- **Hidden-token filter**: `if (encounter.hiddenTokenIds.contains(c.id)) continue;` — hidden combatants never enter `tokens`, so position/HP/name never leave the DM.
- Token position: from `encounter.tokenPositions[c.id]` (Map `{x,y}`); fallback auto-grid layout `(col+1.5)*gs, (row+1.5)*gs`, wrapping after 4 columns.
- Entity resolution: `entities[c.entityId]` with a local `charEntities` fallback (PCs not yet injected into the entity provider still resolve → correct image, `isPlayer=true`, HP). `isPlayer = kPlayerCategorySlugs.contains(entity.categorySlug)`.
- **Token size**: manual `tokenSizeMultipliers[c.id]` wins; else 5e creature size drives a grid-anchored footprint `cells * gridSize / tokenSize` (via `tokenCellSpan`) so the player renders the same whole-cell footprint without leaking size data (just a number).
- `_resolveColor`: per-entity field override (`color`/`token_color`/`tokenColor`) > world-schema category color > neutral `#808080`. Mirrors the DM-side `_categoryColor`.
- Conditions → `ConditionSnapshot(name, turns=duration, imagePath=condition entity's first image)`.
- `_parseShapes(sceneVectorJson)`: decodes `{shapes:[...]}`, skips `ShapeLayer.gm` (GM-only, never projected), flattens points to `[x0,y0,...]`, maps to `ShapeSnapshot`.
- `measureCanvas(mapPath)`: reads the file, `ui.instantiateImageCodec`, returns pixel `(w,h)`; falls back to `(2048,2048)` on null/empty/error. Call once per map change for accurate canvas dims before `build`.

## Notes
- Default `(2048,2048)` is used when the background hasn't been measured yet; `feetPerCell`/`diagonalRule` are mirrored so player distance labels match the DM.
