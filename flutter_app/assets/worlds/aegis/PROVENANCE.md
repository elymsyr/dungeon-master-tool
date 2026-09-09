# PROVENANCE — Aegis / `aegis-act1`

README §4.2 kural 3'ün karşılığı: **her entity'nin izi sürülebilir olmalı.**
Aegis'te aktarılacak bitmiş bir kitap olmadığı için `audit_coverage.py` kapsam
denetiminin yerini bu dosya tutar.

Kaynak kısaltmaları:

| Kısaltma | Dosya |
|---|---|
| `act1` | [lore/canon/act1.md](lore/canon/act1.md) |
| `kart1` | [lore/canon/act1-kartlar.md](lore/canon/act1-kartlar.md) |
| `kartG` | [lore/canon/genel-kartlar.md](lore/canon/genel-kartlar.md) |
| `lonca` | [lore/canon/lonca-sehir.md](lore/canon/lonca-sehir.md) |
| `bolge` | [lore/canon/bolgeler.md](lore/canon/bolgeler.md) |
| `mek` | [lore/canon/mekanikler.md](lore/canon/mekanikler.md) |
| `RM` | [README.md](README.md) (bu dizin) |
| `AE` · `YT` | `lore/archive/AETHELGARD- İRADENİN SON ADASI.pdf` · `lore/archive/YAKIN TARİH VE OYUN MEKANİKLERİ 1.pdf` — **PDF, hiyerarşinin en altı.** Bu iki kaynaktan geleni doğrudan bir entity'ye bağlama: önce `bolge`/`mek`'in filtresinden geçmiş olması gerekir (`bolge §8`, `mek §10` reddedilenler listeleri) |
| `02` · `07` · `08` · `09` · `AD` | `lore/archive/notion-notes/` — 02 Ton ve Atmosfer, 07 Açılış, 08 Kanon Revizyonu, 09 Kıta Yapısı, Adlandırma Doktrini |

---

## campaign — 1

| Entity | Kaynak |
|---|---|
| Aegis — Meridia | `kartG §1` (beş sayfa). Sayfa 1 ← `02` ton kuralı + üç aşamalı omurga (Act 1 = Miras) · Sayfa 2 ← `RM §2` rol yuvaları, `09 §7` iki taşıyıcı, `08 §4` sayaç · Sayfa 3 ← `act1 §1` · Sayfa 4 ← `09 §4` bilgi eğimi, `RM §4.5` sır yerleşimi, `08 §2` perdenin ödülü · Sayfa 5 ← `AD §6-7` (yalnız ilk oturumda duyulan kelimeler) |

## lore — 4

| Entity | Kaynak |
|---|---|
| İrade Çağı | `02 §2` (İrade omurgası) + `08 §1` (doktrin bir kilit; 300 yıllık tanrısızlık bir tasarım) |
| Tanrılar ve Fısıltı | `02 §5.3` |
| Blight — Bilinen Hali | `02 §5.1` (cephe kuralı) + `act1 §4` (üç evre). `dmNotes`'taki #14 coğrafya çelişkisi ← `RM §3.2` |
| Adlandırma Doktrini — Halk Dili ve Latin | `AD §1, §5, §9.1` + `RM §3.1 M0.4-M0.5` + `act1 §3, §7` |

## location — 5

