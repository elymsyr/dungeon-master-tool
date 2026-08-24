---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/tables/trash_items_table.dart + raw side tables in app_database.dart (asset_refs, migration_progress, lan_paired_devices)
layer: data
language: dart
status: stable
updated: 2026-08-24
tags: [file]
---

# Tables — Trash & raw side tables

> [!abstract] Primary Purpose
> **`trash_items`** is the soft-delete store (replaces the legacy `/trash/` directory). Three **raw side tables** (created with `CREATE TABLE IF NOT EXISTS` in [[drift_database]]'s `beforeOpen`, no Drift codegen, no schema bump) sit alongside it: `asset_refs`, `migration_progress`, `lan_paired_devices`.

> [!warning] `sync_outbox` kaldırıldı (2026-08-24)
> Bulut sync ile birlikte `sync_outbox`, `sync_telemetry`, `bm_mark_ops_local` ve `personal_packages` düştü. Mevcut v12 DB'lerinde artık satırlar duruyordu; `beforeOpen` içindeki `_retiredTablesDDL` onları `DROP TABLE IF EXISTS` ile temizliyor. **`schemaVersion` 12'de kaldı** — v13'e çıkmak her kullanıcının DB'sini `.legacy` yapıp sıfırlardı, oysa kaybolan tek şey ölü tablo.

## Inputs / Outputs
**Inputs**
- Reads: `trash_items` by `TrashDao` ([[daos-index]]); raw tables read directly via `customSelect`/`customStatement`.
- Triggers: trash purge runs in `beforeOpen` (30-day retention).

**Outputs**
- Public API: Drift row `TrashItem` + Companion; raw tables have no generated classes.

## Dependencies & Links
- Depends on: `package:drift`.
- Used by: `TrashDao`, [[pending_write_buffer]], the eviction sweeper (via `asset_refs`), the LAN branch (via `lan_paired_devices`).
- Domain map: [[Data-Layer]]
- System flow: [[Share-Broadcast-Flow]]
- Spec / reference: [[Sync-and-Realtime]], `flutter_app/docs/auto_save_sync_redesign_may17.md`

## Key Logic / Variables
- **`TrashItems`** (replaces legacy `/trash/` dir): PK `id`. Cols: `kind` (`entity`/`character`/`package`/…), `sourceId` (original row id), `payloadJson`, `deletedAt`. Indexed by `(kind, deleted_at)`. `TrashDao.existsBySource(kind, sourceId)` is the "user already deleted this" gate against resurrection; `purgeOlderThan(now-30d)` runs in `beforeOpen`.
- **Raw side tables** (defined in `_sideTablesDDL` in [[drift_database]]):
  - `asset_refs` — PK `(uri, owner_table, owner_id, owner_field)` + `world_id?`, `last_seen_at`. AssetRef→owner-row graph for the eviction sweeper's orphan detection. Indexed by uri / owner / world.
  - `migration_progress` — PK `(migration_name, world_id)` + `last_id?`, `completed`, `updated_at`. F11 raw-path migrator resume state; also gates one-time repairs like `subspecies_reclassify_v1`.
  - `lan_paired_devices` — PK `device_id` + `name`, `last_address`, `shared_secret`, `paired_at`, `last_seen_at`. Kalıcı LAN cihaz eşleşmeleri; `shared_secret` iki cihazda aynıdır (bkz. [[LAN-Sync-Flow]]).

## Notes
- Side tables are intentionally raw SQL to avoid Drift codegen and schema bumps; treat them as fixed contracts — any column change must update `_sideTablesDDL` in [[drift_database]].
