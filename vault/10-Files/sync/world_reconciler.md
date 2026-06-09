---
type: file-note
domain: sync
path: flutter_app/lib/application/services/world_reconciler.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_reconciler.dart`

> [!abstract] Primary Purpose
> Manual bidirectional reconcile for online worlds, driven by the "Refresh / Sync" button. Compares the cloud `worlds` table against the local Drift copies by `updated_at` and pulls newer cloud worlds down or pushes newer local worlds up (last-writer-wins per world). The single source of truth is the `worlds` table — the older `cloud_backups` snapshot path for worlds was removed; worlds only live in the cloud once "Make Online" has been done.

## Inputs / Outputs
**Inputs**
- Constructor: `Ref _ref`.
- Reads cloud: `worlds` (`id, world_name, updated_at, template_id, template_hash, state_json`).
- Reads local: `campaignRepositoryProvider.getAvailable()` + `.load(name)` (uses `world_id`, `last_modified`/`updated_at`).
- Gates: `SupabaseConfig.isConfigured`, `authProvider` (session), `betaEnterGateProvider.isCompleted(uid)`.

**Outputs**
- Pull: `campaignRepositoryProvider.save(name, data)`, invalidates `campaignListProvider` / `campaignInfoListProvider`.
- Push: `[[world_mirror_service]].pushWorldState` (via `publish_world` RPC) after media bundling.
- Updates `onlineWorldIdsProvider` (add for each cloud world; refreshed at start to demote worlds unpublished/left elsewhere).
- Returns `ReconcileResult(pulled, pushed, message)`.

## Dependencies & Links
- Depends on: [[world_mirror_service]], [[media_bundler]], [[beta_enter_gate]], [[campaign_provider]], [[free_media_service]]
- Used by: Refresh/Sync UI action (online worlds screen)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[CDC-Sync-Flow]]
- Spec / reference: [[rpc-reference]]

## Key Logic / Variables
- **Rules** (per world id):
  - Cloud-only → pull (`_pullToLocal`), add to online set.
  - Both sides, cloud newer (`cloudUpdated.isAfter(local)`) → pull cloud→local.
  - Both sides, local newer → push local→cloud (`_pushToCloud`).
  - Local-only (not in cloud) → leave untouched (stays offline).
- **`_pullToLocal`:** decodes `state_json`, injects `world_id`, `campaignRepository.save`. Returns false on empty/invalid state.
- **`_pushToCloud`:** bundles world media via `MediaBundler.bundleWorldMedia`, uploads the cover (`metadata.cover_image_path`) to free-media (`dmt-public://`) since `bundleWorldMedia` doesn't walk the cover, then `mirror.pushWorldState`.
- **Beta-enter wipe guard:** if `betaEnterGate` not completed for this uid, the destructive cloud→local pull branch is SKIPPED (a stale cloud row would otherwise wipe local content via `WorldRepositoryImpl._saveToDb` full-replace). Cloud-only inserts and local-only pushes remain safe.

## Notes
- This is the manual counterpart to the realtime CDC path (`[[world_mirror_applier]]`); it does not subscribe to CDC.
- `onlineWorldIdsProvider.refresh()` is called first so worlds unpublished/left on another device get demoted (reconcile otherwise only ever adds, never demotes).
