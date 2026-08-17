# Paket İçerik Uygunluk Taraması — Kontrol Planı ve İlerleme (Stage F1)

**Ölçüt:** `pack_conformance_checklist.md` · **Bulgular:** `pack_conformance_findings.md`
· **Yol haritası:** `open5e_content_audit.md` §6 Stage F

---

## Sonraki adım

> **Şu an:** Checklist **onaylandı** (F0, 2026-08-15), bu plan **onaylandı**
> (F1, 2026-08-17 — §10), bulgu defterinin formatı **onaylandı**
> (F2, 2026-08-17 — `pack_conformance_findings.md`). Sıradaki iş **F3**: önce
> **Pass 0** (korpüs geneli temel ölçüm, §6 tablosunu doldurur), ardından
> **Dalga 0 → built-in SRD paketi**.
>
> Her oturum sonunda, bulgu yazıldıktan sonra: `python3 tool/check_findings.py`.

*(Bu blok her oturum sonunda güncellenir. Yeni bir oturum önce bunu okur.)*

---

## 1. Neden bir plana ihtiyaç var

Tarama üç şeyi aynı anda yapmak zorunda:

1. **Eksiksiz olmak** — 19 paket, 21.839 varlık, 59 kategori. Atlama, taramanın
   varlık sebebini yok eder.
2. **Belleği doldurmamak** — tek bir paket dosyası 3,3 MB. Bir paketi baştan sona
   okumak, o oturumda başka hiçbir şey yapılamaması demektir.
3. **Kendi kendine düzeltmeye kalkmamak** — bulunan her eksik, kendi başına bir
   karar gerektirir (silmek mi, bağlamak mi, boş bırakıp gerekçe yazmak mı).

Bu üçünü aynı anda tutan tek yol: **önce araç, sonra örneklem, hep yazarak.**

## 2. Altın kurallar

- **K1 — Hiçbir şey düzeltilmez.** Bulgu bulunur → `findings` dosyasına yazılır →
  danışılır. Kod, asset veya şema değişikliği bu taramanın parçası değil.
- **K2 — Paket dosyası asla baştan sona okunmaz.** `cat *.pkg.json` yasak.
  Okuma birimi: **tek kategoriden en fazla 5 varlık**, tam hâliyle.
- **K3 — Sayım araçtan, yargı okumadan gelir.** "Kaç tanesi dolu" sorusunun cevabı
  `audit_packs`'ten alınır; "dolu olan doğru mu" sorusunun cevabı örneklemden.
- **K4 — Korpüs geneli kontroller bir kez çalışır.** `gate_packs`, `verify_packs`,
  `dupe_census` ve test paketleri paket başına tekrar tekrar çalıştırılmaz;
  Pass 0'da bir kez çalışır, çıktıları pakete atfedilir.
- **K5 — Her paket bitince yazılır.** Sonraki pakete geçmeden `findings` dosyası
  ve aşağıdaki ilerleme tablosu güncellenir. Yarım kalan tarama, yapılmamış
  taramadır.
- **K6 — Bir oturumda bir paket.** Bağlam %60'ı geçtiyse paket bitmemiş olsa bile
  durulur, "Sonraki adım" bloğu yazılır, oturum kapanır.
- **K7 — Bilinen kabuller bulgu değildir.** Yol haritasının yazılı gerekçesi olan
  boşluklar (⚪ / ⛔) yeniden bulgu olarak açılmaz — ama gerekçe **bulunamıyorsa**
  bulgudur (checklist C8).

## 3. Taramanın iki geçişi

### Pass 0 — Korpüs geneli temel (bir kez, tarama başında)

Checklist maddelerinin çoğu zaten korpüs geneli bir kapıyla ölçülüyor. Bunlar
paket paket tekrarlanmaz; bir kez çalışır, sonucu bu dosyaya yazılır ve
**yalnızca hata çıkarsa** ilgili pakete atfedilir.

