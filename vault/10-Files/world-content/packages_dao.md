---
type: file-note
domain: world-content
path: flutter_app/lib/data/database/daos/packages_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `packages_dao.dart`

> [!abstract] Primary Purpose
> Drift accessor for the local package catalog — the three sibling tables `Packages`, `PackageSchemas`, `PackageEntities`. CRUD + watch streams plus count-only / projection-only queries that avoid materializing the large JSON blobs.

## Inputs / Outputs
**Inputs**
- Reads (Drift tables): `packages`, `package_schemas`, `package_entities`.

**Outputs**
- Packages: `getById`, `getByName`, `getAll`, `watchAll` (desc `updatedAt`, distinct), `upsertPackage`, `deletePackage`, `updateCloudPush(id, pushedAt, pushedHash)`.
- Schemas: `getSchemas`, `firstSchemaNameByPackage()`, `upsertSchema`, `deleteSchemasByPackage`.
- Entities: `getEntities`, `countEntities(id)`, `countEntitiesByPackage()`, `watchEntities`, `upsertEntity` / `upsertEntities` (batch), `deleteEntity`, `deleteEntitiesByPackage`.
- Writes (Drift): `packages`, `package_schemas`, `package_entities`.

## Dependencies & Links
- Depends on: [[tables-packages]], [[drift_database]]
- Used by: [[package_sync_service]], [[bundled_packs_bootstrap]], [[world_repository_impl]] (purge of orphaned packages), [[srd_core_pack]] bootstrap
- Domain map: [[World-and-Content]]
- System flow:
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- **DB-2 perf projections**: `firstSchemaNameByPackage()` uses `selectOnly` projecting only `packageId + name` (skips the big categories/encounter JSON just to label a pack); `countEntitiesByPackage()` is one grouped `COUNT(id)` query instead of materializing rows to call `.length` (packages with zero entities are absent from the map).
- **`countEntities(id)`** (CS-1) — single-package count via `selectOnly` + `id.count()`; used by the SRD/bundled bootstrap freshness gate instead of `getEntities(id).isNotEmpty`.
- `updateCloudPush` records `lastCloudPushAt`/`lastPushedHash` for package cloud-sync watermarking (mirrors `worlds`).
- All upserts are `insertOnConflictUpdate`; batch entity upsert uses Drift `batch(...)`.

## Notes
- Local catalog only. Personal (per-user cloud) packages live in [[personal_packages_dao]].
