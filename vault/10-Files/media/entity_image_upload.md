---
type: file-note
domain: media
path: flutter_app/lib/application/services/entity_image_upload.dart
layer: application
language: dart
status: stable
updated: 2026-09-08
tags: [file]
---

# `entity_image_upload.dart`

> [!abstract] Primary Purpose
> Üç top-level helper (sınıf değil): `localizeEntityImages` seçilen resimleri içeriğin `media/` klasörüne kopyalar, `localizeEntityFiles` aynısını PDF/dosya alanları için yapar, `cleanupRemovedEntityImageRef` kaldırılan bir bulut ref'ini best-effort siler. **Buluta yükleme yok** — sayılan katman Phase D'de kaldırıldı; bir kartın görseli buluta ancak DM onu paylaşınca ve bir oyuncu eksik bildirince çıkar ([[shared_media_courier]]).

## Inputs / Outputs
**Inputs**
- Providers watched (via `ref.read`): `authProvider`, `assetServiceProvider`, `activePackageProvider`, `betaProvider`, `activeCampaignProvider` (`.notifier.data['world_id']`), `onlineWorldIdsProvider`, `entityMediaCleanupServiceProvider`, `pendingWriteBufferProvider`, `syncEngineProvider`.
- Reads: local image file paths to upload.
- Supabase / CDC subscribed: none directly.
- Events consumed: none.
- Triggers: entity image picker add/remove flows (entity card portrait gallery + schema image fields).

**Outputs**
- Public API: `localizeEntityImages(ref, paths)` → `List<String>` (kopya yolları); `localizeEntityFiles(ref, paths)`; `cleanupRemovedEntityImageRef(ref, removedRef, {readOnly, remaining})`.
- Writes: none directly — returns refs; caller persists.
- Supabase pushed: yok. Cloud delete yalnızca `cleanupRemovedEntityImageRef` → [[entity_media_cleanup_service]].
- Events emitted: forces a sync tick (`syncEngineProvider.forceTick`) and flushes outbox prefix `entity:`.

## Dependencies & Links
- Depends on: [[local_media_localizer]], [[entity_media_cleanup_service]], [[auth_provider]], [[campaign_provider]], `sync_engine.dart` (kaldırıldı), [[pending_write_buffer]], `domain/value_objects/asset_ref.dart`, `domain/value_objects/media_kind.dart`, plus `activePackageProvider` (not in allow-list → plain text)
- Used by: entity editor / entity card image pickers
- Domain map: [[Media-and-Assets]]
- System flow: [[Share-Broadcast-Flow]] (`docs/media-storage-redesign.md` Phase D)

## Key Logic / Variables
- **`kMaxEntityImages = 5`** — cap per entity image collection (portrait gallery `entity.images` and each schema image field).
- **Seçilen dosyalar her koşulda önce kopyalanır** — yükleme kararından ÖNCE `LocalMediaLocalizer` ile dünyanın (`{worldsDir}/{ad}/media/`) ya da paketin (`{packagesDir}/{ad}/media/`) klasörüne alınır ve yükleme o kopyalardan yapılır. Ham `Downloads/` yolu asla saklanmaz: LAN eşlemesi taşıyamıyor (`LanSyncSession._mediaFor`) ve kullanıcı orijinali taşırsa resim kayboluyor. Aktif dünya/paket bilinmiyorsa (`_ownerDir` null) kopyalama atlanır.
- **`localizeEntityFiles(ref, paths)`** — schema `file`/`pdf` alanlarının resim olmayan ekleri için aynı iş, hedef `{ownerDir}/files/` (PDF kütüphanesinin `pdfs/` klasörüne karışmasın diye ayrı).
- **`localizeEntityImages(ref, paths)`** — tek işi kopyalama; hedef `_ownerDir` (paket varsa paketin, yoksa aktif dünyanın klasörü). Bulut, oturum ve online-dünya kapıları **kalktı**: hiçbir yükleme yapılmıyor (Phase D).
- **`cleanupRemovedEntityImageRef` no-ops** when: `readOnly` (built-in/read-only pack), ref not `dmt-asset://` (counted), ref still in `remaining` (dup in same entity), not signed in, non-beta package, or no cleanup service configured.
  - **Ordering invariant:** flush `entity:` outbox prefix then `syncEngine.forceTick()` **before** calling `cleanup.cleanupRemovedRef` — otherwise the reference scan sees this entity's stale ref and wrongly skips the delete.

## Notes
- Kota/boyut snackbar'ları kaldırıldı; call site'ta kalan tek uyarı `showImageLimitSnackbar` (adet tavanı).
