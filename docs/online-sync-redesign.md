# Online Senkronizasyon Yeniden Tasarımı — "tam online geri dönüyor, LAN kalkıyor"

Durum: **karar aşaması tamamlandı, uygulama başlamadı.**

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

## Faz 0 — Ön koşullar
*Bağımsız, hemen yapılabilir, hiçbir şeyi bozmaz*

1. **KV rate limiter düzeltmesi** -> `[[ratelimits]]` binding'i veya Durable Object
2. **Drift v13 bump** — tek seferde: `isOnline` kolonları, `sync_outbox`,
   `revision`/`updated_at`, `lan_paired_devices` kaldırılması
   - Kullanıcı yokken yapılmalı, pencere geçici

## Faz 1 — ZIP import/export
*Sunucuya hiç dokunmuyor, tek başına değerli*

3. Paketleme codec'ini `lan_sync/` içinden çıkar, bağımsız servise taşı
4. Dünya / paket / karakter -> zip export
5. Zip import + çakışma davranışı (üzerine yaz / kopya oluştur)
6. Mevcut JSON paket export'unu (`export_package_dialog.dart`) zip'e taşı

**Çıktı:** kullanıcı hesapsız yedek alabiliyor, DM oyuncuya dünya
verebiliyor. LAN'ın yerini dolduran birinci ayak hazır.

## Faz 2 — "Online yapma" iskeleti
*Hâlâ tamamen yerel*

7. `isOnline` bayrağı UI'ı — dünya/paket/karakter
8. "Online'a al" / "Online'dan çıkar" akışı + onay ekranları
9. Kota göstergesi iskeleti (sayılar henüz 0)

## Faz 2.5 — Dünya kimliği temizliği
*Borç ödemesi, senkrondan önce şart*

10. `CampaignRepository`'nin isim yerine `id` ile anahtarlanması
11. `joinWithCode`'daki isim-çakışma suffix'inin kaldırılması
12. `worldName`'in salt etiket haline gelmesi

## Faz 3 — Bulut şeması
*Supabase tarafı, istemci henüz kullanmıyor*

13. Migration: 6 geri + 6 yeni + 3 paket tablosu
14. `world_revisions` + `world_tombstones`
15. `entity_shares` -> izin tablosu (`payload_json` düşer)
16. `world_entities.dm_only_keys` kolonu
17. `get_shared_entities` RPC + SQL redaksiyonu
18. Mind map `owner_id` + RLS
19. `world_member_state`
20. `tg_bump_parent_world` geri
21. Kota fonksiyonları + trigger'ları
22. Realtime yayını: **sadece** `world_revisions`
23. **RLS testleri** — her tablo, oyuncu rolüyle

## Faz 3.5 — Medya ref birleştirmesi
*Push'tan önce olmak zorunda*

24. `dmt-content://{sha}{ext}` şemasının tanımı
25. DM push'unda yolların sha'ya çevrilmesi
26. `asset_refs` üzerinden DM tarafı çözümü
27. Oyuncu tarafı: transient + `missing_shas` akışının bağlanması
28. Eski ref biçimleriyle uyumluluk

## Faz 4 — Push
*Yerelden buluta tek yön*

29. Push katmanı — `PendingWriteBuffer` -> `sync_outbox` -> bulut
30. Echo bastırma (mevcut 3 sn penceresi genişletilir)
31. Revizyon artırma
32. **Düzenleme zamanı kuralı** — istemci yazar, sunucu `now()` ile ezmez (§2.8)
33. Kota reddini düzgün karşıla — yerel yazma durmaz

**Çıktı:** dünya bulutta görünüyor. Geri okuma yok -> veri kaybı riski yok.

## Faz 5 — Pull
*İki yön tamamlanıyor — projenin asıl hedefi*

34. Uzlaştırıcı — açılışta delta çekme
35. Applier'ı tablo bazında genişlet (ayrı handler'lar)
36. Tombstone uygulaması + zaman karşılaştırması
37. İlk senkron akışı (yeni cihazda sıfırdan indirme + ilerleme UI'ı)

## Faz 5.5 — Oyuncu çoklu cihaz
*Faz 5'ten önce de yapılabilir — değeri yüksek, maliyeti düşük*

38. `joinWithCode` -> `redeemInvite` + `materializeWorld`
39. "Online dünyalarım" ekranı + "bu cihaza indir"
40. "Benim karakterim" bulma akışı
41. Oyuncu mind map senkronu
42. `world_member_state` senkronu
43. İzinli kartların RPC'den çekilmesi
44. Paylaşım geri çekildiğinde UI (gri + etiket)

> `applyInitialState` makinesi hazır olduğu için bu faz DM pull'una
> bağımlı değil. Erken değer istersen buraya bakılabilir.

## Faz 6 — LAN'ı sil
*Artık yetim*

45. 6 dosya + provider + dialog + 272 l10n satırı + 3 test
46. 9 dosyada yorum/referans temizliği
47. Audit §2 güvenlik bulgusunu kapalı işaretle

## Faz 7 — Kural, kota, ölçüm

48. "Online olmayan dünya multiplayer olamaz" kuralını açıkça uygula
49. Kota göstergesini gerçek sayılarla doldur
50. Admin panelinde Postgres doluluk görünürlüğü
51. **Ölç:** gerçek dünya boyutu, delta trafiği, egress, transient doluluk

## Faz 8 — Sonraya bırakılanlar
*Kararları Faz 7 ölçümüne bağlı*

- Oyuncuya inen içeriğin granülerliği
- Medyanın önden yüklenmesi — Phase C takasının yeniden değerlendirilmesi
- Oyuncunun paylaşılan karta kendi notunu eklemesi
  (`world_member_state` taşıyabilir)
- Snapshot/zip'in buluta yedek olarak konması (egress duvarına yaklaşılırsa)
- Şifreleme politikası

## Faz özeti

| Faz | Ne | Bulut gerekiyor |
|---|---|---|
| 0 | Ön koşullar + şema bump | hayır |
| 1 | ZIP import/export | hayır |
| 2 | Online bayrağı UI | hayır |
| 2.5 | Dünya kimliği | hayır |
| 3 | Bulut şeması + RLS | evet |
| 3.5 | Medya ref | evet |
| 4 | Push | evet |
| 5 | Pull | evet |
| 5.5 | Oyuncu çoklu cihaz | evet |
| 6 | LAN silme | hayır |
| 7 | Kural + kota + ölçüm | evet |

**İlk dört faz bulut olmadan tamamlanıyor.** Bir şey ters giderse geri
dönüş kolay ve kullanıcıya hiçbir şey kaybettirmiyor.

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
