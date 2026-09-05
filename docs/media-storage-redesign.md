# Medya Depolama Yeniden Tasarımı — "bulutta sadece paylaşılan şey durur"

Durum: **tasarım kararı, henüz uygulanmadı.**
Tarih: 2026-09-05
Yerini aldığı model: [vault/20-Systems/Media-Storage-Tiers.md](../vault/20-Systems/Media-Storage-Tiers.md) (üç tier: Free / Counted / Transient)

## Bir cümlede

Dünya buluta hiç çıkmaz; cihazdan cihaza taşıma yalnızca LAN sync'tir. Buluttaki
medya iki sebebe indirgenir: **online oturumda DM'in paylaştığı şey** ve
**marketplace'e yayınlanan içerik**. Kullanıcı başına kota diye bir şey kalmaz;
tek sınır 10 GB'lık global R2 havuzudur.

## Neden

- Dünyalar artık bulut aynası tutmuyor (migration 077, `SyncEngine`/outbox kaldırıldı).
  Bir kullanıcının kendi haritasını, PDF'ini, SFX'ini R2'de tutmasının hiçbir
  okuyucusu kalmadı — LAN sync medya dahil her şeyi taşıyor.
- Dolayısıyla **Counted tier (100 MB/kullanıcı) ölü yük**: kota muhasebesi,
  `checkAssetQuota`, `get_user_total_storage_used`, temizlik yolları hep
  okuyucusu olmayan bir veriyi koruyor.

## Yeni model — iki tier

| Tier | Backend | Kim yazar | Ömür |
|---|---|---|---|
| **Free** | Supabase Storage `free-media` | profil fotoğrafı (+ mevcut world/package cover) | Kalıcı, kotasız, ≤2 MB/dosya |
| **Pool (R2, 10 GB global)** | Cloudflare R2 | aşağıdaki iki sınıf | Sınıfa göre: `transient` LRU-atılır, `pinned` atılmaz |

Free tier duruyor ama rolü daralıyor: **profil fotoğrafı** için ayrılıyor.
Cover'lar küçük ve marketplace vitrininde gerektiği için orada kalır; kotadan
muaf olma invariantı (migration 053) korunur.

Counted tier **kaldırılır**. Bkz. "Göç" bölümü.

### R2 havuzunun iki sınıfı

| Sınıf | Key şeması | Kim üretir | Eviction |
|---|---|---|---|
| `transient` | `transient/{uploaderId}/{sha}.{ext}` | DM'in online oturumda paylaştığı kartların medyası | **LRU** — `last_used_at`'e göre |
| `pinned` | `pub/{sha}.{ext}` | marketplace paket/dünya medyası + multiplayer dünyadaki oyuncu karakter medyası | **Yok** — refcount 0 olunca silinir |

> [!warning] Havuz bölünmesi zorunlu
> İkisi tek 10 GB'ı paylaşırsa, `pinned` büyüdükçe LRU'nun yiyebileceği alan
> sıfıra iner ve paylaşımlar sessizce patlamaya başlar. Bütçe **ayrı** tutulur:
>
> - `pinned` tavanı: **7 GB**. Dolduğunda yeni marketplace yayını *reddedilir*
>   (`pool_full` hatası, admin müdahalesi gerekir). Transient hiç etkilenmez.
> - `transient` rezervi: **≥ 3 GB**, kendi içinde LRU. Kapasite dolduğunda
>   `transient_reserve` en eskiyi atar — bugünkü davranış aynen sürer.
>
> Yani "alan dolarsa en eski silinir" kuralı **yalnızca transient dilime** uygulanır.

### Kullanıcı başı kota diye bir şey yok

**Kalıcı depolama kotası kaldırılıyor.** Counted tier ile birlikte
`checkAssetQuota`, `get_user_total_storage_used` ve "depolaman doldu" durumu
tamamen gider. Kullanıcı dünyasını istediği kadar büyütür — hepsi yerelde durur,
cihazlar arası LAN sync ile taşınır. Bulutta yer tutmadığı için sayılacak bir şey
de yoktur.

Havuz tarafındaki iki sınır **kota değil, paylaşılan kaynakta adalet koruması**:

| Sınır | Ne için | Dolunca ne olur |
|---|---|---|
| transient, kullanıcı başı **100 MB** | tek bir DM'in 3 GB'lık transient dilimi tek başına yiyip başka masaların paylaşımlarını LRU'ya attırmasını engeller | o DM'in **kendi** en eski paylaşılmış asset'i atılır; kullanıcıya hata gösterilmez, kalıcı bir şey kaybolmaz (DM tekrar paylaşınca geri yüklenir) |
| pinned, kullanıcı başı **500 MB** | tek bir yayıncının 7 GB'lık marketplace dilimini tüketmesini engeller | yeni yayın reddedilir, açık hata mesajı verilir (mevcut listing'ler etkilenmez) |

