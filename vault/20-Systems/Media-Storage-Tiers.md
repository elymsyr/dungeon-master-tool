---
type: system
domain: media
updated: 2026-09-23
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
- [[world_media_sync]] — multiplayer dünyanın medyası R2'de, dünya başına (Faz 5d): rezervasyon → toplu imza → doğrudan PUT → onay; yetim temizliği.
- [[content_ref_index]] — `dmt-content://` ref'inin cihaz-yerel çözümü (`content_paths`).
- [[media_bundler]] — karakter medyası (portre free, ek resim pinned).
- [[worker]] / [[worker_rls]] — R2 routes + quota/access checks.
- [[entity_media_cleanup_service]] — GC on delete.
- [[pdf_library_service]] — world PDF kütüphanesi; Phase D'den beri **tamamen yerel**, LAN sync ile taşınır.

## Tiers
| Tier | Backend | Quota-counted | Lifecycle |
|---|---|---|---|
| **Free** | Supabase Storage `free-media` bucket | **No** | Permanent; ≤2 MB/file. **Yalnızca paylaşım yolu yazar** (`world_characters` mirror push → [[media_bundler]]); görsel seçmek artık yükleme tetiklemez |
| ~~**Counted**~~ | Cloudflare R2 `{userId}/{sha}.{ext}` | — | **Emekli (Phase D)**: PUT 410, GET bir sürüm daha çalışır, sonra prefix süpürülecek |
| ~~**Transient**~~ | ~~R2 `transient/{userId}/…`~~ | — | **Kalktı (Faz 5d, 099)**: LRU, talep-üzerine akış, `missing_shas` ve oturum kapısı gitti |
| **World media** | Cloudflare R2 `worlds/{worldId}/{sha}{ext}` | **Yes** — kişi başı **1 GB** (bütün dünyaları), toplam tavan **9 GB** (`pub/` ile ortak) | Dünya multiplayer oldukça kalıcı; satır silinince (tek tek, multiplayer kapatma, dünya/hesap silme — CASCADE) key `r2_evict_queue`'ya düşer, cron siler. Bayt worker'dan geçmez: `POST /world-media/sign` imzalı URL verir |
| **Pinned** | Cloudflare R2 `pub/{sha}.{ext}` | **No** (toplam 9 GB tavanı dünya medyasıyla paylaşır, 500 MB/yayıncı) | Eviction yok; `pub_asset_refs` refcount 0 olunca kuyruğa atılır (089). Yazan iki yol: marketplace yayını ([[publish_media_pinner]]) ve karakter ek resimleri ([[media_bundler]], ref_key `char:{id}`) |
| **First-party art** | App bundle `assets/art/srd/` + R2 `catalog/art/{uuid}.webp` | **No** (kullanıcı yüklemesi değil) | Salt-okunur, sürümsüz; `cacheDir/art/` altında cache'lenir |

## Flow
1. Upload → pick tier by kind (per-kind size caps: portrait/cover 4 MB, diğer görseller 5 MB, battle map 10 MB, ses 10 MB, **world_pdf 20 MB**, bilinmeyen kind için 20 MB ceiling).
2. ~~Counted~~: yol kapalı — Worker `counted_tier_retired` (410) döner.
3. World media (Faz 5d): push turu giden satırların `dmt-content://` ref'lerinden bulutta olmayanları yükler ([[world_media_sync]]); multiplayer açılınca dünyanın tamamı ilerlemeyle gider; dünya açılışında tam uzlaştırma + yetim temizliği. Kuyruğu (`r2_evict_queue`) **saatlik cron** (`scheduled()`) boşaltır, `/admin/evict-sweep` elle yedek yol.
4. Pinned: **client girişi** [[publish_media_pinner]] — marketplace yayını öncesi payload'daki tüm medya ref'leri gezilir, her biri `AssetService.uploadPub` ile `pub/{sha}{ext}`'e taşınır ve ref `dmt-asset://pub/…` olarak yeniden yazılır (refcount sahibi = listing id, bu yüzden id yayından önce client'ta üretilir). `pub_asset_reserve` RPC (dedup + cap; `exists=true` → PUT atlanır) → Worker `pub/` PUT'unda `get_pub_upload_allowed` rezervasyonu doğrular. `pub_asset_release` / hesap silme ref'i düşürür; son ref gidince `trg_drop_orphan_pub_asset` objeyi evict kuyruğuna atar (aynı sweep, `r2_key` kolonu üzerinden). Anahtar içerik adresli olduğu için kuyruk satırı bayatlayabilir: `r2_evict_pop` (090, 099'da genelleşti) obje hâlâ canlıysa satırı döndürmüyor. Pin başarısız olursa yayın **iptal edilir** ([[publish_media_pinner]]) — aksi halde listing yayıncının local path'iyle canlıya çıkıyordu.
5. Delete entity/world/package → [[entity_media_cleanup_service]] removes cloud copy (local cache kept).
6. Delete package / world → `FirstPartyArtService.sweepUnreferenced` **kart görsel cache'ini süpürür** (2026-09-12): `cacheDir/art/` altında canlı hiçbir referansta geçmeyen her dosya silinir. Referans kaynakları: `package_entities` + `world_entities`.`image_path`, **artı** `trash_items` ve `world_characters` payload'ları — silme 30 günlük soft-delete olduğu için çöpteki paketin görselleri "Geri al" penceresi boyunca korunmalı. Refcount yok, silme başına tek tarama — iki paket/dünya aynı görseli paylaşsa (ya da dünya kopyalanmış olsa) doğru, eski sürümlerden kalan çöp de aynı geçişte gider. Çöp purge'ü sweep tetiklemez; oradan düşen görseller bir sonraki silmede gider. Transaction dışında çağrılır (dosya IO'su DB kilidini tutmasın).

