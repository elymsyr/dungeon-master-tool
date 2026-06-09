---
type: file-note
domain: combat-vtt
path: flutter_app/lib/data/database/daos/map_pins_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `map_pins_dao.md`

> [!abstract] Primary Purpose
> Drift DAO over the `MapPins` table — the world-map pins (entity/location markers placed on the world map). Per-world get-by-id/watch/upsert (single + batch)/delete.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase db`.
- Reads (Drift tables): `mapPins`.
- Supabase / CDC / Events / Triggers: none.

**Outputs**
- Public API: `MapPinsDao` (`@DriftAccessor(tables: [MapPins])`).
  - `getById(id) -> Future<MapPin?>`
  - `watchByWorld(worldId) -> Stream<List<MapPin>>` (`.distinct()`)
  - `upsert(MapPinsCompanion)` / `upsertAll(rows)` (batch `insertAllOnConflictUpdate`)
  - `deleteById(id)` / `deleteByWorld(worldId)`
- Writes (Drift): `mapPins`.
- Supabase / events: none.

## Dependencies & Links
- Depends on: [[drift_database]], [[map_data]]
- Used by: [[daos-index]], [[world_map_data_dao]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- Pins are scoped by `worldId`; `watchByWorld` streams the full list with `.distinct()`.
- `upsertAll` uses a Drift `batch` for bulk pin writes (e.g. importing/restoring a world's pin set).
- Pure passthrough — no business logic.

## Notes
- The `MapPin` row type here is the Drift-generated table class; the domain-layer `MapPin` freezed model lives in [[map_data]] (names collide but are different types).