İkisi de yerel içeriğe dokunmaz. Kullanıcının "şu kadar alanım var" diye
yöneteceği bir bütçesi yoktur; bu sayılar yalnızca sunucu tarafı korumadır ve
UI'da kota göstergesi olarak sunulmaz.

## Ne bulut'a çıkar, ne çıkmaz

### Online oturum (multiplayer)

1. **Karakterler her zaman sync'tir.** `world_characters` zaten abone tablolar
   arasında; karakter medyası (portre, ekstra görsel) `pinned` olarak yüklenir —
   oyuncunun karakteri oturum ortasında LRU'ya yem olmamalı. Refcount, karakter
   satırının kendisidir: karakter silinince/dünyadan çıkınca medya bırakılır.
2. **Karakter yaratımı için gerekli kategorilerdeki kartlar** (class, subclass,
   background, race/lineage, feat, item, spell — dünyanın şemasında
   `usedInCharacterCreation` işaretli kategoriler) medyasıyla birlikte otomatik
   paylaşılır. Böylece oyuncu her zaman karakter yaratıp düzenleyebilir.
   - Kart bir **marketplace paketinden** geliyorsa gövde de medya da yüklenmez:
     oyuncu paketi zaten indirir (`world_packages` → paket kurulumu). Bu bugünkü
     `payload_json = NULL → linked kart` kuralının medyaya uzantısıdır.
   - Kart **dünyaya özgü** (pakette yok) ise gövdesi `entity_shares.payload_json`
     ile, medyası `transient` olarak gider.
