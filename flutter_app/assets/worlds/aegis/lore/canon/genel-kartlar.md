# Genel Kartlar — perdeden bağımsız

> **Durum: çalışma listesi.** Hiçbir act'a bağlı olmayan, dünyanın kendisine ait
> kartlar. Act 1'e özgü olanlar → [`act1-kartlar.md`](act1-kartlar.md).

> ⚠️ **Paketle senkron değil.** `aegis-act1/world-blueprint.json` (0.1.0, 38 entity)
> **2026-09-09 revizyonundan önce** üretildi: içinde hâlâ `trinket/Cerrahi İğne` var,
> üçlü "sivil yolcu" olarak yazılı, background ve `curse` kartı yok. Bu listeler
> kanonu gösteriyor, paketi değil — blueprint bir sonraki üretimde bu kanona göre
> yeniden yazılacak.

**Kapsam:** şimdilik yalnız **oyun öncesi** (giriş kartı, karakter yaratma) ve
**ilk bölümlerin** gerektirdiği kartlar. Dünyanın geri kalanı en alttaki
*Sonraki bölümler için planlama* başlığında — orada kart yok, plan var.

**Ayrım kuralı:** bir kart yalnız Act 1'de anlamlıysa act listesinde; her perdede
geçerliyse burada.

**Durum kodları:** `✅` yazılabilir · `🟡` kanon kısmi · `⬜` kanon yok, önce karar.

**Adlar geçici, her ad link.** Kural ve linkleme tablosu:
[`act1-kartlar.md` §0](act1-kartlar.md). Giriş kartında da geçerli — sözlükteki her
madde ilgili `lore` kartına linklenir.

**Kart eşiği (KARAR, 2026-09-09 2. tur):** *adı olan ve masada işaret edilebilen her
şey kart olur.* Bir kıta, bir han, bir rıhtım, bir arşivcinin çantasındaki tek bir
kitap — hepsi. Bir şeyi kart yapmamanın tek geçerli sebebi **o şeyin hiç var
olmaması** (bkz. her iki listenin *Yazılmayacaklar* başlıkları); "küçük", "sadece
dekor", "sonra bakarız" sebep değil. İçeriği eksik kart yazılabilir, olmayan kart
yazılamaz.

---

## 1. `campaign` — 1 kart, giriş bölümü

Tek kart: **Aegis — Meridia**. İçerik `pages[]` listesinde (README §4.5).

| Sayfa | Durum | Dayanak |
|---|---|---|
| **Bu dünyada oynamak** — ton sözleşmesi | ✅ | 02: *karanlık geçmişte ve yapılarda; ışık insanlarda ve bugünde* · *dünya yaşanabilir, ama gidişat kötü*. **Miras vurgusu düşürüldü** — aşağı bak |
| **Masa kuralları** — rol yuvaları, iki taşıyıcı kuralı, sayaç NPC'de | ✅ | Yönerge §3.2 · 09 §7 · 08 §4 |
| **Karakter yaratma** — serbest, tek cümlelik sözleşme | ✅ | act1.md §1 |
| **DM'e** — bilgi eğimi, sır yerleşimi (`secrets`), neyin gizli kalacağı | ✅ | 09 §4 · README §4.5 |
| **Sözlük** — oyuncunun ilk oturumda duyacağı kadarı | 🟡 | Adlandırma Doktrini; M0.2/M0.3 açık |

> **Uyarı:** giriş kartı DM'in kitabı değil, **oyuncunun ilk okuduğu şey.**
> Baş kötünün kim olduğu buraya yazılmaz. Sözlük de dünyayı anlatmaz, ilk
> oturumda geçen kelimeleri açar.

**KARAR (2026-09-09) — Miras omurgası ilan edilmiyor.** 02'nin üç aşamalı omurgası
(Act 1 = *Miras*: "bu benim suçum değil ama benim sorunum") **kanon olarak duruyor**;
kaldırılmadı. Kaldırılan şey onun *sayfa 1'de adının konması*. Sebep: ton kuralı
zaten aynı şeyi gösteriyor — yaşanabilir bir dünya, devralınmış bir çürüme, korunacak
tek tek insanlar. Omurgayı adıyla ilan etmek oyuncuya hikayenin temasını peşinen
söylemek oluyor, ve sayfa 1'in işi bu değil.

