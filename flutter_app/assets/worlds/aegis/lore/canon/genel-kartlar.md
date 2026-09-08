# Genel Kartlar — perdeden bağımsız

> **Durum: çalışma listesi.** Hiçbir act'a bağlı olmayan, dünyanın kendisine ait
> kartlar. Act 1'e özgü olanlar → [`act1-kartlar.md`](act1-kartlar.md).

**Kapsam:** şimdilik yalnız **oyun öncesi** (giriş kartı, karakter yaratma) ve
**ilk bölümlerin** gerektirdiği kartlar. Dünyanın geri kalanı en alttaki
*Sonraki bölümler için planlama* başlığında — orada kart yok, plan var.

**Ayrım kuralı:** bir kart yalnız Act 1'de anlamlıysa act listesinde; her perdede
geçerliyse burada.

**Durum kodları:** `✅` yazılabilir · `🟡` kanon kısmi · `⬜` kanon yok, önce karar.

**Adlar geçici, her ad link.** Kural ve linkleme tablosu:
[`act1-kartlar.md` §0](act1-kartlar.md). Giriş kartında da geçerli — sözlükteki her
madde ilgili `lore` kartına linklenir.

---

## 1. `campaign` — 1 kart, giriş bölümü

Tek kart: **Aegis — Meridia**. İçerik `pages[]` listesinde (README §4.5).

| Sayfa | Durum | Dayanak |
|---|---|---|
| **Bu dünyada oynamak** — ton sözleşmesi | ✅ | 02: *karanlık geçmişte ve yapılarda; ışık insanlarda ve bugünde* · *dünya yaşanabilir, ama gidişat kötü* |
| **Masa kuralları** — rol yuvaları, iki taşıyıcı kuralı, sayaç NPC'de | ✅ | Yönerge §3.2 · 09 §7 · 08 §4 |
| **Karakter yaratma** — serbest, tek cümlelik sözleşme | ✅ | act1.md §1 |
| **DM'e** — bilgi eğimi, sır yerleşimi (`secrets`), neyin gizli kalacağı | ✅ | 09 §4 · README §4.5 |
| **Sözlük** — oyuncunun ilk oturumda duyacağı kadarı | 🟡 | Adlandırma Doktrini; M0.2/M0.3 açık |

> **Uyarı:** giriş kartı DM'in kitabı değil, **oyuncunun ilk okuduğu şey.**
> Baş kötünün kim olduğu buraya yazılmaz. Sözlük de dünyayı anlatmaz, ilk
> oturumda geçen kelimeleri açar.

## 2. `lore` — 4 kart

Sadece giriş kartının ve ilk bölümlerin dayandığı dördü. Gerisi planlamada.

| Kart | Durum | Dayanak / engel |
|---|---|---|
| **İrade Çağı** — tanrıların kesilmesi, özgürlüğün bedeli | ✅ | 02 §2 |
| **Tanrılar ve fısıltı** — bant genişliği kalmamış sevgi | ✅ | 02 §5.3 |
| **Blight — bilinen hali** | 🟡 | 02 §5.1 cephe kuralı ✅; **#14 coğrafya çelişkisi açık** |
| **Adlandırma Doktrini'nin oyuncuya görünen yüzü** — halk dili / Latin ayrımı | ✅ | Adlandırma Doktrini · act1.md §3, §7 |

DM sırları ayrı kart değil, ilgili kartın `secrets` alanı (README §4.5).

## 3. `background` — 9 kart

act1.md §2'nin dokuzu. Karar kapalı (5e paketi + evrene özel feature + evrene özel
eşya), kart yok.

Arşivci · Lonca Üyesi · Mertebeli Lonca Çocuğu · Sihir Loncası Öğrencisi ·
Lonca Ajanı · Rıhtım İşçisi · Gemi Kaptanı · Paladin Askeri · Paladin Rütbelisi

Durum `🟡`: her birinin **feature'ı ve eşyası yazılmadı** (act1.md §9 açık 1).
Zorunlu alanlar (`granted_skill_refs`, `ability_score_options`,
`asi_distribution_options`, `origin_feat_ref`) SRD ref'leriyle dolar; sapma sadece
feature + `default_inventory_refs`.

## 4. Evrene özel başlangıç eşyaları — 9 kart

Background başına bir kalem (act1.md §2). Kategori kalemine göre değişir:
`adventuring-gear` (arşiv kitapları, seyir defteri) · `trinket` (lonca mührü) ·
`tool`. Hepsi `⬜` — eşyanın kendisi seçilmedi.

Kural: eşya dekorasyon değil **kapı** — hangi kilidi açtığı kartta yazar, kilit de
linklenir.

## 5. `species` — 0 kart (bloke)

**Yazılmaz.** 06 #11 açık: ırksal özellikler simyacı güçlendirmesinden mi geliyor.
Kapanmadan yazılan her ırk kartı yeniden yazılır (README §3.2). Karakter yaratmayı
doğrudan etkilediği için burada duruyor — kapanması gereken ilk kararlardan.

## 6. Kural kartı — 1

| Kart | Kategori | Durum | Not |
|---|---|---|---|
| **Blight enfeksiyonu** | `applied-condition` | 🟡 | act1.md §4: ~1 ay sessiz → ani patlama → bilinç gider/beden güçlenir. Evrelerin mekaniği yazılmadı |

Sapma işareti zorunlu (README §6.5): bu, 5e'nin üstüne eklenen bir kural.

## 7. `monster` — 1 jenerik kart

| Kart | Durum | Not |
|---|---|---|
| **Blight'lı köylü** | 🟡 | act1.md §4 son evre tarifi var, statblock yok |

SRD'de birebir adı olan hiçbir şey tekrar yazılmaz, ref verilir.

## Sayım

| Kategori | ✅ | 🟡 | ⬜ | Toplam |
|---|---|---|---|---|
| `campaign` | 1 | — | — | 1 (5 sayfa) |
| `lore` | 3 | 1 | — | 4 |
| `background` | — | 9 | — | 9 |
| eşya | — | — | 9 | 9 |
| `species` | — | — | 0 | bloke |
| kural kartı | — | 1 | — | 1 |
| `monster` | — | 1 | — | 1 |
| **Toplam** | **4** | **12** | **9** | **25** |

Act 1 listesiyle birlikte toplam **58 kart**; bugün yazılabilir olan **30**.

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
