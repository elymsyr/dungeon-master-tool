---
type: file-note
domain: data-layer
path: flutter_app/lib/data/database/tables/ (packages_table, package_entities_table, package_schemas_table, personal_packages_table, installed_packages_table, entity_shares_table, character_claim_pool_table)
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Tables — Packages, Shares & Claim group

> [!abstract] Primary Purpose
> Drift table definitions for the **content-package catalog** (local hub catalog: `packages` + `package_schemas` + `package_entities`), the synced **personal package** state (`personal_packages`, PG mig 033), per-world **installed-package live-link** tracking (`installed_packages`), plus the multiplayer sharing primitives **entity shares** (`entity_shares`, mig 026) and the DM **character claim pool** (`character_claim_pool`, mig 026).

## Inputs / Outputs
**Inputs**
- Reads: consumed by [[packages_dao]] (`Packages`+`PackageSchemas`+`PackageEntities`), [[personal_packages_dao]] (`PersonalPackages`), `InstalledPackagesDao` (`InstalledPackages`), `EntitySharesDao` (`EntityShares`), `CharacterClaimPoolDao` (`CharacterClaimPool`) — all in [[daos-index]].
- Triggers: `currentDateAndTime` defaults on timestamp columns.

**Outputs**
- Public API: Drift row classes `Package`, `PackageSchema`, `PackageEntity`, `PersonalPackage`, `InstalledPackage`, `EntityShare`, `CharacterClaimPoolData` + Companions.

## Dependencies & Links
- Depends on: `package:drift`; FKs to `Worlds`, `WorldCharacters` ([[tables-worlds]]), `Packages`.
- Used by: `package_repository_impl`, [[package_import_service]], [[package_sync_service]], [[character_claim_service]], [[world_schema]].
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[World-and-Content]], [[Content-Pipeline]]

## Key Logic / Variables
- **`Packages`** (local hub catalog, no PG counterpart — `personal_packages` carries the sync state): PK `id`. Cols: `name`, `stateJson` (`{}`), `createdAt`, `updatedAt`, `lastCloudPushAt?`, `lastPushedHash?`.
- **`PackageEntities`** (local, v11 shape): PK `id`. FK `packageId`→`Packages`. Cols mirror `world_entities` minus world fields: `categorySlug`, `name`, `source`, `description`, `imagePath`, `imagesJson` (`[]`), `tagsJson` (`[]`), `dmNotes`, `pdfsJson` (`[]`), `locationId?`, `fieldsJson` (`{}`), `createdAt`, `updatedAt`. Indexed by `package_id`.
- **`PackageSchemas`** (local, v11 shape): PK `id`. FK `packageId`→`Packages`. Cols: `name`, `version` (`'1.0'`), `baseSystem?`, `description`, `categoriesJson` (`[]`), `encounterConfigJson` (`{}`), `encounterLayoutsJson` (`[]`), `metadataJson` (`{}`), `templateId?`, `templateHash?`, `templateOriginalHash?`, `createdAt`, `updatedAt`.
- **`PersonalPackages`** (PG `personal_packages`, mig 033 — the synced package state): composite PK `{ownerId, packageName}`. Cols: `stateJson` (`{}`), `createdAt`, `updatedAt`.
- **`InstalledPackages`** (tracks packs installed into a world; live-link enables pack add/update/remove propagation; detached/user-edited entities survive removal as homebrew): composite PK `{worldId, packageId}`. FK `worldId`→`Worlds`. Cols: `packageName`, `packageVersion`, `installedAt`, `lastSyncedAt`.
- **`EntityShares`** (PG `entity_shares`, mig 026 — DM "Paylaş" records; `sharedWith` NULL = visible to ALL world members): PK `id`. FK `worldId`→`Worlds`. Cols: `entityId`, `sharedWith?`, `sharedBy`, `sharedAt`. Indexed by `world_id` and `(world_id, shared_with)`.
- **`CharacterClaimPool`** (PG `character_claim_pool`, mig 026 — DM-marked "available for claim" characters): PK `characterId`. FKs `characterId`→`WorldCharacters`, `worldId`→`Worlds`. Cols: `available` (true), `claimedBy?`, `claimedAt?`, `createdAt`. Indexed by `(world_id, available)`.

## Notes
- `PackagesDao` provides aggregate-only queries (`countEntitiesByPackage`, `firstSchemaNameByPackage`) to avoid materializing the ~1000–1500 SRD rows for list views (DB-2 perf, see [[daos-index]]).
- `InstalledPackagesDao.countWorldsForPackage` gates whether a materialized package is safe to purge on world-leave.
