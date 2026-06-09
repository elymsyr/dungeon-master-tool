---
type: file-note
domain: world-content
path: flutter_app/lib/data/database/daos/worlds_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `worlds_dao.dart`

> [!abstract] Primary Purpose
> Thin Drift accessor for the `worlds` table — the top-level row that carries each campaign's id, name, template lineage hashes, and timestamps. CRUD + indexed name lookup + watch streams + cloud-push bookkeeping.

## Inputs / Outputs
**Inputs**
- Reads (Drift table): `worlds` (`Worlds` table; `World` row type).

**Outputs**
- Public API: `getAll()`, `watchAll()` (ordered by `updatedAt` desc, distinct), `getById(id)`, `getByName(name)` (indexed — used by `WorldRepositoryImpl._findByName`), `watchById(id)`, `upsert(row)` / `upsertAll(rows)` (`insertOnConflictUpdate`), `deleteById(id)`, `updateCloudPush(id, pushedAt, pushedHash)`.
- Writes (Drift): `worlds` (incl. `lastCloudPushAt`, `lastPushedHash` columns).

## Dependencies & Links
- Depends on: [[tables-worlds]], [[drift_database]]
- Used by: [[world_repository_impl]], [[campaign_provider]], [[world_mirror_service]], [[world_reconciler]]
- Domain map: [[World-and-Content]]
- System flow:
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- `getByName` runs `select(worlds)..where(worldName == name)` and returns the first match (no uniqueness constraint on name; first-wins). This is the SS-1/DB-3 indexed path replacing the old linear scan.
- `upsert` = `insertOnConflictUpdate` (requires NOT-NULL `worldName`, so the repo uses a raw `update` for timestamp-only touches).
- `updateCloudPush` records `lastCloudPushAt`/`lastPushedHash` — the per-world cloud-sync watermark used by the reconciler/mirror to detect whether the local row diverged since the last push.

## Notes
- 57-line generated-companion DAO; no business logic — all sync/merge decisions live upstream.
