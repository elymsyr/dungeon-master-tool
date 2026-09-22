---
type: file-note
domain: media
path: flutter_app/lib/application/services/shared_media_courier.dart
layer: application
language: dart
status: active
updated: 2026-09-22
tags: [file]
---

# `shared_media_courier.dart`

> [!abstract] Primary Purpose
> DM tarafı, talep-üzerine medya akışının yükleyen ucu. Kart paylaşımı artık hiçbir şey yüklemez; bu modül paylaşım payload'ındaki yerel dosya yollarını içerik-adresli `dmt-content://{sha}{ext}` ref'lerine çevirir (Faz 3.5'e kadar `dmt-transient://` idi) ve baytları **yalnızca bir oyuncu o sha'yı eksik bildirdiğinde** transient havuza gönderir. Karşı ucu [[missing_media_reporter]].

## Inputs / Outputs
**Inputs**
- Constructor dep: Riverpod `Ref`.
- Reads: `assetServiceProvider`, `entityProvider`, `worldSchemaProvider`.
- Triggers: `refFor(localPath)` — paylaşım anında (`entity_share_prepare`); `serve(worldId, shas)` — `world_members.missing_shas` CDC'sinde ([[world_mirror_applier]]).

**Outputs**
- Public API: `refFor`, `serve`, `publish`, `sharedMediaCourierProvider`; top-level `imageFieldKeysBySlug`, `localMediaPathsOf`, `remapEntityMedia` (+ [[content_ref_index]]'ten re-export edilen `shaOfFile`).
- Supabase / R2: `AssetService.uploadTransientShare` → `transient/{uid}/{sha}{ext}` + `transient_shares` satırı.
- Writes (Drift): `content_paths` (dolaylı, [[content_ref_index]] üzerinden). DM'in entity satırı hiç değiştirilmez.

## Dependencies & Links
- Depends on: [[asset_service]], [[content_store]], [[content_ref_index]], [[entity_provider]]
- Used by: `entity_share_prepare.dart`, [[world_mirror_applier]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Share-Broadcast-Flow]], [[Media-Storage-Tiers]]
- Spec: `docs/media-storage-redesign.md` → "Phase C nasıl uygulandı"

## Key Logic / Variables
- `refFor(path)` — sha'yı [[content_ref_index]]'ten alır (değişmemiş dosya yeniden hash'lenmez), `dmt-content://{sha}{ext}` döner. Dosya okunamıyorsa `null` ve yol payload'da olduğu gibi kalır.
- `serve(worldId, shas)` — 64 karakterlik hex olmayanı eler, `_served` ile aynı oturumda ikinci PUT'u engeller. Bilinmeyen sha için sırayla: oturum içi map → `content_paths` → **son çare** `_reindex()`. Tanınmayan/silinmiş sha **sessizce atlanır**: oyuncu listesini korur, dosya geri gelirse sonraki turda çıkar.
- **Ref'ler DM'in entity'sine hâlâ YAZILMAZ** — ama gerekçe değişti. `dmt-content://` tier adlandırmadığı için LRU riski yok; satırda yerel yolun kalması artık [[unused_media_sweeper]] ve [[content_codec]] içindir (ikisi de satırlarda yol arar). Satırın buluta çevrilmesi Faz 4 push'unun işi.
- `remapEntityMedia` saf: orijinal `Entity`'ye dokunmaz, kopya döner.
- **Oturum kapısı burada DEĞİL** — `serve` çağrılmadan önce [[world_mirror_applier]] `sync.isSessionOpen(worldId)` kontrol eder.

## Notes
- `_reindex()` Faz 3.5'ten beri yalnızca **geri düşüş**: `content_paths` kalıcı olduğu için normal akışta hiç çalışmaz. Yalnızca eski sürümde paylaşılmış kartlar / sıfırlanmış DB için; hash'lediğini indekse yazar, ikinci kez gerekmez.
- Regresyon testi: `test/application/services/shared_media_on_demand_test.dart`.
