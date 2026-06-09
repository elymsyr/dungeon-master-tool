---
type: file-note
domain: combat-vtt
path: flutter_app/lib/data/database/daos/combat_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `combat_dao.dart`

> [!abstract] Primary Purpose
> Drift DAO over the normalized combat table family — `Encounters`, `Combatants`, `CombatConditions` — providing CRUD + watch streams. Local-only (no cloud mirror). Manual cascade delete (FK constraints are off, so deleting an encounter manually removes its combatants and their conditions).

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase db`.
- Reads (Drift tables): `encounters`, `combatants`, `combatConditions`.
- Supabase / CDC / Events: none — local-only.
- Triggers: none.

**Outputs**
- Public API: `CombatDao` (`@DriftAccessor(tables: [Encounters, Combatants, CombatConditions])`).
  - Encounters: `getEncounter(id)`, `watchEncounters(sessionId)` (ordered by `sortOrder`), `upsertEncounter`, `deleteEncounter(id)`.
  - Combatants: `getCombatants(encounterId)`, `watchCombatants(encounterId)`, `upsertCombatant`, `upsertCombatants` (batch), `deleteCombatant(id)`.
  - Conditions: `watchConditions(combatantId)`, `insertCondition`, `deleteCondition(id)`.
- Writes (Drift): all three tables.
- Supabase / events: none.

## Dependencies & Links
- Depends on: [[drift_database]], [[tables-combat]]
- Used by: [[daos-index]], [[combat_provider]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- `deleteEncounter` runs in a `transaction`: collects combatant ids for the encounter, deletes their `combatConditions`, then the `combatants`, then the encounter row — manual cascade because FKs are disabled.
- `deleteCombatant` similarly deletes the combatant's conditions first inside a transaction.
- All upserts use `insertOnConflictUpdate`; batch upsert uses `batch(b => b.insertAllOnConflictUpdate(...))`.
- Watch streams append `.distinct()` to suppress duplicate emissions; ordered by `sortOrder` ascending.

## Notes
- IMPORTANT: This DAO is NOT the live combat-tab storage path. [[combat_provider]] persists encounters/combatants inside `world_settings.settings_json['combat_state']` (a JSON blob), NOT this normalized table family. Confirm any caller before assuming this DAO drives the session UI — at audit time the table family appears to be a parallel/legacy normalized representation.
