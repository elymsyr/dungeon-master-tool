# Paket İçerik Uygunluk Taraması — Bulgular (Stage F2)

**Ölçüt:** `pack_conformance_checklist.md` · **Süreç:** `pack_conformance_plan.md`
· **Yol haritası:** `open5e_content_audit.md`

> **Durum: F3 sürüyor — Pass 0 + Dalga 0 bitti (2026-08-17), 3 bulgu.** Sıradaki
> iş **Dalga 1 → `open5e-a5e-gpg`**. Format **F2'de onaylandı (2026-08-17)** —
> yazılarak değil, gerçek bir ölçümü şablona **doldurarak** (§ "Kuru çalışma").
> Defterin kendisi `python3 tool/check_findings.py` ile denetleniyor: her kaydın
> checklist maddesi, etkilenen varlık sayısı, kanıt bloğu, cause code'u ve
> seçenekleri var mı — ve üç özet sayaç gerçek kayıtlarla aynı şeyi söylüyor mu.

---

## Bu dosya ne değildir

- **Yapılacaklar listesi değil.** Bulgu, karar alınana kadar iş kalemi olmaz.
  Karar "düzelt" çıkarsa iş `open5e_content_audit.md` §6'ya **yeni faz** olarak
  dosyalanır; buradaki satır ona işaret eder.
- **Ham çıktı deposu değil.** Kanıt en fazla birkaç satır. Araç çıktısı buraya
  yapıştırılmaz — komutu yazılır, tekrar çalıştırılabilir olması yeterli.
- **Bilinen kabullerin listesi değil.** Yol haritasında yazılı gerekçesi olan
  boşluk (⚪ / ⛔) bulgu değildir. Gerekçe **bulunamıyorsa** bulgudur (checklist C8).

## Bulgu kimliği

`F-<kapsam>-<nn>` — örn. `F-toh-03`, `F-builtin-01`, `F-pass0-02`.
Kapsam ya paketin kısa adı (`open5e-` öneki olmadan), ya `builtin`, ya da korpüs
geneli için `pass0`. `F-kuru-*` yalnızca aşağıdaki kuru çalışmadır, sayaca girmez.

> [!warning] İki ayrı "F1" var
> Checklist'in **F grubu** (F1–F4, "kullanıcıya ulaşıyor mu") ile bu yol
> haritasının **§6 fazları** (F1–F4) aynı harfi kullanıyor ve bulgu kimlikleri de
> `F-` ile başlıyor. Yazım kuralı: checklist maddesi **`checklist F3`**, faz
> **`§6 F3`**. Onaylı bir dosyayı yeniden adlandırmaktansa tek satırlık kural.

**Bir kayıt = bir checklist maddesi.** İki madde birden ihlal ediliyorsa
*birincil* olan yazılır (aksi hâlde madde sayacı toplanamaz); ikinci madde
"Neden önemli" içinde anılır ya da ayrı kayıt açılır.

## Cause code

Kod dağarcığı `open5e_content_audit.md` §1 "Cause codes" tablosundan gelir ve
**burada uydurulmaz**: `S` kaynakta yok · `L` yükleniyor değil · `M` map'lenmiyor
· `D` kopya/link olmalı · `P` bilerek atlandı · `N` karşılığı yok.