*Uygulama:* sayfa 1'in kapanış paragrafı ("Birinci Perde'nin omurgası **Miras**…")
karttan çıkar. Onun yerine hiçbir şey konmaz — sayfa ton kuralıyla biter. Miras
DM tarafında, `dmNotes`'ta bir cümleyle kalabilir.

## 2. `lore` — 4 kart

Sadece giriş kartının ve ilk bölümlerin dayandığı dördü. Gerisi planlamada.

| Kart | Durum | Dayanak / engel |
|---|---|---|
| **İrade Çağı** — tanrıların kesilmesi, özgürlüğün bedeli | ✅ | 02 §2 |
| **Tanrılar ve fısıltı** — bant genişliği kalmamış sevgi | ✅ | 02 §5.3 |
| **Blight — bilinen hali** | ✅ | 02 §5.1 cephe kuralı. **#14 coğrafya çelişkisi kapandı**: hastalık Meridia'ya kuzeyden değil **ikinci kıtadan** taşındı (act1.md §3.1), o yüzden Gümüşsu'nun güneyde olması çelişki değil. Kartta yön verilmez, *taşıyıcı* verilir |
| **İkinci Kıta — bilinen hali** | 🟡 | act1.md §3.1: hastalığın geldiği yer, üçlünün kaçtığı yer. **Adı yok** — kart adı konana kadar `location` ikizi de bekler |

DM sırları ayrı kart değil, ilgili kartın `secrets` alanı (README §4.5).

**Çıkarılan kart (KARAR, 2026-09-09 2. tur):** *Adlandırma Doktrini'nin oyuncuya
görünen yüzü* listeden **kalktı.** "Köyde halk dili, kurumda Latin" diye bir kanon
yok; adlar karışık ve öyle kalıyor (act1.md §3). Doktrin bölümüne sonra dönülecek —
o zaman bir `lore` kartı gerekip gerekmediği yeniden bakılır. Kart yazılmadığı için
giriş kartının **Sözlük** sayfası da bir dil ayrımı anlatmaz, sadece kelime açar.

## 2b. `location` — dünya ölçeği, 3 kart

Kart eşiği gereği kıtaların da kartı var; Act 1'in yerleri bunların altına
`parent_location_ref` ile bağlanır ve zincir kırılmaz.