```sh
cd flutter_app

# Alan sayımı — 408 yuvanın kaçı dolu (checklist A2, C1–C5)
dart run tool/open5e_import/bin/audit_packs.dart --markdown
dart run tool/open5e_import/bin/audit_packs.dart --builtin --markdown

# Kopya / bağlantı (checklist B1, B2, B4)
dart run tool/open5e_import/bin/dupe_census.dart
dart run tool/open5e_import/bin/dupe_census.dart --list-builtin-same
dart run tool/open5e_import/bin/dupe_census.dart --list-shared

# İlişkisel kapı (checklist C4, D3)
dart run tool/open5e_import/bin/gate_packs.dart --examples 20

# Kaynakla karşılaştırma (checklist D1, D2, A3) — snapshot gerekir
dart run tool/open5e_import/bin/verify_packs.dart --data ../open5e-api-staging/data

# Tier-0 sözlüğü (checklist C7) — küçük dosya, tam okunabilir
cat assets/open5e_packs/unmapped_report.json

# Kullanıcıya ulaşma katmanı (checklist E1, F1–F4)
flutter test test/domain/services/bundled_pack_resolve_test.dart
flutter test test/application/services/pack_install_roundtrip_test.dart
flutter test test/presentation/pack_field_render_test.dart
flutter test test/presentation/character_creation/wizard_pack_families_test.dart
flutter test test/presentation/entity_link_navigation_test.dart
```

**Pass 0 çıktısı bu dosyaya §6'ya yazılır.** Beklenen temel (2026-08-15 itibarıyla,
yol haritasından):

