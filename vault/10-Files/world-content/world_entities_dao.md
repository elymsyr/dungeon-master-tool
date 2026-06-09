---
type: file-note
domain: world-content
path: flutter_app/lib/data/database/daos/world_entities_dao.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_entities_dao.dart`

> [!abstract] Primary Purpose
> Drift accessor for the `world_entities` table — the per-world content rows (NPCs, monsters, spells, classes, species, etc.). Provides id/world/category lookups, watch streams, single + batch upserts, and id/world-scoped deletes that back row-level save and package sync.

## Inputs / Outputs
**Inputs**
- Reads (Drift table): `world_entities` (`WorldEntities` table; `WorldEntity` row type).

**Outputs**
- Public API: `getById(id)`, `getByWorld(worldId)`, `watchByWorld(worldId)` (distinct), `watchByCategory(worldId, categorySlug)` (distinct), `upsert(row)` / `upsertAll(rows)` (batch `insertAllOnConflictUpdate`), `deleteById(id)`, `deleteByIds(ids)` (no-op on empty list), `deleteByWorld(worldId)`.
- Writes (Drift): `world_entities`.

## Dependencies & Links
- Depends on: [[tables-worlds]], [[drift_database]]
- Used by: [[world_repository_impl]], [[package_sync_service]], [[entity]] (`EntityNotifier`)
- Domain map: [[World-and-Content]]
- System flow:
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- `deleteByIds` short-circuits `Future.value(0)` on an empty id list (avoids an empty `IN ()` query).
- `watchByCategory` ANDs `worldId == X & categorySlug == Y`; backs category-tab streaming.
- All upserts use `insertOnConflictUpdate` keyed on `id`; batch variant uses Drift `batch(...)` for the bulk replace / package-sync paths.

## Notes
- The `WorldEntity` row carries: id, worldId, categorySlug, name, source, description, imagePath, imagesJson, tagsJson, dmNotes, pdfsJson, locationId, fieldsJson (attributes), packageId, packageEntityId, linked, updatedAt. See [[world_repository_impl]] `_entityCompanion` for the map<->row mapping.
