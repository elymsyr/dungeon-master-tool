---
type: file-note
domain: media
path: flutter_app/lib/application/services/media_manifest_restorer.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `media_manifest_restorer.dart`

> [!abstract] Primary Purpose
> The restore counterpart to [[media_bundler]]. Given a world backup's `media_manifest`, it downloads every listed R2 asset via `AssetService` and mirrors it into `{worldsDir}/{worldName}/media/` so that (1) `dmt-asset://` entity image refs are already cached on first render, and (2) the media gallery's local scan shows them immediately without per-entity resolution. Failures are aggregated, never abort the restore.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: `AssetService` (required).
- Reads: the `media_manifest` list (each `{r2_key, sha256?, original_filename?, ...}`); downloads each `r2_key` to the content-store cache.
- Supabase / CDC subscribed: none (R2 download via worker through `AssetService`).
- Events consumed: none.
- Triggers: world restore / import after a backup produced by [[media_bundler]].

**Outputs**
- Public API: `restore({worldName, manifest})` → `MediaRestoreResult{restored, failures}`. Failure type `MediaRestoreFailure{r2Key, reason}`.
- Writes (Drift tables): none — copies cached files into `{worldsDir}/{worldName}/media/`.
- Supabase pushed / RPC called: `AssetService.downloadAsset(r2Key)`.
- Events emitted: none.

## Dependencies & Links
- Depends on: `data/network/asset_service.dart` (`AssetService.downloadAsset`, `extractShaFromKey`), `core/config/app_paths.dart` (`AppPaths.worldsDir`)
- Used by: world restore/import flow; consumes the manifest written by [[media_bundler]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[worker]]

## Key Logic / Variables
- **Loop:** ensure `{worldsDir}/{worldName}/media/` exists; for each manifest entry with a non-empty `r2_key`: `downloadAsset(key)` → cache file → `_pickTargetPath` → copy into media dir; increments `restored`, or records a `MediaRestoreFailure` on exception. Null/empty/non-map entries skipped.
- **`_pickTargetPath`** dedupe logic: preferred name = `original_filename` if present, else `{sha}{ext}` (sha via `AssetService.extractShaFromKey`, ext from `_extFromKey` = substring after last `.` in the key). If preferred path is free → use it. On name collision, compare **file sizes** as a cheap same-content proxy: equal size → return `null` (skip copy, still counts as restored); different → fall back to `{sha}{ext}` path; if that also exists → `null`.
- **Invariant:** restore is best-effort and idempotent — re-running after a partial restore re-uses already-present files rather than duplicating.

## Notes
- Note basename intentionally `media_manifest_restorer` (matches wikilink allow-list).
- Manifest shape is produced by [[media_bundler]] `bundleWorldMedia`; `sha256`/`size_bytes` may be absent for entries that were already cloud refs at bundle time.