## Key Constants / Invariants
- Free media **intentionally excluded** from quota (migration 053 invariant).
- Free tier'a **eager upload yok**: portre/kapak seçimi yalnızca yerel kopya
  bırakır. Buluta çıkış tek sebeple olur — dünya mirror push'u (portre) ya da
  marketplace yayını ([[publish_media_pinner]] → `pub/`). Paylaşılmayan içerik
  hiç yüklenmez.
- Per-kind limit **yetkilidir**: `pub/` için Worker `KIND_MAX_BYTES[kind] ?? MAX_UPLOAD_BYTES`; dünya medyası için `world_media_max_bytes(kind)` (099) — harita 10 / diğer 5 / ses 10 / PDF 20 MB, limiti aşan dosya **yüklenmez**, yerelde çalışır, kullanıcıya söylenir.
- `application/pdf` Worker MIME allowlist'inde (`ALLOWED_MIME_EXACT`).
- Kota **yalnız dünya medyasında** (kişi başı 1 GB, `get_media_quota`); "multiplayer aç" toplamı önden hesaplar, sığmıyorsa dünyayı hiç yayınlamadan reddeder. UI'da genel kota göstergesi yok (Faz 7).
- Tek toplam tavan (`media_total_cap_bytes()` 9 GB) `pub/` ve `worlds/`'ü birlikte bağlar; iki rezervasyon aynı advisory lock'u alır. 089'un 5+5 bölmesi LRU'yu korumak içindi, LRU kalkınca gerekçesi de kalktı.
- **İndirme eager'dır** (2026-09-12): `marketplace_listing_provider.downloadAsNewCopy` payload'ı kurduktan sonra `remoteMediaRefs` ile bütün cloud+public ref'leri gezip `AssetRefResolver` üzerinden 4'erli diske çeker (`marketplaceDownloadProgressProvider` ile `done/total`). Öncesi tembeldi — bayt ancak kart ilk çizilirken iniyordu, yani "indirdim" diyen kullanıcı çevrimdışına geçince dünyayı görselsiz açıyordu. Kısmi başarı kasıtlı olarak zararsız: düşen ref çizim anında yeniden denenir, indirme başarısız sayılmaz.
- Kart görselleri (`cacheDir/art/`) **paket/dünya silindiğinde temizlenir**; boyut cap'i yoktur, yaşam süresini referans belirler. `EvictionSweeper` bu dizini kapsamaz (o `cacheDir/content/` üzerinde çalışır ve şu an hiçbir yerde instantiate edilmiyor).
- `pub/` DELETE Worker'da **yasak** — silimi refcount belirler, doğrudan DELETE başkasının listing'ini yok ederdi.
- Paylaşım gövdeleri R2'de değil Postgres'te: `entity_shares.payload_json` ≤ **512 KB** (CHECK), dünya başına ≤ **4000** satır (`max_shares_per_world()` + trigger, 088). `worlds` silimi satırları CASCADE'le düşürür (026).

## Related
- MoCs: [[Media-and-Assets]], [[Backend-Infra]]
- Source Docs: `flutter_app/docs/security_media_supabase_r2_audit_may21.md`

## Transient artık talep üzerine dolar (2026-09-08, Phase C) — *Faz 5d ile kalktı*

Paylaşım anında hiçbir bayt yüklenmez. Havuza yalnızca **o an gerçekten birine
eksik olan** dosya girer:

