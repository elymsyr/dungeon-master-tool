---
type: file-note
domain: media
path: flutter_app/lib/application/services/world_media_sync.dart
layer: application
language: dart
status: active
updated: 2026-09-23
tags: [file]
---

# `world_media_sync.dart`

> [!abstract] Primary Purpose
> Faz 5d — multiplayer dünyanın medyası R2'de, dünya başına ve kalıcı (`worlds/{worldId}/{sha}{ext}`). Transient havuzun ve talep-üzerine akışın (`shared_media_courier` / `missing_media_reporter`, ikisi de silindi) yerini alır. **Kuyruk yok:** bulutta ne olduğunu `world_media` söylüyor, gönderilmesi gerekeni satırlardaki `dmt-content://` ref'leri; fark bir sonraki turun işi. Bayt worker'dan geçmez.

## Inputs / Outputs
**Inputs**
- Constructor deps: `SupabaseClient`, [[asset_service]] (imza + PUT), [[content_ref_index]] (kaynak dosya), [[content_store]] (ikinci cihazın indirdiği kopya).
- Reads: `world_media` (RLS: üyeler okur) — yüklü sha'lar ve yetim temizliği için `created_at`.
- Triggers: [[cloud_push_provider]] (tur sonrası, uzlaştırma, "multiplayer aç"), [[projection_output_online]] ve `map_image_upload`/`entity_share_prepare` projeksiyon yolları (`publish`).

**Outputs**
- Public API: `plan(refs)` (ağ yok), `upload(worldId, refs, onProgress)`, `publish(worldId, path, kind)`, `prune(worldId, keep)`, `quota()`, `forget(worldId)`; top-level `worldMediaKindOf(ext, map:)`; tipler `WorldMediaRef`, `WorldMediaPlan`, `WorldMediaReport`, `MediaQuota`, `WorldMediaQuotaException`; `worldMediaSyncProvider` (oturum/worker yoksa null).
- Supabase RPC: `world_media_reserve`, `world_media_confirm`, `get_media_quota` (099); `world_media` üzerinde DELETE (sahip).
- Worker: `POST /world-media/sign {op: put}` → imzalı URL'e doğrudan R2 PUT.

## Dependencies & Links
- Depends on: [[asset_service]], [[content_ref_index]], [[content_store]], [[migrations-cloud-mirror]] (099)
- Used by: [[cloud_push_provider]], [[projection_output_online]], [[cloud_push_service]] (`WorldMediaRef` tipi), `online_world_widgets.turnMultiplayerOn`
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec: `docs/online-sync-redesign.md` §4.8.3, §4.8.4 (5f)

