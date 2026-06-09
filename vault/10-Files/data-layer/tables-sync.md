---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/tables/sync_outbox_table.dart, trash_items_table.dart + raw side tables in app_database.dart (asset_refs, sync_telemetry, migration_progress, bm_mark_ops_local)
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Tables — Sync, Outbox & raw side tables

> [!abstract] Primary Purpose
> The persistence backbone for cloud sync. **`sync_outbox`** is the coalescing per-row push queue (v12 PR-D5: per-row ops, not per-kind blobs). **`trash_items`** is the soft-delete store (replaces the legacy `/trash/` directory) and doubles as the "user-intent: deleted" gate so cloud pulls don't resurrect trashed rows. Four **raw side tables** (created with `CREATE TABLE IF NOT EXISTS` in [[drift_database]]'s `beforeOpen`, no Drift codegen, no schema bump) round out the sync infra: `asset_refs`, `sync_telemetry`, `migration_progress`, `bm_mark_ops_local`.

## Inputs / Outputs
**Inputs**
- Reads: `sync_outbox` consumed by [[sync_outbox_dao]] (and the drainer [[sync_engine]]); `trash_items` by `TrashDao` ([[daos-index]]); raw tables read directly via `customSelect`/`customStatement`.
- Triggers: outbox `nextAttemptAt` controls drain eligibility; trash purge runs in `beforeOpen` (30-day retention).

**Outputs**
- Public API: Drift rows `SyncOutboxRow` (`@DataClassName`), `TrashItem` + Companions; raw tables have no generated classes.

## Dependencies & Links
- Depends on: `package:drift`.
- Used by: [[sync_engine]], [[sync_outbox_dao]], [[sync_tier]], [[pending_write_buffer]], [[world_mirror_service]], [[battlemap_marks_protocol]] (via `bm_mark_ops_local`).
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[Sync-and-Realtime]], `flutter_app/docs/auto_save_sync_redesign_may17.md`

## Key Logic / Variables
- **`SyncOutbox`** (`@DataClassName('SyncOutboxRow')`): PK `opId` (UUID v4, stable across retries). Cols: `targetTable` (PG table name e.g. `world_entities`), `targetPk` (target row PK; composite PKs serialized like `worldId:packageId`), `opType` (`upsert`|`delete`), `scopeId?` (worldId for fan-out filters), `payloadJson` (row snapshot; deletes are `{}`+tombstone meta), `payloadBytes` (0), `attempts` (0), `createdAt`, `lastAttemptAt?`, `nextAttemptAt` (default now), `lastError?`.
  - **Coalescing invariant**: idempotency keyed on `(targetTable, targetPk, opType)` — enqueue overwrites the payload + resets `attempts`/`lastError`/`lastAttemptAt` of any existing pending row instead of inserting a new one (prevents bloat under rapid typing). Slow-tier callers pass `nextAttemptAt = now + cloudDelay` to batch within a coalesce window; `createdAt` always tracks the real enqueue moment for stable drain order. Indexes: `idx_outbox_next_attempt (next_attempt_at, created_at)`, `idx_outbox_table_pk (target_table, target_pk, op_type)`.
- **`TrashItems`** (replaces legacy `/trash/` dir): PK `id`. Cols: `kind` (`entity`/`character`/`package`/…), `sourceId` (original row id), `payloadJson`, `deletedAt`. Indexed by `(kind, deleted_at)`. `TrashDao.existsBySource(kind, sourceId)` is the "user already deleted this" gate against resurrection; `purgeOlderThan(now-30d)` runs in `beforeOpen`.
- **Raw side tables** (defined in `_sideTablesDDL` in [[drift_database]]):
  - `asset_refs` — PK `(uri, owner_table, owner_id, owner_field)` + `world_id?`, `last_seen_at`. AssetRef→owner-row graph for the eviction sweeper's orphan detection. Indexed by uri / owner / world.
  - `sync_telemetry` — PK `(metric, bucket)` + `count`, `sum_ms`, `last_at`. F12 latency histogram buckets.
  - `migration_progress` — PK `(migration_name, world_id)` + `last_id?`, `completed`, `updated_at`. F11 raw-path migrator resume state; also gates one-time repairs like `subspecies_reclassify_v1`.
  - `bm_mark_ops_local` — PK `op_id` + `world_id`, `encounter_id`, `author_id`, `kind`, `payload_json`, `seq`, `created_at`. F8 local mirror of server `world_battlemap_mark_ops`; indexed by `(world_id, encounter_id, seq)`.

## Notes
- `sync_outbox` retry backoff (markFailed / nextAttemptAt scheduling) is driven by the drainer in [[sync_engine]], not by these tables.
- Side tables are intentionally raw SQL to avoid Drift codegen and schema bumps; treat them as fixed contracts — any column change must update `_sideTablesDDL` in [[drift_database]].
