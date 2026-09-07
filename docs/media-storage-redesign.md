# Medya Depolama Yeniden Tasarımı — "bulutta sadece paylaşılan şey durur"

Durum: **tasarım kararı, henüz uygulanmadı.**
Tarih: 2026-09-05
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

**Oturum = `worlds.session_started_at TIMESTAMPTZ NULL`.** Tek bir kolon; ayrı
tablo yok. `NULL` → oturum kapalı, `NOT NULL` → oturum açık. DM
`session_start(world_id)` / `session_end(world_id)` RPC'leri ile çevirir
(yalnızca `role = 'dm'`).

| | Oturum kapalı | Oturum açık |
|---|---|---|
| Kart paylaşma (`entity_shares` satırı + `payload_json`) | **evet** — yazılır, oyunculara gider | evet |
| Kart medyasının transient'e yüklenmesi | **hayır** | evet, talep üzerine |
| DM'in yerel değişiklikleri | yerelde, her zaman | yerelde, her zaman |
| Karakter medyası (`pinned`) | evet | evet |

Yani "paylaş" dediği şey kaybolmaz: satır durur, oyuncu kartın **gövdesini**
görür; eksik olan sadece görseldir ve oturum açılınca gelir. Oturum kapanınca
hiçbir şey silinmez — objeler LRU sırasına düşer ve zamanı gelince atılır.

#### Medya talebe göre yüklenir (DM push değil, oyuncu pull)

Oturum açıldığında DM'in bütün paylaşılmış medyasını topluca yüklemesi havuzun
en büyük israfı olurdu: oyuncuların çoğunda o dosyalar geçen oturumdan zaten
yerelde. Onun yerine eksik listesi **oyuncudan** gelir:

1. Paylaşım satırı medyayı **sha listesi** olarak taşır
   (`entity_shares.media_shas TEXT[]`) — bayt değil, sadece kimlik.
2. Oyuncu satırı uygular; yerelinde olmayan sha'ları kendi üyelik satırına yazar:
   `world_members.missing_shas TEXT[]`. **Yeni abone tablo gerekmez** —
   `world_members` zaten beş abone tablodan biri.
3. DM bu güncellemeyi görür, yalnızca listedeki sha'ları transient'e yükler,
   sonra sha'yı listeden düşürür.
4. Oyuncu indirir, yerele yazar. Aynı dosyayı bir daha hiç istemez.

Sonuç: havuza yalnızca **o an gerçekten birine eksik olan** bayt girer, ve
oturumun ikinci haftasında transient yükü neredeyse sıfırdır.

#### İstisna — karakter yaratımı ve seviye atlama oturum kapısına tabi değil

Oyuncu davetiyeyi aldığı an karakterini yaratabilmeli; DM'in oturum başlatmasını
beklememeli. Bu yüzden **karakter yaratım/ilerleme kategorilerindeki kartlar
(aşağıdaki madde 2) oturumdan bağımsız olarak, medyasıyla birlikte paylaşılır.**
Bunlar dünyanın en küçük medya kümesi (sınıf/ırk/feat ikonları) ve karakter
akışının çalışması için gerekli; kapının tuttuğu şey haritalar, handout'lar ve
NPC portreleridir. Aynı talep-üzerine akış burada da geçerlidir, sadece
`session_started_at` kontrolü atlanır.

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
  - Listing silinince `refcount -= 1`; 0 olunca obje silinir.
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
- Bir listing'in `pinned` medyasını düşür (moderasyon zaten listing siliyor;
  refcount 0'a inince obje gider, ayrı bir düğmeye gerek yok).
- Sınırları koddan değil **config'den** okumak: 5 GB / 5 GB / 500 MB / 100 MB dosya
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
  zaten kendiliğinden onarır. Havuz sıkışırsa bir adım daha var: **oturumu açık
  olan dünyaların** asset'lerini kurban seçiminden muaf tutmak
  (`session_started_at IS NULL` filtresi), ki oturum kapısı bunu ücretsiz
  mümkün kılıyor.
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
- Dünya silinince `entity_shares` satırlarının da gitmesi gerekir; cascade
  yoksa gerçek sızıntı burasıdır — kuralları koymadan önce doğrulanmalı.

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
- `supabase/migrations/` — oturum kapısı: `worlds.session_started_at`,
  `session_start()` / `session_end()` RPC'leri, `entity_shares.media_shas`,
  `world_members.missing_shas` (+ oyuncunun kendi satırını güncellemesi için RLS).
- `flutter_app/lib/application/services/entity_share_prepare.dart` — yaratım
  kategorilerinin otomatik kapanışı, medya sınıfı seçimi, oturum kapalıyken
  upload'ın atlanması (sha listesi yine de yazılır).
- `flutter_app/lib/application/services/world_mirror_applier.dart` — oyuncu
  tarafında eksik sha tespiti → `missing_shas` yazımı; DM tarafında bu listeyi
  görüp upload etme.
- `flutter_app/lib/data/network/asset_service.dart`, `entity_image_upload.dart`,
  `map_image_upload.dart`, `pdf_library_service.dart` — counted yolunun sökülmesi.
- `marketplace_cover_sync_service.dart` + paket yayın yolu — `pub/{sha}` dedup.
