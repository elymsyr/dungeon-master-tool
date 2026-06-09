---
type: file-note
domain: media
path: flutter_app/lib/data/network/free_media_service.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `free_media_service.dart`

> [!abstract] Primary Purpose
> The free-media storage pipeline backed by the Supabase Storage `free-media` **public** bucket. Character portraits and world/package cover images go here and do **NOT** count against the user's 100MB storage quota (`free_media_assets` is excluded from every quota total — migration 053). It mirrors `AssetService`'s shape but without the Cloudflare Worker — talks Supabase Storage directly, with SHA-256 content addressing (same bytes = same path = no re-upload).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: `SupabaseClient`, `ContentStore` (local SHA cache).
- Reads: `free_media_assets` table (dedupe lookup by `storage_path`, list by `owner_id` / `scope_id`); local content-store cache; public-URL downloads from `free-media` bucket.
- Supabase / CDC subscribed: queries `free_media_assets`; no realtime.
- Events consumed: none.
- Triggers: called by [[media_bundler]] (`_uploadFree`), gallery views, and cleanup ([[entity_media_cleanup_service]]).

**Outputs**
- Public API: `uploadFreeMedia(file, {kind, scopeId})` → `dmt-public://{path}`; `resolveFreeMedia(publicPath)` → cached `File?`; `listForUser()`, `listForScope(scopeId)` → `List<FreeMediaAssetRow>`; `deleteFreeMedia(publicPath, {keepCache})`.
- Writes (Drift tables): none (uses `ContentStore`, not Drift).
- Supabase pushed: uploads to `free-media` bucket; inserts/deletes `free_media_assets` rows.
- Events emitted: none.

## Dependencies & Links
- Depends on: `supabase_flutter` (`SupabaseClient`), `application/services/content_store.dart` (`ContentStore`, `ContentMetadata`, `ContentStoreException`), `domain/value_objects/asset_ref.dart` (`AssetRef.formatPublicUri`), `domain/value_objects/media_kind.dart` (`MediaKind`), `core/utils/id_gen.dart`, `crypto` (sha256)
- Used by: [[media_bundler]], [[entity_media_cleanup_service]], gallery/portrait pickers
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[migrations-media-storage]]

## Key Logic / Variables
- **Bucket** `free-media` (public). Storage path layout: `{user.id}/{sha256}{ext}`.
- **`uploadFreeMedia`** asserts `!kind.counted`, requires signed-in user. Reads bytes, enforces `bytes.length <= kind.maxBytes` (else `FreeMediaException('too_large')`). Computes sha256, mime via `_guessMime`. **Dedupe:** if a `free_media_assets` row already has this `storage_path` → just re-cache locally and return the ref (no re-upload). Otherwise `uploadBinary(upsert:true)` + insert metadata row `{id, owner_id, storage_path, sha256_hash, mime_type, size_bytes, kind:wireName, original_filename, scope_id}` (RLS enforces `owner_id = auth.uid()`), then write bytes to local cache.
- **`resolveFreeMedia`** is cache-first: `ContentStore.read(sha)` → hit returns file; miss downloads via **public URL** (`getPublicUrl`), SHA-verifies on cache write (`ContentStoreException` mismatch → null). Public-URL download deliberately bypasses RLS so any member can resolve a shared image while the storage SELECT policy stays owner-scoped — cross-user enumeration stays closed (migration 058).
- **`deleteFreeMedia(keepCache)`:** removes storage object + metadata row; when `keepCache: true` the local SHA cache is **preserved** so a trashed-then-restored entity still renders locally (used by [[entity_media_cleanup_service]]).
- **`_shaFromPath`** extracts sha from `{uid}/{sha}.{ext}`. `_extensionOf` defaults to `.png`.
- `FreeMediaAssetRow` value-object exposes `ref` getter = `dmt-public://{storage_path}`.

## Notes
- Comments Turkish. SHA-256 content-addressing is the dedupe + integrity backbone across both this and the counted R2 path.
