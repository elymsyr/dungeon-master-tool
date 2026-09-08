---
type: file-note
domain: media
path: flutter_app/lib/application/services/shared_media_courier.dart
layer: application
language: dart
status: active
updated: 2026-09-08
tags: [file]
---

# `shared_media_courier.dart`

> [!abstract] Primary Purpose
> DM tarafı, talep-üzerine medya akışının yükleyen ucu. Kart paylaşımı artık hiçbir şey yüklemez; bu modül paylaşım payload'ındaki yerel dosya yollarını içerik-adresli `dmt-transient://{sha}{ext}` ref'lerine çevirir ve baytları **yalnızca bir oyuncu o sha'yı eksik bildirdiğinde** transient havuza gönderir. Karşı ucu [[missing_media_reporter]].

## Inputs / Outputs
**Inputs**
- Constructor dep: Riverpod `Ref`.
- Reads: `assetServiceProvider`, `entityProvider`, `worldSchemaProvider`.
- Triggers: `refFor(localPath)` — paylaşım anında (`entity_share_prepare`); `serve(worldId, shas)` — `world_members.missing_shas` CDC'sinde ([[world_mirror_applier]]).

**Outputs**
- Public API: `refFor`, `serve`, `sharedMediaCourierProvider`; top-level `shaOfFile`, `imageFieldKeysBySlug`, `localMediaPathsOf`, `remapEntityMedia`.
- Supabase / R2: `AssetService.uploadTransientShare` → `transient/{uid}/{sha}{ext}` + `transient_shares` satırı.
- Writes (Drift): **yok** — DM'in entity'si hiç değiştirilmez.

## Dependencies & Links
- Depends on: [[asset_service]], [[content_store]], [[entity_provider]]
- Used by: `entity_share_prepare.dart`, [[world_mirror_applier]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Share-Broadcast-Flow]], [[Media-Storage-Tiers]]
- Spec: `docs/media-storage-redesign.md` → "Phase C nasıl uygulandı"

## Key Logic / Variables
- `refFor(path)` — dosyayı **akış üzerinden** hash'ler (`sha256.bind(openRead())`, 100 MB'lık handout belleğe alınmaz), `sha → yerel yol` eşlemesini belleğe yazar, `dmt-transient://{sha}{ext}` döner. Dosya okunamıyorsa `null` ve yol payload'da olduğu gibi kalır.
- `serve(worldId, shas)` — 64 karakterlik hex olmayanı eler, `_served` ile aynı oturumda ikinci PUT'u engeller, tanınmayan sha varsa bir kez `_reindex()` çalıştırır. Tanınmayan/silinmiş sha **sessizce atlanır**: oyuncu listesini korur, dosya geri gelirse sonraki turda çıkar.
- **Ref'ler DM'in entity'sine YAZILMAZ.** Transient obje sunucu tarafında LRU ile atılabilir; kalıcı satırda ölü ref bırakmak DM'in kendi resmini kaybetmesi demek olurdu. Aynı gerekçe `prepareEntityImagesForProjection`'da da geçerli.
- `remapEntityMedia` saf: orijinal `Entity`'ye dokunmaz, kopya döner.
- **Oturum kapısı burada DEĞİL** — `serve` çağrılmadan önce [[world_mirror_applier]] `sync.isSessionOpen(worldId)` kontrol eder.

## Notes
- `ponytail:` tavan — `_reindex()` dünyanın tüm yerel medyasını hash'ler, oturum başına bir kez. Ölçülür gecikme olursa sha paylaşım anında `asset_refs` yan tablosuna yazılır.
- Regresyon testi: `test/application/services/shared_media_on_demand_test.dart`.