3. **Diğer her şey yalnızca DM paylaşınca.** Oyuncu bir item kazandıysa DM o kartı
   paylaşır; kartın medyası o an transient'e yüklenir. Dünyanın kalan medyası
   (haritalar, NPC portreleri, handout'lar) buluta **hiç çıkmaz**.

Yani transient dilime "dünyanın tüm medyası" değil, **yalnızca paylaşılmış kartların
medyası** girer. Bu, `entity_share_prepare.dart`'ın bugünkü davranışının daraltılmış
hâli, genişletilmiş hâli değil.

### Marketplace

- Kullanıcı paket/dünya yayınlarken **tüm medyası** R2'ye çıkar, istisna yok.
  Sınıf: `pinned`.
- **Dedup zorunlu, ve bugünkü key şeması buna elverişli değil.** `{userId}/{sha}`
  kullanıcı-prefix'li olduğu için iki kişi aynı görseli yayınlarsa iki kopya
  oluşur. Marketplace medyası içerik-adresli ortak prefix'e taşınır:
  `pub/{sha}.{ext}`, yanında `pub_assets(sha, bytes, refcount)` tablosu.
  - Yayın: `sha` varsa yükleme atlanır, `refcount += 1`.
  - Listing silinince `refcount -= 1`; 0 olunca obje silinir.
  - "Marketplace'de zaten olan bir paketin içeriği tekrar yüklenmez" kuralı budur;
    indiren kişide o paket zaten otomatik kurulur.
- `pinned` LRU'ya tabi değildir — indirilebilirliği garanti altındadır.

## Admin paneli — doluluk görünürlüğü

Bu sınırların hepsi sunucu tarafında sessizce uygulanıyor; **görünmezlerse
"neden yayınlayamıyorum" biletine dönüşürler.** Doluluk hem havuz hem kullanıcı
bazında admin panelinde okunabilir olmalı.

Yeni ekran değil: mevcut [`admin_screen.dart`](../flutter_app/lib/presentation/screens/admin/admin_screen.dart)'a
bir **Storage** sekmesi eklenir (audit-log / bug-reports / moderation sekmelerinin
yanına), veri `admin_users_remote_ds.dart` üzerinden gelir.

### Genel görünüm (havuz)

| Gösterilen | Kaynak |
|---|---|
| `pinned` kullanılan / 7 GB, obje sayısı, dedup tasarrufu (`SUM(bytes)` vs `SUM(bytes*refcount)`) | `pub_assets` |
| `transient` kullanılan / 3 GB, obje sayısı, en eski `last_used_at` | transient tabloları |
| Son 24 s / 7 g eviction sayısı ve atılan bayt | `transient_evict_queue` geçmişi |
| Free bucket kullanımı (kotasız, bilgi amaçlı) | mevcut `get_system_storage_stats()` |

Mevcut `get_system_storage_stats()` yalnızca Supabase `storage.objects`'i sayıyor —
R2 havuzunu **görmüyor**. Ya genişletilir ya da yanına `get_r2_pool_stats()`
eklenir (ikisi de `is_admin()` guard'lı, aynı desen).

### Kullanıcı bazında

`search_users` / `get_all_users_summary` satırlarına iki alan eklenir ve kullanıcı
detayında gösterilir:

- `pinned_bytes` / 500 MB — yayınladığı marketplace medyası (dedup sonrası payı).
- `transient_bytes` / 100 MB — o an paylaşımda tuttuğu medya.

Sıralanabilir olmalı: "en çok yer kaplayan 20 kullanıcı" havuz dolduğunda ilk
bakılacak liste odur.

### Admin aksiyonları

- Bir kullanıcının transient'ini boşalt (zararsız — DM tekrar paylaşınca yüklenir).
- Bir listing'in `pinned` medyasını düşür (moderasyon zaten listing siliyor;
  refcount 0'a inince obje gider, ayrı bir düğmeye gerek yok).
- Sınırları koddan değil **config'den** okumak: 7 GB / 3 GB / 500 MB / 100 MB
  ayarlanabilir olmalı, yoksa her kalibrasyon deploy gerektirir.

> [!note] Kullanıcıya gösterilmez
> Bu sayılar admin panelinde kalır. Son kullanıcı UI'ında kota göstergesi yoktur —
> "kotan var" mesajı vermek, kaldırdığımız modeli geri getirir.

## Göç (Counted tier'ın kaldırılması)

Bu yıkıcı bir değişiklik; sırası önemli:

1. Client yeni `counted` upload'u yapmayı bırakır (`entity_image_upload`,
   `map_image_upload`, `pdf_library_service` → yerel-only veya transient).
2. Worker `{userId}/{sha}` prefix'ini **read-only**'ye alır: GET çalışır, PUT 410 döner.
   Kullanıcılar mevcut bulut kopyalarını indirebilsin diye bir sürüm boyunca kalır.
3. Bir sonraki sürümde prefix süpürülür; `checkAssetQuota`,
   `get_user_total_storage_used` ve kota UI'ı kaldırılır.
4. `community_assets` satırlarından counted olanlar temizlenir.

`world_pdf` (50 MB) buluttaki en büyük counted kalemdi — yeni modelde PDF
kütüphanesi tamamen yereldir ve LAN sync ile taşınır.

## Bilinen tavanlar

- **Transient eviction canlı oturumu bozabilir.** `transient_touch` yalnızca
  indirmede tetiklenir; bir görseli herkes önbelleğe almışsa `last_used_at`
  tazelenmez ve obje atılabilir — sonra katılan oyuncu göremez. Kabul edilen
  tavan: DM yeniden paylaşınca tekrar yüklenir. Gerçek çözüm, aktif üyeliği olan
  dünyaların paylaşılmış asset'lerini eviction'dan muaf tutmaktır (o zaman
  `pinned`/`transient` ayrımı üçe çıkar).
- **7 GB / 3 GB bölünmesi ve kullanıcı başı 100 MB / 500 MB elle seçilmiş sayılardır.** Ölçüm çıkınca ayarlanır;
  `pinned` doluluğu admin panelinde görünmeli, yoksa yayın reddi sürpriz olur.
- Karakter yaratım kategorilerinin otomatik paylaşımı, dünyaya özgü çok sayıda
  kart varsa büyük bir ilk yükleme olabilir. Paylaşım başına kart/bayt tavanı
  konmalı.

## Etkilenen yerler

- `flutter_app/lib/presentation/screens/admin/` — Storage sekmesi;
  `admin_users_remote_ds.dart` + `get_r2_pool_stats()` / kullanıcı satırlarına
  `pinned_bytes` & `transient_bytes`.
- `cloudflare/src/worker.ts` — prefix sınıfları, `pub/` rotası, counted PUT 410.
- `supabase/migrations/` — `pub_assets` + refcount RPC'leri, `transient_reserve`
  bütçe parametresi, kota RPC'lerinin düşürülmesi.
- `flutter_app/lib/application/services/entity_share_prepare.dart` — yaratım
  kategorilerinin otomatik kapanışı, medya sınıfı seçimi.
- `flutter_app/lib/data/network/asset_service.dart`, `entity_image_upload.dart`,
  `map_image_upload.dart`, `pdf_library_service.dart` — counted yolunun sökülmesi.
- `marketplace_cover_sync_service.dart` + paket yayın yolu — `pub/{sha}` dedup.