O altı kodun hepsi **içerik kaybını** anlatır ve düzeltmeleri `bin/build_packs.dart`
ile `mappers/*.dart` içine iner. **Built-in SRD paketinin mapper'ı yok** — içerik
`lib/domain/entities/schema/builtin/srd_core/*.dart` içinde elle yazılmış; orada
`M` "el yazımı o alanı hiç yazmıyor" demektir, düzeltme adresi de o dizindir
(F3 / Dalga 0'da yazıldı; yeni kod uydurmaktan ucuz). Bu taramanın **E / F / G**
grubu maddeleri
(mekanik sayfaya iniyor mu, sihirbaz görüyor mu, katalog metadata'sı doğru mu)
oraya inmez — paket doğru, uygulama tarafı eksiktir. Onlar için kod **`A`**
(uygulama): düzeltme `lib/presentation` · `lib/application` · `tool/catalog_publish`
tarafında. Kod önerilemiyorsa `—` yazılır, boş bırakılmaz.

## Durum sözlüğü

| Durum | Anlam |
|---|---|
| 🔎 **açık** | Bulundu, yazıldı, henüz danışılmadı |
| ❓ **danışılacak** | Karar senden bekleniyor — seçenekler yazılı |
| 🛠 **faz dosyalandı** | Karar "düzelt"; iş `open5e_content_audit.md` §6'da bir faz |
| ✅ **kapandı** | Düzeltildi veya gerekçesi yazıldı; kapatan faz/commit belirtildi |
| ⚪ **kapsam dışı** | Bilinçli olarak yapılmayacak; sebebi yazılı |
| ❌ **geçersiz** | Yanlış alarm; neden yanlış olduğu yazılı (silinmez, kayıt kalır) |

## Yayılan bulgu — aynı kusur birkaç pakette

Tarama paket paket, oturum oturum ilerliyor (plan K6); tek bir mapper kusuru ise
19 pakete birden yayılabilir. Kural:

1. Kusur **ilk görüldüğü** oturumda yazılır, kapsamı `pass0` olur — paketin değil,
   korpüsün kusuru olduğu için.
2. Kayda bir **dağılım tablosu** eklenir (`paket | etkilenen`), sonraki oturumlar
   yeni kayıt açmaz, o tabloya satır ekler ve "Kategori / etki" toplamını günceller.
3. Paket sayacında yalnızca `pass0` bir artar. Dağılım tablosu kimin etkilendiğini
   zaten söylüyor; aynı şeyi iki yerde saymak sayaçları yalancı yapar.
4. Dağılım genişlerse "Kanıt" komutu **yeniden çalıştırılır** — sayı elle
   toplanmaz.

Tersi de kural: iki pakette **farklı** sebeple aynı belirti görülüyorsa bunlar iki
ayrı bulgudur, kapsamları kendi paketleridir.

---

## Özet sayaçlar

**Durum dağılımı**

| 🔎 açık | ❓ danışılacak | 🛠 faz | ✅ kapandı | ⚪ kapsam dışı | ❌ geçersiz | **Toplam** |
|--:|--:|--:|--:|--:|--:|--:|
| 0 | 3 | 0 | 0 | 0 | 0 | **3** |

**Checklist maddesine göre** *(bulgu geldikçe doldurulur)*

| Madde | Bulgu | Madde | Bulgu | Madde | Bulgu |
|---|--:|---|--:|---|--:|
| A1 | 0 | B1 | 0 | C1 | 0 |
| A2 | 0 | B2 | 0 | C2 | 0 |
| A3 | 0 | B3 | 0 | C3 | 0 |
| A4 | 0 | B4 | 0 | C4 | 1 |
| A5 | 0 | B5 | 0 | C5 | 0 |
| D1 | 0 | E1 | 0 | C6 | 0 |
| D2 | 0 | E2 | 0 | C7 | 0 |
| D3 | 0 | E3 | 0 | C8 | 1 |
| F1 | 0 | F3 | 0 | G1 | 0 |
| F2 | 1 | F4 | 0 | G2 | 0 |
| | | | | G3 | 0 |

**Pakete göre**

| Kapsam | Bulgu | Kapsam | Bulgu |
|---|--:|---|--:|
| `pass0` | 1 | `open5e-vom` | 0 |
| `builtin` | 2 | `open5e-ccdx` | 0 |
| `open5e-a5e-gpg` | 0 | `open5e-bfrd` | 0 |
| `open5e-a5e-ddg` | 0 | `open5e-tob2` | 0 |
| `open5e-open5e` | 0 | `open5e-tob` | 0 |
| `open5e-tdcs` | 0 | `open5e-tob3` | 0 |
| `open5e-toh` | 0 | `open5e-a5e-mm` | 0 |
| `open5e-a5e-ag` | 0 | `open5e-tob-2023` | 0 |
| `open5e-kp` | 0 | | |
| `open5e-wz` | 0 | | |
| `open5e-deepmx` | 0 | | |
| `open5e-spells-that-dont-suck` | 0 | | |
| `open5e-deepm` | 0 | | |

---

## Bulgu formatı — ve kuru çalışma

Şablon aşağıda. Uydurma bir örnekle değil, **gerçek bir ölçümle** doldurulmuş:
yol haritasının zaten bildiği "85 büyü hiçbir yoldan görünmüyor" açığı (aşağıdaki
bilinen açık #4). K7 gereği bilinen açık **bulgu değildir** — kuru çalışma için
seçilmesinin sebebi de bu: defteri kirletmeden şablonun her kutusu doldurulabiliyor
mu, ölçülebilir mi, denetçiden geçiyor mu, hepsi görülüyor.

F2 bunu doldururken formatın **üç kutusunun** boş kalamayacağını ölçtü: kanıt
komutu paket kırılımını da vermek zorunda (yoksa "yayılan bulgu" kuralı
uygulanamaz), cause code altı koddan hiçbirine oturmuyor (kod `A` bu yüzden var),
ve tek kayıt üç paketi birden anlatıyor.

<details>
<summary><b>Şablon — gerçek ölçü, ama bulgu değil (bilinen açık #4)</b></summary>

### F-kuru-01 — 85 paketli büyü hiçbir sınıfa bağlı değil

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, üç pakete yayılı |
| **Checklist** | checklist F3 (sihirbaz paketin satırlarını görüyor) |
| **Kategori / etki** | `spell` — 1.297 paketli büyünün **85**'i (dağılım aşağıda) |
| **Cause code (öneri)** | `A` — paket doğru, kaynakta sınıf yok; kayıp okuma tarafında |
| **Durum** | ⚪ kapsam dışı — yol haritasında ölçülü açık, bu taramanın bulgusu değil |

**Bulgu.** `class_refs` 93 büyüde boş; bunların 85'inde `tags` içinde de hiçbir
sınıf adı yok. Sihirbazın sınıf sekmesi her iki yoldan da bakıyor, ikisi de boş
olduğu için bu 85 kart hiçbir sınıfın büyü listesinde görünmüyor.

**Kanıt.**
```sh
python3 - <<'EOF'
import json,glob,collections
CL={'artificer','herald','anti paladin'}; per=collections.Counter(); noref=0
for f in glob.glob('assets/open5e_packs/open5e-*.pkg.json'):
    for e in json.load(open(f,encoding='utf-8'))['entities'].values():
        if e.get('type')!='spell' or (e.get('attributes') or {}).get('class_refs'): continue
        noref+=1
        if not {t.lower() for t in (e.get('tags') or [])} & CL:
            per[f.split('open5e-')[1][:-9]]+=1
print(noref, sum(per.values()), dict(per))
EOF
# 93 85 {'deepm': 75, 'kp': 7, 'a5e-ag': 3}
```

**Dağılım** *(yayılan bulgu kuralı — 2026-08-17'de ölçüldü)*

| Paket | Etkilenen |
|---|--:|
| `open5e-deepm` | 75 |
| `open5e-kp` | 7 |
| `open5e-a5e-ag` | 3 |

**Neden önemli.** L3 `class_refs`'i %92'ye çıkardı, U2 de `tags`'in 1.212 büyüyü
taşıdığını ölçtü; kalan 85 ikisinin de dışında. Sayı küçük ama Dalga 2'nin üç
paketinde yoğunlaşıyor — `deepm` taranırken "bu paketin büyüleri görünmüyor" diye
**yeniden keşfedilmesi** en olası açık bu.

**Seçenekler.**
1. **Düzelt** — sihirbaza "sınıfsız büyüler" girişi; kayıp okuma tarafında olduğu
   için mapper'a dokunmaz. Yeni faz gerekir.
2. **Gerekçe yaz** — kaynakta sınıf yok, ⚪ olarak §5.6'ya işlenir (bugünkü durum).
3. **Kapsam dışı** — 1.297'de 85, karar yazılı bırakılır.

**Karar.** Kuru çalışma — karar F4'ün işi. · **Tarih:** — · **Kapatan:** —

</details>

Kayıt yazıldıktan sonra `python3 tool/check_findings.py` çalıştırılır; hiçbir kutu
eksik değilse ve üç sayaç kayıtlarla uyuşuyorsa temiz döner.

---

## Bulgular

### Pass 0 — korpüs geneli

### F-pass0-01 — render kapısı ilk SRD alanında duruyor: 306 çiftin 223'ü hiç ölçülmüyor

| | |
|---|---|
| **Kapsam** | `pass0` — kapının kendisi; içerik değil |
| **Checklist** | checklist F2 (her (kategori, alan) çifti çökmeden render oluyor) |
| **Kategori / etki** | built-in SRD — 306 (kategori, alan) çiftinin **223**'ü hiç render edilmiyor; tetikleyen alan `pack.content_quantities` (8 SRD paket varlığı). 19 resmi paketin 141 çifti yeşil |
| **Cause code (öneri)** | `A` — veri ve widget doğru; kusur testin sarmalayıcısında |
| **Durum** | ❓ danışılacak |

**Bulgu.** `pack_field_render_test`'in `_wrap`'i temasız bir `MaterialApp`
kuruyor. `_LevelTableFieldWidget.build` ise
`Theme.of(context).extension<DmToolColors>()!` yazıyor (aynı `!` bu dosyada 6
widget'ta var) — uzantı yoksa null-check patlıyor. Uygulamada tema uzantıyı hep
kaydediyor (`lib/presentation/theme/palettes.dart:1070`), **kullanıcı
etkilenmiyor**; patlayan şey kapı. Ve `expect` ilk hatada testi bitirdiği için
SRD taraması 83. çiftte duruyor: kalan **223** çift ölçülmeden kalıyor.

Tetikleyen veri 2026-08-14'te geldi: `6de4b1e` SRD paketlerine
`content_quantities` **ekledi** (T2-3 relabel'ı, "shape unchanged" notuna rağmen
alanın kendisi yeniden yazıldı). Test aynı gün ama **daha önce** yazılmıştı
(`4cba473`), o yüzden yazıldığında yeşildi.

**Kanıt.**
```sh
flutter test test/presentation/pack_field_render_test.dart
# 00:24 +94 -1: builtin SRD fields render [E]
#   SRD: Burglar's Pack → pack.content_quantities (levelTable, readOnly=true) render hatası
#   Expected: null   Actual: _TypeError:<Null check operator used on a null value>
# pack_field_render: 224 (kategori, alan) çifti, 446 pump

dart run tool/open5e_import/bin/audit_packs.dart --builtin --markdown | grep -c '^| ✅\|^| 🟡'
# 306   ← SRD'nin dolu (kategori, alan) çifti; testin taraması bunun 83'ünde duruyor
```

Duruş noktası (83/306) aynı yineleme sırasını tekrar eden tek kullanımlık bir
probe ile ölçüldü; temalı sarmalayıcıyla (`buildThemeData('dark')`) aynı alan
`readOnly` iki modda da **hatasız** render oluyor — widget'ın kendisi sağlam.

**Neden önemli.** Checklist F2 bugün "**438 çift / 876 pump**" diyor; kapı
gerçekte **224 çift / 446 pump** ölçüyor ve tamir edilse **447** ölçecek (141
paket + 306 SRD). Yani ölçütteki sayı ölü, kapı da kendi kapsamının yarısını
sessizce bırakmış durumda. Dalga 0 (built-in SRD) bu kapıya güvenerek taranırsa,
"built-in render temiz" cümlesi 306 çiftin 83'ü hakkında olur.

**Seçenekler.**
1. **Düzelt (test tarafı)** — `_wrap`'e `theme: buildThemeData('dark')`; tek
   satır, kapı 447 çifte döner. Yeni faz gerekir (K1).
2. **Düzelt (widget tarafı)** — `extension<DmToolColors>()!` yerine varsayılana
   düşen okuma (6 yer). Daha geniş diff, ama widget'lar temadan bağımsız
   render olur.
3. **Kapsam dışı** — kullanıcı etkilenmiyor. O zaman checklist F2'nin sayısı
   224/446 olarak düzeltilmeli ve "223 çift ölçülmüyor" yazılı kabul olmalı.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### Dalga 0 — built-in SRD

### F-builtin-01 — 345 SRD statbloğunun hiçbirinde kurtarma ve beceri satırı yok

| | |
|---|---|
| **Kapsam** | `builtin` |
| **Checklist** | checklist C4 (monster + çocuk satırlar) |
| **Kategori / etki** | `monster` 248 + `animal` 97 = **345** statblok; `save_bonuses` ve `skill_bonuses` ikisi de **0%** (4 audit yuvası). SRD kaynağı bu satırları taşıyor |
| **Cause code (öneri)** | `M` — el yazımı alanı hiç yazmıyor (`srd_core/monsters.dart`, `animals.dart`) |
| **Durum** | ❓ danışılacak |

**Bulgu.** Şema iki alanı `proficiencyTable` olarak beyan ediyor
(`builtin/content.dart:1272-1275`) ve her ikisinin de **varsayılan tablosu var**
(`proficiencyTableDefault(kDnd5eSavingThrows / kDnd5eSkills)`). Anahtarlar
`srd_core` içinde **hiç geçmiyor**, yani 345 statblok kartı kurtarma/beceri
tablosunu tamamen yetkinliksiz gösteriyor — boş değil, **yanlış**.

Yazarın veriyi görmüş olduğu ölçülebiliyor: Adult Red Dragon
(`monsters.dart:176`) `passive_perception: 23` taşıyor. SRD 5.2.1'de o değer
10 + Perception **+13**'ten gelir, yani beceri bonusu hesaba girmiş ama satır
karta yazılmamış. Aynı kartta SRD'nin verdiği Dex/Wis kurtarmaları da yok.

**Kanıt.**
```sh
grep -c 'save_bonuses\|skill_bonuses' \
    lib/domain/entities/schema/builtin/srd_core/monsters.dart \
    lib/domain/entities/schema/builtin/srd_core/animals.dart
# monsters.dart:0
# animals.dart:0

dart run tool/open5e_import/bin/audit_packs.dart --builtin --markdown \
  | grep -E '^\| . \| `(save|skill)_bonuses`'
# | 🔴 | `save_bonuses`  | Combat |  | 0% (0/248) |   ← monster
# | 🔴 | `skill_bonuses` | Combat |  | 0% (0/248) |
# | 🔴 | `save_bonuses`  | Combat |  | 0% (0/97)  |   ← animal
# | 🔴 | `skill_bonuses` | Combat |  | 0% (0/97)  |
```

**Neden önemli.** Bu, masada en çok bakılan iki satır: DM canavarın kurtarma
atışını her turda atıyor. Paketli canavarlarda alan **dolu** geliyor (plan §4
`skill_bonuses.rows`'u ham JSON maliyeti olarak ölçtü), yani built-in SRD
canavarları bugün 19 resmi paketin canavarlarından **daha zayıf** kartlar.
Ayrıca yol haritası bu boşluğu hiç yazmamış: `save_bonuses` / `skill_bonuses`
`open5e_content_audit.md` içinde **hiç geçmiyor** — yani K7 muafiyeti yok.

**Seçenekler.**
1. **Düzelt** — 345 statbloğa iki satır eklemek el işi; yeni faz gerekir ve
   SRD PDF'inden okunmalı (kaynağı `docs/SRD_CC_v5.2.1.pdf`).
2. **Kısmi düzelt** — yalnız kurtarma satırı olan canavarlar (CR ≥ 5 civarı)
   önce; geri kalanı ⚪ yazılı kabul.
3. **Kapsam dışı** — o zaman iki alanın built-in tarafındaki 0%'ı yazılı bir
   ⛔ gerekçesi almalı (checklist C8), çünkü şu an hesapsız boş.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-builtin-02 — built-in'in §5'i yok: 419 boş yuvanın hiçbirinin yazılı sebebi yok

| | |
|---|---|
| **Kapsam** | `builtin` |
| **Checklist** | checklist C8 (boş kalan her alanın yazılı bir sebebi var) |
| **Kategori / etki** | 59 kategori / 725 yuvanın **419**'u 🔴 ve tek satırlık gerekçesi bile yok. En görünür bloğu: 39 Tier-0 kategorisinin 37'sinde `summary` + `effects` 0% → **345** sözlük satırı yalnızca addan oluşuyor |
| **Cause code (öneri)** | `M` — el yazımı yazmıyor (`srd_core/` + `builtin/lookups.dart` seed'leri) |
| **Durum** | ❓ danışılacak |

**Bulgu.** Yol haritası §5, **19 resmi paketin** alan alan politika tablosu:
her 🔴 satırın bir cause code'u var (§5.8). Built-in paketin böyle bir tablosu
**hiç yok**, ama boş yuvası 19 paketin toplamından fazla: **419**. Üçe ayrılıyor:

| Blok | Yuva | Yorum |
|---|--:|---|
| Beş ortak lookup alanı — `abbreviation` · `summary` · `effects` · `icon_name` · `color` | **194** | `_commonLookupFields` her Tier-0 kategoriye ekliyor (`lookups.dart:117`); yalnız `ability` ve `skill` doldurulmuş |
| Grant bloğu alanları (`granted_*`, `speed_*`, `*_bonus*` …) | ~205 | **tasarım gereği** boş — "one mechanic, one field": kart yalnız verdiği mekaniği yazar |
| Gerçek içerik alanları (`monster.save_bonuses`, `condition.ends_on`, `magic-item` sentient/attunement bloğu …) | ~20 | ayrı bulgular; ilki **F-builtin-01** |

Sertliği ölçen tek sayı: **zorunlu ve boş alan 0** — yani hiçbir kart yarım
değil (checklist A2 built-in'de ✅). Kusur kapsamda değil, **hesapta**.

Kullanıcıya değen kısım Tier-0 sözlüğü: `condition` "Grappled" kartı
`stacks` + `grants_incapacitated` taşıyor (mekanik çalışıyor) ama
`summary`/`effects` boş — DM kuralı okuyamıyor. Ve her paketin yumuşak ref'i
buraya iniyor: Pass 0 **4.045** ref'in built-in'e indiğini ölçtü, hepsi
çözülüyor (checklist B4 ✅), gövdesiz bir karta.

**Kanıt.**
```sh
dart run tool/open5e_import/bin/audit_packs.dart --builtin --markdown > /tmp/b.md
python3 - <<'EOF'
import re,collections
cats=re.findall(r'### `([^`]+)` — (\d+) entities.*?\n(.*?)(?=\n### |\Z)',open('/tmp/b.md').read(),re.S)
red=collections.Counter(); req=0; nameonly=0
for slug,n,body in cats:
    for gl,f,_,r,_ in re.findall(r'\| (.+?) \| `([^`]+)` \| ([^|]*)\| ([^|]*)\| (.+?) \|',body):
        if gl.strip()=='🔴':
            red[f]+=1
            if r.strip(): req+=1
    if re.search(r'\| 🔴 \| `summary`',body) and re.search(r'\| 🔴 \| `effects`',body):
        nameonly+=int(n)
COS=['effects','icon_name','color','abbreviation','summary']
print(f"🔴 yuva {sum(red.values())} · zorunlu-ve-boş {req} · beş ortak alan {sum(red[c] for c in COS)}")
print("gövdesiz Tier-0 satır:",nameonly)
EOF
# 🔴 yuva 419 · zorunlu-ve-boş 0 · beş ortak alan 194
# gövdesiz Tier-0 satır: 345
```

**Neden önemli.** C8'in cümlesi "boş alan sorun değil, **sebebi yazılmamış** boş
alan sorun". Tablo olmadığı için Dalga 0 her 🔴 satırı tek tek yargılamak zorunda
kaldı — ve 419 satırın hangisinin tasarım, hangisinin eksik olduğunu ayıran tek
kayıt bu bulgunun kendisi. Sonraki kişi ya 205 grant satırını gereksiz yere
"doldurulacak iş" sanacak ya da F-builtin-01'i tasarım sanıp geçecek.

**Seçenekler.**
1. **Gerekçe yaz** — yol haritasına built-in için bir §5 karşılığı (üç bloklu
   tablo, yukarıdaki gibi); en ucuz ve C8'i gerçekten kapatan seçenek.
2. **Düzelt (Tier-0 gövdeleri)** — 345 sözlük satırına `summary` (+ `effects`);
   SRD 5.2.1 metinleri CC-BY, kopyalanabilir. Ayrı faz, gerçek içerik işi.
3. **Kapsam dışı** — built-in'i taramanın dışında bırakmak; o zaman Dalga 0'ın
   tamamı geçersiz olur (plan §5'in "neden ilk" gerekçesi bunu reddediyor).

**Karar.** — · **Tarih:** — · **Kapatan:** —

### Dalga 1 — karakter yaratma paketleri

*(henüz yok)*

### Dalga 2 — büyü paketleri

*(henüz yok)*

### Dalga 3 — sihirli eşyalar

*(henüz yok)*

### Dalga 4 — canavar paketleri

*(henüz yok)*

---

## Tarama öncesi bilinen açıklar

Bunlar **bu taramanın bulgusu değil** — yol haritası bunları zaten ölçtü ve açık
bıraktı. Buraya yazılıyorlar ki tarama sırasında yeniden "keşfedilip" bulgu
sayılmasınlar; ama tarama onlara **yeni satır eklerse** o ekleme bulgudur.

| # | Açık | Nerede yazılı | Durum |
|---|---|---|---|
| 1 | §5'te 25 satır 🔴 `M` — hiçbir fazın sahiplenmediği düzyazı işi (`class` proficiency/equipment/multiclass prose, `subclass` prose grants + `flavor_description`, `species.age`, `background.starting_gold_gp`, üç `feat` pick-count anahtarı, `spell`/`creature-action` `applied_condition_refs` + `save_dc`, `magic-item` attunement/charges/body-slot) | §5.8, "Done when" #1 | Karar bekliyor: yeni düzyazı-ayrıştırma fazı **veya** "kural zaten `description`'da render oluyor, orada kalır" kararı |
| 2 | M4 — büyü slotu tablosunun sayfaya inmesi | §6 Stage M | Yol haritasında **açık tek faz** |
| 3 | `dupe_census` B bölümü 189 ad / 193 kopya | §2.5, L4 | **Karar gereği** duruyor: 188'i statblock çocuk satırı, taşımak içerik siler |
| 4 | 85 paketli büyü hiçbir yoldan görünmüyor — **F2 dağılımı ölçtü: `deepm` 75, `kp` 7, `a5e-ag` 3** (yukarıdaki kuru çalışma) | U2 ölçümü | Açık |
| 5 | `magic-item.cost_gp` **pakette 1.063/1.063 `null`** — `0.00` olan **kaynaktaki** `MagicItem.cost` sütunu, paket onu hiç yazmıyor (F1 2026-08-17 ölçtü, checklist C5 buna göre düzeltildi) | §5.8 | ⛔ yazmak fiyat uydurmak olur |
| 6 | D1 publish — `DMT_WORKER_URL` + `ADMIN_TOKEN` CI secret'ı, upload hiç çalışmadı | §6 Stage D | Açık |

---

## F2 onayı — 2026-08-17

**Onaylandı.** Format, F0 ve F1'in kuralıyla: onay **defteri doldurarak** verildi,
okuyarak değil. Uydurma örnek gerçek bir ölçümle değiştirilince şablonun dört
kutusu tutmadı.

**Çalıştırılarak doğrulananlar.** Kuru çalışmanın kanıt komutu çalışıyor ve
**93 / 85 / {deepm 75, kp 7, a5e-ag 3}** veriyor (U2'nin 85'i birebir çıkıyor —
dağılım yeni). Paket sayaç tablosundaki 19 slug `assets/open5e_packs/` ile birebir
eşleşiyor. Checklist madde tablosundaki 31 kimlik onaylı checklist'in 31 başlığıyla
birebir. `python3 tool/check_findings.py` → temiz; `--selftest` → bozuk kayıtta 6
eksik yakalıyor; sayaçlar bir kayıt eklenip tablolar güncellenmeyince üçü birden
bağırıyor (denendi).

**Düzeltilen kusurlar.**

1. **Cause code dağarcığı defterde hiç yoktu** — şablon `M` kullanıyordu ama altı
   kodun nerede tanımlı olduğu yazmıyordu; daha kötüsü, altısı da **içerik
   kaybını** anlatıyor ve düzeltmeleri importer'a iniyor. Bu taramanın **E/F/G**
   maddeleri (sayfaya iniyor mu, sihirbaz görüyor mu, katalog doğru mu) oraya
   inmez: paket doğru, uygulama eksiktir. Onlar için hiçbir kod yoktu — tarayıcı
   ya yanlış kod yazacak ya boş bırakacaktı. Kod **`A`** eklendi.
2. **Yayılan bulgunun kuralı yoktu.** Kuru çalışmanın kendisi kanıtı: tek kusur,
   üç paket. Tarama paket paket, oturum oturum ilerlediği için ya aynı kayıt üç
   kez açılacak ya da ilk pakete yazılıp diğerleri kaybolacaktı; her iki hâlde de
   paket sayacı yalan söyler. Kural + dağılım tablosu eklendi (`pass0` bir artar).
3. **Uydurma örnek.** `F-örnek-00` icat edilmiş sayılar taşıyordu (`73/76`, örneklem
   `#12/#40/#57`) — checklist A3'ün ("uydurma değer yok") kendi defterinde ihlali,
   ve kanıtın gerçekten üretilebildiğini kanıtlamıyordu. Yerine ölçülmüş, komutu
   yeniden çalıştırılabilir bir kayıt kondu; K7 gereği bulgu **olmadığı bilinen**
   bir açık seçildi ki defter kirlenmesin.
4. **Bilinen açık #5 yanlıştı** — checklist C5'in F1'de düzeltilen hatasının
   aynısı: `cost_gp` "1.063/1.063 = `0.00`" yazıyordu; `0.00` **kaynaktaki**
   sütun, pakette alan 1.063'ünde de `null`. Atıf §5.6 → §5.8'e çekildi.
5. **İki ayrı "F1"** — checklist'in F grubu ile §6 fazları aynı harfi kullanıyor,
   bulgu kimlikleri de `F-` ile başlıyor. Yazım kuralı eklendi (`checklist F3` /
   `§6 F3`), onaylı dosya yeniden adlandırılmadı. Bir kayıt = bir madde kuralı da
   yazıldı, yoksa madde sayacı toplanamıyor.

**Değişmeyen.** Hiçbir `*.pkg.json` satırına dokunulmadı; defterde tek bir gerçek
bulgu yok — tarama F3'te başlıyor.
