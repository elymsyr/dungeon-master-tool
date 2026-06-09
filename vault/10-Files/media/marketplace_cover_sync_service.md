---
type: file-note
domain: media
path: flutter_app/lib/application/services/marketplace_cover_sync_service.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `marketplace_cover_sync_service.dart`

> [!abstract] Primary Purpose
> When an entity's (world / package / character) cover or portrait changes, this refreshes the inline banner (`cover_image_b64`) of any marketplace listings published from that entity, so the marketplace thumbnail tracks the new artwork. The published content copy (`content_hash` / `payload_path`) is untouched — only the banner updates. Best-effort: never throws, never blocks the local save.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: `MarketplaceLinksLocalDataSource` (local), `MarketplaceListingsRemoteDataSource` (remote), `AssetRefResolver` (resolver). Provider returns **null** when `SupabaseConfig.isConfigured` is false (callers no-op).
- Reads: local owned listing ids via `local.getOwnedListingIds(itemType, localId)` (offline-safe); resolves+encodes the new ref to a base64 thumbnail.
- Supabase / CDC subscribed: none (writes only).
- Events consumed: none.
- Triggers: cover/portrait change, called **after** the new ref is committed to the local DB.

**Outputs**
- Public API: `syncCover({itemType, localId, oldRef, newRef})`.
- Writes (Drift tables): none.
- Supabase pushed: `remote.updateListingCover(listingId, coverImageB64)` per owned listing.
- Events emitted: none.

## Dependencies & Links
- Depends on: `core/config/supabase_config.dart` (`SupabaseConfig.isConfigured`), `data/datasources/local/marketplace_links_local_ds.dart`, `data/datasources/remote/marketplace_listings_remote_ds.dart`, `asset_ref_resolver.dart` (`AssetRefResolver`), `marketplace_cover_encoder.dart` (`encodeCoverThumbnailB64`)
- Used by: cover/portrait edit flows after local commit
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Multiplayer-and-Online]]

## Key Logic / Variables
- **`itemType`** ∈ `{'world','package','character'}`; **`localId`** = world/package name, or character id.
- **Flow:** no-op if Supabase unconfigured, or `oldRef == newRef` (cover unchanged), or no owned listings for the item. If `newRef` non-empty → `encodeCoverThumbnailB64(resolver, newRef)`; **if encode fails (likely offline) → skip entirely** (keep listings' existing banner, do NOT push null and erase it). If `newRef` is empty → `b64` stays null → cover intentionally removed (listing shows fallback icon). Then `updateListingCover` for each owned listing id (per-listing try/catch).
- **Invariant:** only the banner changes; listing content/hash is never re-published.

## Notes
- Comments Turkish. Distinct from [[entity_media_cleanup_service]] (which deletes the underlying cloud object) — this only re-skins published marketplace banners.
