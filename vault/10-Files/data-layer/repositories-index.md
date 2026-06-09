---
type: file-note
domain: data-layer
path: flutter_app/lib/data/repositories/
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# Repositories — index

> [!abstract] Primary Purpose
> The repository layer between application providers and the Drift store / remote datasources. Each `*_repository_impl` implements a `domain/repositories/*` interface. After the v12 Drift migration (PR-D3/D4) the persistence-backed repos route through DAOs on [[drift_database]]; two are thin in-memory shims over Riverpod state. Most interfaces are still `Map<String, dynamic>`-based (interface rename deferred).

## Inputs / Outputs
**Inputs**
- Providers watched / ctor deps: `appDatabaseProvider` ([[drift_database]]) for DB-backed repos; `ActiveCampaignNotifier` ([[campaign_provider]]) and `Ref` for the in-memory shims; `CloudBackupRemoteDataSource` + `betaProvider.quotaBytes` for cloud backup.
- Reads: DAOs (worlds/entities/characters/packages/installed-packages/trash) and remote datasources.

**Outputs**
- Providers: `campaignRepositoryProvider`, `characterRepositoryProvider`, `packageRepositoryProvider`, `cloudBackupRepositoryProvider`, `sessionRepositoryProvider`, `settingsRepositoryProvider`.
- Writes: their respective DAOs / Supabase Storage + Postgres (cloud backup).

## Dependencies & Links
- Depends on: [[drift_database]], [[daos-index]], [[remote-datasources-index]], [[campaign_provider]].
- Used by: application providers, `character_provider`, `package_provider`.
- Domain map: [[Data-Layer]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: `docs/full_drift_migration_plan.md`

## Key Logic / Variables
- **`world_repository_impl.dart`** → `WorldRepositoryImpl implements CampaignRepository` (provider `campaignRepositoryProvider`, ~25 KB). The campaign/world store (PR-D3 minimal rewrite of legacy `CampaignRepositoryImpl`). `worlds` row carries id/name/template_*/timestamps; `world_entities` rows carry entities; schema content + all other dynamic keys (combat_state, map_data, sessions, mind_maps, …) packed into `world_settings.settings_json` under key `_world_schema`. `_typedTopKeys` = {world_id, world_name, created_at, entities, world_schema, template_id/hash/original_hash}. Cross-pack ref / built-in synth via `builtin_synth.dart` + `srd_core_bootstrap`. See [[world_repository_impl]].
- **`character_repository.dart`** → `CharacterRepository` (provider `characterRepositoryProvider`). PR-D4 rewrite: characters ride `world_characters` Drift table via `WorldCharactersDao`. `loadAll()`/`loadAllWithLegacy()` (corrupt payloads skipped, sorted by `updatedAt` desc), `save()` upserts. Trash via `trash_items.kind='character'`. `CharacterLoadResult.legacyWorldNames` always empty under v12 fresh-cut. Treats `payloadJson` as opaque ([[character_resolver]] derives mechanics).
- **`package_repository_impl.dart`** → `PackageRepositoryImpl implements PackageRepository` (provider `packageRepositoryProvider`, ~18 KB). PR-D4 rewrite: routes through `PackagesDao` (Packages+Schemas+Entities) + `TrashDao`; old `package_local_ds.dart` sidecar JSON gone. `getPackageInfoList()` uses 3 lightweight queries (grouped count + first-schema-name) instead of 1+2N. Handles subspecies reclassify + parent softRef synth on load (see [[package_import_service]]).
- **`cloud_backup_repository_impl.dart`** → `CloudBackupRepositoryImpl implements CloudBackupRepository` (provider `cloudBackupRepositoryProvider`). JSON-encode + gzip → Supabase Storage `campaign-backups` bucket; metadata in Postgres `cloud_backups`. Shared by worlds/templates/packages. Constants: `cloudBackupItemSizeLimit` = 20 MB, `cloudBackupUserQuotaFallback` = 100 MB; runtime quota via `BetaQuotaResolver` callback (`betaProvider.quotaBytes`). Delegates to `CloudBackupRemoteDataSource` ([[remote-datasources-index]]).
- **`session_repository_impl.dart`** → `SessionRepositoryImpl implements SessionRepository` (provider `sessionRepositoryProvider`). In-memory shim over `ActiveCampaignNotifier.data` — reads/writes `combat_state` and `sessions[]` keys directly in the active campaign map (no DB).
- **`settings_repository_impl.dart`** → `SettingsRepositoryImpl implements SettingsRepository` (provider `settingsRepositoryProvider`). In-memory shim writing theme/locale/volume into `uiStateProvider` state (no DB).

## Notes
- Two repos (`session`, `settings`) intentionally never touch the DB — they proxy Riverpod state.
- Interface rename `CampaignRepository`→`WorldRepository` deferred to PR-D6.
