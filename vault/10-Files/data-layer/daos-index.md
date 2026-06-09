---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/daos/
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# DAOs — index

> [!abstract] Primary Purpose
> Catalog of all `@DriftAccessor` DAOs registered on [[drift_database]] (20 total). Each is a thin Drift accessor over its table(s) with the same shape: `getById`/`get`, `watchBy*` (`.watch().distinct()` streams), `upsert`/`upsertAll` (`insertOnConflictUpdate`, batched), and `deleteBy*`. This note documents the DAOs **without their own dedicated note**; the rest are cross-referenced to their standalone notes.

## Inputs / Outputs
**Inputs**
- Reads: their respective Drift tables ([[tables-worlds]], [[tables-packages]], [[tables-combat]], [[tables-sync]]).
- Triggers: streams emit on any matching table write.

**Outputs**
- Public API: per-DAO query/mutation methods, surfaced via `AppDatabase` DAO getters.

## Dependencies & Links
- Depends on: [[drift_database]], the `tables/` family.
- Used by: [[repositories-index]], [[world_mirror_applier]], [[world_membership_service]], [[character_claim_service]], `package_repository_impl`.
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[World-and-Content]], [[Multiplayer-and-Online]]

## Key Logic / Variables

### DAOs documented HERE (no standalone note)
- **`WorldCharactersDao`** (`world_characters_dao.dart`) — opaque-blob char store. `getAllChars()` (hub cold-load, all rows, no ownership filter), `watchById/watchByWorld/watchByOwner/watchOrphans(worldId)` (orphan = world set, owner NULL), `upsert/upsertAll`, `deleteById/deleteByWorld`, **`dropOwnership(id)`** (set ownerId NULL — used on world import). **Invariant: never parse/re-serialize `payloadJson`.**
- **`WorldSessionsDao`** (`world_sessions_dao.dart`) — sessions ordered by `sortOrder`; `getById`, `getByWorld/watchByWorld`, `upsert/upsertAll`, `deleteById/deleteByWorld`.
- **`WorldSettingsDao`** (`world_settings_dao.dart`) — 1:1 settings blob; `get/watch(worldId)` (single-or-null), `upsert`, `deleteByWorld`.
- **`WorldMindMapDao`** (`world_mind_map_dao.dart`) — accesses BOTH `WorldMindMapNodes` + `WorldMindMapEdges`; node/edge `watch*/get*(worldId, mapId)`, `upsertNode(s)/upsertEdge(s)`, `deleteNode/deleteEdge`, and **`replaceMap(worldId, mapId, {nodes, edges})`** (transactional delete-then-batch-insert of a whole map).
- **`WorldPackagesDao`** (`world_packages_dao.dart`) — DM-shared world↔package state; `getByPackage`, `getByWorld/watchByWorld`, **`getAll()`** (every link row, for the hub Worlds-tab world→packageNames map without N+1), `upsert/upsertAll`, `deleteByPackage/deleteByWorld`.
- **`EntitySharesDao`** (`entity_shares_dao.dart`) — `getByWorld/watchByWorld`, **`watchForUser(worldId, userId)`** (rows where `sharedWith == userId` OR NULL), `upsert/upsertAll`, `deleteById/deleteByWorld`.
- **`CharacterClaimPoolDao`** (`character_claim_pool_dao.dart`) — `get(characterId)`, **`watchAvailable(worldId)`** (worldId & available==true), `upsert/upsertAll`, `deleteById`.
- **`PersonalPackagesDao`** (`personal_packages_dao.dart`) — composite-key store; `get(ownerId, packageName)`, `watchByOwner(ownerId)`, `upsert/upsertAll`, `deleteOne`.
- **`PackagesDao`** (`packages_dao.dart`) — accesses `Packages`+`PackageSchemas`+`PackageEntities`. Beyond CRUD: **`firstSchemaNameByPackage()`** (projects only id+name, skips big JSON blobs), **`countEntities(id)`** / **`countEntitiesByPackage()`** (grouped count — never materializes the ~1000–1500 SRD rows, DB-2 perf; gates SRD bootstrap CS-1), `updateCloudPush(id, pushedAt, pushedHash)`, plus `upsertEntities` batch.
- **`InstalledPackagesDao`** (`installed_packages_dao.dart`) — `get(worldId, packageId)`, `getByWorld/watchByWorld`, `upsert`, `deleteOne/deleteByWorld`, **`countWorldsForPackage(packageId)`** (purge-safety gate on world leave).
- **`TrashDao`** (`trash_dao.dart`) — soft-delete; `getByKind/watchByKind` (desc `deletedAt`), `getById`, **`existsBySource(kind, sourceId)`** (anti-resurrection gate), `upsert`, `deleteById`, **`purgeOlderThan(cutoff)`** (30-day retention, called in `beforeOpen`).
- **`TimelinePinsDao`** (`timeline_pins_dao.dart`) — `getById`, `watchByWorld`, `upsert/upsertAll`, `deleteById/deleteByWorld`.

### DAOs with their own note (cross-reference only)
- [[worlds_dao]] — `Worlds` CRUD + `updateCloudPush`.
- [[world_entities_dao]] — `WorldEntities` CRUD incl. `watchByCategory`, `deleteByIds`.
- [[world_members_dao]] — `WorldMembers` (composite key) + `watchByUser`.
- [[world_invites_dao]] — `WorldInvites` by `code`.
- [[world_map_data_dao]] — 1:1 `WorldMapData` blob.
- [[combat_dao]] — `Encounters`+`Combatants`+`CombatConditions`, manual cascade deletes.
- [[map_pins_dao]] — `MapPins` CRUD.
- [[sync_outbox_dao]] — coalescing outbox queue (`enqueueCoalesced`, `readyBatch`, `markFailed`, `watchPendingCount`).

## Notes
- Standard pattern: all `watch*` use `.distinct()`; all `upsert*` use `insertOnConflictUpdate`; `upsertAll` wraps `batch(b.insertAllOnConflictUpdate)`.
- Because `PRAGMA foreign_keys=OFF` (see [[drift_database]]), DAOs that delete parents do manual cascades in a `transaction` (e.g. `CombatDao.deleteEncounter`, `WorldMindMapDao.replaceMap`).
