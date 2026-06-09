---
type: file-note
domain: combat-vtt
path: flutter_app/lib/data/database/daos/world_map_data_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_map_data_dao.md`

> [!abstract] Primary Purpose
> Tiny Drift DAO over the `WorldMapData` table — one row per world holding the serialized world-map state (image, eras, fog, grid, drawings). Single-row-per-world get/watch/upsert/delete.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase db`.
- Reads (Drift tables): `worldMapData`.
- Supabase / CDC / Events / Triggers: none.

**Outputs**
- Public API: `WorldMapDataDao` (`@DriftAccessor(tables: [WorldMapData])`).
  - `get(worldId) -> Future<WorldMapDataData?>`
  - `watch(worldId) -> Stream<WorldMapDataData?>` (`.distinct()`)
  - `upsert(WorldMapDataCompanion)` (`insertOnConflictUpdate`)
  - `deleteByWorld(worldId)`
- Writes (Drift): `worldMapData`.
- Supabase / events: none.

## Dependencies & Links
- Depends on: [[drift_database]], [[map_data]]
- Used by: [[daos-index]], [[map_pins_dao]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- One row per `worldId` (primary key). `watch` uses `watchSingleOrNull().distinct()`.
- Pure passthrough — no business logic; serialization of [[map_data]] models into the row is done by the caller (repository layer).

## Notes
- Stores world-map state; the per-encounter battle-map state is on `Encounter`/`combat_state` (see [[combat_provider]]), not here.
