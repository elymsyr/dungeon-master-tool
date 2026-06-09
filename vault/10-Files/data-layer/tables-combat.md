---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/tables/ (encounters_table, combatants_table, combat_conditions_table, map_pins_table, timeline_pins_table, world_map_data_table)
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Tables — Combat & Map group

> [!abstract] Primary Purpose
> Drift table definitions for combat (encounters / combatants / conditions) and map pins / timeline pins. These are **local-only** tables with **no Postgres counterpart** — they do not sync via CDC; their FKs follow the v12 `world_*` rename. `world_map_data` (the synced 1:1 map blob) is summarized in [[tables-worlds]] but cross-referenced here since map state spans both.

## Inputs / Outputs
**Inputs**
- Reads: consumed by [[combat_dao]] (`Encounters`+`Combatants`+`CombatConditions`), [[map_pins_dao]] (`MapPins`), `TimelinePinsDao` (`TimelinePins` — see [[daos-index]]), [[world_map_data_dao]] (`WorldMapData`).
- Triggers: `currentDateAndTime` default on `createdAt` (encounters).

**Outputs**
- Public API: Drift row classes `Encounter`, `Combatant`, `CombatCondition`, `MapPin`, `TimelinePin` + Companions.

## Dependencies & Links
- Depends on: `package:drift`; FKs to `Worlds`, `WorldSessions`, `WorldEntities` ([[tables-worlds]]).
- Used by: [[combat_provider]], [[combat_dao]], [[grid_canvas]], [[map_data]].
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[Combat-and-VTT]]

## Key Logic / Variables
- **`Encounters`** (local-only): PK `id`. FKs `sessionId`→`WorldSessions`, `worldId`→`Worlds`. Cols: `name`, `mapPath?`, `tokenSize` (40), `gridSize` (50), `gridVisible` (true), `gridSnap` (true), `feetPerCell` (5), `fogData?` (text), `annotationData?` (text), `encounterLayoutId?`, `turnIndex` (-1), `round` (1), `tokenPositionsJson` (`{}`), `tokenSizeMultipliersJson` (`{}`), `sortOrder` (0), `createdAt`. Indexed by `session_id`.
- **`Combatants`** (local-only): PK `id`. FK `encounterId`→`Encounters`, nullable `entityId`→`WorldEntities`. Cols: `name`, `init` (0), `ac` (10), `hp` (10), `maxHp` (10), `tokenId?`, `sortOrder` (0). Indexed by `encounter_id`.
- **`CombatConditions`** (local-only): autoIncrement int PK `id`. FK `combatantId`→`Combatants`. Cols: `name`, `duration?`, `initialDuration?`, `entityId?`. (Only int-PK table in the schema.)
- **`MapPins`** (local-only): PK `id`. FK `worldId`→`Worlds`, nullable `entityId`→`WorldEntities`. Cols: `x`/`y` (real), `label`, `pinType` (`'default'`), `note`, `color`, `styleJson` (`{}`). Indexed by `world_id`.
- **`TimelinePins`** (local-only): PK `id`. FK `worldId`→`Worlds`. Cols: `x`/`y` (real), `day` (0), `note`, `entityIdsJson` (`[]`), `sessionId?`, `parentIdsJson` (`[]`), `color`. Indexed by `world_id`.
- **`WorldMapData`** (synced, PG `world_map_data` mig 042, 1:1 world): PK `worldId`, `dataJson` (`{}`), `updatedAt`. (Full detail in [[tables-worlds]].)

## Notes
- FK cascades are manual because the DB runs `PRAGMA foreign_keys=OFF` (see [[drift_database]]) — e.g. `CombatDao.deleteEncounter` deletes conditions→combatants→encounter in a transaction.
- Combat/map state does not appear in the CDC sync set; only `WorldMapData` syncs. Battlemap collaborative marks ride the raw `bm_mark_ops_local` side table (see [[tables-sync]] / [[battlemap_marks_protocol]]).
