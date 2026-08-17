# Paket İçerik Uygunluk Taraması — Kontrol Planı ve İlerleme (Stage F1)

**Ölçüt:** `pack_conformance_checklist.md` · **Bulgular:** `pack_conformance_findings.md`
· **Yol haritası:** `open5e_content_audit.md` §6 Stage F

---

## Sonraki adım

> **Şu an:** Checklist **onaylandı** (F0, 2026-08-15), bu plan **onaylandı**
> (F1, 2026-08-17 — §10), bulgu defterinin formatı **onaylandı**
> (F2, 2026-08-17). **F3 sürüyor: Pass 0 (§6) + Dalga 0 + `a5e-gpg` + `a5e-ddg`
> + `open5e` + `tdcs` + `toh` bitti (2026-08-17).** 20 tarama biriminin 6'sı
> kapandı, defterde **15 bulgu** var: F-pass0-01 (checklist F2), F-builtin-01 (C4),
> F-builtin-02 (C8), F-pass0-02 (C2 — 30 background seçimli becerilerin hepsini
> hediye ediyor), F-pass0-03 (A5 — `ability_score_options` 27/27 aynı altı
> yetenek), F-pass0-04 (A3 — 6 kartın gövdesi `"[No description provided]"` ile
> açılıyor), F-pass0-05 (D1 — `granted_language_count` 31 satırın 2'sinde
> yanlış), F-pass0-06 (B3 — background ekipmanında adı yazılı eşya envantere
> girmiyor), F-pass0-07 (A4 — 19 kart adı built-in bir adın yazım varyantı,
> 9 pakette), F-open5e-01 (G3 — 5e-2024 belgesi 5e-2014 etiketli pakete
> karışıyor), F-pass0-10 (E3 — üçte-bir büyücü 4 subclass hiç slot almıyor; `toh`
> taramasında kapsamı `pass0`'a çıktı, eski kimliği F-open5e-02),
> **F-pass0-08** (E1 — 24 subclass büyü listesi yalnız düzyazı tablosu, 523
> feature satırının 0'ı grant taşıyor), **F-pass0-09** (C2 — background'un adı
> verilmiş dili yazılacak alan bulamıyor, 2 satır), **F-toh-01** (C1 —
> `Underfoot` 1. seviyede seçilebilen rogue arketipi), **F-toh-02** (B2 —
> `Scoundrel` background'u iki pakette, %83 aynı metin).
> On beşi de ❓ danışılacak.
>
> **Sıradaki iş: Dalga 1 → `open5e-a5e-ag`** (455 varlık: spell 371, feat 59,
> background 21, subclass 3, class 1 — dalganın **gerçek en büyüğü**; sonra
> `bfrd`'nin 2 satırı Dalga 1'i kapatır).
> Beş uyarı hazır: (1) `audit_packs`'i **`--only` olmadan çalıştırma**,
> örneklemde `--picks 2` yeter; (2) 371 büyü tek kategori — `toh`'un spell
> ölçümleri (material 0/91 `S`, higher_level prose'a gömülü) burada **yeniden
> ölçülür, varsayılmaz**: `a5e-ag`'nin kaynağında `material` 217/371 dolu,
> `material_specified` ise 0 → aynı `S`, ama sayıyı komut söylesin;
> (3) paketin **1 `class` + 3 `subclass`** kartı var — F-pass0-10'un "korpüste
> `'Third'` taşıyan 0 kart" iddiası ve F-toh-01'in `granted_at_level` kuralı
> burada sınanır (a5e sisteminin arketip seviyesi 2014'ünkinden farklı olabilir,
> **önce kaynağa bak**); (4) `game_system: a5e` — G3 için 2014/2024 değil, ayrı
> bir sistem; §4'ün SRD örtüşme sorusu buraya farklı iner; (5) 21 background,
> F-pass0-02…06'nın hepsinin dağılımında zaten var → **doğrulama**, ama
> `toh`'un dersi gereği dağılım tablosuna bakarak.
>
> **Test dosyalarının yeri** (geçen oturumda yanlış yol arandı): F grubu
> `test/application/services/pack_install_roundtrip_test.dart`,
> `test/presentation/character_creation/wizard_pack_families_test.dart`,
> `test/presentation/pack_field_render_test.dart`,
> `test/presentation/entity_link_navigation_test.dart`.
>
> **Bu birimin eklediği sorular.** `open5e`'den: kartın taşıdığı mekanik
> **şemada bir eve sahip mi**, ve o ev **doğru belgeden** mi dolduruluyor?
> `tdcs`'ten: bir alan boşsa, boşluk **pakette mi kaynakta mı**? Bu ikinci soru
> `tdcs`'te üç, `toh`'ta beş yanlış bulguyu önledi — kategori başına tek bir
> kaynak sütunu saymak yetiyor. `toh`'un eklediği **beşinci soru**: *alan dolu
> ve kaynakla aynı, ama **değer** kuralla uyuşuyor mu?* — `verify_packs` 661 ok /
> 0 disagree derken `Underfoot`'un 1. seviyesi oradaydı; kaynak sadık, kural
> değil. Ve **altıncı**, süreç sorusu: *devir notunun "zaten biliniyor" satırı
> ölçüldü mü?* Bu birimde bir uyarı (F-pass0-07 dağılımı) ve bir kayıt kanıtı
> (F-pass0-10'un komutu) ölçümde yanlış çıktı.
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
| `open5e-a5e-ag` | 455 | spell 371, feat 59, background 21, subclass 3, class 1 | ⬜ | — | — |

> `open5e-bfrd`'nin `class` 1 + `subclass` 1 satırı da **bu dalgada** bakılır
> (ucuz); canavarları Dalga 4'te.

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
