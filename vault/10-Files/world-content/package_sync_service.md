---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/package_sync_service.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `package_sync_service.dart`

> [!abstract] Primary Purpose
> Live-link reconciliation between an installed package's `package_entities` and a world's `world_entities`. Keeps linked rows in lockstep with the pack (insert new, overwrite changed, delete removed) while leaving user-detached homebrew copies alone. Also handles uninstall with detached-survival semantics.

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase _db`.
- `sync(worldId, packageId, resolveAttrs?)` — `resolveAttrs` translates Tier-0 lookup placeholders embedded in pack attrs.
- `uninstall(worldId, packageId, purgeDetached, extraScrubSlugs, extraScrubSource)`.
- Reads: `packagesDao.getEntities(packageId)`, world `world_entities` rows scoped by `packageId`.

**Outputs**
- Returns `PackageSyncResult(added, updated, removed, detachedSurvived)`.
- Writes (Drift): `world_entities` (batch upsert + `deleteByIds`), `installed_packages` (upsert `lastSyncedAt` on sync; `deleteOne` on uninstall). All in one `_db.transaction`.

## Dependencies & Links
- Depends on: [[packages_dao]], [[world_entities_dao]], [[drift_database]]
- Used by: package install/uninstall flows, world load self-heal
- Domain map: [[World-and-Content]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: [[Content-Pipeline]]

## Key Logic / Variables
- **Sync rules** (matched by `packageEntityId`): new pack entity -> insert as `linked:true`; existing & `linked` -> overwrite from pack; existing & detached -> leave alone; removed pack entity & `linked` -> delete; removed & detached -> keep but clear `packageId`/`packageEntityId` and set `source: 'Homebrew'` (now full homebrew).
- **ID strategy**: builds `packToWorld` map up front — existing rows reuse their world UUIDs, new pack rows get fresh UUIDs minted now so same-batch cross-references resolve in one pass.
- **`_remapPackRefs`** walks attrs and rewrites any string matching a `packToWorld` key to the world-side UUID — fixes inter-Tier-1 relations (class_refs, trait_refs, action_refs, ...) that pack rows store as pack-side UUIDs.
- **`uninstall`**: `purgeDetached:false` (default) deletes linked rows, keeps detached as homebrew; `true` deletes everything tied to the pack. `extraScrubSlugs` (only when `purgeDetached`) wipes legacy Tier-0 lookup rows seeded without a `packageId` (matched by category slug + `packageId IS NULL`, optionally narrowed by `extraScrubSource`).
- Batched: all upserts collected into one list, single `upsertAll`; deletes collected into one `deleteByIds`.

## Notes
- Counterpart to the one-shot [[package_import_service]] copy-in. `resolveAttrs` is null when pack rows already store resolved IDs.