| Kart | Üst | Durum | Not |
|---|---|---|---|
| **Aegis** — dünya | — | ✅ | README §1. Kökü tutan kart; altında iki kıta |
| **Meridia** — kıta | Aegis | ✅ | Act 1'in tamamı burada. Sancak Kaydı'nın geçerli olduğu yer |
| **İkinci Kıta** | Aegis | 🟡 | act1.md §3.1: Blight oradan geldi, üçlü oradan kaçtı. **Adı yok** (M5). Perde bu kıta ufukta görülünce biter (06 #12) — yani kart Act 1'in *son karesi* |

Bölge/güzergah kartları (Cinervik · Argenfon · Votumar · Ravenhall) henüz yazılmıyor:
ikisi ad kararı bekliyor, ikisi Act 1'de yer alıp almadığı belli değil
([`act1-kartlar.md`](act1-kartlar.md) planlama başlığı).

## 3. `background` — 9 kart ✅

act1.md §2'nin dokuzu. **Hepsinin mekaniği yazıldı (2026-09-09), dokuzu da
yazılabilir.**

| Kart | Durum | Not |
|---|---|---|
| **Arşivci** · **Lonca Üyesi** · **Mertebeli Lonca Çocuğu** · **Sihir Loncası Öğrencisi** · **Lonca Ajanı** · **Rıhtım İşçisi** · **Gemi Kaptanı** · **Paladin Askeri** · **Paladin Rütbelisi** | ✅ | act1.md §2 tablosu: yetenek seçimi · 2 skill · tool · origin feat · eşya · kurgusal eksi |

Kapanan iki karar (act1.md §9):

1. **Evrene özel *feature* yok.** `background` sözleşmesinde serbest mekanik
   yazacak alan yok (`world-blueprint.md` §3.22). Feature'ın işini **eşya + kurgu**
   yapıyor; "artı mekanik, eksi kurgusal" kuralı bozulmuyor çünkü artı zaten
   SRD paketinden geliyor.
2. **Zorunlu alanların hepsi SRD ref'i.** `granted_skill_refs` ·
   `ability_score_options` · `asi_distribution_options` (`+2/+1`, `+1/+1/+1`) ·
   `origin_feat_ref`. Sapma yok, yani `--check` bu dokuzda hiçbir şeye takılmaz.

## 4. Background başlangıç eşyaları — 13 kart ✅

**KARAR (2026-09-09, 2. tur — önceki kararın tersi): her background eşyası kendi
kartını alır.** Gerekçe act1.md §2'de: eşya dekorasyon değil **kapı**, ve kapının ne
açtığı SRD'nin `Signet Ring` satırında yazmıyor. Aynı sebeple arşivcinin çantasındaki
**her kitap ayrı kart**.

| Kart | Kategori | SRD muadili | Hangi background | Durum |
|---|---|---|---|---|
| **Tasnif Çantası** | `adventuring-gear` | Case, Map or Scroll | Arşivci | ✅ |
| **Kayıt Elifbası** | `adventuring-gear` | Book | Arşivci | ✅ |
| **Sancak Fihristi** | `adventuring-gear` | Book | Arşivci | ✅ |
| **Lonca Mührü** | `trinket` | Signet Ring | Lonca Üyesi | ✅ |
| **Lonca Rozeti** | `trinket` | — (yeni nesne) | Lonca Üyesi | ✅ |
| **Aile Mührü** | `trinket` | Signet Ring | Mertebeli | ✅ |
| **Mertebe Kaftanı** | `adventuring-gear` | Clothes, Fine | Mertebeli | ✅ |
| **Öğrenci Defteri** | `adventuring-gear` | Spellbook | Sihir Loncası Öğrencisi | ✅ |
| **Sahte Mühür** | `trinket` | Signet Ring | Lonca Ajanı | ✅ |
| **Yük Kancası** | `adventuring-gear` | Grappling Hook | Rıhtım İşçisi | ✅ |
| **Seyir Defteri** | `adventuring-gear` | Book | Gemi Kaptanı | ✅ |
| **Kışla Künyesi** | `trinket` | Emblem (Holy Symbol) | Paladin Askeri | ✅ |
| **Emir Mührü** | `trinket` | Signet Ring + Sealing Wax | Paladin Rütbelisi | ✅ |

**Yazım kuralı:** kart evrenin adıyla yazılır, SRD muadili yalnız `description`'da
anılır ("SRD `Signet Ring` muadili") — ayrıca ref'lenmez, yoksa aynı nesne iki kez
envantere girer. `default_inventory_refs` SRD'ye değil **bu kartlara** ref verir;
hepsi pack-içi hard ref olur.

**SRD'de kalanlar:** aletler (`Cartographer's Tools` · `Calligrapher's Supplies` ·
`Gaming Set` · `Alchemist's Supplies` · `Forgery Kit` · `Carpenter's Tools` ·
`Navigator's Tools` · `Smith's Tools`), `Rope`, `Spear`. Bunların evrene özel bir
anlamı yok — kart açmak boş kart açmak olurdu.

**İçerik sonraya (KARAR).** Kitapların ve defterlerin *içi*, rozetin nakşı, künyenin
ibaresi bu turda yazılmadı. Kart adı, kategorisi ve **neyi açtığı** yazıldı; gerisi
ilgili kurum (Lonca · Sancak Kaydı · Paladin düzeni) yazılırken doldurulur.

**Mühür, bu evrenin merkezî nesnesi.** Sancak Kaydı'nda mühür hukuki kimliktir;
mühürlü yüzük "kayıtlıyım" demektir. On üç kartın **dördü** mühür, ve act1.md
§3.3'ün **mührü eğelenmiş yüzüğü** onların tam tersidir — o dört karttan birini
taşıyan PC yüzüğü zar atmadan okur. Background eşyası ile perdenin kanıtı aynı
sistemin iki ucu.

## 5. `species` — 0 kart (bloke), ama ref serbest

**Yeni ırk kartı yazılmaz.** 06 #11 açık: ırksal özellikler simyacı
güçlendirmesinden mi geliyor. Kapanmadan yazılan her ırk kartı yeniden yazılır
(README §3.2). Karakter yaratmayı doğrudan etkilediği için burada duruyor —
kapanması gereken ilk kararlardan.

**Ayrım (2026-09-09):** blok *yazmayı* engelliyor, *ref vermeyi* değil. SRD'de adı
birebir olan bir ırka `species_ref` ile referans verilebilir ve verilir — Act 1'in
üçlüsü böyle: iki `Halfling`, bir `Tiefling` (act1.md §3.1). Bu, 06 #11'i
etkilemez: soru "ırksal özellik nereden geliyor", "hangi ırklar var" değil.

## 6. Kural kartı — 1 ✅

