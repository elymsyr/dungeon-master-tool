---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/app_database.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `app_database.dart`

> [!abstract] Primary Purpose
> The `@DriftDatabase` core — `AppDatabase`, a per-user SQLite (Drift) database that is a **flat mirror of the Supabase Postgres schema**. Schema version is **12** ("fresh-cut": all v1–v11 migration steps were deleted; any pre-v12 file is renamed to a forensic backup and a fresh v12 DB is created). It registers 25 Drift tables + 20 DAOs, applies hot-path indexes, tunes PRAGMAs, and idempotently creates four raw side tables that codegen deliberately avoids.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none directly. Opened via `_openConnectionForUser(userId)` using `AppPaths.dataRoot`; `userId` from `activeUserIdProvider` (in `database_provider.dart`).
- Reads (DAOs / Drift tables): all 25 tables (see list below) + raw side tables `asset_refs`, `sync_telemetry`, `migration_progress`, `bm_mark_ops_local`.
- Supabase / CDC subscribed: none (this is the local store; CDC apply targets these tables — see [[world_mirror_applier]]).
- Events consumed: none.
- Triggers (timers, connectivity, lifecycle): `beforeOpen` runs on every open; `onCreate`/`onUpgrade` on schema (re)create.

**Outputs**
- Providers / public API exposed: `AppDatabase` (default + `.forUser(userId)` + `.forTesting(e)` ctors); all DAO getters (`worldsDao`, `worldEntitiesDao`, `combatDao`, `syncOutboxDao`, `trashDao`, …). Exposed via `appDatabaseProvider` (`database_provider.dart`).
- Writes (Drift tables): all.
- Supabase pushed / RPC called: none.
- Events emitted: none.

## Dependencies & Links
- Depends on: `app_database.g.dart` (codegen), `AppPaths`, the `tables/` family ([[tables-worlds]], [[tables-combat]], [[tables-packages]], [[tables-sync]]), and all DAOs ([[daos-index]], plus standalone [[worlds_dao]], [[world_entities_dao]], [[combat_dao]], [[sync_outbox_dao]], [[world_members_dao]], [[world_invites_dao]], [[world_map_data_dao]], [[map_pins_dao]]).
- Used by: [[world_repository_impl]], [[character_resolver]] (read-time via `world_characters`), [[repositories-index]], DAO consumers across all domains.
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: `docs/full_drift_migration_plan.md` (PR-D0 fresh-cut)

## Key Logic / Variables
- **Schema v12**, 25 tables registered in `@DriftDatabase`:
  - World group: `Worlds, WorldMembers, WorldInvites, WorldEntities, WorldCharacters, WorldMindMapNodes, WorldMindMapEdges, WorldSessions, WorldMapData, WorldSettings, WorldPackages` ([[tables-worlds]]).
  - Sharing/packages: `EntityShares, CharacterClaimPool, PersonalPackages, Packages, PackageSchemas, PackageEntities, InstalledPackages` ([[tables-packages]]).
  - Sync/trash: `SyncOutbox, TrashItems` ([[tables-sync]]).
  - Combat/map (local-only): `Encounters, Combatants, CombatConditions, MapPins, TimelinePins` ([[tables-combat]]).
- **20 DAOs** registered: Worlds, WorldMembers, WorldInvites, WorldEntities, WorldCharacters, WorldMindMap, WorldSessions, WorldMapData, WorldSettings, WorldPackages, EntityShares, CharacterClaimPool, PersonalPackages, Packages, InstalledPackages, SyncOutbox, Trash, Combat, MapPins, TimelinePins.
- **Side tables** (`_sideTablesDDL`, raw SQL, `CREATE TABLE IF NOT EXISTS`, run in `beforeOpen`, no schema bump): `asset_refs` (AssetRef→owner-row graph for eviction sweeper), `sync_telemetry` (F12 latency histogram buckets), `migration_progress` (F11 raw-path migrator resume state, also gates one-time repairs), `bm_mark_ops_local` (F8 mirror of server `world_battlemap_mark_ops`).
- **PRAGMA tuning** (every open): `journal_mode=WAL`, `synchronous=NORMAL`, `temp_store=MEMORY`, `mmap_size=64MB`, **`foreign_keys=OFF`** — lets CDC apply land out-of-order events without parent-first ordering; parent-exists checks are done at app level on apply.
- **Index block** `_v12Indexes` (S1 perf): hot-path indexes incl. `idx_world_entities_world`, `idx_world_entities_category (world_id, category_slug)`, `idx_world_characters_owner/updated`, `idx_outbox_next_attempt (next_attempt_at, created_at)`, `idx_outbox_table_pk (target_table, target_pk, op_type)` for outbox coalescing, `idx_trash_kind_deleted`.
- **`beforeOpen` one-time repairs** (gated via `migration_progress`): `subspecies_reclassify_v1` promotes legacy `species` rows whose description starts `*Subspecies of X.*` to `category_slug='subspecies'` + injects `parent_species_ref` softRef via `json_set`; plus best-effort `trashDao.purgeOlderThan(now-30d)`.
- **DB file path / fresh-cut** (`_openConnectionForUser`): `AppPaths.dataRoot/db/dmt.sqlite` (or `.../users/{userId}/db/dmt.sqlite`). Legacy `getApplicationSupportDirectory/DungeonMasterTool/...` file copied once (marked `.moved_to_dataroot`). Any pre-v12 file is renamed to `dmt.sqlite.legacy.<unix-ms>` (marker `.v12_cut_applied`), kept 30 days then purged. Uses `NativeDatabase.createInBackground`.

## Notes
- Companion `database_provider.dart`: `activeUserIdProvider` (StateProvider) + `appDatabaseProvider` (Provider) — changing the active user opens a new user-scoped DB and disposes the old one, cascade-invalidating all downstream DAO/repo providers.
- Generated `app_database.g.dart` is ~872 KB — do not read directly; rely on this note + table notes.
- `foreign_keys=OFF` is intentional and load-bearing for CDC; manual cascades live in DAOs (e.g. `CombatDao.deleteEncounter`).
