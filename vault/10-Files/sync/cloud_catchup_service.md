---
type: file-note
domain: sync
path: flutter_app/lib/application/services/cloud_catchup_service.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `cloud_catchup_service.dart`

> [!abstract] Primary Purpose
> App-start best-effort pull from `cloud_backups` for packages and characters (worlds were intentionally removed from this path). For each cloud backup row newer than the local copy (or missing locally) it downloads and saves it, then pushes still-local worldless-character portraits to free media. Silently skipped when offline, not signed in, or not in the beta program. This is the "catch up on what changed while I was away" pull; the push side is handled by `[[sync_engine]]`.

## Inputs / Outputs
**Inputs**
- Constructor: `Ref _ref`.
- Gates: `SupabaseConfig.isConfigured`, `authProvider`, `isBetaActiveProvider`.
- Reads cloud: `cloudBackupRepositoryProvider.listBackupsByType('package')` + `downloadBackup`; `characterListProvider.notifier.pullNewerFromCloud()`.
- Reads local: `packageListProvider` + `packageRepository.load` (`last_modified`/`updated_at`), `characterListProvider`, `betaEnterGateProvider.isCompleted(uid)`, `freeMediaServiceProvider`.

**Outputs**
- `packageRepository.save(name, fresh)` then invalidates `packageListProvider`.
- Character portrait uploads via `uploadCharacterPortraitRef` (→ `dmt-public://`), then `characterListProvider.notifier.update`.
- Deletes orphaned cloud meta (`repo.deleteOrphanedMeta`) when `downloadBackup` 404s (`isStorageNotFound`).

## Dependencies & Links
- Depends on: [[beta_enter_gate]], [[free_media_service]], `character_provider`, `cloudBackupRepositoryProvider`, [[package_import_service]] (via package repo)
- Used by: app startup wiring (runs `runAll` after sign-in)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]

## Key Logic / Variables
- **`runAll`:** gate checks → `Future.wait([_pullPackages, _pullCharacters])` → `_pushLocalPortraits`. Worlds explicitly NOT pulled here (a snapshot pull would resurrect a deleted world; online worlds sync via `worlds` row + `[[world_reconciler]]` Sync button instead).
- **`_pullPackages`:** for each `cloud_backups` package meta, skip when `localAt != null && !meta.createdAt.isAfter(localAt)` (local is fresh). Beta-enter wipe guard: if beta-enter not completed and the package exists locally, skip the pull (`PackageRepositoryImpl._saveToDb` full-replaces entities, so a stale/empty cloud row would wipe offline content).
- **`_pullCharacters`:** delegates to `characterListProvider.notifier.pullNewerFromCloud()`.
- **`_pushLocalPortraits`:** worldless characters only (world-bound portraits bundle on the `world_characters` mirror push). Uploads `entity.imagePath` if `AssetRef(portrait).isLocal`; rewrites the ref via `update`.
- **Offline handling:** every method wraps in try/catch and returns silently on `isOfflineError(e)`.

## Notes
- Best-effort, fire-and-forget; failures only `debugPrint`. Complements (does not replace) the realtime CDC + outbox paths.
