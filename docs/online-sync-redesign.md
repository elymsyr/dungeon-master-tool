# Online Senkronizasyon Yeniden Tasarımı — "tam online geri dönüyor, LAN kalkıyor"

Durum: **uygulama başladı** — dal `online-again`, Faz 0 ve Faz 1 bitti, Faz 2.5
detaylı (bkz. [BÖLÜM 4](#bölüm-4--roadmap)), Faz 3+ taslak.

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
> fark [§4.5](#45-kod-incelemesinden-çıkan-düzeltmeler) tablosuna yazılır.
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
| DM | `asset_refs` tablosundan sha -> yerel dosya |
| Oyuncu | transient'ten indir; bulamazsa `missing_shas`'e yaz |

Vault'taki endişe de çözülüyor: ref tier belirtmediği için transient
LRU'su DM'i etkilemiyor — DM'in çözüm yolu yerel. `asset_refs`
(sha <-> yol eşlemesi) `app_database.dart`'ta zaten var.

**Bu çözülmüş değil, tasarım işi** (Faz 3.5). Yoksa link modeli "kartlar
geliyor, resimler gelmiyor" olarak çıkar.

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
2. **`dmt-content://` ref birleştirmesi** (§2.7) — worker tarafında sha
   çözümü.
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
| ~~**0**~~ | KV rate limiter'ı platform binding'ine taşı | istek yolunda `kv.put` yok | worker | ✅ bitti (deploy bekliyor) |
| ~~**1**~~ | ZIP import/export + codec'in LAN'dan çıkarılması | dünya export → temiz kurulumda import → aynı dünya | hayır | ✅ bitti |
| **2.5** | Dünya kimliğinin isimden id'ye taşınması | `CampaignRepository` ismi anahtar olarak kullanmıyor | hayır | detaylı |
| 3 | Bulut şeması + RLS | RLS testleri yeşil, istemci hâlâ kullanmıyor | evet | taslak |
| 3.5 | `dmt-content://` medya ref birleştirmesi | ref cihazdan bağımsız çözülüyor | evet | taslak |
| 4 | Drift v13 bump + push | dünya bulutta görünüyor, geri okuma yok | evet | taslak |
| 5 | Pull + uzlaştırıcı | iki cihaz aynı dünyada buluşuyor | evet | taslak |
| 5.5 | Oyuncu çoklu cihaz | oyuncu ikinci cihazdan karakterine ulaşıyor | evet | taslak |
| 6 | LAN'ı sil | `lan_sync/` yok, analyze temiz | hayır | taslak |
| 7 | Kural, kota, ölçüm | gerçek sayılar ölçüldü | evet | taslak |
| 8 | Sonraya bırakılanlar | — | — | açık |

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

**Durum:** uygulandı. `rate_limit.ts` silindi, üç limiter de platform
binding'i (`CATALOG_RL` / `DL_RL` / `UL_RL`). `npm run typecheck` ve
`wrangler deploy --dry-run` temiz. **Deploy edilmedi** — `wrangler deploy`
kullanıcının kararı.

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
`flutter analyze` temiz (0 error/warning), `content_archive_test.dart` ve
taşınan iki test yeşil.

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

Giriş noktaları: hub dünya kartı menüsü, paket listesi, karakter düzenleyici.
Üçü de aynı servisi çağırır, tip parametresi değişir.

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
(bkz. §4.5) — önce o düzeltilmeli.

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

## 4.3 Faz 2.5 — Dünya kimliği: isimden id'ye

*Borç ödemesi. Faz 4 push'undan önce şart (§2.10, §3.2 Kural 2).*

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

### Çıkış kriteri

- `CampaignRepository` arayüzünde `campaignName` parametresi kalmadı
- Aynı isimle iki dünya oluşturulabiliyor, ikisi de doğru açılıyor
- Bir dünya yeniden adlandırıldıktan sonra medya klasörü, kurulu paketleri ve
  oturumları bozulmadan duruyor (yeniden adlandırma bugün klasör de taşıyor —
  `_applyWorld` içindeki `oldDir.rename` yolu)
- `flutter test test/data/` ve dünya ile ilgili dosyalar yeşil

### Neden v13 bump'ı burada değil

Bu fazın yeni kolona ihtiyacı yok; `worlds.id` zaten birincil anahtar. Bump
Faz 4'ün başında, gerçekten kolon gerektiğinde (bkz. §4.0).

---

## 4.4 Faz 3 ve sonrası — taslak

*Aşağısı henüz detaylandırılmadı. Faz 1 bitince, koda bakılarak Faz 3 aynı
ayrıntıda açılacak.*

### Faz 3 — Bulut şeması
Migration 094+: 077'den geri gelen 6 tablo + hiç olmamış 6 tablo + 3 paket
tablosu; `world_revisions`, `world_tombstones`, `world_member_state`;
`entity_shares` → izin tablosu (`payload_json` düşer);
`world_entities.dm_only_keys`; `get_shared_entities` RPC + SQL redaksiyonu;
mind map `owner_id` + RLS; `tg_bump_parent_world` geri; kota
fonksiyonları; Realtime yayını **sadece** `world_revisions`;
**her tablo için oyuncu rolüyle RLS testi.**

### Faz 3.5 — Medya ref birleştirmesi
`dmt-content://{sha}{ext}` tanımı; DM push'unda yol→sha; `asset_refs`
üzerinden DM tarafı çözümü; oyuncu tarafı transient + `missing_shas`; eski
ref biçimleriyle uyumluluk.

### Faz 4 — Drift v13 + push
Tek v13 bump (`isOnline`, `sync_outbox`, `revision`/`updated_at`,
`lan_paired_devices` düşürülmesi); push katmanı
`PendingWriteBuffer → sync_outbox → bulut`; echo bastırma; revizyon artırma;
**düzenleme zamanı kuralı** (§2.8); kota reddi yerel yazmayı durdurmaz.
Eski Faz 2'nin online anahtarı (paket + karakter) burada, `_makeOnline`
genelleştirilerek.

### Faz 5 — Pull
Uzlaştırıcı; applier'ın tablo başına ayrı handler olarak yeniden yazımı;
tombstone + zaman karşılaştırması; ilk senkron akışı ve ilerleme UI'ı.

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
trafiği, egress, transient doluluk.

### Faz 8 — Sonraya bırakılanlar
Değişmedi — bkz. eski liste.

---

## 4.5 Kod incelemesinden çıkan düzeltmeler

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
| Faz 1: id çakışmasında "kopya oluştur" seçeneği | Yapılamaz: `world_entities` PK'sı global `{id}` ve DAO `insertAllOnConflictUpdate` kullanıyor — yeni id'li kopya, var olan dünyanın entity satırlarını kendine çeker. **Aynı hata `WorldRepositoryImpl.copy`'de bugün de var** (`world_repository_impl.dart:405`); ayrı iş |
| §2.11: `sync_outbox` "geri gelmeli" | `app_database.dart:430` `_retiredTablesDDL` onu aktif `DROP` ediyor — o satırın kalkması Faz 4'ün parçası |

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
