# Paket İçerik Uygunluk Taraması — Kontrol Planı ve İlerleme (Stage F1)

**Ölçüt:** `pack_conformance_checklist.md` · **Bulgular:** `pack_conformance_findings.md`
· **Yol haritası:** `open5e_content_audit.md` §6 Stage F

---

## Sonraki adım

> **Şu an:** Checklist **onaylandı** (F0, 2026-08-15), bu plan **onaylandı**
> (F1, 2026-08-17 — §10), bulgu defterinin formatı **onaylandı** (F2, 2026-08-17).
> **F3 sürüyor: Pass 0 (§6) + Dalga 0 + Dalga 1 bitti, Dalga 2'nin ilk dört
> birimi tarandı** — `a5e-gpg`, `a5e-ddg`, `open5e`, `tdcs`, `toh`, `a5e-ag`
> (2026-08-17), `bfrd`'nin class/subclass satırları, `kp`, `wz`, `deepmx` ve
> `spells-that-dont-suck` (2026-08-18).
> **20 tarama biriminin 12'si kapandı**, defterde **27 bulgu** var, yirmi yedisi
> de ❓ danışılacak (`python3 tool/check_findings.py` → *28 kayıt, 27 sayaca
> giriyor, temiz*). `spells-that-dont-suck` üç bulgu üretti: **F-spells-that-dont-suck-01**
> (`Self (60-foot radius)` menzilinin yarıçapı hiçbir alana yazılmıyor, 8 kart),
> **F-spells-that-dont-suck-02** (malzeme metni fiyatı söylerken
> `material_cost_gp` `0`, 5 kart) ve **F-pass0-15** (yayılan — `spell.effects`'in
> ⚪ gerekçesinin "kaynakta yapılandırılmış hasar yok" yarısı yanlış;
> `damage_roll` gönderilen belgelerde 303/1.297 dolu).
>
> **Sıradaki iş: Dalga 2'nin son birimi → `open5e-deepm` (515 büyü).** Bitince
> Dalga 2 kapanır (13/20) ve Dalga 3 (sihirli eşyalar, `open5e-vom`) başlar.
> `spells-that-dont-suck`'tan çıkan beş uyarı:
> (1) **`deepm` bu dalganın en büyük birimi** (515 kart, 4 belge dosyası) —
> örneklem kuralına sıkı sıkı uy, tam tablo taraması yalnız araç çıktısından
> gelsin (K2);
> (2) `deepm` üç devralınan kaydın **beklenen** tarafında duruyor: F-pass0-11
> **9** satır, F-pass0-12 **2**, F-pass0-13 **2**, F-pass0-14 **2**
> (`Caustic Touch`, `Stench of Rot`).
> Komutlar yeniden çalıştırılır, sayı tutuyorsa **yeni kayıt açılmaz**;
> (3) **`material_*` `deepm`'de canlı** — `material_description` 288/515 dolu ve
> `material_cost_gp == 0` olan kart **0**; F-spells-that-dont-suck-02'nin `deepm`
> beklentisi bu sıfırdır, doğrula ve geç;
> (4) `SpellCastingOption.json`'ın "ölü" gerekçesi artık `desc`'in boşluğuna
> değil, **içeriğin ebeveynin `higher_level`'ında zaten olmasına** dayanıyor
> (`spells-that-dont-suck`: 60 satır, `desc` 37'sinde **dolu**, ama hepsi slot
> bazlı kısaltma) — `deepm`'de aynı biçimde sına;
> (5) ucuz `desc` karşılaştırması **kural uygulanmış** dizeyle yapılır
> (`spell.dart:158`); `spells-that-dont-suck`'ta 87 satır `higher_level`
> taşıyordu ve kural uygulanınca 180/180 birebir çıktı.
>
> **Dalga 2 bittiğinde** 13/20 birim kapanır ve Dalga 3 (sihirli eşya paketleri)
> başlar; onun bilinen açığı `magic-item.cost_gp` (bilinen açık #5, ⛔).
>
> **Test dosyalarının yeri**: F grubu
> `test/application/services/pack_install_roundtrip_test.dart`,
> `test/presentation/character_creation/wizard_pack_families_test.dart`,
> `test/presentation/pack_field_render_test.dart`,
> `test/presentation/entity_link_navigation_test.dart` ve
> `test/domain/services/bundled_pack_resolve_test.dart` (**`domain/`** altında,
> `application/` değil). `pack_field_render_test`
> **kırmızı gelir** — kesen tek grup built-in, yani F-pass0-01; paket tarafı
> (224 çift / 446 pump) yeşil.
>
> **Taramanın yedi sorusu** (birim birim biriktiler, hepsi geçerli):
> 1. Kartın taşıdığı mekanik **şemada bir eve sahip mi**? (`open5e`)
> 2. O ev **doğru belgeden** mi dolduruluyor? (`open5e`)
> 3. Alan boşsa, boşluk **pakette mi kaynakta mı**? — kategori başına tek kaynak
>    sütunu saymak yetiyor; `tdcs`'te 3, `toh`'ta 5, `bfrd`'de 3 yanlış bulgu
>    önledi.
> 4. Alan dolu ve kaynakla aynı, ama **değer kuralla uyuşuyor mu**? (`toh`,
>    `a5e-ag`)
> 5. Devir notunun **"zaten biliniyor"** satırı ölçüldü mü? — `toh`'ta iki,
>    `bfrd`'de bir tane yanlış çıktı (a5e-ag'nin *"class kartının boş alanları
>    `S`"* cümlesi; §5.1 onlara `M`🔗 diyor ve haklı).
> 6. Boş alanın **okuyucusu** var mı, **yazanı** var mı? — `grep -rn <alan> lib/`
>    dolu + `tool/` boş ⇒ cause `M` (`a5e-ag`). `bfrd`'de 5 alana uygulandı,
>    beşinin de cause code'u zaten doğruydu.
> 7. Bulduğun kusurun **doğrusu kaynağın kendisinde** başka bir alanda duruyor mu?
>    (`bfrd` — `name` yanlış, `pk` doğru; F-a5e-ag-02'nin tersi durum.)
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
| **built-in SRD** (`srd_core/` + Tier-0 seeds) | 2.719 | 59 kategori (2.350 Tier-1 + 369 Tier-0) | ⚠️ | 2026-08-17 | F-builtin-01, F-builtin-02 |

> Neden ilk: her paketin yumuşak ref'i buraya iniyor. Burada bir ad yanlışsa
> 19 paketin ref'i birden ölür.

#### Dalga 0 sonucu — 2026-08-17

31 maddenin **2'si bulgu**, 10'u bu birime uygulanmıyor (built-in ne kaynak
snapshot'ından map'leniyor ne katalogdan kuruluyor), 19'u ✅.

| Madde | Verdict | Dayanak |
|---|:--:|---|
| A1 | ✅ | `audit_packs --builtin` 59 kategorinin tamamını sayıyor ve toplam **2.719** — şema dışı `type` kalmış olsa toplam düşerdi |
| A2 | ✅ | **zorunlu ve boş alan 0** (725 yuva tarandı) |
| A3 | ✅ | ⚠ satırlarının 10'u da SRD'nin gerçek tek değeri (aşağıda); uydurma yok |
| A4 | ✅ | Pass 0 `dupe_census` C: **4.045** paket ref'i built-in'e iniyor, **0 dangling** — yazım korpüsçe doğrulanmış |
| A5 | ✅ | 10 ⚠ satırı okundu: `class.multiclass_prereq_min_score`=13 ·`subclass.granted_at_level`=3 (SRD 5.2.1'de 12 sınıfın hepsi 3. seviye) · `species.creature_type_ref`=Humanoid (9/9) · `animal.creature_type_ref`=Beast (97/97) · `background.asi_distribution_options`=`['+2/+1','+1/+1/+1']` · `background.gold_alternative_gp`=50 · `mount.is_trained` · `magic-item.is_sentient`=false (286/286, `sentient_*` bloğu da 0%) · `trait`/`creature-action`.`source`=`'SRD 5.2.1'`. Hepsi kural gereği sabit |
| B1 | ✅ | Pass 0: same-text 0 |
| B2 | ➖ | paketler arası kural |
| B3 | ✅ | Tier-0 ilişkileri `lookup()`, Tier-1 arası `ref()` — düzyazıda ad bırakılmıyor (`srd_core/_helpers.dart`) |
| B4 | ✅ | `gate_packs` green + census C 0 dangling |
| B5 | ➖ | built-in `metadata.links` taşımaz; manifest'te girdisi yok (19 satır hepsi `open5e-*`) |
| C1 | ✅ | `class.features` 12/12, `subclass.features` 12/12 + `granted_at_level` |
| C2 | 🟡→C8 | `species` 39 / `subspecies` 34 / `feat` 16 🔴 yuva — hepsi grant bloğu, tasarım gereği; hesabı **F-builtin-02**'de |
| C3 | ✅ | `spell` 25 yuvanın 24'ü dolu; tek 🔴 `effects` (M3'te beyanlı) |
| C4 | ⚠️ | **F-builtin-01** — `save_bonuses` / `skill_bonuses` 345 statblokta 0% |
| C5 | 🟡→C8 | `magic-item` 64 yuvanın 51'i 🔴 (sentient + attunement + grant blokları); `cost_gp` 2/286 |
| C6 | ✅ | `mechanical_notes` boş ama grant alanları tipli evlerinde; `grant_contract_test` + `grant_field_isolation_test` yeşil |
| C7 | ✅ | çözünürlük tarafı temiz (`unmapped_report` 3, hepsi paket tarafı); **gövde** tarafı F-builtin-02 |
| C8 | ⚠️ | **F-builtin-02** — 419 🔴 yuvanın yazılı sebebi yok |
| D1 | ➖ | `verify_packs` fixture snapshot'ıyla karşılaştırır; built-in'in kaynağı PDF |
| D2 | ➖ | aynı sebep |
| D3 | ✅ | `gate_packs` green (built-in ref hedefi olarak da doğrulanıyor) |
| E1 | ✅ | `wizard_pack_families_test` 39 vakanın tamamında built-in tabanı kullanıyor |
| E2 | ✅ | M3 beyan listesi built-in alanlarını da kapsıyor (`spell.effects`, `creature-action.effects`) |
| E3 | ✅ | 12 SRD sınıfının `caster_kind`'ı preset'i besliyor (M4 kapandı) |
| F1 | ➖ | built-in kurulmuyor, gömülü geliyor |
| F2 | ⛔ | kapı **F-pass0-01** yüzünden 306 çiftin 83'ünü ölçüyor — bu birim için ölçülmemiş sayılır |
| F3 | ✅ | aynı wizard testi |
| F4 | ✅ | `entity_link_navigation_test` yeşil |
| G1 | ➖ | katalog sürümü yerine `srdCorePackVersion` (bugün `1.0.8`) |
| G2 | ➖ | manifest girdisi yok |
| G3 | ➖ | SRD örtüşme kuralı **bu paketin kendisi** |

> **Okuma bütçesi.** Built-in `*.pkg.json` değil, 21.690 satır Dart. K2'nin
> "5 varlık" kuralı burada "alan tablosundan gidip **yalnız şüpheli satırın**
> kaynağını grep'lemek" oldu: 10 ⚠ satırının değeri + 1 tam statblok
> (Adult Red Dragon, `monsters.dart:176`) + `_commonLookupFields` + `_helpers.dart`
> — toplam ~250 satır okuma.
>
> **Vault düzeltmesi (K1 dışı, doküman).** `vault/40-Reference/SRD-5.2.1.md`'nin
> "Coverage in code" sayıları eskimişti (71 class / 55 subclass / 29 background /
> 236 feat / 364 spell); ölçülen 12 / 12 / 16 / 305 / 341 + `animal` 97 satırı hiç
> yazılmamış. Not bugünkü ölçümle güncellendi.

### Dalga 1 — Karakter yaratma paketleri (küçükten büyüğe)

| Paket | Varlık | Kategoriler | Durum | Tarih | Bulgular |
|---|--:|---|:--:|---|---|
| `open5e-a5e-gpg` | 2 | background 2 | ⚠️ | 2026-08-17 | F-pass0-02, F-pass0-03, F-pass0-04 |
| `open5e-a5e-ddg` | 4 | background 4 | ⚠️ | 2026-08-17 | F-pass0-02…06 |
| `open5e-open5e` | 22 | subclass 17, spell 2, background 2, subspecies 1 | ⚠️ | 2026-08-17 | F-open5e-01, F-pass0-10 (eski F-open5e-02), F-pass0-06, F-pass0-07 |
| `open5e-tdcs` | 35 | trait 11, creature-action 10, background 5, monster 4, subclass 4, feat 1 | ⚠️ | 2026-08-17 | F-pass0-08, F-pass0-09 |
| `open5e-toh` | 239 | spell 91, subclass 76, subspecies 29, background 19, feat 13, species 11 | ⚠️ | 2026-08-17 | F-toh-01, F-toh-02, F-pass0-10 (+2 kart) |
| `open5e-a5e-ag` | 455 | spell 371, feat 59, background 21, subclass 3, class 1 | ⚠️ | 2026-08-17 | F-a5e-ag-01, F-a5e-ag-02 |
| `open5e-bfrd` (class + subclass) | 2 | class 1, subclass 1 | ⚠️ | 2026-08-18 | F-bfrd-01 |

> `open5e-bfrd`'nin `class` 1 + `subclass` 1 satırı **bu dalgada** bakıldı
> (2026-08-18); paketin 360 `monster`'ı ve 2.110 çocuk satırı Dalga 4'te.
> **Dalga 1 kapandı: 8/20 birim.**

#### `open5e-a5e-gpg` sonucu — 2026-08-17

2 varlık, tek kategori (`background`), 11 beyan edilmiş alanın 5'i dolu.
31 maddenin **3'ü bulgu**, 6'sı uygulanmıyor, 1'i bilinen ⛔, 1'i araçla
ölçülemiyor, 20'si ✅. **Üç bulgu da mapper kusuru, yani kapsamı `pass0`** —
paketin kendi sayacı 0 kalıyor (yayılan bulgu kuralı).

> **Geriye dönük düzeltme — 2026-08-17, `a5e-ddg` taranırken.** `a5e-ddg`'de
> bulunan iki yeni yayılan bulgunun ikisi de bu pakete de dokunuyor, yani bu
> tablo iki satırda **fazla iyimserdi**: `B3` ✅ → ⚠️ (F-pass0-06) ve `D1`
> 🟡 → ⚠️ (F-pass0-05). Düzeltilmiş sayım: **19 ✅ · 6 ➖ · 1 ⛔ · 5 ⚠️.**
> İkisi de aynı sebeple kaçtı: **dolu alanın içine bir kademe daha inilmedi** —
> `equipment_choice_groups`'un grubu vardı (içindeki eşya satırı eksikti),
> `granted_language_count`'un sayısı vardı (sayı yanlıştı). Dalga 1'in geri
> kalanı için kural buna göre keskinleşti: *dolu alanın değerine bak* yetmiyor,
> **değerin kaynaktaki karşılığını say.**

| Madde | Verdict | Dayanak |
|---|:--:|---|
| A1 | ✅ | tek `type` = `background`, şemada var, `audit_packs` 11 alanla tabloluyor |
| A2 | ⛔ | 4 zorunlu alanın 2'si dolu; `asi_distribution_options` + `origin_feat_ref` **0%** ve ikisi de §5.8'de yazılı ⛔ (B7 kararı: "requirement is wrong for imported content") → K7 |
| A3 | ⚠️ | **F-pass0-04** — kaynağın `"[No description provided]"` placeholder'ı kart gövdesinin ilk satırı |
| A4 | ✅ | `Cursed` / `Haunted` title case; 9 ekipman + 4 beceri + 6 yetenek ref hedefinin **tamamı** built-in kartlarda birebir bulundu (ölçüldü) |
| A5 | ⚠️ | **F-pass0-03** — `ability_score_options` 27/27 satırda aynı altı-yetenek listesi, ve `isConstant` %100 dolu istediği için ⚠ basılmıyor |
| B1 | ✅ | Pass 0 same-text 0; iki ad built-in'in 16 background'ıyla çakışmıyor (ölçüldü) |
| B2 | ✅ | iki ad korpüste yalnız bu pakette var (ölçüldü) |
| B3 | ⚠️ | *(2026-08-17'de `a5e-ddg` taranırken geriye dönük düzeltildi: ✅ değil)* — **F-pass0-06**, bu pakette 1 düşen ekipman sözcüğü (Haunted) |
| B4 | ✅ | `gate_packs --packs /tmp/one` **green**; 9 ekipman softRef'i built-in gear'a çözülüyor |
| B5 | ✅ | `metadata.links` yok + manifest `requires: []` — L2'nin yazılı kararı |
| C1 | ➖ | `class` / `subclass` yok |
| C2 | ⚠️ | **F-pass0-02** — seçimli beceri satırının bütün alternatifleri grant yazılıyor |
| C3 | ➖ | `spell` yok |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ✅ | M1 yeşil; `granted_language_count` B7'de "bilerek inert" olarak yazılı. Düzyazıdaki *Accursed* Intimidation expertise'ının tipli evi yok → bilinen açık #1 |
| C7 | ✅ | `_lookup` zarfları (`skill`, `ability`) + gear softRef'leri; `unmapped_report.json`'da bu paketten satır yok, paket kendi Tier-0 tohumunu göndermiyor |
| C8 | ✅ | 6 🔴 alanın **altısının** da yazılı sebebi var: 2 ⛔ (§5.8), `granted_tool_refs`/`_variant_group` `S` (kaynakta `tool_proficiency` satırı yok), `starting_gold_gp`/`gold_alternative_gp` bilinen açık #1, `default_inventory_refs` ⛔ |
| D1 | ⚠️ | **ölçülmedi:** `verify_packs --doc a5e-gpg --only background` → `2/2 eşleşti, ok 0` (§4 Uyarı 2). Okumayla yapıldı ve iki sapma buldu (F-pass0-02, -04); *(2026-08-17'de üçüncüsü eklendi: **F-pass0-05**, Haunted'ın dil sayısı 2 yerine 1 — geçen birimde kaçtı, 🟡 → ⚠️)* |
| D2 | ➖ | ölçüm olmadığı için kova da yok (`unsourced` 0 / `unverifiable` 0) |
| D3 | ✅ | `gate_packs` green |
| E1 | ✅ | M1 73 çift yeşil — paketin 5 alanı sayfaya iniyor (F-pass0-02 tam bu yüzden acıtıyor: yanlış sayı iniyor) |
| E2 | ✅ | M3 beyan listesine yeni alan gerekmedi |
| E3 | ➖ | `class` / büyücülük yok |
| F1 | ✅ | `pack_install_roundtrip_test` 19 pakette yeşil |
| F2 | ✅ | paket tarafı 141 çift yeşil; F-pass0-01 yalnız built-in grubunu kesiyor. Not: `seen` kümesi paketler arası paylaşıldığı için `background` çiftlerini alfabetik olarak `a5e-ag` kapıyor — bu paketin **kendi değerleri** pump edilmiyor (testin yazılı bütçe kararı, `pack_field_render_test.dart:58-82`) |
| F3 | ✅ | `wizard_pack_families_test` → `open5e-a5e-gpg` 2 vaka (+8, +9) yeşil |
| F4 | ✅ | `entity_link_navigation_test` yeşil (Pass 0) |
| G1 | ✅ | `pack_version` 1.1.0 = manifest `version` = `r2_path @1.1.0`; `counts.background` 2; `size_bytes` 16.932 = dosyanın gerçek boyutu (ölçüldü) |
| G2 | ✅ | `publisher` / `license` / `game_system` / `is_srd_overlap` dördü de iki dosyada aynı (EN Publishing · `ogl-10a` · `a5e` · false) |
| G3 | ✅ | `is_srd_overlap: false`, `game_system: a5e` — SRD belgesi değil |

> **Okuma bütçesi.** `scan_pack.py a5e-gpg` + `--cat background` = 2 varlığın
> tamamı, ~60 satır. Kalanı araç çıktısı ve **kaynak** okuması: bu paketin
> `Background.json`'ı 2 satır, `BackgroundBenefit.json`'ı 14 — A3'ün tamamı
> okumayla yapıldığı için (§4 Uyarı 2) kaynağı açmak zorunluydu ve zaten ucuzdu.
>
> **Yöntem notu.** Üç bulgunun üçü de "alan dolu" satırlarından çıktı, boş
> satırlardan değil: 5 dolu alanın 3'ünde değer var ama **yanlış** (fazla beceri,
> genişletilmiş yetenek listesi, placeholder metin). Boş alanların hepsinin
> (C8 ✅) yazılı sebebi vardı. Dalga 1'in geri kalanı için kural: **doluluk
> tablosuna değil, dolu satırın değerine bak.**

#### `open5e-a5e-ddg` sonucu — 2026-08-17

4 varlık, tek kategori (`background`), 11 beyan edilmiş alanın 6'sı dolu
(gpg'den bir fazla: `granted_tool_refs` 4/4, çünkü kaynakta `tool_proficiency`
satırı var). 31 maddenin **5'i bulgu** — 3'ü `a5e-gpg`'den gelen yayılan
bulgunun doğrulanması, **2'si yeni** ve ikisi de yine mapper kusuru, yani
kapsamı `pass0`; paketin kendi sayacı 0 kalıyor.

| Madde | Verdict | Dayanak |
|---|:--:|---|
| A1 | ✅ | tek `type` = `background`, `audit_packs` 11 alanla tabloluyor |
| A2 | ⛔ | 4 zorunlu alanın 2'si dolu; `asi_distribution_options` + `origin_feat_ref` **0%**, ikisi de §5.8'de yazılı ⛔ → K7. Not: ASI sütunu burada **zorunlu olarak** boş — dört kaynak satırının dördü de "one other ability score" diyor, yani `floating` dalı, yani mapper hiç yazmıyor |
| A3 | ⚠️ | **F-pass0-04** doğrulandı: 4 kartın 4'ünde `desc` = `"[No description provided]"` (kaynakta da öyle) |
| A4 | ✅ | 4 ad title case; 12 ref hedefinin **12'si** built-in kartlarda birebir var (`Leatherworker's/Cartographer's/Thieves' Tools`, `Disguise Kit`, `Chalk`, `Clothes, Traveler's`, `Hunting Trap`, `Pick, Miner's`, `Shovel`) |
| A5 | ⚠️ | **F-pass0-03** doğrulandı: `ability_score_options` 4/4 satırda aynı altı yetenek. Bu paket ⚠ körlüğünün **ikinci** yüzünü de gösteriyor: 4 varlık `_constMinSample`'ın altında, yani doluluk %100 olsa bile ⚠ basılmazdı |
| B1 | ✅ | 4 ad built-in'in 16 background'ıyla çakışmıyor (ölçüldü) |
| B2 | ✅ | 4 ad korpüsün diğer 18 paketindeki background adlarıyla çakışmıyor (ölçüldü) |
| B3 | ⚠️ | **F-pass0-06 (yeni)** — `Common clothes` ×2 ve `Cartographers' tools` ×1 yalnız `label` düzyazısında kalıyor, `items` satırı olmuyor |
| B4 | ✅ | `gate_packs --packs /tmp/one` **green**; 8 gear/tool softRef'inin hepsi built-in'de var |
| B5 | ✅ | `metadata.links` yok + manifest `requires: []` — L2'nin yazılı kararı |
| C1 | ➖ | `class` / `subclass` yok |
| C2 | ⚠️ | **F-pass0-02** doğrulandı, dağılım tam çıktı: 4 kaynak satırının 4'ü de "X, and either Y or Z" (2 beceri) diyor, kart 3 veriyor → **4 fazla yetkinlik** |
| C3 | ➖ | `spell` yok |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ✅ | M1 yeşil (Pass 0, K4); grant bloğunun 6 alanı yazılı. `granted_language_count`'un **değeri** yanlış ama o D1'in işi (F-pass0-05) |
| C7 | ✅ | `_lookup` zarfları (`skill`, `ability`) + gear/tool softRef'leri; `unmapped_report.json`'ın 3 satırının hiçbiri bu paketten değil |
| C8 | ✅ | 5 🔴 alanın hepsinin yazılı sebebi var: 2 ⛔ (§5.8), `granted_tool_variant_group` `S` (dört kaynak satırı da tek alet adı, "of your choice" yok), `starting_gold_gp`/`gold_alternative_gp` bilinen açık #1, `default_inventory_refs` ⛔ |
| D1 | ⚠️ | **F-pass0-05 (yeni)** — Dungeon Robber'ın dil hakkı kaynakta "Any six", pakette **0**. `verify_packs --doc a5e-ddg --only background` → `4/4 eşleşti, ok 0` (§4 Uyarı 2), yani yine ölçüm değil okuma buldu |
| D2 | ➖ | ölçüm olmadığı için kova da yok (`unsourced` 0 / `unverifiable` 0) |
| D3 | ✅ | `gate_packs` green |
| E1 | ✅ | M1 73 çift yeşil; paketin 6 alanı sayfaya iniyor |
| E2 | ✅ | M3 beyan listesine yeni alan gerekmedi |
| E3 | ➖ | `class` / büyücülük yok |
| F1 | ✅ | `pack_install_roundtrip_test` 19 pakette yeşil (Pass 0) |
| F2 | ✅ | paket tarafı 141 çift yeşil; `background` çiftlerini `seen` kümesi yüzünden `a5e-ag` kapıyor (gpg'de yazılan not burada da geçerli) |
| F3 | ✅ | `wizard_pack_families_test` → `open5e-a5e-ddg` 2 vaka (+6, +7) yeşil (çalıştırıldı) |
| F4 | ✅ | `entity_link_navigation_test` yeşil (Pass 0) |
| G1 | ✅ | `pack_version` 1.1.0 = manifest `version` = `r2_path @1.1.0`; `counts.background` 4; `size_bytes` **26.006** = dosyanın gerçek boyutu (ölçüldü) |
| G2 | ✅ | `publisher` / `license` / `game_system` / `is_srd_overlap` iki dosyada aynı (EN Publishing · `ogl-10a` · `a5e` · false) |
| G3 | ✅ | `is_srd_overlap: false`, `game_system: a5e` |

**Sayım: 19 ✅ · 6 ➖ · 1 ⛔ · 5 ⚠️.**

> **Okuma bütçesi.** `scan_pack.py a5e-ddg --cat background` = 4 varlığın tamamı,
> ~55 satır. Kaynak tarafı: `Background.json` 4 satır + `BackgroundBenefit.json`
> 29 satır — A3/D1 okumayla yapıldığı için (§4 Uyarı 2) zorunluydu ve ucuzdu.
>
> **Yöntem notu — gpg'nin notu bir kademe derinleşti.** gpg'de kural "boş alana
> değil, dolu alanın değerine bak"tı. Bu paket onun yetmediğini gösterdi: iki
> yeni bulgunun ikisi de **değerin içinde** duruyor. `equipment_choice_groups`
> dolu ve grup doğru, ama grubun `items` dizisi kaynağın saydığı eşyaları
> saymıyor; `granted_language_count` dolu ve tek hücre, ama o hücre yanlış sayı.
> Yani sıradaki paketlerde sorulacak soru: **kaynak kaç tane diyor, pakette kaç
> tane var.** Beceri (F-pass0-02), yetenek (F-pass0-03), dil (F-pass0-05) ve
> ekipman (F-pass0-06) — dördü de aynı soruya "eşit değil" cevabı verdi.
>
> **Küçük paket, kör araç.** 4 varlıkta `audit_packs`'in ⚠ dedektörü
> `_constMinSample`'ın altında kaldığı için hiçbir "tek sabit" sütunu
> bildirmiyor; `verify_packs` `background` kuralı boş olduğu için 0 ok basıyor;
> `gate_packs` softRef'leri gate'lemiyor. Bu birimde **31 maddenin 5'i** yalnız
> okumayla bulundu, ve 5'i de bulgu çıktı.

#### `open5e-open5e` sonucu — 2026-08-17

22 varlık, **dalganın ilk çok kategorili paketi** (subclass 17, spell 2,
background 2, subspecies 1). 31 maddenin **4'ü bulgu**, 1'i yazılı-açık,
2'si ➖, 2'si ⛔, 22'si ✅. Bulguların **2'si bu pakete ait** (dalgada bir paketin
kendi sayacının ilk kez artması), 1'i yeni yayılan bulgu, 1'i doğrulama.

| Madde | Verdict | Dayanak |
|---|:--:|---|
| A1 | ✅ | 4 `type` (`subclass`/`spell`/`background`/`subspecies`), dördü de şemada; `audit_packs` dördünü de tabloluyor, sayılar manifest `counts` ile birebir (17/2/2/1) |
| A2 | ⛔ | `background`'ın 4 zorunlusundan 3'ü boş (`ability_score_options`, `asi_distribution_options`, `origin_feat_ref`) — §5.8'de yazılı ⛔ → K7. Diğer üç kategoride zorunlu alanların **hepsi** dolu (`subclass` 2/2 × 17, `spell` 11/11 × 2, `subspecies` 1/1) |
| A3 | ✅ | `granted_at_level` sabit değil, **veriden** geliyor (cleric/warlock/sorcerer 1, wizard/druid 2, fighter/rogue/bard/paladin/monk 3 — `min(ClassFeatureItem.level)`); iki background'ın gövdesi gerçek metin (F-pass0-04 buraya inmiyor); subspecies'in ASI'si `asi_json`'dan |
| A4 | ⚠️ | **F-pass0-07 (yeni, yayılan)** — `Eye bite` built-in `Eyebite`'ın yazım varyantı; korpüs geneli ölçüm **19 kart / 9 paket** |
| A5 | ✅ | `audit_packs` bu pakette hiç ⚠ basmıyor (22 varlık, `_constMinSample` altı) — el ile bakıldı: tek-değerli sütunların hepsi 1–2 satırlık kategorilerde, yani "kapsama değil default" durumu oluşmuyor |
| B1 | ✅ | census A "same text" **0**. Paket built-in ile tek ad paylaşıyor (`Ray of Sickness`) ve metin farklı — kartın kendi gövdesi sebebini yazıyor: *"This Open5e spell replaces a like-named non-SRD spell"* |
| B2 | ✅ | `Scoundrel` background'ı `toh`'ta da var, ama **ad-paylaşımı**: difflib oranı 0.396 (kişilik tabloları tamamen farklı), mekanikler aynı. B2'nin "yalnız unowned identical text taşınır" kuralına göre ikisi de kalır |
| B3 | ⚠️ | **F-pass0-06 doğrulandı** — Con Artist'in `pouch`'u, Scoundrel'ın `ball bearings` + `common clothes`'u `label`'da kalıyor, `items`'a girmiyor (dağılım tablosundaki 6 sözcük) |
| B4 | ✅ | `gate_packs --packs /tmp/one` **green**; census C korpüs geneli **0 dangling**; paketin softRef'leri (`class` Wizard/Fighter/…, `species` Halfling, `tool`, `adventuring-gear`) built-in'e iniyor |
| B5 | ✅ | `metadata.links` yok + katalog girdisi `requires: []` — L2'nin yazılı kararı |
| C1 | ✅ | `subclass.features` 17/17 ve `granted_at_level` 17/17; seviye tabloları 4–7 satır |
| C2 | 🟡 | `background` becerileri **doğru** (iki kaynak satırı da iki sabit beceri veriyor → kart iki veriyor; F-pass0-02 bu pakete inmiyor). Ama Con Artist'in `"Two of your choice"` alet hakkı hiç yazılmıyor — §5.4'ün 40 satırlık tablosunda *"correctly empty"* diye **yazılı**, dolayısıyla K7 gereği bulgu değil. Ölçüldü: kaynağı alet veren 42 background'ın **4'ü** pakette alet almıyor (`Con Artist`, `tdcs` Crime Syndicate Member, `toh` Mercenary Company Scion / Mysterious Origins) — dördünün de gerekçesi §5.4'te |
| C3 | ✅ | 2 büyünün 2'si kaynakla okunarak karşılaştırıldı: `Eye bite` (self / 1 dk / konsantrasyon / Wisdom / 4 sınıf) ve `Ray of Sickness` (60 ft / instantaneous / Con / Ranged / poison) — hepsi `Spell.json` ile aynı. `at_higher_levels_text` boş, ama prose `description`'a ekli ve sebebi §5.8'de `P` |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ✅ | `mechanical_notes` boş; subspecies'in ASI'si ve poison direnci tipli evlerinde (`ability_bonuses`, `granted_damage_resistances`), zehir kurtarma **avantajı** prose'da — subspecies şemasında karşılığı yok (§5.3) |
| C7 | ✅ | `_lookup` zarfları (`skill`, `ability`, `damage-type`, `creature-type`, `spell-school`, `casting-time-unit`, `duration-unit`, `casting-component`) çözülüyor; `unmapped_report.json`'ın 3 satırının hiçbiri bu paketten değil |
| C8 | ✅ | 0% kalan alanların hepsi yazılı: `subclass`'ın 4 🔴'ı §5.2 (`M`, feature prose), `background`'ınkiler §5.4 + §5.8, `spell.at_higher_levels_text` `P`, subspecies grant bloğu §5.3. **Not:** C8 yalnız *beyan edilmiş* alanı sorabiliyor — E3'ün bulduğu boşluk (subclass'ta `caster_kind` **alanı yok**) bu maddenin kör noktası |
| D1 | ✅ | Dalga 1'de **ilk kez araçla** ölçüldü: `verify_packs --doc open5e --only subclass,spell` → **14 ok / 0 disagree / 0 absent** |
| D2 | ✅ | 6 `unverifiable`, dördü de beyanlı kuralla geliyor (`casting_time` öneksiz, v2 `classes` boş → v1 `dnd_class`, `attack_roll` menzilden çıkarım, `range_ft` `range_text`'ten); `unsourced` 0 |
| D3 | ✅ | `gate_packs` green |
| E1 | ✅ | M1 73 çift yeşil (Pass 0); paketin yazdığı alanlar sayfaya iniyor |
| E2 | ✅ | M3 beyan listesine yeni alan gerekmedi |
| E3 | ⚠️ | **F-pass0-10 (yeni; o gün F-open5e-02)** — `Arcane Warrior` + `Eldritch Trickster` üçte-bir büyücü; `caster_kind` yalnız `class`'tan okunuyor, korpüste `'Third'` taşıyan **0** kart var. Checklist E3'ün "paketli bir büyücü çıkarsa yeniden dosyalanır" notu tetiklendi |
| F1 | ✅ | `pack_install_roundtrip_test` 19 pakette yeşil |
| F2 | ⛔ | `pack_field_render_test`: paket tarafı **224 çift / 446 pump yeşil**, `builtin SRD fields render` vakası **F-pass0-01** yüzünden kırık (temiz ağaçta da kırık — taban) |
| F3 | ✅ | `wizard_pack_families_test` yeşil (17 subclass `granted_at_level` + parent sınıf iddiası bu paketi de kapsıyor) |
| F4 | ✅ | `entity_link_navigation_test` yeşil |
| G1 | ✅ | `pack_version` 1.1.0 = katalog `version` = `r2_path @1.1.0`; `size_bytes` **219.829** = dosyanın gerçek boyutu; `counts` üç dosyada aynı |
| G2 | ✅ | `publisher` / `license` / `game_system` / `is_srd_overlap` paket ve katalogda aynı (Open5e · `ogl-10a` · `5e-2014` · false) |
| G3 | ⚠️ | **F-open5e-01 (yeni)** — `mergeOpen5eOriginals` `open5e-2024` belgesini (`gamesystem: 5e-2024`) `5e-2014` etiketli pakete katıyor; `Abjurationist` etiketsiz kalıyor ve `verify_packs --doc open5e` onu 17'de 1 "unmatched" olarak görüyor |

**Sayım: 22 ✅ · 2 ➖ · 2 ⛔ · 4 ⚠️ · 1 🟡.**

> **Okuma bütçesi.** `scan_pack.py open5e` + 4 kategori (`subclass --picks 3`) =
> ~330 satır; kaynak tarafı `Background.json` 2 + `Spell.json` 2 + `Subrace.json` 1
> + `CharacterClass.json` iki belge (ad listesi) ≈ 60 satır. Bütçenin altında
> kalındı, `--picks 3` gerçekten gerekliydi (17 × 18 ≈ 306 satır olurdu).
>
> **Yöntem notu — soru bir kademe daha genişledi.** `a5e-ddg` "kaynak kaç tane
> diyor, pakette kaç tane var" diye sormayı öğretmişti. Bu paketin iki bulgusu
> **o soruya da yakalanmıyordu**: F-open5e-01'de sayı doğru (17 kart, 17 kaynak
> satırı), yanlış olan **hangi kaynaktan** geldikleri; F-pass0-10'da kayıp bir
> değerde değil, **var olmayan bir alanda**. Yani çok kategorili paketlerde üçüncü
> soru: *kartın taşıdığı mekanik, şemada bir eve sahip mi — ve o ev doğru
> belgeden mi dolduruluyor?* Doluluk tablosu ikisini de göremez; ikisi de
> örneklem okumasından çıktı.
>
> **İlk kez ölçen araç.** Bu birimde `verify_packs`'in kural tablosu gerçekten
> çalıştı (`subclass` + `spell`): 14 ok / 0 disagree. Yani D1 ilk iki paketteki
> gibi "ölçülmemiş" değil, **ölçülmüş ve temiz** — ve tam da o çıktı,
> `Abjurationist`'i "unmatched" diye raporlayarak G3 bulgusunun ikinci kanıtını
> verdi.

#### `open5e-tdcs` sonucu — 2026-08-17

35 varlık, **dalganın ilk canavarlı paketi** ve ilk `feat`'i (trait 11,
creature-action 10, background 5, monster 4, subclass 4, feat 1). 31 maddenin
**2'si bulgu** (ikisi de yeni yayılan), 3'ü doğrulama, 2'si ➖, 1'i ⛔, 25'i ✅.
Bu birimin özelliği: **bulgu adayı sayısı, bulgu sayısından fazla** — üç aday
ölçümde düştü (aşağıda).

| Madde | Verdict | Dayanak |
|---|:--:|---|
| A1 | ✅ | 6 `type`, altısı da şemada; `audit_packs --only` altısını da tabloluyor, sayılar manifest `counts` ile birebir (11/10/5/4/4/1 = 35) |
| A2 | ⛔ | `background`'ın 3 zorunlusu (`ability_score_options`, `asi_distribution_options`, `origin_feat_ref`) 0/5 — §5.8'de yazılı ⛔ → K7 (paket `5e-2014`, kaynakta 2024 alanı yok). Diğer beş kategoride zorunlular **tam**: `monster` 12/12 × 4, `subclass` 2/2 × 4, `feat` 2/2, `creature-action` 2/2 × 10 |
| A3 | ✅ | `verify_packs` **unsourced 1**, o da kuralla: `feat.repeatable` = false, kaynakta sütun yok (D2'nin beyanlı listesinde). `granted_at_level` veriden: Blood Domain 1 (cleric), Juggernaut/Lawbearer 3; `tags_line` "(any race)" v1 `subtype`'tan |
| A4 | ✅ | Bu paketin 35 adının **hiçbiri** built-in bir adın yazım varyantı değil — F-pass0-07'nin 19'luk kovasında `tdcs` satırı yok (ölçüldü, çapraz-paket yakın-ad eşleşmesi de 0) |
| A5 | ✅ | `audit_packs` üç ⚠ basıyor (`trait.source`, `trait.trait_kind`, `creature-action.source`), üçü de kural gereği sabit — built-in'de de öyle |
| B1 | ✅ | census A "same text" 0; `Spellcasting` / `Multiattack` çocuk satırları built-in'de de var ama metinleri paketin kendi canavarlarını anlatıyor |
| B2 | ✅ | Çocuk satır adları çakışınca mapper **birinciyi çıplak, sonrakini parantezli** bırakıyor (`Spellcasting` → `Spellcasting (Skydancer)`); B2'nin "çocuk satır hariç" kuralı |
| B3 | ⚠️ | **F-pass0-06 doğrulandı** — Elemental Warden'ın `(a shortbow with 20 arrows, or a hunting trap)` parantezi hâlâ tamamen düşüyor; ayrıca **F-pass0-09 (yeni)**: Crime Syndicate Member'ın `Thieves' Cant`'i düzyazıda kalıyor — ama onun birincil maddesi C2 (alan **yok**), B3 değil |
| B4 | ✅ | `gate_packs --packs /tmp/one` **green**; softRef'leri (`class` Cleric/Barbarian/…, `tool` Herbalism Kit, `language`, `skill`) built-in'e iniyor |
| B5 | ✅ | `metadata.links` yok + katalog `requires: []` — L2'nin yazılı kararı |
| C1 | ✅ | `subclass.features` 4/4, `granted_at_level` 4/4 (5–7 satırlık seviye tabloları) |
| C2 | ⚠️ | **F-pass0-09 (yeni)** — `granted_languages` alanı `background` şemasında yok, adı verilmiş dil yazılamıyor (korpüste 2 satır). Ayrıca **F-pass0-02 doğrulandı**: 3 kart (Crime Syndicate Member, Elemental Warden, Lyceum Student) kaynağın "birini seç" dediği becerilerin hepsini veriyor; ve §5.4'ün yazılı alet-kaybı satırı (Crime Syndicate Member, "Thieves' Tools / Forgery Kit / Disguise Kit"den biri) doğrulandı |
| C3 | ➖ | `spell` yok |
| C4 | ✅ | 4 statblok tam: `ac`/`hp`/`speed`/`cr`/`xp`/`pb`/`passive_perception` 4/4, `trait_refs` 4/4, `action_refs` 4/4. `skill_bonuses` 0/4 **kaynakta da boş** (v2'nin 18 `skill_bonus_*` sütunu bu 4 satırda null, v1 `skills` null) → `S`, F-builtin-01 buraya inmiyor |
| C5 | ➖ | `magic-item` yok |
| C6 | ✅ | `feat.mechanical_notes` 1/1 dolu (Rapid Drinker'ın iki maddesi); grant bloğu boş, çünkü "iksiri bonus eylemle iç" ve "yutma kurtarmalarında avantaj" için tipli alan yok — §5.5'te yazılı |
| C7 | ✅ | `_lookup` zarfları (`skill`, `language`, `size`, `creature-type`, `alignment`, `feat-category`) çözülüyor; `unmapped_report.json`'da bu paketten satır yok |
| C8 | ✅ | 0% kalanların hepsi yazılı: `subclass`'ın 5 🔴'ı §5.2 satır 2242 (`M`, feature prose), `monster.gear_refs`/`spell_refs` §5.8 ⛔, `creature-action` grant alanları §5.8, `background` 2024 alanları §5.8 |
| D1 | ✅ | `verify_packs --doc tdcs --only monster,subclass,feat` → **73 ok / 0 disagree / 0 absent**; eşleşme 4/4 + 4/4 + 1/1 |
| D2 | ✅ | 20 `unverifiable` + 1 `unsourced`, hepsi beyanlı kuralla (`initiative_modifier`/`proficiency_bonus`/`xp` türetme, `tags_line` v1 `subtype`, `legendary_action_uses` SRD default, `feat.repeatable` sütunsuz) |
| D3 | ✅ | `gate_packs` green — 4 canavarın 15 çocuk satır ref'i çözülüyor |
| E1 | ⚠️ | **F-pass0-08 (yeni)** — Blood Domain'in domain büyüleri `features[].description` içinde markdown tablosu; korpüste 523 subclass feature satırının **0'ı** grant anahtarı taşıyor, 24'ü büyü listesi tablosu. Statblok tarafı sayfaya iniyor (M1 73 çift yeşil) |
| E2 | ✅ | M3 beyan listesine yeni alan gerekmedi |
| E3 | ✅ | 4 subclass'ın hiçbiri büyücü değil (Blood Domain cleric'in **kendi** ilerlemesini kullanır); F-pass0-10'un üçte-bir vakası buraya inmiyor |
| F1 | ✅ | `pack_install_roundtrip_test`: `open5e-tdcs installs and reads back unchanged` yeşil (19 paketin tamamı yeşil) |
| F2 | ⛔ | `pack_field_render_test` paket tarafı **224 çift / 446 pump yeşil**; `builtin SRD fields render` **F-pass0-01** yüzünden kırık (temiz ağaçta da kırık — taban) |
| F3 | ✅ | `wizard_pack_families_test` yeşil |
| F4 | ✅ | `entity_link_navigation_test` yeşil (5 vaka) |
| G1 | ✅ | `pack_version` 1.1.0 = katalog `version` = `r2_path @1.1.0`; `size_bytes` **106.324** = dosyanın gerçek boyutu; `counts` üç dosyada aynı |
| G2 | ✅ | `publisher` Green Ronin · `license` `ogl-10a` — kaynak `Document.json` ile aynı (`licenses: ["ogl-10a"]`, `organization: "Green Ronin Publishing™"`). Yazar satırı (Matthew Mercer, James Haeck) pakette taşınmıyor, çünkü şemada yazar alanı yok — G2 lisans/yayıncı soruyor, ikisi de doğru |
| G3 | ✅ | `is_srd_overlap: false`, `game_system: 5e-2014` = kaynak `Document.gamesystem` — F-open5e-01'in belge karışması burada **yok** (tek belge, tek `source_doc_slug`) |

**Sayım: 25 ✅ · 2 ➖ · 1 ⛔ · 3 ⚠️** (⚠️'lerden 2'si yeni bulgu, biri
doğrulama satırı; 🟡 yok).

> **Okuma bütçesi.** `scan_pack.py tdcs` + `audit_packs --only` (232 satır,
> filtreli okundu) + 3 kategori örneklemi (`subclass --picks 2`, `feat --picks 1`,
> background 5 kartın alan dökümü) + statblok özet satırları ≈ 280 satır;
> kaynak tarafı `Background.json` v1 5 satır + `Document.json` 2 + `Creature.json`
> sütun sayımı ≈ 40 satır. Paket dosyası bir kez bile baştan sona açılmadı (K2).
>
> **Yöntem notu — bu birimde bulgu adayları ölçümde düştü.** Üçü de "eksik
> görünüyor" diye başladı, ölçüm üçünü de kapattı:
> 1. `monster.skill_bonuses` 0/4 → F-builtin-01'in paket tarafı sanıldı; ölçüm:
>    paketlerde **1.963 / 2.885** canavarda dolu, `tdcs`'in 4'ünde boş çünkü
>    **kaynak sütunları boş**. Cause `S`, bulgu değil.
> 2. `monster.spell_refs` 0/4 → §5.8 satır 2602 bunu ⛔ olarak yazmış ve
>    *"ceiling in shipping documents is 4 monsters (tdcs)"* demiş. Doğrulandı:
>    `MonsterSpell.json` bu belgede **43 satır / 4 canavar**, korpüste 379 satırın
>    336'sı atlanan `wotc-srd`'de. Yazılı gerekçe **doğru** — sayı bile tutuyor.
> 3. Fate-Touched background'ının **hiçbir** grant'ı yok → mapper kaybı sanıldı;
>    kaynakta `skill_proficiencies`, `tool_proficiencies`, `languages`,
>    `equipment` dördü de boş. Cause `S`.
>
> Yani dalganın üçüncü sorusu (mekaniğin evi var mı) yanına dördüncüsü eklendi:
> **"boş alan bu pakette mi boş, yoksa kaynakta mı?"** — kategori başına tek bir
> kaynak sütunu saymak, üç yanlış bulguyu birden önledi.

#### `open5e-toh` sonucu — 2026-08-17

239 varlık — dalganın **en çok kategorili** paketi (altı kategori; varlık
sayısında `a5e-ag` 455 ile önde)
(spell 91, subclass 76, subspecies 29, background 19, feat 13, species 11).
31 maddenin **3'ü bulgu** (ikisi paket kapsamlı, biri var olan bir kaydın
büyümesi), 5'i doğrulama, 1'i ➖, 1'i ⛔, 24'ü ✅. Bu birimin özelliği: **beş
bulgu adayı ölçümde düştü** ve **bir önceki oturumun bir sayısı yanlış çıktı**
(aşağıda).

| Madde | Verdict | Dayanak |
|---|:--:|---|
| A1 | ✅ | 6 `type`, altısı da şemada; manifest `counts` paketle birebir (91/76/29/19/13/11 = 239) |
| A2 | ⛔ | `background`'ın 3 zorunlusu (`ability_score_options`, `asi_distribution_options`, `origin_feat_ref`) 0/19 — §5.8'de yazılı ⛔ → K7 (paket `5e-2014`). Diğerleri tam: `spell` 12/12 × 91, `subclass` `parent_class_ref` 76/76, `species` `creature_type_ref` 11/11, `subspecies` `parent_species_ref` 29/29, `feat` 2/2 × 13. `subclass.granted_at_level` 75/76 — eksik olan `Path of Hellfire`, kaynakta **hiç** ClassFeature satırı yok (K7, §5.2) |
| A3 | ✅ | `verify_packs` **unsourced 24**, hepsi kurallı: `feat.repeatable` 13 (sütun yok), `species.creature_type_ref` 11 (sütun yok, hepsi Humanoid). `disagree 0 / absent 0` |
| A4 | ✅ | 239 adın **hiçbiri** built-in bir adın yazım varyantı değil; çapraz-paket yakın-ad (yalnız-harf anahtarı) eşleşmesi de **0**. **Planın 3. uyarısı yanlıştı**: `toh`, F-pass0-07'nin 19'luk kovasında **yok** |
| A5 | ✅ | `audit_packs` üç ⚠ basıyor (`species`/`subspecies` `creature_type_ref`, `feat` `category_ref` + `repeatable`); üçü de veriden doğru sabit — 11 tür de Humanoid, 13 feat de genel kategori ve tekrarlanamaz |
| B1 | ✅ | census A'da `toh` **hiç geçmiyor** — 76 subclass + 91 büyüde built-in adla tek çakışma yok |
| B2 | ⚠️ | **F-toh-02 (yeni)** — `Scoundrel` background'u `open5e-open5e`'de de var, aynı iki beceri, %83 aynı metin. Diğer tek ad çakışması (`Misdirection` büyüsü) gerçek çakışma değil. Çocuk satır hariç korpüste **birebir aynı** metinli çift sayısı 1 (bir `language`) |
| B3 | ⚠️ | **F-pass0-06 doğrulandı** (19 background'un ekipman parantezleri); `granted_tool_refs` 8/19 + `granted_tool_variant_group` 5/19 kaynakla uyumlu |
| B4 | ✅ | `gate_packs --packs /tmp/one` **green**; census C "nothing installed" **0**. 76 subclass'ın `parent_class_ref`'i 12 built-in sınıfın hepsine dağılıyor (Druid/Cleric/Barbarian/Monk 7'şer, gerisi 6'şar), yazımlar built-in ile birebir |
| B5 | ✅ | `metadata.links` yok + katalog `requires: []` — L2'nin yazılı kararı (F-toh-02'nin 2. seçeneği bunu tartışıyor) |
| C1 | ⚠️ | **F-toh-01 (yeni)** — `granted_at_level` 75/76 dolu ama `Underfoot` (Rogue) **1** diyor; 3'ten küçük 46 değerin diğer 45'i 2014 kuralına göre doğru. `features` 75/76, **389 seviye satırı** |
| C2 | ⚠️ | **F-pass0-09 doğrulandı** (Forest Dweller → Sylvan). `granted_language_count` **19/19 doğru** (kaynakla tek tek karşılaştırıldı: 0 ×5, 1 ×11, 2 ×3) — F-pass0-05'in 2 hatalı satırı bu pakette **yok**. `species.granted_languages` 11/11, `granted_senses` 10/11, `ability_bonuses` 10/11 |
| C3 | ✅ | `spell` 91'de 12 alan %100 (`level`, `school_ref`, `casting_time_*`, `components`, `duration_unit_ref`, `requires_concentration`, `class_refs`, `range_type`, `is_ritual`, `description`). `material_*` 0/91 ve `at_higher_levels_text` 0/91 → ölçümde düştü, aşağıya bak |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ✅ | `mechanical_notes`: species 11/11, feat 13/13, subspecies 26/29. Boş 3'ün (Derro Heritage, Elf/Shadow Fey Heritage, Uncorrupted) trait metni `description` içinde duruyor — kayıp yok, yerleşim tutarsız |
| C7 | ✅ | `unmapped_report.json`'da `toh` **hiç geçmiyor**; `_lookup` zarfları (`skill`, `ability`, `casting-component`, `creature-type`, `damage-type`, `school`) çözülüyor |
| C8 | ✅ | 0% kalanların hepsi yazılı: `subclass`'ın 5 🔴'ı §5.2:2242, `feat.benefits` §5.8 ⛔, `prereq_class_refs` §5.5 ⚪ (L3), `at_higher_levels_text` §5.8 ⚪ (A1), `size_ref`/`speed_ft` §5.3 + §6 B3 |
| D1 | ✅ | `verify_packs --doc toh --only spell,subclass,feat,species` → **661 ok / 0 disagree / 0 absent**; eşleşme 91/91 + 76/76 + 13/13 + 11/11 (dalganın en büyük doğrulaması). Mapper kaynağın yazım hatasını da düzeltiyor: v1 `dnd_class` "Sorceror" → `Sorcerer` |
| D2 | ✅ | 233 `unverifiable` + 24 `unsourced`, hepsi beyanlı kuralla (`class_refs` v1'den, `casting_time_amount` örtük 1, `range_ft` `range_text`'ten, `size_ref`/`speed_ft` trait satırından, `reaction_trigger` yeniden cümlelenmiş, `attack_type` menzilden) |
| D3 | ✅ | `gate_packs` green — 29 subspecies → 11 species zinciri ve 76 subclass → built-in sınıf softRef'i çözülüyor |
| E1 | ⚠️ | **F-pass0-08 doğrulandı ve büyüdü**: `toh`'un 76 subclass'ında **389 features satırının 0'ı** grant anahtarı taşıyor; kaydın `toh` payı 15 büyü tablosu |
| E2 | ✅ | M3 beyan listesine yeni alan gerekmedi |
| E3 | ⚠️ | **F-pass0-10 iki kart büyüdü** — `Underfoot` (Rogue, druid ilerlemesi) ve `Soulspy` (Rogue, cleric ilerlemesi) üçte-bir büyücü; kayıt 2 karttan **4**'e çıktı ve kapsamı `pass0`'a taşındı. Kaydın eski kanıt komutu satır **adına** baktığı için ikisini de kaçırmıştı |
| F1 | ✅ | `pack_install_roundtrip_test`: `open5e-toh installs and reads back unchanged` yeşil (19 paketin tamamı + idempotency yeşil) |
| F2 | ⛔ | `pack_field_render_test` paket tarafı **224 çift / 446 pump yeşil**; `builtin SRD fields render` **F-pass0-01** yüzünden kırık (temiz ağaçta da kırık — taban) |
| F3 | ✅ | `wizard_pack_families_test` yeşil — ama F-toh-01 tam bu testin kör noktası: iddia "`granted_at_level` dolu ve aralıkta", 1 de aralıkta |
| F4 | ✅ | `entity_link_navigation_test` yeşil |
| G1 | ✅ | `pack_version` 1.1.0 = katalog `version` = `r2_path @1.1.0`; `size_bytes` **1.490.197** = dosyanın gerçek boyutu; `counts` üç dosyada aynı |
| G2 | ✅ | `publisher` Kobold Press · `license` `ogl-10a` — kaynak `Document.json` (`publisher: kobold-press`) ile aynı |
| G3 | ✅ | `is_srd_overlap: false`, `game_system: 5e-2014` = kaynak `Document.gamesystem`; tek belge, tek `source_doc_slug` — F-open5e-01'in belge karışması burada yok |

**Sayım: 24 ✅ · 2 ➖ · 1 ⛔ · 4 ⚠️** (⚠️'lerden 2'si yeni bulgu, 2'si var olan
kayıtların doğrulanması/büyümesi; 🟡 yok).

> **Okuma bütçesi.** `scan_pack.py toh` + `audit_packs --only` (249 satır,
> filtreli okundu) + kategori başına birer küçük toplama (subclass features,
> background dil sayısı, feat prereq, species size/speed, spell material) ≈ 300
> satır; kaynak tarafı `Spell.json` sütun listesi + `SpeciesTrait` 3 ebeveyn +
> `ClassFeatureItem` 8 satır + `Document.json` ≈ 60 satır. 1,49 MB'lık paket
> dosyası bir kez bile baştan sona açılmadı (K2).
>
> **Yöntem notu — dördüncü soru beş adayı birden düşürdü.** "Boş alan bu pakette
> mi boş, kaynakta mı?" bu birimde şunları kapattı:
> 1. `spell.material_description` / `material_cost_gp` / `material_consumed`
>    0/91 → kaynakta `material_specified` **91 satırın 91'inde boş** (v2'nin
>    tamamında yalnız `deepm`, `stds`, `srd-*` doldurmuş). Cause `S`.
> 2. `spell.at_higher_levels_text` 0/91 → §5.8 ⚪ `P` (A1, 2026-07-30) ve doğru:
>    kaynakta `higher_level` taşıyan **44** büyünün **44'ünde** metin
>    `description` içine *"At Higher Levels"* olarak eklenmiş.
> 3. `species.size_ref` 7/11, `speed_ft` 8/11 → §5.3 + §6 B3'te ölçülü yazılı;
>    ölçüm **birebir** aynı çıktı (üç ebeveyn "alt ırk belirler" diyor, 29 alt
>    ırkın hiçbiri söylemiyor, 19'u o üç ebeveynden iniyor). K7.
> 4. `feat.prereq_class_refs` 0/13 → §5.5 ⚪ `S` (L3). Ölçüm L3'ün **kendi
>    örneklerini** bu pakette buldu ("the Ki class feature", "the Shadow Traveler
>    shadow fey trait"); 10 prereq metninin 8'i `prereq_clauses`'a dönüyor,
>    dönmeyen 3'ü (beden, adı verilmiş trait, silah **kategorisi**) korpüste
>    toplam 5 satır — L3'ün kapsam kararının içinde.
> 5. `subspecies.mechanical_notes` 26/29 → boş 3'ün trait metni `description`'da;
>    kayıp yok.
>
> **Bir önceki oturumun bir sayısı yanlıştı.** Planın bu birim için yazdığı
> 3. uyarı "`toh` F-pass0-07'nin (yakın-ad kopyaları) dağılımında zaten var"
> diyordu; ölçüm **0** dedi — `toh`'un 239 adının hiçbiri built-in bir adın
> yazım varyantı değil, ve `dupe_census` çıktısında `toh` kelimesi hiç geçmiyor.
> Uyarı, dağılım tablosuna bakılmadan yazılmıştı. Ders: **devir notundaki
> "zaten biliniyor" satırları da ölçülmeden kullanılmaz** — K7 bir kestirme
> değil, kaynağı gösterilmiş bir iddia demek.
>
> **Ve bir kanıt komutu yanlış ölçüyordu.** F-pass0-10 (eski F-open5e-02)
> `features` satırının **adında** "spellcasting" arıyordu; `toh`'un iki
> üçte-bir büyücüsünün biri slot tablosunu `Spell Slots` adlı satırda, diğeri
> gövdede taşıyor. Kayıt "toh'un hepsi büyücü sınıf üstünde" diyordu, yanlıştı.
> Komut gövdeye bakacak şekilde düzeltildi ve kayıt 2 → **4 kart**, kapsamı da
> `pass0` oldu. Ders: **bir bulgunun kanıt komutu, sonraki paketlerde
> yeniden çalıştırıldığında sayıyı büyütebilir — bu, kaydın kusuru değil kuralı**
> (yayılan bulgu, madde 4).

#### `open5e-a5e-ag` sonucu — 2026-08-17

Dalga 1'in **gerçek en büyüğü** (455 varlık) ve dalganın tek `class` kartını
taşıyan birim. `verify_packs --doc a5e-ag --only spell,feat,background,class,subclass`:
**2.362 ok · 0 disagree · 0 absent · 59 unsourced · 867 unverifiable**, eşleşme
kapsaması **371/371 spell · 59/59 feat · 21/21 background · 3/3 subclass · 1/1 class**
(korpüste ilk kez `background` da doğrulanabildi). `gate_packs --packs /tmp/one`
yeşil, `dupe_census` "nothing installed" **0**, `--list-shared` çıktısında paket
**hiç geçmiyor**.

| # | Sonuç | Ölçüm |
|---|:--:|---|
| A1 | ✅ | 5 kategori (spell, feat, background, subclass, class) şemada; roundtrip yeşil |
| A2 | ✅ | zorunlu alanların tek boşluğu `class.primary_ability_ref` — kaynak `primary_abilities: []`, §5.8'de **⚪ yazılı** (B7). K7 |
| A3 | ✅ | 0 disagree / 0 absent; 59 unsourced'ın hepsi `feat.repeatable` (kaynakta sütun yok) |
| A4 | ⚠️ | **F-pass0-07 doğrulandı** — 1 varyant ad: `Meld Into Stone` ⟷ built-in `Meld into Stone` (dağılım tablosunun `a5e-ag: 1` satırı, komut yeniden çalıştırıldı) |
| A5 | ⚠️ | **F-pass0-03 doğrulandı** (21/21 aynı altı yetenek). Ayrıca `feat.category_ref` 73/73 `General` ve `repeatable` 73/73 `false` — ikisi de kaynakta **sütun yok** (`S`), bulgu değil |
| B1 | ✅ | census "nothing installed" 0; 326 A-bölümü ad çakışması = A5E restat politikası (§4, yazılı) |
| B2 | ✅ | `--list-shared` çıktısında paket yok |
| B3 | ⚠️ | **F-pass0-06 doğrulandı** (dağılım `a5e-ag: 33`). `equipment_choice_groups` 20/21 — boş olan `Folk Hero`, §B7'de **adıyla yazılı** allowlist satırı. K7 |
| B4 | ✅ | gate yeşil, census C "nothing installed" 0 |
| B5 | ✅ | `metadata.links` yok + katalog `requires: []` — L2'nin yazılı kararı |
| C1 | ⚠️ | `granted_at_level` 3/3 = **kaynakla aynı** (`min(ClassFeatureItem.level)` üç arketipte de 3, tablo satırı yok) → F-toh-01'in kuralı burada **doğru** çalışıyor. Ama `Marshal`'ın 20 satırlık ilerleme tablosu (`Maneuvers Known` / `Maneuver Degree` / `Lessons Known` / `Followers` / `Commanding Presence`) yalnız `description` düzyazısında → **F-a5e-ag-02** |
| C2 | ⚠️ | **F-a5e-ag-01 (yeni)** — `Tenacious`'ın kurtarma yeterliliği; `grants_save_prof_from_asi` korpüste 0/73 ama okuyucusu var. Ayrıca **F-pass0-02 doğrulandı** (dağılım `a5e-ag: 20`) ve `Guildmember`'ın `"Two of your choice"`'u §5.4'te **yazılı** → K7 |
| C3 | ✅ | `material_specified` kaynakta **0/371** (`material` bir *bool*, metin sütunu boş) → `S`, `toh`'un sonucu **yeniden ölçüldü**. `higher_level` 191 satırın **191'i** `description`'a gömülü, kayıp yok. `class_refs` 366/371; boş 5'in 3'ü **F-kuru-01'in ⚪ dağılımı** (komut yeniden çalıştırıldı), 2'si `tags` yoluyla görünüyor |
| C4 | ➖ | `monster` / çocuk satır kategorisi yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ✅ | `mechanical_notes` 54/59; boş 5'in (`Skillful`, `Tenacious`, üç `Outfitted`) mekaniği **tipli alanlarda** (`asi_*`, `granted_armor_proficiencies`, `player_choices`) — tek istisna F-a5e-ag-01'in yarım cümlesi |
| C7 | ✅ | gate yeşil; `_lookup` sözlükleri (ability, armor-category, feat-category, casting-*) çözülüyor |
| C8 | ⚠️ | F-a5e-ag-01 bu maddenin karşı örneği: `🔴 0%` bir alan `S` sanılıp geçilirse cause code **yanlış** yazılır — 0%'ın sebebi burada `M` |
| D1 | ⚠️ | **2.362 ok / 0 disagree / 0 absent** — lafzen tam; ama **F-a5e-ag-02**: `Commanding Presence` 13→14→15 = 30 / **10** / 45 feet, kaynak da öyle diyor |
| D2 | ✅ | 59 unsourced + 867 unverifiable'ın **hepsinin** `verify.dart`'ta yazılı kuralı var (370 `class_refs` v1 kolonu, 304 casting_time, 163 range, 23 attack, 6 reaction, 1 caster_kind) |
| D3 | ✅ | gate yeşil |
| E1 | ⚠️ | **F-pass0-08 doğrulandı** — 3 arketipin **16** `features` satırı yalnız `{level, name, description}`, 0 grant. Bu pakette **büyü tablosu yok** (0 satırda `\|`), yani F-pass0-08'in 24'lük sayısı **büyümüyor** |
| E2 | ✅ | mekanik olmayan alanlar (`description`, `prerequisite`) beyan edilmiş |
| E3 | ✅ | `Marshal` `caster_kind: 'None'` = kaynak `caster_type: NONE`; üç arketip de büyücü değil → **F-pass0-10 büyümüyor** (plan uyarısı 3 böylece kapandı) |
| F1 | ✅ | `pack_install_roundtrip_test` yeşil (455 varlık kayıpsız) |
| F2 | ✅ | paket tarafı yeşil (224 çift, 446 pump); F-pass0-01 yalnız built-in grubunu kesiyor |
| F3 | ✅ | `wizard_pack_families_test` yeşil |
| F4 | ✅ | `entity_link_navigation_test` yeşil |
| G1 | ✅ | manifest `size_bytes` **1.119.725** = dosyanın kendisi; `counts` beşi de birebir |
| G2 | ✅ | `publisher` / `license` / `game_system` / `is_srd_overlap` iki dosyada aynı (EN Publishing · `ogl-10a` · `a5e` · false) |
| G3 | ✅ | `is_srd_overlap: false`, `game_system: a5e`; 326 ad çakışması §4'ün yazılı "A5E her şeyi tutar" kararı |

**Sayım: 24 ✅ · 2 ➖ · 0 ⛔ · 5 ⚠️.**

**Okuma bütçesi.** Paket dosyası (1,07 MB) **hiç baştan sona açılmadı**; tüm
bilgi araç çıktısından ve tek satırlık python sorgularından geldi. Kaynaktan
okunan: `CharacterClass.json` (4 satır), `ClassFeature`/`ClassFeatureItem`
(sayım), `Background.json` + `BackgroundBenefit.json` (2 kart), `Spell.json`
(sütun sayımı). Toplam ~120 satır kaynak, 0 satır paket.

**Beş aday ölçümde düştü.**
> 1. `class` kartının 20 boş alanı (`spell_slots_by_level`, `equipment_choice_groups`,
>    `multiclass_*` …) → kaynakta **sütun yok**; `CharacterClass` yalnız
>    `caster_type / hit_dice / primary_abilities / saving_throws / subclass_of`
>    taşıyor. `S`.
> 2. `Marshal`'ın 113 tablo satırı "düşüyor" sanılmıştı → **düşmüyor**,
>    `description`'a 20 satırlık markdown tablo olarak yazılıyor. Bunu kovalarken
>    çıkan tek gerçek kusur F-a5e-ag-02.
> 3. `material_*` 0/371 → kaynağın `material` sütunu **bool**, `material_specified`
>    **boş**. `S` (deepm ve spells-that-dont-suck'ta dolu; onlar Dalga 2'nin işi).
> 4. `Guildmember` (beceri) ve `Folk Hero` (ekipman) boşlukları → ikisi de
>    §5.4 ve B7'de **adıyla yazılı**. K7.
> 5. 5 feat'in `mechanical_notes`'u boş → mekanikleri tipli alanlara inmiş;
>    kayıp değil, **doğru** davranış.

**Dalganın beşinci sorusu ilk cevabını verdi.** *"Alan dolu ve kaynakla aynı, ama
değer kuralla uyuşuyor mu?"* — F-a5e-ag-02 tam olarak bu: `verify_packs` 0
disagree diyor ve haklı, ama 14. seviyede menzil dörtte birine düşüyor. Korpüs
geneli tarandı: `class`/`subclass` tablolarında azalan sayısal geçiş **2** tane,
biri ilerleme tablosu bile değil. Yani bu sınıftan hata **nadir ama görünmez** —
hiçbir kapı kaynağın kendi içinde tutarlı olup olmadığını sormuyor.

**Ve bir bulgu türü daha görüldü: alanı da okuyucusu da hazır olan mekanik.**
F-a5e-ag-01'de eksik olan tek şey mapper satırı — `grants_save_prof_from_asi`
şemada beyan edilmiş, `pending_choice_resolver_dialog` iki yerde okuyor,
built-in `Resilient` onunla çalışıyor, `tool/` altında ise **hiç geçmiyor**.
Yeni kontrol, sonraki birimler için: *"bu alanı okuyan var mı, yazan var mı?"* —
`grep -rn <alan> lib/ | wc -l` ve `grep -rn <alan> tool/ | wc -l` ikilisi
`🔴 0%` bir satırın `S` mi `M` mi olduğunu tek adımda söylüyor.

#### `open5e-bfrd` (`class` + `subclass`) sonucu — 2026-08-18

Dalga 1'in **en ucuz ve son** birimi: 2 varlık (`Mechanist` sınıfı, `Metallurgist`
arketipi). Paketin öteki 2.471 varlığı (`monster` 360, `trait` 772,
`creature-action` 1.338, `language` 1) **Dalga 4'ün** işi ve bu birimde
ölçülmedi. `verify_packs --doc bfrd --only class,subclass` → **2 ok · 0 disagree ·
0 absent · 0 unsourced · 1 unverifiable** (tek unverifiable `caster_kind`, yazılı
kural: `caster_type` bir enum, kopyalanmıyor), eşleşme **1/1 class · 1/1 subclass**.
`gate_packs --packs /tmp/one` yeşil; `dupe_census` C "nothing installed" **0**.

**Plandaki dört uyarının hepsi ölçüldü, ikisi düzeltildi.**

1. **Lisans `cc-by-40`** — doğru ve **iki dosyada da** tutarlı; dahası paketin
   `attribution` metni de CC-BY metni (OGL metni değil), yani lisans etiketi
   yalnız alanda değil **gövdede** de doğru. G2 ✅.
2. **`Mechanist` `caster_kind: 'None'`** — kaynak `caster_type: NONE` (yeniden
   ölçüldü, `a5e-ag`'den kopyalanmadı). İki kartın `description`'ında
   `Spellcasting` / `spell slots` / `cantrip` / `spell list` geçmiyor: sınıf
   gerçekten büyücü değil, **F-pass0-10 büyümüyor**.
3. **F-pass0-07 dağılımı `bfrd: 3`** — komut yeniden çalıştırıldı, toplam yine
   **19**, `bfrd`'nin 3'ü doğrulandı: `Counter Spell`, `Cultist, Fanatic`,
   `War Horse Skeleton`. **Ama üçü de `monster` / `creature-action`**, yani bu
   birimin iki kartına dokunmuyorlar — kayıt Dalga 4'te tekrar bakılacak.
4. **Okuyucu/yazan testi** (a5e-ag'nin yedinci sorusu) — bu birimde **yeni bulgu
   üretmedi**: `bonus_skill_pick_count` (lib 7 / tool 0), `flavor_description`
   (2/0), `tool_proficiency_count` (6/0), `casting_ability_ref` (4/0),
   `multiclass_requirements` (1/0) hepsi "okuyucu var, yazan yok" = `M`, ve
   **beşinin de §5.1/§5.2'de `M` yazıyor**. Test doğru çalıştı, cause code'lar
   zaten doğruydu.

| # | Sonuç | Ölçüm |
|---|:--:|---|
| A1 | ✅ | `class` + `subclass` şemada; roundtrip yeşil |
| A2 | ⚠️ | tek boşluk `class.primary_ability_ref` (zorunlu) — kaynak `primary_abilities: []`, §5.8'de ⚪ yazılı (B7). K7, `a5e-ag` ile aynı |
| A3 | ⚠️ | 0 unsourced; ama **F-bfrd-01 (yeni)** — `### Class Table`'ın 2. sütun başlığı `Augment Effects Known (2)`, mapper'ın ürettiği bir etiket; kaynağın `pk`'si ona `augmented-items` diyor |
| A4 | ✅ | `Mechanist` / `Metallurgist` korpüste tek; built-in'de karşılığı yok. F-pass0-07'nin `bfrd: 3` satırı **bu iki kartta değil** |
| A5 | ➖ | tek varlıklı iki kategoride "tek sabit sütun" ölçülemez |
| B1 | ✅ | `--list-builtin-same` çıktısında `bfrd` **hiç geçmiyor** |
| B2 | ✅ | `--list-shared`'da `bfrd` var ama satırların hepsi `trait`/`creature-action`/`monster` + `language Void Speech` (L2'nin yazılı kararı); `class`/`subclass` **yok** |
| B3 | ⚠️ | `Proficiencies` ve `Starting Equipment` özellikleri kaynakta **var** ve `description`'a düzyazı olarak giriyor; `tool_proficiency_*`, `granted_tool_refs`, `equipment_choice_groups`, `default_inventory_refs` boş. §5.1'de **`M`🔗 yazılı** → K7, bulgu değil |
| B4 | ✅ | gate yeşil; `parent_class_ref` in-pack **hard ref** ve hedefi `class Mechanist` (pakette aynı adda bir `monster` da var — farklı kategori, çakışma değil) |
| B5 | ✅ | `metadata.links` yok + katalog `requires: []`; softRef'lerin hepsi built-in'e (§2.1, beyan gerekmez) |
| C1 | ✅ | `class.features` 19 satır (1→20), `subclass.features` 7 satır, `granted_at_level: 3` = `min(ClassFeatureItem.level)` ve **doğru** — F-toh-01'in tuzağı (tablo satırı 1. seviyede) burada yok, çünkü tablo sütunları `_isTableFeature` ile ayrılıyor |
| C2 | ➖ | `species`/`background`/`feat` yok |
| C3 | ➖ | `spell` yok |
| C4 | ➖ | `monster` + çocuk satırlar **Dalga 4** |
| C5 | ➖ | `magic-item` yok |
| C6 | ✅ | `subclass`'ta grant bloğu **yok** ve bu şemada yazılı bir karar (`content.dart` `_subclassCategory` yorumu); `mechanical_notes` bu iki kategoride beyan edilmemiş |
| C7 | ✅ | `_lookup` sözlükleri (ability, armor-category, weapon-category, skill) çözülüyor; `unmapped_report.json`'ın 3 satırının hiçbiri `bfrd` değil |
| C8 | ✅ | `class`'ın 22 boş alanının **22'sinde** §5.1'de cause code var (⚪ 5, `M` 14, `S` 3), `subclass`'ın 5 boşunun 5'inde §5.2'de (`M`) |
| D1 | ✅ | **2 ok / 0 disagree / 0 absent**; sınıfın parse edilmiş yeterlilikleri (`Light/Medium/Shield`, `Simple/Martial`, 2 beceri / 5 seçenek, CON+INT) kaynak `Proficiencies` düzyazısıyla **birebir** |
| D2 | ✅ | tek unverifiable `caster_kind`, `verify.dart`'ta yazılı kuralla |
| D3 | ✅ | gate yeşil |
| E1 | ⚠️ | 9 dolu `class` alanının **9'unun** da `lib/` içinde okuyucusu var. Ama **F-pass0-08 doğrulandı**: 26 `features` satırının (19 class + 7 subclass) **0'ı** grant anahtarı taşıyor. Büyü listesi tablosu yok → F-pass0-08'in **24**'lük sayısı büyümüyor |
| E2 | ✅ | mekanik olmayan tek alan `description`, beyan edilmiş |
| E3 | ✅ | `caster_kind: 'None'` = kaynak `NONE`; iki kartın metninde büyücülük yok → F-pass0-10 büyümüyor |
| F1 | ✅ | `pack_install_roundtrip_test` yeşil |
| F2 | ✅ | paket tarafı yeşil (224 çift, 446 pump); tek kırmızı hâlâ built-in grubu = F-pass0-01 |
| F3 | ✅ | `wizard_pack_families_test` yeşil |
| F4 | ✅ | `entity_link_navigation_test` yeşil |
| G1 | ✅ | `build_catalog` çalıştırıldı → `git status` temiz, drift yok; `size_bytes` **2.213.260** = dosyanın kendisi, `counts` altı kategoride birebir |
| G2 | ✅ | `publisher` / `license` / `game_system` / `is_srd_overlap` iki dosyada aynı (Kobold Press · `cc-by-40` · `5e-2014` · false) + CC-BY `attribution` metni |
| G3 | ✅ | `is_srd_overlap: false`; `bfrd` bir SRD belgesi değil, Kobold Press'in kendi SRD'si |

**Sayım: 20 ✅ · 5 ➖ · 0 ⛔ · 6 ⚠️.**

**Okuma bütçesi.** Paket dosyası (2,11 MB) **hiç baştan sona açılmadı**;
`scan_pack.py bfrd --cat class/--cat subclass` (~60 satır) + tek satırlık python
sorguları yetti. Kaynaktan okunan: `CharacterClass.json` (2 satır),
`ClassFeature.json` / `ClassFeatureItem.json` (sayım + 3 satır düzyazı).

**Üç aday ölçümde düştü.**
> 1. **"Sınıfın başlangıç ekipmanı ve alet yeterlilikleri düşüyor"** — düşmüyor,
>    `description`'a giriyor; ve daha önemlisi `a5e-ag`'nin *"class kartının 20
>    boş alanı `S`, kaynak `CharacterClass` yalnız beş sütun taşıyor"* cümlesi
>    **bu birimde yanlış çıktı**: ekipman/alet kaynakta var, ama
>    `CharacterClass`'ta değil, `ClassFeature`'ın `STARTING_EQUIPMENT` /
>    `PROFICIENCIES` satırlarında. §5.1 zaten `M`🔗 diyor, `S` demiyor — yani
>    doğru cause code dosyada duruyordu, yanlış olan devir notuydu (altıncı soru).
> 2. **"Aynı özellik hem `description`'da hem `features`'ta duruyor"** — 103
>    `class`/`subclass` kartının tamamında böyle (bfrd'de 26/26 satır). Ama §5.2
>    `flavor_description` satırı bunu **`M` olarak yazmış**: *"everything is folded
>    into `description`"*. K7 → bulgu değil, o `M` satırının parçası.
> 3. **`**At this level:** d8` gövdeli yarım feature satırları** — `Heavy Hitter`
>    9. ve 15. seviyede yalnız yeni zarı yazıyor. Korpüste **3** satır
>    (`bfrd` 2, `a5e-ag` 1) ve kaynak `ClassFeatureItem.detail` birebir bu; satır
>    seviyeli ilerlemeyi doğru gösteriyor. Kusur değil.

**Dalga 1'in kapanış dersi.** Sekiz birimde bulunan 18 bulgunun **10'u `pass0`**
kapsamlı, yani tek tek paketlerin değil mapper'ın kusuru — ve paket başına düşen
"kendi" bulgusu ortalama **1**. Dalga 1 karakter yaratmayı besleyen her kategoriyi
(background, feat, species, subspecies, subclass, class, spell) en az bir kez
gördü; Dalga 2'den itibaren kategori çeşitliliği düşüyor, tekrar artıyor.

### Dalga 2 — Büyü paketleri

| Paket | Varlık | Kategoriler | Durum | Tarih | Bulgular |
|---|--:|---|:--:|---|---|
| `open5e-kp` | 31 | spell 31 | ⚠️ | 2026-08-18 | F-pass0-11 |
| `open5e-wz` | 43 | spell 43 | ⚠️ | 2026-08-18 | F-wz-01, F-wz-02, F-pass0-12 |
| `open5e-deepmx` | 64 | spell 64 | ⚠️ | 2026-08-18 | F-pass0-13, F-pass0-14 |
| `open5e-spells-that-dont-suck` | 180 | spell 180 | ⚠️ | 2026-08-18 | F-spells-that-dont-suck-01, -02, F-pass0-15 |
| `open5e-deepm` | 515 | spell 515 | ⬜ | — | — |

> Bu dalganın ortak riski tek: **U2'nin ölçtüğü 85 görünmez büyü** ve
> `class_refs` / `tags` ikilisi (checklist B3, F3). İlk birim (`kp`, 2026-08-18)
> bu riski doğruladı ve **ayrı bir kusur** buldu: süre sözlüğünde "kalıcı" satırı
> yok (F-pass0-11).

#### `open5e-kp` sonucu — 2026-08-18

31 varlık, tek kategori (`spell` 31), 74.597 bayt. `verify_packs --doc kp --only
spell` → **200 ok · 0 disagree · 0 absent · 0 unsourced · 74 unverifiable**,
eşleşme **31/31**. `gate_packs --packs /tmp/one` yeşil; `dupe_census` C "nothing
installed" **0**, A/B listelerinde `kp` **hiç geçmiyor**. `unmapped_report.json`
yalnız üç `alignment` satırı taşıyor (canavar paketlerinden), `kp`'den sıfır.
Okuma bütçesi: `scan_pack.py` iki mod (~170 satır) + kaynağın 4 alan sorgusu;
paket dosyası **açılmadı** (K2).

**Bu birimin üç ölçümü.**

1. **Metin sadakati birebir.** 31 kartın `description`'ı kaynağın `desc`'iyle
   **bayt bayt aynı** (9 satırda kuralın yazdığı `**At Higher Levels.**` eki
   dahil), adlar 31/31 aynı. Kaynağın kendi bozuk cümlesi de aynen geliyor
   (`Selfish Wish`: kapanmayan parantez, madde işaretleri düz metne yapışmış) —
   **upstream kusuru, `S`**, mapper'ın eklediği/kaybettiği bir şey yok.
2. **`material_*` 0/31 = `S`** — kaynakta `material` bir **bool** (31/31 satırda),
   `material_specified` boş. `a5e-ag`'nin sebebiyle aynı, `toh`'unkiyle farklı.
   Korpüs geneli bu alan **369/1.297 dolu** (`deepm` 288, `spells-that-dont-suck`
   81), yani §5.6'da satırı **yok** ve olmasına da gerek yok — 0% olan bir alan
   değil. Bu birimin `S` gerekçesi burada yazılıdır (C8).
3. **`class_refs` 21/31 (alan `required`)** — 7 kart hiçbir sınıf taşımıyor
   (F-kuru-01 komutu yeniden çalıştırıldı: **93 / 85**, dağılım `kp 7 · deepm 75 ·
   a5e-ag 3` — değişmedi), 3 kart yalnız `Anti Paladin` etiketi taşıyor ve o sınıfı
   hiçbir paket göndermiyor, yani §5.6'nın yazılı filtresi gereği ref alamıyor.
   İkisi de yazılı açık; bu birimde **büyümediler**.

**Yeni bulgu: F-pass0-11** (checklist A3) — kaynağın `permanent` dediği süre karta
`Until Dispelled` yazılıyor. `kp`'de 2 kart, korpüste **25** (`a5e-ag` 12,
`deepm` 9, `kp` 2, `deepmx` 1, `spells-that-dont-suck` 1). Tier-0 `duration-unit`
sözlüğünde yedi satır var, "kalıcı" yok; mapper `Special` yerine `Until Dispelled`
seçiyor, yani karta kaynağın söylemediği bir mekanik (*dispel magic* bitirir)
giriyor. Bulgu ölçümden değil **okumadan** geldi — `duration_unit_ref` kural
tablosunda yok, bu yüzden 0 disagree ile birlikte yaşıyor.

**Ölen aday: `shape_size_unit`.** 5 alan kartının hepsinde kaynak birimi `None`,
paket `area_size_ft` yazıyor. Mapper'ın yazılı gerekçesi var
(`mappers/spell.dart:108-115`: snapshot'ta feet dışında birim **yok**) ve §5.6
aynı cümleyi taşıyor → K7, bulgu değil.

| # | Sonuç | Ölçüm |
|---|:--:|---|
| A1 | ✅ | `spell` şemada; roundtrip yeşil |
| A2 | ⚠️ | `class_refs` **required** ama 21/31 — 7 kartta kaynakta sınıf yok (F-kuru-01, ⚪), 3 kartta `Anti Paladin` (§5.6'nın yazılı ref filtresi). Diğer 10 zorunlu alan 31/31 |
| A3 | ⚠️ | 0 unsourced; ama **F-pass0-11 (yeni)** — `permanent` → `Until Dispelled` |
| A4 | ✅ | 31/31 ad kaynakla aynı; built-in'de karşılığı olan tek ad yok |
| A5 | ✅ | 16 dolu sütunun hiçbiri tek sabit değil (en düşük ayrık değer 2: `is_ritual` 27/4) |
| B1 | ✅ | `--list-builtin-same`'de `kp` yok |
| B2 | ✅ | `--list-shared`'da `kp` yok; korpüsteki 4 paylaşılan `spell` adı başka paketlerden |
| B3 | ✅ | okul, süre, atış birimi, bileşen, hasar tipi, kurtarma yeteneği hepsi ref; düzyazıda kalan mekanik yok |
| B4 | ✅ | gate yeşil, census C "nothing installed" 0; 4.045 softRef'in hepsi built-in'e |
| B5 | ✅ | `metadata.links` yok + `requires: []` — doğru: tüm ref'ler built-in'e (§2.1) |
| C1 | ➖ | `class`/`subclass` yok |
| C2 | ➖ | `species`/`background`/`feat` yok |
| C3 | ⚠️ | 25 şema alanının 17'si dolu. Boşların hepsinin sebebi yazılı: `at_higher_levels_text` `P` (9 satırın metni `description`'da), `effects` ⚪, `applied_condition_refs` `M`, `attack_type`/`reaction_trigger`/`material_*` `S` (kaynakta `attack_roll` 0/31, `reaction_condition` 0/31) |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ➖ | `spell`'de grant bloğu yok |
| C7 | ✅ | 7 ayrı Tier-0 sözlüğüne ref var, `unmapped_report.json`'da `kp` sıfır satır |
| C8 | ⚠️ | 8 boş alanın 7'sinin §5.6'da satırı var; `material_*`'ın **yok** — çünkü korpüste 0% değil (369/1.297). Bu birimin `S` gerekçesi yukarıda yazıldı |
| D1 | ✅ | 200 ok · 0 disagree · 0 absent |
| D2 | ✅ | 74 unverifiable, üçü de yazılı kuralla: `class_refs` (v1 sütunu), `casting_time_amount` (öneksiz), `range_ft` (`range_text`'ten ayrıştırılıyor) |
| D3 | ✅ | gate yeşil |
| E1 | ✅ | `spell`'in mekanik alanları grant alanı değil, M1'in 73 çiftine girmiyor; sayfaya inişi F2'nin render matrisi ölçüyor (yeşil) |
| E2 | ✅ | `effects` `notResolverRead`'de; `bundled_pack_resolve_test` iki yönlü kapı yeşil |
| E3 | ➖ | paket sınıf göndermiyor; slot ilerlemesi bu birimde ölçülemez |
| F1 | ✅ | `pack_install_roundtrip_test` yeşil |
| F2 | ✅ | paket tarafı yeşil (224 çift / 446 pump); tek kırmızı grup built-in = F-pass0-01 |
| F3 | ⚠️ | `wizard_pack_families_test` yeşil, ama `kp`'nin 7 büyüsü hiçbir sınıf listesinde görünmüyor (F-kuru-01) + 3 `Anti Paladin` büyüsü yalnız etiketten |
| F4 | ✅ | `entity_link_navigation_test` yeşil; kartın her ref'i built-in bir karta gidiyor |
| G1 | ✅ | `build_catalog` yeniden çalıştı, ağaç temiz; `size_bytes` 74.597 = dosya, `counts: {spell: 31}` = gerçek |
| G2 | ✅ | `licenses: ["ogl-10a"]`, `publisher: kobold-press` kaynağın `Document.json`'ıyla birebir; `attribution` metni de OGL metni |
| G3 | ✅ | `is_srd_overlap: false` ve doğru — built-in'le tek çakışan ad yok |

**Sayım: 20 ✅ · 6 ➖ · 0 ⛔ · 5 ⚠️** — ⚠️'ler A2, A3, C3, C8, F3;
➖'ler C1, C2, C4, C5, C6, E3 (tek kategorili paket).

#### `open5e-wz` sonucu — 2026-08-18

**Ne ölçüldü.** `verify_packs --doc wz --only spell` → **288 ok / 0 disagree /
0 absent / 0 unsourced / 96 unverifiable**, eşleşme **43/43**. `gate_packs`
(izole `/tmp/one`) yeşil, `dupe_census` C "nothing installed" **0**, `wz`
`--list-builtin-same` ve `--list-shared` listelerinin ikisinde de yok,
`unmapped_report.json`'da **sıfır** satır. `build_catalog` yeniden çalıştı, ağaç
temiz; katalog satırı `size_bytes 113.300` = dosya, `counts {spell: 43}` = gerçek,
`license ogl-10a` + `publisher Kobold Press` kaynağın `Document.json`'ıyla birebir.

**Metin sadakati (kp'den gelen ucuz kontrol, tekrar tuttu).** 43 kartın
`description`'ı kaynağın `desc` + `**At Higher Levels.**` ekiyle **bayt bayt
aynı**; 43/43 ad da aynı. Metin kaybı yok.

**Bu birimin farkı: `class_refs` 43/43.** `kp`'de yapısal ⚠️ olan alan burada
tam dolu — kaynağın v1 `dnd_class` sütunu 43 satırın hepsinde yazılı ve sekiz ad
da kanonik SRD sınıfı (Wizard 27, Warlock 18, Cleric 14, Druid 11, Sorcerer 10,
Bard 10, Ranger 3, Paladin 2). Bu yüzden A2 ve checklist F3 burada ✅.

**Üç yeni bulgu, üçü de süre alanından ve üçü de okumadan geldi** (`verify` 0
disagree diyor, çünkü `duration_unit_ref` kural tablosunda yok — `kp`'nin 4.
uyarısı doğrulandı):

1. **F-wz-01** — `Order of Revenge`: kaynak `1 hour/caster level`, kart `Hours 1`.
   Regex ilk sayıyı alıp kuyruğu atıyor; kaynağın verdiği ölçek küçülüyor.
2. **F-wz-02** — `Storm of Axes`: kaynağın `duration`'ı `concentration + 1 round`,
   `concentration` bool'u `false`; mapper yalnız bool'u okuduğu için **zorunlu**
   `requires_concentration` alanı `false` iniyor. `Eternal Echo` aynı ailede ama
   sebebi kaynağın v1/v2 çelişkisi (`Concentration` ↔ `special`).
3. **F-pass0-12** *(yayılan)* — `1 year` süreler `Special` + `null` oluyor; sayı
   büsbütün kayboluyor. Korpüste 3 kart (`deepm` 2, `wz` 1).

**Doğrulanan devir uyarısı.** F-pass0-11'in dağılım tablosu `wz` için **0**
bekliyordu; komut yeniden çalıştırıldı, kaynakta `permanent` ile başlayan satır
**0** — tablo değişmedi, yeni kayıt açılmadı.

**Ölen aday: `SpellCastingOption.json`.** `wz`'de 161 satır var ve 60'ı gerçekten
veri taşıyor (`target_count` 25, `damage_roll` 23, `range` 7, `duration` 5) —
yani "boş dosya" değil. Ama §7'nin (audit:2025) yazılı gerekçesi *"payload taşıyıp
`Spell.higher_level` düzyazısı olmayan büyü: 0, her belgede"*; `wz`'de ölçüldü:
payload taşıyan **9** büyünün **9'unun da** düzyazısı var, `desc` sütunu 161
satırın hepsinde `null`. Gerekçe ayakta → K7, bulgu değil.

**`material_*`'ın `S` gerekçesi (C8, birim başına yazılır).** Kaynakta `material`
43/43 **bool** (`false`), `material_specified` 43/43 boş, `material_cost` 43/43
`null` — yani boşluk pakette değil kaynakta. (`components`'te `Material` 30 kartta
var; kaynak "malzeme gerekir" diyor, "hangi malzeme" demiyor.)

| # | Sonuç | Ölçüm |
|---|:--:|---|
| A1 | ✅ | `spell` şemada; roundtrip yeşil |
| A2 | ✅ | 11 zorunlu alanın hepsi 43/43 (`class_refs` dahil) |
| A3 | ⚠️ | 0 unsourced; ama **F-wz-01**, **F-wz-02**, **F-pass0-12** — üçü de süre alanında |
| A4 | ✅ | 43/43 ad kaynakla aynı; built-in'de karşılığı olan ad yok |
| A5 | ✅ | 19 dolu sütunun hiçbiri tek sabit değil (en düşük ayrık değer 2) |
| B1 | ✅ | `--list-builtin-same`'de `wz` yok |
| B2 | ✅ | `--list-shared`'da `wz` yok; 43 büyü adının hiçbiri başka pakette geçmiyor |
| B3 | ✅ | okul, süre birimi, atış birimi, bileşen, hasar tipi, kurtarma yeteneği, alan şekli hepsi ref |
| B4 | ✅ | gate yeşil, census C "nothing installed" 0 |
| B5 | ✅ | `metadata.links` yok + `requires: []` — tüm ref'ler built-in'e (§2.1) |
| C1 | ➖ | `class`/`subclass` yok |
| C2 | ➖ | `species`/`background`/`feat` yok |
| C3 | ⚠️ | 25 şema alanının 19'u dolu (`kp`'de 17). Boşlar: `at_higher_levels_text` `P` (16 satırın metni `description`'da), `effects` ⚪, `applied_condition_refs` `M`, `material_*` `S` (yukarıda ölçüldü) |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ➖ | `spell`'de grant bloğu yok |
| C7 | ✅ | 7 ayrı Tier-0 sözlüğüne ref var, hepsi kanonik satır; `unmapped_report.json`'da `wz` sıfır |
| C8 | ⚠️ | 6 boş alanın 5'inin §5.6'da satırı var; `material_*`'ın **yok** (korpüste 0% değil, 369/1.297) — bu birimin `S` gerekçesi yukarıda |
| D1 | ✅ | 288 ok · 0 disagree · 0 absent |
| D2 | ✅ | 96 unverifiable, beşi de yazılı kuralla: `class_refs` (v1 sütunu, 43), `casting_time_amount` (öneksiz, 35), `range_ft` (`range_text`'ten, 14), `attack_type` (menzilden çıkarım, 2), `reaction_trigger` (cümleye çevriliyor, 2) |
| D3 | ✅ | gate yeşil |
| E1 | ✅ | `spell`'in mekanik alanları grant alanı değil; sayfaya inişi F2'nin render matrisi ölçüyor (yeşil) |
| E2 | ✅ | `effects` `notResolverRead`'de; `bundled_pack_resolve_test` 10/10 yeşil |
| E3 | ➖ | paket sınıf göndermiyor; slot ilerlemesi bu birimde ölçülemez |
| F1 | ✅ | `pack_install_roundtrip_test` yeşil (`open5e-wz installs and reads back unchanged`) |
| F2 | ✅ | paket tarafı yeşil (224 çift / 446 pump); tek kırmızı grup built-in = F-pass0-01 |
| F3 | ✅ | `wizard_pack_families_test` yeşil; 43 büyünün 43'ü bir sınıf listesinde görünüyor |
| F4 | ✅ | `entity_link_navigation_test` yeşil; kartın her ref'i built-in bir karta gidiyor |
| G1 | ✅ | `build_catalog` yeniden çalıştı, ağaç temiz; `size_bytes` 113.300 = dosya, `counts {spell: 43}` = gerçek |
| G2 | ✅ | `licenses: ["ogl-10a"]`, `publisher: kobold-press`, `gamesystem: 5e-2014` kaynağın `Document.json`'ıyla birebir |
| G3 | ✅ | `is_srd_overlap: false` ve doğru — built-in'le tek çakışan ad yok |

**Sayım: 22 ✅ · 6 ➖ · 0 ⛔ · 3 ⚠️** — ⚠️'ler A3, C3, C8;
➖'ler C1, C2, C4, C5, C6, E3 (tek kategorili paket).

#### `open5e-deepmx` sonucu — 2026-08-18

64 varlık, tek kategori (`spell` 64), 128.216 bayt. `verify_packs --doc deepmx
--only spell` → **466 ok · 0 disagree · 0 absent · 0 unsourced · 100
unverifiable**, eşleşme **64/64**. `gate_packs --packs /tmp/one` yeşil;
`dupe_census` C "nothing installed" **0** ve `deepmx` iki kopya listesinde de yok;
`unmapped_report.json`'da **sıfır** satır. `build_catalog` yeniden çalıştı, ağaç
temiz; katalog satırı `size_bytes 128.216` = dosya, `counts {spell: 64}` = gerçek,
`license ogl-10a` + `publisher Kobold Press` kaynağın `Document.json`'ıyla birebir.

**Metin sadakati — ucuz kontrolün doğru biçimi.** `wz`'de "bayt bayt aynı" diye
yazılan kontrol burada **17 kartta ayrıştı**; fark tamamen mapper'ın yazılı
kuralı: kaynakta `higher_level` dolu olan 17 satırda `spell.dart:158`
`desc + "\n\n**At Higher Levels.** " + higher_level` yazıyor. Beklenen dize
kurulup karşılaştırıldığında **64/64 birebir**. Yani bu kontrol ham `desc` ile
değil, *kural uygulanmış* dizeyle yapılmalı — `wz`'de 0 satır `higher_level`
taşıdığı için fark görünmemişti.

**Bu birimin farkı: `class_refs` 61/64 ve sebep `kp` ile aynı.** v2 `classes`
61 satırda dolu; boş kalan 3 satırın v1 `dmag-e` karşılığı **"Anti-Paladin"**
(`Borrowing`, `Risen Road`, `Strength of the Underworld`). §5.6'nın yazılı ref
filtresi bu adı elemek zorunda — hiçbir paket böyle bir sınıf göndermiyor, softRef
yazılsa `gate` `dangling-soft-ref` verirdi. Kartlar `tags: ["Anti Paladin"]`
taşımaya devam ediyor; F-kuru-01'in "93 kartın 85'i" ayrımındaki 8 karttan üçü
bunlar, yani **yazılı açık** → K7, yeni kayıt yok.

**İki yeni bulgu, ikisi de yayılan** (`verify` yine 0 disagree diyor — süre alanı
da bool sütunu da kural tablosunda yok):

1. **F-pass0-13** — koşullu/değişken süre kuyruğu düşüyor, kart düz sayı iddia
   ediyor: `Risen Road` kaynakta `2-12 hours`, kartta `Hours 12`;
   `Gift of Azathoth` kaynakta `24 hours or until the target attempts a third
   death saving throw`, kartta `Hours 24`. Korpüste 4 kart (`deepmx` 2,
   `deepm` 2). Karşı örnek: `kp`/`Feed the Worms` (`until destroyed`) hiçbir
   dalla eşleşmediği için `Special`/`null` iniyor ve kayıp yok — kayıp yalnız
   metin **bir sayıyla başladığında** oluşuyor.
2. **F-pass0-14** — `requires_concentration` **64/64 `false`**; ama
   `Shadow Realm Gateway` ("until you lose concentration on it") ve
   `Summon Old One's Avatar` ("each round you maintain concentration") gövdesinde
   kuralı yazıyor. Kaynağın `concentration` sütunu bu satırlarda `false`, v1
   `dmag-e` sütunu ise 64/64 `null` → cause `S`. Korpüste 7 kart, 5 paket
   (`deepmx` 2, `deepm` 2, `toh` 1, `wz` 1 = F-wz-02'nin kartı, `a5e-ag` 1).

**Doğrulanan devir uyarıları** *(komutlar yeniden çalıştırıldı, yeni kayıt
açılmadı)*. F-pass0-11 `deepmx` için **1** bekliyordu — kaynakta `permanent` ile
başlayan satır 1 (`Extract Foyson`), kart `Until Dispelled`. F-pass0-12 `deepmx`
için **0** bekliyordu — `year`/`week`/`month` ölçekli satır 0. `wz`'nin 2.
uyarısı (süre metninde `concentration` ara) burada **0** satır verdi; bulgu
gövde metninden çıktı, bu yüzden desen genişletildi.

**Ölen aday, ikinci kez: `SpellCastingOption.json`.** 169 satır, 42'si veri
taşıyor (`damage_roll` 23, `duration` 14, `range` 5), ama `desc` 169 satırın
hepsinde `null` ve payload taşıyan **8** büyünün **8'inin de** `higher_level`
düzyazısı var → audit:2025'in gerekçesi ayakta, K7.

**`material_*`'ın `S` gerekçesi (C8, birim başına).** Kaynakta `material`
64/64 bool (37 `true`), `material_specified` 64/64 boş, `material_cost` 64/64
`null` — boşluk pakette değil kaynakta.

| # | Sonuç | Ölçüm |
|---|:--:|---|
| A1 | ✅ | `spell` şemada; roundtrip yeşil (`open5e-deepmx installs and reads back unchanged`) |
| A2 | ⚠️ | `class_refs` **zorunlu** ama 61/64 — 3 kart `Anti-Paladin` (§5.6'nın yazılı ref filtresi, K7). Diğer 10 zorunlu alan 64/64 |
| A3 | ⚠️ | 0 unsourced; ama **F-pass0-13** (kesin olmayan süre kesin yazılıyor) ve **F-pass0-14** (gövdesi konsantrasyon diyen kart `false`) |
| A4 | ✅ | 64/64 ad kaynakla aynı; built-in'de karşılığı yok. Korpüste tek ad çakışması `Overclock` ve o bir `creature-action` (`a5e-mm`), farklı kategori |
| A5 | ⚠️ | 19 dolu sütunun **biri tek sabit**: `requires_concentration` 64/64 `false` — tam da F-pass0-14'ün alanı. Diğerlerinin en düşük ayrık değeri 2 |
| B1 | ✅ | `--list-builtin-same`'de `deepmx` yok |
| B2 | ✅ | `--list-shared`'da `deepmx` yok; 64 büyü adının hiçbiri başka pakette **büyü** olarak geçmiyor |
| B3 | ✅ | okul, süre birimi, atış birimi, bileşen, hasar tipi, kurtarma yeteneği, alan şekli hepsi ref (7 Tier-0 sözlüğü + `class` softRef ×150) |
| B4 | ✅ | gate yeşil, census C "nothing installed" 0 |
| B5 | ✅ | `metadata.links` yok + `requires` yok — tüm ref'ler built-in'e (§2.1) |
| C1 | ➖ | `class`/`subclass` yok |
| C2 | ➖ | `species`/`background`/`feat` yok |
| C3 | ⚠️ | 25 şema alanının 19'u dolu. Boşlar: `at_higher_levels_text` `P` (17 satırın metni `description`'ın sonuna eklenmiş), `effects` ⚪, `applied_condition_refs` `M`, `material_*` `S` (yukarıda ölçüldü) |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ➖ | `spell`'de grant bloğu yok |
| C7 | ✅ | 7 ayrı Tier-0 sözlüğüne ref, hepsi kanonik satır; `unmapped_report.json`'da `deepmx` sıfır |
| C8 | ⚠️ | 6 boş alanın 5'inin §5.6'da satırı var; `material_*`'ın **yok** — bu birimin `S` gerekçesi yukarıda (`wz` ile aynı) |
| D1 | ✅ | 466 ok · 0 disagree · 0 absent · 0 unsourced |
| D2 | ✅ | 100 unverifiable, beşi de yazılı kuralla: `casting_time_amount` (öneksiz, 52), `range_ft` (`range_text`'ten, 41), `attack_type` (menzilden çıkarım, 3), `class_refs` (v1 sütunu, 3), `reaction_trigger` (cümleye çevriliyor, 1) |
| D3 | ✅ | gate yeşil |
| E1 | ✅ | `spell`'in mekanik alanları grant alanı değil; render matrisi F2'de yeşil |
| E2 | ✅ | `effects` `notResolverRead`'de; `bundled_pack_resolve_test` yeşil |
| E3 | ➖ | paket sınıf göndermiyor; slot ilerlemesi bu birimde ölçülemez |
| F1 | ✅ | `pack_install_roundtrip_test` yeşil (75/75) |
| F2 | ✅ | paket tarafı yeşil (224 çift / 446 pump); tek kırmızı grup built-in = F-pass0-01 |
| F3 | ⚠️ | `wizard_pack_families_test` yeşil (39/39, `open5e-deepmx spell adımı` dahil); ama 64 büyünün **61'i** bir sınıf listesinde görünüyor — 3 `Anti-Paladin` kartı F-kuru-01'in yazılı 93−85 aralığında (⚪) |
| F4 | ✅ | `entity_link_navigation_test` yeşil; kartın her ref'i built-in bir karta gidiyor |
| G1 | ✅ | `build_catalog` yeniden çalıştı, ağaç temiz; `size_bytes` 128.216 = dosya, `counts {spell: 64}` = gerçek |
| G2 | ✅ | `licenses: ["ogl-10a"]`, `publisher: kobold-press`, `gamesystem: 5e-2014` kaynağın `Document.json`'ıyla birebir |
| G3 | ✅ | `is_srd_overlap: false` ve doğru — built-in'le çakışan büyü adı yok |

**Sayım: 19 ✅ · 6 ➖ · 0 ⛔ · 6 ⚠️** — ⚠️'ler A2, A3, A5, C3, C8, F3
(A5 bu dalgada ilk kez ⚠️); ➖'ler C1, C2, C4, C5, C6, E3 (tek kategorili paket).

#### `open5e-spells-that-dont-suck` sonucu — 2026-08-18

180 varlık, tek kategori (`spell` 180), 511.977 bayt. `verify_packs --doc
spells-that-dont-suck --only spell` → **1.678 ok · 0 disagree · 0 absent ·
0 unsourced · 253 unverifiable**, eşleşme **180/180**. `gate_packs --packs
/tmp/one` yeşil; `dupe_census` C "nothing installed" **0**, paket iki kopya
listesinde de yok (`--list-builtin-same` 0, `--list-shared` 0);
`unmapped_report.json`'da **sıfır** satır. `build_catalog` yeniden çalıştı, ağaç
temiz; katalog satırı `size_bytes 511.977` = dosya, `counts {spell: 180}` =
gerçek, `license cc-by-40` + `publisher SoMany Robots` + `gamesystem 5e-2014`
kaynağın `Document.json`'ıyla birebir.

**Devir notunun beş uyarısı da işledi.** (1) Metin sadakati *kural uygulanmış*
dizeyle ölçüldü (`spell.dart:158`) → **180/180 birebir**; ham `desc` ile
ölçülseydi 87 sahte fark çıkacaktı (`higher_level` bu belgede 87 satırda dolu —
`deepmx`'teki 17'nin beş katı, yani uyarı tam yerinde). (2) A5 sayıldı, bir
sabit sütun çıktı ama bu kez **dürüst**: `casting_time_amount` 180/180 `1` ve
kaynağın `casting_time` sütununda 1'den başka bir sayı **yok** (`action` 144,
`1minute` 19, `bonus-action` 12, `reaction` 4, `1hour` 1) — `deepmx`'in aksine
burada sabitlik kaynağın gerçeği. (3) Devralınan dört beklentinin dördü de
tuttu: F-pass0-11 → **1** (`permanent`, `Wayfinding`), F-pass0-12 → **0**,
F-pass0-13 → **0** (16 ayrık süre metninin hiçbiri sayıyla başlayıp koşulla
sürmüyor), F-pass0-14 → **0**. (4) `SpellCastingOption.json` üçüncü kez ölçüldü.
(5) `class_refs` **180/180** — v2 `classes` sütunu bu belgede eksiksiz, v1
karşılığı zaten yok; F-kuru-01'in görünmez büyülerinden **hiçbiri** bu pakette
değil.

**Üçüncü ölçüm, ilk kez farklı sonuç: `SpellCastingOption.json`.** 60 satır,
53'ü veri taşıyor ve `desc` bu kez **37 satırda dolu** — `wz`/`deepmx`'te
gerekçenin dayandığı "hepsi `null`" cümlesi burada geçerli değil. Ama gerekçe
yine ayakta, çünkü metinler ebeveynin `higher_level` düzyazısının **slot bazlı
kısaltmaları** (`Adaptation`/`slot_level_4` → *"Natural weapon bonus increases to
+2…"*, ebeveynin `higher_level`'ı aynı şeyi cümleyle söylüyor) ve o düzyazı
karta zaten `**At Higher Levels.**` bloğu olarak iniyor. Payload taşıyan **8**
büyünün **8'inde** `higher_level` dolu → bilgi kaybı yok, K7. *(Not: gerekçenin
"`desc` boş" biçimi artık genelleştirilemez; ayakta kalan biçim "içeriği
ebeveynin `higher_level`'ında zaten var".)*

**Üç yeni bulgu.**

1. **F-spells-that-dont-suck-01** (checklist A3, cause `M`) — kaynağın 8 satırı
   menzili `Self (60-foot radius)` / `Self (10-foot dome)` / `Self (1-mile
   radius)` biçiminde yazıyor; kartta `range_type: Self`, `range_ft: null`,
   `area_shape_ref: null`, `area_size_ft: null` — sayı da şekil de yok.
   `_range` `self` görünce dalı bitiriyor, parantezi okuyan kod yok; kaynak
   `range` sütunu bu satırlarda `0`. Korpüste `Self (N …)` yazan **tek** belge bu.
2. **F-spells-that-dont-suck-02** (checklist A3, cause `S`) — 5 kartın
   `material_cost_gp` alanı `0`, aynı kartın `material_description`'ı fiyatı
   söylüyor (`Devil Binding` *"…obsidian chalice worth at least 665 gp"*).
   Kaynağın `material_cost` sütunu bu satırlarda `'0'`, 18 satırda ise gerçek
   sayı — yani `0` burada "bedava" değil "girilmemiş". `deepm`'de aynı desen
   zarar vermiyor: orada sütun `null` ve `if (cost != null)` alanı hiç yazmıyor
   (288 malzemeli kartın **0**'ında `material_cost_gp == 0`).
3. **F-pass0-15** (checklist C8, cause `A`, yayılan) — §5.8'in `spell.effects`
   ⚪ gerekçesi iki ayak üstünde duruyor ve ikincisi ("dolduracak yapılandırılmış
   hasar satırı yok") ölçümle uyuşmuyor: v2 `Spell.json`'ın `damage_roll` sütunu
   gönderilen 8 büyü belgesinde **303 satırda** dolu (285'i düpedüz zar
   ifadesi). Verdict ⚪ kalır (okuyucu yokluğu ayakta), düzeltilecek olan
   gerekçenin kendisi — `monster.lair_action_refs`'in "Reason was wrong"
   satırıyla aynı desen.

**`material_*` bu birimde `S` değil.** Dalga 2'nin ilk üç birimi bu üçlüyü
"kaynakta boş" diye kapatmıştı; burada `material_specified` **81/180** dolu,
yani alanlar ilk kez gerçekten ölçülebildi: `material_description` 81/180
(80 ayrık değer), `material_consumed` 81/180 (11 `true`, kaynakla birebir),
`material_cost_gp` 81/180 — ve kusur bu üçüncüsünde (yukarıda). Kaynağın
`material` bool'u 82 satırda `true`, biri (`Spreadshot`) metinsiz; kart o satırda
`Material` bileşenini yazıyor ama açıklama yazmıyor — kaynağa sadık, bulgu değil.

| # | Sonuç | Ölçüm |
|---|:--:|---|
| A1 | ✅ | `spell` şemada; roundtrip yeşil (`open5e-spells-that-dont-suck installs and reads back unchanged`) |
| A2 | ✅ | 11 zorunlu alanın 11'i **180/180** — `class_refs` dahil (dalgada ilk kez tam) |
| A3 | ⚠️ | 0 unsourced; ama **F-spells-that-dont-suck-01** (yarıçap hiçbir alana yazılmıyor) ve **-02** (metin "665 gp" derken alan `0`) |
| A4 | ✅ | 180/180 ad kaynakla aynı; census'un iki kopya listesinde de paket yok |
| A5 | ✅ | 22 dolu sütunun biri sabit (`casting_time_amount` 180/180 `1`), ama kaynağın `casting_time` sütununda 1'den başka sayı yok → sabitlik gerçek. Diğerlerinin en düşük ayrık değeri 2 |
| B1 | ✅ | `--list-builtin-same`'de paket yok |
| B2 | ✅ | `--list-shared`'da paket yok |
| B3 | ✅ | 7 Tier-0 sözlüğüne ref (`spell-school` 180, `casting-time-unit` 180, `casting-component` 421, `duration-unit` 180, `ability` 94, `damage-type` 103, `area-shape` 22) + `class` softRef ×460 |
| B4 | ✅ | gate yeşil, census C "nothing installed" 0 |
| B5 | ✅ | `metadata.links` yok + `requires` yok — tüm ref'ler built-in'e (§2.1) |
| C1 | ➖ | `class`/`subclass` yok |
| C2 | ➖ | `species`/`background`/`feat` yok |
| C3 | ⚠️ | 25 şema alanının **22'si** dolu (dalganın en yükseği). Boşlar: `at_higher_levels_text` `P` (87 satırın metni `description` sonunda), `effects` ⚪ ama gerekçesi yarım → F-pass0-15, `applied_condition_refs` `M` |
| C4 | ➖ | `monster` yok |
| C5 | ➖ | `magic-item` yok |
| C6 | ➖ | `spell`'de grant bloğu yok |
| C7 | ✅ | 7 Tier-0 sözlüğünün her satırı kanonik; `unmapped_report.json`'da sıfır satır |
| C8 | ⚠️ | 3 boş alanın ikisinin gerekçesi doğru (`P`, `M`); `effects`'inki yarı yanlış → F-pass0-15 |
| D1 | ✅ | 1.678 ok · 0 disagree · 0 absent · 0 unsourced |
| D2 | ✅ | 253 unverifiable, dördü de yazılı kuralla: `casting_time_amount` (öneksiz, 160), `range_ft` (`range_text`'ten, 68), `attack_type` (menzilden çıkarım, 21), `reaction_trigger` (cümleye çevriliyor, 4) |
| D3 | ✅ | gate yeşil |
| E1 | ✅ | `spell`'in mekanik alanları grant alanı değil; render matrisi F2'de yeşil |
| E2 | ✅ | `effects` `notResolverRead`'de; `bundled_pack_resolve_test` yeşil (75/75) |
| E3 | ➖ | paket sınıf göndermiyor; slot ilerlemesi bu birimde ölçülemez |
| F1 | ✅ | `pack_install_roundtrip_test` yeşil (75/75) |
| F2 | ✅ | paket tarafı yeşil (224 çift / 446 pump); tek kırmızı grup built-in = F-pass0-01 |
| F3 | ✅ | `wizard_pack_families_test` yeşil (39/39); 180 büyünün **180'i** bir sınıf listesinde — dalgada ilk kez kayıp yok |
| F4 | ✅ | `entity_link_navigation_test` yeşil; kartın her ref'i built-in bir karta gidiyor |
| G1 | ✅ | `build_catalog` yeniden çalıştı, ağaç temiz; `size_bytes` 511.977 = dosya, `counts {spell: 180}` = gerçek |
| G2 | ✅ | `licenses: ["cc-by-40"]`, `publisher: somanyrobots`, `gamesystem: 5e-2014` kaynağın `Document.json`'ıyla birebir; atıf metni CC-BY-4.0 |
| G3 | ✅ | `is_srd_overlap: false` ve doğru — built-in'le çakışan büyü adı yok |

**Sayım: 25 ✅ · 6 ➖ · 0 ⛔ · 3 ⚠️** — ⚠️'ler A3, C3, C8; ➖'ler C1, C2, C4,
C5, C6, E3 (tek kategorili paket). Dalga 2'nin **en temiz** birimi: zorunlu
alanların hepsi tam, `class_refs` eksiksiz, kayıp yalnız iki dar desende
(parantezli Self menzili, sıfırla doldurulmuş malzeme fiyatı).

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

**Ölçüldü: 2026-08-17 (F3).** Dokuz kapının sekizi tabanında; onuncu satır
(render testi) tabanının **altında** ve taramanın ilk bulgusu oldu.

| Kapı | Beklenen | Ölçülen | Tarih | Not |
|---|---|---|---|---|
| `audit_packs` dolu yuva | 136 / 408 | **136 / 408** ✅ | 2026-08-17 | 44 ✅ + 84 🟡 + 8 `✅ ⚠` · 264 🔴 · 8 `—` |
| `audit_packs --builtin` | — | **306 / 725** (59 kategori, 2.719 varlık) | 2026-08-17 | Yeni taban. 142 ✅ + 154 🟡 + 10 `✅ ⚠` · 419 🔴 |
| `dupe_census` A | 0 | **0 same text** ✅ | 2026-08-17 | 1.636 ad çakışması, %100'ü farklı metin |
| `dupe_census` B | 189 / 193 | **189 ad / 193 kopya** ✅ | 2026-08-17 | `--list-builtin-same` → 0 satır |
| `dupe_census` C | 4.074 / 0 dangling | **4.074 / 0** ✅ | 2026-08-17 | 4.045 built-in'e, 29 kendi paketine |
| `gate_packs` | 0 ihlal | **green** ✅ | 2026-08-17 | — |
| `verify_packs` | 68.561 / 0 / 0 | **68.561 / 0 / 0** ✅ | 2026-08-17 | 3.303 unsourced · 17.268 unverifiable · 5.514/5.515 eşleşme (tek boşluk "Abjurationist", §6'da yazılı → K7) |
| `unmapped_report.json` | 3 | **3** ✅ | 2026-08-17 | üçü de `alignment` |
| M1 çiftleri | 73 / 247 / 1 | **73 / 247 / 1** ✅ | 2026-08-17 | — |
| Korpüs | 21.839 + 2.719 | **21.839 + 2.719** ✅ | 2026-08-17 | audit paydası 21.832 + 6 `language` + 1 `size` |
| 5 test süiti | hepsi yeşil | **+94 −1** ⚠️ | 2026-08-17 | `pack_field_render_test` → **F-pass0-01** |

### Pass 1 için Pass 0'dan düşen iş

- **A5 (⚠ tuzağı) — 8 satır**, hepsi tek sabit değerli: `species.creature_type_ref`
  (11/11) · `subspecies.creature_type_ref` (30/30) · `feat.category_ref` (73/73) ·
  `feat.repeatable` (73/73) · `magic-item.is_cursed` / `activation` / `is_sentient`
  (1.063/1.063) · `trait.trait_kind` (6.419/6.419). Sekizi de `verify_packs`'te
  **`unsourced`** olarak dönüyor — yani "kaynakta böyle bir sütun yok, değeri
  mapper koydu". Dalga 1 (`species`/`subspecies`/`feat`), Dalga 3 (`magic-item`)
  ve Dalga 4 (`trait`) bunları okumayla doğrular.
- **Ham çıktılar** oturum bazlıdır, saklanmaz — bir daha gerekirse komut yeniden
  çalıştırılır (K4 bir kez çalışmayı söyler, tekrar çalıştırmayı yasaklamaz).

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
