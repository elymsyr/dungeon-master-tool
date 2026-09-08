---
type: system
domain: media
updated: 2026-09-08
tags: [system]
---

# Media Storage Tiers

> [!summary] What this is
> Depolama sınıfları ve kota/ömür kuralları. Owned by [[Media-and-Assets]]; backends in [[Backend-Infra]].
>
> **Counted tier kaldırıldı (Phase D, 2026-09-08).** Client artık `{userId}/…`
> altına hiçbir şey yazmıyor, Worker o prefix'e PUT'u **410** ile reddediyor —
> GET bir sürüm boyunca çalışıyor ki eski kopyalar inebilsin. Kullanıcı başına
> kalıcı depolama kotası diye bir şey yok; `checkAssetQuota` /
> `USER_QUOTA_BYTES` Worker'dan silindi.
> **Kalan:** prefix'in süpürülmesi + `get_user_total_storage_used` /
> `check_asset_quota` RPC'lerinin düşürülmesi (bir sonraki sürüm), Phase E
> (marketplace medya zip'i). Bkz. [`docs/media-storage-redesign.md`](../../docs/media-storage-redesign.md).

## Participants
- [[free_media_service]] — free tier reads.
- [[entity_image_upload]] — seçilen resmin yerelleştirilmesi (yükleme yok).
- [[shared_media_courier]] — transient'e talep-üzerine + projeksiyon yüklemesi.
- [[media_bundler]] — karakter medyası (portre free, ek resim pinned).
- [[worker]] / [[worker_rls]] — R2 routes + quota/access checks.
- [[entity_media_cleanup_service]] — GC on delete.
- [[pdf_library_service]] — world PDF kütüphanesi; Phase D'den beri **tamamen yerel**, LAN sync ile taşınır.

## Tiers
| Tier | Backend | Quota-counted | Lifecycle |
|---|---|---|---|
| **Free** | Supabase Storage `free-media` bucket | **No** | Permanent; ≤2 MB/file. **Yalnızca paylaşım yolu yazar** (`world_characters` mirror push → [[media_bundler]]); görsel seçmek artık yükleme tetiklemez |
| ~~**Counted**~~ | Cloudflare R2 `{userId}/{sha}.{ext}` | — | **Emekli (Phase D)**: PUT 410, GET bir sürüm daha çalışır, sonra prefix süpürülecek |
| **Transient** | Cloudflare R2 `transient/{userId}/{sha}.{ext}` | **No** (LRU, **5 GB** global, per-user cap YOK) | Auto-evicted by `last_used_at`; multiplayer shared assets |
| **Pinned** | Cloudflare R2 `pub/{sha}.{ext}` | **No** (5 GB havuz, 500 MB/yayıncı) | Eviction yok; `pub_asset_refs` refcount 0 olunca kuyruğa atılır (089). Yazan iki yol: marketplace yayını ([[publish_media_pinner]]) ve karakter ek resimleri ([[media_bundler]], ref_key `char:{id}`) |
| **First-party art** | App bundle `assets/art/srd/` + R2 `catalog/art/{uuid}.webp` | **No** (kullanıcı yüklemesi değil) | Salt-okunur, sürümsüz; `cacheDir/art/` altında cache'lenir |

## Flow
1. Upload → pick tier by kind (per-kind size caps: portrait/cover 4 MB, battle map 10 MB, **world_pdf 50 MB**, bilinmeyen kind için 20 MB ceiling).
2. ~~Counted~~: yol kapalı — Worker `counted_tier_retired` (410) döner.
3. Transient: `transient_reserve` (capacity + LRU evict), `transient_touch` on download (LRU refresh), worker `/transient/evict-sweep` pops queue — kuyruğu **saatlik cron** (`scheduled()`) boşaltır, elle POST yedek yol.
4. Pinned: **client girişi** [[publish_media_pinner]] — marketplace yayını öncesi payload'daki tüm medya ref'leri gezilir, her biri `AssetService.uploadPub` ile `pub/{sha}{ext}`'e taşınır ve ref `dmt-asset://pub/…` olarak yeniden yazılır (refcount sahibi = listing id, bu yüzden id yayından önce client'ta üretilir). `pub_asset_reserve` RPC (dedup + cap; `exists=true` → PUT atlanır) → Worker `pub/` PUT'unda `get_pub_upload_allowed` rezervasyonu doğrular. `pub_asset_release` / hesap silme ref'i düşürür; son ref gidince `trg_drop_orphan_pub_asset` objeyi evict kuyruğuna atar (aynı sweep, `r2_key` kolonu üzerinden). Anahtar içerik adresli olduğu için kuyruk satırı bayatlayabilir: 090 `transient_evict_pop`'ta sha hâlâ canlıysa satırı döndürmüyor. Pin başarısız olursa yayın **iptal edilir** ([[publish_media_pinner]]) — aksi halde listing yayıncının local path'iyle canlıya çıkıyordu.
5. Delete entity/world/package → [[entity_media_cleanup_service]] removes cloud copy (local cache kept).