## Key Logic / Variables
- **Yükleme dört adım:** rezervasyon (sahiplik + dosya limiti + kişi başı 1 GB + toplam 9 GB, **tek RPC**) → toplu imza (**tek worker isteği**, 100 sha) → imzalı URL'e PUT → onay. Satır rezervasyonla `uploaded = false` doğar; onaysız satır okunamaz ama kotaya sayılır.
- **PUT'un boyutu ve türü imzaya bağlı** — `AssetService.mimeOf(ext)` hem rezervasyona yazılan hem PUT'ta gönderilen değer; ikisi aynı fonksiyondan geldiği için imza tutuyor. Limit worker'sız da zorlanır.
- **Kaynak dosya iki yerden:** özgün dosya (`fileForSha`) ya da içerik önbelleği. İkisinde de yoksa sha **atlanır** — o baytı yükleyebilecek olan başka cihaz (DM'in ikinci cihazı buluttan indirdiği görseli yeniden yükleyebilir, indirmediğini yükleyemez).
- **Limit aşan dosya rezerve bile edilmez**, `tooLarge`'da adıyla döner (önbellek kopyasının `{sha}.bin` adı kısaltılır).
- **PUT'lar 6 eşzamanlı** (`_parallel`, Faz 5f): 100'lük partinin dosyalarını işçi havuzu sırayla alır. Dünya medyası çoğunlukla küçük (Aegis medyan 72 KB), süreyi gidiş-dönüş belirliyor — sırayla 179 dosya 179 ardışık istekti. Bir işçinin hatası yenilerin başlamasını durdurur, yoldakiler biter ve onaylanır. `WorldMediaReport.bytes` giden bayt (ölçüm log'u).
- **Onay onar dosyada bir** (`_confirmEvery`) ve turun sonunda (`finally`). Eskiden yalnız 100'lük partinin sonunda gidiyordu: 98. PUT asılı kalınca 97 obje R2'de durdu ama 100 satırın hepsi `uploaded = false` kaldı ve **hiçbiri kimseye imzalanmadı** — öbür cihaza tek görsel gelmedi. Kopan turda kayıp artık en çok 10 PUT; onaysızı sonraki rezervasyon yeniden döner, aynı key'e aynı bayt yazılır.
- **Onay hatası yutulmaz:** yukarı çıkar ve o sha'lar `_inCloud`'a eklenmez. Yutulsaydı bu cihaz onları yüklü sanıp bir daha denemezdi.
- **Dosya başına dayanıklılık** (`_put`): geçici hata (ağ, zaman aşımı, 5xx) `_attempts` = 3 kez, `backoff` beklemesiyle (varsayılan 2·n sn); geçmezse tur **durur** (ağ yoksa kalan dosyaları tek tek denemek zaman kaybı) — o ana dek yüklenenler onaylı. 403 önce imzayı bir kez tazeler (1 saatlik imza uzun turda dolar); başka 4xx ya da okunamayan dosya yalnız o dosyayı atlar, adı `WorldMediaReport.failed`'da, tur sürer.
- **Zaman aşımları:** Supabase çağrıları `.retry(requestTimeout: 30 sn)` (postgrest takılan isteği gerçekten iptal ediyor; POST'u otomatik tekrarlamıyor). HTTP tarafı [[asset_service]]'te.
- **`_inCloud` önbelleği** dünya başına yüklü sha kümesi; ilk ihtiyaçta `world_media`'dan sayfalanarak (PostgREST 1000 satır) okunur, `forget` tazeletir.
- **Yetim temizliği** (`prune`) `pruneGrace` = **10 dk**'dan genç satıra dokunmaz: öbür cihaz yeni bir görseli yüklemiş, onu anan satır bu cihaza henüz inmemiş olabilir. Yanlış silme kendiliğinden düzelir — hâlâ anılan sha sonraki turda yeniden yüklenir.
- **`publish`** projeksiyonun tek dosyası: satırda duran görsel zaten yüklü olduğundan ağa çıkmadan ref döner; hiçbir satırın anmadığı görsel (paket kartının token'ı, düz görsel) yüklenir ve bir sonraki oturumun temizliğinde düşer.
- **Sınıflar** (`worldMediaKindOf`): `.pdf` → `world_pdf` 20 MB, ses uzantıları → `world_audio` 10 MB, harita → `battle_map` 10 MB, geri kalan → `world_entity_image` 5 MB. Hangi satırın harita olduğunu [[cloud_push_service]] `mediaRefsOf` belirler.

## Notes
- Regresyon testleri: `test/application/services/world_media_sync_test.dart` (sahte PostgREST üstünde rezervasyon → imza → PUT → onay zinciri, kota, denemeleri biten PUT, **yanıt vermeyen PUT'un zaman aşımı**, 4xx atlama + 403 yeniden imza, onar onay, **en çok 6 eşzamanlı PUT**, temizlik penceresi, projeksiyon önbelleği; PUT yanıtları `FakePostgrest.routes` ile yola bağlı) ve `world_media_refs_test.dart` (sınıflandırma + paylaşım/push aynı sha'yı görüyor).
- Paket medyası henüz buluta çıkmıyor — Faz 5e.
