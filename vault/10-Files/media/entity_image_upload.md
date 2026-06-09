---
type: file-note
domain: media
path: flutter_app/lib/application/services/entity_image_upload.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `entity_image_upload.dart`

> [!abstract] Primary Purpose
> Two top-level helper functions (not a class) that drive eager cloud upload and best-effort cloud cleanup for entity image collections. `eagerUploadEntityImages` uploads freshly-picked images to counted Cloudflare R2 when the host entity is online + signed-in (mirroring the portrait gallery gating); `cleanupRemovedEntityImageRef` deletes a just-removed cloud image after flushing the outbox so the reference scan sees fresh state.

## Inputs / Outputs
**Inputs**
- Providers watched (via `ref.read`): `authProvider`, `assetServiceProvider`, `activePackageProvider`, `betaProvider`, `activeCampaignProvider` (`.notifier.data['world_id']`), `onlineWorldIdsProvider`, `entityMediaCleanupServiceProvider`, `pendingWriteBufferProvider`, `syncEngineProvider`.
- Reads: local image file paths to upload.
- Supabase / CDC subscribed: none directly.
- Events consumed: none.
- Triggers: entity image picker add/remove flows (entity card portrait gallery + schema image fields).

**Outputs**
- Public API: `eagerUploadEntityImages(ref, paths, {transientFallback, overrideKind})` → record `(refs, pushWorldId, quotaExceeded, tooLarge, tooLargeActualBytes)`; `cleanupRemovedEntityImageRef(ref, removedRef, {readOnly, remaining})`.
- Writes: none directly — returns refs; caller persists.
- Supabase pushed: R2 uploads via `uploadEntityImageRef` (image_upload_helper); cloud delete via cleanup service.
- Events emitted: forces a sync tick (`syncEngineProvider.forceTick`) and flushes outbox prefix `entity:`.

## Dependencies & Links
- Depends on: [[entity_media_cleanup_service]], [[auth_provider]], [[campaign_provider]], [[sync_engine]], [[pending_write_buffer]], `domain/value_objects/asset_ref.dart`, `domain/value_objects/media_kind.dart`, `image_upload_helper.dart` (`uploadEntityImageRef`), plus `betaProvider`/`activePackageProvider`/`onlineWorldsProvider` (not in allow-list → plain text)
- Used by: entity editor / entity card image pickers
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[CDC-Sync-Flow]]

## Key Logic / Variables
- **`kMaxEntityImages = 5`** — cap per entity image collection (portrait gallery `entity.images` and each schema image field).
- **`eagerUploadEntityImages` gating (returns paths untouched when skipped):**
  - not signed in OR no `assetServiceProvider` → skip.
  - **Package entity:** requires `betaProvider.isActive` (else skip); `scopeId = packageName`, `kind = packageEntityImage`, `pushWorldId = null` (no per-row outbox).
  - **World entity:** `worldId` from active campaign must be in `onlineWorldIdsProvider` (online world) — offline worlds bundle media at Make-Online instead and skip here. `scopeId = worldId`, `kind = worldEntityImage`, `pushWorldId = worldId`.
  - Uploads all paths in parallel (`Future.wait`); aggregates `quotaExceeded` (any fell back to local on full quota), `tooLarge` (any exceeded per-kind size limit) + first `tooLargeActualBytes`. `overrideKind` lets callers force a specific `MediaKind`.
- **`cleanupRemovedEntityImageRef` no-ops** when: `readOnly` (built-in/read-only pack), ref not `dmt-asset://` (counted), ref still in `remaining` (dup in same entity), not signed in, non-beta package, or no cleanup service configured.
  - **Ordering invariant:** flush `entity:` outbox prefix then `syncEngine.forceTick()` **before** calling `cleanup.cleanupRemovedRef` — otherwise the reference scan sees this entity's stale ref and wrongly skips the delete.

## Notes
- Comments English. Quota/size fallback semantics surface as UI snackbars at the call site.
