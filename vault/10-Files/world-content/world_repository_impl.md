---
type: file-note
domain: world-content
path: flutter_app/lib/data/repositories/world_repository_impl.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_repository_impl.dart`

> [!abstract] Primary Purpose
> The v12 Drift-backed implementation of `CampaignRepository`. Translates the legacy `Map<String,dynamic>` world blob into normalized rows across `worlds`, `world_entities`, `world_settings`, `world_map_data`, `world_sessions`, and back. Handles create (with built-in SRD bootstrap), load (with built-in synthesis + schema overlay), row-level + bulk save, trash/restore, and the full cascade purge.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AppDatabase _db`.
- Reads (DAOs): `worldsDao`, `worldSettingsDao`, `worldEntitiesDao`, `worldMapDataDao`, `worldSessionsDao`, `installedPackagesDao`, `trashDao`, `packagesDao` (purge), plus `entitySharesDao`, `worldMembersDao`, `worldInvitesDao`, `worldPackagesDao`, `mapPinsDao`, `timelinePinsDao` (purge cascade).
- Built-in bootstrap: `SrdCorePackageBootstrap`, `SrdCoreBootstrap`, `generateBuiltinDnd5eV2Schema()`, `synthesizeWorldBuiltins`.

**Outputs**
- Public API: implements `CampaignRepository` — `getAvailable`, `load`, `create`, `save`, `saveEntity`, `deleteEntity`, `saveSettingsPatch`, `saveMapData`, `saveSessions`/`saveSession`/`deleteSession`, `delete`, `purge`, `restoreFromTrash`, `permanentlyDelete`, `installedPackages`.
- Writes (Drift): `worlds`, `world_settings`, `world_entities`, `world_map_data`, `world_sessions`, `trash_items` (+ cascade deletes across membership/share/pin/package-link tables on purge).

## Dependencies & Links
- Depends on: [[worlds_dao]], [[world_entities_dao]], [[packages_dao]], [[world_schema]], [[srd_core_pack]], [[tables-worlds]], [[drift_database]]
- Used by: [[campaign_provider]] (via `campaignRepositoryProvider`)
- Domain map: [[World-and-Content]]
- System flow:
- Spec / reference: [[Data-Layer]]

## Key Logic / Variables
- **Storage split** (PR-D3 v12): `worlds` row = id/name/template_*/timestamps. `world_entities` rows = entities. Everything else dynamic (combat_state, mind_maps, map_view, ...) packed into `world_settings.settings_json`. Schema content rides in `settings_json` under key `_world_schema` (`_schemaSettingsKey`) — the legacy `world_schemas` table is gone.
- **`_typedTopKeys`**: `world_id, world_name, created_at, entities, world_schema, template_id, template_hash, template_original_hash` — excluded from the settings blob.
- **`_findByName`** uses indexed `worldsDao.getByName` (SS-1/DB-3 — replaced `getAll()` + linear scan on every debounced write; 12 call sites).
- **`load` (`_loadFromDb`)**: decodes settings blob, pops `_world_schema`, joins `world_entities` rows into an entities map (tracking `package_entity_id` coverage), then **self-heals** built-in worlds (re-links SRD pack + re-imports) and runs `synthesizeWorldBuiltins` (F1 — built-in pack rows live once in `package_entities`, synthesized per-world rather than duplicated). Built-in schema snapshots are passed through `_overlayMissingBuiltinCategories` so older worlds pick up newly-added built-in categories (e.g. `subspecies`) without a per-world migration; custom categories preserved. Granular `world_map_data` + `world_sessions` rows OVERRIDE anything leaked into the settings blob (reopen-survives-force-close fix).
- **`create`**: requires a template (throws otherwise); computes `currentHash`/`originalHash`; writes `worlds` + schema snapshot; if `templateId == builtinDnd5eV2SchemaId` runs `SrdCorePackageBootstrap.ensureInstalled` + `SrdCoreBootstrap.ensureImported`.
- **`save` (`_saveToDb`)**: bulk path — full-replace `world_entities` ONLY when payload contains the `entities` key (PR-B5 beta-enter wipe defense: a metadata-only payload must NOT wipe rows). Entries flagged `synthFlagKey` (built-in synth) are never persisted. `_touchWorld` is UPDATE-only (INSERT path needs NOT-NULL worldName).
- **`saveSessions`** strips typed columns (id/name/is_active/sort_order) from the inner blob and writes them to dedicated `world_sessions` columns.
- **`_purgeWorld`** (cascade): captures package links first, deletes entities/settings/map_data/sessions/installed-packages, then drops any materialized package whose only home was this world (skips `srdCorePackageName`; survives if `countWorldsForPackage > 0`), then clears shares/members/invites/world-packages/map-pins/timeline-pins, finally the `worlds` row.
- `_builtinCategoryJsonCache` caches the generated built-in category JSON (generator is deterministic except timestamps).

## Notes
- PR-D5 intended to split map_data/sessions/mind_maps to typed tables for granular CDC — map_data + sessions done; mind_maps still in the blob.
