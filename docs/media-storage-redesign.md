# Medya Depolama Yeniden Tasarımı — "bulutta sadece paylaşılan şey durur"

Durum: **kısmen uygulandı.**
- ✅ Postgres paylaşım sınırları — `088_share_payload_limits.sql`
- ✅ Havuz bütçeleri + `pinned` sınıfı (`pub_assets`, worker `pub/` rotası) — `089_media_pool_budgets.sql`
- ✅ Bayat evict satırı canlı objeyi silmiyor — `090_evict_skip_relive.sql`
- ✅ Evict kuyruğu cron ile süpürülüyor (`transient_evict_pop`, zamanlanmış job)
- ✅ Admin rate limit fail-open — limit tablosu okunamazsa moderasyon aksiyonu bloklanmaz
- ✅ Marketplace yayın yolu `pub_asset_reserve`'e bağlandı — `publish_media_pinner.dart`,
  `AssetService.uploadPub`, listing silmede `pub_asset_release`
- ✅ Pinlenemeyen medya yayını **iptal ediyor** (aşağıdaki nota bak) + lokalize hata
  mesajı (`publishDialogMediaPinFailed`, 4 dil)
- ✅ Moderatör silmesi de medyayı bırakıyor — `091_admin_delete_releases_media.sql`
- ✅ Admin Storage sekmesi havuz görünümü — `admin_screen.dart` `_R2PoolSection`,
  `R2PoolStats` / `adminR2PoolStatsProvider` (kullanıcı başına `pinned_bytes` /
  `transient_bytes` kolonları hâlâ ⬜, `search_users` migration'ı gerekiyor)
- ✅ Free tier eager upload'ları kaldırıldı — portre/kapak seçimi artık yüklemiyor
- ✅ **Phase C — oturum kapısı + talep-üzerine akış** — `092_media_on_demand.sql`
  (`world_members.missing_shas`, `report_missing_shas` RPC),
  `world_sync_service` presence, `shared_media_courier.dart` (DM),
  `missing_media_reporter.dart` (oyuncu). Bkz. "Phase C nasıl uygulandı".
- ✅ **Phase D — counted tier sökümü** — client upload yolları, worker PUT 410,
  kota UI. Bkz. "Phase D nasıl uygulandı". Kalan tek adım göç listesinin 3.
  maddesi: prefix süpürme + `check_asset_quota` / `get_user_total_storage_used`
  RPC'lerinin düşürülmesi — **bir sonraki sürümde**, kullanıcılar mevcut bulut
  kopyalarını indirebilsin diye.
- ⬜ **Phase E — marketplace medya zip'i** (indirmede toptan, official `art-bundle` deseni). Bkz. son bölüm.

> [!warning] Deploy bekleyenler
> - `091_admin_delete_releases_media.sql` henüz deploy edilmedi.
> - `092_media_on_demand.sql` henüz deploy edilmedi. **Client'tan önce gitmeli**:
>   kolon/RPC yokken `report_missing_shas` hata verir, oyuncu eksik bildiremez ve
>   paylaşılan resim hiç gelmez.
> - Launch öncesi **Cloudflare Workers Paid** planına geçilmeli (cron + istek hacmi).

> [!note] Karar değişikliği — pinner artık yayını bloklar
> Bu belgenin ilk hâlinde pin "best-effort"tü: pinlenemeyen ref eski hâliyle
> payload'da kalır, yayın yine de yapılırdı. Tersine çevrildi. Sebep: yayıncının
> local dosya yolunu taşıyan bir listing indirende **sessizce** kırık açılıyor,
> üstelik yayın başarılı görünüyor. Artık tek bir ref bile pinlenemezse yayın
> iptal edilir ve o ana kadar pinlenmiş ref'ler bırakılır. Karar geri alınabilir;
> geri alınırsa `marketplace_listing_provider.publishSnapshot`'taki
> `PublishMediaPinFailure` throw'u kaldırılır.

Tarih: 2026-09-05 (uygulama başlangıcı 2026-09-07, son güncelleme 2026-09-08 — Phase D)
Yerini aldığı model: [vault/20-Systems/Media-Storage-Tiers.md](../vault/20-Systems/Media-Storage-Tiers.md) (üç tier: Free / Counted / Transient)

## Bir cümlede

Dünya buluta hiç çıkmaz; cihazdan cihaza taşıma yalnızca LAN sync'tir. Buluttaki
medya iki sebebe indirgenir: **açık bir oturumda DM'in paylaştığı şey** ve
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
Kotadan muaf olma invariantı (migration 053) korunur.

> [!note] Uygulandı — free tier'a eager upload yok
> Portre ve kapak seçimi artık hiçbir şey yüklemez, yalnızca yerel kopya
> bırakır. Bulut kopyası iki paylaşım yolundan doğar: dünya mirror push'u
> (`media_bundler`, portre) ve marketplace yayını (`publish_media_pinner`,
> `pub/`). Marketplace vitrini kapağı zaten payload'dan değil, listing satırına
> yazılan inline base64 küçük resimden geliyor — o yol yerel yolu da çözer.

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
> - `pinned` tavanı: **5 GB**. Dolduğunda yeni marketplace yayını *reddedilir*
>   (`pool_full` hatası, admin müdahalesi gerekir). Transient hiç etkilenmez.
> - `transient` rezervi: **5 GB**, kendi içinde LRU. Kapasite dolduğunda
>   `transient_pool_cap_bytes()` en eskiyi atar — bugünkü davranış aynen sürer.
>
> Yani "alan dolarsa en eski silinir" kuralı **yalnızca transient dilime** uygulanır.

### Kullanıcı başı kota diye bir şey yok

**Kalıcı depolama kotası kaldırılıyor.** Counted tier ile birlikte
`checkAssetQuota`, `get_user_total_storage_used` ve "depolaman doldu" durumu
tamamen gider. Kullanıcı dünyasını istediği kadar büyütür — hepsi yerelde durur,
cihazlar arası LAN sync ile taşınır. Bulutta yer tutmadığı için sayılacak bir şey
de yoktur.

**Transient'te kullanıcı başı sınır da yoktur.** Bir DM bir şey paylaştığında
oyuncular onu indirir ve yerelde tutar; obje sonradan LRU'dan düşse bile kimse
bir şey kaybetmez. Havuz genelinde LRU zaten *en eski* dokunulanı atar, yeni
yükleneni değil — tek bir masanın anlık yükü, başka masaların taze içeriğini
öldürmez. Kalan tek sınırlar sunucu tarafı korumadır:

| Sınır | Ne için | Dolunca ne olur |
|---|---|---|
| pinned, kullanıcı başı **500 MB** | tek bir yayıncının 5 GB'lık marketplace dilimini tüketmesini engeller | yeni yayın reddedilir, açık hata mesajı verilir (mevcut listing'ler etkilenmez) |