1. DM paylaşırken payload'daki yerel yollar `dmt-content://{sha}{ext}`'e
   çevrilir (`shared_media_courier`, 5d'de silindi) — baytlar DM'in diskinde kalır.
2. Oyuncu çözemediği sha'ları `world_members.missing_shas`'e yazar
   (`missing_media_reporter` → `report_missing_shas`, migration 092).
3. DM CDC ile görür ve **yalnızca istenenleri** `uploadTransientShare` ile
   yükler — ama sadece `WorldSyncService.isSessionOpen(worldId)` doğruysa
   (presence'ta DM'den başka üye var). DM tek başına hazırlık yaparken havuz
   büyümez.

Sonuç: oturumun ikinci haftasında transient yükü neredeyse sıfır — oyuncularda
dosyalar zaten yerelde. Detay: `docs/media-storage-redesign.md`.


## Projeksiyon da transient'e yazar (2026-09-08, Phase D) — *Faz 5d: artık dünya medyasına*

Kart / harita / mindmap projeksiyonunda eksik bildirme turu yoktur (oyuncu
`world_projection` satırını okur), o yüzden baytlar önden çıkar:
`SharedMediaCourier.publish(worldId, path)` yükler ve ref'i döndürür. Dönen
transient ref **kalıcı satıra yazılmaz** — LRU atarsa DM kendi resmini
kaybederdi. Giriş noktaları: `prepareEntityImagesForProjection`,
`projectableMapImage`, `WorldMapNotifier.ensureMapImageProjectable`.


## Ref artık tier adlandırmıyor (2026-09-22, Faz 3.5)

Paylaşım ve projeksiyon payload'ları `dmt-transient://` yerine
**`dmt-content://{sha}{ext}`** taşıyor. Fark isimden ibaret değil: eski biçim
baytların transient havuzda olduğunu iddia ediyordu, yani LRU atınca ref
ölüyordu ve bu yüzden kalıcı bir satıra **yazılamıyordu** (vault'un
"dönen transient ref kalıcı satıra yazılmaz" kuralı). Yeni biçim hiçbir katman
adlandırmıyor, dolayısıyla her okuyan kendi yolundan çözüyor:

| Kim | Yol |
|---|---|
| Baytları üreten cihaz | [[content_ref_index]] → `content_paths` → yerel dosya, **ağ yok** |
| Başka cihaz | içerik store'u → *(5d'den beri)* toplu imza → R2 `worlds/` → store |
| Hiçbir yerde yoksa | *(5d'den beri)* bulutta yok demek: yüklenmedi ya da limitin üstünde |

Havuz mekaniği, kota ve LRU **değişmedi** — transient hâlâ baytların tek
bulut yolu. Değişen tek şey satıra yazılabilir bir ref biçiminin doğmuş
olması; Faz 4 push'u bunu gerektiriyordu. Eski `dmt-transient://` gövdeleri
okunmaya devam ediyor. Detay: `docs/online-sync-redesign.md` §2.7 + §4.5.


## Dünya medyası bulutta (2026-09-23, Faz 5d)

Multiplayer açılınca dünyanın **tamamı**, görseller dahil, kalıcı olarak R2'de
(`worlds/{worldId}/{sha}{ext}`, 099). Transient havuz, `missing_shas`, oturum
kapısı (presence) ve 15 sn'lik yeniden deneme döngüsü kalktı. Nedeni: DM'in
ikinci cihazına görsel hiç gelmiyordu (kendi uid'sinden gelen talebi
"kendim" sayıyordu) ve DM çevrimdışıyken oyuncunun yeni cihazı görselsiz
kalıyordu.

| Adım | Nerede |
|---|---|
| Hangi medya | push turunun giden satırlarındaki `dmt-content://` ref'leri — [[cloud_push_service]] `mediaRefsOf` (harita = `world_map_data` + `world_encounters.map_path`) |
| Yükleme | [[world_media_sync]]: `world_media_reserve` (sahiplik + limit + kota) → `POST /world-media/sign {op: put}` (100 sha, tek istek) → imzalı URL'e PUT (boyut + tür imzaya bağlı) → `world_media_confirm` |
| Ne zaman | tur sonrası yalnız değişen satırların medyası; dünya açılışında (`catchUp`, pull'dan **sonra**) tam uzlaştırma + yetim temizliği; "multiplayer aç"ta tamamı, ilerlemeyle ([[cloud_push_provider]]) |
| Okuma | [[asset_ref_resolver]]: store → `content_paths` → `POST /world-media/sign {op: get}` (50 ms pencerede toplanır, tek istek) → R2 → store. DM'in ikinci cihazı da oyuncu da aynı yol; izin **dünya üyeliği** |
| Silme | satır silinince trigger key'i `r2_evict_queue`'ya yazar, cron siler. Yetim temizliği 10 dk'dan genç satıra dokunmaz |

İzin neden üyelik, kart değil: oyuncu bir sha'yı yalnız kendisine paylaşılmış
bir karttan öğrenebilir, tahmin edemez; kart bazlı izin sha → kart indeksi
isterdi. Bilinçli sınırlar (dedup yok, sıkıştırma yok, imzalı URL 1 saat
geçerli, paket medyası henüz yok): `docs/online-sync-redesign.md` §4.8.3.