## Key Constants / Invariants
- Free media **intentionally excluded** from quota (migration 053 invariant).
- Free tier'a **eager upload yok**: portre/kapak seçimi yalnızca yerel kopya
  bırakır. Buluta çıkış tek sebeple olur — dünya mirror push'u (portre) ya da
  marketplace yayını ([[publish_media_pinner]] → `pub/`). Paylaşılmayan içerik
  hiç yüklenmez.
- Per-kind limit **yetkilidir**: Worker `KIND_MAX_BYTES[kind] ?? MAX_UPLOAD_BYTES`; bilinmeyen kind 20 MB ceiling'e düşer. `world_pdf` (50 MB) girdisi duruyor ama artık yazan yok.
- `application/pdf` Worker MIME allowlist'inde (`ALLOWED_MIME_EXACT`).
- **Kullanıcı başına kalıcı depolama kotası yoktur** ve UI'da kota göstergesi yoktur (`storage_usage_provider`, kota snackbar'ları ve `AssetService.uploadAsset` Phase D'de silindi).
- Transient: per-user cap **yok** (089); dosya başına 100 MB emniyet kapağı (`transient_max_file_bytes()`), global pool 5 GB LRU. Rate: 20 DL/h, 60 UL/h per user.
- Pinned havuzu `transient`ten **ayrı bütçelidir** (5 GB / 5 GB): tek havuz olsaydı pinned büyüdükçe LRU'nun yiyebileceği alan sıfıra iner, paylaşımlar sessizce patlardı.
- `pub/` DELETE Worker'da **yasak** — silimi refcount belirler, doğrudan DELETE başkasının listing'ini yok ederdi.
- Paylaşım gövdeleri R2'de değil Postgres'te: `entity_shares.payload_json` ≤ **512 KB** (CHECK), dünya başına ≤ **4000** satır (`max_shares_per_world()` + trigger, 088). `worlds` silimi satırları CASCADE'le düşürür (026).

## Related
- MoCs: [[Media-and-Assets]], [[Backend-Infra]]
- Source Docs: `flutter_app/docs/security_media_supabase_r2_audit_may21.md`

## Transient artık talep üzerine dolar (2026-09-08, Phase C)

Paylaşım anında hiçbir bayt yüklenmez. Havuza yalnızca **o an gerçekten birine
eksik olan** dosya girer:

1. DM paylaşırken payload'daki yerel yollar `dmt-transient://{sha}{ext}`'e
   çevrilir ([[shared_media_courier]]) — baytlar DM'in diskinde kalır.
2. Oyuncu çözemediği sha'ları `world_members.missing_shas`'e yazar
   ([[missing_media_reporter]] → `report_missing_shas`, migration 092).
3. DM CDC ile görür ve **yalnızca istenenleri** `uploadTransientShare` ile
   yükler — ama sadece `WorldSyncService.isSessionOpen(worldId)` doğruysa
   (presence'ta DM'den başka üye var). DM tek başına hazırlık yaparken havuz
   büyümez.

Sonuç: oturumun ikinci haftasında transient yükü neredeyse sıfır — oyuncularda
dosyalar zaten yerelde. Detay: `docs/media-storage-redesign.md`.


## Projeksiyon da transient'e yazar (2026-09-08, Phase D)

Kart / harita / mindmap projeksiyonunda eksik bildirme turu yoktur (oyuncu
`world_projection` satırını okur), o yüzden baytlar önden çıkar:
`SharedMediaCourier.publish(worldId, path)` yükler ve ref'i döndürür. Dönen
transient ref **kalıcı satıra yazılmaz** — LRU atarsa DM kendi resmini
kaybederdi. Giriş noktaları: `prepareEntityImagesForProjection`,
`projectableMapImage`, `WorldMapNotifier.ensureMapImageProjectable`.
