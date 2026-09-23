# Online Senkronizasyon Yeniden Tasarımı — "tam online geri dönüyor, LAN kalkıyor"

Durum: **uygulama başladı** — dal `online-again`, Faz 0, Faz 1, Faz 2.5, Faz 3,
Faz 3.5, 4a, 4b, 5a, 5b ve 5c bitti (bkz. [BÖLÜM 4](#bölüm-4--roadmap)), Faz
5.5+ taslak. Migration 095–097 **deploy edildi** ve 5b'nin elle doğrulaması
**yapıldı** (2026-09-23). 5c'de dünya indirme ve indirilen dünyada canlı
düzenleme elle doğrulandı — ikincisi Faz 4a'dan kalan bir damga hatası
düzeltildikten sonra (§4.9); görseller gelmiyor, karar bekliyor. **098 deploy
ve paket adımları bekliyor**; liste
[§4.8.2](#482-faz-5c--ikinci-cihazın-ilk-senkronu--bitti) sonunda. Son faz
(9) işlem geri bildirimi.

> **Bu belge nasıl uygulanır — önce bunu oku.**
>
> Kodun ve uygulamanın bugünkü hali bu belgeyle **birebir eşleşmeyebilir.**
> Belge niyeti anlatır, kodun anlık halini değil; yazıldığı andan beri kod
> ilerledi ve ilerlemeye devam edecek.
>
> Bir fazı uygularken asıl iş, o fazın **ne yapmak istediğini** tam anlayıp
> onu gerçekleştirmektir — belgedeki dosya adını, satır numarasını, sayıyı ya
> da adım listesini harfi harfine izlemek değil. Bunlar niyeti anlatmak için
> var; bağlayıcı olan şey fazın **çıkış kriteri**.
>
> Belge ile kod çeliştiğinde **kod kazanır**, belge düzeltilir — bulunan her
> fark [§4.9](#49-kod-incelemesinden-çıkan-düzeltmeler) tablosuna yazılır.
> Fazın niyeti belirsizse ya da fark bir kararı değiştiriyorsa **kullanıcıya
> sor**, tahmin etme.

Bu belge `077_drop_cloud_sync.sql` ile kaldırılan tam bulut aynasının geri
getirilmesini, LAN sync'in tamamen çıkarılmasını ve zip import/export'un
eklenmesini tanımlar. Kararların hepsi verilmiş durumda; açık kalan noktalar
"Sonraya bırakılanlar" bölümünde ve Faz 8'de işaretli.

İlgili belgeler:
- [`media-storage-redesign.md`](media-storage-redesign.md) — medya tier'ları, Phase C/D/E
- [`audit-2026-09.md`](audit-2026-09.md) — §2 LAN güvenlik bulgusu, §5 KV write amplification
- [`../vault/20-Systems/Share-Broadcast-Flow.md`](../vault/20-Systems/Share-Broadcast-Flow.md) — mevcut paylaşım kanalı
- [`../vault/20-Systems/LAN-Sync-Flow.md`](../vault/20-Systems/LAN-Sync-Flow.md) — kaldırılacak sistem

---

## Bir cümlede

Yerel Drift kaynak-doğru kalmaya devam eder, ama **kullanıcı neyi online
yapmak isterse** onun tamamı satır bazlı olarak Supabase'e aynalanır; oyuncu
hiçbir şeyin bulut kopyasını tutmaz, yalnızca kendi karakterini ve mind
map'ini tutar, DM'in paylaştığı kartlara izinle erişir.

---

## Verilen kararlar

| Konu | Karar |
|---|---|
| LAN sync | kalkıyor |
| Tam online | dönüyor, **satır bazlı** (snapshot / zip yükleme yok) |
| Online kapsamı | seçici — kullanıcı ne isterse |
| Dünya içeriği | kartlar, harita, mind map, oturumlar, **savaş**, **pinler**, ayarlar, kurulu paketler |
| Çöp kutusu | yerel kalıyor |
| Paketler | dünyayla aynı mantıkta online olabiliyor |
| Oyuncu bulutta ne tutuyor | **yalnızca** karakteri + o dünyadaki mind map'i |
| Paylaşılan kartlar | **link** — oyuncuda bulut kopyası yok |
| Oyuncu paylaşılan kartı düzenleyebilir mi | hayır |
| Paylaşım geri çekilirse | özellik eksiğe düşer, oyuncu DM'e sorar |
| DM dünyayı silerse | export/import ile kullanıcıya bırakılıyor |
| DM hesabını silerse | yapacak bir şey yok |
| Multiplayer | hesap zorunlu, dünya online olmak zorunda |
| Çatışma | **son düzenleyen kazanır** (kilit yok) |
| Senkron yöntemi | revizyon sinyali + artımlı çekme (**CDC değil**) |
| Import / export | zip — dünya, paket, karakter |
| Kota | kişi başı tek sayı (500 MB) |

---

# BÖLÜM 1 — Ne istiyoruz

*Teknik terim olmadan: kullanıcı ne görecek, ne bekliyoruz.*

## 1.1 Temel fikir

Uygulama bugün tamamen yerel çalışıyor, bulut sadece oyunculara gösterilen
şeyler için kullanılıyor. İstediğimiz: kullanıcı neyi online yapmak isterse
onu online yapabilsin, gerisi yerelde kalsın.

Hesabın tamamı buluta çıkmıyor. Bir düğme var, basıyorsun, o şey bulutta
duruyor. Basmazsan hiçbir baytı çıkmıyor.

## 1.2 Ne online olabilir

| Şey | Online olabilir | Notu |
|---|---|---|
| Dünya | evet | tamamı bulutta |
| Paket | evet | dünyayla aynı mantık |
| Karakter | evet | multiplayer'da **zorunlu** |
| Çöp kutusu | hayır | hep yerel |

Her biri bağımsız. Dünyanı online yapıp paketlerini yerel bırakabilirsin.

## 1.3 DM: dünyayı online yapınca

Dünyanın **tamamı** bulutta bir kopya olarak duruyor:

- Bütün kartlar — NPC, mekân, büyü, eşya, ne varsa
- Haritalar ve harita üzerindeki işaretler
- Mind map
- Oturum notları
- Zaman çizelgesi işaretleri
- **Devam eden savaş** — kimin sırası, kaç canı kaldı, hangi etkiler aktif
- Dünya ayarları
- Dünyada kurulu paketlerin listesi

Bu kopya **sadece sahibine ait.** Oyuncu hiçbirini göremez.

**Beklenen davranış:**

> Laptop'ta hazırlık yapıyorsun. Kapatıyorsun. Tableti açıyorsun — dünya
> orada. Aynı savaş yarıda kaldığı yerde, aynı notlar, aynı harita
> işaretleri. Hiçbir şey yapmadın, kendiliğinden oldu.

Savaş durumunun taşınması özellikle önemli: masada oturum yarıda kaldı,
ertesi gün başka cihazdan devam ediyorsun, savaş hâlâ orada.

## 1.4 Oyuncu: ne bulutta, ne değil

Oyuncunun bulutta **iki** şeyi var:

| Ne | Neden |
|---|---|
| Karakteri | en değerli şeyi, kaybolmamalı |
| O dünyadaki mind map'i | kendi ürettiği içerik |

DM'in paylaştığı kartlar bulutta **kopyalanmıyor.** Oyuncunun tarafında
sadece "DM'in şu kartına erişimim var" kaydı duruyor; kartı okurken DM'in
nüshasından çekiyor.

Üç sonucu:

- **Multiplayer için hesap şart.** Karakter bulutta olduğu için hesapsız
  multiplayer yok.
- **DM kartı düzeltince oyuncu anında görüyor.** Bugün DM'in tekrar
  "paylaş" demesi gerekiyor; tek nüsha olunca düzeltme kendiliğinden
  yansıyor.
- **Oyuncu paylaşılan kartı düzenleyemez.** Kart DM'in malı.

## 1.5 Oyuncu da farklı cihazdan girebilir

> Oyuncu telefonundan katıldı, karakterini yarattı, oynadı. Sonra
> laptop'ını açtı, giriş yaptı. "Online dünyalarım" listesinde o dünya
> duruyor. Tıklıyor — DM'in paylaştığı kartlar, haritalar ve **kendi
> karakteri** bıraktığı haliyle iniyor.

Davet kodunu tekrar bulmak zorunda değil; zaten o dünyanın üyesi.

## 1.6 Multiplayer

Bir dünyayı multiplayer yapmak için **önce online yapmak gerekiyor.**
Online değilse davet kodu üretilemez.

Onun dışında oyun deneyimi aynı: DM canlı yayın yapıyor, kart paylaşıyor,
oyuncular karakterlerini yönetiyor. Karakter yaratmak için gereken kartlar
(ırk, sınıf, büyü listesi) dünyaya girerken otomatik iniyor.

## 1.7 Paylaşım geri çekilirse

DM bir kartın paylaşımını geri çekerse oyuncu o kartı bir daha çekemiyor.
Karakteri o karttan bir şey almışsa (özel bir background, bir trait) o
özellik **eksik** durumuna düşüyor.

Uygulama çökmüyor — karakter açılıyor, sadece o özellik görünmüyor ve bir
uyarı çıkıyor. Oyuncu isterse DM'e sorar. Bu bir hata değil, masadaki
normal bir konuşma.

## 1.8 DM dünyayı silerse

Aynı durum, daha geniş: oyuncunun karakterindeki o dünyaya ait özellikler
eksiğe düşüyor. Oyuncu isterse DM'den dünyanın bir kopyasını ister, DM
export dosyası verir, oyuncu import eder. **Bunu kullanıcıya bırakıyoruz.**

DM hesabını tamamen silerse yapacak bir şey yok.

## 1.9 Import / Export

Tamamen yeni özellik. Kullanıcı şunları **zip** olarak kaydedip geri
yükleyebilecek: dünya (görseller dahil), paket, karakter.

Ne işe yarıyor:

- Hesap açmadan yedek alma
- Arkadaşına dosya olarak verme
- Bilgisayar değiştirirken taşıma
- DM'in dünyasını oyuncuya vermesi (§1.8)
- Bulut kotası dolsa, hesabını silsen bile elinde içerik kalması

**İnternetten ve hesaptan tamamen bağımsız.** Online olmak istemeyen
kullanıcı da kullanabiliyor.

## 1.10 LAN sync kalkıyor

Yerini iki şey alıyor:

| Yeni yol | Artısı |
|---|---|
| Online | kendiliğinden, wifi şartı yok, hesap gerekiyor |
| Zip export | manuel ama hiçbir şeye bağımlı değil |

LAN'ın kendi sorunları vardı: aynı ağda olma zorunluluğu, QR okutarak
eşleşme, ve silmeleri taşımıyordu — bir cihazda sildiğin kart diğerinde
duruyorsa geri geliyordu.

## 1.11 Sınırlar

- Kişi başı **tek bir alan** — örn. 500 MB, içinde ne tutarsa tutsun
- Online dünya sayısı sınırlı — örn. 10
- Sınır dolunca "online yapma" düğmesi çalışmıyor

**En önemli kural:** kota dolduğunda **yerel çalışma asla durmuyor.**
Uygulamayı kullanmaya devam ediyorsun, sadece buluta yeni bir şey çıkmıyor.

---

# BÖLÜM 2 — Teknik

## 2.1 Mevcut durum

`077_drop_cloud_sync.sql` (2026-08-24) tam aynayı kaldırdı. Gerekçesi kendi
içinde yazılı:

> Oyuncunun cihazına DM'in paylaşmadığı içerik de iniyordu; gizlilik
> yalnızca istemci tarafındaki `visibleEntityProvider` filtresiydi.

Bugün bulutta duran sekiz tablo:

| Tablo | Ne için |
|---|---|
| `worlds` | dünya kimliği + meta |
| `world_members` | kim hangi dünyada, rolü |
| `world_invites` | 8 karakterli davet kodu (`uses_left = 99999`, pratikte sınırsız) |
| `world_projection` | DM'in canlı yayını — tek satır, 120/500 ms debounce |
| `entity_shares` | paylaşılan kartlar **+ gövdeleri** (`payload_json`, 078) |
| `world_characters` | oyuncu karakter sayfaları |
| `world_packages` | dünyaya paylaşılan paketler |
| `character_claim_pool` | karakter sahiplenme |

İstemci: `WorldSyncService` (kanal, 5 tablo), `WorldMirrorService` (push,
3 sn echo penceresi), `WorldMirrorApplier` (954 satır, 16 ms batch).
Kuyruk yok, retry yok. Tek çevrimdışı telafi: `pushOwnedCharacters(worldId)`.

## 2.2 Postgres — hedef tablo listesi

### Kalan sekiz

`worlds`, `world_members`, `world_invites`, `world_characters`,
`world_packages`, `world_projection`, `character_claim_pool`,
`entity_shares` (gövdesi çıkıyor — §2.5)

### 077'den geri gelen altı

| Bulut | Yerel karşılığı |
|---|---|
| `world_entities` | `world_entities_table.dart` |
| `world_settings` | `world_settings_table.dart` |
| `world_map_data` | `world_map_data_table.dart` |
| `world_sessions` | `world_sessions_table.dart` |
| `world_mind_map_nodes` | `world_mind_map_nodes_table.dart` |
| `world_mind_map_edges` | `world_mind_map_edges_table.dart` |

Altısının da yerelde birebir karşılığı duruyor, şema 026'dan kopyalanabilir.

### Hiç var olmamış altı

| Bulut | Yerel karşılığı |
|---|---|
| `world_encounters` | `encounters_table.dart` |
| `world_combatants` | `combatants_table.dart` |
| `world_combat_conditions` | `combat_conditions_table.dart` |
| `world_map_pins` | `map_pins_table.dart` |
| `world_timeline_pins` | `timeline_pins_table.dart` |
| `world_installed_packages` | `installed_packages_table.dart` |

> Eski "tam ayna" bunların hiçbirini içermiyordu. Yani "eskisi gibi" değil,
> eskisinden fazlası.

### Online paketler — üç tablo

077 `personal_packages` + `personal_package_entities`'i düşürmüştü. Yerelde
paket şeması ayrı durduğu için üçüncü tablo da gerekiyor:

```
user_packages             <- packages_table.dart
user_package_entities     <- package_entities_table.dart
user_package_schemas      <- package_schemas_table.dart
```

### Yeni altyapı — üç tablo

```
world_revisions        -- senkronun kalbi (§2.3)
world_tombstones       -- silme takibi (§2.4)
world_member_state     -- oyuncunun notları / kurulu paketleri / arayüzü
```

**Toplam: ~26 tablo.**

## 2.3 En kritik karar: CDC değil, artımlı çekme

### Yanlış yol — eski sistem böyleydi

26 tablonun hepsine Realtime CDC aboneliği. Üç sorunu var:

1. **Mesaj bütçesi.** Supabase free tier 2M realtime mesaj/ay. Yoğun
   hazırlıkta (debounce sonrası) saatte ~1000 yazma olur, her yazma x abone
   sayısı mesaj.
2. **Binding maliyeti.** Bir kanala 26 tablo bağlamak gerekir; her binding
   her değişiklikte değerlendirilir.
3. **`REPLICA IDENTITY FULL`** açık (migration 052). Bir kartta tek harf
   değişse replikasyon akışına satırın eski ve yeni halinin tamamı gider.
   Büyük entity satırlarında ciddi bir gizli vergi.

### Doğru yol

```
Realtime  ->  sadece uyandırma sinyali
              "dünya X revizyon 47'de"
              tek tablo, dünya başına nadiren

Çekme     ->  istemci tek RPC atar
              get_world_delta(world_id, since_revision)
              -> sadece o revizyondan sonra değişenler
```

| | CDC | Artımlı çekme |
|---|---|---|
| Realtime mesajı / saat | ~1000 | **~1** |
| Realtime binding | 26 | **1** |
| Egress | her satır akar | sadece değişenler |

### Gereken tablo

```sql
world_revisions
  world_id     TEXT PRIMARY KEY REFERENCES worlds(id) ON DELETE CASCADE,
  revision     BIGINT      NOT NULL,   -- her yazmada artar
  updated_at   TIMESTAMPTZ NOT NULL,
  updated_by   UUID                    -- echo bastırma
```

Her ayna tablosunda `revision` + `updated_at` kolonu olur; delta sorgusu
bunun üzerinden gider. 077'de düşürülen `tg_bump_parent_world` trigger'ı
geri gelir ve revizyonu artırır.

### Egress etkisi

| | İnen bayt |
|---|---|
| Yeni cihazda ilk açılış | ~10 MB, **tek sefer** |
| Sonraki açılışlar | delta, KB'ler |

Yerel Drift kaynak-doğru ve önbellek olarak çalışıyor, tekrar indirme yok.
İki cihazlı kullanıcı ~20 MB tek seferlik -> 5 GB / 20 MB ~ **250
kullanıcı.** Tam ayna modelini free tier'da yaşanabilir kılan karar budur;
CDC ile aynı model ~25 kullanıcıda egress duvarına çarpardı.

## 2.4 Tombstone — ilk migration'da

Silmeler yayılmazsa hayalet satır oluşur: bir cihazda sildiğin kart
diğerinde duruyorsa delta onu geri getirir. LAN sync'in kabul edilmiş
açığı buydu:

> **Bilinçli sınır:** tombstone yok, dolayısıyla silmeler yayılmaz. A'da
> silinmiş bir entity'yi B hâlâ tutuyorsa birleşimde geri gelir.

Online'da kabul edilemez. Ayrı bir `world_tombstones` tablosu tercih
edilir (ayna tabloları sade kalır, tombstone'lar tek yerden süpürülür —
örn. 90 gün). **Sonradan eklenmesi çok acı**, ilk migration'da olmalı.

## 2.5 İzin sistemi — paylaşımın yeni hali

`entity_shares` gövdesini bırakıyor, saf izin tablosuna dönüşüyor:

```sql
entity_shares
  world_id     TEXT,
  entity_id    TEXT,
  shared_at    TIMESTAMPTZ,
  shared_by    UUID,
  -- payload_json  <- KALKIYOR (078 geri alınıyor)
  PRIMARY KEY (world_id, entity_id)
```

Anlamı: "bu dünyanın üyeleri bu kartı okuyabilir." Başka hiçbir şey.

### Okuma yolu — tek kapı

Oyuncu `world_entities`'e **asla doğrudan erişmiyor**:

```
get_shared_entities(world_id, since_revision)
       |
world_entities  JOIN  entity_shares     -- sadece izinli satırlar
       |
redaksiyon uygula                       -- §2.6
       |
oyuncuya dön
```

| Rol | `world_entities` | `entity_shares` | RPC |
|---|---|---|---|
| DM | tam okuma/yazma | tam | — |
| Oyuncu | **erişim yok** | okuma | evet |

Tek fonksiyon = tek denetim noktası. `is_world_member` / `is_world_dm`
helper'ları 026'dan beri var.

### Paylaşımı geri çekme

İzin satırını silmek yeterli. Oyuncunun yerel önbelleğindeki kopya
**silinmiyor** — gri görünür, "DM bu kartı artık paylaşmıyor" etiketi
taşır, yenilenmez. Karakter o karta bağlıysa özellik eksiğe düşer,
`CharacterResolver` uyarı üretir.

### Kazanç

| Kalkan | Neden |
|---|---|
| `entity_shares.payload_json` | tek nüsha |
| 512 KB payload sınırı (088) | payload yok |
| 4000 satır sınırı (088) | izin satırı küçük |
| Gövde enjeksiyon kodu (applier) | RPC'den çekiliyor |
| DM'in düzeltince tekrar push'laması | tek nüsha |

## 2.6 Redaksiyon — en riskli kısım

### Bugün hatasız

`redactDmOnly` (`entity_share_prepare.dart:272`) paylaşım anında,
göndermeden önce çalışıyor: `dm_notes` boşaltılıyor, `attributes`'tan
`dmOnlyFieldKeys` siliniyor. Sır **oyuncunun okuyabildiği satıra hiç
girmiyor** — yanlış yapmak imkansız.

### Link modelinde sır satırın içinde

Redaksiyon okuma anına kayıyor. Tek hatalı politika DM'in gizli notlarını
açar. **Dönüşümün en büyük gerçek riski budur.**

### Çözüm: kararı Dart'ta bırak, uygulamayı SQL'e ver

İş basit — `dm_notes`'u boşalt, `attributes`'tan anahtar listesi çıkar.
SQL'de tek ifade:

```sql
(fields - 'dm_notes') ||
jsonb_build_object('attributes', fields->'attributes' - dm_only_keys)
```

Zor kısım `dm_only_keys` listesi; o şemadan geliyor ve şema yorumlayıcısı
Dart'ta. **Onu SQL'de hesaplamaya çalışmayalım.** Yerine DM'in istemcisi
push ederken listeyi de yazar:

```sql
world_entities
  ...
  dm_only_keys  TEXT[]    -- DM'in istemcisi yazar, şemadan türetir
```

| Parça | Nerede | Neden |
|---|---|---|
| **Karar** — neyin sır olduğu | Dart | şemayı bilen, test edilmiş kod |
| **Uygulama** — anahtarı sil | SQL | mekanik, hata yapması zor |

PL/pgSQL'e ikinci bir şema yorumlayıcısı yazmıyoruz; iki yorumlayıcının
zamanla ayrışması tam olarak sır sızdıran senaryodur.

**Emniyet kuralı:** `dm_only_keys` NULL ise "sır yok" değil
**"bilinmiyor"** say ve kartı hiç döndürme.

## 2.7 Medya ref'leri taşınabilir olmalı

### Sorun

DM'in ayna satırları DM'in kendi diskindeki yolları taşıyor. Bugün sorun
değil, çünkü paylaşım anında `_payloadWithTransientRefs` yolları
`dmt-transient://{sha}{ext}`'e çeviriyor — taşınabilir ref **sadece
kopyada** var.

Link modelinde kopya yok. Oyuncu DM'in satırını okuyor ve
`/home/dm/Resimler/ejder.png` buluyor; onun makinesinde anlamsız.

Ve vault bunu bilinçli bir karar olarak yazıyor:

> Dönen transient ref kalıcı satıra yazılmaz — LRU atarsa DM kendi resmini
> kaybederdi.

### Çözüm: ref'i tier'dan ayır

```
dmt-content://{sha}{ext}    <- "şu bayt yığını, her neredeyse"
```

| Kim | Nasıl çözüyor |
|---|---|
| DM | `content_paths` tablosundan sha -> yerel dosya |
| Oyuncu | transient'ten indir; bulamazsa `missing_shas`'e yaz |

Vault'taki endişe de çözülüyor: ref tier belirtmediği için transient
LRU'su DM'i etkilemiyor — DM'in çözüm yolu yerel.

**Bitti** (Faz 3.5, bkz. [§4.5](#45-faz-35--medya-ref-birleştirmesi--bitti)).
Sha <-> yol eşlemesi `asset_refs`'te **yok** — o graf ham yolları kasten
indekslemiyor; iş için `content_paths` yan tablosu açıldı.

### Bağlantılı tavan

Medya talep-üzerine akıyor (Phase C, 092) ve DM çevrimiçi olmadan
yüklenmiyor. Yeni cihazda oyuncunun önbelleği boş:

> Oyuncu laptop'tan dünyayı indirdi. Kartlar var, yazılar var, görseller
> yok. DM o an çevrimiçi değil.

`missing_shas` kalıcı olduğu için DM dönünce düzeliyor. Çoklu cihaz bu
tavana daha sık çarpıyor. Medyanın önden yüklenmesi bir seçenek ama
transient havuzunu (5 GB) büyütür — **ölçümden sonra karar** (Faz 8).

## 2.8 Çatışma — son düzenleyen kazanır

Kilit **tercih edilmedi.** Gerekçe: kilit fikri LAN sync'in problemine
karşı doğmuştu — orada dünya tek bir payload olarak gidiyordu, bir cihazda
savaş notu bir cihazda mind map düzenlendiğinde biri tamamen eziliyordu
(`world_merge.dart` tam bu yüzden yazıldı).

Satır bazlı senkronda bu problem yok: farklı kartları düzenlediysen farklı
satırlar, ikisi de yaşıyor. Çakışma ancak **aynı satırı** iki cihazda
düzenlersen oluşuyor, o da nadir. LWW bu modelde doğal olarak güvenli.

### Tek kural: zamanı doğru yerden al

Karşılaştırma **düzenlemenin kendi zamanı** ile yapılmalı, sunucuya varış
zamanı ile değil.

```
Telefon çevrimdışı, 14:00'te karakteri düzenledi
Laptop 15:00'te aynı karakteri düzenledi
Telefon 16:00'da ağa girdi, kuyruğunu gönderdi
```

- Varış zamanına bakarsan -> telefon kazanır, **laptop'un yeni hali silinir**
- Düzenleme zamanına bakarsan -> laptop kazanır, doğru

Yani `updated_at` istemcide düzenleme anında yazılır ve sunucuda `now()`
ile **ezilmez**. Tek satırlık bir kural ama kaçırılırsa çevrimdışı kuyruk
her seferinde yeni veriyi eziyor.

Aynısı silme için de geçerli: tombstone'un zamanı ile düzenlemenin zamanı
karşılaştırılır, yoksa çevrimdışı cihaz silinmiş bir kartı geri diriltir.

### Kabul edilen kayıp

> Aynı kartı / karakteri iki cihazda düzenledin, biri çevrimdışıydı. Eski
> olan kaybolur, uyarı da çıkmaz.

Dar bir senaryo, kilidin getireceği sürtünmeye değmez.

### `world_merge.dart` ne olacak

Senkron için gerekmiyor — satır bazlı LWW kendi başına yeterli. Ama **zip
import için gerekiyor**: mevcut bir dünyanın üstüne zip import edince
"hangi bölüm hangi taraftan" sorusu aynen orada ve payload tek parça.
Dosya kalıyor, ev değiştiriyor: `lan_sync/` -> import servisi.
`world_section_stamps.dart` de aynı şekilde kalıyor.

## 2.9 Oyuncu tarafı şeması

### Mind map — aynı tablolar, `owner_id` kolonu

```sql
world_mind_map_nodes
  ...
  owner_id  UUID    -- NULL = DM'in, dolu = o oyuncunun
```

RLS: `(owner_id IS NULL AND is_world_dm(...)) OR owner_id = auth.uid()`

Tek şema, tek applier, tek migration. DM'in ve oyuncunun mind map'i aynı
mekanizmayı paylaşıyor, sadece sahibi farklı.

### Oyuncunun geri kalan durumu

```sql
world_member_state
  world_id    TEXT,
  user_id     UUID,
  state_json  JSONB,       -- notlar, kurulu paketler, arayüz durumu
  revision    BIGINT,
  updated_at  TIMESTAMPTZ,
  PRIMARY KEY (world_id, user_id)
```

RLS tek satır: `user_id = auth.uid()`. DM bile göremez. LAN sync bunları
`extras` içinde taşıyordu (`installed_packages`, `ui_view`) — karşılığı bu.

### Yeni cihazda geri katılma

`joinWithCode` ikiye ayrılıyor:

```
redeemInvite(code)            -> üyelik, sadece ilk katılışta
materializeWorld(worldId)     -> yerel kabuk + içerik çekme, her yeni cihazda
```

İkincisi zaten `joinWithCode` içinde gömülü, ayırmak yeterli. Üstüne
"Online dünyalarım" ekranı + "bu cihaza indir".

`online_worlds_provider.dart` bir id set'i veriyor ama amacı farklı — push
kararı için içsel kontrol, kullanıcıya gösterilen liste değil.

### Karakteri bulma

`claim_character` RPC'si `available` kontrolü yapıyor, ikinci cihaz tekrar
sahiplenemiyor — doğru davranış. Ama "benim bu dünyadaki karakterim
hangisi" sorgusu akışa konmalı, yoksa oyuncu yeni karakter yaratmaya
kalkar. `world_characters.owner_id` var, sorgu basit.

## 2.10 Dünya kimliği — isimden id'ye

`world_join_service.dart` yerelde isim çakışması olunca `Ad (2)`,
`Ad (3)`... sonra `ad-{worldId[0:8]}` yapıyor. Gerekçesi makul:

> repository.save keys by worldName, so if the player already has a
> different campaign with the same name we must pick a unique local label

Çoklu cihazda sonucu:

```
Telefon:  "Fırtına Vadisi"
Laptop:   "Fırtına Vadisi (2)"     <- aynı dünya, farklı isim
```

`CampaignRepository.save(worldName, payload)` **isimle** anahtarlıyor.
Senkronu isim üzerinden kurarsak iki cihaz asla buluşmaz. Dünya kimliği
`id` olmalı, `worldName` salt etiket. Şema bump'ı bedavayken (§3.1)
yapılmalı.

## 2.11 İstemci tarafı

### Geri gelmesi gerekenler

- **Çevrimdışı kuyruk.** `sync_outbox` tablosu geri gelmeli.
  `app_database.dart` içindeki `_retiredTablesDDL` onu aktif olarak
  düşürüyor — o satır kalkar.
- **Uzlaştırıcı.** Açılışta "bulutta revizyon 47, bende 43 -> delta çek,
  kuyruktakileri gönder." Eski adı `WorldReconciler`.
- **Applier genişlemesi.** `world_mirror_applier.dart` 954 satır / 5 tablo
  -> 26 tablo. **Baştan tablo başına ayrı handler olarak yazılmalı**, tek
  dosya kalırsa bakımı imkansızlaşır.

### Kalacaklar

| Ne | Neden |
|---|---|
| `PendingWriteBuffer` (750–2000 ms) | push'un girişi; debounce bulut için de çalışıyor |
| `WorldRepositoryImpl.save()` granular yazma | delta hesabı için şart |
| `world_merge.dart` + stamps | zip import'ta kullanılıyor (§2.8) |
| `world_projection` (120/500 ms) | canlı yayın, dokunulmuyor |
| `entity_shares` akışı | izin tablosuna dönüşüyor, akış korunuyor |

## 2.12 Silinecekler — LAN

| Ne | Boyut |
|---|---|
| `lan_sync/` — 6 dosya | **2.733 satır** |
| `lan_sync_provider.dart`, `lan_sync_dialog.dart` | eşleşme + QR UI |
| `lan_paired_devices` tablosu | `app_database.dart` DDL |
| l10n anahtarları | **68 anahtar x 4 dil = 272 satır** |
| Testler | 3 dosya |

Temizlik gerekenler (LAN'dan bahsedip kendileri kalacak, 9 dosya):
`startup_sync_gate.dart`, `save_sync_indicator.dart`,
`profile_menu_button.dart`, `local_media_localizer.dart`,
`asset_importer.dart`, `pdf_library_service.dart`, `map_image_upload.dart`,
`entity_image_upload.dart`, `character_repository.dart`

**Bedava güvenlik kazancı:** `audit-2026-09.md` §2'deki kırmızı bulgu —
LAN sunucusu kimlik doğrulamadan önce sınırsız gövde okuyor — bu silmeyle
kapanıyor.

**Kaybedilen tek şey:** hesapsız + internetsiz cihaz taşıma. Zip export
kapatıyor.

## 2.13 Cloudflare / R2

Medya altyapısı hazır, **neredeyse hiçbir şey değişmiyor:**

| Tier | Yer | Bütçe |
|---|---|---|
| Free | Supabase Storage `free-media` | <=2 MB/dosya, kalıcı |
| Transient | R2 `transient/{uid}/{sha}.{ext}` | 5 GB, LRU |
| Pinned | R2 `pub/{sha}.{ext}` | 5 GB, refcount (089) |
| First-party | R2 `catalog/art/` | salt-okunur |

Ayna **medya taşımıyor** — satırda ref, bayt ayrı yolda.

### Üç iş

1. **KV rate limiter — opsiyonel değil.** `cloudflare/src/rate_limit.ts`
   her izinli istekte `kv.put` çağırıyor; KV free tier günde **1000
   yazma.** Audit §5: "Bir pack kurulumu = asset başına 1 KV write. Tek IP
   tek saatte 600 write." Çözüm: `[[ratelimits]]` binding'i (katalog GET'i
   için `wrangler.toml`'da zaten kullanılıyor, unmetered) ya da Durable
   Object — ikincisi read-then-write yarışını da kapatıyor.
2. ~~**`dmt-content://` ref birleştirmesi**~~ (§2.7) — **bitti, worker'a
   dokunmadan** (§4.5). Sha çözümü zaten `transient_shares` + mevcut
   transient indirme route'u üzerinden yürüyor; yeni bir worker yolu
   gerekmedi.
3. **Transient eviction riski artıyor.** Daha fazla online dünya = daha
   hızlı dolan havuz. `transient_touch` sadece indirmede tetikleniyor,
   herkesin önbelleğindeki görsel atılabiliyor. Admin panelinde doluluk
   görünürlüğü şart.

**Zip export buluta çıkmıyor** — yerel dosya, R2'de yeni prefix gerekmiyor.

## 2.14 Free tier bütçesi

| Kaynak | Sınır | Durum |
|---|---|---|
| Postgres | **500 MB** | en dar yer — ayna satırları burada |
| Supabase egress | **5 GB/ay** | artımlı çekmeyle ~250 kullanıcı |
| Realtime mesaj | **2M/ay** | sinyal modeliyle sorun değil |
| Realtime eşzamanlı | 200 bağlantı | rahat |
| R2 depolama | **10 GB** | medya, değişmiyor |
| R2 indirme | ücretsiz | — |
| R2 Class A | 1M/ay | rahat |
| Workers istek | 100k/gün | izlenmeli |
| **KV yazma** | **1000/gün** | **şu an bile sınırda** |

> Free tier sayıları değişebiliyor, ara ara kontrol edilmeli.

### Kota önerisi

| Sınır | Değer | Neden |
|---|---|---|
| Kişi başı bulut alanı | **500 MB** | tek sayı, anlatılabilir |
| Online dünya / kişi | 10 | psikolojik fren |
| Dünya başına satır | 20.000 | 088'in mantığı |
| Entity satırı | 256 KB | `entity_shares`'in yarısı |
| Online paket / kişi | 20 | eski `max_online_packages_per_user` |

### Kritik uyarı

R2 dolunca LRU atıyor. **Postgres dolunca tüm uygulama yazmayı
bırakıyor.** `media-storage-redesign.md` bunu "havuz sayılarından daha
erken ölçülmeli" diye işaretlemiş. O yüzden:

- Kota aşımı **asla yerel yazmayı durdurmuyor**
- Sadece "online yapma" ve push reddediliyor
- Kullanıcıya hangi dünyanın ne kadar yer tuttuğu gösteriliyor

Phase D'de kota kavramı tamamen silinmişti (`storage_usage_provider`,
uyarılar, `check_asset_quota`) — geri gelmesi lazım, bu sefer Postgres
için de.

## 2.15 DM ve oyuncu — yan yana

| | DM | Oyuncu |
|---|---|---|
| Kopyanın niteliği | **asıl nüsha** | türetilmiş |
| Bulut tabloları | ~26 ayna | karakter + mind map + durum |
| Kart gövdeleri | 1 kopya | **0** (link) |
| Postgres yükü | yüksek | ihmal edilebilir |
| Kuyruk + delta | şart | karakter için yeter |
| Ana risk | RLS gizlilik hatası | medya önbelleği boş gelmesi |

**Oyuncu çoklu cihazı DM çoklu cihazından çok daha ucuz** — çünkü
oyuncunun kopyası türetilmiş. Daha az iş, daha çok kullanıcıya dokunuyor.

---

# BÖLÜM 3 — Bu modele nasıl geçeriz

## 3.1 En büyük avantaj: kullanıcı yok

### Drift şema bump'ı şu an bedava

`schemaVersion` 12 ve "fresh cut" — bump edilirse her kullanıcının DB'si
`.legacy` olarak yeniden adlandırılıp boş başlıyor. `CLAUDE.md` tam bu
yüzden yasaklıyor:

> **The version deliberately stayed at 12**: bumping it would rename every
> existing user's DB and start them empty.

Kullanıcı olmadığı için şu an serbest. **Bu pencere kapanmadan
yapılmalı.** v13'te bir kerede:

- `isOnline` kolonları (dünya, paket, karakter)
- `sync_outbox` tablosu
- `revision` / `updated_at` kolonları
- Dünya kimliğinin id'ye taşınması (§2.10)
- `lan_paired_devices` silinmesi

Sonradan yapmak her kullanıcıyı sıfırlamak demek olurdu.

### Diğer kolaylıklar

- **Supabase'de veri taşıma yok** — 077'nin düşürdüğü tablolar boş geliyor
- **Geriye uyumluluk yok** — eski sürümle konuşan istemci yok
- **Yanlış kararı geri almak ucuz** — kimsenin verisi yok

## 3.2 Sıralamanın üç kuralı

**Kural 1 — ZIP codec'i LAN'dan önce çıkar.** Paketleme kodu şu an
`lan_sync/` içinde yaşıyor:

| Ne | Nerede |
|---|---|
| Payload codec | `campaignRepository.load()/save()` |
| Medya toplama | `lan_sync_session._mediaFor`, `_collectContentBlobs` |
| Yol yazma | `rewriteRoots` |
| Çatışma çözümü | `world_merge.dart` |

LAN'ı önce silersen bu kodu yeniden yazarsın.

**Kural 2 — Dünya kimliği senkrondan önce düzelsin.** Push/pull'u isimle
anahtarlanan repository üstüne kurarsan iki cihaz buluşmaz (§2.10).

**Kural 3 — Medya ref'i push'tan önce birleşsin.** Push başlayınca
satırlara yol yazılıyor; yanlış biçimde yazılmış satırları sonra
düzeltmek göç işi olur.

## 3.3 Bozulmaması gerekenler

| Ne | Neden |
|---|---|
| Multiplayer paylaşım akışı | çalışıyor, yalnızca gövde -> link dönüşümü |
| Projeksiyon (120/500 ms) | çalışıyor, dokunulmuyor |
| Medya tier'ları | çalışıyor, dokunulmuyor |
| Marketplace | ilgisiz |
| **Yerel çalışma** | online kapalıyken hiçbir şey değişmemeli |

Son satır test edilebilir bir invariant: `SUPABASE_URL` define'ı
verilmeden alınan build bugün olduğu gibi tam çalışmalı.

## 3.4 Risk tablosu

| Risk | Şiddet | Önlem |
|---|---|---|
| RLS hatası gizli içeriği açar | yüksek | tek RPC kapısı + `dm_only_keys` + rol bazlı RLS testleri |
| Medya ref'i taşınamaz, resimler gelmez | yüksek | `dmt-content://` birleştirmesi push'tan önce |
| Applier 2500 satıra çıkar, bakımsız kalır | orta | baştan tablo başına handler |
| Silmeler yayılmaz, hayalet satırlar | orta | tombstone ilk migration'da |
| Çevrimdışı kuyruk yeni veriyi ezer | orta | düzenleme zamanı kuralı (§2.8) |
| KV limiti online açılınca patlar | orta | LAN silinmeden önce düzelt |
| Kota dolunca uygulama kilitlenir | orta | kota sadece push'u reddeder |
| İsim anahtarlı repository cihazları ayırır | orta | Faz 2.5 |

### En büyük riskin altını çizelim

Bugün gizlilik `redactDmOnly` ile sağlanıyor ve **yanlış yapmak
imkansız** — sır hiç gönderilmiyor. Yeni modelde sır sunucuya çıkıyor ve
tek bir yanlış politika onu oyuncuya açar.

**RLS testleri opsiyonel değil.** Her ayna tablosu için "oyuncu rolüyle
okumaya çalış, boş dönmeli" testi gerekiyor.

---

# BÖLÜM 4 — Roadmap

Çalışma dalı: **`online-again`** (`main`'den, 2026-09-21).

## 4.0 Genel görünüm

Her fazın bir **çıkış kriteri** var — o sağlanmadan sonraki faza geçilmiyor.
Kriterler çalıştırılabilir olacak şekilde yazıldı; "bitti" demek için
tıklanacak bir şey ya da yeşil olacak bir test var.

| Faz | Ne | Çıkış kriteri | Bulut | Durum |
|---|---|---|---|---|
| ~~**0**~~ | KV rate limiter'ı platform binding'ine taşı | istek yolunda `kv.put` yok | worker | ✅ bitti (2026-09-21 deploy edildi) |
| ~~**1**~~ | ZIP import/export + codec'in LAN'dan çıkarılması | dünya export → temiz kurulumda import → aynı dünya | hayır | ✅ bitti |
| ~~**2.5**~~ | Dünya kimliğinin isimden id'ye taşınması | `CampaignRepository` ismi anahtar olarak kullanmıyor | hayır | ✅ bitti |
| ~~**3**~~ | Bulut şeması + RLS | RLS testleri yeşil, istemci hâlâ kullanmıyor | evet | ✅ bitti (2026-09-22 deploy edildi) |
| ~~**3.5**~~ | `dmt-content://` medya ref birleştirmesi | ref cihazdan bağımsız çözülüyor | evet | ✅ bitti |
| ~~**4a**~~ | Drift v13 bump + dünya push'u | dünya bulutta görünüyor, geri okuma yok | evet | ✅ bitti (elle doğrulama bekliyor) |
| ~~**4b**~~ | Paket + karakter online anahtarı | paket/karakter de buluta çıkıyor | evet | ✅ bitti (095 deploy edildi; elle doğrulama bekliyor) |
| ~~**5a**~~ | Dünya pull'u + echo guard + uzlaştırıcı | bulutta değişen satır yerele iniyor, döngü yok | evet | ✅ bitti (096 deploy edildi; elle doğrulama bekliyor) |
| ~~**5b**~~ | Realtime sinyali + uzlaştırma anı + sunucu tarafı LWW | iki cihaz aynı dünyada **canlı** buluşuyor | evet | ✅ bitti (097 deploy edildi, elle doğrulandı) |
| ~~**5c**~~ | Paket pull'u + "bu cihaza indir" + ilk senkron ilerlemesi | ikinci cihaz dünyayı/paketi zip'siz alıyor | evet | ✅ bitti (dünya adımları elle doğrulandı; 098 + paket adımları bekliyor) |
| 5.5 | Oyuncu çoklu cihaz | oyuncu ikinci cihazdan karakterine ulaşıyor | evet | taslak |
| 6 | LAN'ı sil | `lan_sync/` yok, analyze temiz | hayır | taslak |
| 7 | Kural, kota, ölçüm | gerçek sayılar ölçüldü | evet | taslak |
| 8 | Sonraya bırakılanlar | — | — | açık |
| 9 | İşlem geri bildirimi (en son) | ağa çıkan her iş görünür; hata log'a değil kullanıcıya düşüyor | hayır | analiz edildi (§4.8.3) |

### Faz 2 nereye gitti

Eski Faz 2 ("online yapma iskeleti — hâlâ tamamen yerel") **kaldırıldı**, işleri
Faz 4'e katıldı. İki gerekçe:

1. **Dünya için zaten var.** `save_sync_indicator.dart:437` `_makeOnline` →
   `publishWorld` RPC, satır 566 `unpublishWorld`. Akış çalışıyor. Yeniden
   yazılacak bir şey yok, sadece paket/karakter için genelleştirilecek.
2. **Geri kalanı boş kabuk olurdu.** Paket ve karakter anahtarı bastığında
   arkasında yazacağı tablo Faz 3'ten önce yok; kota göstergesi Faz 4'ten önce
   sıfır gösterir. Düğmenin arkasındaki şey çalıştığında düğme de gelsin.

### Drift v13 bump neden Faz 0'dan Faz 4'e taşındı

Eski plan bump'ı Faz 0'a koyuyordu, gerekçe "kullanıcı yokken yapılmalı,
pencere geçici". Pencere gerçekten geçici ama **ilk sürümde** kapanıyor, faz
sınırında değil. Bump'ın taşıyacağı beş şeye tek tek bakınca hepsi Faz 4 ya da
sonrasında doğuyor:

| v13 kalemi | Gerçekte ne zaman gerekiyor |
|---|---|
| `isOnline` kolonları | Faz 4 — çevrimdışıyken push kararı verilirken |
| `sync_outbox` | Faz 4 |
| `revision` / `updated_at` | Faz 4 |
| Dünya kimliğinin id'ye taşınması | Faz 2.5 — **kolon gerektirmiyor**, `id` zaten PK |
| `lan_paired_devices` düşürülmesi | Faz 6 |

Faz 0'da bump etmek, Faz 3–4'te hangi kolonların gerekeceğini tahmin etmek
demek. Tahmin tutmazsa ikinci bir bump geliyor ve bump'ın tek bir kez olması
tam da amaçtı. Faz 4'ün başında, kolonlar bilindiğinde, **tek seferde**.

### Sıralamanın üç kuralı (§3.2) bu planda nasıl karşılanıyor

| Kural | Nerede |
|---|---|
| ZIP codec'i LAN'dan önce çıksın | Faz 1 ↔ Faz 6 |
| Dünya kimliği senkrondan önce düzelsin | Faz 2.5 ↔ Faz 4 |
| Medya ref'i push'tan önce birleşsin | Faz 3.5 ↔ Faz 4 |

---

## 4.1 Faz 0 — KV rate limiter ✅ bitti

*Tek iş. Worker tarafı, istemciye dokunmuyor, geri alması kolay.*

**Durum:** uygulandı ve **2026-09-21'de deploy edildi**. `rate_limit.ts`
silindi, üç limiter de platform binding'i (`CATALOG_RL` / `DL_RL` / `UL_RL`).
`npm run typecheck` ve `wrangler deploy --dry-run` temiz.

Limitler dakikalık ve **per-colo**: `DL_RL` 600/60s, `UL_RL` 20/60s,
`CATALOG_RL` değişmedi. Yükleme tavanı dar görünüyorsa tek dokunuş
`wrangler.toml` + yeniden deploy.

### Bugünkü durum

`cloudflare/src/rate_limit.ts` saatlik bucket sayacını KV'de tutuyor ve
**her izinli istekte `kv.put` çağırıyor.** KV free tier günde 1000 yazma.
Dosyanın kendi başlığı sorunu zaten yazmış; kota dolunca `catch` fail-open
geçiyor, yani limiter sessizce kapanıyor.

`wrangler.toml:39` platform limiter binding'i zaten kullanılıyor:

```toml
[[ratelimits]]
name = "CATALOG_RL"
namespace_id = "1001"
simple = { limit = 300, period = 60 }
```

Yani çözüm mevcut ve projede kanıtlanmış. Yeni bağımlılık, Durable Object,
yeni altyapı yok.

### Yapılacaklar

1. `wrangler.toml`'a iki binding daha: `DL_RL` (indirme), `UL_RL` (yükleme),
   ayrı `namespace_id`, `simple = { limit, period }` bugünkü saatlik
   sayılarla eşleşecek şekilde.
2. `checkRateLimit`'i binding'e çevir — `await env.DL_RL.limit({ key })`.
   KV yolu tamamen silinir (fail-open `catch` dahil; limiter artık
   kaybolmuyor).
3. Çağıranları uyarla. Platform limiter `{ success }` döner, sayaç ve
   `resetInSeconds` vermez — `X-RateLimit-Remaining` / `Retry-After`
   başlıkları buna göre sadeleşir. Bunu ölçmek için önce `checkRateLimit`
   çağıranları tarayıp `result.count` / `resetInSeconds` okuyan yerleri
   listele.
4. `audit-2026-09.md` §5'i kapalı işaretle.

### Çıkış kriteri — karşılandı

- ✅ `grep -rn "kv.put" cloudflare/src/` boş; `rate_limit.ts` ve `RATE_KV`
  binding'i tamamen kaldırıldı
- ✅ `wrangler deploy --dry-run` üç Rate Limit binding'ini bağlıyor,
  KV binding'i listede yok
- ✅ Katalog GET'i bozulmadı — `CATALOG_RL` aynı, yalnızca 429 gövdesindeki
  sabit `CATALOG_LIMIT_PER_MIN` olarak isimlendi

### Uygulamada çıkan fark: `period` yalnızca 10 veya 60

Plandaki 1. madde "bugünkü saatlik sayılarla eşleşecek şekilde" diyordu;
platform limiter'ın `period` alanı **yalnızca 10 veya 60 saniye** kabul
ediyor. Saatlik tavan bu binding ile ifade edilemiyor, dolayısıyla sayılar
dakikalığa çevrildi:

| | Eskiden (KV, saatlik) | Şimdi (platform, dakikalık) |
|---|---|---|
| İndirme | 10 000 / saat | 600 / dakika |
| Yükleme | 60 / saat | 20 / dakika |

Kâğıt üstünde gevşedi, pratikte sıkılaştı: eski sayaç günde ~1000 KV
yazmadan sonra ölüp fail-open geçtiğinden **günün büyük kısmında hiç limit
yoktu.** Dakikalık limiter hiç kaybolmuyor. Gerçek tavanlar zaten R2 kotası
ve `KIND_MAX_BYTES` (dosya başı boyut).

İkinci fark: platform sayaçları **per-colo**, global değil — coğrafi olarak
dağılmış bir istemci efektif olarak limitin katını geçebilir. `CATALOG_RL` bu
takası 2026-09-07'de zaten kabul etmişti; abuse freni için yeterli.

### Bilinçli sınır

İki tane. (1) Durable Object read-then-write yarışını da kapatırdı ve
saatlik pencereyi ifade edebilirdi; platform limiter ikisini de yapmıyor.
Ama buradaki iş bir **abuse freni**, güvenlik sınırı değil — dosyanın kendi
yorumu da bunu söylüyordu. (2) Limit sayıları iki yerde: `wrangler.toml`
(uygulanan) ve `worker.ts` üstündeki `*_LIMIT_PER_MIN` sabitleri (429
gövdesinde bildirilen). Platform limiter sayaç döndürmediği için elle senkron
tutuluyor; ikisi ayrışırsa yalnızca 429 gövdesi yanlış sayı söyler, limit
doğru uygulanır.

---

## 4.2 Faz 1 — ZIP import/export ✅ bitti

*Sunucuya hiç dokunmuyor. Tek başına değerli: hesapsız yedek, DM'den oyuncuya
dünya aktarımı, cihaz değiştirme. LAN silinmeden önce bitmeli (§3.2 Kural 1).*

**Durum:** uygulandı. Codec `lib/application/services/content_transfer/`
altında (`content_codec.dart`, `content_item.dart`, `world_merge.dart`), zip
`content_archive.dart`, UI `presentation/widgets/content_archive_menu.dart`.
`flutter analyze` temiz (0 error/warning); `content_archive_test.dart`,
`content_archive_menu_test.dart` ve taşınan iki test yeşil.

### 1.1 — Codec'i `lan_sync/`'ten çıkar

`lan_sync_session.dart` 659 satır ve **çoğu LAN'a ait değil.** İçindeki
paketleme/uygulama mantığı zip'in de ihtiyacı olan şeyin ta kendisi. Faz 6
`lan_sync/` dizinini komple sildiği için bu kod önce taşınmalı.

Taşınacaklar → `lib/application/services/content_transfer/`:

| Bugün | Ne yapıyor |
|---|---|
| `loadItem` / `_worldExtras` | dünya/paket/karakter → taşınabilir blob + extras |
| `_mediaFor` / `_collectDir` | dünya-paket-karakter medya dosyaları |
| `_collectContentBlobs` / `_collectAssetShas` | `dmt-asset://` vb. ref'lerin **baytları** (`cache/content/{sha}.bin`) |
| `applyItem` / `_applyWorld` / `_applyPackage` / `_applyCharacter` | karşı taraf yazımı |
| `rewriteRoots` / `_rewritePath` | veri kökü takası |
| `_uniqueName`, `_sectionStamps`, `_restoreSectionStamps` | isim çakışması + bölüm damgaları |
| `fileSha256`, `resolveMedia`, `hasMedia`, `writeMedia` | medya yardımcıları |
| `world_merge.dart` (+ testi) | bölüm bazlı birleştirme — zip import'un çakışma çözümü |

`lan_sync/`'te kalanlar: eşleşme, soket, protokol çerçeveleme, ilerleme.

`LanItemRef` / `LanItemPayload` / `LanMediaEntry` `lan_sync_protocol.dart`
içinde yaşıyor ama codec'in sözleşmesi bunlar. Üçü
`content_transfer/content_item.dart`'a taşınıp `Content*` olarak
adlandırılır; `lan_sync_protocol.dart` onları import eder.

**Çıkış kriteri:** `flutter analyze` temiz, `lan_sync_loopback_test.dart` ve
`world_merge_test.dart` **değiştirilmeden** yeşil. Test dosyaları yeni yolu
import etmek dışında düzenlenirse taşıma davranış değiştirmiş demektir.

### 1.2 — Zip formatı

```
<slug>.dmtz                 (zip / deflate)
  manifest.json             {format:1, type, id, name, updatedAt,
                             renamedAt, dataRoot, appVersion}
  payload.json              campaignRepository.load() çıktısı
  extras.json               yalnız dünya — installed_packages, ui_view
  stamps.json               yalnız dünya — WorldSectionStamps
  media/<göreli yol>        baytlar; manifest'teki dataRoot'a göreli
```

**Yol taşınabilirliği için yeni kod yazılmıyor.** `manifest.dataRoot` =
export eden makinenin `userBase`'i — LAN telde ne gönderiyorsa aynısı.
Import `rewriteRoots(payload, manifest.dataRoot, userBase)` çağırır. LAN'ın
iki cihaz arasında yaptığı şeyin aynısı, arada zip var.

`archive: ^4.0.9` **zaten bağımlılık** (`pubspec.yaml:52`). Yeni paket yok.
`ZipFileEncoder`'ın akış API'si kullanılır — büyük dünya belleğe alınmasın.

Medya girdileri `sha256` + `size` taşıyor (bugünkü `LanMediaEntry`); import
sha doğrular, tutmayan dosya atlanır ve uyarı verilir.

### 1.3 — Export akışı

Uygulamada bugün **hiçbir yerde dosyaya kaydetme yok** —
`FilePicker.platform.saveFile` çağrısı sıfır. Bu ilk olacak.

- **Masaüstü:** `FilePicker.platform.saveFile()` → yola akış yazımı
- **Mobil:** `ponytail:` dosya `AppPaths` altındaki Documents'a yazılır ve
  yol snackbar'da gösterilir. Paylaşım sayfası (`share_plus`) bağımlılık
  ekler; gerçekten istenirse eklenir.

Giriş noktaları: hub Dünyalar ve Paketler sekmelerindeki buton satırı, bir de
karakter düzenleyicinin araç çubuğu. Üçü de aynı servisi çağırır, tip
parametresi değişir.

**Düğmenin biçimi** (2026-09-22 düzeltmesi): hub'da tetikleyici gerçek bir
`OutlinedButton.icon` — yani yanındaki "Kopyala" ile aynı widget türü, dolayısıyla
yükseklik/kenarlık/zemin/köşe yarıçapı/dolgu `outlinedButtonTheme`'den geliyor ve
widget'ta tek bir sabit değer yok. Menü `showMenu` ile açılıyor, uygulamanın öbür
dokuz menüsü gibi `popupMenuTheme`'e uyuyor. İlk sürüm çıplak bir
`PopupMenuButton`'dı: içeride `IconButton` üretiyor, yani 48×48 kenarlıksız bir
kutu olarak satırda sırıtıyordu (komşusu 137×48). Karakter düzenleyicide tek
eylem (dışa aktarma) kaldığı için menü hiç açılmıyor — oradaki düğme doğrudan
`IconButton`, geri/ileri düğmeleriyle aynı ölçüde.

### 1.4 — Import akışı + çakışma

- `FilePicker.pickFiles(allowedExtensions: ['dmtz'])`
- `manifest.format` bilinmiyorsa net hata, sessiz kabul yok
- Aynı `id` yerelde varsa kullanıcıya iki seçenek:
  - **Üzerine birleştir** — `mergeWorldPayloads` + `stamps.json`, LAN'ın
    kullandığı yolun aynısı
  - **Kopya oluştur** — yeni uuid, `_uniqueName` ile yeni etiket
- İsim çakışması (farklı id, aynı isim) → `_uniqueName`, sessizce

### 1.5 — Paket export'u hakkında düzeltme

Eski roadmap'in 6. maddesi "mevcut JSON paket export'unu
(`export_package_dialog.dart`) zip'e taşı" diyordu. **Taşınacak bir şey yok:**
o diyalog dosyaya yazmıyor, dünyadan seçilen kartlarla *uygulama içinde* yeni
bir paket kurup `repo.save(name, data)` çağırıyor (satır 235).
`import_package_dialog.dart` da dosyadan değil, kurulu/marketplace
paketlerinden yüklüyor. Madde şuna dönüşür: **paket listesine `.dmtz` export
girişi ekle** — 1.3'ün paket varyantı, ayrı iş değil.

### Faz 1 çıkış kriteri — karşılandı

Temiz bir kurulumda (`AppPaths.dataRoot` silinmiş) import edilen zip'ten çıkan
dünya, export edilen dünyayla eşleşiyor: kartlar, harita görselleri, mind map,
oturumlar, savaş, kurulu paket bağlantıları. Görsellerin açılması şart —
"kartlar geldi, resimler gelmedi" başarısızlıktır.

- ✅ `content_archive_test.dart` bunu **iki ayrı `AppPaths.dataRoot`** arasında
  koşuyor: A'da dünya kurulur + veri kökü dışından bir resim seçilir, export
  edilir, kök B'ye çevrilir, import edilir. Assert'ler hem kartı/oturumu hem
  resmin **yeniden yazılmış yolunu ve baytlarını** kontrol ediyor.
- ✅ 1.1'in kendi kriteri: `lan_sync_loopback_test.dart` ve
  `world_merge_test.dart` **davranış değişikliği olmadan** yeşil — diff'te
  yalnız import yolu ve `Lan*` → `Content*` isim değişikliği var.
- ✅ `flutter analyze lib test` 0 error / 0 warning.

### Uygulamada çıkan farklar

**`stamps.json` yazılmadı.** Plandaki beşinci dosya gereksiz: `extras` zaten
`section_stamps` taşıyor (`_worldExtras`) ve `applyItem` onu oradan okuyor.
Ayrı dosya aynı veriyi ikinci kez yazmak olurdu.

**Manifest `media` listesini de taşıyor.** Plandaki alan listesinde yoktu ama
medya girdilerinin `sha256 + size`'ı bir yerde durmak zorunda — import onunla
doğruluyor. Manifest yalnız pakete **gerçekten giren** dosyaları listeliyor.

**Çakışma diyaloğu yapılmadı, "kopya oluştur" seçeneği yok.** Plan iki seçenek
öneriyordu. Birincisi (üzerine birleştir) zaten `applyItem`'ın varsayılanı ve
yıkıcı değil — bölüm bazlı birleştirme, silme yaymıyor — dolayısıyla soracak
bir şey kalmıyor. İkincisi **yapılamaz**: `world_entities` birincil anahtarı
global `{id}`, `upsert` de `insertAllOnConflictUpdate`. Yeni id'li bir dünya
kopyası, entity satırlarını var olan dünyadan **kendine çeker** ve orijinali
boşaltır. Aynı gizli hata bugün `WorldRepositoryImpl.copy`'de de duruyor
(bkz. §4.9) — önce o düzeltilmeli.

### Bilinçli sınırlar

- Aynı yolda **farklı içerikli** yerel bir dosya varsa üzerine yazılmıyor,
  atlananlara sayılıp kullanıcıya bildiriliyor. Yol `worlds/<isim>/media/...`
  olduğu için isim çakışmasından `(2)` olarak açılan bir import, yerel
  dünyanın resmini ezerdi. Tavan: o durumda kopya yereldeki resmi gösterir.
  Gerçek çözüm import sırasında dünya klasörünü de yeniden adlandırmak —
  Faz 2.5'ten sonra ucuz.
- Mobilde kaydetme diyaloğu yok (planın `ponytail:` notundaki gibi):
  `FilePicker.saveFile` mobilde baytları istiyor, biz diske akıtıyoruz. Dosya
  Documents'a yazılıp yolu snackbar'da gösteriliyor.

---

## 4.3 Faz 2.5 — Dünya kimliği: isimden id'ye ✅ bitti

*Borç ödemesi. Faz 4 push'undan önce şart (§2.10, §3.2 Kural 2).*

**Durum:** bitti. `CampaignRepository`'nin her metodu `worldId` alıyor,
`activeCampaignProvider` id tutuyor, medya klasörü `worlds/<id>/` oldu ve
mevcut kurulumları taşıyan tek seferlik geçiş `app_database.dart`'ın
`beforeOpen`'ında (`world_media_dir_by_id_v1`). Yeni testler:
`test/data/database/world_media_dir_migration_test.dart` ve
`world_srd_opt_out_test.dart`'a eklenen iki kimlik testi.

### Sorun

`CampaignRepository`'nin **her metodu** `String campaignName` alıyor —
`load`, `save`, `saveEntity`, `deleteEntity`, `saveSettingsPatch`,
`saveMapData`, `saveSessions`, `delete`, `purge`, `copy`, `renameWorld`…
`activeCampaignProvider` da `String?` tutuyor ve o string bir **isim**
(`campaign_provider.dart:825`).

`world_join_service.dart:67-84` yerelde isim çakışınca `Ad (2)` üretiyor.
Sonucu: aynı dünya telefonda `Fırtına Vadisi`, laptop'ta `Fırtına Vadisi (2)`.
Push/pull bunun üstüne kurulursa iki cihaz asla buluşmaz.

### Ölçü

| | Sayı |
|---|---|
| `campaignRepositoryProvider` referansı | 30 satır / 13 dosya |
| `worldsDao.getByName` çağrısı | 21 |

Mekanik ama küçük değil. Tek başına bir faz olmayı hak ediyor.

### Yapılacaklar

1. `CampaignRepository` parametresi `campaignName` → `worldId`. Metot adları
   değişmiyor — diff parametre ve gövdeyle sınırlı kalsın.
2. `WorldRepositoryImpl` içinde isim→satır aramaları id→satır olur;
   `getByName` yalnız **kullanıcıya görünen arama** için kalır.
3. `activeCampaignProvider` `String?` world **id**'si tutar. İsim
   gerektiğinde satırdan okunur.
4. `world_join_service.dart`'taki isim-çakışma suffix'i kalkar. Aynı isimli
   iki dünya yerelde yan yana durabilir — ayırt edici id.
5. `worldName` salt etiket: yeniden adlandırma hiçbir anahtarı
   değiştirmediği için `renameWorld` tek satır UPDATE'e iner.

### Faz 2.5 çıkış kriteri — karşılandı

- ✅ **`CampaignRepository` arayüzünde `campaignName` parametresi kalmadı.**
  Her metot `worldId` alıyor. `_findByName` silindi; `worldsDao.getByName`'in
  `lib/` içinde tek bir çağıranı kalmadı.
- ✅ **Aynı isimle iki dünya oluşturulabiliyor, ikisi de doğru açılıyor.**
  `world_srd_opt_out_test.dart` → "aynı isimde iki dünya yan yana durabilir":
  iki `create` farklı id veriyor, ikisi de kendi payload'unu yüklüyor,
  `listWorlds()` ikisini de o adla listeliyor.
- ✅ **Yeniden adlandırma sonrası medya, paketler ve oturumlar duruyor.**
  Aynı dosyada "yeniden adlandırma kimliği değiştirmez". Klasör artık id ile
  anahtarlı olduğu için `oldDir.rename` yolu tamamen kalktı.
- ✅ **Testler yeşil.** `flutter test`: 1513 geçti, tek kırık
  `bundled_pack_resolve_test` — Faz 1'den beri var, temiz ağaçta da düşüyor.
  `flutter analyze lib test`: 0 error / 0 warning.

### Uygulamada çıkan farklar

- **Medya klasörü de id'ye taşındı** — planda yoktu. Zorunluydu: klasör
  `worlds/<dirSafe(ad)>/media/` idi, yani aynı adlı iki dünya aynı klasörü
  paylaşır ve `UnusedMediaSweeper` birini açıp kapatınca ötekinin dosyalarını
  referanssız sayıp silerdi. Mevcut kurulumlar `beforeOpen`'daki
  `world_media_dir_by_id_v1` ile taşınıyor: klasörler yeniden adlandırılıp
  gövdedeki **mutlak** yollar `replaceInEveryTextColumn` + `pathSpellings` ile
  çevriliyor, hepsi tek tablo taramasında. Eşleştirmeye **ayıraç dahil** —
  yoksa "Ad" dünyasının yolu "Ad2"nin yollarının öneki olur ve ikincisinin
  bütün resimleri bozulur (test tam olarak bunu bekliyor).
- **Bir hata kapandı:** `renameWorld` klasörü taşıyıp gövdedeki mutlak yolları
  olduğu gibi bırakıyordu — yani yeniden adlandırılan her dünyanın resimleri
  kırılıyordu. Klasör id ile anahtarlı olunca taşıma da hata da kalktı.
- **`campaignListProvider` ve `getAvailable()` silindi.** İsim listesi aynı
  adı taşıyan iki dünyada belirsiz; yerine `listWorlds()` → `(id, name)`.
- **`CharacterDraft.worldName` → `worldId`.** Sihirbazın dünya seçicisi
  değeri id, etiketi ad tutuyor; `DropdownButton` değerin tam olarak bir kez
  eşleşmesini şart koştuğu için aynı adlı iki dünya eski haliyle assertion
  atardı.
- **`campaign_selector_screen.dart` silindi** — hiçbir yerden referans
  almıyordu (ölü ekran), ama isimle `load`/`create` eden iki çağrı yeri daha
  taşıyordu.
- **`world_join_service`'teki "Ad (2)" suffix'i kalktı** (planlıydı): artık
  yerelde aynı adı taşıyan başka bir dünya varsa bile isim olduğu gibi kalıyor.

### Bilinçli sınırlar

- **Paketler hâlâ isimle anahtarlı.** `PackageRepository.load(name)`,
  `packagesDao.getByName`, `packages/<ad>/media/`. Bu fazın kapsamı dünya;
  paket kimliği ayrı bir iş.
- **Paketlenmiş dünyalar yeniden kurulurken hâlâ adla eşleşiyor.** Doğrusu
  bundle dizininden türetilmiş deterministik bir id olurdu, ama o zaman bugün
  kurulu olan (v4 id'li) dünyalar eşleşmez ve bir sonraki kurulum kullanıcının
  dünyasını güncellemek yerine ikinci bir kopya açardı.
- **Marketplace listing bağları taşınmadı.** `marketplace_links` yerel JSON
  dosyası `world|<ad>` ile anahtarlıydı, artık `world|<id>` yazılıyor; daha
  önce yayınlanmış bir dünyanın bağı eşleşmiyor ("yayınlanmamış" görünür,
  silinince listing'i temizlenmez). §3.1'e göre kullanıcı yok, o yüzden bu
  dosya için ayrı bir geçiş yazılmadı.
- **`ui_state` dünya görünümleri** (açık kartlar, panel filtreleri, açık PDF
  sekmeleri) de ad yerine id ile anahtarlanıyor; eski kayıtlar eşleşmiyor ve
  bu tercihler bir kez sıfırlanıyor. Veri değil, tercih.

### Neden v13 bump'ı burada değil

Bu fazın yeni kolona ihtiyacı yok; `worlds.id` zaten birincil anahtar, medya
geçişi de şemaya dokunmuyor (`migration_progress` satırıyla kapılı). Bump
Faz 4'ün başında, gerçekten kolon gerektiğinde (bkz. §4.0).

---

## 4.4 Faz 3 — Bulut şeması + RLS ✅ bitti

Tek migration: [`094_cloud_mirror_schema.sql`](../supabase/migrations/094_cloud_mirror_schema.sql)
(~960 satır). Doğrulama: [`verify_094.sql`](../supabase/scripts/verify_094.sql).

### Sorun

077 tam aynayı kaldırırken gerekçesi gizlilikti: oyuncunun cihazına DM'in
paylaşmadığı içerik de iniyordu. Ayna geri geliyor ama bu sefer **oyuncu
`world_entities`'e hiç erişmiyor** — tek kapı bir RPC ve redaksiyon sunucuda.
Bu, §3.4'ün en yüksek şiddetli riski; şemayla birlikte testi de yazılmadan
faz bitmiş sayılmaz.

### Yapılanlar

| Bölüm | Ne |
|---|---|
| A | `world_revisions`, `world_tombstones`, `world_member_state` |
| B | 077'den geri gelen altı tablo + `revision` kolonu, `dm_only_keys`, mind map `owner_id` |
| C | Hiç var olmamış beş tablo: encounter, combatant, harita pini, zaman çizelgesi pini, kurulu paket |
| D | `user_packages` / `user_package_entities` / `user_package_schemas` |
| E | `next_world_revision` + damgalama/tombstone trigger'ları, paket sayacı |
| F | RLS + grant'ler (17 tablo) |
| G | `v_shared_entities` görünümü, `get_shared_entities`, `get_shared_entity_ids` |
| H | Kota sabitleri, kart satırı 256 KB, dünya başına 20.000 satır, kişi başı 20 paket |
| I | Realtime: `world_revisions` **eklenir**, hiçbir şey çıkarılmaz |

Toplam ayna yüzeyi **25 tablo** (26 değil — bkz. §4.9).

### Faz 3 çıkış kriteri — karşılandı

> RLS testleri yeşil, istemci hâlâ kullanmıyor.

- `verify_094.sql` yedi bölüm, ~60 assertion: revizyon sayacı, tombstone,
  kota, politika yüzeyi, **oyuncu rolüyle her ayna tablosundan boş dönüş**,
  redaksiyon, DM rolü, başkasının paketi. Tek satır döner: `094 OK`.
- Temiz Postgres 16'da (docker, minimal Supabase iskelesi) çalıştırıldı;
  094 arka arkaya iki kez uygulandı — **idempotent**; script `ROLLBACK` ile
  bitiyor ve `worlds`/`auth.users` sayımı sıfır kalıyor.
- Flutter tarafında tek satır değişmedi.

En kritik iki assertion — ikisi de sızıntıyı doğrudan yakalar:

```
5.1  OYUNCU world_entities OKUYABILIYOR — gizlilik hatasi
6.4  DM'E OZEL ALAN OYUNCUYA SIZDI — redaksiyon calismiyor
```

### Uygulamada çıkan farklar

| Belgede yazan | Uygulanan |
|---|---|
| §2.5: `entity_shares.payload_json` **düşer**, Realtime yayını **sadece** `world_revisions` | İkisi de **ertelendi**. 094 tamamen eklemeli: yerine geçen şey (istemcinin RPC'den çekmesi) Faz 5.5'te, şimdi düşürmek bugün çalışan paylaşım akışını iki faz boyunca kırardı — §3.3'ün "multiplayer paylaşım akışı bozulmamalı" maddesi. `world_revisions` yayına eklendi, hiçbir şey çıkarılmadı |
| §2.2: `world_combat_conditions` ayrı tablo | `world_combatants.conditions_json` kolonu. Yereldeki `combat_conditions` PK'sı `autoIncrement` int — cihazlar arası taşınamaz, bulutta id üretmek gerekirdi. Hiçbir zaman combatant'ından ayrı okunmuyorlar |
| §2.3: `tg_bump_parent_world` geri gelir | Gelmedi, gelmemeli. 050 o fonksiyonu tam da çocuk trigger'ının `worlds` satırını UPDATE etmesi yüzünden budamıştı. Yeni sayaç **ayrı tabloya** (`world_revisions`) yazıyor; aynı tuzak yok. Test 2.3 dünya CASCADE'inde boş tombstone üretilmediğini doğruluyor |
| §2.6: redaksiyon `fields->'attributes' - keys` | `fields_json` zaten `attributes`'ın kendisi (`entityToRaw`'da `'attributes': e.fields`, tabloda düz kolon). Tek seviye: `fields_json::jsonb - dm_only_keys` |
| §2.5: 042'nin "member read" politikaları | `world_settings` / `world_map_data` / `world_sessions` artık **DM-only**. §1.3 "bu kopya sadece sahibine ait" diyor; tablolar zaten sıfırdan kuruluyor, member-read'i taşımanın sebebi yoktu |
| §2.9: mind map `map_id = 'player_<uid>'` konvansiyonu (026) | `owner_id` kolonu. String'e gömülü kimlik yerine kolon; `can_access_map` yeni tablolarda kullanılmıyor |
| §2.5: paylaşım geri çekilince oyuncu nasıl öğrenir | `get_shared_entity_ids(world)` — güncel görünür kart listesi. Tombstone'dan ucuz ve `get_shared_entities` ile **aynı** predikatı (`v_shared_entities`) kullanıyor |

### Bilinçli sınırlar

- **Paket tombstone'u yok.** `world_tombstones` yalnızca dünya kapsamlı.
  Paketler tek sahipli ve küçük; silinmiş paket kartı, id listesi
  karşılaştırmasıyla bulunur. Dünya için aynı şey doğru değildi (çok cihaz +
  çok kullanıcı), o yüzden orada tombstone ilk migration'da.
- **`trg_chars_bump_updated` (026) duruyor.** §2.8'in "sunucu `updated_at`'i
  ezmesin" kuralı yeni tabloların hepsinde geçerli (test 1.5) ama
  `world_characters` hâlâ yaşayan istemcinin yolunda; trigger'ı düşürmek Faz
  4'ün, push yazılırken yapacağı iş.
- **Kota yalnızca sayılabilir olanı zorluyor.** Satır sayısı, satır boyutu ve
  paket adedi trigger/CHECK ile kapalı; kişi başı 500 MB **sabit olarak
  tanımlı ama zorlanmıyor** — gerçek dünya boyutu ölçülmeden eşik
  uydurulamaz (§"Doğrulanmamış tek veri", Faz 7).
- **`v_shared_entities` istemciye kapalı.** Görünüm `postgres`'e ait, yani
  `world_entities` RLS'ini atlar. `anon` ve `authenticated` için `REVOKE`
  edildi ve test 6.7 bunu doğruluyor; tek okuyucusu iki SECURITY DEFINER
  fonksiyon.
- **İki ortamda da doğrulandı.** Geliştirme sırasında temiz Postgres 16'da
  (docker + minimal Supabase iskeleti, iki kez üst üste uygulanarak);
  ardından **2026-09-22'de gerçek Supabase projesinde**: 094 hatasız
  uygulandı, `verify_094.sql` orada da `094 OK` döndü.

---

## 4.5 Faz 3.5 — Medya ref birleştirmesi ✅ bitti

*Tek iş: ref'i tier'dan ayır. İstemci tarafı, bulut şemasına dokunmuyor.*

### Sorun

§2.7: DM'in satırları DM'in kendi diskindeki yolları taşıyor. Bugün sorun
değil çünkü paylaşım anında payload `dmt-transient://{sha}{ext}`'e çevriliyor
— taşınabilir ref **sadece kopyada** var. Faz 4 push'u satırın kendisini
gönderecek; orada `/home/dm/Resimler/ejder.png` oyuncuda anlamsız.

Ama transient ref kalıcı satıra da yazılamıyor: adı baytların transient
havuzda olduğunu iddia ediyor, LRU her an atabilir ve DM kendi resmini
kaybeder (vault bunu bilinçli bir karar olarak yazmıştı). Yani push'un
yazabileceği bir ref biçimi **yoktu**.

### Yapılanlar

| Parça | Ne |
|---|---|
| **Ref biçimi** | `dmt-content://{sha}{ext}` — `AssetRef.contentScheme`, `isContent`, `contentExt`, `formatContentUri`. Hiçbir katman adlandırmıyor; `contentSha` dört şemayı birden çözüyor |
| **`content_paths` yan tablosu** | sha → bu cihazdaki özgün dosya. `_sideTablesDDL`'de idempotent DDL, şema bump'ı yok. PK `(sha, path)` + `path` INDEX |
| **`ContentRefIndex`** | `refFor` / `shaFor` / `fileForSha`. `size`+`mtime` tutuyor: değişmemiş dosya yeniden hash'lenmiyor, **değişmiş dosyanın eski satırı atılıyor** |
| **`SharedMediaCourier`** | Artık `dmt-content://` üretiyor. `serve` önce kalıcı indekse bakıyor; "dünyanın tüm medyasını hash'le" turu yalnızca geri düşüş |
| **`AssetRefResolver`** | Content dalı: içerik store'u → `ContentRefIndex` (yerel dosya, **ağ yok**) → transient indirme. Transient dalı aynı indirme yoluna indirgendi |
| **`MissingMediaReporter`** | `collectTransientRefs` → `collectContentRefs`; iki biçimi de topluyor, ikisi de aynı sha'yı veriyor |
| **Şema listeleri** | `ReferenceIndexer` (yeni şemayı tanımazsa indirilen bayt orphan sanılırdı), `PublishMediaPinner.isMediaRef`, `EvictionSweeper` kardeş-ref kontrolü |

### Faz 3.5 çıkış kriteri — karşılandı

> **ref cihazdan bağımsız çözülüyor**

Ref'in kendisinde cihaz, kullanıcı ya da katman adı yok — yalnız sha. Üç
çözüm yolu da yerinde:

| Kim | Nasıl | Kanıt |
|---|---|---|
| Baytları üreten cihaz | `content_paths` → dosya, ağa hiç çıkmadan | `content_ref_index_test.dart` (6 test) |
| Baytları olmayan cihaz | içerik store'u → transient indirme | mevcut `missing_shas` turu, ref biçiminden bağımsız |
| Hiçbir yerde yoksa | sha `missing_shas`'e yazılır, DM dönünce iner | `shared_media_on_demand_test.dart` |

`flutter analyze` temiz; `test/application/services` + `test/database` +
`test/data` (322 test) ve `asset_ref_test` / `publish_media_pinner_test`
yeşil. Tek kırmızı `bundled_pack_resolve_test` — temiz ağaçta da kırmızı,
bu fazla ilgisiz.

**Elle de doğrulandı** (2026-09-22, gerçek DM + oyuncu): resimli kart
paylaşıldı, oyuncuya resmiyle birlikte gitti; **uygulama kapatılıp yeniden
açıldıktan sonra** da gitti (eşleme artık `content_paths`'te kalıcı, eskiden
her açılışta dünya yeniden taranıyordu); DM'in dosyasının üzerine başka bir
resim yazıldığında oyuncuya **eski resim servis edilmedi**.

### Uygulamada çıkan farklar

| Belgede yazan | Uygulanan |
|---|---|
| §2.7: "DM `asset_refs` tablosundan sha → yerel dosya" | Yapılamaz: `ReferenceIndexer._isAssetRef` ham yolları **kasten** indekslemiyor ("silinen path'ler false-orphan verir"), yani o tabloda yerel dosya diye bir satır hiç yok. Ayrı bir yan tablo açıldı: `content_paths` |
| Eski §4.7 taslağı: "DM push'unda yol→sha" | Dönüşüm noktası doğru ama push henüz yok. Bugün aynı dönüşümü paylaşım ve projeksiyon yolları çağırıyor (`SharedMediaCourier.refFor`); Faz 4 push'u aynı fonksiyonu çağıracak, yeni bir yol yazmayacak |
| §2.7: "ref'i tier'dan ayır" tek başına yeterli | Yetmedi — ref'i tanıyan **dört** yer daha var: `ReferenceIndexer` (tanımazsa `EvictionSweeper` indirilen baytı orphan sanıp siler), `PublishMediaPinner`, `EvictionSweeper`'ın kendisi, `MissingMediaReporter`. Yeni bir şema eklemek bu listeyi gezmek demek |

### Bilinçli sınırlar

- **Kalıcı satırlar hâlâ yerel yol taşıyor.** Ref dönüşümü giden kopyada
  yapılıyor, DM'in Drift satırında değil. Bilinçli: satıra content ref yazmak
  `UnusedMediaSweeper`'ı (satırlarda yol arıyor) ve `ContentCodec`'i
  (zip'e dosya toplarken yol arıyor) aynı anda bozardı. Faz 4 push'u satırı
  gönderirken çevirir — çeviriciyi bu faz hazırladı.
- **`content_paths` cihaz-yereldir ve senkronlanmaz.** Doğru olan bu: aynı
  sha her cihazda başka bir yolda duruyor. Tablo silinse maliyet bir kerelik
  yeniden hash'leme.
- **Eski sürümdeki oyuncu yeni DM'in paylaştığı resmi göremez** —
  `dmt-content://` onun istemcisinde bilinmeyen şema, yerel yol sanıp
  açmaya çalışır. Tersi çalışıyor: yeni istemci eski `dmt-transient://`
  gövdelerini okumaya devam ediyor.
- **Hash akış üzerinden ama izolatta değil.** 100 MB'lık bir handout ana
  isolate'ta hash'leniyor. Ölçülür bir takılma olursa `compute()` doğru
  yükseltme; şimdilik dosya başına bir kez oluyor ve sonucu tablo tutuyor.

---

## 4.6 Faz 4a — Drift v13 + dünya push'u ✅ bitti

*İki iş: şemanın tek seferlik bump'ı ve yereldeki satırların buluta çıkması.*

### Sorun

Faz 3 bulut tablolarını kurdu ama istemci tek satır yazmıyordu. Yazabilmesi
için üç şey eksikti: dünyanın online olduğunu **çevrimdışıyken de** bilecek
yerel bir bayrak, beş tabloda (`encounters`, `combatants`, `map_pins`,
`timeline_pins`, `installed_packages`) hiç olmayan `updated_at`, ve silinen
satırı hatırlayan bir kayıt — silme taramada görünmez.

### Verilen karar: kuyruk değil, watermark

Belge (§2.11) `sync_outbox`'ın geri gelmesini söylüyordu. Kod okunduktan
sonra **kullanıcıya soruldu ve watermark taraması seçildi.** İkisi de aynı
işi yapıyor, farkları ne hatırladıkları:

| | Outbox | Watermark |
|---|---|---|
| Hatırlanan şey | yapılacak işlerin listesi | tek tarih: nereye kadar gidildi |
| Yazma noktaları | her birine `enqueue` serpilir (~20 yer) | **hiçbirine dokunulmaz** |
| Aynı karta 20 düzenleme | 20 kuyruk satırı (ya da ayrı birleştirme mantığı) | tek satır, kendiliğinden birleşik |
| Çevrimdışı birikim | kuyruk diskte büyür | satırlar zaten yerinde |
| Yarıda kalan tur | gidenler kuyruktan düşer | damga ilerlemez, tur baştan gider (upsert idempotent) |
| Eski gerçekleşmesi | `sync_engine.dart` 998 satır | `cloud_push_service.dart` ~330 satır |

Watermark'ın bedeli iki yerde ödendi ve ikisi de kapatıldı: kalıcı reddedilen
bir satır damgayı sonsuza kadar kilitleyebilirdi (→ satır atlanır, damga
ilerler), ve silme taramada görünmez (→ `sync_tombstones`).

### Yapılanlar

| Parça | Ne |
|---|---|
| **Drift v13** | `worlds.is_online` + `cloud_revision`, `packages.is_online` + `cloud_revision`, `world_characters.is_online`, beş tabloya `updated_at`. Tek bump — v13'te ne gerekeceği artık tahmin değil |
| **`onUpgrade` 12→13** | Gerçek geçiş adımı: `addColumn` × 10 + mevcut satırların `updated_at` backfill'i. v12 dosyası **korunur** (aşağıdaki fark tablosuna bak) |
| **`sync_tombstones`** | Yan tablo (raw DDL, bump yok): `(table_name, row_id, world_id, deleted_at)`. DAO silme yollarında yazılır |
| **`sync_stamp.dart`** | İki satırlık sözleşme: `stampedNow` (upsert damgası) + `recordTombstone(s)`. DAO'lar bunu çağırıyor, başka kimse |
| **`CloudPushService`** | Tarama + gönderim. 10 tablo bildirimsel bir listede (`_mirrorTables`), combatant ayrı (dünyası encounter'dan gelir, koşulları JSON kolona iner) |
| **`CloudPushPump`** | `PendingWriteBuffer.tick` → 3 sn sessizlik → tur. Dünya açıkken `MainScreen`'in keep-alive kalıbıyla yaşıyor |
| **`_makeOnline` / `_confirmOffline`** | Yerel bayrağı yazıyor; online yapınca **tam tur** koşuyor. Offline yapınca damga sıfırlanır — yeniden açılırsa kapalıyken yapılan düzenlemeler de gider |

Turun anatomisi:

```
cutoff = now()                      ← taramadan ÖNCE alınır
tombstone'lar  → bulutta DELETE     ← upsert'ten ÖNCE (sil+yeniden yarat doğru çalışsın)
her tablo      → updated_at > damga → 200'lük parçalar hâlinde upsert
damga = cutoff                      ← yalnız tur temiz bittiyse
```

### Faz 4a çıkış kriteri — karşılandı

> **dünya bulutta görünüyor, geri okuma yok**

- `cloud_push_collect_test.dart` (8 test) turun satır üretimini ağsız
  doğruluyor: watermark penceresi, SQLite 0/1 → `boolean`, unix saniye → ISO,
  `dm_only_keys`'in bilinmeyen kategoride **NULL** kalması, combatant'ın
  dünyasının encounter'dan gelmesi, koşul değişiminin ebeveyni damgalaması,
  silmenin tombstone bırakması, yeniden yaratılan satırın **öldürülmemesi**.
- `v13_schema_smoke_test.dart` kolonları ve yan tabloyu doğruluyor.
- `flutter analyze` temiz; tam `flutter test` 1541 yeşil / 1 kırmızı ve o tek
  kırmızı (`bundled_pack_resolve_test`) temiz ağaçta da kırmızı.
- Geri okuma **yok**: servis hiçbir yerde `select` etmiyor, applier'a
  dokunulmadı. Pull Faz 5.

**Gerçek projede kısmi kanıt (2026-09-22).** Aegis dünyası
(`47272f9a-baf7-4eb6-acdf-267f8dfc6b4e`) uygulamadan online yapıldı ve
yereldeki `worlds.last_cloud_push_at` **yazıldı**. Damga yalnız tur ağ hatası
almadan bittiğinde ilerlediği için bu, oturumun + RLS'in + upsert yolunun
gerçek Supabase'de çalıştığını gösteriyor. Göstermediği şey satır satır
doğruluk: reddedilen satır sessizce atlanıp damga yine ilerliyor (aşağıdaki
"bilinçli sınırlar"). Bulut tarafındaki sayım kontrolü §4.7 sonundaki listede.

### Uygulamada çıkan farklar

| Belgede yazan | Uygulanan |
|---|---|
| §2.11: `sync_outbox` geri gelmeli | Gelmedi — watermark taraması seçildi (yukarıdaki karar tablosu). `_retiredTablesDDL`'deki `DROP TABLE IF EXISTS sync_outbox` **duruyor** |
| §4.0: "v13'e çıkmak her kullanıcının DB'sini `.legacy` yapar" | Yapmıyor. `_openConnectionForUser`'daki kesim `user_version < 12` diyor; v12 dosyası kesime takılmaz, Drift `onUpgrade(12→13)` koşar. Yani bump'ın bedeli sıfır değil — **gerçek bir geçiş adımı yazmak** gerekti (eski `onUpgrade` `createAll()` çağırıyordu, o kolon eklemez) |
| §2.3: her ayna tablosunda `revision` + `updated_at`, delta sorgusu bunun üzerinden | Bulut tarafı öyle; **istemci** tarafında `revision` yazılmıyor, yazılmamalı — sayaç `next_world_revision` ile sunucuda artıyor. Yerel `worlds.cloud_revision` Faz 5'in okuyacağı boş kolon olarak duruyor |
| §2.2: `world_combat_conditions` | Yerel `combat_conditions` PK'sı autoincrement int; push onu combatant'ın `conditions_json`'ına katlıyor. Koşul eklemek/silmek ebeveyni damgalıyor, yoksa değişiklik taramaya hiç girmezdi |
| §4.5: "Faz 4 push'u satırı gönderirken çevirir" | Çevirdi ve **çevirici genişledi**: `refFor` yalnız entity'nin görsel alanlarında değil, `settings_json` / `data_json` / `map_path` / mind map `image_url` içinde de çalışıyor — gövdeler şemasız gezilip mutlak yol taşıyan her string dönüştürülüyor |

### Bilinçli sınırlar

- **Reddedilen satır sessizce atlanır.** Bir parça reddedilirse suçlu satır
  tek tek denenerek bulunur, atlanır ve damga yine de ilerler — tek bir dev
  kart bütün dünyanın senkronunu kilitlemesin. Bugün sonucu yalnız
  `debugPrint` görüyor; kullanıcıya "şu kart buluta sığmadı" demek Faz 7'nin
  kota göstergesiyle gelecek.
- **`revision` istemcide boş.** `worlds.cloud_revision` kolonu var, kimse
  yazmıyor. Faz 5 pull'u dolduracak.
- ~~**Karakterler ve paketler bu turda yok.**~~ Faz 4b kapattı: ikisi de
  turda (§4.7). `pushCharacter` doğrudan yolu güvenlik ağı olarak duruyor.
- **Tur yalnız yazma tamponunun tick'iyle başlar.** Uygulama kapanırken ayrı
  bir "son tur" yok — gerek de yok: gitmeyen satırlar yerinde duruyor ve
  damga ilerlemediği için bir sonraki açılışta ilk düzenlemede giderler.
  Kaybolan bir şey olmuyor, yalnız gecikme.
- **Mind map tabloları boş gidiyor.** `world_mind_map_nodes/_edges` yerelde
  kayıtlı ama uygulama mind map'i bugün `world_settings.settings_json`
  içindeki `mind_maps` anahtarında tutuyor — yani push'a ayarlarla birlikte,
  medya çevirisi dahil, giriyor. Bulut tabloları o veri kendi satırlarına
  ayrılana kadar boş kalır.
- **Tam tarama, indekssiz.** Tur her tabloda `world_id = ? AND updated_at > ?`
  koşuyor; `world_id` indeksleri var, `updated_at` için ayrı indeks yok.
  20.000 satırlık dünyada ölçülebilir bir gecikme çıkarsa doğru yükseltme
  `(world_id, updated_at)` bileşik indeksi — ölçülmeden eklenmedi.

---

## 4.7 Faz 4b — Paket + karakter push'u ✅ bitti

*Aynı watermark iskeleti, iki yeni kapsam: kullanıcının paketi ve dünyanın
karakterleri.*

### Sorun

Faz 4a'nın turu yalnız dünyayı tanıyordu. Geriye iki delik kaldı:

- **Paket hiç buluta çıkmıyordu.** §1.2 "paket online olabilir" diyor,
  `user_packages` / `user_package_entities` / `user_package_schemas` Faz 3'te
  kuruldu, `packages.is_online` v13'te geldi — ama yazan kimse yoktu.
- **Karakterin çevrimdışı düzenlemesi kayboluyordu.**
  `WorldMirrorService.pushCharacter` tek atışlık doğrudan yazma: ağ yoksa
  yazma düşüyor, yeniden deneyen bir şey yok. Kart için Faz 4a bunu kapatmıştı
  (satır yerinde durur, damga ilerlemez, sonraki tur bulur), karakter için
  kapatmamıştı.

### Yapılanlar

| Parça | Ne |
|---|---|
| **`_MirrorTable` genelleşti** | Tarama artık kapsam kolonunu tablodan okuyor (`scope`: dünyada `world_id`, paket çocuklarında `package_id`, paketin kendi satırında `id`). Üstüne üç küçük alan: `rename` (yerel ↔ bulut kolon adı), `jsonCols` (TEXT → `jsonb`), `owner` (satırın `owner_id`'si nereden geliyor) |
| **`pushPackage` + `collectPackage`** | `pushWorld`/`collect` ile bire bir aynı iskelet; damga `packages.last_cloud_push_at`, `dm_only_keys` yok (paket oyuncuyla paylaşılmıyor, RLS tek kolona bakıyor) |
| **`unpublishPackage`** | "Yerele al" yolu: bulut satırı silinir, çocuklar FK cascade'iyle gider, bekleyen tombstone'lar düşer |
| **Karakterler ayna ailesine katıldı** | `world_characters` `_mirrorTables`'ta. `referenced_entity_ids_json` → `referenced_entity_ids` (yeniden adlandırma + `jsonb` çözümü) |
| **Migration 095** | `trg_chars_bump_updated` düştü — 094'ün başlığında "Faz 4'te" diye yazılı olan borç. Zamanı artık istemci yazıyor (§2.8); `pushCharacter` de aynı anahtarı göndermeye başladı ki trigger düşerken damgayı yazan biri kalsın |
| **DAO'lar** | `packages` / `package_entities` / `package_schemas` / `world_characters` upsert'leri `stampedNow` ile damgalanıyor, silme yolları tombstone bırakıyor. `dropOwnership` de damgalanıyor — `owner_id` RLS girdisi, damgasız kalsa taramaya girmezdi |
| **Pompa iki turlu** | `tick` → dünya turu → paket turu. İkisi sıralı koşuyor, tek `_guarded` kapısından geçiyor |
| **Paket ekranında anahtar** | `SaveSyncIndicator(isPackage: true)` diyaloğunda "Paketi Online Yap / Yerele Al" (4 dilde 6 yeni l10n anahtarı). Paket ekranı pompayı `MainScreen` ile aynı keep-alive kalıbıyla canlı tutuyor |

### Faz 4b çıkış kriteri — testlerle karşılandı

> **paket/karakter de buluta çıkıyor**

- `cloud_push_collect_test.dart` 8 → **15 test**: karakterin referans
  listesinin `jsonb`'ye çevrilip yeniden adlandırılması, payload blob'una
  dokunulmaması, karakter silmesinin tombstone bırakması, paketin ebeveyn
  satırının damgadan bağımsız gitmesi, çocukların damgaya bakması,
  `owner_id`'nin her satıra yazılması, paket kartı silmesinin tombstone'u
  **paket kapsamına** yazması, paket silinince kayıt birikmemesi, offline
  paketin atlanması, damganın offline'da sıfırlanması.
- `flutter analyze` temiz (30 önceden var olan info); tam `flutter test`
  **1549 yeşil / 1 kırmızı**, o tek kırmızı (`bundled_pack_resolve_test`)
  temiz ağaçta da kırmızı.
- Geri okuma yine **yok** — pull Faz 5.

### Uygulamada çıkan farklar

| Belgede yazan | Uygulanan |
|---|---|
| Eski §4.7 taslağı: "`world_characters` üstündeki `isOnline` bayrağı" | Kolon duruyor ama **kimse okumuyor**. Dünya başına bir anahtar var, karakter başına ikincisinin bugün anlamı yok: dünyanın karakterleri dünya online'sa gider. Kolon `cloud_revision` gibi Faz 5.5'i bekliyor — oyuncunun dünyaya bağlı olmayan karakteri ortaya çıkınca kullanılacak |
| Eski §4.7 taslağı: "paketin kendi revizyon sayacı" | Sayaç bulutta (`next_package_revision`), istemci yine yazmıyor — dünyadaki kuralın aynısı |
| Faz 4a: "`pushCharacter` doğrudan yolu duruyor" | Duruyor ve **duracak**. Tur onun yerine geçmiyor, güvenlik ağı: doğrudan yol anında yazıyor (oyuncu canlı oyunda beklemesin), tur 3 sn sonra aynı satıra idempotent upsert yapıyor. Doğrudan yolun emekliliği Faz 5.5'te, oyuncu RPC'ye geçince |

### Bilinçli sınırlar

- ~~**Paketin silinmesi buluta gitmiyor.**~~ Faz 5c kapattı (§4.8.2). Paket yerelden silinince
  `pushPackage` bir daha koşamaz (satır yok), o yüzden `deletePackage`
  bekleyen tombstone'ları temizliyor ve bulut satırı yerinde kalıyor. Bulut
  kopyasını düşüren tek yol bugün "Yerele al". Dünyada da aynı yapı var
  (`deleteWorld` + `unpublishWorld`); doğru kapanışı Faz 5'in uzlaştırıcısı.
- **Karakter görselleri mutlak yolla gidiyor.** `payload_json` medya
  çevirisine sokulmadı: blob'un byte-for-byte korunması kuralı
  (`world_characters_dao`) jsonDecode/encode turundan ağır basıyor. Bugünkü
  `pushCharacter` de aynısını yapıyor, yani gerileme yok — `dmt-content://`
  çevirisi karakterler için ayrı bir iş.
- **Paket kapsamı `sync_tombstones.world_id` kolonunda taşınıyor.** Kolon adı
  artık "kapsam" demek. Yeniden adlandırmak yan tablonun `CREATE TABLE IF NOT
  EXISTS` DDL'ini kırardı; adın yalanı yorumla kapatıldı.
- **Paket turu yalnız paket açıkken koşuyor.** Hub'dan paketi online yapmak
  yok; anahtar paketin içindeki Save & Sync diyaloğunda.
### Bekleyen doğrulama

4a ve 4b'nin testleri yeşil ama **ikisi de gerçek projede uçtan uca
koşturulmadı.** Faz 3 ve 3.5'te olduğu gibi (§4.4, §4.5) burada da elle
doğrulama yapılana kadar faz "kapandı" sayılmaz. Sırasıyla:

**1. Migration 095 — deploy edildi** (2026-09-22). Tek satırdı:

```sql
DROP TRIGGER IF EXISTS trg_chars_bump_updated ON public.world_characters;
```

Bu yapılmadan karakter testi yanıltır: sunucu `updated_at`'i kendi saatiyle
ezmeye devam eder ve §2.8 ihlali gizli kalır.

**2. Dünya turu (4a).** Aegis dünyası zaten online ve damgası yazılmış;
bulut tarafındaki sayım kontrolü yapılmadı:

```sql
select count(*) from world_entities
  where world_id = '47272f9a-baf7-4eb6-acdf-267f8dfc6b4e';   -- yerelde 189
select revision from world_revisions
  where world_id = '47272f9a-baf7-4eb6-acdf-267f8dfc6b4e';   -- > 0
select substr(image_path,1,14), dm_only_keys from world_entities
  where world_id = '47272f9a-baf7-4eb6-acdf-267f8dfc6b4e'
    and image_path <> '' limit 5;                            -- dmt-content://
```

Sayı tutmuyorsa suçlu, sessizce atlanan reddedilmiş satırlardır — `rejected`
bugün yalnız `debugPrint`'e düşüyor. Yereldeki `image_path`'in `/home/...`
kalması **doğru**: çeviri yalnız giden kopyada (§4.5).

**3. Paket turu (4b).** Yerelde tek paket var — SRD 5.2.1 Core,
`d95e214e-ff70-4bb7-9071-222ceb3abaa9`, **2721 kart**, `is_online = 0`. İlk
tur ~14 parça sürer; daha hızlı bir tur için birkaç kartlık yeni bir paket
açmak yeterli. Paketi aç → Save & Sync → "Paketi Online Yap":

```sql
select id, name, revision, updated_at from user_packages;
select count(*) from user_package_entities where package_id = '<id>';
select count(*) from user_package_schemas  where package_id = '<id>';
```

`owner_id` her satırda oturumun uid'i olmalı; RLS başkasına döndürmüyor, boş
sonuç "yanlış hesapla bakıyorsun" demek olabilir. Ardından artımlı tur (bir
kartın adını değiştir → 4 sn → satır güncellendi mi), silme (kart sil → 4 sn
→ satır bulutta yok mu) ve "Yerele al" (ebeveyn gitti mi, çocuklar cascade
ile gitti mi).

**4. Karakter (4b'nin asıl kazancı).** Bir karakteri düzenle → 4 sn:

```sql
select id, template_name, owner_id, updated_at, referenced_entity_ids
from world_characters where world_id = '47272f9a-baf7-4eb6-acdf-267f8dfc6b4e';
```

`updated_at` **düzenleme saati** olmalı (sunucu saati geldiyse 095
uygulanmamış), `referenced_entity_ids` gerçek bir dizi olmalı (tırnaklı
string değil). Asıl senaryo çevrimdışı: internet kapalıyken karakteri düzenle
→ interneti aç → herhangi bir kartı kurcalayıp turu tetikle → satır buluta
çıkmalı. Eski doğrudan push yolunda o düzenleme sessizce kayboluyordu; bu
fazın kapattığı delik tam olarak bu, dolayısıyla **atlanmaması gereken tek
test** bu.

---

## 4.8 Faz 5a — Dünya pull'u ✅ bitti

*Aynanın ikinci yönü. Push'un bildirimi ters okunuyor; yeni olan tek şey
okuma kapısı ve uzlaştırma kuralı.*

### Sorun

Faz 4a/4b aynayı tek yönlü kurdu: dünya buluta çıkıyor, geri okuyan yok.
§1.3'ün vaadi ("laptop'ta hazırlık, tablette devam") tam olarak eksik olan
yön.

Koda bakınca ikinci, **daha ciddi** bir sorun çıktı: 094'ün trigger'ı pull'u
imkânsız kılıyordu.

```
trg_*_stamp_rev  BEFORE INSERT OR UPDATE ... EXECUTE tg_stamp_world_revision()
                 ↑ WHEN şartı yok
```

Pull satırı bulutun `updated_at`'i ile yerele yazar. O zaman satır push
damgasından yeni görünür, push onu geri gönderir, trigger revizyonu **yine**
artırır, karşı cihaz sinyal alır, o da pull eder… iki cihaz arasında kapanmayan
bir tur. Aynı hata bugün bile para yakıyor: `user_packages` satırı push'ta
`sinceAll` (her tur gider, çocukların FK hedefi), yani hiçbir şey değişmese
bile her tur revizyonu bir artırıyor.

### Verilen karar: kırpmalı tek RPC, per-tablo select değil

İki seçenek vardı. Tablo başına PostgREST select **sıfır yeni SQL** isterdi —
RLS zaten DM'e açık, `revision` kolonu her tabloda var, istemcide harita hazır.
Bedeli pull başına 13 HTTP isteği. Sinyal başına 13 gidiş-geliş, kalıcı bir
maliyet; RPC'nin bedeli ise tek seferlik ~100 satır SQL. §2.3'ün kararı da
buydu, korundu.

Belgede olmayıp eklenen tek şey **sayfalama**: tablo başına `limit`, bir tablo
dolduysa turun kesme noktası o tablonun son satırına çekilir ve tüm tablolar
oradan kırpılır. §2.3'ün "yeni cihazda ilk açılış ~10 MB" satırı, kırpma
olmadan tek bir 10 MB'lık jsonb yanıtı demekti — telefonda bellek sorunu.
İlerleme garantili: kesme noktası her zaman `since`'ten büyük.

### Yapılanlar

| Parça | Ne |
|---|---|
| **Migration 096 — echo guard** | 16 tablonun `trg_*_stamp_rev`'i ikiye bölündü: `_ins` şartsız, `_upd` yalnız `WHEN (OLD.* IS DISTINCT FROM NEW.*)`. Upsert yalnız gönderilen kolonları yazdığı için içerik aynıysa `NEW = OLD` ve sayaç kıpırdamaz. Satır yine UPDATE edilir (boşa yazma) ama sinyal çıkmaz |
| **Migration 096 — `get_world_delta`** | `(world, since, limit)` → `{revision, head, complete, tables, tombstones}`. SECURITY **INVOKER**: RLS çağıranın rolüyle işliyor, oyuncu bu kapıdan DM kartı alamıyor. 12 ayna tablosu + tombstone'lar, kırpmalı |
| **`cloud_mirror_tables.dart`** | `_MirrorTable` + iki liste `cloud_push_service.dart`'tan çıktı. Tek bildirim, push soldan sağa pull sağdan sola okuyor. Pull için eklenen tek alan: `key` (yerel PK — `id`, 1:1'de `world_id`, `installed_packages`'ta bileşik) |
| **`CloudPullService`** | `pullWorld` (sayfa döngüsü + damga) ve `apply` (**ağsız**, testin girdiği kapı). Ters dönüşümler: ISO → unix saniye, `boolean` → 0/1, `jsonb` → TEXT, `rename` tersine, `dmt-content://` → `ContentRefIndex.fileForSha` |
| **Uzlaştırma** | Son düzenleyen kazanır: yerel `updated_at` gelenden büyük **ya da eşitse** satır atılır. Tombstone'un `deleted_at`'i yerel düzenlemeden eskiyse satır silinmez — sonraki push onu buluta geri koyar |
| **`syncOnOpen`** | Rol DM'e çözülünce bir kez: **önce push, sonra pull**. Sıra bağlayıcı, gerekçe aşağıda |

### Faz 5a çıkış kriteri — testlerle karşılandı

> **bulutta değişen satır yerele iniyor, döngü yok**

- `cloud_pull_apply_test.dart` **14 test**: tip dönüşümleri, bulut-yalnızı
  kolonların (`revision`, `dm_only_keys`) sızmaması, LWW'nin iki yönü,
  tombstone'un iki yönü, pull silmesinin yerel tombstone bırakmaması,
  combatant koşullarının açılması, encounter silmesinin elle cascade'i,
  karakterin `jsonb` dizisi + aynalanmayan `is_online`'ın korunması, 1:1 ve
  bileşik anahtar, damganın yazılması.
- Sonuncusu **round-trip**: pull edilen satır push'a verildiğinde bayt bayt
  aynı gövdeyi üretiyor. Echo guard'ın çalışması tam buna bağlı — tek kolon
  farklı çıksa `OLD.* IS DISTINCT FROM NEW.*` doğru olur ve döngü kapanmaz.
- `verify_096.sql`: echo guard'ın iki yönü (aynı gövde artırmamalı, gerçek
  değişiklik artırmalı), delta penceresi, tombstone, kırpmanın satır
  kaybetmemesi, sayfalamanın sonlanması, "oyuncu bu kapıdan DM kartı göremez".
- `flutter analyze` temiz (30 önceden var olan info); `cloud_push_collect_test`
  15/15 yeşil (bildirim taşınması push'u bozmadı).

### Uygulamada çıkan farklar

| Belgede yazan | Uygulanan |
|---|---|
| Eski §4.8 taslağı: "applier'ın tablo başına ayrı handler olarak yeniden yazımı" | Yapılmadı ve **gerekmiyor**. `world_mirror_applier.dart` paylaşım yayınının tüketicisi, ayna pull'unun değil; ikisi ayrı kanallar. Pull'un tablo başına handler'a ihtiyacı yok çünkü `cloud_mirror_tables.dart` bildirimi zaten tablo başına dönüşümü tarif ediyor — elle yazılan tek özel durum combatant |
| §2.3: "tek RPC `get_world_delta(world_id, since_revision)`" | Üçüncü parametre `limit` eklendi ve yanıt `complete` taşıyor. Sebebi §2.3'ün kendi cümlesi: ilk açılış ~10 MB, tek jsonb olarak telefonda bellek sorunu |
| §2.3: "her ayna tablosunda `revision` + `updated_at`" | Doğru ve yeterliydi; ama trigger'ın **şartsız** olması pull'u imkânsız kılıyordu. Belgede hiç geçmeyen delik; 096 kapattı |
| Eski §4.8 taslağı: "ilk senkron akışı ve ilerleme UI'ı" | Faz 5b'ye kaydı. 5a'nın kapsamı motor + uzlaştırıcı; tetikleyici bugün dünya açılışı |

### Bilinçli sınırlar

- ~~**Realtime sinyali yok.**~~ Faz 5b kapattı (§4.8.1).
- ~~**Açık dünyanın bellekteki hali tazelenmiyor.**~~ **Kapandı** — bkz.
  aşağıdaki "Sonradan eklendi". Pull Drift'e yazıyor ama
  `EntityNotifier._loadFromCampaign` Drift'ten değil `ActiveCampaignNotifier`'ın
  **bellekteki blob'undan** okuyor; inen satırlar o açılışta değil bir
  sonrakinde görünüyordu.
- ~~**Paket pull'u yok.**~~ Faz 5c kapattı (§4.8.2).
- **Pull'dan sonra bir tur fazla push olabilir.** `syncOnOpen` push'u önce
  koşturuyor ve damgayı `now()`'a çekiyor, dolayısıyla ondan **önce**
  düzenlenmiş uzak satırlar bir sonraki taramaya düşmez. Saat kayması olan
  cihazın satırları düşebilir; echo guard sayesinde bedeli bir kerelik boşa
  upsert, sinyal değil.
- **Reddedilen satır pull tarafında yok.** Push'taki "suçluyu bul, atla"
  mekanizmasının karşılığı gelen yönde gerekmedi: yerel yazma kotaya takılmaz.
  Şema uyuşmazlığı çıkarsa tur patlar ve damga ilerlemez — doğru davranış.
- **`_maxRounds = 200`** — sayfa döngüsünün güvenlik freni. Tablo başına 500
  satırla 100.000 satırlık bir dünyayı tek çağrıda bitirir; sunucu `complete`
  demeyi beceremezse sonsuza kadar dönmesin diye.

### Sonradan eklendi: açık dünyanın tazelenmesi

Yukarıdaki sınır 5a'yı **kullanıcıya tamamen görünmez** kılıyordu, o yüzden
5b'ye bırakılmadı. Yeni kod yok — depoda hazır olan yol kullanıldı:
`ActiveCampaignNotifier.reload()` zaten `_repo.load()` ile blob'u **yerinde**
değiştirip `campaignRevisionProvider`'ı bump ediyor (cloud restore bu yoldan
geçiyor). `CloudPushPump.pull()` artık tur satır uyguladıysa ve çekilen dünya
hâlâ açık dünyaysa onu çağırıyor.

Kapsam kontrolü: `_loadFromDb` pull'un yazdığı granüler tabloların hepsini
(kartlar, ayarlar, `map_data`, oturumlar, mind map, savaş, pinler) blob'a
topluyor. `installed_packages` zaten Drift `StreamProvider`'ı üstünden canlı.
`worldCharactersProvider` bulut kaynaklı, pull'un yazdığı yerel satırı
okumuyor — tazeleme gerekmiyor.

~~Bilerek yapılmadı: **pull'dan önce `PendingWriteBuffer.flush()`.**~~ 5b'de
geldi: pull artık düzenleme sürerken de koşabiliyor, tampondaki satır Drift'e
inmeden LWW onu bayat haliyle karşılaştırırdı (§4.8.1).

### Bekleyen doğrulama

**1. Migration 096 — deploy edildi** (2026-09-22, 095 ile birlikte).
`supabase/scripts/verify_096.sql` henüz koşturulmadı; `096 OK` dönmeli.

**2. Echo guard'ın tek başına ölçülmesi.** 096'dan **sonra**, hiçbir şey
düzenlemeden uygulamayı açıp kapatarak birkaç push turu koşturun:

```sql
select revision from world_revisions
  where world_id = '47272f9a-baf7-4eb6-acdf-267f8dfc6b4e';
select revision from user_packages;
```

İki sayı da **sabit kalmalı.** Artıyorsa guard tutmuyor demektir ve pull'u
açmak iki cihazı birbirine kilitler — 5b'ye geçmeden önce durulacak nokta.

**İlk ölçüm tutmadı (2026-09-22):** hiçbir şey düzenlemeden aç–kapa, sayaç
55 → 57. Suçlu guard değildi, gönderilen gövdenin **gerçekten** her seferinde
farklı olmasıydı: `WorldMapScreen.deactivate()` harita sekmesinden her çıkışta
`map_data`'yı koşulsuz yazıyor ve `saveSettingsPatch` her çağrıda
`_section_updated_at[bölüm] = now()` damgalıyordu — içerik aynı, `settings_json`
bayt bayt farklı. Bedeli her dünya kapanışında boşuna giden 773 KB'lık blob.
a3dbfad2 kapattı: patch'teki her anahtar depodakiyle aynıysa `saveSettingsPatch`
hiç yazmıyor. Sayacı hangi satırın artırdığını göstermek için
`supabase/scripts/which_bumped.sql`. **Ölçüm düzeltmeden sonra yeniden
koşturulmadı** — 5b'nin doğrulamasının ilk adımı bu (§4.8.1).

**3. Pull'un kendisi — iki cihaz.** A'da bir kartın adını değiştir, dünyayı
kapat. B'de aynı dünyayı aç: kart yeni adıyla gelmeli. Sonra A'da bir kart
sil, B'yi yeniden aç: kart gitmeli. Tersi de: B'de düzenle, A'da aç.

**4. Asıl senaryo — savaş (§1.3).** A'da savaşı yarıda bırak (sıra, HP,
durum etkileri), kapat. B'de aç: `world_combatants` satırları inmiş,
`combat_conditions` yeniden kurulmuş olmalı. Bu, pull'un tek elle yazılmış
özel durumu, dolayısıyla **atlanmaması gereken test** bu.

**5. Çatışma.** Aynı kartı A ve B'de farklı zamanlarda düzenle, sonra ikisini
de senkronla: **sonra düzenlenen** kazanmalı — varış sırası değil (§2.8).

---

## 4.8.1 Faz 5b — Canlı sinyal ✅ bitti

*Pull'un tetiği dünya açılışından bulut sayacına taşındı. Yolda üç gizli
hata çıktı; ikisi bulutta, biri istemcide.*

### Sorun

5a'nın pull'u dünya açılışında bir kez koşuyordu. Karşı cihazın değişikliğini
görmenin yolu dünyayı kapatıp açmaktı — §1.3'ün "hiçbir şey yapmadın,
kendiliğinden oldu" vaadi eksikti.

Kod okununca iki sorun daha çıktı:

1. **`syncOnOpen` uygulama başına bir kez koşuyordu, dünya başına değil.**
   `cloudPushPumpProvider` sıradan (autoDispose olmayan) bir `Provider`, kök
   kapsamda yaşıyor ve dünya kapanınca dispose olmuyor. Yorumdaki "pompa
   dünya kapanınca dispose olduğu için bayrak da onunla gider" doğru değildi:
   `_opened` ilk DM dünyasında `true` olup öyle kalıyordu. İkinci açılan
   dünya — ya da aynı dünyanın ikinci açılışı — hiç pull almıyordu.
2. **Sunucu "son düzenleyen kazanır"ı uygulamıyordu.** §2.8 istemcide vardı
   (pull: yerel ≥ gelen → at), bulutta yoktu: push düz upsert, varış sırası
   kazanıyordu. Belgenin kendi örneği (telefon 14:00, laptop 15:00, telefon
   16:00'da ağa girer) **kalıcı ayrışma** üretiyordu: bulut ve telefon 14:00,
   laptop 15:00 — ve laptop'un pull'u 14:00'ü "eski" diye attığı için kimse
   kimseyi düzeltmiyordu. Silmede de aynısı: çevrimdışı cihazın eski
   düzenlemesi silinmiş kartı upsert'le yeniden INSERT edip diriltiyordu.
   Canlı sinyal bunu seyrek bir durumdan her çevrimdışı dönüşe taşırdı.
3. **096'nın echo guard'ı upsert'te delikti.** PostgREST'in upsert'i
   `INSERT … ON CONFLICT DO UPDATE` ve Postgres BEFORE INSERT trigger'larını
   çakışma kontrolünden **önce** koşturuyor: var olan satırın upsert'inde de
   `trg_*_stamp_rev_ins` sayacı artırıyordu. Aynı gövde bile bir revizyon
   yakıyordu, değişen gövde **iki** — biri hiçbir satırın taşımadığı ölü bir
   revizyon. `verify_096` guard'ı düz `UPDATE` ile test ettiği için görmedi;
   `verify_097`'nin ilk koşusu yakaladı. Bedeli iki katı Realtime mesajı ve
   aşağıdaki yankı kontrolünün hiç tutmaması (her güncellemede bir boşluk).

### Verilen kararlar

**Sinyal mevcut kanala, yalnız DM'e.** `dmt:world:{id}` kanalı DM'de zaten
açık ve reconnect/backoff mantığı hazır; ikinci bir kanal o mantığın kopyası
olurdu. `world_revisions` binding'i yalnız `onRevision` verilince ekleniyor ve
onu yalnız DM veriyor — oyuncunun ayna kapısı yok (Faz 5.5), sinyal ona her DM
yazmasında boşa bir mesaj olurdu.

**Uzlaştırma anı = kanalın `SUBSCRIBED` anı.** `syncOnOpen`'ın bayrağı
düzeltilmedi, kaldırıldı. Kanal zaten ilk bağlanmada, her reconnect'te ve
uygulama öne geldiğinde (`resumed` → applier invalidate) `SUBSCRIBED`'a
geçiyor; postgres_changes kesintideki mesajları tekrar etmediği için tam da o
an telafi gerekiyor. Bayrağa gerek kalmıyor.

**Kendi yankımızı çekmemek: dönen revizyonlar boşluksuzsa damgayı ilerlet.**
Sayaç her yazmada artıyor ve sinyal yazan cihaza da geliyor. Önlem alınmasa
DM'in her düzenlemesi kendi pull'unda geri inerdi — `map_data` gibi 773 KB'lık
bir satırda her harita dokunuşu bir egress. `updated_by` işe yaramıyor (aynı
hesabın iki cihazı aynı uid). Çözüm push'un kendi elinde: upsert
`select('revision')` ile satırların aldığı revizyonları döndürüyor; bunlar
damganın hemen ardından boşluksuz bir diziyse aradaki her yazma bizimdir ve
yerel zaten o haldedir → damga dizinin sonuna ilerler, sinyal gelince eşik
altında kalır. Bir boşluk = başka bir yazar (öbür cihaz, oyuncunun karakteri,
paylaşım) → damga yerinde, pull onu getirir.

**Sunucu LWW: tek migration, iki trigger.** 097 BEFORE UPDATE'e
`WHEN (NEW.updated_at < OLD.updated_at)` → satırı atla; BEFORE INSERT'e "aynı
satırın tombstone'u bu düzenlemeden yeniyse atla". Eşitlik bilerek geçiyor:
`next_package_revision` ve `claim_character` `updated_at`'e dokunmadan
güncelliyor, `<=` onları yutardı. Adlar `trg_<t>_lww_*` — aynı zamanlamada
trigger'lar ada göre koşuyor ve `lww` < `stamp_rev`, yani atlanan satır
revizyon yakmıyor, sinyal çıkmıyor.

### Yapılanlar

| Parça | Ne |
|---|---|
| **Migration 097** | A: 16 tabloya eski-düzenleme guard'ı. B: 13 dünya tablosuna tombstone guard'ı (`tg_skip_buried_insert`, SECURITY DEFINER — oyuncu kendi karakterini yazarken DM'in bıraktığı tombstone'u da görmeli). C: `tg_stamp_world_revision` / `tg_stamp_package_revision` INSERT dalında satır zaten varsa damgalamıyor — kararı UPDATE dalı veriyor; `_ins` trigger'ları PK kolonlarını argüman olarak alıyor |
| **`WorldSyncService.subscribe(onRevision:)`** | Verilirse kanala `world_revisions` binding'i; callback yeni sayacı alıyor. Resubscribe retry'ı binding'i aynı haritadan yeniden kuruyor |
| **`worldMirrorApplierProvider`** | Rol DM ise `onRevision` → `pump.onSignal`, `onSubscribed` → `pump.catchUp` |
| **`CloudPushPump`** | `_guarded`/`_pendingRound` yerine **tek şerit** (`_serial`): push ve pull sırayla, hiçbir istek düşmüyor. `catchUp` = flush → push → pull. `onSignal` 1 sn debounce (karşı cihazın turu satır başına bir sinyal üretiyor), sonra şeridin boşalmasını bekleyip sayacı yerel damgayla karşılaştırıyor |
| **`CloudPushService`** | Upsert revizyonları topluyor; `ownRunEnd(base, revs)` boşluksuz diziyi buluyor, damga **koşullu** UPDATE ile ilerliyor (`WHERE cloud_revision = base` — tur sürerken bir pull ilerlettiyse dokunmuyor). Silme olan turda ilerleme yok: tombstone'un revizyonu DELETE'ten dönmüyor |

Sinyalin yolu:

```
A: düzenle → tampon (0.75–2 sn) → 3 sn sessizlik → push
     └─ her satır sayacı artırır → Realtime → B ve A'nın kendisi
A: dönen revizyonlar boşluksuz → cloud_revision = son → kendi sinyali eşik altında
B: 1 sn sessizlik → şerit boş mu → sayaç > cloud_revision
     → flush → push (B'nin yarım düzenlemesi önce gider) → pull → reload()
```

### Faz 5b çıkış kriteri — testlerle kısmen, elle bekliyor

> **iki cihaz aynı dünyada canlı buluşuyor**

- `cloud_push_collect_test.dart` 15 → **16 test**: `ownRunEnd`'in kenarları
  (sırasız dizi, echo guard'ın eski revizyonu, ortadaki boşluk, baştaki boşluk,
  boş/eski liste). Yanlış bir ilerleme o satırı bir daha hiç indirmez — test
  bu yüzden tek fonksiyonun üstünde yoğun.
- `cloud_pull_apply_test.dart` 14/14 yeşil (pull'a dokunulmadı).
- `verify_097.sql`: eski düzenleme yeniyi ezmiyor ve revizyon yakmıyor; yeni
  düzenleme yazılıyor; eşit zaman geçiyor ve paket sayacı hâlâ ilerliyor;
  tombstone'dan eski düzenleme diriltmiyor, yenisi diriltiyor; **upsert**
  aynı gövdede sayacı yakmıyor, değişen gövdede tam bir artırıyor ve satır o
  değeri taşıyor (bileşik PK ve paket çocuğu dahil).
- **Temiz Postgres 16'da** (Supabase'in `auth`/rol iskeleti taklit edilerek)
  001→097 zinciri hatasız, `verify_094` / `096` / `097` üçü de OK; 097 iki kez
  üst üste uygulanabiliyor. `verify_094`'ün 1.5'i güncellendi: "sunucu
  `updated_at`'i ezmesin" testini **daha eski** bir zamanla yapıyordu, 097'den
  beri o yazma doğru olarak reddediliyor — niyet aynı, tarih ileri.
- Pompa (debounce, şerit, sinyal eşiği) Riverpod + Realtime'a bağlı
  yapıştırıcı; testi elle — aşağıdaki liste.

### Uygulamada çıkan farklar

| Belgede yazan | Uygulanan |
|---|---|
| §4.8 taslağı: 5b = sinyal + paket pull'u + ilk senkron UI'ı | Sinyal + uzlaştırma anı + sunucu LWW. Paket pull'u ve "bu cihaza indir" **5c**'ye ayrıldı — ikisi aynı iş (bulutta olup yerelde olmayanı ilk kez indirmek) ve sinyalden bağımsız |
| §2.3: "Realtime mesajı / saat ~1" | Sayaç **satır başına** artıyor, dolayısıyla mesaj da satır başına × abone: 200 satırlık bir tur 200 mesaj. CDC'ye göre kazanç mesaj **sayısı** değil, mesaj **boyutu** (4 kolon) ve binding sayısı (1). İstemci patlamayı 1 sn debounce ile tek pull'a indiriyor ama mesaj kotası (2M/ay) sayıyı görüyor — Faz 7'de ölçülecek |
| §2.8: "`updated_at` istemcide yazılır ve sunucuda ezilmez" yeter | Yetmiyordu: ezilmemesi yetmez, **karşılaştırılması** gerekir. 097 |
| 5a: "`syncOnOpen` rol DM'e çözülünce bir kez" | Uygulama ömründe bir kez koşuyordu (pompa kök kapsamda). Kaldırıldı, yerine kanalın her `SUBSCRIBED`'ı |
| 5a: "096'nın echo guard'ı aynı gövdenin sayacı artırmasını engelliyor" | Yalnız düz `UPDATE`'te. Upsert'in INSERT dalı çakışmadan önce sayacı yakıyordu; 097 C kapattı |

### Bilinçli sınırlar

- **Aynı saniye, farklı içerik.** Drift `updated_at` saniye hassasiyetinde. İki
  cihaz aynı satırı aynı saniyede farklı düzenlerse bulut son geleni tutar,
  ilk gelenin cihazı pull'da eşitliği "yerel kazanır" diye okur → o satır bir
  sonraki düzenlemeye kadar ayrışık kalır. Eşitlikte içerik karşılaştıran bir
  kural gerekir; ölçülmeden eklenmedi.
- **Saat kayması.** Karşılaştırma iki cihazın saatine güveniyor (§2.8'in kendi
  kabulü). Saati geri kalmış cihaz kendi yeni düzenlemesini "eski" diye
  kaybeder.
- **Tombstone zamanı sunucunun.** `deleted_at` silmenin değil push'un zamanı;
  çevrimdışı yapılıp geç gönderilen silme olduğundan yeni görünür. Belirsizlik
  silmenin lehine çözülüyor, pull da aynı karşılaştırmayı yaptığı için
  cihazlar yine **aynı** sonuca varıyor.
- **Silmeli turda yankı çekilir.** Damga ilerlemiyor, kendi satırlarımız bir
  pull'da geri iniyor (LWW hepsini atar, `reload()` koşmaz). Bedeli o turun
  egress'i.
- **Tazeleme bütün blob'u yeniden yüklüyor.** Karşı cihazın her turu açık
  dünyada bir `ActiveCampaignNotifier.reload()`. Satır bazlı tazeleme ancak
  ölçüm isterse.
- **Oyuncu sinyal almıyor.** Oyuncunun kapısı `get_shared_entities`, Faz 5.5.

### Doğrulama — yapıldı (2026-09-23)

Kullanıcı aşağıdaki listenin tamamını bildirdi: 097 deploy edildi,
`verify_097` koşturuldu, echo ölçümü yeniden yapıldı, iki cihazlı el testleri
geçti. Liste kayıt için duruyor.

**1. Migration 097'yi deploy et**, sonra `supabase/scripts/verify_097.sql` →
`097 OK`. `verify_096.sql` de yeniden `096 OK` dönmeli (097 onun yazdığı
satırlara dokunmamalı).

**2. Echo ölçümü — a3dbfad2'den sonra hiç koşturulmadı** (§4.8 adım 2).
Hiçbir şey düzenlemeden dünyayı birkaç kez aç–kapa; `world_revisions.revision`
sabit kalmalı, artıyorsa `which_bumped.sql` hangi satır olduğunu söyler.
**Sinyal açıkken bu ölçümün önemi arttı:** artan her revizyon artık öbür
cihazda bir pull + `reload()` demek; `reload()` içerik değiştiren bir yazma
tetikliyorsa iki cihaz arasında kapanmayan bir tur olur.

**3. Canlı — asıl kriter.** İki cihaz; ikincisine dünya `.dmtz` ile taşınır ve
orada "Online yap" denir (097 sayesinde ikinci cihazın ilk tam turu buluttaki
daha yeni satırları ezemez). İkisinde de aynı dünya açık: A'da kart adı
değiştir → ~5–7 sn içinde B'de görünmeli, **B'de dünyayı kapatıp açmadan.**
Sonra ters yönde. Sonra silme.

**4. Yankı.** Tek cihaz açıkken bir kart düzenle; loglarda
`CloudPullService.pullWorld` görünmemeli (kendi sinyali eşik altında kaldı).
Bir kart **sil** — bu kez bir pull görünmesi doğru (silmeli tur, sınırlar).

**5. Çevrimdışı dönüş — §2.8'in örneği.** B'nin internetini kes, B'de kartı
düzenle. A'da aynı kartı **sonra** düzenle. B'yi bağla: B'nin push'u 097'ye
takılmalı, B pull'da A'nın halini almalı; iki cihaz ve bulut A'nın halinde
buluşmalı. Aynısı silmeyle: A kartı siler, çevrimdışı B ondan önce
düzenlemişti → kart geri gelmemeli.

**6. Uzlaştırma anı.** B'de dünya açıkken uygulamayı arka plana al, A'da
düzenle, B'yi öne getir: `SUBSCRIBED` → `catchUp` değişikliği getirmeli.
Ayrıca hub'a dön ve **başka** bir DM dünyası aç — onun da açılış pull'u
koşmalı (eski `_opened` hatası).

---

## 4.8.2 Faz 5c — İkinci cihazın ilk senkronu ✅ bitti

*Bulutta olup bu cihazda olmayanı indirmek: dünya ve paket. Paket tarafı
ayrıca pull'un ve silmenin eksik yarısını aldı.*

### Sorun

5b iki cihazı canlı buluşturuyordu ama ikinci cihaza dünya **ancak `.dmtz`
ile** gelebiliyordu; paket için pull hiç yoktu. Koda bakınca paket tarafında
üç delik daha çıktı:

1. **Paket kartı silmesi bulutta iz bırakmıyordu.** Push satırı siliyordu ama
   paket tablolarında tombstone trigger'ı yoktu (dünyadakiler 094'te var) —
   öbür cihaz kartı sonsuza kadar tutardı.
2. **Buluttan silinen paket geri dirilirdi.** Push paketin kendi satırını her
   turda upsert ediyor (çocukların FK hedefi). A paketi buluttan silse ("Yerele
   al" ya da yeni kural gereği yerel silme) B'nin bir sonraki turu onu yeniden
   yaratırdı. Dünyada bu yok: `worlds` satırını yalnız `publish_world` RPC'si
   yaratıyor.
3. **Yerel silme bulutu bırakıyordu.** Dünya silinince bulut kopyası da
   siliniyordu, paket silinince değil — ve 5c'nin listesi silinen paketi
   hemen "bulutta, bu cihazda yok" diye geri gösterirdi.

### Verilen kararlar

**Kabuk en son.** Yarım inmiş bir dünya ya da paket hiçbir listede
görünmemeli: açılabilseydi varsayılan ayarlarını "şimdi" damgasıyla kaydeder,
LWW'yi kazanır ve buluttaki gerçek ayarları (şema, mind map) ezerdi. Dünyada
`worlds` satırı bütün sayfalar indikten sonra yazılıyor; pakette paketin kendi
satırı `get_package_delta`'nın son sayfasında geliyor (sayacı o taşıyor,
revizyonu hep başa eşit) ve `apply` onu sayfanın en sonunda yazıyor. Yarıda
kalan indirme ham SQL ile silinir — DAO'dan geçseydi tombstone bırakır ve
sonraki push buluttaki gerçek satırları silerdi.

**Paket silme = dünya silme.** Online paketi silmek bulut kopyasını da siler,
önce bulut: silinemezse yerel silme de iptal (dünyadaki kural). Öbür cihazın
kopyası **diriltmez**: ilk yayından sonra paketin satırı upsert değil UPDATE
ile yazılıyor; satır yoksa yerel paket offline'a düşüyor. Boş UPDATE iki şey
olabilir — satır yok ya da 097'nin LWW'si eski hâli atladı — o yüzden bir okuma
daha ayırıyor.

**Paketin uzlaştırma anı açılış.** Paketin Realtime sinyali yok; paket
açılmadan önce push → pull (en çok 8 sn beklenir, sonra yerel haliyle açılır).

### Yapılanlar

| Parça | Ne |
|---|---|
| **Migration 098** | `user_package_tombstones` + kart/şema silmesinde trigger (paket CASCADE ile siliniyorsa atlar); tombstone'dan eski düzenleme silinmiş kartı diriltmez; `get_package_delta` — `get_world_delta`'nın eşi, paketin satırı yalnız son sayfada |
| **`CloudPullService`** | Sayfa döngüsü dünya/paket ortak (`_pullFrom`), `apply(package:)`. Yeni: `listCloudOnlyWorlds` / `downloadWorld`, `pullPackage` / `listCloudOnlyPackages` / `downloadPackage`. İndirme push damgasını başlangıcına çekiyor: inen satırlar ilk açılışta buluta geri gitmez |
| **`CloudPushService.pushPackage`** | İlk yayından sonra paketin satırı yalnız güncelleniyor; bulutta yoksa `setOnline(false)` |
| **Paket silme** | `ActivePackageNotifier.delete` online paketi önce buluttan siliyor; hata hub'da snackbar |
| **Hub** | Dünyalar ve Paketler sekmelerinde ortak `CloudOnlySection`: bulutta olup burada olmayanlar, satır başına "İndir" + ilerleme çubuğu; tek seferde tek indirme. Paket açılışı `CloudPushPump.syncPackage` |
| **l10n** | 7 anahtar × 4 dil (`cloudOnly*`, `cloudPackageNameTaken`) |

### Faz 5c çıkış kriteri — testlerle karşılandı, elle bekliyor

> **ikinci cihaz dünyayı/paketi zip'siz alıyor**

- `cloud_download_test.dart` **9 test**, ağ yerine yerel bir sahte PostgREST
  (`test/support/fake_postgrest.dart`, yeni bağımlılık yok) — RPC, select ve
  update yolları gerçekten koşuyor: iki sayfalık dünya indirmesinde ikinci
  sayfa istenirken ilk sayfa yerelde ama kabuk **yok**; kabuğun damgaları;
  yarıda kalan indirme satır ve tombstone bırakmıyor; görünmeyen dünya boş
  kabuk yaratmıyor; liste yerelde olanı ve aynası boş olanı elemiş; paket
  indirmesi; aynı adlı yerel paket varsa ağa hiç çıkılmıyor; paket pull'unda
  tombstone yerelde siliyor ve buluta geri gitmiyor; buluttan silinmiş paketi
  push diriltmiyor (POST yok, yalnız PATCH + GET) ve paket offline'a düşüyor;
  LWW'nin atladığı güncelleme silme sanılmıyor.
- `verify_098.sql` temiz Postgres 16'da `098 OK` (001→098 zinciri hatasız,
  098 idempotent, `verify_094/096/097` hâlâ yeşil).
- Tam `flutter test` **1575 yeşil / 1 kırmızı** (bilinen
  `bundled_pack_resolve_test`), `flutter analyze` yeni bulgu yok.

### Uygulamada çıkan farklar

| Belgede yazan | Uygulanan |
|---|---|
| 5c taslağı: "yerel kabuk + `pull(full: true)`" | Kabuk önce yazılsaydı yarım dünya açılabilir ve buluttaki ayarları ezebilirdi. Kabuk **en son**; `pullWorld` değil, kabuk istemeyen ortak döngü |
| §4.7: "paketin silinmesi buluta gitmiyor" (bilinçli sınır) | Artık gidiyor — dünyadaki kuralla aynı. Sınırın asıl tehlikesi buluta gitmemesi değil, **öbür cihazın diriltmesiydi**; o da kapandı |
| 094: tombstone "ayna tablolarında" | Yalnız dünya tablolarındaydı; paket çocukları silmeyi hiç yaymıyordu. 098 |

### Bilinçli sınırlar

- ~~**Görseller DM'in öbür cihazı açıkken gelir.**~~ **Yanlıştı — görseller
  hiç gelmiyor** (el testinde çıktı, 2026-09-23). İnen satırlar
  `dmt-content://` taşıyor ama talep-üzerine medya yalnız oyuncu için
  kurulu: `MissingMediaReporter` yalnız paylaşım olaylarında süpürüyor ve DM
  tarafı `missing_shas` olayını aynı uid'den gelince "kendim" sayıp
  (`isSelf`) yüklemiyor. §2.7'nin tablosu DM'in ikinci cihazını hiç
  düşünmemiş ("DM → `content_paths`'ten yerel dosya"). Karar bekliyor.
- **Paket canlı değil.** Açılışta uzlaşıyor; açıkken öbür cihazın düzenlemesi
  bir sonraki açılışta gelir. 8 sn'yi aşan pull arka planda biter, satırları
  yine Drift'e yazar ama açık paket onları görmez.
- **Aynı adlı paket indirilemez.** Yerelde paket adı UNIQUE; kullanıcıdan
  yerel olanı yeniden adlandırması isteniyor. Otomatik "(2)" eklemek adı
  buluta da yayardı.
- **Buluttan silinen dünya öbür cihazda online görünmeye devam eder.** Rol
  `none`'a düştüğü için push/pull koşmaz, zarar yok; bayrak yalnız temizlenmiyor.
- **Paketin kendisinin silinmesinin tombstone'u yok.** Öbür cihaz bunu yalnız
  o paketi düzenleyip push ettiğinde öğreniyor.

### Bekleyen doğrulama

**1. Migration 098'i deploy et**, sonra `supabase/scripts/verify_098.sql` →
`098 OK`.

**2. Dünya indirme.** B'de A'nın online dünyası yoksa (sil ya da temiz kurulum)
hub → Dünyalar → "Bulutta, bu cihazda yok" → İndir. İlerleme çubuğu dolmalı,
dünya listeye düşmeli; açınca kartlar, harita, oturumlar, mind map, savaş
orada. Açılışta push loglarında **satır gitmemeli** (damga indirmenin başı).

> **Yapıldı (2026-09-23), görseller hariç.** İçerik indi; görseller gelmedi
> (bilinçli sınırlarda, karar bekliyor). Aynı testte A'da mevcut kartın
> düzenlemesi B'ye hiç ulaşmadı, silmeler ulaştı — kök neden Faz 4a'dan
> kalan damga hatası (§4.9). Düzeltmeden sonra kart düzenlemesi ve harita
> pini canlı geldi. Teşhis için `CloudSync:` log satırları eklendi (rol,
> `catchUp`, sinyal, push `↑✕`, pull `+-`); iki cihazlı testte
> `grep CloudSync` zincirin nerede koptuğunu gösteriyor.

**3. Paket indirme + pull.** Aynısı Paketler sekmesinde. Sonra A'da bir kartı
düzenle ve bir kartı sil; B'de paketi aç: ikisi de yansımalı.

**4. Silme.** A'da online paketi sil: bulutta satır gitmeli
(`select * from user_packages where id = '<id>'` boş). B'de o paketi aç,
bir kartı düzenle → B'nin paketi **offline**'a düşmeli, bulutta yeniden
belirmemeli.

**5. Yarıda kalan indirme.** İndirme sürerken ağı kes: dünya/paket listede
**görünmemeli**; ağ gelince yeniden indirilebilmeli.

---

## 4.8.3 Faz 5.5 ve sonrası — taslak

*Aşağısı henüz detaylandırılmadı. Bir faz başlarken, koda bakılarak aynı
ayrıntıda açılıyor (bkz. §4.4–§4.8.2).*

### Faz 5.5 — Oyuncu çoklu cihaz
`joinWithCode` → `redeemInvite` + `materializeWorld`; "Online dünyalarım"
ekranı; "benim karakterim" bulma; oyuncu mind map'i; `world_member_state`;
izinli kartların RPC'den çekilmesi; paylaşım geri çekilince gri kart + etiket.

### Faz 6 — LAN'ı sil
`lan_sync/` 6 dosya (2.733 satır), provider + dialog, **41 l10n anahtarı ×
4 dil ≈ 164 satır**, 3 test dosyası; 9 dosyada referans temizliği;
audit §2 bulgusunu kapalı işaretle.

### Faz 7 — Kural, kota, ölçüm
"Online olmayan dünya multiplayer olamaz"; kota göstergesi gerçek sayılarla;
admin panelinde Postgres doluluğu; **ölçüm**: gerçek dünya boyutu, delta
trafiği, egress, transient doluluk, **Realtime mesaj sayısı** (sinyal satır
başına — §4.8.1; kota zorlarsa sayaç işlem başına bir kez artırılır, ama o
zaman `get_world_delta`'nın kırpması aynı revizyonlu satırları bölmemeli).

### Faz 8 — Sonraya bırakılanlar
Değişmedi — bkz. eski liste.

### Faz 9 — İşlem geri bildirimi (en son)

*Kullanıcının isteği (2026-09-23): "bir işlem yapılırken kullanıcıya
belirtilmiyor." Bu bölüm analiz; uygulama en son, çünkü Faz 6 (LAN) ve Faz 7
(kota göstergesi) gösterilecek şeyin kendisini değiştiriyor.*

**Sorun.** Senkron artık arka planda ve sürekli: düzenlemeden 3 sn sonra
push, açılışta ve sinyalde pull, görüntülenirken görsel indirme. Hiçbiri
görünmüyor. Kullanıcı ne verinin bulutta olup olmadığını, ne öbür cihazın
değişikliğinin yolda olduğunu, ne de bir şeyin **başarısız** olduğunu
biliyor — başarısızlık yalnız `debugPrint`. 5c el testinde bu doğrudan
maliyet oldu: "hiçbir şey gelmedi" raporunun arkasındaki sebebi ayırmanın tek
yolu log satırı eklemekti (`CloudSync:`).

**Envanter** (koddan, 2026-09-23):

| İşlem | Nerede | Bugün kullanıcı ne görüyor |
|---|---|---|
| Bulut push turu | `CloudPushPump._round` | **Hiçbir şey.** `SaveSyncIndicator` yalnız yerel kaydı anlatıyor ("Auto-saving…" / "Saved"); çevrimdışı birikme, reddedilen satır, kota hatası görünmüyor |
| Bulut pull (açılış `catchUp`, sinyal) | `CloudPushPump.pull` | **Hiçbir şey.** Önce bayat hal görünüyor, `reload()` sonrası kartlar birden değişiyor |
| "Online yap" tam push | `_MakeOnlineButton` | Düğme etiketi "Yayımlanıyor..." — ilerleme yok, büyük dünyada uzun |
| Dünya/paket indirme (5c) | `CloudOnlySection` | ✅ satırda ilerleme çubuğu |
| Paket açılışı `syncPackage` (≤ 8 sn) | `packages_tab` | Genel overlay "Opening package…" — senkronu söylemiyor; zaman aşımında sessizce yerel halle açılıyor |
| Görsel çözümü | `AssetRefImage` | Çözülürken spinner ✅; bulunamazsa `broken_image` — **nedeni yok** (DM'den bekleniyor mu, hiç gelmeyecek mi) |
| Oyuncunun eksik görsel beklemesi | `MissingMediaReporter` | Hiçbir şey — 15 sn'lik yeniden deneme döngüsü görünmüyor |
| Push'ta medya yükleme | `SharedMediaCourier` | Hiçbir şey |
| `.dmtz` dışa/içe aktarma | `content_archive_menu` | Dosya seçimiyle son snackbar arası **hiçbir şey**; medyalı büyük dünyada saniyeler sürüyor |
| Resmi katalog kurulumu | `first_party_catalog_provider` | ✅ kalem başına "done / total" |
| Misafirden hesaba geçiş | `GuestPromotionService` | Hiçbir şey — veri birleştiriliyor ama kullanıcıya söylenmiyor |
| Oyuncuya paylaşım push'u | `EntityNotifier._pushIfShared` | Hiçbir şey; hata yalnız log (kuyruk / yeniden deneme yok) |
| LAN senkronu | `lan_sync_dialog` | ✅ kendi diyaloğu — Faz 6'da zaten gidiyor |

**Var olan altyapı:**
- `globalLoadingProvider` + `GlobalLoadingOverlay` — **tam ekran, girişi
  kilitleyen** modal; ilerleme destekli, 13 çağrı yeri. Kullanıcının başlattığı
  ve sonraki adımı bekleyen iş için doğru (dünya açma, paket yaratma); arka
  plan senkronu için **yanlış** — her 3 sn'de ekranı kilitlerdi. Mesajları
  koda gömülü İngilizce (`'Opening package "$name"...'`), l10n kuralının dışında.
- `SaveSyncIndicator` — araç çubuğundaki simge; bulut durumunun doğal evi.
- `CloudBackupButton` (`cloud_sync_button.dart`) — boşta / meşgul / bitti /
  hata durum makinesi hazır, **hiçbir yerde kullanılmıyor**.
- `CloudSync:` log noktaları — durum geçişlerinin tam yerleri; göstergenin
  besleneceği yerler aynı.

**Taslak.**
1. **Tek kural:** kullanıcının başlattığı ve beklediği iş → mevcut overlay;
   arka plan işi → engellemeyen gösterge, asla overlay; **hata → kalıcı ve
   görünür durum**, log değil.
2. **Tek model:** arka plan işlerini tutan bir provider (`id`, tür, etiket,
   ilerleme?, hata?). Üreticiler pompa (push/pull), görsel çözücü, arşiv
   aktarımı, misafir geçişi. Yeni bir servis katmanı değil — `globalLoading`'in
   engellemeyen eşi.
3. **Tüketiciler:** `SaveSyncIndicator` simgesi dört hal (eşitlendi ·
   eşitleniyor · çevrimdışı bekliyor · hata N) ve Save & Sync diyaloğunda
   kısa bir etkinlik listesi; `AssetRefImage`'ın hata hali nedenini söyler
   ("DM'den bekleniyor" / "bu cihazda yok").
4. Overlay mesajları l10n'a taşınır.

**Çıkış kriteri:** ağa çıkan ve ~1 sn'yi aşabilen ya da başarısız olabilen her
iş görünür bir hal taşıyor; senkron hatası log açmadan görülüyor; çevrimdışı
düzenleme "bekliyor" diye işaretli.

**Karar bekleyen bağlantı:** DM'in ikinci cihazına görsel gelmemesi (§4.8.2
bilinçli sınırlar) çözülmeden görselin "bekleniyor" hali yalan söyler —
bekleyen bir şey yok. Faz 9'dan önce karara bağlanmalı.

---

## 4.9 Kod incelemesinden çıkan düzeltmeler

Bu roadmap hazırlanırken kod okundu ve belgenin birkaç yeri gerçekle
uyuşmuyordu. Kayda geçiyor:

| Belgede yazan | Kodda olan |
|---|---|
| Faz 2: "`isOnline` bayrağı UI'ı" yeni iş | Dünya için **var** — `save_sync_indicator.dart:437` `_makeOnline` → `publishWorld` RPC, satır 566 `unpublishWorld` |
| Faz 1/6: "mevcut JSON paket export'unu zip'e taşı" | `export_package_dialog.dart` dosyaya yazmıyor; dünyadan uygulama içi paket kuruyor (`repo.save`, satır 235). Uygulamada hiç `saveFile` çağrısı yok |
| Faz 6: "68 l10n anahtarı × 4 dil = 272 satır" | Gerçek LAN anahtarı **41** (`lanSync*`). 68 sayısı `landing*` anahtarlarını da sayıyor. ≈164 satır |
| Faz 0: v13 bump şimdi yapılmalı | Bump'ın taşıyacağı her kalem Faz 4+ doğuyor; Faz 0'da yapmak tahmin demek (§4.0) |
| Faz 0: limitleri "bugünkü saatlik sayılarla eşleştir" | Platform limiter'da `period` yalnızca 10 veya 60 — saatlik pencere ifade edilemiyor, sayılar dakikalığa çevrildi (§4.1) |
| Faz 0: 429'da `X-RateLimit-Remaining` sadeleşir | Böyle bir başlık hiç yoktu; `rateLimitedResponse` yalnızca `Retry-After` + `X-RateLimit-Limit` yazıyor ve Flutter istemcisi ikisini de okumuyor — 429 gövdesi tamamen bilgilendirme amaçlı |
| Faz 1: zip'e `stamps.json` da yazılacak | `extras.section_stamps` zaten aynı veriyi taşıyor ve `applyItem` oradan okuyor — ayrı dosya çift yazım olurdu |
| Faz 1: id çakışmasında "kopya oluştur" seçeneği | Yapılamaz: `world_entities` PK'sı global `{id}` ve DAO `insertAllOnConflictUpdate` kullanıyor — yeni id'li kopya, var olan dünyanın entity satırlarını kendine çeker. **Aynı hata `WorldRepositoryImpl.copy`'de bugün de var**; probe testiyle doğrulandı (1 kartlı kaynak → kaynak 0 / kopya 1) ve `docs/KNOWN_ISSUES.md`'e alındı. Ayrı iş |
| Faz 2.5: çıkış kriteri "aynı isimle iki dünya" | Tek başına repository katmanı yetmiyordu: medya klasörü de isimle anahtarlıydı (`worlds/<ad>/media/`), yani aynı adlı iki dünya aynı klasörü paylaşır ve `UnusedMediaSweeper` birini açıp kapatınca ötekinin dosyalarını silerdi. Klasör de id'ye taşındı; `beforeOpen`'da tek seferlik `world_media_dir_by_id_v1` geçişi |
| Faz 2.5: "`renameWorld` tek satır UPDATE'e iner" | Doğru çıktı ama gerekçesi eksikti: rename **bugün klasörü taşıyıp gövdedeki mutlak yolları bırakıyordu**, yani yeniden adlandırılan her dünyanın resimleri kırılıyordu. Klasör id'ye geçince taşıma tamamen kalktı ve hata da kalktı |
| Faz 2.5: `activeCampaignProvider` yalnız dünya adı tutar | Paket ekranı bu provider'ı kendi `ProviderScope`'unda **paket adıyla** override ediyor (`package_screen.dart:112`). Değer "açık içeriğin anahtarı" — dünyada id, pakette paket adı |
| §2.7: "DM `asset_refs`'ten sha → yerel dosya" | `asset_refs` ham yol tutmuyor ve tutmamalı (false-orphan). `content_paths` yan tablosu açıldı (§4.5) |
| §2.2: "Toplam ~26 tablo" | 25. `world_combat_conditions` tablo olmadı — `world_combatants.conditions_json` kolonu oldu (§4.4) |
| §2.11: `sync_outbox` "geri gelmeli" | Gelmedi: Faz 4a push'u kuyruk tutmuyor, watermark tarıyor (§4.6). `_retiredTablesDDL`'deki `DROP` satırı **kalıyor** |
| §4.0: v13 bump'ı her kullanıcının DB'sini sıfırlar | Sıfırlamıyor — legacy kesimi `user_version < 12`'ye bakıyor, v12 dosyası `onUpgrade(12→13)`'e düşüyor. Bedel sıfırlama değil, gerçek bir geçiş adımı yazmak oldu (§4.6) |

| §2.3: revizyon trigger'ı yeterli | **Değildi.** 094'ün `trg_*_stamp_rev`'i şartsız `BEFORE INSERT OR UPDATE`; aynı gövdenin yeniden yazılması da sayacı artırıyor. Push tek yönlüyken yalnız israf (`user_packages` her tur), pull açılınca iki cihaz arasında kapanmayan tur. 096 `WHEN (OLD.* IS DISTINCT FROM NEW.*)` ile kapattı (§4.8) |
| Faz 5: "applier'ın tablo başına ayrı handler olarak yeniden yazımı" | Gerekmedi: `world_mirror_applier` paylaşım yayınının tüketicisi, ayna pull'unun değil. Pull'un dönüşümleri `cloud_mirror_tables.dart` bildiriminden geliyor; elle yazılan tek özel durum combatant (§4.8) |
| §2.3: `get_world_delta(world_id, since_revision)` | Üçüncü parametre `limit` + yanıtta `complete`. Belgenin kendi "ilk açılış ~10 MB" satırı kırpmayı zorunlu kılıyor; kırpmasız tek jsonb telefonda bellek sorunu (§4.8) |
| Faz 5b: açık dünyayı tazelemek için "revizyon bump" yeter | Yetmez — `campaignRevisionProvider` bump'ı aynı bayat blob'u yeniden okutur. Blob'un **depodan** yeniden yüklenmesi gerekiyor; `ActiveCampaignNotifier.reload()` zaten ikisini birden yapıyordu. İş 5a'ya çekildi (§4.8) |
| §2.8: istemcide yazılan, sunucuda ezilmeyen `updated_at` yeter | Yetmez — sunucu **karşılaştırmıyordu**, varış sırası kazanıyordu ve sonuç kayıp değil kalıcı ayrışmaydı. Silmede de eski düzenleme kartı diriltiyordu. 097 (§4.8.1) |
| §2.3: sinyal modelinde "Realtime mesajı / saat ~1" | Sayaç satır başına artıyor → mesaj satır başına × abone. Kazanç mesaj boyutu ve binding sayısında, sayıda değil. Faz 7'de ölçülecek (§4.8.1) |
| 5a: "`syncOnOpen` dünya açılışında bir kez" | Pompa kök kapsamda yaşadığı için **uygulama ömründe** bir kez koşuyordu. Kanalın `SUBSCRIBED`'ına taşındı (§4.8.1) |
| 096: echo guard aynı gövdenin sayacı artırmasını engelliyor | Upsert'te engellemiyordu — BEFORE INSERT trigger'ı çakışmadan önce koşuyor ve sayacı yakıyordu; değişen gövde iki revizyon (biri ölü). `verify_096` düz UPDATE ile test ediyordu. 097 C (§4.8.1) |
| §4.7: paketin silinmesi buluta gitmiyor, bulut kopyasını yalnız "Yerele al" düşürüyor | Yerel silme dünyada bulutu da siliyordu, pakette silmiyordu; üstelik push paketin satırını her turda upsert ettiği için buluttan silinen paketi öbür cihaz **diriltiyordu**. 5c: silme buluta gidiyor, ilk yayından sonra paketin satırı yalnız UPDATE (§4.8.2) |
| 094: silmeler tombstone ile yayılır | Yalnız dünya tablolarında. Paket kartının silmesi öbür cihaza hiç ulaşmıyordu; 098 (§4.8.2) |
| Faz 4a: DAO upsert'leri `stampedNow` ile damgalanıyor | `world_entities` hariç — 4a damgayı yeni kolon alan tablolara ekledi, eskiden beri `updated_at`'i olan kart tablosu atlandı. ON CONFLICT eski damgayı bırakıyordu: **var olan kartın düzenlemesi buluta hiç çıkmıyordu**, yalnız yeni kartlar ve silmeler gidiyordu. 5c el testinde çıktı (2026-09-23); DAO damgalıyor, `saveEntity` aynı içeriği yazmıyor (yankı) |

Değişmeyen tek şey `lan_sync/` boyutu: **2.733 satır**, belgedeki sayı doğru.

---

## Üç kırmızı nokta

1. **RLS gizlilik hatası** — sır artık sunucuya çıkıyor. Tek RPC kapısı +
   `dm_only_keys` + rol bazlı testler.
2. **Medya ref'lerinin taşınabilirliği** — çözülmemiş tasarım işi,
   push'tan önce bitmeli.
3. **KV rate limiter** — şu an bile sınırda, online açılmadan
   düzeltilmeli.

## Doğrulanmamış tek veri

Gerçek dünya payload boyutu (MB) ölçülmedi. Şüpheli ağır bölümler: battle
map fog verisi (base64), çizim stroke'ları, harita görselleri. Faz 7'de
ölçülecek; kota sayıları (500 MB / 20.000 satır / 256 KB) ve "~250
kullanıcı" tahmini bu ölçüme göre ayarlanır.