| Kapı | Beklenen |
|---|---|
| `audit_packs` | 136 / 408 dolu yuva |
| `dupe_census` A "same text" | 0 |
| `dupe_census` B "textually identical" | 189 ad / 193 kopya (**karar gereği**, ihmal değil) |
| `dupe_census` C | 4.074 ref / **0 dangling** |
| `gate_packs` | **0 ihlal** |
| `verify_packs` | 68.561 ok / **0 disagree** / **0 absent** / 3.303 unsourced / **17.268** unverifiable (F0 2026-08-15'te yeniden ölçtü; V1'in 14.383'ü `monster.tags_line` kuralından önceydi) |
| `unmapped_report.json` | 3 satır |
| M1 | 73 çift / 247 iddia / 1 kısmi |
| Korpüs | 21.839 varlık (19 paket) + 2.719 (built-in) — **`audit_packs`'in paydası 21.832**, dışarıda 6 `language` + 1 `size` (F0) |

**Bu sayılardan sapma, taramanın ilk bulgusudur** — çünkü sapma, yol haritasının
kapandığı günden bu yana bir şeyin kaydı olmadan değiştiği anlamına gelir.

### Pass 1 — Paket paket örneklem (asıl iş)

Pass 0'ın **göremediği** şeyler burada bakılır. Araçlar "alan dolu mu" der;
"doldurulan şey doğru şey mi" demez. Paket başına bakılacaklar:

| Checklist | Paket başına ne yapılır |
|---|---|
| A1 | Pakette geçen kategori slug'larının tekil listesi (tek komut) |
| A3 | Örneklemdeki her alanı "bu kaynaktan mı geldi" diye sorgula |
| A4 | Örneklemdeki ad yazımları + ref hedeflerinin yazımı |
| A5 | Pass 0'ın ⚠ satırlarından bu pakete düşenleri doğrula |
| B3 | Örneklemde **düzyazıda duran ama ref olması gereken** ne var |
| B5 | Paketin `metadata` bloğu (küçük okuma) |
| C1–C7 | Kategori bazında doluluk + örneklem semantiği |
| C8 | Bu pakette 0% kalan her alanın §5 / §5.8'de cause code'u var mı |
| G1–G3 | `manifest.json`'daki paket satırı (küçük okuma) |

---

## 4. Bir paket nasıl taranır — 7 adım

> **Paket dosyasının şekli** — elle bir şey yazmadan önce bilinmesi gereken üç
> nokta (F1 ölçtü; planın ilk hâlindeki snippet'ler üçünü de yanlış varsayıyordu):
> `entities` bir **liste değil, id → varlık sözlüğü**; kategori anahtarı
> `category` değil **`type`**; alanlar `fields` değil **`attributes`** altında.
> Ayrıca bu makinede `python` yok, **`python3`** var.

### Adım 1 — Paketi izole et (araçları tek pakete daraltmak için)

Araçlarda `--pack` bayrağı **yok**; `--packs <dizin>` var ve dizindeki
`*.pkg.json` dosyalarını tarıyor. O yüzden tek paketi ayrı bir dizine kopyala —
ve **`--only` olmadan çalıştırma**: `audit_packs` tablolanan 12 kategorinin
hepsini basar, 35 varlıklık bir pakette bile **474 satır** (bütçenin %79'u);
pakette gerçekten bulunan kategorilerle daraltınca **221**.

```sh
cd flutter_app
mkdir -p /tmp/one && rm -f /tmp/one/*.pkg.json
cp assets/open5e_packs/open5e-toh.pkg.json /tmp/one/

# --only listesini Adım 2 hazır basıyor
dart run tool/open5e_import/bin/audit_packs.dart --packs /tmp/one --markdown \
    --only background,feat,species,spell,subclass,subspecies
dart run tool/open5e_import/bin/gate_packs.dart  --packs /tmp/one --examples 20
```

> **Uyarı 1.** `dupe_census` paketler **arası** kopyayı ölçtüğü için tek pakete
> daraltılmaz — o hep korpüs genelinde çalışır (Pass 0).
>
> **Uyarı 2.** `verify_packs` için daraltma yolu `--doc <belge slug>` +
> `--only <kategori>` (ölçüldü: `--doc a5e-gpg` 3 saniye). Ama **kural tablosu
> 9 kategori tanıyor** — `monster`, `spell`, `magic-item`, `feat`, `class`,
> `subclass`, `species`, `subspecies` ve **kuralı boş olan `background`**.
> `creature-action`, `trait`, `language`, `size` ve `background` için çıktı
> `0 ok / 0 disagree`'dir: **temiz değil, ölçülmemiş** demektir. Dalga 1'in ilk
> iki paketi (`a5e-gpg`, `a5e-ddg`) sadece `background` taşıdığı için A3'ün
> tamamı orada **okumayla** yapılır.

### Adım 2–5 — Tek araç: `tool/scan_pack.py`

Planın ilk hâlindeki dört ayrı snippet tek bir okuyucuya toplandı; her oturumda
yeniden yazılan bir heredoc, taramanın kendisinden daha kırılgandı.

```sh
cd flutter_app
python3 tool/scan_pack.py --selfcheck          # araç hâlâ doğru mu (0,1 sn)

python3 tool/scan_pack.py toh                  # Adım 2 + Adım 5
python3 tool/scan_pack.py toh --cat spell      # Adım 3 + Adım 4
python3 tool/scan_pack.py toh --cat spell --picks 3
```

- **`scan_pack.py <slug>`** → paket adı, varlık sayısı, kategori haritası, Adım
  1'e yapıştırılacak hazır `--only` satırı ve `metadata` bloğu.
  Checklist **A1, B5, G1–G3** (+ `assets/open5e_packs/manifest.json`'daki karşılığı).
- **`--cat <kategori>`** → o kategorinin alan doluluk tablosu (checklist **A2,
  C1–C5**; tabloda hiç görünmeyen şema alanı = `0/n` → **C8** adayı) ve ardından
  örneklem: ilk, son ve aradan üç varlık — indeksle seçildiği için tekrarlanabilir.

**Okuma bütçesi: paket başına ~600 satır**, ve bu artık ölçülmüş bir sayı:

| Kategori | Varlık başına satır (`scan_pack`) | Ham `indent=1` JSON (medyan) |
|---|--:|--:|
| `trait` / `creature-action` | 11–13 | 16–18 |
| `background` | 12–14 | 69 |
| `subclass` / `feat` | 18 | 27–48 |
| `magic-item` | 19 | 26 |
| `species` / `subspecies` | 20 | 33–50 |
| `class` | 21 | 237 |
| `spell` | 28–31 | 65 |
| **`monster`** | **50** | **236** |

Fark canavarda: ham JSON `trait_refs` / `action_refs` / `skill_bonuses.rows`
dizilerini satır satır bastığı için 5 canavarlık bir örneklem **tek başına 691
satır** — bütçenin üstü. `scan_pack.py` skaler dizileri tek satıra topladığı için
aynı örneklem doluluk tablosuyla birlikte **285 satır**, ve `tob3`'ün dört
kategorisinin tamamı **433** (ham hâli 872). Yani "kategori başına 5 varlık"
kuralı ile bütçe artık çelişmiyor. Ölçülen tek istisna **`toh`**: 6 kategori ×
5 varlık = **670 satır** → `--picks 3` ile **437**. Kural: bütçe aşılıyorsa
**örneklem küçültülür, paket bölünmez.**

Örneklemde bakılacaklar: **A3** (bu değer kaynaktan mı geliyor, yoksa makul
görünen bir uydurma mı), **A4** (ad yazımı), **B3** (düzyazıda duran ref adayı),
**C3/C6** (alan semantiği, `mechanical_notes` yönlendirmesi).

### Adım 6 — Bulguları yaz

Her bulgu `pack_conformance_findings.md`'ye, oradaki formatla. Bulgu yoksa da
yazılır: "temiz" de bir sonuçtur ve tekrar taranmasını engeller.

### Adım 7 — İlerleme tablosunu ve "Sonraki adım" bloğunu güncelle

Sonra dur. Düzeltme yok (K1).

---

## 5. Tarama sırası ve ilerleme tablosu

Sıra **rastgele değil**: önce bağlantıların hedefi (built-in), sonra karakter
yaratmayı besleyen paketler (yol haritasının 🔴 satırlarının çoğu orada), sonra
tek kategorili büyük paketler, en sona da birbirinin tekrarı olan canavar
paketleri.

**Durum:** ⬜ başlanmadı · 🟦 devam · ✅ temiz · ⚠️ bulgu var · ⛔ engellendi

### Dalga 0 — Bağlantı hedefi

| Paket | Varlık | Kategoriler | Durum | Tarih | Bulgular |
|---|--:|---|:--:|---|---|
| **built-in SRD** (`srd_core/` + Tier-0 seeds) | 2.719 | 59 kategori (2.350 Tier-1 + 369 Tier-0) | ⬜ | — | — |

> Neden ilk: her paketin yumuşak ref'i buraya iniyor. Burada bir ad yanlışsa
> 19 paketin ref'i birden ölür.

### Dalga 1 — Karakter yaratma paketleri (küçükten büyüğe)

| Paket | Varlık | Kategoriler | Durum | Tarih | Bulgular |
|---|--:|---|:--:|---|---|
| `open5e-a5e-gpg` | 2 | background 2 | ⬜ | — | — |
| `open5e-a5e-ddg` | 4 | background 4 | ⬜ | — | — |
| `open5e-open5e` | 22 | subclass 17, spell 2, background 2, subspecies 1 | ⬜ | — | — |
| `open5e-tdcs` | 35 | trait 11, creature-action 10, background 5, monster 4, subclass 4, feat 1 | ⬜ | — | — |
| `open5e-toh` | 239 | spell 91, subclass 76, subspecies 29, background 19, feat 13, species 11 | ⬜ | — | — |
| `open5e-a5e-ag` | 455 | spell 371, feat 59, background 21, subclass 3, class 1 | ⬜ | — | — |

> `open5e-bfrd`'nin `class` 1 + `subclass` 1 satırı da **bu dalgada** bakılır
> (ucuz); canavarları Dalga 4'te.

### Dalga 2 — Büyü paketleri

| Paket | Varlık | Kategoriler | Durum | Tarih | Bulgular |
|---|--:|---|:--:|---|---|
| `open5e-kp` | 31 | spell 31 | ⬜ | — | — |
| `open5e-wz` | 43 | spell 43 | ⬜ | — | — |
| `open5e-deepmx` | 64 | spell 64 | ⬜ | — | — |
| `open5e-spells-that-dont-suck` | 180 | spell 180 | ⬜ | — | — |
| `open5e-deepm` | 515 | spell 515 | ⬜ | — | — |

> Bu dalganın ortak riski tek: **U2'nin ölçtüğü 85 görünmez büyü** ve
> `class_refs` / `tags` ikilisi (checklist B3, F3).

### Dalga 3 — Sihirli eşyalar

| Paket | Varlık | Kategoriler | Durum | Tarih | Bulgular |
|---|--:|---|:--:|---|---|
| `open5e-vom` | 1.063 | magic-item 1.063 | ⬜ | — | — |

> Bilinen giriş noktası: `cost_gp` ve §5.8'in 🔴 `M` attunement / charges /
> body-slot bloğu (checklist C5, A5). **F1 düzeltmesi:** `0.00` olan **kaynak**
> sütunu (`MagicItem.cost`, 1.063/1.063), pakette yazan değil — ölçüldü, pakette
> `cost_gp` **1.063 satırın hepsinde `null`**, yani alan `0/1.063` dolu. Yani
> aranacak şey "her yerde 0 fiyat" değil, **hiç fiyat olmaması**; §5.8 buna ⛔
> gerekçesi yazdığı için tek başına bulgu değildir (K7).

### Dalga 4 — Canavar paketleri (yapıları birbirinin tekrarı)

| Paket | Varlık | Kategoriler | Durum | Tarih | Bulgular |
|---|--:|---|:--:|---|---|
| `open5e-ccdx` | 2.426 | creature-action 1.148, trait 921, monster 356, language 1 | ⬜ | — | — |
| `open5e-bfrd` | 2.473 | creature-action 1.338, trait 772, monster 360, language 1, class 1, subclass 1 | ⬜ | — | — |
| `open5e-tob2` | 2.607 | creature-action 1.209, trait 1.014, monster 383, language 1 | ⬜ | — | — |
| `open5e-tob` | 2.734 | creature-action 1.303, trait 1.039, monster 391, language 1 | ⬜ | — | — |
| `open5e-tob3` | 2.787 | creature-action 1.577, trait 812, monster 397, language 1 | ⬜ | — | — |
| `open5e-a5e-mm` | 3.071 | creature-action 1.655, trait 829, monster 586, size 1 | ⬜ | — | — |
| `open5e-tob-2023` | 3.088 | creature-action 1.658, trait 1.021, monster 408, language 1 | ⬜ | — | — |

> Bu dalgada örneklem **kategori başına 5 canavar + o canavarların çocuk
> satırları** demektir — çocuk satırları ayrıca örneklenmez, ebeveyniyle okunur.
> `tob` ⟷ `tob-2023` çifti ve `a5e-mm` ⟷ `bfrd` çifti L4'ün 188 kopyasının
> kaynağı; checklist B2'nin istisnası burada test edilir.

**Toplam:** 1 built-in + 19 official = **20 tarama birimi.**

> **F1 doğrulaması (2026-08-17).** Yukarıdaki dört dalganın **19 satırının
> tamamı** — varlık sayısı ve kategori dağılımı — `assets/open5e_packs/`'ten
> yeniden sayıldı: **hepsi birebir tutuyor, toplam 21.839.** Built-in satırı da
> `audit_packs --builtin` ile sayıldı: **59 kategori, 2.719 varlık**, ve
> 2.350/369 ayrımı da doğru (`resource-pool`'a kadarki 39 Tier-0 kategorisi tam
> **369** ediyor).

---

## 6. Pass 0 temel ölçümü (tarama başlayınca doldurulacak)

| Kapı | Beklenen | Ölçülen | Tarih | Not |
|---|---|---|---|---|
| `audit_packs` dolu yuva | 136 / 408 | — | — | — |
| `audit_packs --builtin` | — | — | — | — |
| `dupe_census` A | 0 | — | — | — |
| `dupe_census` B | 189 / 193 | — | — | — |
| `dupe_census` C | 4.074 / 0 dangling | — | — | — |
| `gate_packs` | 0 ihlal | — | — | — |
| `verify_packs` | 68.561 / 0 / 0 | — | — | — |
| `unmapped_report.json` | 3 | — | — | — |
| M1 çiftleri | 73 / 247 / 1 | — | — | — |
| Korpüs | 21.839 + 2.719 | — | — | — |

---

## 7. Oturum devri (handoff)

Her oturum şunu bırakır, sonraki oturum şunu okur:

1. **"Sonraki adım" bloğu** (bu dosyanın en üstü) — hangi paket, hangi adım.
2. **İlerleme tablosu satırı** — durum + tarih + bulgu ID'leri.
3. **`findings` dosyasındaki yeni satırlar** — kanıtıyla birlikte.

Sonraki oturum **bu üçü dışında hiçbir şeyi yeniden okumak zorunda kalmamalı.**
Kalıyorsa, devir eksik yazılmış demektir.

## 8. Bulgudan sonra ne olur

Tarama düzeltmez; **iş kalemi üretir.** Bir bulgu kapatılırken izlenecek yol:

1. Bulgu `findings` dosyasında **durum: danışılacak** ile durur.
2. Karar alınır (sen verirsin): düzelt / gerekçe yaz / kapsam dışı.
3. "Düzelt" çıkarsa bulgu, yol haritasında **yeni bir faz** olarak dosyalanır
   (`open5e_content_audit.md` §6) — bu taramanın içinde değil.
4. Faz kapandığında bulgu **durum: kapandı** olur ve hangi fazın kapattığı yazılır.
5. Yol haritasının üç kapısı yeni faz için de geçerli: ref kapısı, okuyucu kapısı,
   repo kapısı (`flutter analyze && flutter test` + vault notu + changelog satırı).

## 9. Ne zaman biter

- 20 tarama biriminin hepsi ✅ veya ⚠️ (⬜ kalmamış),
- her ⚠️ bulgusunun bir kararı var (düzeltildi / gerekçesi yazıldı / kapsam dışı),
- Pass 0 kapıları tarama sonunda **başladığı yerde veya daha iyi**,
- ve `open5e_content_audit.md` "Done when" bölümündeki beş çıktının hiçbiri
  bu tarama yüzünden yeniden açılmamış.

---

## 10. F1 onayı — 2026-08-17

**Onaylandı.** Sıra, tahta ve devir protokolü kullanıma hazır. F0'ın kuralı
burada da uygulandı: onay **prosedürü çalıştırarak** verildi, okuyarak değil — ve
prosedür ilk hâliyle **çalışmıyordu.**

**Çalıştırılarak doğrulananlar.**

- **Sıra ve tahta.** 19 paket satırının varlık sayısı ve kategori dağılımı
  asset'lerden yeniden sayıldı — **19'u da birebir**, toplam **21.839**.
  Built-in satırı: `audit_packs --builtin` → **59 kategori / 2.719 varlık**,
  Tier-0 ayrımı **369** (tam olarak `ability`…`resource-pool` arası 39 kategori),
  Tier-1 **2.350**. Sıra yol haritasının F1 çıkışıyla aynı: built-in → 6 chargen
  → 5 büyü → `vom` → 7 canavar = 19.
- **İzolasyon gerçekten çalışıyor.** `audit_packs --packs <dizin>` ve
  `gate_packs --packs <dizin>` tek paketle koştu (`tdcs`: gate green).
  `verify_packs --doc a5e-gpg --only background` **3 saniyede** döndü.
- **Snapshot yerinde:** `../open5e-api-staging/data` var, yani Pass 0'ın
  `verify_packs` adımı engelli değil.

**Onay sırasında planda bulunan dört şey — düzeltildi.**

1. **Adım 2–5'in dördü de çalışmıyordu, üç ayrı sebepten.** `python` bu makinede
   yok (`python3` var); `d['entities']` **liste değil sözlük** (`.get` çağrısı
   `AttributeError` ile patlıyor); alanlar `fields` değil **`attributes`** altında
   ve kategori anahtarı `category` değil `type` — yani snippet düzeltilse bile
   doluluk tablosu her alanı **0** sayardı ve "paket boş" diye 20 uydurma bulgu
   üretirdi. Dört snippet tek bir okuyucuya toplandı: **`tool/scan_pack.py`**
   (`--selfcheck` dahil, dosya şekli değişirse tarama başlamadan patlar).
2. **Bütçe ile örneklem kuralı çelişiyordu.** "Paket başına ~600 satır" ve
   "kategori başına 5 varlık, tam hâliyle" aynı anda tutmuyordu: ham `indent=1`
   JSON ile 5 canavar **691 satır** — tek kategori, tek başına bütçenin üstü — ve
   `tob3`'ün dört kategorisi toplam **872**. Sebep uuid dizilerinin satır satır
   basılması. `scan_pack.py` skaler dizileri tek satıra topluyor: aynı 5 canavar
   doluluk tablosuyla birlikte **285**, `tob3`'ün tamamı **433**. Ölçülen satır
   maliyeti tablosu §4'e yazıldı. Kalan tek taşma **`toh`** (6 kategori, 5'er
   varlık = **670**); `--picks 3` onu **437**'ye indiriyor — kuralın "aşılıyorsa
   örneklem küçültülür" cümlesi artık gerçekten uygulanabilir bir kural.
3. **`--only` yoksa bütçe daha ilk komutta gidiyor.** `audit_packs --packs` tek
   paketle bile tablolanan 12 kategorinin hepsini basıyor: 35 varlıklık `tdcs`
   için **474 satır**, pakette bulunan 6 kategoriye daraltınca **221**.
   Adım 1 artık `--only` ile yazılı, listeyi de Adım 2 basıyor.
4. **`verify_packs`'in "0 disagree"i her kategoride aynı şeyi söylemiyor.**
   Kural tablosu **9 kategori** tanıyor ve `background`'ınki **boş**;
   `creature-action`, `trait`, `language`, `size` hiç yok. Ölçüldü:
   `--doc a5e-gpg --only background` → `2/2 eşleşti, ok 0`. Bu "temiz" değil
   **"ölçülmemiş"** demek — Dalga 1'in ilk iki paketi (`a5e-gpg`, `a5e-ddg`,
   yalnız `background`) tamamen okumaya kalıyor. §4 Uyarı 2'ye yazıldı.

**Ayrıca ölçütte bir şey düzeltildi.** Checklist **C5** ve bu planın Dalga 3
notu, §5.8'in "`MagicItem.cost` 1.063/1.063 `0.00`" cümlesini **pakette yazan
değer** sanıyordu. Pakette `cost_gp` **1.063'ünde de `null`** (0/1.063 dolu);
`0.00` olan kaynağın sütunu. Eski hâliyle tarayıcı "her satırda 0.00" arar,
bulamaz ve `vom`'a kayıp-değer bulgusu yazardı.

**Değişmeyen karar.** Tarama içinde hiçbir şey düzeltilmez (K1 / F4). Bu onayda
dokunulanlar **prosedür ve ölçüt**; hiçbir `*.pkg.json` satırı değişmedi.