Buna ek olarak transient'te **dosya başına 100 MB** tavanı durur
(`transient_max_file_bytes()`); bu bir kota değil, tek bir upload'ın havuzu
sarsmasını engelleyen bir emniyet kapağıdır.

Hiçbiri yerel içeriğe dokunmaz. Kullanıcının "şu kadar alanım var" diye
yöneteceği bir bütçesi yoktur; bu sayılar yalnızca sunucu tarafı korumadır ve
UI'da kota göstergesi olarak sunulmaz.

## Ne bulut'a çıkar, ne çıkmaz

### Online oturum (multiplayer)

#### Oturum kapısı — transient yalnızca oturum açıkken yazılır

Bir dünyanın "online" olması ile **oyunun oynanıyor olması** aynı şey değil. DM
kampanyayı haftalarca tek başına hazırlar; bu hazırlığın buluta çıkması için
sebep yok. Bu yüzden transient havuzu bir **oturum** kapısının arkasındadır.

**Oturum = DM'in realtime kanalında kendisi dışında en az bir üye var.**
Buton yok, kolon yok, RPC yok — DM oturum başlatmayı unutamaz.

`world_sync_service.dart` her dünya için zaten ortak bir kanal açıyor
(`dmt:world:{worldId}`); DM de oyuncu da oradadır. Supabase Realtime
**Presence** bu kanalın üstünde bedava gelir: katılırken `channel.track(...)`,
DM tarafında `onPresenceSync` bir `bool sessionOpen` çevirir ve transient
upload'ı yalnızca o gate'ler.

> [!note] Karar değişikliği — 2026-09-08
> İlk tasarımda oturum `worlds.session_started_at TIMESTAMPTZ NULL` kolonu ve
> `session_start()` / `session_end()` RPC'leriydi; DM bir düğmeye basardı.
> Presence lehine kaldırıldı: kanal zaten açık, üye listesi zaten orada, ve
> unutulan düğme diye bir hata sınıfı kalmıyor.

| | Oturum kapalı | Oturum açık |
|---|---|---|
| Kart paylaşma (`entity_shares` satırı + `payload_json`) | **evet** — yazılır, oyunculara gider | evet |
| Kart medyasının transient'e yüklenmesi | **hayır** | evet, talep üzerine |
| DM'in yerel değişiklikleri | yerelde, her zaman | yerelde, her zaman |
| Karakter medyası (`pinned`) | evet | evet |

Yani "paylaş" dediği şey kaybolmaz: satır durur, oyuncu kartın **gövdesini**
görür; eksik olan sadece görseldir ve oturum açılınca gelir. Oturum kapanınca
hiçbir şey silinmez — objeler LRU sırasına düşer ve zamanı gelince atılır.

Presence kapısının sağlamlığını asıl kurtaran şey, upload'ın zaten talep-üzerine
olması (bir sonraki bölüm): kapı yanlış tarafa düşse bile kayıp yok.