| Kart | Kategori | Durum | Not |
|---|---|---|---|
| **Blight — Enfeksiyon** | `curse` | ✅ | act1.md §4 — bulaşma DC'si, üç evre, üç başarı/üç başarısızlık, tedavi. Perdenin **tek** kural sapması |

**Kategori kararı (2026-09-09): `curse`, `applied-condition` değil.** Sebep şema:
`applied-condition` zorunlu `condition_ref` ister ve Blight bir SRD condition'ı
değil. `curse` ise `trigger` · `effect` · `mechanical_notes` · `removed_by`
alanlarını serbest bırakıyor (`world-blueprint.md` §3.10) — evre tablosu ve DC'ler
oraya sığıyor.

**Ad ayrımı:** `curse/Blight — Enfeksiyon` = kural kartı (DM). `lore/Blight —
Bilinen Hali` = halkın bildiği yüzü (oyuncu). İkisi ayrı kart, birbirine linkli.

Sapma işareti zorunlu (README §6.5): bu, 5e'nin üstüne eklenen bir kural.

## 7. `monster` — 1 jenerik kart

| Kart | Durum | Not |
|---|---|---|
| **Dönüşmüş** (jenerik Blight'lı köylü) | ✅ | act1.md **§5.1'de statblock yazıldı**: CR 1/2, AC 12, HP 22, Pençe +5 (1d8+3), *Acıyı Tanımaz* + *Bulaştıran Yara* (CON DC 12). Act 1'in üç Dönüşmüş kartı bunun adlandırılmış hâli |

Act 1'in üçü ırkıyla türetilir: iki halfling (Small, HP 18, CR 1/2) ve bir tiefling
(HP 30, ateşe direnç, CR 1) — [`act1-kartlar.md` §3](act1-kartlar.md).

SRD'de birebir adı olan hiçbir şey tekrar yazılmaz, ref verilir.

## Sayım

| Kategori | ✅ | 🟡 | ⬜ | Toplam |
|---|---|---|---|---|
| `campaign` | 1 | — | — | 1 (5 sayfa) |
| `lore` | 3 | 1 | — | 4 |
| `location` (dünya ölçeği) | 2 | 1 | — | 3 |
| `background` | 9 | — | — | 9 |
| eşya (background) | 13 | — | — | 13 |
| `species` | — | — | 0 | bloke *(ref vermek serbest)* |
| kural kartı (`curse`) | 1 | — | — | 1 |
| `monster` | 1 | — | — | 1 |
| **Toplam** | **30** | **2** | **0** | **32** |

Act 1 listesiyle birlikte toplam **61 kart** (30 + 32, `curse` iki listede de
görünüyor, bir kez sayıldı); bugün yazılabilir olan **59**. Bekleyen iki kartın da
engeli aynı: **İkinci Kıta'nın adı yok** (`lore` + `location` ikizi).

---

## Sonraki bölümler için planlama

Yazılmayacak, sadece unutulmasın diye duruyor.

**Dünya lore'u** — `lore` kartları: Sansürlü resmi tarih (halkın bildiği versiyon,
revizyon sonrası yeniden yazılmalı) · Fraksiyonlar (lonca · paladin düzeni · Occulus ·
konsey · Kara Gemiler, 09 §8 adım 2) · Kronoloji (`03` boş) · Sancak Kaydı (statü
sistemi, 10 M1: "omurga, M2–M17 buna bağlı") · Mesafeler ve yol süreleri (10 M12,
"bu olmadan tempo hesaplanamaz").

**Act üstü NPC'ler** — Başkumandan / Suretsiz (Lucian'ın eli, baş kötü **değil**;
gerçek kimliği `secrets`) · Lucian (06 #10 açık: yaşıyor / kurum olarak işliyor /
yarı-varlık) · Occulus arşivcisi (belgesel kapının kurumsal yüzü).

**Jenerik düşmanlar** — `monster` Blight'lı asker · Ele geçirilmiş paladin.

**Blight cephesi** — `environmental-effect`; 02 §5.1, sınır var ve tutuluyor.
Blight bir iklim değil cephe olduğu için harita kararına bağlı (#14).

**Açık kalan kategori kararları** — `class`/`subclass`/`spell` kartı gerekiyor mu,
yoksa ilahi büyü sapması için `lore` notu yeter mi (README §6.5) · `service`/`hireling`
gerekiyor mu (Gizli Liman'ın "iyi para" ekonomisi, act1.md §9 açık 4).
