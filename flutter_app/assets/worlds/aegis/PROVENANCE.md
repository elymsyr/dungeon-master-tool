# PROVENANCE — Aegis / `aegis-act1`

README §4.2 kural 3'ün karşılığı: **her entity'nin izi sürülebilir olmalı.**
Aegis'te aktarılacak bitmiş bir kitap olmadığı için `audit_coverage.py` kapsam
denetiminin yerini bu dosya tutar.

**Sürüm 0.4.0 — 125 entity** (2026-09-11). Kartlar güncel kanondan (Hastalık Puanı
revizyonu dahil) **sıfırdan** yazıldı; 0.2.0'ın metni kullanılmadı. 0.4.0'da bütün kartlar
README §6.7 (WotC read-aloud / modül sesi) ile yeniden yazıldı ve kayıt vurgusu azaltıldı
(README §4.8). Kartların içinde süreç dili, belge atfı ve "kanon değil" işareti
yok (README §6.0); o işaretlerin hepsi bu dosyanın **§Yorum ve türetme** bölümünde.

Üretim: kartlar bir üretici betikle kuruldu, `world-blueprint.json` onun çıktısı.
Betiğin denetimi: bütün `@[..](entity:..)` linkleri ve pakete ait ref'ler çözülüyor;
kart metinlerinde `Act 1 · perde · kanon · § · .md · şimdilik · Aethel · Evre` ve tasarım dili (`taşıyıcısı · Açtığı kapı · Kırılma noktası`) geçmiyor.
`convert_blueprint.dart --check` temiz.

Kaynak kısaltmaları:

| Kısaltma | Dosya |
|---|---|
| `act1` | [lore/canon/act1.md](lore/canon/act1.md) |
| `liste` | [lore/canon/kart-listesi.md](lore/canon/kart-listesi.md) |
| `kartG` | [lore/canon/genel-kartlar.md](lore/canon/genel-kartlar.md) |
| `lonca` | [lore/canon/lonca-sehir.md](lore/canon/lonca-sehir.md) |
| `bolge` | [lore/canon/bolgeler.md](lore/canon/bolgeler.md) |
| `mek` | [lore/canon/mekanikler.md](lore/canon/mekanikler.md) |
| `RM` | [README.md](README.md) |
| `02` · `08` · `09` | `lore/archive/notion-notes/` — Ton ve Atmosfer, Kanon Revizyonu, Kıta Yapısı |

---

## campaign — 1

| Entity | Kaynak |
|---|---|
| Aegis | `liste §1` · `kartG §1`. Sayfa *Bu dünyada oynamak* ← `02` ton kuralı + `lonca §0` + `bolge §1.1` · *Masa kuralları* ← `RM §2` yuvalar, `act1 §1` iki taşıyıcı, `08 §2` sayaç, `mek §1` büyünün üç katmanı, `mek §4.1`, `mek §12` (Kalıcı Yaralar önceden) · *Karakter yaratma* ← `act1 §1–2` · *DM'e* ← `act1 §6` / `bolge §9.12` bilgi eğimi, `RM §4.5` sır yerleşimi, `08 §1` (kanıtlanmayanlar) · *Sözlük* ← `lonca §1–3, §9`, `liste` ad katmanları |

"Miras" omurgası sayfada ilan edilmiyor (`kartG §1`); `dmNotes`'ta tek cümle.

## lore — 20