| Durum | Ne olur |
|---|---|
| DM'in soketi düşer, presence boşalır | Kapı kapanır; bekleyen `missing_shas` kalıcı olduğu için bağlantı dönünce yüklenir. |
| Oyuncu uygulamayı günlerce açık bırakır | Kapı sürekli açık ama **hiçbir şey yüklenmez** — kimse eksik bildirmiyorsa upload da yok. |
| Oyuncu sadece karakter sayfasına bakar | Oturum açılır, yalnızca onun eksikleri yüklenir. İstenen davranış. |
| DM tek başına hazırlık yapar | Presence boş → kapı kapalı. Hedefin tamamı bu. |

#### Medya talebe göre yüklenir (DM push değil, oyuncu pull)

Oturum açıldığında DM'in bütün paylaşılmış medyasını topluca yüklemesi havuzun
en büyük israfı olurdu: oyuncuların çoğunda o dosyalar geçen oturumdan zaten
yerelde. Onun yerine eksik listesi **oyuncudan** gelir:

1. Paylaşım satırının **gövdesi zaten sha listesidir**: DM paylaşırken yerel
   yolları `dmt-transient://{sha}{ext}` ref'lerine çevirir (bayt yüklemez).
2. Oyuncu satırı uygular; çözemediği sha'ları kendi üyelik satırına yazar:
   `world_members.missing_shas TEXT[]`. **Yeni abone tablo gerekmez** —
   `world_members` zaten beş abone tablodan biri.
3. DM bu güncellemeyi görür, yalnızca listedeki sha'ları transient'e yükler.
4. Oyuncu indirir, yerele yazar; listeyi baştan yazar, çözülen sha düşer.

> [!note] Karar değişikliği — `entity_shares.media_shas` yazılmadı
> Tasarımda ayrı bir sha kolonu vardı. Gerekmedi: gövde zaten içerik-adresli
> ref taşıyor, yani `payload_json`'ı taramak aynı listeyi veriyor. İkinci bir
> kolon, aynı gerçeğin ayrışabilen ikinci kopyası olurdu.

Sonuç: havuza yalnızca **o an gerçekten birine eksik olan** bayt girer, ve
oturumun ikinci haftasında transient yükü neredeyse sıfırdır.

#### İstisna — karakter yaratımı ve seviye atlama oturum kapısına tabi değil

Oyuncu davetiyeyi aldığı an karakterini yaratabilmeli; DM'in oturum başlatmasını
beklememeli. Bu yüzden **karakter yaratım/ilerleme kategorilerindeki kartlar
(aşağıdaki madde 2) oturumdan bağımsız olarak, medyasıyla birlikte paylaşılır.**
Bunlar dünyanın en küçük medya kümesi (sınıf/ırk/feat ikonları) ve karakter
akışının çalışması için gerekli; kapının tuttuğu şey haritalar, handout'lar ve
NPC portreleridir. Aynı talep-üzerine akış burada da geçerlidir, sadece
presence kontrolü atlanır.

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
3. **Diğer her şey yalnızca DM paylaşınca — ve yalnızca oturum açıkken.** Oyuncu
   bir item kazandıysa DM o kartı paylaşır; kartın medyası, biri onu eksik
   bildirdiğinde transient'e yüklenir. Oturum kapalıysa satır yazılır, medya
   beklemede kalır. Dünyanın kalan medyası
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
  - Listing silinince `refcount -= 1`; 0 olunca obje silinir. Hem sahibin silmesi
    (client `pub_asset_release`) hem moderatör silmesi
    (`admin_delete_marketplace_listing`, migration 091) bu yolu izler — moderatör
    yolu ref'leri doğrudan düşürür, çünkü `pub_asset_release` sahiplik filtreliyor
    ve admin sahibi değil.
  - "Marketplace'de zaten olan bir paketin içeriği tekrar yüklenmez" kuralı budur;
    indiren kişide o paket zaten otomatik kurulur.
- `pinned` LRU'ya tabi değildir — indirilebilirliği garanti altındadır.

### Postgres tarafı — paylaşım gövdelerinin sınırı

Yukarıdaki bütün tavanlar R2'yi koruyor; **kart gövdeleri ise R2'de değil,
Postgres'te** (`entity_shares.payload_json`, migration 078). Bugün orada hiçbir
sınır yok: satır sayısı da, gövde boyutu da serbest. Diğer her eksende limit var
(`055_online_count_limits.sql`: karakter 10, dünya 10, paket 10) — paylaşımda
yok. Madde 2'nin otomatik paylaşımı bunu tek başına şişirebilir: dünyaya özgü
binlerce spell/item kartı olan bir DM, tek dünya açtığında binlerce satır yazar.

| Sınır | Değer | Nerede |
|---|---|---|
| Kart başına gövde | **512 KB** | `CHECK (octet_length(payload_json) <= 524288)` |
| Dünya başına paylaşım satırı | **4000** | `max_shares_per_world()` + BEFORE INSERT trigger |

