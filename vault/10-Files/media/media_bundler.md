---
type: file-note
domain: media
path: flutter_app/lib/application/services/media_bundler.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `media_bundler.dart`

> [!abstract] Primary Purpose
> Walks entity/world/character/map/settings JSON, uploads every local image to the right storage tier (counted Cloudflare R2 via `AssetService`, or free Supabase Storage via [[free_media_service]]), and rewrites the strings in place to portable refs (`dmt-asset://` / `dmt-public://`). All inputs are deep-cloned so the in-memory graph is untouched. SHA-dedupe (delegated to `AssetService.uploadAsset`) makes re-bundling cheap.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: `AssetService` (required, R2 counted uploads); optional [[free_media_service]] `FreeMediaService` (free portrait/cover uploads).
- Reads: local image files referenced in entity maps (`image_path`, `images[]`) and loose files in `{worldsDir}/{worldName}/media/`. JSON maps passed by caller.
- Supabase / CDC subscribed: none directly (via `FreeMediaService`).
- Events consumed: none.
- Triggers: world backup / Make-Online, F4 row-level outbox push, character/map/settings save.

**Outputs**
- Public API: `bundleWorldMedia` (full backup + manifest), `bundleEntityMedia` (per-row outbox), `bundleCharacterMedia`, `bundleMapMedia`, `bundleSettingsMedia`; static `sha256Of`. Result types `MediaBundleResult` / `MediaBundleFailure`.
- Writes (Drift tables): none — returns rewritten clones; caller persists.
- Supabase pushed / RPC called: R2 uploads via `AssetService.uploadAsset`; free uploads via `FreeMediaService.uploadFreeMedia`.
- Events emitted: none.

## Dependencies & Links
- Depends on: [[free_media_service]], `data/network/asset_service.dart` (`AssetService`), `domain/value_objects/asset_ref.dart` (`AssetRef`), `domain/value_objects/media_kind.dart` (`MediaKind`), `core/config/app_paths.dart` (`AppPaths.worldsDir`), `core/utils/deep_copy.dart`
- Used by: world backup/Make-Online flow, row-level outbox push, then [[media_manifest_restorer]] restores the manifest on the other device
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[worker]]

## Key Logic / Variables
- **`bundleWorldMedia`** (full): deep-clone → walk `entities` map (`image_path` legacy + `images[]`); for each local path call `uploadAndTrack` (upload → key from `dmt-asset://` substring → manifest entry `{r2_key, sha256, size_bytes, original_filename, referenced_by[]}`). Already-cloud refs are recorded via `trackExistingCloudRef` (so the restorer still downloads them into the new device's media dir). Then walks `{worldsDir}/{worldName}/media/` for loose gallery images **not** referenced by any entity and bundles them (`referenced_by: ['gallery']`). Attaches `media_manifest` + `media_manifest_version: 1`. Per-key dedupe via `seenKeys`; per-file failures collected (best-effort, never aborts).
- **Tier routing:** entities/maps/settings/world-extra-images → **counted** R2 (`_uploadCounted`); character **portrait** → **free** Supabase (`_uploadFree`, `MediaKind.characterPortrait`); character `images[]` → counted (`characterExtraImage`).
- **`MediaKind` mapping:** world entity = `worldEntityImage`, package entity = `packageEntityImage` (scopeId = world id or package name), map background = `battleMap` (10MB), mind map = `mindMapImage`. All non-battleMap kinds are 4MB.
- **`bundleSettingsMedia`** recursively walks `mind_maps`/`map_data`/`combat_state` subtrees, rewriting any local string under keys in `_settingsImageKeys` = `{imageUrl, image_path, imagePath, mapPath, map_path}`. Rescues offline-picked map images at Make-Online.
- **Invariants:** only `AssetRef(x).isLocal` paths are uploaded; existing cloud refs untouched. `_imageExts = {.png .jpg .jpeg .bmp .webp .gif}`.

## Notes
- Mixed Turkish/English comments. `bundleEntityMedia` skips the manifest pass (per-row pushes only need the entity itself).
