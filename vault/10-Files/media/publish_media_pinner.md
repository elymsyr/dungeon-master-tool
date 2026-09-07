---
type: file-note
domain: media
path: flutter_app/lib/application/services/publish_media_pinner.dart
layer: application
language: dart
status: stable
updated: 2026-09-07
tags: [file]
---

# `publish_media_pinner.dart`

> [!abstract] Primary Purpose
> Before a marketplace snapshot is published, walks the whole payload JSON and moves **every** media ref into the `pinned` class (`pub/{sha}{ext}`), rewriting the strings in place. Without it a listing ships refs that point at the publisher's local paths (broken for the downloader) or at their counted `{uid}/` objects (dead once the counted tier is torn down). `pinned` is not LRU-evictable, so downloadability is guaranteed.

## Inputs / Outputs
**Inputs**
- Constructor deps: `AssetService` (R2 pinned upload), `AssetRefResolver` (turns any ref — local, cached, public, transient, counted cloud — into a `File`).
- Reads: the payload map handed in by `publishSnapshot`; media bytes via the resolver.
- Triggers: `MarketplaceListingNotifier.publishSnapshot`, before the content hash is computed.

**Outputs**
- Public API: `pin({payload, refKey, kind})` → `PublishPinResult`; static `isMediaRef(String)`.
- Supabase / RPC: `pub_asset_reserve` (via `AssetService.uploadPub`).
- Writes: none — returns a deep-cloned, rewritten map; caller publishes it.

## Dependencies & Links
- Depends on: `data/network/asset_service.dart` (`uploadPub`, `PinnedQuotaExceededException`), [[asset_ref_resolver]], `domain/value_objects/asset_ref.dart`, `domain/value_objects/media_kind.dart`, `core/utils/deep_copy.dart`
- Used by: [[marketplace_listing_provider]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: `docs/media-storage-redesign.md` → "Marketplace"

## Key Logic / Variables
- **`isMediaRef`** is the single branch point (public so the test can hit it): pins local image paths (needs a separator + known image ext), `dmt-public://`, `dmt-transient://`, and counted `dmt-asset://`. **Skips** `dmt-art://` (first-party catalog, lives in R2 `catalog/`, no refcount) and refs already under `dmt-asset://pub/`.
- **`refKey`** is the **listing id** — it is the refcount owner (`pub_asset_refs.ref_key`). Hence the id is generated in the provider *before* publishing, not by the remote DS.
- **Dedup:** a `pinned` map keyed by old ref means a repeated ref in one payload costs one upload; across payloads/users the server side dedups by `sha` (`pub_asset_reserve` returns `exists: true` → PUT skipped).
- **Failure policy:** per-ref failures land in `PublishPinResult.failures` and the old ref survives *inside the returned payload* — but the pinner is no longer best-effort end-to-end: [[marketplace_listing_provider]] **aborts the publish** when `failures` is non-empty, because a surviving ref is the publisher's local path and would open blank for every downloader while the publish still reported success. Failed refs are also negatively cached (`failures` is a `Set`), so one broken ref is attempted once per publish, not once per occurrence — a retry repeats `pub_asset_reserve` + rollback `pub_asset_release` and pushes a second stale row into the evict queue (see migration 090). `PinnedQuotaExceededException` (pool 5 GB / publisher 500 MB) cuts the walk immediately.
- Returned refs are `dmt-asset://pub/{sha}{ext}` on purpose: the existing resolver/download path works unchanged, and the Worker already serves `pub/` GETs to everyone.

## Notes
- Comments Turkish. Test: `test/application/publish_media_pinner_test.dart` (covers `isMediaRef` only — the upload path needs a live Supabase/Worker).