| Entity | Kaynak |
|---|---|
| Gümüşsu | `act1 §3` (manzara, kadro, üçlü, iğne) · `09 §5` (ufak köy) · `RM §3.1 M0.4` · sırlar ← `act1 §3` + `06 #8` (kurtarılabilirlik) |
| Kulübe | `act1 §3` (karantina değil, köyün kendi kararı) + `act1 §5` (son evre eşiği) |
| Bulut'un Hanı | `act1 §3` (yalnız hancı yazılı) — **🟡 mekan kanon değil**, `dmNotes`'ta işaretli |
| Gizli Liman | `act1 §7` tamamı (iki kapı, tehdit işlemez, düzen) + `09 §5` |
| Rıhtım | `act1 §7.4` (Fare'nin alanı) — **🟡 ayrı kart olmayabilir**, `kart1 §1` |

## npc — 12

| Entity | Kaynak |
|---|---|
| Duran · Umay · Karaca · Bulut | `act1 §3` kadro tablosu (üç satır: ne istiyor / ne gizliyor / hangi kapıyı açar) |
| Toygar · Selvi · Demir | `act1 §3` (sivil, Gizli Liman'dan, iğne) + `act1 §5` (1. gün hali) + `act1 §4` (belirti değişkenliği) |
| Sicim · Fare · Kaptan Vela · Kaptan Halim · Konsey Aracısı | `act1 §7.4` tablosu; Fare'nin bilgi eğimi rolü ← `09 §4` |

**İşaretli sapmalar**

- `attitude_ref` şema zorunluluğu; kanon tavır söylemiyor. Üç satırlık standarttan
  türetildi (yarası olmayan/yardım eden → `Friendly`, kalanı `Indifferent`).
  Hiçbir NPC `Hostile` değil — perde bir soruşturma, bir savaş değil.
- Toygar/Selvi/Demir'in **belirti farkları** ayrı bir kanon değil; `act1 §4`'ün
  *"iki hasta hiç aynı seyri izlemez"* kuralının uygulanışıdır. Kart `dmNotes`'unda
  🟡 ile işaretli.
- **Konsey Aracısı** bir unvan, ad değil: kişi adı dağarcığı (M5) yazılmadı.
- `species_ref` hiçbir NPC'de yazılmadı — kanon ırk söylemiyor.

## monster — 3 (+ 3 `creature-action`)

| Entity | Kaynak |
|---|---|
| Dönüşmüş Toygar · Selvi · Demir | `act1 §5` (aynı üç kişinin 2. gün hali, `npc` ikizine linkli) + `act1 §4` (bilinç gider, beden güçlenir) |
| Ezici Vuruş · Bırakmayan Kavrama · Sekmeyen Koşu | Kanonda yok — aşağıya bak |

⚠️ **Statblock kanon değil, mekanik karardır.** `act1 §4` yalnız *"bilinç gider,
beden güçlenir"* diyor; AC/HP/CR/aksiyon sayıları perdenin ilk çatışmasını 5e'ye
oturtmak için yazıldı ve her kartın `dmNotes`'unda böyle işaretlendi. Kanon bir sayı
verdiğinde bu kartlar onunla değiştirilir. Aynı şey `encounter.difficulty` ve
`xp_budget` için de geçerli.

## scene — 5 · encounter — 1 · quest — 3

| Entity | Kaynak |
|---|---|
| Köye Varış | `act1 §3` + `08 §2` (soruşturma, aynı anda varmak şart değil) |
| Kulübe Sorgusu | `act1 §5` (son konuşabilen hal) |
| Şafak Dönüşümü | `act1 §5` + `08 §4` (sayaç oyuncuda değil) |
| Limana Kabul | `act1 §7.1` (kefil / iş / yük) + `§7.3` (tehdit ilan eder) |
| Geçiş Pazarlığı | `act1 §7.2` (yazı ya da para) + `§7.4` kadro |
| Şafak Çatışması | `act1 §5` (perdenin ilk savaşı) |
| Söylentinin Peşinde | `act1 §1` giriş sözleşmesi |
| Nereden Geldiler | `act1 §3, §6, §7.5` (iğne → kayıtsız giriş → kaydı kim sildirdi) |
| Yol Hakkı | `act1 §7.2` — **🟡** "iyi yazı"/"iyi para" tanımı açık (`act1 §9` açık 3-4) |

## trinket — 1

| Entity | Kaynak |
|---|---|
| Cerrahi İğne | `act1 §3` + `07` (belkemiği: salgın değil suç). `roll_d100: 1` şema zorunluluğu, içerik değil. Kategori seçimi `kart1 §7` — sözleşmede `item` kategorisi yok |

---

## Bilerek yazılmayanlar

| Ne | Neden |
|---|---|
| 9 `background` + 9 evrene özel eşya | Her birinin feature'ı ve eşyası seçilmedi (`act1 §9` açık 1, `kartG §3-4`) |
| `species` | 06 #11 kapanmadan yazılan ırk kartı yeniden yazılır (`kartG §5`) |
| `applied-condition` "Blight enfeksiyonu" | Evrelerin mekaniği yazılmadı (`kartG §6`); anlatı hali `lore/Blight — Bilinen Hali` kartında |
| `monster` "Blight'lı köylü" (jenerik) | Statblock yok (`kartG §7`) |
| Sicim'in defteri | Prop mu kart mı belirsiz (`kart1 §7`) |
| Kolye (pusula) | Act 1'de var mı belli değil (`kart1 §7`) |
| Liman kaçışı `encounter` | Tehdit ilan edilirse çıkabilecek sonuç, kanon değil (`kart1 §5`) |
| Karantina doktoru · mızrak parçası | `kart1` *Yazılmayacaklar* — `act1 §3` karantinayı kaldırdı, `RM §1` mızrağı |
| Lonca · Merkezi Şehir · Elymsyr · Votumar · Ravenhall · Cinervik/Argenfon | **Kanonu artık var** (`lonca`, `bolge §2–5`) — blueprint'e girmediler, engel içerik değil sıra. Elymsyr/Votumar/Ravenhall NPC'lerinin **adı** ayrı bir tur ister (`bolge §9` açık 1) |
| Gemi (kapalı mekan bölümü) | `RM §2` adım 6; hâlâ yazılmadı |
| `lore/Kural Sapmaları` · `Direnç Şerbeti` | Kanonu var (`mek §5, §7–8`), blueprint'e girmedi. İkisinin de **sayıları** karar bekliyor (`mek §11`) |
| Tier 3 `blueprint.json` (dört pre-gen) | Faz 6; serbest yaratım kararından sonra zorunlu değil |
| `media/` | Arşivdeki 17 görsel 110 MB ve `.webp`'e çevrilmeden paketlenemez (`RM §4.6`). Dönüştürme aracı bu ortamda yok; `manifest.json → files` bilerek boş |
