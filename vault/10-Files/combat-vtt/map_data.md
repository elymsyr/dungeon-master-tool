---
type: file-note
domain: combat-vtt
path: flutter_app/lib/domain/entities/map_data.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `map_data.md`

> [!abstract] Primary Purpose
> Freezed/json_serializable domain models for the WORLD map (the campaign world/region map with eras + timeline pins), distinct from the per-encounter battle map. Defines `MapData`, `MapPin`, `TimelinePin`, `MapEra`, `LocationMapData`, and `EraWaypoint`. These are immutable value objects with JSON round-trip; the era-scoped maps support time-traveling world views (per-era images sourced from the location entity's `map_per_era`).

## Inputs / Outputs
**Inputs**
- Constructor deps: none — pure data classes; constructed from JSON or copyWith.
- Reads / Supabase / CDC / Events / Triggers: none — domain layer, no IO.

**Outputs**
- Public API (all `@freezed`):
  - `MapData`: `imagePath`, `pins: List<MapPin>`, `timeline: List<Map>`, `gridSize` (default 50), `gridVisible`, `gridSnap`, `feetPerCell` (default 5), `fogState: Map`, `drawings: List<Map>`.
  - `MapPin`: `id`, `x`, `y`, `label`, `pinType` (default `'default'`), `entityId?`, `note`, `color`, `style: Map`.
  - `TimelinePin`: `id`, `x`, `y`, `day` (default 1), `note`, `entityIds: List<String>`, `sessionId?`, `parentIds: List<String>`, `color` (default `#42a5f5`), `style: Map`.
  - `MapEra`: `id`, `imagePath`, `pins`, `timelinePins`, `locationMaps: Map<String, LocationMapData>`.
  - `LocationMapData`: `pins`, `timelinePins` (nested drill-in collection).
  - `EraWaypoint`: `id`, `label` — separator on the era scroll bar.
- Writes / Supabase / events: none.

## Dependencies & Links
- Depends on: (freezed/json_serializable only)
- Used by: [[map_pins_dao]], [[world_map_data_dao]], [[grid_canvas]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[World-and-Content]]

## Key Logic / Variables
- Two grid-bearing concepts: `MapData.gridSize/gridVisible/gridSnap/feetPerCell` describe the world-map overlay (NOT the encounter battle-map grid, which lives on `Encounter` fields in [[combat_provider]]).
- `MapEra.locationMaps` holds per-location nested pin collections for drill-in; the era's background image is NOT stored here — it's pulled from the location entity's `map_per_era[era.id]` (falls back to `map`).
- `LocationMapData` background image likewise comes from `map_per_era[eraId]` on the location entity.
- All models have `fromJson` factories; freezed generates `copyWith` + equality (`map_data.freezed.dart` / `.g.dart`).

## Notes
- This is the WORLD/region map model. The battle/VTT map state is carried on `Encounter` (see [[combat_provider]]), not here — header note ("Sprint 3'te detaylandırılacak") reflects its early-stage origin.
