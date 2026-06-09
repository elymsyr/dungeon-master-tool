---
type: file-note
domain: media
path: flutter_app/lib/application/services/entity_media_cleanup_service.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `entity_media_cleanup_service.dart`

> [!abstract] Primary Purpose
> When an entity (character / world / package) or one of its cover/image refs is deleted or replaced, this service deletes the corresponding cloud media objects — counted Cloudflare R2 (`community_assets`) via `AssetService`, and free Supabase `free-media` (`free_media_assets`) via [[free_media_service]]. Per the 2026-05-21 product decision: the cloud object is removed but the **local SHA cache is preserved** (`keepCache: true`) so a trashed-then-restored entity still renders locally. SHA-dedupe means a single cloud object may be shared, so a ref is only deleted if no surviving entity still references it.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: `ReferenceGraph`, `AssetService`, `FreeMediaService`. Provider `entityMediaCleanupServiceProvider` returns **null** when Supabase/Worker not configured (callers no-op).
- Reads: `reference_graph` (`asset_refs` INDEX(uri) O(1) lookup); `community_assets` (`listAssetsForCampaign`) and `free_media_assets` (`listForScope`) for scope-based discovery.
- Supabase / CDC subscribed: queries only; no realtime.
- Events consumed: none.
- Triggers: entity/world/package delete, cover/portrait replace, entity image remove (via [[entity_image_upload]]).

**Outputs**
- Public API: `cleanupCharacter(json)`, `cleanupEntity(json)`, `cleanupWorld({worldId, campaignName, worldData?})`, `cleanupPackage({packageName})`, `cleanupReplacedRef({oldRef, newRef})`, `cleanupRemovedRef(ref)`.
- Writes (Drift tables): none.
- Supabase pushed: R2 `deleteAsset(key, keepCache: true)` + `free.deleteFreeMedia(path, keepCache: true)`.
- Events emitted: none.

## Dependencies & Links
- Depends on: [[free_media_service]], `data/network/asset_service.dart` (`AssetService`), `domain/value_objects/asset_ref.dart` (`AssetRef`), `reference_graph.dart` (`ReferenceGraph.isReferenced`)
- Used by: [[entity_image_upload]] (`cleanupRemovedEntityImageRef`), entity/world/package delete + cover-replace flows
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Ref-Resolution-Hard-vs-Soft]]

## Key Logic / Variables
- **Ref discovery:** `_collectRefs` recursively walks a JSON tree collecting any string starting with `AssetRef.scheme` (`dmt-asset://`) or `AssetRef.publicScheme` (`dmt-public://`). `_scopedRefs` lists assets bound to a scope from both `community_assets` (counted → `dmt-asset://`) and `free_media_assets` (free → `dmt-public://`).
- **Per-method scopes:** character = refs collected from `Character.toJson()`; entity = refs from entity map; world = `_scopedRefs(counted+free = {worldId, campaignName})` plus optional `worldData` tree (backup path for mislabeled `campaign_id`/`scope_id`); package = scope `{packageName}`.
- **`_deleteRefs`** core guard: for each ref, **skip if `_isReferencedElsewhere`** (delegates to `ReferenceGraph.isReferenced` — F2 O(1) `asset_refs` INDEX(uri); on scan error it returns `true` = safe, keep the object). Then route by `AssetRef`: `isCloud` → `asset.deleteAsset(key, keepCache:true)`; `isPublic` → `free.deleteFreeMedia(path, keepCache:true)`.
- **Ordering invariant (critical, repeated in many docstrings):** all cleanup methods must run **after** the entity's Drift row / new ref is committed locally — otherwise the reference scan sees the entity's own stale ref and wrongly skips the delete.
- **`cleanupReplacedRef`** / **`cleanupRemovedRef`** no-op when old ref empty, equals new ref, or is local/transient (not cloud/public).

## Notes
- Comments Turkish. Entire service is best-effort: every branch is try/caught with `debugPrint`, never throws, never blocks the local delete.