| Entity | Kaynak |
|---|---|
| İrade Çağı | `02 §2` (tanrılar kesildi, özgürlüğün bedeli) + `08 §1–2` (sansür, arşivsizlik) + `09 §1` (Occulus) + `lonca §1` (kral 300 yıldır oturumda yok) + `bolge §3.5` ("birbirinize bakın") |
| Tanrılar ve Fısıltı | `02` Beş Hamle #3 + `mek §3` + `lonca §5` |
| Blight — Bilinen Hali | `act1 §4` (kimse bilmiyor, hastalık olduğu bile kesin değil) + `act1 §4.2` belirtiler + `act1 §4.3` + `02` Beş Hamle #1 + `act1 §3` (köyün yöntemi) + `lonca §6` (humma) |
| Vorstrand — Bilinen Hali | `kartG §2` ("Öte", *kıta dışı*) + `lonca §6.3` (serbest ticaretçiler) + `bolge §2.7` (çevirmen) |
| Konsey ve Lonca Meclisi | `lonca §1, §2, §5` + `bolge §2.1, §3.1` (Konsey'in atadıkları) |
| Sancak Kaydı | Sayfa 1 ← `lonca §0, §5, §9` + `act1 §2` (mühür = kimlik) + `bolge §1.4, §4.1` + `liste` adlandırma · Sayfa 2 *Defter nasıl işler* ← `liste §2` *Kayıt Nasıl İşler*'in altı sayfası; `dmNotes` ← aynı bölümün `secrets` cümlesi |
| Büyücü Loncası | `lonca §2` + `mek §1, §2, §4.2–4.3, §12` |
| Sınır ve Ticaret Loncası | `lonca §2, §6.1, §6.2` + `bolge §2.1–2.2` |
| Demircilik ve İşçi Loncası | `lonca §2, §6, §9.2` + `bolge §1.6` |
| Simya ve Şifacılar Loncası | `lonca §2, §6, §7` + `mek §7` |
| Askeri Hukuk Loncası | `lonca §2, §4, §6` + `mek §2` + `act1 §7.4` (Halet Custar) |
| Mimarlık ve Planlama Loncası | `lonca §2, §6` + `bolge §1.3` |
| İrade Yolu | `bolge §1.1` (tablodaki "Aethel" → Lucian) + `bolge §3.5, §4.4` |
| Sessiz Mabetler | `bolge §1.2` + `bolge §3.5, §5.1, §6.1` |
| Hizmet Basamakları | `bolge §1.4` + `lonca §3` |
| Onur Mahkemeleri | `bolge §1.5, §2.2, §3.1` + `lonca §4` |
| Gümüş Kalkan Nişanı | `bolge §3.1–3.5` + `act1 §2` + `mek §3, §6` |
| Kuzeyin Gözcüleri | `bolge §4.2–4.5` + `mek §6` |
| Liman Ahdi | `bolge §6.2` + `act1 §7.3` |
| Kural Sapmaları | *Ölümün Ağırlığı* ← `mek §5, §12` · *Işınlanma ve Mesafe* ← `mek §4.2–4.3` + `bolge §1.7` · *Kalıcı Yaralar* ← `mek §8` |

## location — 18

| Entity | Üst | Kaynak |
|---|---|---|
| Aegis | — | `kartG §2b` + `09 §1` |
| Meridia | Aegis | `bolge §0` arazi + `act1 §7.2` (yol serbest) + `bolge §1.3, §1.7` + `RM §3.2 #14` (Gümüşsu güneyde) |
| Vorstrand | Aegis | `kartG §2b` + `act1 §3.1` |
| Gümüşsu | Meridia | `act1 §3` + `bolge §6.1` |
| Kulübe | Gümüşsu | `act1 §3, §3.1, §3.3, §4.5` + `mek §12` |
| Goodbarrel'ın Ocak Başı | Gümüşsu | `act1 §3.4` |
| Gizli Liman | Meridia | `act1 §7.1–7.5` + `bolge §1.2, §6.2` + `mek §2, §4.3` + `09 §5` |
| Rıhtım | Gizli Liman | `act1 §7.6` |
| Lucid Triton | Meridia | `lonca §5` + `bolge §1.3` + `09 §5` + `liste §3` (Lucidum Triton) |
| Mühür Salonu | Lucid Triton | `liste §3` + `lonca §5` Siyasal |
| Meclis Salonu | Lucid Triton | `liste §8` iki sahnenin yeri + `lonca §1, §5, §6` — `liste §3` başlığının 18. satırı (README §4.8) |
| Karşı-İmza Masası | Lucid Triton | `liste §3` + `liste §2` sayfa 4, 6 + `lonca §6.2, §7` |
| Elymsyr | Meridia | `bolge §2.1–2.7` |
| Votumar | Meridia | `bolge §3.1–3.7` + `bolge §1.7` |
| Gözcü Kuleleri Hattı | Votumar | `bolge §3.3` |
| Ravenhall Avlusu | Meridia | `bolge §4.1–4.6` |
| Cinervik | Meridia | `bolge §5.1` |
| Argenfon | Meridia | `bolge §5.2` |

## npc — 34

| Grup | Entity | Kaynak |
|---|---|---|
| Gümüşsu | Duran · Umay · Corvin · Milo Goodbarrel | `act1 §3` kadro + `act1 §3.3–3.4` + `bolge §6.1` + `mek §12` (Umay'ın ağzından) |
| Kulübe | Alton Leagallow · Merla Tealeaf · Kromanna | `act1 §3.1, §3.3, §4.3, §4.5, §5` |
| Gizli Liman | Sicim · Fare · Kaptan Caelynn · Kaptan Holg · Kadife · Mine | `act1 §7.3–7.5` (gerçek adlar Burgell · Trym · Halet Custar) + `liste §2` (fiyat cümlesi) + `bolge §1.5` |
| Meclis | Rektör — Quarion · Sınır ve Ticaret — Orvan Sancar · Kalfa Başı — Adrik Ferrun · Baş Otacı — Caramip Kalender · Sicil Ağası — Valen Custar · Levha Sahibi — Perhun Mizan | `lonca §6, §6.1–6.3, §10` (kırılma noktaları) |
| Sokak | Corin Sancar · Kildrak Ferrun · Sindri · Kandil · Çavuş Krusk | `lonca §7` + `liste §2` (Corin'in karşı-imzası, Orvan'ın nüshası) + `liste` adlandırma (Kandil) |
| Elymsyr | Gümrük Valisi · Nehir Muhafızı Çavuşu · Vinç Ustası · Çevirmen | `bolge §2.1, §2.7` |
| Votumar | Başkumandan · Kapı Komutanı · Şüpheci Rütbeli · Kule Nöbetçisi | `bolge §3.1, §3.6, §3.7, §10` + `09 §2` (gerçek Başkumandan tutuluyor) + `08 §1` (Lucian'ın eli) |
| Ravenhall | En Yaşlı Druid · Patika Gözcüsü | `bolge §4.5–4.6, §10` |

## monster — 4 · creature-action — 4 · trait — 5 · curse — 1

| Entity | Kaynak |
|---|---|
| Dönüşmüş · Dönüşmüş Alton · Dönüşmüş Merla · Dönüşmüş Kromanna | `act1 §5.1` |
| Pençe · Pençe (Alton) · Pençe (Merla) · Pençe (Kromanna) | `act1 §5.1` |
| Acıyı Tanımaz · Bulaştıran Yara · Durmayan Adım · Kesik Kesik · Erken Güçlenme | `act1 §5.1` |
| Blight — Enfeksiyon | `act1 §4.1–4.6` + `mek §6` (Yozlaşma) + `mek §7` (yapanın bedeli, şerbet) + `mek §12` |

## scene — 11 · encounter — 1 · quest — 2

| Entity | Kaynak |
|---|---|
| Köye Varış | `act1 §3, §5` + `08 §2` + `RM §2` yuvalar |
| Kulübe Sorgusu | `act1 §3.1, §3.3, §5` + `mek §12` |
| Şafak Dönüşümü | `act1 §5, §6` + `bolge §6.1` |
| Limana Kabul | `act1 §7.1, §7.3, §7.4` + `bolge §6.2` |
| Geçiş Pazarlığı | `act1 §7.2, §7.4` + `lonca §6.2` |
| Meclis Oturumu | `lonca §6, §6.1, §6.3, §10` |
| Kapı Önündeki Teklif | `lonca §6.2, §10` + `act1 §6.1` |
| Geçiş Divanı'nda Sıra | `liste §2` sayfa 4, 6 + `lonca §7` |
| Gümrük Rıhtımı | `bolge §2.2–2.7` |
| Susan Kule | `bolge §3.3, §3.7` |
| Avluda Karşılanma | `bolge §4.5, §4.6, §10` |
| Şafak Çatışması | `act1 §5, §5.1` + `mek §8, §12` + `bolge §6.1` |
| Söylentinin Peşinde | `act1 §1, §5, §6, §6.1` |
| Nereden Geldiler | `act1 §3.1–3.3, §7.5` + `lonca §6.2–6.3, §7` + `liste §4` iki taşıyıcı kuralı |

`lonca §8`'in *Adı tanıyan üye* sahnesi ayrı kart değil (`liste §8` on bir sahne
sayıyor): içerik `Meclis Oturumu` beat 3'e ve Orvan Sancar'ın `secrets`'ına girdi.

## background — 9 · adventuring-gear — 8 · trinket — 7

| Entity | Kaynak |
|---|---|
| Dokuz background | `act1 §2` tablosu + `liste §11` (altın) + `act1 §7.4` (Kadife'yi zarsız tanıyanlar) + `act1 §7.6` (Rıhtım İşçisi) + `mek §7` (Öğrenci'nin simya takımı) + `bolge §2.5` (Arşivci Elymsyr'de) |
| Tasnif Çantası · Kayıt Elifbası · Sancak Fihristi · Mertebe Kaftanı · Öğrenci Defteri · Yük Kancası · Seyir Defteri | `act1 §2` eşya tablosu + `liste §12` |
| Direnç Şerbeti | `mek §7, §12` |
| Lonca Mührü · Lonca Rozeti · Aile Mührü · Sahte Mühür · Kışla Künyesi · Emir Mührü | `act1 §2` eşya tablosu + `mek §3` (künye = anten) |
| Mühürsüz Yüzük | `act1 §3.3` iz 3 + yedek içerik |

---

## Yorum ve türetme — kanonun söylemediği, kartta duran

Kartların içinde işaret yok; kanon bir sayı ya da karar verdiğinde değişecek yerler bunlar.

**Kanon içi çelişkiler — `act1.md` izlendi:**

- **Maruziyet DC'si 12.** `act1 §4.1` ve `mek §7` DC 12 diyor; `liste §7` curse satırı DC 8 diyor.
- **Bulaştıran Yara DC'si 8.** `act1 §5.1` DC 8 diyor (revizyonda bilerek 12'den 8'e indi, `8a2b3f96`); `liste §6` ve `kartG §7` DC 12 diyor. `liste` iki sayıyı yer değiştirmiş görünüyor.
- **Sayım.** `liste §2` başlığı 22 `lore` diyor, tablosu 21 satır; `§3` başlığı 18 `location`, tablosu 17 satır (+ Meclis Salonu). Toplam 126; `Kayıt Nasıl İşler` `Sancak Kaydı`'na sayfa olarak girdiği için 125.
- **`quest/Silinen Sayfa` yazılmadı** — `lonca §6.2, §8` hâlâ sayıyor ama `RM §4.8` geri aldı ve `liste §10` iki görev sayıyor. Teklifin kendisi `scene/Kapı Önündeki Teklif`'te.

**Türetilmiş sayılar:**

- **Statblock boşlukları.** `act1 §5.1` üç adlandırılmış Dönüşmüş için yalnız bazı değerleri veriyor; eksikler ortak gövdeden alındı (Alton/Merla: CON 13 · INT 4 · WIS 8 · CHA 5; Kromanna: DEX 12 · INT 4 · WIS 8 · CHA 5). Hepsinde karanlıkgörüş 60 ft, pasif Algı 9, üç durum bağışıklığı gövdeden. Initiative DEX'ten.
- **`encounter.difficulty` = High, `xp_budget` = 400** — statblock'lardan hesap (2×100 + 200); 2024 bütçesinde dört 1. seviye karakter için High eşiği.
- **Yozlaşma DC'si 13 ve günlük hastalık zarı DC 13** — `mek §11` açık 2, 2a (türetildi).
- **Aşama 4'ün yozlaşma tablosu yok** — kartta yalnız "yozlaşma dalgası (Wild Magic benzeri)" (`mek §11` açık 2b).
- **Kalıcı Yara bandları (1–5 / 6–14 / 15–20)** — `mek §8`, türetildi (`mek §11` açık 3).
- **Diriltme Sınavı'nın zarı yok** — kartta sınavın varlığı ve üç sonuç, zar yok (`mek §11` açık 1).
- **Direnç Şerbeti:** `cost_cp` 0 (fiyat açık, `mek §11` açık 5), `weight_lb` 0.5 (iksir şişesi ağırlığı; şema zorunlu).
- **Diğer eşyaların `cost_cp` / `weight_lb`'i** SRD muadilinden.

**Yorumlar:**

- **Mühürsüz Yüzük'ün yedek içeriği** (eğelenmiş mühür yüzü, taze Meridia ayar damgası) kartta içerik olarak yazıldı: `trinket/Mühürsüz Yüzük` açıklamasının son paragrafı, `npc/Mine` `secrets`, `quest/Nereden Geldiler` `secrets`. Kanon bunu *askıda* tutuyor (`act1 §9` açık 5); ama `liste §4` Mine'ın ve `lonca §7` Kildrak'ın satırları ona yaslanıyor. Karar değişirse bu üç alan + `npc/Kildrak Ferrun` birlikte değişir.
- **Kulübeye girmek bir maruziyet zarı** — `mek §12`'nin DM notu ("kulübeye giren her PC bir maruziyet zarı atar"); `act1 §4.1`'in dört yolu ayrıca duruyor.
- **`attitude_ref`** şema zorunlu, kanon söylemiyor: Umay · Milo Goodbarrel · Fare · Orvan Sancar · Sindri `Friendly`, kalanı `Indifferent`. `Hostile` yok.
- **`species_ref`** yalnız SRD'de birebir adı olan ırklarda. Yarı-elf / yarı-orc (Umay · Caelynn · Holg · Krusk · Çevirmen · Patika Gözcüsü) ve kanonun iki ırk verdiği iki NPC (Şüpheci Rütbeli: insan/ejderdoğan · En Yaşlı Druid: insan/elf) ile Başkumandan'da ref yok; ırk `appearance` ya da `dmNotes`'ta.
- **Background trinket'leri envantere giremiyor** — `default_inventory_refs` şeması `trinket` kabul etmiyor (`content.dart`); mühür/rozet/künye açıklamada link, `dmNotes`'ta "karaktere elle ekle".
- **Magic Initiate (Wizard)** — SRD feat adı sınıfsız; sınıf `dmNotes`'ta.
- **Susan Kule** — nöbetçinin *ne gördüğü* kanonda yok; sahne yalnız "körfezin girişinde bir şey" diyor (`bolge §3.3`'ün sistem tarifi).
- **Avluda Karşılanma** — druidin çürümeyi *nasıl okuduğunun* içeriği kanonda yok; sahne başlığını veriyor, içeriği vermiyor.
- **Read-aloud dokusu (README §6.7 / A1).** Açılış metinlerine koku, ses, sıcaklık ve sayılabilir ayrıntı eklendi; hiçbiri yeni NPC, yer, nesne ya da olay değil. İlerde tartışılabilecek olanlar: Meclis Salonu'nda beş hane işareti + tek boş duvar (beş hane + hanesiz koltuktan) · Karşı-İmza Masası'nda kenarı sararmış kağıtlar · Susan Kule'de köşesi katlanmış defter sayfası · Gümrükte *Lucid Triton* yazan mühürlü torba · Lucid Triton ağaçlarının renkleri (kızıl/turuncu/mor; kanon "canlı renkler").
- **NPC görünüş ve tavırları** kanonda çoğunlukla yok; rol ve ırktan türetilmiş yüzey ayrıntısı. **Yaş, cinsiyet, saç/göz rengi, giysi, koku, ses ve örnek replikler** hep doku (kanonda NPC cinsiyeti hiç geçmiyor). Kadın yazılanlar: Umay · Merla · Kromanna · Kaptan Caelynn · Mine · Nehir Muhafızı Çavuşu · Kapı Komutanı · Patika Gözcüsü. Olay örgüsüne en yakın olanlar: Vinç Ustası "gece daha iyi çalışır" · Kandil'in tabelasız çivileri · Kaptan Caelynn'in kapalı sandığı beklemesi · Başkumandan'ın göz kırpmaması · Kapı Komutanı'nın defterinde iki aydır boş *emir* sütunu · Umay'ın da kulübeye girdiğini sorulunca susması.
- **Mekan bölümleri (0.4.0).** Mekanlara bölüm bölüm fiziksel tasvir eklendi; yeni NPC, olay ya da gizli bilgi yok. Tartışılabilecek dokular: Meclis Salonu duvar işaretleri (anahtar/Sancar · çekiç/Ferrun · terazi/Kalender · kılıç/Custar · pergel/Mizan) · Goodbarrel'da altı masa, iki oda, üç atlık ahır (kanondan) + geyik boynuzları · Kulübe'de penceresizlik, eşyaların kimde olduğu (kese Alton'da, parşömen Merla'da) · Mühür Salonu'nda mum ocakları ve gözlü dolap · Karşı-İmza Masası'nda kilitli eski defter dolabı · Elymsyr bölümleri (boğaz, zincir, aşağı rıhtım, gümrük binası, teraslar) · Votumar avlusu ve kalkan duvarı talimi · Gözcü kulesinin üç katı · Rıhtım'da barakalar (meyhane, depo, ağ tamircisi) · Paladin Rütbelisi / Emir Mührü'nde beyaz mühür mumu · Sancak Fihristi'nin renkli sekmeleri.
- **Çatışma alanı.** Şafak Çatışması'nda patikanın genişliği, iki yanda zorlu arazi sayılan çalı ve köyün son evine altmış adım: harita dokusu, kanonda yok.
- **Kanonda DC'si olmayan ikna anları DC'siz yazıldı** (Duran'ın "limandan geldiler"i, Sindri'nin kopyası, Kapı Komutanı'nın cümlesi): rol yapma koşulu var, zar yok.

---

## Bilerek yazılmayanlar

| Ne | Neden |
|---|---|
| `species` | 06 #11 kapanmadan yazılan ırk kartı yeniden yazılır (`kartG §5`). Blok **yazmayı** engelliyor, **ref vermeyi** değil |
| Silinen Sayfa `quest` | `RM §4.8` geri aldı; `liste §10` iki görev sayıyor |
| Adı tanıyan üye `scene` | `liste §8` on bir sahne sayıyor; içerik Meclis Oturumu'nda |
| Karantina doktoru | Karantina yok; kulübe köyün kendi kararı |
| Cerrahi iğne | `act1 §3.2` kaldırdı |
| Mızrak parçası · kolye (pusula) | `RM §1` · `act1 §9` madde 16 |
| Üçlünün gerçek adlarının ötesi | `act1 §3.1` — cevap limanın dışında |
| Sicim'in defteri · altın kesesi · boş parşömenler | Sahnede duran prop (`act1 §9` madde 15, `act1-kartlar.md` Yazılmayacaklar) |
| Liman kaçışı `encounter` · Yol hakkı `quest` | `act1 §7.2–7.3` |
| Haneler | Loncanın `lore` kartında (`lonca §3`) |
| Gemi bölümü · ufuk sahnesi | `RM §2` adım 6; kanonu yazılmadı |
| Kronoloji · fraksiyon kartları | `RM §5` Faz 1'in kalanı |
| Tier 3 `blueprint.json` | `RM §5` Faz 6 |
| `media/` | 17 görsel, 110 MB, `.webp`'e çevrilmeden paketlenemez (`RM §4.6`); `manifest.json → files` boş |
