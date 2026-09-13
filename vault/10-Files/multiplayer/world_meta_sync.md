---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/services/world_meta_sync.dart
layer: application
language: dart
status: stable
updated: 2026-09-13
tags: [file]
---

# `world_meta_sync.dart`

> [!abstract] Primary Purpose
> Dünya kartının **görünen yüzünü** — açıklama, etiketler, kapak resmi — DM'den oyuncuya taşıyan tek kanal. 077 bulut aynasını kaldırdığında dünya metadata'sı da onunla gitmişti: katılan oyuncu hub'ında isimden ibaret boş bir kart görüyordu. Migration **093** `worlds.meta_json` kolonunu ekler; bu dosya o kolonun yazan (DM) ve çözen (oyuncu) uçlarıdır. İçerik hâlâ yalnızca DM'in bilinçli paylaşımlarından akar — burada taşınan şey kartın kimliği, dünyanın verisi değil.

## Inputs / Outputs
**Inputs**
- Constructor: `SupabaseClient`, [[free_media_service]] (`worldMetaSyncProvider` ikisini de `freeMediaServiceProvider` üzerinden kurar; Supabase konfigüre değilse provider **null** döner).
- `push(worldId:, metadata:)` — `world_settings.settings_json` içindeki `metadata` map'i.
- `decodeWorldMeta(raw)` — `worlds.meta_json` (String ya da decode edilmiş Map).

**Outputs**
- Supabase: `worlds` UPDATE (`meta_json`), free-media bucket'a kapak yüklemesi (`MediaKind.worldCover`, quota'ya sayılmaz).
- `decodeWorldMeta` → yerel `metadata` yaması ya da null.

## Dependencies & Links
- Depends on: [[free_media_service]], [[asset_ref]], [[media_kind]]
- Used by: [[campaign_provider]] (`updateCampaignMetadata`), Make Online yolları (`online_world_section.dart`, `save_sync_indicator.dart`), [[world_join_service]], [[world_mirror_applier]], [[world_mirror_service]] (`fetchWorldMeta`)
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[Share-Broadcast-Flow]]
- Spec / reference: [[migrations-online-worlds]]

## Key Logic / Variables
- **Whitelist** `WorldMetaSync.keys = {description, tags, cover_image_path}`. Metadata map'inin geri kalanı DM'de kalır — `meta_json`'a dünyanın başka hiçbir alanı girmez.
- **Kapak yüklemesi (`_remoteCoverRef`)**: DM'in `cover_image_path`'i kendi diskindeki mutlak yol; olduğu gibi gitse oyuncuda çözülmez. `AssetRef(cover).isLocal` ise dosya free-media havuzuna yüklenir ve `dmt-public://` ref'i yazılır; zaten ref ise dokunulmaz; dosya yoksa / yükleme patlarsa boş string gider. DM'in **kendi** satırı yerel yolda kalır (çevrimdışı açılış + LAN eşlemesi asıl dosyayı ister).
- Yükleme içerik-adresli ve dedupe'lu (`FreeMediaService` aynı sha'yı ikinci kez yüklemez), bu yüzden her metadata kaydında yeniden push etmek ucuz.
- `push` **best-effort**: atmaz, yalnız debug'a loglar. Non-DM çağrısını `Worlds: dm update` RLS policy'si zaten reddeder.
- `decodeWorldMeta` bozuk/boş blob'da ve whitelist'ten hiçbir anahtar taşımayan payload'da null döner — çağıran "yama yok" diye okur.

## Notes
- Yazan uçlar: dünya ayarları kaydı + Make Online. Okuyan uçlar: davet kodu ([[world_join_service]]), dünya açılışı (`WorldMirrorApplier._applyWorldMeta`) ve `worlds` CDC UPDATE.
- `test/application/services/world_meta_sync_test.dart` — whitelist + bozuk payload davranışı.
