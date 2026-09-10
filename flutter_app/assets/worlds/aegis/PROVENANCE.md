# PROVENANCE — Aegis / `aegis-act1`

README §4.2 kural 3'ün karşılığı: **her entity'nin izi sürülebilir olmalı.**
Aegis'te aktarılacak bitmiş bir kitap olmadığı için `audit_coverage.py` kapsam
denetiminin yerini bu dosya tutar.

**Sürüm 0.2.0 — 126 entity.** Kapsam
[`lore/canon/kart-listesi.md`](lore/canon/kart-listesi.md)'nin tamamı.

Kaynak kısaltmaları:

| Kısaltma | Dosya |
|---|---|
| `act1` | [lore/canon/act1.md](lore/canon/act1.md) |
| `liste` | [lore/canon/kart-listesi.md](lore/canon/kart-listesi.md) |
| `kart1` | [lore/canon/act1-kartlar.md](lore/canon/act1-kartlar.md) |
| `kartG` | [lore/canon/genel-kartlar.md](lore/canon/genel-kartlar.md) |
| `lonca` | [lore/canon/lonca-sehir.md](lore/canon/lonca-sehir.md) |
| `bolge` | [lore/canon/bolgeler.md](lore/canon/bolgeler.md) |
| `mek` | [lore/canon/mekanikler.md](lore/canon/mekanikler.md) |
| `RM` | [README.md](README.md) (bu dizin) |
| `AE` · `YT` | `lore/archive/*.pdf` — **PDF, hiyerarşinin en altı.** Bu iki kaynaktan geleni doğrudan bir entity'ye bağlama: önce `bolge`/`mek`'in filtresinden geçmiş olması gerekir (`bolge §8`, `mek §10` reddedilenler listeleri) |
| `02` · `07` · `08` · `09` | `lore/archive/notion-notes/` — Ton ve Atmosfer, Açılış, Kanon Revizyonu, Kıta Yapısı |

---

## campaign — 1

| Entity | Kaynak |
|---|---|
| Aegis | `liste §1` · `kartG §1` (beş sayfa). Sayfa 1 ← `02` ton kuralı + `lonca §0` (kayıt) + `bolge §1.1` · Sayfa 2 ← `RM §2` rol yuvaları, `09 §7` iki taşıyıcı, `08 §4` sayaç, `mek §1` büyünün üç katmanı, `mek §4.1` · Sayfa 3 ← `act1 §1-2` · Sayfa 4 ← `bolge §9` madde 12 (bilgi eğiminin yedi noktası), `RM §4.5` sır yerleşimi · Sayfa 5 ← `lonca §9` üç kayıt sınıfı + `liste` ad katmanları |

**Not:** `kartG §1` kararı gereği "Miras" omurgası sayfa 1'de **ilan edilmiyor**;
yalnız `dmNotes`'ta bir cümle olarak duruyor.

## lore — 20