En kötü hâlde dünya başına ~2 GB, gerçekte ~40 MB. Trigger
`enforce_world_character_limits`'in birebir kalıbı — yeni desen icat edilmiyor,
limit sabiti yine `IMMUTABLE` fonksiyon olarak tek noktadan ayarlanır.

> [!warning] Gövdeler R2'ye taşınamaz
> "Metinleri de LRU havuzuna atalım" cazip görünüyor ama dört sebeple çalışmaz:
>
> 1. **R2'de realtime yok.** `entity_shares` beş abone tablodan biri; gövde
>    oyuncuya push ile düşüyor. Objeye abone olunamaz — satır yine Postgres'te
>    kalır (sha'yı taşımak için) ve oyuncuya ikinci bir tur binerdi.
> 2. **LRU gövdeyi atarsa kart yok olur.** Resim düşünce kart okunur kalıyor,
>    eksik sha bildirilip onarılıyor. Gövde düşerse oyuncunun elinde ölü sha'ya
>    bakan boş satır kalır — "metin hiç kaybolmaz, en fazla resim geç gelir"
>    invariantı ölür.
> 3. **Ekonomi ters.** R2 bayt için ucuz, işlem için pahalı. Gövdeler en küçük
>    ve en sık okunan veri; obje deposunun yanlış ucu.
> 4. **Riski çözmezdi.** 5 GB'lık resim dilimi yanında 10 KB'lık metinler asla
>    "en eski"ye düşmez — dert taşınır, çözülmez.
>
> Doğru yer Postgres; eksik olan tek şey yukarıdaki iki kuraldı.

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
| `pinned` kullanılan / 5 GB, obje sayısı, dedup tasarrufu (`SUM(bytes)` vs `SUM(bytes*refcount)`) | `pub_assets` |
| `transient` kullanılan / 5 GB, obje sayısı, en eski `last_used_at` | transient tabloları |
| Son 24 s / 7 g eviction sayısı ve atılan bayt | `transient_evict_queue` geçmişi |
| Free bucket kullanımı (kotasız, bilgi amaçlı) | mevcut `get_system_storage_stats()` |

Mevcut `get_system_storage_stats()` yalnızca Supabase `storage.objects`'i sayıyor —
R2 havuzunu **görmüyor**. Ya genişletilir ya da yanına `get_r2_pool_stats()`
eklenir (ikisi de `is_admin()` guard'lı, aynı desen).

### Kullanıcı bazında

`search_users` / `get_all_users_summary` satırlarına iki alan eklenir ve kullanıcı
detayında gösterilir:

- `pinned_bytes` / 500 MB — yayınladığı marketplace medyası (dedup sonrası payı).
- `transient_bytes` — o an paylaşımda tuttuğu medya (tavanı yok; sıralama için).

Sıralanabilir olmalı: "en çok yer kaplayan 20 kullanıcı" havuz dolduğunda ilk
bakılacak liste odur.

### Admin aksiyonları

- Bir kullanıcının transient'ini boşalt (zararsız — DM tekrar paylaşınca yüklenir).
- Bir listing'in `pinned` medyasını düşür — ayrı düğme yok: moderasyon listing'i
  silerken ref'leri de düşürüyor (migration 091), refcount 0'a inince obje gider.
- Sınırları koddan değil **config'den** okumak: 5 GB / 5 GB / 500 MB / 100 MB dosya
  ayarlanabilir olmalı, yoksa her kalibrasyon deploy gerektirir.

> [!note] Kullanıcıya gösterilmez
> Bu sayılar admin panelinde kalır. Son kullanıcı UI'ında kota göstergesi yoktur —
> "kotan var" mesajı vermek, kaldırdığımız modeli geri getirir.

## Göç (Counted tier'ın kaldırılması)

Bu yıkıcı bir değişiklik; sırası önemli:

1. ✅ Client yeni `counted` upload'u yapmıyor (`entity_image_upload`,
   `map_image_upload`, `pdf_library_service` → yerel-only; projeksiyon → transient).
2. ✅ Worker `{userId}/{sha}` prefix'i **read-only**: GET çalışır, PUT
   `410 counted_tier_retired` döner. Kullanıcılar mevcut bulut kopyalarını
   indirebilsin diye bir sürüm boyunca kalır.
3. ⬜ Bir sonraki sürümde prefix süpürülür; `check_asset_quota` ve
   `get_user_total_storage_used` RPC'leri düşürülür. (Kota UI'ı ve client
   tarafı bugün kaldırıldı; `USER_QUOTA_BYTES` Worker'dan silindi.)
4. ⬜ `community_assets` satırlarından counted olanlar temizlenir.

`world_pdf` (50 MB) buluttaki en büyük counted kalemdi — yeni modelde PDF
kütüphanesi tamamen yereldir ve LAN sync ile taşınır.

## Bilinen tavanlar

- **Talep-üzerine yükleme ilk görüntülemede gecikme demek.** Oyuncu kartı
  görür ama görsel bir tur sonra gelir (oyuncu bildirir → DM yükler → oyuncu
  indirir). Kabul edilen tavan; alternatifi DM'in her şeyi baştan yüklemesi.
- **DM oturum boyunca online olmalı** — upload'ı DM'in cihazı yapıyor. Zaten
  oyunu o yürütüyor, ama DM uygulamayı kapatırsa bekleyen `missing_shas`
  karşılanmaz. Liste kalıcı olduğu için DM döndüğünde tamamlanır.
- **Transient eviction canlı oturumu bozabilir.** `transient_touch` yalnızca
  indirmede tetiklenir; bir görseli herkes önbelleğe almışsa `last_used_at`
  tazelenmez ve obje atılabilir — sonra katılan oyuncu göremez. Kabul edilen
  tavan: oyuncu eksiği bildirir, DM tekrar yükler — talep-üzerine akış bu durumu
  zaten kendiliğinden onarır.
- **Presence Postgres'ten okunamaz — sunucu tarafı oturum zorlaması yok.** Bir
  RPC "oturum kapalıyken transient yazma" diye reddedemez; kapı yalnızca DM'in
  client'ında uygulanır. Kabul edilen tavan, çünkü transient'e yazan tek şey
  zaten DM'in kendi client'ı ve dosya başı 100 MB + havuz LRU emniyet kapağı
  duruyor; kapı bir güvenlik sınırı değil, israf önleyici. Gerekirse yükseltme
  yolu tek kolon: `world_members.last_seen_at` (60 sn'de bir dokunulur, oturum =
  "son 2 dk içinde görülmüş üye var") — düğme yine gelmez, ama RPC okuyabilir.
  Presence'ın yetmediği ölçülene kadar yapılmaz.
- **5 GB / 5 GB bölünmesi ve yayıncı başı 500 MB elle seçilmiş sayılardır.** Ölçüm çıkınca ayarlanır;
  `pinned` doluluğu admin panelinde görünmeli, yoksa yayın reddi sürpriz olur.
- Karakter yaratım kategorilerinin otomatik paylaşımı, dünyaya özgü çok sayıda
  kart varsa büyük bir ilk yükleme olabilir. Tavanı 512 KB / 4000 satır kuralı
  çiziyor, ama limit dolduğunda DM'e ne söyleneceği (hangi kartlar elendi?)
  tasarlanmadı.
- **512 KB / 4000 de elle seçilmiş sayılardır**, R2'nin 5 GB / 5 GB'ı gibi.
  Postgres'in R2'den farkı: dolduğunda LRU atmaz, **yazma tamamen patlar** ve
  bu yalnızca paylaşımı değil bütün uygulamayı etkiler. O yüzden bu iki sayı
  havuz sayılarından daha erken ölçülmeli.
- ~~Dünya silinince `entity_shares` satırlarının da gitmesi gerekir; cascade
  yoksa gerçek sızıntı burasıdır — kuralları koymadan önce doğrulanmalı.~~
  **Doğrulandı:** `entity_shares.world_id REFERENCES worlds(id) ON DELETE
  CASCADE` (026_online_worlds.sql:144) — sızıntı yok.

## Etkilenen yerler

- `flutter_app/lib/presentation/screens/admin/` — Storage sekmesi;
  `admin_users_remote_ds.dart` + `get_r2_pool_stats()` / kullanıcı satırlarına
  `pinned_bytes` & `transient_bytes`.
- `cloudflare/src/worker.ts` — prefix sınıfları, `pub/` rotası, counted PUT 410.
- `supabase/migrations/` — `pub_assets` + refcount RPC'leri, havuz bütçe
  parametreleri, kota RPC'lerinin düşürülmesi; `transient_per_user_cap_bytes()`
  yerine `transient_max_file_bytes()` (dosya başı), `transient_pool_cap_bytes()`
  → 5 GB, `transient_per_user_full` kontrolünün kaldırılması
  (`065_transient_shared_pool.sql` üzerine yeni bir migration).
- `supabase/migrations/` — paylaşım gövdesi sınırları: `payload_json` üzerinde
  512 KB `CHECK`, `max_shares_per_world()` (4000) + `entity_shares` BEFORE
  INSERT trigger (`078_share_payloads.sql` üzerine yeni bir migration).
- `supabase/migrations/` — talep-üzerine akış: `entity_shares.media_shas`,
  `world_members.missing_shas` (+ oyuncunun kendi satırını güncellemesi için
  RLS). Oturum kapısı presence'ta olduğu için migration gerektirmiyor.
- `flutter_app/lib/application/services/world_sync_service.dart` — mevcut
  `dmt:world:{id}` kanalında presence `track` / `onPresenceSync`; DM'e
  "kendim dışında üye var mı" bool'unu veren provider.
- `flutter_app/lib/application/services/entity_share_prepare.dart` — yaratım
  kategorilerinin otomatik kapanışı, medya sınıfı seçimi, oturum kapalıyken
  upload'ın atlanması (sha listesi yine de yazılır).
- `flutter_app/lib/application/services/world_mirror_applier.dart` — oyuncu
  tarafında eksik sha tespiti → `missing_shas` yazımı; DM tarafında bu listeyi
  görüp upload etme.
- `flutter_app/lib/data/network/asset_service.dart`, `entity_image_upload.dart`,
  `map_image_upload.dart`, `pdf_library_service.dart` — counted yolunun sökülmesi.
- `marketplace_cover_sync_service.dart` + paket yayın yolu — `pub/{sha}` dedup.

## Phase C nasıl uygulandı (2026-09-08)

Tasarımdan üç sapma var, üçü de bir şeyi **eksiltiyor**:

1. **`entity_shares.media_shas` yazılmadı.** Gövde zaten içerik-adresli ref
   taşıyor; ikinci kolon aynı gerçeğin ayrışabilen kopyası olurdu.
2. **`world_members` üzerinde self-UPDATE policy'si yok, RPC var.** Düz bir
   `USING (auth.uid() = user_id)` policy'si oyuncunun kendi `role`'ünü
   `'dm'` yapmasına izin verirdi — `WITH CHECK` OLD satırı göremiyor.
   `report_missing_shas` SECURITY DEFINER olarak yalnızca tek kolona dokunur,
   sha256 hex'i olmayanı eler, tekilleştirir, `max_missing_shas()` (500) ile
   kırpar.
3. **Paylaşım artık DM'in kendi kartını hiç yeniden yazmıyor.** Eski yol
   görselleri yükleyip entity'yi bulut ref'lerine göre kalıcı olarak
   güncelliyordu; yeni yolda remap **yalnızca payload'da** yapılır. Sebep
   `prepareEntityImagesForProjection`'daki ile aynı: transient obje LRU ile
   atılabilir, kalıcı satırda ölü ref bırakmak DM'in kendi resmini kaybetmesi
   demek. Yan etkisi olarak eager upload + `flushPrefix` + entity re-read
   adımları silindi.

### Akış

```
DM "Paylaş"                              entity_share_prepare.dart
  └─ _payloadWithTransientRefs
       ├─ localMediaPathsOf(entity)      shared_media_courier.dart
       ├─ courier.refFor(path)           sha256(stream) → dmt-transient://{sha}{ext}
       │                                 (sha → yerel yol BELLEKTE tutulur)
       └─ remapEntityMedia (kopya)  ─▶ entity_shares.payload_json
                                              │ CDC
                                              ▼
Oyuncu   WorldMirrorApplier._applyEntityShareEvent
           └─ MissingMediaReporter.schedule (2 sn debounce)
                ├─ collectTransientRefs(blob)      → sha listesi
                ├─ ContentStore.read / resolver.resolve
                └─ report_missing_shas RPC   ─▶ world_members.missing_shas
                                                     │ CDC
                                                     ▼
DM       WorldMirrorApplier._applyMembersEvent
           └─ presence açık mı?  ──hayır──▶ hiçbir şey yükleme
                    │ evet
                    └─ courier.serve → uploadTransientShare (yalnız istenenler)
```

### Oturum kapısı nerede

`WorldSyncService` mevcut `dmt:world:{id}` kanalına presence bağladı: kanal
`RealtimeChannelConfig(key: uid)` ile açılıyor, `SUBSCRIBED` sonrası
`track({'uid'})`, `onPresenceSync` → `isSessionOpen(worldId)` = "benden başka
anahtar var mı". Migration, kolon, düğme yok.

Kapı **tek bir yerde** okunuyor: `_applyMembersEvent`'te upload'dan hemen önce.
Yani DM tek başına hazırlık yaparken havuza hiçbir şey girmez, ama paylaşım
satırı yazılır ve oyuncunun `missing_shas` listesi kalıcı olduğu için oturum
açıldığında karşılanır.

### DM payload'ı kendine geri yazmıyor

`applyInitialState` ve `_applyEntityShareEvent`, rol DM ise gövde enjeksiyonunu
atlıyor. Eskiden zararsızdı (payload kalıcı bulut ref'leri taşıyordu ve DM'in
satırı da aynısını taşıyordu); artık payload transient ref taşıdığı için geri
yazmak DM'in **yerel dosya yollarını ezerdi**.

### Bilinen tavan — yeniden deneme timer'ı

Oyuncunun "baytlar geldi" diye dinleyebileceği bir satır yok:
`transient_shares` beş abone tablodan biri değil ve olmamalı. Bu yüzden
`MissingMediaReporter` eksik varken 15 sn'de bir süpürüyor, liste boşalınca
duruyor. Doğru yükseltme o tabloya abone olmak değil, DM'in yükleme sonrası
oyuncunun **zaten dinlediği** bir satıra dokunması.

İkinci tavan: `sha → yerel yol` eşlemesi yalnızca bellekte. Uygulama yeniden
başladıktan sonra gelen ilk talep, dünyanın tüm yerel medyasını bir kez
hash'liyor (`SharedMediaCourier._reindex`, `ponytail:` ile işaretli). Ölçülür
bir gecikme olursa sha paylaşım anında `asset_refs` yan tablosuna yazılır.

## Phase D nasıl uygulandı (2026-09-08)

Tasarımdan üç sapma var; üçü de bir şeyi **eksiltiyor** ya da tasarımın başka
bir yerindeki kuralı uyguluyor.

1. **Karakter ek resimleri `pinned` oldu, transient değil.** "Counted'ı neye
   çevirelim" sorusunun cevabı tasarımın kendi tablosunda yazıyordu: karakter
   medyası oturum ortasında LRU'ya yem olmamalı. `MediaBundler` artık
   portreyi free tier'a, ek resimleri `pub/{sha}{ext}`'e yüklüyor; refcount
   sahibi `char:{characterId}`, karakter silinince `AssetService.releasePub`
   ref'leri düşürüyor.
2. **PDF paylaşımı tamamen kaldırıldı** — "yeni modelde PDF kütüphanesi
   tamamen yereldir" kuralının sonucu. `share` / `shareAll` / `download` ve
   `world_settings.settings_json['pdf_library']` manifest'i gitti.
   **Kullanıcıya görünen davranış değişikliği:** online oyuncu artık DM'in
   PDF'ini uygulama içinden indiremiyor; PDF'ler cihazlar arasında LAN sync
   ile taşınıyor. Eski dünyalardaki manifest girdileri zararsız artık veri.
3. **Projeksiyon yolu transient'e taşındı, kalıcı yazma kalmadı.** Eski akış
   sayılan ref'i entity'ye kalıcı yazıyor, kota dolunca transient'e düşüyordu.
   Artık tek yol var: `SharedMediaCourier.publish(worldId, path)` yükler, ref
   **yalnızca projeksiyon anlık görüntüsünde** kullanılır. Gerekçe Phase C ile
   aynı — LRU atarsa kalıcı satırda ölü ref kalırdı. Giriş noktaları
   `prepareEntityImagesForProjection`, `projectableMapImage`,
   `WorldMapNotifier.ensureMapImageProjectable`.

### Silinenler

Sayılan katmanla birlikte okuyucusu kalmayanlar: `AssetService.uploadAsset` /
`listAssetsForUser` / `maxItemBytes` / `AssetQuotaExceededException`,
`image_upload_helper.dart`, `storage_usage_provider.dart`,
`media_manifest_restorer.dart`, `MediaBundler`'ın karakter dışı beş metodu,
kota + "dosya çok büyük" snackbar'ları ve altı l10n anahtarı. Ayrıca zaten ölü
olan iki dosya bu geçişte temizlendi: `fog_externalizer.dart` (fog projeksiyon
patch'inde base64 gidiyor) ve `raw_path_migrator.dart`.

Worker tarafında: `handleUpload` yalnızca `transient/{uid}/` ve `pub/` kabul
ediyor, gerisi `410 counted_tier_retired`; `checkAssetQuota` (`rls.ts`),
`USER_QUOTA_BYTES` (`wrangler.toml`) ve `ASSET_QUOTA_RESERVE_BYTES` kaldırıldı.
Hesap silme sweep'i `{userId}/` prefix'ini hâlâ süpürüyor — eski objeler orada.

### Bilinen tavan

`char:{id}` ref_key'i altında eski sha bırakılmıyor: kullanıcı karakter
resmini değiştirirse eskisi karakter silinene kadar refcount'ta kalır ve
yayıncı başına 500 MB pinned payından düşer. Ölçülür bir sızıntı olursa
bundle öncesi `releasePub(refKey)` çağrılır (`ponytail:` ile işaretli).

## Phase E — marketplace medyası zip olarak iner (karar: 2026-09-07)

**Karar:** marketplace indirmesi medyayı talep üzerine tek tek çekmeyi bırakır.
Yayın zaten bir **snapshot** — medyası da o an paketlenir, indiren kişi tek zip
ile **tüm içeriğe yerelde** sahip olur. Offline-first invariantı budur: indirme
bittiğinde dünya ağa bir daha ihtiyaç duymaz.

Yeni desen değil — **official paketlerde zaten bu yapılıyor.**
`first_party_catalog_provider._installOne` kurulumda
`art-bundle/{slug}@{version}.zip`'i `FirstPartyArtService.prefetchBundle` ile
toptan indiriyor, ilerlemeyi `done / total` olarak gösteriyor ve boyutu
`entry.downloadBytes` içinde sayıyor. Oradaki yorum bu kararın gerekçesini
birebir yazıyor: *"Lazy indirme paketi hafif gösterip kullanıcıyı her kartta
beklettiği için tercih edilmedi."* Community içeriği için aynı yol açılır.

### Yayın tarafı

`PublishMediaPinner` bugün her ref'i ayrı `pub/{sha}{ext}` objesi olarak
yüklüyor. Yerine (ya da yanına) tek bir **medya zip'i** üretilir:

1. Payload gezilir, medya ref'leri toplanır (gezgin aynı — `isMediaRef`).
2. Baytlar tek arşive yazılır, **girdi adı `{sha}{ext}`** — arşiv içi düzen
   content-addressed, çünkü çıkarma hedefi `ContentStore`.
3. Arşiv `pinned` sınıfına yüklenir: `pub/{zipSha}.zip`, `ref_key` = listing id.
   `pub_asset_reserve` / `pub_asset_release` yolu aynen geçerli.
4. Payload ref'leri yine `dmt-asset://pub/{sha}{ext}` olarak yazılır. Ref şeması
   **değişmez** — zip yalnızca baytların taşınma biçimidir.

### İndirme tarafı

`downloadAsNewCopy` payload'dan sonra zip'i indirir, girdileri SHA doğrulayarak
`ContentStore`'a yazar, sonra local item'ı kaydeder. Ref'lere dokunulmaz:
`AssetRefResolver` servis katmanına uğramadan önce zaten `_store.read(sha)`'ya
bakıyor, yani çıkarılmış baytlar çevrimdışı da çözülür. İlerleme ve iptal UI'ı
official kurulumdaki `done / total` kalıbını kullanır.

### Ne paketlenir, ne paketlenmez — **yalnızca homebrew**

Bu kural yayının en önemli kısmı; zip'i şişiren şey buradaki gevşekliktir.

| Medya kaynağı | Zip'e girer mi | Neden |
|---|---|---|
| Dünyaya/pakete özgü (homebrew) medya | **evet** | başka hiçbir yerden gelmiyor |
| Marketplace'den kurulmuş bir paketten gelen kart medyası | **hayır** | indiren o paketi zaten kurar; paketin kendi zip'i taşır |
| Official katalog paketinden gelen medya (`dmt-art://`) | **hayır** | R2 `catalog/` prefix'inde public, `art-bundle` ile iniyor |
| Zaten `pub/` olan ref | **hayır** | havuzda duruyor, tekrar paketlemek çift depolama |

Bu, belgede zaten iki kez geçen kuralın üçüncü uygulaması: "Marketplace'de zaten
olan bir paketin içeriği tekrar yüklenmez" (Marketplace bölümü) ve "kart bir
marketplace paketinden geliyorsa gövde de medya da yüklenmez" (madde 2). Yayın
öncesi bağımlılık listesi (`world_packages` / `links`) zaten hesaplanıyor —
paketten gelen entity'lerin ref'leri o listeden çıkarılır.

### Bilinen tavanlar

- **Dosya başı dedup ölür.** Zip tek sha'dır; iki yayıncının aynı görseli iki
  ayrı zip'te taşıması iki kopya demektir, ve bir görsel değişince yeni
  snapshot'ın **tüm zip'i** yeniden yüklenir. Yayıncı başı 500 MB payı artık
  snapshot başına tam zip boyutu sayar. Ölçüm gerektiren gerçek bir maliyet.
  - Yükseltme yolu: bireysel `pub/{sha}` objelerini korumak ve zip'i worker'da
    manifest'ten **anlık üretmek** — dedup korunur, indiren yine tek istek atar.
    Worker işi gerektirdiği için ilk sürümde yapılmaz.
- **İndirme anı ağırlaşır.** Bugün tek JSON, sonra yüzlerce MB. İlerleme,
  iptal ve kısmi başarı politikası şart. Yayın tarafındaki "tek ref pinlenemezse
  iptal" katılığının indirme tarafında karşılığı **yoktur**: zip inemezse dünya
  yine kurulur, medya lazy yola düşer (ref'ler zaten `pub/`).
- **`ContentStore` bir cache dizini** (`{base}/cache/content/`).
  `EvictionSweeper.sweepIfOverBudget` 1 GB üstünde LRU siliyor ve yorumu açık:
  *"Referenced dosyaları da siler — sonraki resolve re-fetch eder."* Çevrimdışı
  kullanıcıda re-fetch yok. Sweeper'ın bugün `lib/` içinde çağıranı yok, yani
  şimdilik zararsız; açılmadan önce ya indirilen listing medyası muaf tutulmalı
  ya da baytlar `LocalMediaLocalizer.worldDir` altına yazılmalı (PDF yolu
  `field_widget_factory._open` bunu zaten yapıyor).

### Etkilenen yerler

- `publish_media_pinner.dart` — ref gezgini korunur, çıktı tek arşiv;
  homebrew filtresi burada uygulanır.
- `asset_service.dart` — `uploadPub`'ın zip varyantı (`.zip` kind + boyut tavanı).
- `marketplace_listing_provider.dart` — `publishSnapshot` zip üretimi,
  `downloadAsNewCopy` zip indirme + `ContentStore`'a çıkarma.
- `first_party_art_service.dart` — `prefetchBundle` zaten zip→store yazıyor;
  community yolu bunu genelleştirir, ikinci bir çıkarıcı yazılmaz.
- `archive: ^4.0.9` zaten bağımlılıkta.
