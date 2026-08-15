# Paket İçerik Uygunluk Taraması — Kontrol Planı ve İlerleme (Stage F1)

**Ölçüt:** `pack_conformance_checklist.md` · **Bulgular:** `pack_conformance_findings.md`
· **Yol haritası:** `open5e_content_audit.md` §6 Stage F

---

## Sonraki adım

> **Şu an:** Checklist onay bekliyor. Onaydan **önce** hiçbir paket taranmaz.
> Onay geldiğinde ilk iş **Pass 0** (korpüs geneli temel ölçüm), sonra
> **Dalga 0 → built-in SRD paketi**.

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
| `verify_packs` | 68.561 ok / **0 disagree** / **0 absent** / 3.303 unsourced / 14.383 unverifiable |
| `unmapped_report.json` | 3 satır |
| M1 | 73 çift / 247 iddia / 1 kısmi |
| Korpüs | 21.839 varlık (19 paket) + 2.719 (built-in) |

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

### Adım 1 — Paketi izole et (araçları tek pakete daraltmak için)

Araçlarda `--pack` bayrağı **yok**; `--packs <dizin>` var ve dizindeki
`*.pkg.json` dosyalarını tarıyor. O yüzden tek paketi ayrı bir dizine kopyala:

```sh
cd flutter_app
mkdir -p /tmp/one && rm -f /tmp/one/*.pkg.json
cp assets/open5e_packs/open5e-toh.pkg.json /tmp/one/

dart run tool/open5e_import/bin/audit_packs.dart --packs /tmp/one --markdown
dart run tool/open5e_import/bin/gate_packs.dart  --packs /tmp/one --examples 20
```

> **Uyarı.** `dupe_census` paketler **arası** kopyayı ölçtüğü için tek pakete
> daraltılmaz — o hep korpüs genelinde çalışır (Pass 0).
> `verify_packs` için daraltma yolu `--doc <belge>` + `--only <kategori>`.

### Adım 2 — Kategori haritasını çıkar (okuma değil, sayım)

```sh
python -c "
import json,collections
d=json.load(open('assets/open5e_packs/open5e-toh.pkg.json',encoding='utf-8'))
c=collections.Counter(e.get('category') or e.get('type') for e in d['entities'])
print(d['package_name'], sum(c.values()))
for k,v in c.most_common(): print(f'  {k:22} {v}')
"
```

→ Checklist **A1**. Çıkan slug'lar şemada tanımlı mı.

### Adım 3 — Alan doluluk tablosu (yine sayım, içerik değil)

```sh
python -c "
import json,collections
CAT='spell'
d=json.load(open('assets/open5e_packs/open5e-toh.pkg.json',encoding='utf-8'))
rows=[e for e in d['entities'] if (e.get('category') or e.get('type'))==CAT]
n=len(rows); f=collections.Counter()
for e in rows:
    for k,v in (e.get('fields') or {}).items():
        if v not in (None,'',[],{},0): f[k]+=1
print(CAT,n)
for k,v in sorted(f.items(),key=lambda x:-x[1]): print(f'  {k:32} {v:5}/{n}')
"
```

→ Checklist **A2, C1–C5**. `0/n` çıkan alanlar C8'in adayları.

### Adım 4 — Örneklem oku (tek gerçek okuma — sınırı aşma)

Kategori başına **en fazla 5** varlık, tam hâliyle. Seçim: ilk, son ve aradan
üç tane (rastgele değil, tekrarlanabilir olsun diye indeksle).

```sh
python -c "
import json
CAT='spell'; PICKS=5
d=json.load(open('assets/open5e_packs/open5e-toh.pkg.json',encoding='utf-8'))
rows=[e for e in d['entities'] if (e.get('category') or e.get('type'))==CAT]
idx=sorted({0,len(rows)-1,len(rows)//4,len(rows)//2,3*len(rows)//4})[:PICKS]
for i in idx: print('#',i); print(json.dumps(rows[i],ensure_ascii=False,indent=1)[:2500]); print('-'*60)
"
```

**Okuma bütçesi: paket başına ~600 satır.** Aşılıyorsa örneklem küçültülür,
paket bölünmez.

Örneklemde bakılacaklar: **A3** (bu değer kaynaktan mı geliyor, yoksa makul
görünen bir uydurma mı), **A4** (ad yazımı), **B3** (düzyazıda duran ref adayı),
**C3/C6** (alan semantiği, `mechanical_notes` yönlendirmesi).

### Adım 5 — Metadata satırı

```sh
python -c "
import json
d=json.load(open('assets/open5e_packs/open5e-toh.pkg.json',encoding='utf-8'))
print(json.dumps(d.get('metadata'),ensure_ascii=False,indent=1)[:2000])
"
```

→ Checklist **B5, G1–G3** (+ `assets/open5e_packs/manifest.json`'daki karşılığı).

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

> Bilinen giriş noktası: `cost_gp` 1.063/1.063 = `0.00` ve §5.8'in 🔴 `M`
> attunement / charges / body-slot bloğu (checklist C5, A5).

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