| Entity | Kaynak |
|---|---|
| İrade Çağı | `02 §2` + `08 §1` |
| Tanrılar ve Fısıltı | `02 §5.3` + `mek §3` (Yankılanan Sessizlik: pasif tanrılar, şifanın ağırlığı, sembol = anten) + `lonca §5` (usulsüzlük okuması) |
| Blight — Bilinen Hali | `02 §5.1` (cephe kuralı) + `act1 §4` (görünen seyir) + `act1 §3.1` (taşıyıcı: hastalık **ikinci kıtadan** geldi, yön verilmez) |
| Vorstrand — Bilinen Hali | `act1 §3.1` + `kartG §2` ("Öte", Sancak Kaydı'nda tek satır) + `liste` ad sicili |
| Konsey ve Lonca Meclisi | `lonca §1` tablosu + `lonca §2` altı koltuk + `lonca §5` (kararlar oturumdan önce alınır) |
| Sancak Kaydı | `lonca §0, §9` (üç sınıf) + `bolge §1.4` (Hizmet Basamakları bağı) + `act1 §2` (mühür = yazma yetkisi) |
| Büyücü Loncası | `lonca §2` + `mek §1, §2, §4.2-4.3` (lisans, iki yasak okul, ışınlanma kaydı) |
| Sınır ve Ticaret Loncası | `lonca §2, §6.1` + `bolge §2.1-2.2` (taşra gümrüğü) |
| Demircilik ve İşçi Loncası | `lonca §2` + `lonca §9` açık 2 (Ferrunlar cüce hanesi) + `act1 §7.4` (ayar damgası) |
| Simya ve Şifacılar Loncası | `lonca §2` + `mek §7` (iksirin ruhsatlı kalem olması) |
| Askeri Hukuk Loncası | `lonca §2, §4` + `bolge §1.5` (kayıttan düşürme) + `act1 §7.4` (Halet Custar) |
| Mimarlık ve Planlama Loncası | `lonca §2, §6` + `bolge §1.3` (mimarinin kuralı) |
| İrade Yolu | `bolge §1.1` tamamı (üç kurucu cümle + bozulma tablosu) + `bolge §3.5`, `§4.4` (yerel okumalar) |
| Sessiz Mabetler | `bolge §1.2` (beş biçim) |
| Hizmet Basamakları | `bolge §1.4` + `lonca §3` (hane = mührü tutan aile) |
| Onur Mahkemeleri | `bolge §1.5` + `lonca §4` |
| Gümüş Kalkan Nişanı | `bolge §3.2, §3.5` + `act1 §2` (Kışla Künyesi / Emir Mührü) + `bolge §3.1` (Onur ve Yemin Yasaları) |
| Kuzeyin Gözcüleri | `bolge §4.2, §4.3, §4.4, §4.5` + `mek §6` (Druid +2 bir eğitim) |
| Liman Ahdi | `bolge §6.2` (ad + iki madde) + `act1 §7.3` (üç sabit doğru) |
| Kural Sapmaları | 3 sayfa: `mek §5` (Ölümün Ağırlığı) · `mek §4.2-4.3` (Işınlanma ve Mesafe, `bolge §1.7` mesafesiyle) · `mek §8` (Kalıcı Yaralar) |

⚠️ **`lore/Kural Sapmaları`'nda iki sayı kanon değil** ve kartın `dmNotes`'unda
işaretli: Diriltme Sınavı'nın zarı (`mek §11` açık 1) ve Kalıcı Yara bandlarının
sınırları (`mek §11` açık 3).

**Sayım notu:** `liste §2` başlığı 21 diyor, tablosu 20 satır sayıyor. Yazılan
tablodaki 20; eksik olan bir kart değil, başlıktaki bir sayı.

## location — 18

| Entity | Üst | Kaynak |
|---|---|---|
| Aegis | — | `kartG §2b` + `RM §1` (izolasyon arşivsel) |
| Meridia | Aegis | `kartG §2b` + `bolge §0` (arazi: dağlar/nehir, kireçtaşı kıyı, kuzey platosu) + `act1 §7.2` (yol serbest) |
| Vorstrand | Aegis | `kartG §2b` + `act1 §3.1` |
| Gümüşsu | Meridia | `act1 §3` (manzara, kadro) + `bolge §6.1` (İhtiyar Heyeti, milis, takas, Koca Orman) + `RM §3.1 M0.4` |
| Kulübe | Gümüşsu | `act1 §3` (köyün kendi kararı) + `act1 §3.3` (kapalı eşya listesi) + `act1 §5` (son evre eşiği) |
| Goodbarrel'ın Ocak Başı | Gümüşsu | `act1 §3.4` tamamı (fiyatlar dahil) |
| Gizli Liman | Meridia | `act1 §7` tamamı + `bolge §6.2` (Liman Ahdi) + `mek §4.3` (büyü malzemesi), `mek §2` (lisans bir şaka) |
| Rıhtım | Gizli Liman | `act1 §7.6` tamamı |
| Lucid Triton | Meridia | `lonca §5` (dört başlık) + `bolge §1.3` (beyaz taş, anıtlar, fener) + `lonca §9` açık 1 (ad) |
| Meclis Salonu | Lucid Triton | `lonca §1, §6` — **`liste §3` tablosunda satırı yok, başlığı 18 diyor.** `liste §8`'in iki sahnesi (*Meclis Oturumu* · *Kapı Önündeki Teklif*) bu yeri "Meclis Salonu" diye adlandırıyor; 18. satır bu |
| Mühür Salonu | Lucid Triton | `lonca §8` + `lonca §5` (kararın kayda geçtiği yer) + `lonca §5` kültürel (doğum töreni) |
| Karşı-İmza Masası | Lucid Triton | `lonca §7, §8` (Geçiş Divanı) + `lonca §6.2` (karşı-imzalı geçiş kağıdı) |
| Elymsyr | Meridia | `bolge §2` tamamı (§2.1–§2.6) |
| Votumar | Meridia | `bolge §3` tamamı (§3.1–§3.6) + `bolge §1.7` (iki gün) |
| Gözcü Kuleleri Hattı | Votumar | `bolge §3.3` (işaret ağı, deniz feneri) |
| Ravenhall Avlusu | Meridia | `bolge §4` tamamı (§4.1–§4.5) |
| Cinervik | Meridia | `bolge §5.1` + `bolge §5` ad ataması |
| Argenfon | Meridia | `bolge §5.2` + `bolge §5` ad ataması |

## npc — 34

| Grup | Entity | Kaynak |
|---|---|---|
| Gümüşsu | Duran · Umay · Corvin · Milo Goodbarrel | `act1 §3` kadro tablosu (üç satır: ne istiyor / ne gizliyor / hangi kapıyı açar) + `act1 §3.4` (Milo) + `bolge §6.1` (Duran heyetin başı) |
| Kulübe | Alton Leagallow · Merla Tealeaf · Kromanna | `act1 §3.1` (kimlikler, sahte adlar, hane) + `act1 §3.3` (izler, gizli cepteki yüzük) + `act1 §5` (1. gün hali) |
| Gizli Liman | Sicim · Fare · Kaptan Caelynn · Kaptan Holg · Kadife · Mine | `act1 §7.4` tablosu + gerçek adlar (Burgell · Trym · Halet Custar) + `bolge §1.5` (Mine'ın gönüllü kayıttan düşmesi) |
| Meclis | Rektör — Quarion · Sınır ve Ticaret — Orvan Sancar · Kalfa Başı — Adrik Ferrun · Baş Otacı — Caramip Kalender · Sicil Ağası — Valen Custar · Levha Sahibi — Perhun Mizan | `lonca §6` tablosu (altı inkâr) + `lonca §6.1` (en fakir koltuk) + `lonca §6.3` (adı tanıyan üye) |
| Lucid Triton sokağı | Corin Sancar · Kildrak Ferrun · Sindri · Kandil · Çavuş Krusk | `lonca §7` tablosu |
| Elymsyr | Gümrük Valisi · Nehir Muhafızı Çavuşu · Vinç Ustası · Çevirmen | `bolge §2.7` tablosu |
| Votumar | Başkumandan · Kapı Komutanı · Şüpheci Rütbeli · Kule Nöbetçisi | `bolge §3.7` tablosu + `bolge §3.6` (Başkumandan = Suretsiz, `secrets`) |
| Ravenhall | En Yaşlı Druid · Patika Gözcüsü | `bolge §4.6` tablosu |

**İşaretli sapmalar**

- `attitude_ref` şema zorunluluğu; kanon tavır söylemiyor. Üç satırlık standarttan
  türetildi (yarası olmayan / yardım eden → `Friendly`, kalanı `Indifferent`).
  `Hostile` yalnız iki yerde: **Kromanna** (hasta ve koruyucu) ve **Patika Gözcüsü**
  (kimsenin yukarı çıkmasını istemiyor).
- **On NPC unvanla yazıldı, adsız** (`bolge §9` açık 1): Elymsyr'in dördü,
  Votumar'ın dördü, Ravenhall'ın ikisi. Her birinin `dmNotes`'unda 🟡 işareti var;
  ad kondugunda tek `name` değişikliği yeter.
- `species_ref` **yalnız SRD'de birebir adı olan ırklara** verildi. Yarı-elf ve
  yarı-orc NPC'lerde (Umay · Kaptan Caelynn · Kaptan Holg · Çavuş Krusk · Çevirmen ·
  Patika Gözcüsü) ref **yok** — SRD'de o ırk yok ve `kartG §5` yeni `species` kartı
  yazmayı bloke ediyor. Irk `appearance` alanında yazılı.
  Aynı sebeple **Başkumandan**'da da ref yok (`bolge §3.7`: *insan görünümünde*),
  ve **Şüpheci Rütbeli** ile **En Yaşlı Druid**'de kanon iki ırk birden veriyor.
- **Başkumandan'ın Votumar'da ne aradığı yazılmadı** (`bolge §9` açık 3).
  `secrets` alanı bilerek ince: koltuk ele geçirilmiş, sebebi açık.

## monster — 4 · creature-action — 4 · trait — 5

| Entity | Kaynak |
|---|---|
| Dönüşmüş (jenerik) | `act1 §5.1` ortak gövde + `kartG §7` |
| Dönüşmüş Alton · Merla · Kromanna | `act1 §5.1` (üç adlandırılmış blok) + `act1 §4.3` (belirti hatları) |
| Pençe · Pençe (Alton) · Pençe (Merla) · Pençe (Kromanna) | `act1 §5.1` |
| Acıyı Tanımaz · Bulaştıran Yara | `act1 §5.1` ortak gövde |
| Durmayan Adım · Kesik Kesik · Erken Güçlenme | `act1 §5.1` (sırasıyla Alton · Merla · Kromanna) |

⚠️ **Statblock kanon değil, mekanik karardır.** `act1 §4` yalnız *"bilinç gider,
beden güçlenir"* diyor; `act1 §5.1`'in sayıları perdenin ilk çatışmasını 5e'ye
oturtmak için yazıldı ve her kartın `dmNotes`'unda böyle işaretlendi. Aynı şey
`encounter.difficulty` ve `xp_budget` için de geçerli.

## curse — 1

| Entity | Kaynak |
|---|---|
| Blight — Enfeksiyon | `act1 §4` tamamı (bulaşma DC 12 · üç evre · üç başarı/üç başarısızlık · tedavi) + `mek §6` (Yozlaşma Kontrolü) + `mek §7` (şifa büyülerinin yapana bedeli, Direnç Şerbeti) + `act1 §4.6` (büyülü + biyolojik, Arcana DC 13) |

Kategori kararı `act1 §4`: `curse`, `applied-condition` değil — Blight bir SRD
condition'ı değil ve `curse` şeması `trigger`/`effect`/`mechanical_notes`/`removed_by`
alanlarını serbest bırakıyor.

⚠️ **Yozlaşma DC'si 13 türetildi** (`mek §6`, `mek §11` açık 2); Evre 2 zarıyla
hizalandı, kanon bir sayı vermiyor.

## scene — 11 · encounter — 1 · quest — 3

| Entity | Kaynak |
|---|---|
| Köye Varış | `act1 §3` + `08 §2` (soruşturma, aynı anda varmak şart değil) |
| Kulübe Sorgusu | `act1 §5` (son konuşabilen hal) + `act1 §3.3` (beş iz ve DC'leri) + `act1 §3.1` (alyans çatlağı) |
| Şafak Dönüşümü | `act1 §5` + `08 §4` (sayaç oyuncuda değil) + `bolge §6.1` (milis) |
| Limana Kabul | `act1 §7.1` (kefil / iş / yük) + `§7.3` (tehdit ilan eder) + `bolge §6.2` (Ahit) |
| Geçiş Pazarlığı | `act1 §7.2` (yazı ya da para) + `§7.4` kadro + `lonca §6.2` (iyi yazı = karşı-imzalı geçiş kağıdı) |
| Meclis Oturumu | `lonca §6` (altı inkâr) + `lonca §6.1` (tek sessiz üye) + `lonca §6.3` (adı tanıyan üye) |
| Kapı Önündeki Teklif | `lonca §6.2` tamamı (üç cümle + iki parça ödül + eriyen miras) |
| Geçiş Divanı'nda Sıra | `lonca §7` (geçiş memuru) + `lonca §8` |
| Gümrükte Kayıt | `bolge §2.2` + `§2.3` (zincir) + `§2.5` (söylenti okunur) |
| Susan Kule | `bolge §3.3` + `§3.7` (kule nöbetçisi) |
| Avluda Karşılanma | `bolge §4.5` + `§4.3` (Avlu) + `§4.6` (iki NPC) |
| Şafak Çatışması | `act1 §5` + `§5.1` tempo notu + `mek §8` (Kalıcı Yaralar ilk kez burada) |
| Söylentinin Peşinde | `act1 §1` giriş sözleşmesi |
| Nereden Geldiler | `act1 §3.3, §6, §7.5` (izler → kayıtsız giriş → kaydı kim sildirdi) + `act1 §3.1` (gerçek adlar Meclis'te) |

`lonca §8`'in *Adı tanıyan üye* sahnesi ayrı kart olarak yazılmadı: `liste §8` on bir
sahne sayıyor ve bunu içermiyor. İçerik `scene/Meclis Oturumu`'nun 5. beat'ine ve
`npc/Sınır ve Ticaret — Orvan Sancar`'ın `secrets` alanına girdi.

## background — 9

| Entity | Kaynak |
|---|---|
| Arşivci · Lonca Üyesi · Mertebeli Lonca Çocuğu · Sihir Loncası Öğrencisi · Lonca Ajanı · Rıhtım İşçisi · Gemi Kaptanı · Paladin Askeri · Paladin Rütbelisi | `act1 §2` tablosu (yetenek seçimi · 2 skill · tool · origin feat · eşya · kurgusal eksi) + `liste §11` (başlangıç altını) |

- `asi_distribution_options` = `+2/+1` ve `+1/+1/+1`, `gold_alternative_gp` = 50
  — dokuzunda da (`act1 §2`).
- **Evrene özel `feature` yok** (`act1 §2` kararı): şemada serbest mekanik yazacak
  alan yok. Feature'ın işini eşya + kurgu yapıyor.
- `origin_feat_ref` **Magic Initiate** olarak yazıldı; `act1 §2` *Magic Initiate
  (Wizard)* diyor ama SRD'de feat'in adı sınıfsız. Sınıf seçimi kartın
  `dmNotes`'unda.
- **Mühür/rozet/künye kartları `default_inventory_refs`'e giremiyor:** o alan
  `adventuring-gear`/`weapon`/`armor`/`tool`/`pack`/`ammunition` taşıyor, `trinket`
  taşımıyor (`world-blueprint.md §3.22`). Altı `trinket` eşyası kartın
  `description`'ında entity link'iyle veriliyor ve bu kartlarda bir şema notu var.
  Converter README kural 3 gereği alan zorlanmadı.

## adventuring-gear — 8 · trinket — 7

| Entity | Kaynak |
|---|---|
| Tasnif Çantası · Kayıt Elifbası · Sancak Fihristi · Mertebe Kaftanı · Öğrenci Defteri · Yük Kancası · Seyir Defteri | `act1 §2` eşya tablosu + `kartG §4` (SRD muadilleri) |
| Direnç Şerbeti | `mek §7` (24 saat, +5, kim üretir) |
| Lonca Mührü · Lonca Rozeti · Aile Mührü · Sahte Mühür · Kışla Künyesi · Emir Mührü | `act1 §2` eşya tablosu + `kartG §4` |
| Mühürsüz Yüzük | `act1 §3.3` iz 3 (gizli cep, Investigation DC 15) + yedek içerik (`act1 §3.3`) |

- `cost_cp` / `weight_lb` şema zorunluluğu; kanon fiyat vermiyor. Değerler
  **SRD muadilinden** alındı (`kartG §4` tablosu), uydurulmadı.
- ⚠️ **Direnç Şerbeti'nin fiyatı `0` bırakıldı** (`mek §11` açık 5): kıt olduğu
  kanon, ne kadar kıt olduğu değil. Kartın `dmNotes`'unda işaretli.
- ⚠️ **Mühürsüz Yüzük'ün adı ve içeriği askıda** (`act1 §9` açık 5). Nesnenin var
  olduğu ve saklandığı kanon; ne olduğu değil. `description`'ın son paragrafı
  `act1 §3.3`'ün **yedek içeriği** ve kanon sayılmıyor — kartın `dmNotes`'unda
  işaretli. Karar verilince bu kart, `npc/Mine` ve kart adı birlikte değişir.
- `roll_d100` şema zorunluluğu (1..7 sırayla), içerik değil.

---

## Bilerek yazılmayanlar

| Ne | Neden |
|---|---|
| `species` | 06 #11 kapanmadan yazılan ırk kartı yeniden yazılır (`kartG §5`). Blok **yazmayı** engelliyor, **ref vermeyi** değil |
| Karantina doktoru | Karantina yok; kulübe köyün kendi kararı (`liste` *Yazılmayacaklar*) |
| Cerrahi iğne | `act1 §3.2` kaldırdı. Yerini beden (Medicine DC 12) ve hava (Arcana DC 13) aldı. **0.1.0'da vardı, bu sürümde silindi** |
| Mızrak parçası · kolye (pusula) | `RM §1` · `act1 §9` madde 16 — bu kapsamda yoklar |
| Üçlünün gerçek adlarının ötesi | Cevap limanın dışında (`act1 §3.1`) |
| Sicim'in defteri | Sahnede duran prop, ayrı karta ihtiyacı yok (`act1 §9` madde 15) |
| Liman kaçışı `encounter` | Kavga bir kurgu değil bir sonuç; DM doğaçlar (`act1 §7.3`) |
| Yol hakkı `quest` | Yol serbest; fiyatı olan tek şey gemiye binmek (`act1 §7.2`) |
| Silinen Sayfa `quest` | Kanonda dayanağı yok — DM onayı olmadan yazılmış bir kart olarak geri alındı, elymsyr onayından sonra tekrar açılabilir |
| Haneler (Sancarlar · Ferrunlar · Kalenderler · Custarlar · Mizanlar) | Ait oldukları loncanın `lore` kartında; masaya çıkana kadar ayrı kart değil (`lonca §3`) |
| Gemi (kapalı mekan bölümü) | `RM §2` adım 6; kanonu yazılmadı |
| Kronoloji tablosu · fraksiyon kartları | `RM §5` Faz 1'in kalanı — kanon henüz yok |
| Tier 3 `blueprint.json` (dört pre-gen) | `RM §5` Faz 6; serbest yaratım kararından sonra zorunlu değil |
| `media/` | Arşivdeki 17 görsel 110 MB ve `.webp`'e çevrilmeden paketlenemez (`RM §4.6`). Dönüştürme aracı bu ortamda yok; `manifest.json → files` bilerek boş |
