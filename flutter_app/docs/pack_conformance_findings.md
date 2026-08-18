# Paket İçerik Uygunluk Taraması — Bulgular (Stage F2)

**Ölçüt:** `pack_conformance_checklist.md` · **Süreç:** `pack_conformance_plan.md`
· **Yol haritası:** `open5e_content_audit.md`

> **Durum: F3 sürüyor — Pass 0 + Dalga 0 + Dalga 1 bitti, **Dalga 2'nin ilk dört
> birimi tarandı** (`kp`, `wz`, `deepmx`, `spells-that-dont-suck` — 2026-08-18),
> 27 bulgu.** Sıradaki iş **Dalga 2'nin son birimi: `open5e-deepm`** (515 büyü);
> onunla Dalga 2 kapanır ve Dalga 3 (sihirli eşyalar) başlar.
> Format **F2'de onaylandı (2026-08-17)** — yazılarak değil, gerçek bir ölçümü
> şablona **doldurarak** (§ "Kuru çalışma").
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
| 0 | 27 | 0 | 0 | 0 | 0 | **27** |

**Checklist maddesine göre** *(bulgu geldikçe doldurulur)*

| Madde | Bulgu | Madde | Bulgu | Madde | Bulgu |
|---|--:|---|--:|---|--:|
| A1 | 0 | B1 | 0 | C1 | 1 |
| A2 | 0 | B2 | 1 | C2 | 3 |
| A3 | 10 | B3 | 1 | C3 | 0 |
| A4 | 1 | B4 | 0 | C4 | 1 |
| A5 | 1 | B5 | 0 | C5 | 0 |
| D1 | 2 | E1 | 1 | C6 | 0 |
| D2 | 0 | E2 | 0 | C7 | 0 |
| D3 | 0 | E3 | 1 | C8 | 2 |
| F1 | 0 | F3 | 0 | G1 | 0 |
| F2 | 1 | F4 | 0 | G2 | 0 |
| | | | | G3 | 1 |

**Pakete göre**

| Kapsam | Bulgu | Kapsam | Bulgu |
|---|--:|---|--:|
| `pass0` | 15 | `open5e-vom` | 0 |
| `builtin` | 2 | `open5e-ccdx` | 0 |
| `open5e-a5e-gpg` | 0 | `open5e-bfrd` | 1 |
| `open5e-a5e-ddg` | 0 | `open5e-tob2` | 0 |
| `open5e-open5e` | 1 | `open5e-tob` | 0 |
| `open5e-tdcs` | 0 | `open5e-tob3` | 0 |
| `open5e-toh` | 2 | `open5e-a5e-mm` | 0 |
| `open5e-a5e-ag` | 2 | `open5e-tob-2023` | 0 |
| `open5e-kp` | 0 | | |
| `open5e-wz` | 2 | | |
| `open5e-deepmx` | 0 | | |
| `open5e-spells-that-dont-suck` | 2 | | |
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

> Üçü de `a5e-gpg` taranırken bulundu ama kusur mapper'da, o yüzden kapsam
> `pass0` ve her birinin dağılım tablosu var (yayılan bulgu kuralı).

### F-pass0-02 — 30 background, kaynağın "şunlardan birini seç" dediği becerilerin hepsini hediye ediyor

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 5 pakete yayılı (Dalga 1 / `a5e-gpg`'de bulundu) |
| **Checklist** | checklist C2 (species/subspecies/background/feat alanları) |
| **Kategori / etki** | `background` — kaynak satırı seçim ifadesi taşıyan **30** kart (kaynakla eşleşen 52'nin %58'i); karakter sayfasına **32 fazladan yetkinlik** iniyor. Dağılım aşağıda |
| **Cause code (öneri)** | `M` — `mapBackgrounds` seçim ifadesini okumuyor, metindeki her beceri adını grant yazıyor (`mappers/chargen.dart:1406-1410`) |
| **Durum** | ❓ danışılacak |

**Bulgu.** `descOfType('skill_proficiency')` benefit satırının **tamamını**
`_refListFromText`'e veriyor; fonksiyon metinde adı geçen her beceriyi bulup
`granted_skill_refs`'e koyuyor. Kaynak ise çoğu satırda seçim yazıyor:

| Kart | Kaynak satırı | Kitabın verdiği | Kartın verdiği |
|---|---|--:|--:|
| `a5e-gpg` **Cursed** | "Perception, and either Arcana, Nature, or Religion…" | 2 | **4** |
| `a5e-ag` **Sage** | "History, and either Arcana, Culture, Engineering, or Religion." | 2 | **3** |
| `tdcs` **Lyceum Student** | "Your choice of two from among Arcana, History, and Persuasion." | 2 | **3** |

Alan **grant**, seçim değil: `proficiencies_step.dart:59-62` onu
`grantedSkillIds`'e, `character_creation_wizard_screen.dart:1064` de commit'te
beceri tablosuna yazıyor — oyuncu seçmiyor, hepsi işaretli geliyor.

**Kanıt.**
```sh
# repo kökünden — kaynağı "seç" diyen kartlara kaç alternatif hediye edildi
python3 - <<'EOF'
import json,glob,re,os,collections
src={}
for f in glob.glob('open5e-api-staging/data/v2/*/*/Background.json'):
    doc=os.path.basename(os.path.dirname(f))
    bg={r['pk']:r['fields']['name'] for r in json.load(open(f))}
    bf=os.path.join(os.path.dirname(f),'BackgroundBenefit.json')
    if not os.path.exists(bf): continue
    for r in json.load(open(bf)):
        fl=r['fields']
        if fl.get('type')=='skill_proficiency' and fl['parent'] in bg:
            src[(doc,bg[fl['parent']])]=fl['desc']
KEY=re.compile(r'either|choice of|one of your choice|of your choice',re.I)
per=collections.Counter(); extra=0
for p in sorted(glob.glob('flutter_app/assets/open5e_packs/*.pkg.json')):
    d=json.load(open(p)); doc=d['metadata']['source_doc_slug']
    for e in d['entities'].values():
        t=src.get((doc,e['name'])) if e['type']=='background' else None
        if not t or not (m:=KEY.search(t)): continue
        alts={r['name'] for r in e['attributes'].get('granted_skill_refs',[])
              if re.search(rf"\b{re.escape(r['name'])}\b",t[m.start():],re.I)}
        if len(alts)>1: per[os.path.basename(p)[:-9]]+=1; extra+=len(alts)-1
print(sum(per.values()), extra, dict(per))
EOF
# 30 32 {'open5e-a5e-ag': 20, 'open5e-a5e-ddg': 4, 'open5e-a5e-gpg': 1,
#         'open5e-tdcs': 3, 'open5e-toh': 2}
```

**Dağılım** *(2026-08-17'de ölçüldü)*

| Paket | Etkilenen kart | Fazla yetkinlik |
|---|--:|--:|
| `open5e-a5e-ag` | 20 | 21 |
| `open5e-a5e-ddg` | 4 | 4 |
| `open5e-tdcs` | 3 | 3 |
| `open5e-toh` | 2 | 2 |
| `open5e-a5e-gpg` | 1 | 2 |

**Neden önemli.** Üç kapı da bunu **yeşil** görüyor: M1 "her (paket, mekanik alan)
çifti sayfaya iniyor" diyor — iniyor, yanlış sayıda; `wizard_pack_families_test`
`a5e-gpg` için taslağı commit ediyor; `verify_packs`'in `background` kuralı boş
olduğu için D1 hiç bakmıyor (plan §4 Uyarı 2). Yani bu, taramanın "araç doluluk
görür, doğruluk görmez" cümlesinin ilk somut örneği. Yön de tek taraflı değil:
aynı fonksiyon `Haunted`'ın "Religion, and any one skill of your choice"'unda
**1** grant yazıyor (serbest seçim düşüyor) — §5.4'ün `Guildmember` notu ("Two of
your choice" → 0) bunun bilinen ucu; **eksik veren hâli yazılı, fazla veren hâli
değil.**

**Seçenekler.**
1. **Düzelt (iki taraflı)** — mapper yalnız sabit kısmı grant yazsın, alternatifler
   bir seçim alanına gitsin. Alan yok: `granted_skill_count` / seçenek listesi
   şema tarafında açılmalı (§5.4 "there is no `granted_skill_count`"). Yeni faz.
2. **Düzelt (yalnız mapper)** — seçim ifadesinden **sonrasını** hiç okuma: 30 kart
   eksik verir ama uydurma vermez (A3'ün "bilmiyorsan boş bırak" ilkesi).
   Küçük diff, tek dosya.
3. **Kapsam dışı** — o zaman §5.4'e yazılı bir ⛔ girmeli: "seçimli beceri satırı
   hepsini verir", çünkü şu an hiçbir yerde yazılı değil.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-03 — `ability_score_options` 27 satırın 27'sinde aynı altı yetenek: kaynağın zorunlu +1'i kayıp

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 3 pakete yayılı (Dalga 1 / `a5e-gpg`'de bulundu) |
| **Checklist** | checklist A5 (dolu ama tek sabit olan sütun yok — ⚠ tuzağı) |
| **Kategori / etki** | `background` — alanın dolu olduğu **27** satırın **27**'si birebir aynı altı-yetenek listesi; kaynak her birinde **bir** yeteneği zorunlu kılıyor (`a5e-ag` 21, `a5e-ddg` 4, `a5e-gpg` 2) |
| **Cause code (öneri)** | `A` — "sabit +1 X + serbest +1"in şemada evi yok; resolver kapısı mapper'ın elini bağlıyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** Kaynak: `"+1 Charisma and one other ability score."` Pakette
`ability_score_options` = altı yeteneğin tamamı. Genişletme **bilinçli** ve
gerekçesi kodda da, vault'ta da yazılı (`mappers/chargen.dart:1414-1421`,
[[mapper_chargen]]): `character_resolver`'ın `background_asi` kapısı yalnız
`ability_score_options` içindekilere izin veriyor, tek adlı liste oyuncunun
serbest +1'ini sessizce düşürürdü. Yazılı **olmayan** şey bunun içerik bedeli:
liste altı olduğu için Cursed'ı seçen oyuncu iki puanı Güç/Beceri'ye koyup
Karizma'ya hiç dokunmayabilir — kartın zorunlu kıldığı yetenek kartta artık yok.
Resolver'ın "listede olmayan yetenek" uyarısı da hiçbir zaman tetiklenmiyor.

İkinci yarısı ölçüt tarafı: **A5'in aracı bunu göremiyor.**
`audit_packs`'in `isConstant`'ı `filled[key] == total` istiyor
(`audit_packs.dart:141-145`), sütun 27/53 olduğu için satır `🟡 50%` basılıyor,
`⚠` basılmıyor. Yani "dolu olanların %100'ü aynı sabit" durumu, sütun %100 dolu
olmadıkça ⚠ tuzağına hiç yakalanmıyor.

**Kanıt.**
```sh
# repo kökünden — kaç satır dolu, kaç farklı değer var
python3 - <<'EOF'
import json,glob,collections
per=collections.Counter(); vals=set()
for p in sorted(glob.glob('flutter_app/assets/open5e_packs/*.pkg.json')):
    for e in json.load(open(p))['entities'].values():
        o=(e['attributes'] or {}).get('ability_score_options') if e['type']=='background' else None
        if not o: continue
        per[p.split('open5e-',1)[1][:-9]]+=1; vals.add(json.dumps(o))
print(sum(per.values()), 'satır ·', len(vals), 'farklı değer ·', dict(per))
EOF
# 27 satır · 1 farklı değer · {'a5e-ag': 21, 'a5e-ddg': 4, 'a5e-gpg': 2}

cd flutter_app && dart run tool/open5e_import/bin/audit_packs.dart \
    --markdown --only background | grep '`ability_score_options`'
# | 🟡 | `ability_score_options` | Grants | **yes** | 50% (27/53) |   ← ⚠ yok
```

**Dağılım** *(2026-08-17'de ölçüldü)*

| Paket | Etkilenen |
|---|--:|
| `open5e-a5e-ag` | 21 |
| `open5e-a5e-ddg` | 4 |
| `open5e-a5e-gpg` | 2 |

**Neden önemli.** Bu kayıt iki şeyi birden söylüyor: A5E'nin 27 background'ında
zorunlu yetenek bilgisi pakette **hiç yok** (düzyazıda var, alanda yok — B3'ün
tersi), ve ölçütün ⚠ dedektörü bu şekli tanımıyor. İkincisi daha pahalı: Dalga
2–4'te aynı desen (dolu satırların hepsi aynı, ama sütun %100 değil) hiçbir
pakette otomatik yakalanmayacak.

**Seçenekler.**
1. **Düzelt (uygulama tarafı)** — sabit yeteneği taşıyan bir alan (`asi_fixed_ability_ref`
   + serbest sayaç) ve resolver'da onu okuyan bir geçiş; mapper adı oraya yazar,
   `ability_score_options` gerçekten "seçenek" olur. Yeni faz, şema + resolver.
2. **Düzelt (yalnız ölçüt)** — `isConstant`'ı "dolu satırların hepsi aynı" hâline
   çevir (tek satırlık koşul), 27 satır ⚠ olarak görünür ve karar F4'e kalır.
   İçeriği düzeltmez, körlüğü kapatır.
3. **Kapsam dışı** — genişletme kalır, ama A5 için yazılı bir istisna gerekir:
   "27 A5E background'ında sabit yetenek düzyazıda kalır" (bugün yazılı değil).

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-04 — 6 background kartının gövdesi "[No description provided]" ile açılıyor

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 2 pakete yayılı (Dalga 1 / `a5e-gpg`'de bulundu) |
| **Checklist** | checklist A3 (uydurma değer yok — "bilmiyorsan boş bırak") |
| **Kategori / etki** | `background` — **6** kart (`a5e-gpg` 2 + `a5e-ddg` 4); dize gövdenin **ilk satırı**, kart açılınca ilk görünen şey |
| **Cause code (öneri)** | `S` — kaynakta açıklama yok; kaynak bunu düzyazı olarak yazıyor, mapper da olduğu gibi taşıyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** Open5e'nin `Background.json`'ı bu altı satırda `desc` alanına gerçek
metin değil `"[No description provided]"` yazmış. `_fold` onu benefit
bölümlerinin **önüne** koyduğu için kart şöyle açılıyor:

```
[No description provided]

### Ability Score Increase
+1 Charisma and one other ability score.
```

D1 temiz sayıyor (değer kaynakla birebir aynı), `verify_packs`'in `background`
kuralı da boş — yani hiçbir kapı bunu göremez, yalnız okuma görür.

**Kanıt.**
```sh
# repo kökünden
grep -c '\[No description provided\]' \
    open5e-api-staging/data/v2/en-publishing/a5e-*/Background.json
# a5e-ddg/Background.json:4   a5e-gpg/Background.json:2   a5e-ag/Background.json:0

python3 -c "
import json,glob,os
n=[(os.path.basename(p)[:-9],e['name'])
   for p in glob.glob('flutter_app/assets/open5e_packs/*.pkg.json')
   for e in json.load(open(p))['entities'].values()
   if '[No description provided]' in json.dumps(e)]
print(len(n),n)"
# 6 [('open5e-a5e-ddg','Deep Hunter'), ('open5e-a5e-ddg','Dungeon Robber'),
#    ('open5e-a5e-ddg','Escapee from Below'), ('open5e-a5e-ddg','Imposter'),
#    ('open5e-a5e-gpg','Cursed'), ('open5e-a5e-gpg','Haunted')]
```

**Dağılım** *(2026-08-17'de ölçüldü)*

| Paket | Etkilenen |
|---|--:|
| `open5e-a5e-ddg` | 4 |
| `open5e-a5e-gpg` | 2 |

**Neden önemli.** A3'ün ilkesi "boş alan görünür, uydurma değer doğru sanılır".
Burada kaynak "bilmiyorum" diyor ve o cümle kullanıcıya **içerik olarak**
gösteriliyor — boş bırakmaktan kötü, çünkü kart eksik değil **bozuk** görünüyor.
Altısı da Dalga 1'in ilk iki paketinde, yani `a5e-ddg` taranırken aynı şey
yeniden keşfedilmesin diye buraya yazıldı. Ayrıca `a5e-ag`'nin
`SpellSchool.json`'unda da aynı dize var (pakete inmiyor), yani bu Open5e'nin
genel bir doldurma alışkanlığı — Dalga 2–4'te başka kategorilerde çıkabilir.

**Seçenekler.**
1. **Düzelt** — mapper bilinen placeholder'ı düşürsün (`_fold`'da tek koşul);
   6 kart benefit bölümleriyle açılır, hiçbir şey kaybolmaz. En ucuz.
2. **Gerekçe yaz** — kaynak böyle, ⛔ olarak §5.4'e işlenir; kullanıcı görmeye
   devam eder.
3. **Kapsam dışı** — 53 background'ta 6; karar yazılı bırakılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-05 — `granted_language_count`: "Any six" 0 olarak, "Two … one of which" 1 olarak yazılmış

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 2 pakete yayılı (Dalga 1 / `a5e-ddg`'de bulundu) |
| **Checklist** | checklist D1 (değer kaynakla aynı) |
| **Kategori / etki** | `background` — 31 dolu satırın **2'si yanlış**: `a5e-ddg` Dungeon Robber 6 → **0**, `a5e-gpg` Haunted 2 → **1** |
| **Cause code (öneri)** | `M` — sayı sözcüğü tablosu `five`'da bitiyor ve **ilk eşleşen kazanıyor**; `\bno\b` "no longer spoken" içinde eşleşiyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** `_parseLanguageCount` (`mappers/chargen.dart:1329-1334`) önce
`_numberWord`'e soruyor, o da `_numberWords` sözlüğünü **sırayla** geziyor:

```dart
const _numberWords = {
  'no': 0, 'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
};
```

İki şekilde yanlış cevap veriyor:

- **Dungeon Robber** — kaynak: `"Any six (three of them no longer spoken)."`
  `six` tabloda **yok**; `no` ise `"no longer"` içinde `\bno\b` olarak eşleşiyor
  ve sözlüğün **ilk** girdisi olduğu için kazanıyor → **0**. Altı dil hakkı
  "hiç dil yok"a dönüyor.
- **Haunted** (`a5e-gpg`, geçen birimde kaçtı) — kaynak: `"Two of your choice,
  one of which is the spirit's native language."` Metinde hem `two` hem `one`
  var; `one` sözlükte önce geldiği için → **1**.

Doğru yazılan 29 satırın hepsi tek sayı sözcüğü taşıyor (`One of your choice`,
`Two of your choice`, `No additional languages`) — yani tablo yalnızca **cümle
karmaşıklaştığında** yanılıyor.

Alanın şemadaki tanımı `max: 5` (`builtin/content.dart:759`), yani "six" bu
alanda **temsil edilemiyor** bile; mapper'ın tavanı şemanın tavanı. Kusur
tavanın kendisi değil, tavanın üstündeki bir değerin **sessizce 0'a** düşmesi.

**Kanıt.**
```sh
# repo kökünden — 33 kaynak satırının hepsi + mapper'ın vereceği cevap
python3 - <<'EOF'
import json,glob,re
nw={'no':0,'zero':0,'one':1,'two':2,'three':3,'four':4,'five':5}
for f in glob.glob('open5e-api-staging/data/v2/*/*/BackgroundBenefit.json'):
    for r in json.load(open(f)):
        fl=r['fields']
        if fl['type']!='language': continue
        t=' '.join(fl['desc'].split()); hit=None
        for k,v in nw.items():
            if re.search(r'\b%s\b'%k,t,re.I): hit=v; break
        print(f.split('/')[-2], hit, '|', t[:70])
EOF
# … a5e-ddg 0 | Any six (three of them no longer spoken).
# … a5e-gpg 1 | Two of your choice, one of which is the spirit's native language.
# 33 satır, 31'i pakete iniyor, 29'u doğru
```

**Dağılım** *(2026-08-17'de ölçüldü)*

| Paket | Dolu satır | Yanlış |
|---|--:|--:|
| `open5e-toh` | 16 | 0 |
| `open5e-a5e-ag` | 5 | 0 |
| `open5e-tdcs` | 3 | 0 |
| `open5e-a5e-gpg` | 2 | **1** |
| `open5e-a5e-ddg` | 1 | **1** |
| `open5e-open5e` | 1 | 0 |

**Neden önemli.** İki ayrı şey aynı yere bakıyor:

1. `granted_language_count`'u **hiçbir resolver okumuyor** (`lib/` içinde tek
   geçtiği yer şema beyanı) — B7'nin yazılı "bilerek inert" kararı. Yani bugün
   mekanik zarar yok, ama alan **kartta render ediliyor**: Dungeon Robber'ı açan
   oyuncu "Granted Language Count: 0" okuyor, kaynak altı dil verirken.
2. `audit_packs` bu sütunu `a5e-ddg`'de **🟡 25% (1/4)** diye gösteriyor — ve o
   *tek dolu hücre* yanlış olan hücre. Doluluk ölçen bir araç için bu kusursuz
   bir kör nokta: üç boş hücre doğru (kaynakta `language` satırı yok), dolu olan
   tek hücre yanlış.

`verify_packs`'in `background` kuralı boş olduğu için D1 bunu da göremiyor
(§4 Uyarı 2) — F-pass0-04 ile aynı kapı, farklı alan.

**Seçenekler.**
1. **Düzelt (küçük)** — `_numberWords`'ü 10'a kadar uzat, `\bno\b` yerine
   `"no additional"`/`"none"` gibi bağlamlı kalıp kullan, ve birden fazla sayı
   sözcüğü eşleşirse **ilkini metin sırasına göre** seç. Üç satırlık değişiklik;
   `max: 5` şema sınırı ayrıca kararı bekler (6 → 5'e kırpmak mı, alanı 10'a
   çıkarmak mı).
2. **Alanı sil** — inert bir alanın yanlış değeri, kartta yanlış bilgi demek;
   B7'nin "bilerek inert" kararı alanı **gizlemiyor**. Render'dan çıkarmak da
   bir çözüm.
3. **Kapsam dışı** — 31 satırda 2, alan inert; karar yazılı bırakılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-06 — background başlangıç ekipmanında adı yazılı olan eşya envantere girmiyor: 23 "pouch"un 17'si, 20 "common clothes"un 20'si

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 6 pakete yayılı (Dalga 1 / `a5e-ddg`'de bulundu) |
| **Checklist** | checklist B3 (düzyazıda duran şey ref olmalı) |
| **Kategori / etki** | `background` — **42** kartta **120** eşya sözcüğü yalnız `label` düzyazısında kalıyor, `items` satırı olmuyor; ölçülen en büyük üç kalıp: `pouch` 23 anımsatmanın **6'sında** ref var, `ball bearings` 2/**0**, `prayer book` 2/**0**, `common clothes` 20/**0** |
| **Cause code (öneri)** | `M` — `builtinItem` yalnız üç bağışlayıcı kural tanıyor (çoğul, son ` of ` kuyruğu, ölçü sözcüğü); **öndeki niteleyici** ("belt pouch", "prayer book") ve **parantez içi liste** hiç denenmiyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** `_gearRef`'in yazılı sözleşmesi (`mappers/chargen.dart:1099-1113`)
şöyle: pakette olan → hard `ref`, built-in katalogda olan → `softRef`, ikisi de
değilse **satır yok**, ve düşenler "background flavour — 'pet monkey wearing a
tiny fez', 'memento of your destiny'". Ölçüm bu gerekçenin **yarısını**
doğruluyor: 120 düşen sözcüğün çoğu gerçekten uydurulamaz flavour, ama içinde
**katalogda birebir duran eşyalar** da var:

| Kaynak düzyazısı | Katalogdaki kart | Neden düşüyor |
|---|---|---|
| `belt pouch containing 10 gp` | `Pouch` | öndeki `belt` niteleyicisi bağışlanmıyor (`pouch` bilerek `_measureWords`'te değil — yazar kartı biliyor) |
| `bag of 1,000 ball bearings` | `Ball Bearings` | `of` kuyruğu `1000 ball bearings`, ölçü sözcüğü `bag` listede yok |
| `prayer book` | `Book` | öndeki `prayer` |
| `(amulet or reliquary)` | `Amulet (Holy Symbol)` | parantez içi **baştan siliniyor** (`_kitItems:1209`) |
| `Common clothes` | **yok** | SRD 5.2.1 kataloğunda yalnız `Clothes, Fine` + `Clothes, Traveler's` var — 2024 listesi "common clothes"u düşürdü → bu satırın cause code'u `N`, `M` değil |

Parantez kuralı ayrı bir mekanizma ve ölçülebilir: 11 parantezin **6'sının**
içinde verilmeyen bir katalog eşyası var — `tdcs` Elemental Warden'ın
`(a shortbow with 20 arrows, or a hunting trap)`'i (Shortbow + Arrows + Hunting
Trap), `a5e-ag` Acolyte/Cultist'in `(amulet or reliquary)`'si, `a5e-ag` Farmer'ın
`(rations)`'ı. Kodun yorumu parantez silmeyi tam bu `(amulet or reliquary)`
örneğiyle gerekçelendiriyor — "virgülde parçalanmasın" diye; sonuç, parçalanmak
yerine **tamamen kaybolması**.

Ölçümün en okunaklı kanıtı **aynı dosyanın içindeki asimetri**:
`parseToolProficiencies` noktalama-duyarsız eşleştirme yapıyor ve gerekçesi
yazılı — "upstream `Cartographers’ tools` yazıyor, katalog `Cartographer's
Tools`". Ekipman yolu aynı upstream alışkanlığına karşı **çıplak**: `a5e-ddg`
Dungeon Robber'ın `Cartographers’ tools`'u alet yetkinliği olarak doğru
eşleşiyor (`granted_tool_refs` dolu), ama başlangıç ekipmanı olarak düşüyor.
Aynı sözcük, aynı kart, iki farklı eşleştirici, iki farklı sonuç.

**Kanıt.**
```sh
# flutter_app'ten — label'de adı geçip items'a girmeyen kalıplar
python3 - <<'EOF'
import json,glob
pat=[('pouch','Pouch'),('rope','Rope'),('ball bearings','Ball Bearings'),
     ('prayer book','Book'),('common clothes','Clothes')]
res={k:[0,0] for k,_ in pat}
for f in glob.glob('assets/open5e_packs/*.pkg.json'):
    for e in json.load(open(f))['entities'].values():
        if e['type']!='background': continue
        for g in e['attributes'].get('equipment_choice_groups',[]) or []:
            for o in g['options']:
                lab=o['label'].lower().replace('’',"'")
                items=[i['ref']['name'].lower() for i in o.get('items',[])]
                for k,want in pat:
                    if k in lab:
                        res[k][0]+=1
                        if any(want.lower() in n for n in items): res[k][1]+=1
print(res)
EOF
# {'pouch': [23, 6], 'rope': [3, 2], 'ball bearings': [2, 0],
#  'prayer book': [2, 0], 'common clothes': [20, 0]}
```

**Dağılım** *(2026-08-17'de ölçüldü — düşen sözcük sayısı)*

| Paket | Düşen sözcük |
|---|--:|
| `open5e-toh` | 68 |
| `open5e-a5e-ag` | 33 |
| `open5e-tdcs` | 9 |
| `open5e-open5e` | 6 |
| `open5e-a5e-ddg` | 3 |
| `open5e-a5e-gpg` | 1 |

*(120 sözcüğün tamamı kusur değildir — flavour olanlar B6'nın yazılı kararıyla
zaten düşmeli. Kusur, bu kümenin içinde **katalogda karşılığı olan** eşyaların
bulunması ve gerekçenin bunu kapsamadığını sanması.)*

**Neden önemli.** Bu alan sihirbazda **verilen** ekipman: oyuncu kartı seçince
`items` envantere düşüyor, `label` yalnız okunuyor. Yani "adı yazılı ama satırı
yok" demek, oyuncunun kaynağa göre hakkı olan kesenin / bilyelerin / kutsal
sembolün **envanterine hiç girmemesi** ve bunu ancak düzyazıyı okuyup fark
etmesi. Hiçbir kapı göremiyor: `gate_packs` green (softRef gate'lemiyor,
üstelik burada ref **hiç yazılmamış**), `audit_packs`
`equipment_choice_groups` sütununu **100% dolu** görüyor (grup var, içi eksik),
`verify_packs`'in `background` kuralı boş. F-pass0-02 ile aynı aile: **dolu alan,
eksik içerik.**

**Seçenekler.**
1. **Düzelt (iki küçük kural)** — (a) parantez içini silmek yerine ayrı bir
   segment olarak tokenize et; (b) `builtinItem`'a "son sözcükten geriye doğru
   katalog araması" ekle (`belt pouch` → `pouch`), yalnız gerçek bir kart adına
   **oturursa** kabul. İkisi de "yanlış kart verme" ilkesini bozmadan yapılabilir.
2. **`common clothes` için karşılık kararı** — 20 anımsatma tek bir eksik karta
   bakıyor: ya built-in kataloğa `Clothes, Common` eklenir (SRD 5.2.1 dışı içerik
   demek), ya `Clothes, Traveler's`'a eşlenir (yaklaşık), ya `N` olarak §5.4'e
   yazılır.
3. **Kapsam dışı** — B6'nın gerekçesi genişletilip "katalogda olanlar da düşebilir,
   çünkü eşleme mekanik" diye yazılır; `label` düzyazısı kullanıcıya görünmeye
   devam ettiği için bilgi kaybı değil, **otomasyon** kaybı sayılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-07 — 19 paket kartının adı built-in bir kartın adından yalnız boşluk/noktalama kadar farklı: dedup anahtarı da ref çözümü de göremiyor

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 9 pakete yayılı (Dalga 1 / `open5e-open5e`'de bulundu) |
| **Checklist** | checklist A4 (ad ve yazım kuralı) |
| **Kategori / etki** | 19 kart — `trait` 11, `monster` 3, `creature-action` 3, `spell` 2. Ad, harf dışı her karakter atılınca bir built-in kartla **birebir** aynı, literal olarak **farklı**: `Eye bite`→`Eyebite`, `Meld Into Stone`→`Meld into Stone`, `Counter Spell`→`Counterspell`, `Battle Axe`→`Battleaxe`, `War Horse Skeleton`→`Warhorse Skeleton`, `Devil’s Sight`→`Devil's Sight` (kıvrık kesme işareti, 3 pakette) |
| **Cause code (öneri)** | `S` — 19'unun 19'u upstream'de de böyle yazılı; `titleCaseName` (L3) yalnız **büyük/küçük harfi** düzeltir, sözcük bölmesini ve kesme işaretini değil |
| **Durum** | ❓ danışılacak |

**Bulgu.** `dupe_census`'un A bölümü `(slug, lowercased name)` anahtarıyla
çalışıyor ve "case-only" kovasında **3** satır bildiriyor. Anahtarı bir adım
gevşetince — harf dışı her karakteri de düşürünce — sayı **19**'a çıkıyor. Yani
korpüste, built-in'in zaten getirdiği bir kartın **yazım varyantı** olan 16 kart
daha var ve hiçbir kapı onları görmüyor:

- **B1 göremiyor** — eşleme anahtarı `(kategori, ad)`; `Eye bite` ile `Eyebite`
  iki ayrı ad, dolayısıyla "aynı kart" sayılmıyor. Kullanıcı listede iki kart
  görüyor.
- **A4 göremiyor** — bugüne dek A4 "ref hedefi çözülüyor mu" diye ölçüldü
  (`gate_packs`, census C: **0 dangling**). Bu 19 kartın hiçbiri bir ref
  *hedefi* değil, ref *kaynağı* da değil — kimse onlara ad ile bağlanmıyor, o
  yüzden hiçbir kapı kırmızıya dönmüyor.
- **`findEntityIdByName` göremiyor** — büyük/küçük harfe duyarlı, tek denemesi
  sondaki parantezi atmak. `Eyebite` diye arayan bir soft ref `Eye bite`'a
  **hiçbir zaman** inmez; tersi de geçerli.

Bulunduğu yer `open5e-open5e`: pakette **Eye bite** (2014 metni, level 6,
Necromancy, Self, 1 dakika, Bard/Sorcerer/Warlock/Wizard, Wisdom kurtarma)
duruyor; built-in'de **Eyebite** (SRD 5.2.1 metni, aynı altı özellik) duruyor.
İkisi aynı büyü, iki kart, ve kaynak `Spell.json`'da adı gerçekten
`"Eye bite"`.

**Kanıt.**
```sh
# flutter_app'ten — built-in adları srd_core'dan, paket adları asset'lerden;
# anahtar: harf-dışı her şey atılmış küçük harf
python3 - <<'EOF'
import json,glob,re,collections
names=set()
for f in glob.glob('lib/domain/entities/schema/builtin/srd_core/*.dart'):
    for m in re.finditer(r"name:\s*'((?:[^'\\]|\\.)*)'", open(f).read()):
        names.add(m.group(1).replace("\\'","'"))
key=lambda s: re.sub(r'[^a-z0-9]','',s.lower())
bykey=collections.defaultdict(set)
for n in names: bykey[key(n)].add(n)
hits=[]
for f in sorted(glob.glob('assets/open5e_packs/*.pkg.json')):
    pk=f.split('/')[-1][:-9]
    for e in json.load(open(f))['entities'].values():
        if e['name'] in names: continue
        if key(e['name']) in bykey:
            hits.append((pk,e['type'],e['name'],sorted(bykey[key(e['name'])])[0]))
print(len(hits)); [print(' ',*h) for h in hits]
EOF
# 19 — a5e-mm 5, ccdx 4, bfrd 3, tob 2, a5e-ag 1, open5e 1, tob-2023 1, tob2 1, tob3 1
```

**Dağılım** *(2026-08-17'de ölçüldü)*

| Paket | Varyant ad |
|---|--:|
| `open5e-a5e-mm` | 5 |
| `open5e-ccdx` | 4 |
| `open5e-bfrd` | 3 |
| `open5e-tob` | 2 |
| `open5e-a5e-ag` | 1 |
| `open5e-open5e` | 1 |
| `open5e-tob-2023` | 1 |
| `open5e-tob2` | 1 |
| `open5e-tob3` | 1 |

**Neden önemli.** 19'un 14'ü statblock çocuk satırı (`trait` /
`creature-action`) — orada zarar küçük, çünkü satır zaten sahibine bağlı. Geri
kalan 5'i **kendi başına duran kart**: 2 büyü (`Eye bite`, `Meld Into Stone`),
3 canavar (`Will-o-Wisp`, `Cultist, Fanatic`, `War Horse Skeleton`). Onlarda
iki ayrı sonuç doğuyor: (1) kullanıcı built-in kartın
neredeyse aynısını ikinci kez görüyor ve hangisinin "gerçek" olduğunu bilmiyor;
(2) ileride bu kartlara ad ile bağlanacak her `*_ref` — B3'ün doldurmayı
planladığı alanlar dahil — kanonik yazımı kullanırsa paket kartını **hiç**
bulamayacak. Bugün ölçülen zarar 0 dangling'dir; bu bulgu, o 0'ın
**anahtarın darlığından** geldiğini söylüyor.

**Seçenekler.**
1. **Alias tablosu** — `normalize.dart`'a ölçülmüş 19 satırlık bir kanonikleştirme
   listesi (`Herbalist kit → Herbalism Kit` zaten böyle duruyor, §5.4). Küçük,
   denetlenebilir, ama listeyi elle beslemek gerekir.
2. **Anahtarı gevşet** — `dupe_census` A ve `findEntityIdByName` harf-dışı
   karakterleri normalize eden ikinci bir deneme yapsın. Tek yerde çözer, ama
   `findEntityIdByName` bilerek katı (§2.3) — gevşetmek yanlış eşleşme riski.
3. **Kapsam dışı** — upstream yazımı korunur (`S`), 8 tekil kartın kopya
   görünmesi kabul edilir; kayıt burada durur.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-open5e-01 — 5e-2024 belgesinden gelen 1 subclass, `game_system: 5e-2014` etiketli paketin içinde eriyor

| | |
|---|---|
| **Kapsam** | `open5e-open5e` |
| **Checklist** | checklist G3 (`game_system` etiketi kartın hangi kurala göre yazıldığını taşır) |
| **Kategori / etki** | `subclass` — 17'nin **1'i** (`Abjurationist`) `open5e-2024` belgesinden geliyor (`gamesystem: 5e-2024`), paket ve katalog girdisi ise **`5e-2014`** diyor. Kartın üzerinde 2024 olduğunu söyleyen hiçbir alan yok: `source` = `"Open5e Originals"`, diğer 16'sıyla aynı |
| **Cause code (öneri)** | `M` — `mergeOpen5eOriginals` (`tool/open5e_import/emit.dart:71-102`) ikinci belgenin **varlıklarını** alıyor, **metadata'sını** almıyor; birincil `doc` ile yeniden `assemblePack` çağrılıyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** Open5e kendi homebrew'unu iki belge olarak yayınlıyor: `open5e`
(`gamesystem: 5e-2014`, 16 subclass) ve `open5e-2024` (`gamesystem: 5e-2024`,
1 subclass). `mergeOpen5eOriginals` ikisini tek pakette birleştiriyor — bu
**yazılı ve gerekçeli** bir karar (yorum: "we present them as a single 'Open5e
Originals' package"). Birleşmenin götürdüğü şey belgenin oyun sistemi:
`assemblePack` metadata'yı `doc`'tan yazdığı için sonuç `game_system: 5e-2014`,
`source_doc_slug: open5e` oluyor ve 17. kart bu etiketin altında görünmez hâle
geliyor.

İki ölçülebilir izi var:

- **`verify_packs --doc open5e` 17 subclass'ın 16'sını eşleştiriyor**,
  `Abjurationist` "unmatched" düşüyor — çünkü kaynağı `--doc open5e`'nin
  altında değil. D1 kapısı o kart için **hiç çalışmıyor**, ve çıktı bunu
  "bir kart kaynakta yok" gibi gösteriyor.
- **Aynı okulun iki sürümü yan yana duruyor.** `School of Abjuring and Warding`
  (2014, `granted_at_level: 2`) ve `Abjurationist` (2024,
  `granted_at_level: 3`) aynı wizard abjuration nişini dolduruyor; ikisi de
  aynı `parent_class_ref` (Wizard) ile listeleniyor, ikisi de aynı "Open5e
  Originals" damgasını taşıyor. Seviye farkı sihirbazda **görünür**: biri 2.
  seviyede seçilebilir, diğeri 3.
- `granted_at_level` **doğru** (her ikisi de kendi belgesinin ilk özellik
  seviyesinden okunuyor) — yani bu bir mapper hatası değil, iki kural setinin
  aynı pakette etiketsiz durması.

**Kanıt.**
```sh
# repo kökünden
python3 -c "
import json
for d in ('open5e','open5e-2024'):
    j=json.load(open(f'open5e-api-staging/data/v2/open5e/{d}/Document.json'))
    print(d, j[0]['fields']['gamesystem'], len(json.load(open(f'open5e-api-staging/data/v2/open5e/{d}/CharacterClass.json'))))
p=json.load(open('flutter_app/assets/open5e_packs/open5e-open5e.pkg.json'))
print('pack game_system =', p['metadata']['game_system'], '| source_doc_slug =', p['metadata']['source_doc_slug'])
print([ (e['name'], e['attributes']['granted_at_level']) for e in p['entities'].values()
        if e['name'] in ('Abjurationist','School of Abjuring and Warding') ])
"
# open5e 5e-2014 16
# open5e-2024 5e-2024 1
# pack game_system = 5e-2014 | source_doc_slug = open5e
# [('Abjurationist', 3), ('School of Abjuring and Warding', 2)]

cd flutter_app && dart run tool/open5e_import/bin/verify_packs.dart \
    --data ../open5e-api-staging/data --doc open5e --only subclass,spell
# open5e-open5e  subclass  16/17  1 unmatched — e.g. Abjurationist
```

**Neden önemli.** G3'ün yazılı gerekçesi tam olarak bu: etiket, kartın hangi
kurala göre yazıldığını taşır. Bugün etiket yalnız katalog kartında bir çip
olarak görünüyor (`official_packages_catalog_view.dart:113`) — mekanik etkisi
yok — ama 2014 masası kuran bir DM "5e-2014" yazan paketi kurup içinde 2024
kuralıyla yazılmış bir subclass buluyor, üstelik onun 2014 karşılığıyla yan
yana. Filtreleme bir gün `game_system`'a bakarsa, bu kart yanlış tarafta
kalacak.

**Seçenekler.**
1. **Varlığa etiket** — birleşmede ikinci belgenin kartlarına `source`'u
   belgeden yazdır (`"Open5e Originals (2024)"`) ya da `tags`'e `5e-2024` ekle.
   En küçük değişiklik, kayıp yok, kullanıcı ayrımı görüyor.
2. **Birleştirmeyi geri al** — iki paket olarak ship et (`open5e-open5e` +
   `open5e-open5e-2024`), her biri kendi `game_system`'ıyla. Katalogda iki satır,
   ama etiketler dürüst; `verify_packs` de her iki belgeyi ölçer.
3. **Kapsam dışı** — birleşme kararı yazılı, etiket bugün yalnız gösterimlik;
   `metadata`'ya `"contains: [5e-2014, 5e-2024]"` gibi bir not düşülüp bırakılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-10 — üçte-bir büyücü 4 subclass hiç büyü slotu almıyor: `CasterKind.third` korpüste hiçbir kartla ulaşılamıyor

> **Eski kimlik `F-open5e-02`.** Dalga 1 / `toh` taramasında (2026-08-17) aynı
> kusurun üçüncü kartı **başka bir pakette** ölçüldü, yayılan bulgu kuralı
> gereği kapsam `pass0`'a çıktı ve kimlik ona göre yenilendi. Diğer belgelerdeki
> `F-open5e-02` atıfları bu kaydı gösterir.

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 2 pakete yayılı (ilk `open5e-open5e`'de bulundu) |
| **Checklist** | checklist E3 (büyücülük ilerlemesi) |
| **Kategori / etki** | `subclass` — **4 kart** (`Arcane Warrior` / Fighter, `Eldritch Trickster` / Rogue, `Soulspy` / Rogue, `Underfoot` / Rogue) kendi büyü ilerlemesini veriyor; karakter sayfasında **0 slot, 0 cantrip, büyü adımı yok**. Korpüste `caster_kind: 'Third'` taşıyan **0** kart var (built-in 12 sınıf + paketli 2 sınıf ölçüldü) |
| **Cause code (öneri)** | `A` — `level_up_planner.dart:473` `caster_kind`'ı **yalnız `classEntity`'den** okuyor; `subclass` şemasında böyle bir alan hiç **yok** (8 beyan edilmiş alan) |
| **Durum** | ❓ danışılacak |

**Bulgu.** Checklist E3'ün kendi örneği bu maddeyi "paketli bir büyücü çıkarsa
yeniden dosyalanır" diye bırakmıştı; ölçüm o koşulu karşılıyor — ama beklenen
yerde değil. Paketli iki `class` kartının ikisi de `caster_kind: 'None'`
(T2-2 bunu ölçmüştü ve doğru). Çıkan büyücü **subclass** tarafında:

- `Arcane Warrior` (Fighter) ve `Eldritch Trickster` (Rogue) — SRD'nin Eldritch
  Knight / Arcane Trickster kalıbı, yani **üçte-bir büyücü**. Özellik metni
  açık: *"Beginning at 3rd level, you can cast spells from the wizard spell
  list"*, ardından `Cantrips` / `Spell Slots` / `Spells Known` alt başlıkları.
- Slot sayıları **kaynakta yok**: prose "as shown on the Arcane Warrior Spells
  table" diyor, ama `ClassFeatureItem.json`'da bu iki subclass için
  `column_value` taşıyan **tek satır bile** yok. Yani B1'in bilerek atladığı
  sınıf-tablosu satırları burada zaten mevcut değil (`S`).
- **`toh`'ta iki kart daha (2026-08-17 eklendi).** `Underfoot` (Rogue, erina'ya
  kısıtlı) `Spell Slots` · `Spells Known of 1st-Level and Higher` · `Cantrips`
  satırlarıyla **kendi druid ilerlemesini**, `Soulspy` (Rogue) ise 3. seviyede
  **cleric ilerlemesini** taşıyor; ikisinin de slot tablosu feature gövdesinde
  markdown tablosu olarak duruyor (F-pass0-08'in kardeşi, ama orada büyü listesi,
  burada slot sütunları). İlk ölçümün komutu ikisini de kaçırmıştı: tarama
  `features` satırının **adında** "spellcasting" arıyordu, Underfoot'un slot
  satırının adı `Spell Slots`, Soulspy'ınki ise gövdede. Kaydın "`toh`'un hepsi
  büyücü sınıf üstünde" notu bu yüzden **yanlıştı**; komut aşağıda düzeltildi ve
  artık ada değil gövdeye bakıyor.
- Uygulama tarafında tablo **hazır duruyor**: `CasterKind.third` tanımlı,
  `defaultSpellSlotsByLevel` üçte-bir ilerlemesini hesaplıyor, `spells_step`
  "Third caster" etiketini basıyor. Hiçbir içerik bu dalı **seçtiremiyor**,
  çünkü tek okuma noktası sınıf kartının `caster_kind`'ı.

Built-in SRD 5.2.1 bunu hiç zorlamadı: 2024 SRD'nin Fighter'ı Champion,
Rogue'u Thief getiriyor — ikisi de büyücü değil. Yani `CasterKind.third`
bugüne kadar **ölü kod**du ve bunu ilk gösteren şey bu paket.

**Kanıt.**
```sh
# flutter_app'ten — büyücü OLMAYAN sınıfın altında kendi ilerlemesini taşıyan subclass'lar
# (2026-08-17: satır adına değil, satır gövdesine bakılıyor — ilk komut Underfoot'u kaçırdı)
python3 - <<'EOF'
import json,glob,re
NONCASTER={'Fighter','Rogue','Barbarian','Monk'}
PAT=re.compile(r'spell slots you have to cast|cast spells from the wizard spell list|Spells Known\s*\|',re.I)
for f in sorted(glob.glob('assets/open5e_packs/*.pkg.json')):
    d=json.load(open(f)); names={k:v['name'] for k,v in d['entities'].items()}
    for e in d['entities'].values():
        if e['type']!='subclass': continue
        p=e['attributes'].get('parent_class_ref')
        pc=p.get('name') if isinstance(p,dict) else names.get(p)
        if pc not in NONCASTER: continue
        hit=[r.get('name') for r in (e['attributes'].get('features') or [])
             if PAT.search(r.get('description') or '')]
        if hit: print(f.split('/')[-1][:-9],'|',pc,'|',e['name'],'|',hit[0])
EOF
# open5e-open5e | Fighter | Arcane Warrior     | Spellcasting
# open5e-open5e | Rogue   | Eldritch Trickster | Spellcasting
# open5e-toh    | Rogue   | Soulspy            | Spellcasting   <- 2026-08-17
# open5e-toh    | Rogue   | Underfoot          | Spell Slots    <- 2026-08-17

grep -rn "caster_kind" lib/application/character_creation/level_up_planner.dart
#   473:  final kind = parseCasterKind(classEntity?.fields['caster_kind']);
grep -c "'caster_kind': 'Third'" lib/domain/entities/schema/builtin/srd_core/classes.dart   # 0
```

**Dağılım.**

| Paket | Kart | Ana sınıf | Aldığı liste |
|---|---|---|---|
| `open5e-open5e` | Arcane Warrior | Fighter | wizard |
| `open5e-open5e` | Eldritch Trickster | Rogue | wizard |
| `open5e-toh` | Soulspy | Rogue | cleric |
| `open5e-toh` | Underfoot | Rogue | druid |
| **Toplam** | **4** | 2 paket | — |

**Neden önemli.** Bu, "alan boş" değil "alan yok" kusuru — C8 bile göremez,
çünkü C8 **beyan edilmiş** alanların boşluğunu sorar. Oyuncu Arcane Warrior
seçtiğinde kart doğru okunuyor (özellik metni sayfada), ama sihirbazın büyü
adımı hiç açılmıyor: 3. seviyede iki cantrip ve üç 1. seviye büyü hakkı olan
karakterin **hiçbir yerde** slotu yok. M4 slot tablosunu sayfaya indirdi;
o tablo bu dört subclass için sonsuza kadar boş kalır.

**Seçenekler.**
1. **`caster_kind`'ı subclass şemasına ekle** (+ `level_up_planner`'da
   `subclassEntity?.fields['caster_kind'] ?? classEntity…` sırası). Alan zaten
   var olan enum'u kullanır, `CasterKind.third` ilk kez ulaşılabilir olur;
   mapper tarafı ayrı bir iş (prose'dan "you can cast spells" çıkarımı, 4 kart).
   `toh`'un iki kartında slot sütunları **feature gövdesindeki tabloda** yazılı,
   yani orada sayı da ayrıştırılabilir — `open5e`'nin ikisinde değil.
2. **Yalnız uygulama tarafı** — subclass özelliklerinde `Spellcasting` başlığı
   varsa üçte-bir kabul et. Kod değişikliği küçük, ama sezgisel: `toh`'un
   5 "Potent Spellcasting" satırını (hepsi zaten büyücü sınıf üstünde) yanlış
   sınıflandırmamak için ana sınıfın `caster_kind`'ına da bakmak gerekir —
   bu kaydın kanıt komutunun ilk sürümü tam bu yüzden 2 kart kaçırdı.
3. **Kapsam dışı** — 4 kart, ve `open5e`'nin ikisinde slot sayıları kaynakta yok;
   karar "prose olarak
   kalır" diye yazılır, `CasterKind.third`'ün ölü kod olduğu da kayda geçer.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-08 — 24 subclass büyü listesi yalnız düzyazı tablosu: `features` satırının büyü anahtarı yok, B5'in yazılı kuralı da bunlara yetişmiyor

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 3 pakete yayılı (Dalga 1 / `tdcs`'te bulundu) |
| **Checklist** | checklist E1 (mekanik sayfaya iniyor) |
| **Kategori / etki** | `subclass` — 101 subclass'ın **523** `features` satırından **0'ı** hiçbir grant anahtarı taşımıyor; bunların **24'ü** düzyazının içine gömülü **büyü listesi tablosu** (domain / circle / expanded spells): `toh` 15, `open5e` 8, `tdcs` 1 |
| **Cause code (öneri)** | `M` — `classFeatures` satır şemasında büyü anahtarı **hiç yok** (`granted_feat_refs` var, `always_prepared_spell_refs` yok); mapper tabloyu `description` metnine bırakıyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** Built-in SRD'de bir subclass'ın büyü listesi, `always_prepared_spell_refs`
taşıyan bir **feat kartına** yazılıyor (`srd_core/feats_class.dart:945, 980, 1039…`)
ve `features` satırı o karta `granted_feat_refs` ile bağlanıyor. Open5e paketlerinde
o zincirin **hiçbir halkası** yok: `features` satırları yalnız `{level, name,
description}` taşıyor, ve domain/circle büyü listesi feature'ın `description`'ı
içinde markdown boru tablosu olarak duruyor:

```
Blood Domain Spells (table)
Cleric Level | Spells                                |
 |--------------|-------------------------------------------|
 | 1st          | *sleep*, *ray of sickness*                |
```

Bu, F-open5e-02 ile **aynı sınıftan** bir açık ama farklı yeri: orada mekaniğin
alanı vardı (`caster_kind`) ve yanlış kategoriden okunuyordu; burada satırda
**alan yok**. Doluluk tablosu ikisini de göremez — C8 yalnız *beyan edilmiş*
alanları sorar.

**Yol haritasının B5 notu bunu kapatmıyor.** §5'te (`open5e_content_audit.md:2224`)
`granted_feat_refs`'in boş olduğu yazılı ve "left to B5" deniyor; B5'in yazılı
kuralı ise `granted_feat_refs` için **"softRef the built-in feat, never mint one"**
(§5, satır 2343). Blood Domain / Circle of Bees / Storm Domain büyü listelerinin
built-in'de karşılığı **yok** — bunlar pakete ait içerik. Yani B5 tamamlansa bile
bu 24 tablo düzyazıda kalır; kapatmak için ya satır şemasına büyü anahtarı, ya da
pakete ait feat kartı basma izni gerekir. B5'in kapsamı bu yüzden burada
**yetersiz**, bulgu da bu yüzden yazıldı (K7 ihlali değil).

**Kanıt.**
```sh
# flutter_app'ten — subclass features satırlarında grant anahtarı ve büyü tablosu sayımı
python3 - <<'EOF'
import json, glob, collections
c = collections.Counter()
for p in glob.glob('assets/open5e_packs/*.pkg.json'):
    slug = p.split('/')[-1].replace('open5e-', '').replace('.pkg.json', '')
    for e in json.load(open(p))['entities'].values():
        if e['type'] != 'subclass':
            continue
        c['subclass'] += 1
        for f in e['attributes'].get('features') or []:
            c['rows'] += 1
            if set(f) - {'level', 'name', 'description'}:
                c['rows_with_grant'] += 1
            d = f.get('description') or ''
            if '|' in d and 'spell' in d.split('\n')[0].lower():
                c['spelltable_' + slug] += 1
print(c)
EOF
# → subclass 101, rows 523, rows_with_grant 0,
#   spelltable_toh 15, spelltable_open5e 8, spelltable_tdcs 1
```

**Dağılım.**

| Paket | Büyü tablosu | Örnek |
|---|--:|---|
| `open5e-toh` | 15 | Circle of Bees "Circle Spells", Hunt/Mercy/Portal/Serpent/Shadow/Vermin/Wind Domain Spells |
| `open5e-open5e` | 8 | Demise/Mischief/Storm Domain Spells, The Ancient Fey Court "Expanded Spell List" |
| `open5e-tdcs` | 1 | Blood Domain "Blood Domain Spells (table)" |
| **Toplam** | **24** | 7 tablo daha var ama büyü listesi değil (Totem Dragon, Combat Engineer gibi düzyazı içi tablolar) |

**Neden önemli.** Cleric domain büyüleri 5e'de "her zaman hazır" mekaniğidir —
oyuncu onları hazırlamak zorunda değildir ve hazırlık limitine saymazlar. Şu an
paket subclass'ı seçen karakterin sayfasında **tek bir büyü** görünmüyor; kural
yalnız feature metninde okunuyor. Aynı mekanik built-in Cleric domain'lerinde
çalışıyor, yani kullanıcı iki subclass arasında **davranış farkı** görüyor.
17 tablonun metninde ayrıca `\r\n` var ve tablo başlığı satır başında boru
taşımıyor; bu ayrı bir render sorusu (checklist F2), burada yalnız anılıyor.

**Seçenekler.**
1. **Satır şemasına anahtar ekle** — `classFeatures` satırına
   `always_prepared_spell_refs` (+ resolver Pass 4b'de okuyucu). Dört koordineli
   düzenleme (grant sözleşmesi), sonra mapper tablo satırlarını softRef'e çevirir;
   "1st | *sleep*, *ray of sickness*" seviye→büyü eşlemesi ayrıştırılabilir bir
   kalıp (24 tablonun hepsi aynı iki sütunlu şekilde).
2. **Pakete ait feat kartı bas** — built-in'in yaptığı şeyi mapper yapar: her
   büyü tablosu için bir `feat` kartı + `granted_feat_refs`. B5'in "never mint one"
   kuralının **gevşetilmesi** demektir; ref kapısı (§2 (a)) 24 yeni kart anlamına
   gelir, kopya üretmez ama karar senindir.
3. **Kapsam dışı** — "düzyazı olarak kalır" yazılır; o zaman F-open5e-02 ile
   birlikte, paket subclass'larının **hiçbir** büyü mekaniği taşımadığı kayda
   geçer.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-09 — background'un adı verilmiş dili düşüyor: Thieves' Cant ve Sylvan hiçbir alana yazılamıyor

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, 2 pakete yayılı (Dalga 1 / `tdcs`'te bulundu) |
| **Checklist** | checklist C2 (species/background/feat alanları) |
| **Kategori / etki** | `background` — kaynakta dil sütunu dolu **24** satırın **22'si** "seçim" (`granted_language_count` doğru yazılıyor), **2'si adı verilmiş dil**: `tdcs` Crime Syndicate Member → `Thieves' Cant`, `toh` Forest Dweller → `Sylvan`. İkisi de pakette **hiç** görünmüyor |
| **Cause code (öneri)** | `N` — `background` şemasında yalnız `granted_language_count` var (`content.dart:759`); `granted_languages` alanı **yok**, yani mapper'ın yazacağı yer de yok |
| **Durum** | ❓ danışılacak |

**Bulgu.** `background` şeması dili **sayı** olarak modelliyor: "One of your
choice" → 1. Kaynak bazen dilin **adını** veriyor, ve o ad hiçbir yere sığmıyor —
`granted_language_count` yazılamaz (sayı değil), `granted_languages` diye bir alan
yok. Sonuç: Crime Syndicate Member seçen karakter Thieves' Cant'i almıyor ve
kartında bunun **yazılı bir izi de yok** (feature metni ayrı bir alanda değil,
`description` düzyazısının içinde).

Alan `trait`, `feat`, `species` kategorilerinde **var** (`granted_languages`,
grant bloğu); yalnız `background` onu taşımıyor. Bu, 2024 SRD'nin background
tasarımından geliyor (dil hakları origin/species'e taşındı), yani şema 2024'e
göre doğru — ama korpüsün 19 paketinin çoğu **5e-2014** ve orada background dil
adı verebiliyor.

**Kanıt.**
```sh
# repo kökünden — kaynakta adı verilmiş dil taşıyan background satırları
python3 - <<'EOF'
import json, glob, re, collections
c, named = collections.Counter(), []
for p in glob.glob('open5e-api-staging/data/v1/*/Background.json'):
    for r in json.load(open(p)):
        f = r.get('fields', r)
        L = (f.get('languages') or '').strip()
        if not L or L.lower() in ('none', '-'):
            c['empty'] += 1
        elif re.search(r'choice|choose|any', L, re.I):
            c['choice'] += 1
        else:
            c['named'] += 1
            named.append((p.split('/')[-2], f.get('name'), L))
print(c, named)
EOF
# → Counter({'empty': 18, 'choice': 17, 'named': 7})
#   named'in 5'i "No additional languages" (yani gerçekte 0), kalan 2'si:
#   ('taldorei', 'Crime Syndicate Member', 'Thieves’ Cant')
#   ('toh', 'Forest Dweller', 'Sylvan')
```

**Dağılım.**

| Paket | Kart | Kaynaktaki dil |
|---|---|---|
| `open5e-tdcs` | Crime Syndicate Member | Thieves' Cant |
| `open5e-toh` | Forest Dweller | Sylvan |

**Neden önemli.** İki satır küçük bir sayı, ama F-pass0-05 ile aynı alanın iki
farklı kusuru: orada sayı **yanlış** yazılıyor, burada değer **yazılamıyor**.
İkisinin de kararı aynı alana dokunuyor, o yüzden birlikte görülmeli. Thieves'
Cant ayrıca boş bir bayrak değil — 2014'te Rogue sınıfının imza dilidir ve
karakterin dil listesinde görünmesi beklenir.

**Seçenekler.**
1. **Alanı ekle** — `background`'a `granted_languages` (grant bloğundakiyle aynı
   şekil, `CharacterResolver.grantFieldKeys` zaten okuyor). İki satır dolar;
   şema değişikliği + mapper'da tek dallanma.
2. **`description`'a düş** — mapper adı bulduğunda `mechanical_notes` benzeri bir
   yere yazar; kullanıcı görür ama mekanik değildir.
3. **Kapsam dışı** — 24 satırda 2; "şema 2024'e göre doğru, 2014 background dil
   adları düzyazıda kalır" kararı yazılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-toh-01 — `Underfoot` 1. seviyede seçilebiliyor: rogue arketipi, slot tablosunun ilk satırından seviye alıyor

| | |
|---|---|
| **Kapsam** | `open5e-toh` |
| **Checklist** | checklist C1 (class/subclass seviye tablosu) |
| **Kategori / etki** | `subclass` — 101 paketli subclass'ın **1'i**: `Underfoot` (Rogue) `granted_at_level: 1`. 3'ten küçük 46 değerin diğer **45'i doğru** (2014'te Cleric/Sorcerer/Warlock 1, Wizard/Druid 2); yanlış olan tek kart bu |
| **Cause code (öneri)** | `S` — kaynağın `ClassFeatureItem` satırı gerçekten `level: 1` diyor (`toh_underfoot_spell-slots`); paket sadık, ama B1'in "tablo satırlarını dışarıda bırak" kuralı burada tutmuyor çünkü upstream o satırlara `column_value` yazmamış (`M` sonucu) |
| **Durum** | ❓ danışılacak |

**Bulgu.** `granted_at_level` §5.2'nin kuralıyla hesaplanıyor:
`min(ClassFeatureItem.level)` — subclass'ın **tablo olmayan** özellikleri
üzerinden. "Tablo satırı" testi `column_value` dolu mu diye bakıyor. `toh`'ta
`Underfoot`'un büyü ilerleme tablosu **düzyazı** olarak geliyor, satırların
`column_value`'su boş, dolayısıyla `Spell Slots` (level 1) ve `Spells Known of
1st-Level and Higher` (level 1) normal özellik sayılıyor ve minimum 1 çıkıyor.
Oysa kartın kendi `Spellcasting` satırı **3. seviyede** ve 2014 kuralında rogue
arketipi 3'te seçilir. Sonuç: sihirbazın subclass adımı bu tek kartı **1. seviye
rogue'a** açıyor, diğer 5 `toh` rogue arketipi 3'te kilitli kalıyor.

Kart aynı zamanda F-pass0-10'un üçüncü kartı (üçte-bir büyücü); orada mekaniğin
**alanı yok**, burada alan var ve **değeri yanlış** — iki ayrı madde, o yüzden
iki ayrı kayıt (bir kayıt = bir checklist maddesi).

**Kanıt.**
```sh
# flutter_app'ten — 3'ten küçük granted_at_level değerleri ve ana sınıfları
python3 - <<'EOF'
import json,glob,os
OK={'Cleric':1,'Sorcerer':1,'Warlock':1,'Wizard':2,'Druid':2}
for p in sorted(glob.glob('assets/open5e_packs/*.pkg.json')):
    d=json.load(open(p)); names={k:v['name'] for k,v in d['entities'].items()}
    for e in d['entities'].values():
        if e['type']!='subclass': continue
        a=e['attributes']; g=a.get('granted_at_level')
        r=a.get('parent_class_ref'); pc=r.get('name') if isinstance(r,dict) else names.get(r)
        if isinstance(g,int) and g<3 and OK.get(pc)!=g:
            print(os.path.basename(p)[7:-9],'|',pc,'|',e['name'],'| granted_at_level',g)
EOF
# open5e-toh | Rogue | Underfoot | granted_at_level 1     <- tek satır

# kaynak sadık mı — evet, upstream'in kendi seviyesi 1
python3 -c "
import json
rows=[r['fields'] for r in json.load(open('../open5e-api-staging/data/v2/kobold-press/toh/ClassFeatureItem.json'))]
print([(r['level'],r['parent'],r['column_value']) for r in rows if 'underfoot' in r['parent']])"
# → (1, 'toh_underfoot_spell-slots', None) … column_value None olduğu için
#   satır 'tablo satırı' sayılmıyor ve minimuma giriyor
```

**Neden önemli.** §5.2 bu alanın **sihirbaz davranışını doğrudan değiştirdiğini**
yazıyor: `subclass_step.dart` `_grantedAtLevel` eksik değeri 1 kabul ediyordu,
B1 alanı doldurunca 3. seviye kilidi canlıya çıktı. O kilit şimdi 100 kartta
doğru, 1 kartta yanlış tarafa açılıyor — ve `wizard_pack_families_test`'in
yazılı iddiası "alan dolu ve aralıkta" olduğu için 1 değeri testten geçiyor.
Yanlış yön de kötü olan yön: kilidi gevşetiyor, karakter 1. seviyede alması
mümkün olmayan bir arketipi alıyor.

**Seçenekler.**
1. **Ana sınıfın arketip seviyesini taban al** — `granted_at_level` hesabında
   `max(min(ClassFeatureItem.level), archetypeLevel(parentClass))`. 2014 için
   tablo bilinen ve kısa (Cleric/Sorcerer/Warlock 1, Wizard/Druid 2, gerisi 3);
   45 doğru değeri bozmadan tek yanlışı düzeltir, ama mapper'a **kural bilgisi**
   koymak demektir.
2. **Tablo satırı testini genişlet** — `column_value` boş olsa da adı
   `Spell Slots` / `Spells Known…` olan satırları minimumdan dışla. Daha dar
   düzeltme, ama ad eşlemesi (§5.3'ün `SpeciesTrait` adıyla eşleme dersi:
   kırılgan).
3. **Kapsam dışı** — "kaynak öyle diyor" yazılır; o zaman tek kartın 1. seviyede
   göründüğü ve testin bunu yakalamadığı kayda geçer.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-toh-02 — `Scoundrel` background'u iki pakette birden: aynı iki beceri, %83 aynı metin, iki ayrı satır

| | |
|---|---|
| **Kapsam** | `open5e-toh` (ikizi `open5e-open5e`'de) |
| **Checklist** | checklist B2 (paketler arası kopya kart yok) |
| **Kategori / etki** | `background` — **1 kart** çifti. Statblok çocuk satırları dışarıda tutulduğunda korpüste **metni birebir aynı** olan paketler-arası kart sayısı **1** (bir `language`); bu çift ise birebir değil, **%83** benzer, ama mekaniği aynı |
| **Cause code (öneri)** | `D` — iki paket aynı içeriği ayrı kart olarak taşıyor; dedup ya da link kaydı yok |
| **Durum** | ❓ danışılacak |

**Bulgu.** `open5e-toh`'un `Scoundrel`'ı ile `open5e-open5e`'nin `Scoundrel`'ı
aynı cümleyle açılıyor, aynı iki beceriyi veriyor (`Athletics`,
`Sleight of Hand`), ikisinde de `granted_language_count: 0`. Metin uzunlukları
3.973 ve 5.371 karakter; `SequenceMatcher` oranı **0,83**. `source` alanları
farklı: *Tome of Heroes* ve *Open5e Originals*. İkisi de kuruluysa sihirbazın
background listesinde **iki `Scoundrel`** yan yana duruyor ve aralarındaki fark
yalnız düzyazının uzunluğu.

`dupe_census` bunu göremiyor: A bölümü built-in'e, B bölümü **birebir aynı**
metne bakıyor; bu çift B'nin "yalnız adı paylaşıyor" (1.782) kovasına düşüyor.
`toh`'un korpüsteki tek diğer ad çakışması `Misdirection` büyüsü ve o **gerçek
bir çakışma değil** — iki farklı büyü (210 vs 862 karakter, farklı etki).

**Kanıt.**
```sh
# flutter_app'ten — çocuk satırlar hariç, birebir aynı metinli paketler-arası kart
python3 - <<'EOF'
import json,glob,os,collections,difflib
g=collections.defaultdict(list)
for p in glob.glob('assets/open5e_packs/*.pkg.json'):
    slug=os.path.basename(p)[7:-9]
    for e in json.load(open(p))['entities'].values():
        g[(e['type'],e['name'].lower())].append((slug,e.get('description') or ''))
ident=collections.Counter()
for (t,n),v in g.items():
    if len({s for s,_ in v})<2: continue
    txt={d for _,d in v if d}
    if len(txt)==1: ident[t]+=1
print(dict(ident))                       # {'trait':125,'creature-action':63,'language':1}
v=g[('background','scoundrel')]
print([s for s,_ in v],                  # ['open5e','toh']
      round(difflib.SequenceMatcher(None,v[0][1],v[1][1]).ratio(),2))   # 0.83
EOF
```

**Neden önemli.** Kopya kartın maliyeti listede iki satır değil, **seçim**:
oyuncu hangisini seçerse seçsin aynı mekaniği alıyor ama karakteri farklı bir
pakete bağlanıyor; paket kaldırıldığında biri kayboluyor, diğeri kalıyor.
B2'nin sorduğu şey tam bu. Sayı küçük (1 çift) ama **ölçüm yöntemi eksik**:
birebir eşitlik testi %83'lük çifti göremiyor, yani korpüste bunun gibi kaç
çift olduğu **bilinmiyor**. Bir ön tarama (ucuz `quick_ratio`, üst sınır)
1.130 ad grubunu 0,80 üstünde işaretledi, ama bunların çoğu statblok çocuk
satırı; gerçek oranla sayım yapılmadı. Bu, Pass 0'a geri dönen bir soru.

**Seçenekler.**
1. **Ölç, sonra karar ver** — `dupe_census`'a çocuk satırları hariç tutan bir
   yakın-kopya modu (`--near <oran>`) ekle; B2 bugün yalnız birebir eşitliği
   ölçüyor ve bu çifti kaçırıyor. Karar bu sayıdan sonra verilir.
2. **Link kaydı** — `metadata.links` ile `toh` → `open5e` yönünde "aynı kart"
   ilişkisi yazılır; sihirbaz tek satır gösterir. B5'in link altyapısı zaten var
   (`toh`'ta `metadata.links` **yok**).
3. **Kapsam dışı** — "iki ayrı yayıncı belgesi, iki ayrı kart" yazılır; o zaman
   kullanıcının iki `Scoundrel` görmesi bilinçli kabul edilmiş olur.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-a5e-ag-01 — `Tenacious` feat'inin kurtarma yeterliliği düşüyor: alanı var, okuyanı var, yazanı yok

| | |
|---|---|
| **Kapsam** | `open5e-a5e-ag` — korpüs geneli tarandı, **tek kart** |
| **Checklist** | checklist C2 (species/background/feat alanları) |
| **Kategori / etki** | `feat` — `grants_save_prof_from_asi` korpüsteki **73 feat kartının 0'ında** dolu; kaynağı bu mekaniği yazan **1** kart var (`a5e-ag` `Tenacious`) ve o da alamıyor. Kartın ASI'si tam doğru yazılmış (`asi_amount: 1`, `asi_max_score: 20`, altı yetenek), yalnız cümlenin ikinci yarısı kayıp |
| **Cause code (öneri)** | `M` — alan **beyan edilmiş** (`builtin/content.dart:836`), **okuyanı da var** (`pending_choice_resolver_dialog.dart:793, 1203`, built-in `Resilient` bununla çalışıyor); yazan yalnız mapper tarafında yok |
| **Durum** | ❓ danışılacak |

**Bulgu.** `Tenacious`'ın gövdesi: *"Choose one ability score. The chosen ability
score increases by 1, to a maximum of 20, **and you gain proficiency in saving
throws using it**."* Bu, built-in `Resilient`'in birebir aynı mekaniği
(`srd_core/feats.dart:471` → `'grants_save_prof_from_asi': true`). Paket kartında
ASI yarısı tipli alanlara inmiş, kurtarma yarısı yalnız düzyazıda kalmış.

Bu bulgunun diğerlerinden farkı: burada **eksik olan tek şey mapper satırı**.
F-pass0-08'de alan yoktu, F-pass0-09'da alan yoktu, F-pass0-10'da alan yanlış
kategorideydi. Burada alan da okuyucu da yerinde — kart seçildiğinde diyalog
`grants_save_prof_from_asi == true` görseydi kurtarma yeterliliğini soracaktı.

**Neden önemli.** Doluluk tablosu bunu `🔴 0%` diye gösteriyor ama 0%'ın burada
"kaynakta yok" (`S`) demediğini hiçbir kapı söylemiyor — korpüste bu mekaniği
yazan tam bir kart var ve o kart pakette. C8'in "her boşluğun cause code'u var"
sorusu bu alanda `S` sanılıp geçilirse yanlış cevaplanır.

**Kanıt.**
```sh
# flutter_app'ten — mekaniği düzyazıda yazan ama tipli alanı boş olan feat'ler
python3 - <<'EOF'
import json,glob,os,re,collections
pat=re.compile(r'proficiency in saving throws|saving throw proficiency|'
               r'proficient in .{0,20}saving throw',re.I)
hits=collections.defaultdict(list)
for p in glob.glob('assets/open5e_packs/*.pkg.json'):
    doc=os.path.basename(p)[7:-9]
    for e in json.load(open(p))['entities'].values():
        if e['type']!='feat': continue
        a=e['attributes']
        if (pat.search(a.get('description') or '')
                and not a.get('grants_save_prof_from_asi')
                and not a.get('granted_save_proficiencies')):
            hits[doc].append(e['name'])
print(dict(hits))
EOF
# {'a5e-ag': ['Tenacious']}

dart run tool/open5e_import/bin/audit_packs.dart --only feat | grep save_prof
#    🔴   grants_save_prof_from_asi              0%  (0/73)
grep -rn "grants_save_prof_from_asi" lib/ | wc -l   # 4 — 1 şema, 2 okuma, 1 built-in kart
grep -rn "grants_save_prof_from_asi" tool/ | wc -l  # 0 — yazan yok
```

**Seçenekler.**
1. **Mapper'a tek kural** — `feat` gövdesinde ASI cümlesiyle aynı yerde kurtarma
   yeterliliği geçiyorsa `grants_save_prof_from_asi: true`. Metin eşlemesi, yani
   §5.3'ün "kırılgan" uyarısı geçerli; ama okuyucu hazır olduğu için diff tek satır.
2. **Elle kür** — tek kart, `migrate_pack_assets.dart` tarzı hedefli düzeltme.
   Ölçek bugün 1; yarın yeni bir belge gelirse tekrar kaçar.
3. **Kapsam dışı** — o zaman C8'e yazılı bir satır girmeli: "`grants_save_prof_from_asi`
   paket tarafında hiç yazılmaz, yalnız built-in kartların alanıdır."

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-a5e-ag-02 — `Marshal`'ın seviye tablosu 14. seviyede geriliyor: 30 feet → 10 feet → 45 feet

| | |
|---|---|
| **Kapsam** | `open5e-a5e-ag` — korpüs geneli tarandı, **tek kart / tek hücre** |
| **Checklist** | checklist D1 (değer kaynakla aynı) |
| **Kategori / etki** | `class` — `Marshal`'ın `description`'ındaki 20 satırlık ilerleme tablosunda `Commanding Presence` sütunu 13'te 30 feet, **14'te 10 feet**, 15'te 45 feet. Korpüsteki 103 `class`/`subclass` kartının tablolarında azalan geçiş **2** tane; öteki (`toh` `Sapper`) ilerleme tablosu değil, tuzak listesi |
| **Cause code (öneri)** | `S` — kaynak `ClassFeatureItem` satırı da `14 → "10 feet"` diyor; paket kaynağı **birebir** yeniden üretiyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** `verify_packs` bu paketi **0 disagree / 0 absent** ile geçiriyor ve
haklı: yazılan değer kaynaktaki değer. Ama kural düzeyinde yanlış — bir sınıf
özelliğinin menzili 14. seviyede dörtte birine düşüp 15'te dört buçuk katına
çıkmıyor. Upstream'in dizgi hatası, paketten kullanıcıya kesintisiz geçiyor.

**Neden önemli.** Bu, dalganın beşinci sorusunun ilk somut karşılığı: *"alan dolu
ve kaynakla aynı, ama değer kuralla uyuşuyor mu?"* D1'in **lafzı** geçiyor,
**amacı** kalıyor. Tarama araçlarının tamamı kaynağa karşı ölçüm yapıyor; hiçbiri
"kaynak kendi içinde tutarlı mı" diye sormuyor, dolayısıyla bu sınıftan her hata
sessizce taşınır.

**Kanıt.**
```sh
# flutter_app'ten — sınıf/arketip tablolarında azalan sayısal geçişler
python3 - <<'EOF'
import json,glob,os,re
nums=lambda c:(lambda m:int(m.group(1)) if m else None)(re.match(r'^(\d+)',c.strip()))
for p in glob.glob('assets/open5e_packs/*.pkg.json'):
    for e in json.load(open(p))['entities'].values():
        if e['type'] not in ('class','subclass'): continue
        L=[l for l in (e['attributes'].get('description') or '').split('\n')
           if l.strip().startswith('|')]
        if len(L)<4: continue
        hdr=[c.strip() for c in L[0].strip('|').split('|')]
        body=[[c.strip() for c in l.strip('|').split('|')] for l in L[2:]]
        for i,col in enumerate(hdr[1:],1):
            seq=[(r[0],nums(r[i])) for r in body if len(r)>i and nums(r[i]) is not None]
            for a,b in zip(seq,seq[1:]):
                if b[1]<a[1]:
                    print(os.path.basename(p),e['name'],col,f'{a[0]}:{a[1]}→{b[0]}:{b[1]}')
EOF
# open5e-toh.pkg.json  Sapper  Time Required to Build Trap  ...   (tablo değil, liste)
# open5e-a5e-ag.pkg.json  Marshal  Commanding Presence  13:30→14:10

# kaynak da aynı şeyi diyor
python3 - <<'EOF'
import json,glob
d=glob.glob('../open5e-api-staging/data/v2/*/a5e-ag')[0]
cf={x['pk']:x.get('fields',x) for x in json.load(open(d+'/ClassFeature.json'))}
ci=[x.get('fields',x) for x in json.load(open(d+'/ClassFeatureItem.json'))]
print(sorted((it['level'],it['column_value']) for it in ci
             if cf.get(it['parent'],{}).get('name')=='Commanding Presence'
             and it['column_value'])[12:15])
EOF
# [(13, '30 feet'), (14, '10 feet'), (15, '45 feet')]
```

**Seçenekler.**
1. **Kaynak hatasını düzeltme, işaretle** — importer'a bir *tutarlılık uyarısı*
   ekle (monoton olması beklenen sütunda gerileme → `unmapped_report.json`'a
   satır). Değer değişmez, ama bir daha sessiz geçmez. Bugün bilinen ölçek: 1 hücre.
2. **Yerinde düzelt** — 14. seviyeyi 30 feet yap (a5e basılı tablosuna bakılarak).
   D1'i **kırar**: paket artık kaynakla birebir değil, ve `verify_packs` disagree
   üretir; o zaman allowlist gerekir.
3. **Kapsam dışı** — "upstream ne diyorsa o" yazılır. Politika olarak savunulabilir
   (paket = belgenin aynası), ama o zaman §5'e yazılı girmeli, çünkü şu an
   hiçbir yerde yazılı değil.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-bfrd-01 — `Mechanist` ilerleme tablosunun ikinci sütunu `Augment Effects Known (2)` diye başlıklanıyor; kaynağın kendi kimliği ona `Augmented Items` diyor

| | |
|---|---|
| **Kapsam** | `open5e-bfrd` — korpüs geneli tarandı, **tek kart / tek sütun başlığı** |
| **Checklist** | checklist A3 (uydurma değer yok) |
| **Kategori / etki** | `class` — `Mechanist`'in `description`'ına render edilen `### Class Table`'ın iki sütunu var ve ikisinin başlığı da `Augment Effects Known`; mapper ikinciyi `Augment Effects Known (2)` diye numaralıyor. Kaynakta iki ayrı `ClassFeature` var — `bfrd_mechanist_augment-effects-known` ve **`bfrd_mechanist_augmented-items`** — ama ikisinin de `name` alanı `Augment Effects Known`. `(2)` korpüste **1** tane: paketli 103 `class`/`subclass` kartının tablolarında başka çakışma yok |
| **Cause code (öneri)** | `M` — kaynak `name` upstream'de yanlış, ama doğru ad `pk`'de duruyor ve mapper onu hiç okumuyor (`mappers/chargen.dart:1679-1683`, çakışmayı numaralayan blok) |
| **Durum** | ❓ danışılacak |

**Bulgu.** B2 bu tabloyu 2026-08-14'te "bozuk" durumdan kurtardı: `column_value`
satırları artık düşmüyor, markdown tablo olarak basılıyor. Kalan kusur başlıkta:
kullanıcı 2. sütunun neyi saydığını tablodan öğrenemiyor, çünkü 1. sütunla aynı
adı taşıyor. Sayılar farklı (2/3/3/4… ile 3/3/3/4…), yani iki ayrı mekanik.

`verify_packs --doc bfrd --only class,subclass` **2 ok / 0 disagree / 0 absent**
diyor ve haklı — `description` alanı kural tablosunda yok, tablo başlığı
hiçbir kapının ölçtüğü bir değer değil. Bu bulgu ölçümden değil **okumadan**
geldi (plan §4 Adım 3-4).

**Neden önemli.** Mapper'ın yorumu ("çakışan adı numarala") sadakat değil, bir
**karar**: kaynak iki farklı şeye aynı adı verdiğinde paket o adı iki kez yazıyor.
Aynı kaynakta doğru ad zaten var (`pk` slug'ı), yani bu, F-a5e-ag-02'nin tersi
bir durum — orada kaynak yanlıştı ve başka yerde doğrusu yoktu; burada var.

**Kanıt.**
```sh
# flutter_app'ten — korpüste kaç sütun başlığı numaralanmış
python3 - <<'EOF'
import json,glob,re,collections
c=collections.Counter()
for f in sorted(glob.glob('assets/open5e_packs/*.pkg.json')):
    pk=f.split('/')[-1][:-9]
    for e in json.load(open(f))['entities'].values():
        if e['type'] not in ('class','subclass'): continue
        for hdr in re.findall(r'\| Level \|([^\n]*)\|', e['attributes'].get('description','')):
            for col in hdr.split('|'):
                if re.search(r'\(\d+\)\s*$', col.strip()): c[(pk,e['name'],col.strip())]+=1
print(dict(c))
EOF
# {('open5e-bfrd', 'Mechanist', 'Augment Effects Known (2)'): 1}

# kaynağın kimliği ile adı ayrı şeyler söylüyor
python3 -c "
import json
for r in json.load(open('../open5e-api-staging/data/v2/kobold-press/bfrd/ClassFeature.json')):
    if r['fields'].get('feature_type')=='CLASS_TABLE_DATA':
        print(r['pk'], '->', r['fields']['name'])"
# bfrd_mechanist_augment-effects-known -> Augment Effects Known
# bfrd_mechanist_augmented-items       -> Augment Effects Known
```

**Seçenekler.**
1. **`pk` slug'ından başlık türet (çakışma hâlinde)** — `_classTable`'daki
   numaralama bloğu, ad çakıştığında `pk`'nin son parçasını başlığa çevirsin
   (`augmented-items` → `Augmented Items`). Bugün bilinen ölçek: 1 sütun,
   1 kart, 1 paket; `(n)` yolu yedek olarak kalır.
2. **İki sütunu birleştir** — mapper zaten "sessizce birleştirmemek" için
   numaralıyordu; birleştirmek bir sütunun sayılarını siler, bu yüzden yanlış.
3. **Kapsam dışı** — "kaynak ne diyorsa o", F-a5e-ag-02'nin 3. seçeneğiyle aynı
   politika. Fark: orada doğru değer hiçbir yerde yoktu, burada `pk`'de var.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### Dalga 2 — büyü paketleri

### F-pass0-11 — kaynağın `permanent` dediği 25 büyü kartta `Until Dispelled` yazıyor: sözlükte "kalıcı" satırı yok, mapper en yakınına yuvarlıyor

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli, beş büyü paketine yayılı (dağılım aşağıda) |
| **Checklist** | checklist A3 (uydurma değer yok) |
| **Kategori / etki** | `spell` — `duration_unit_ref`; kaynağın `duration` sütunu `permanent` (22), `permanent until discharged` (2), `permanent; one generation` (1) diyen **25** satırda karta `Until Dispelled` yazılıyor. `kp`'de 2 kart: `Curse of Formlessness`, `Incantation of Lies Made Truth` |
| **Cause code (öneri)** | `M` — `mappers/spell.dart:237` (`if (d.startsWith('permanent')) return (null, 'Until Dispelled');`); Tier-0 `duration-unit` sözlüğünde yedi satır var (`lookups.dart:1388-1396`) ve hiçbiri "kalıcı" değil |
| **Durum** | ❓ danışılacak |

**Bulgu.** Mapper'ın yazılı kuralı "serbest metin süreleri altı kanonik satıra
oturt, oturmayan `Special` olsun" (satır 229-231). `instantaneous`, `10 minutes`,
`until dispelled` bu kurala uyuyor. `permanent` ise **ayrı bir satırla** ele
alınıp `Until Dispelled`'a gönderiliyor — yani "oturmuyorsa `Special`" yolundan
çıkarılıp karta kaynağın söylemediği bir mekanik iddia yazılıyor: büyü
*dağıtılabilir*. `permanent; one generation` ve `permanent until discharged`
satırlarında kayıp daha da somut — kaynağın verdiği bitiş koşulu düşüyor.

`verify_packs --doc kp --only spell` **200 ok / 0 disagree / 0 absent /
0 unsourced** diyor ve haklı: kural tablosunda `duration_unit_ref` için
karşılaştırma yok, süre metni serbest metin. Bu bulgu da ölçümden değil
**okumadan** geldi (plan §4 Adım 3-4).

**Neden önemli.** Aynı kart gövdesinde süre düzyazısı yok — `kp`'nin iki büyüsünün
`description`'ı süreye hiç değinmiyor — yani kullanıcının süreyi göreceği tek yer
bu alan. `Special` "kartın gövdesine bak" der; `Until Dispelled` "*dispel magic*
bunu bitirir" der. İkincisi kaynağın yazmadığı bir kuraldır.

**Kanıt.**
```sh
# flutter_app'ten — kaynakta kaç satır "permanent" ile başlıyor, hangi pakette
python3 - <<'EOF'
import json,glob,collections,os
per=collections.Counter(); raw=collections.Counter()
for f in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json'):
    doc=os.path.basename(os.path.dirname(f))
    for r in json.load(open(f,encoding='utf-8')):
        d=(r['fields'].get('duration') or '').strip().lower()
        if d.startswith('permanent'): per[doc]+=1; raw[d]+=1
print(sum(per.values()), dict(per), dict(raw))
EOF
# 25 {'spells-that-dont-suck': 1, 'deepmx': 1, 'deepm': 9, 'kp': 2, 'a5e-ag': 12}
#    {'permanent': 22, 'permanent; one generation': 1, 'permanent until discharged': 2}

# kartta ne yazıyor
python3 -c "
import json
p=json.load(open('assets/open5e_packs/open5e-kp.pkg.json'))
for e in p['entities'].values():
    if e['name'] in ('Curse of Formlessness','Incantation of Lies Made Truth'):
        print(e['name'], '->', e['attributes']['duration_unit_ref']['name'])"
# Curse of Formlessness -> Until Dispelled
# Incantation of Lies Made Truth -> Until Dispelled
```

**Dağılım** *(yayılan bulgu kuralı — 2026-08-18'de ölçüldü)*

| Paket | Etkilenen kart |
|---|--:|
| `open5e-a5e-ag` | 12 |
| `open5e-deepm` | 9 |
| `open5e-kp` | 2 |
| `open5e-deepmx` | 1 |
| `open5e-spells-that-dont-suck` | 1 |
| **Toplam** | **25** |

**Seçenekler.**
1. **`permanent` → `Special`** — tek satır silmek (`spell.dart:237`); kart
   "özel" der, kullanıcı gövdeye bakar, uydurma iddia kalkar. `dispelled`
   içeren 2 satır zaten bir üstteki kuraldan `Until Dispelled` alır ve orada
   kalır. Ölçek: 23 kart değişir, 19 paketin 5'i.
2. **Tier-0'a `Permanent` satırı ekle** — sözlük 7 → 8 satır
   (`is_concentration_compatible: false`); en sadık yol, ama built-in şema
   değişikliği ve şema sürümü demek, üstelik SRD'nin kendi büyülerinde
   karşılığı yok.
3. **Kapsam dışı** — 5e'de kalıcı büyülerin çoğu fiilen *dispel magic*'e
   açıktır; mapper bunu kural olarak yazmış sayılır. O hâlde gerekçe koddan
   §5.6'ya taşınmalı (bugün yalnız satır içi bir kod satırı, yazılı karar değil).

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-wz-01 — kaynak "1 hour/caster level" diyor, kart düpedüz "1 Hour" yazıyor

| | |
|---|---|
| **Kapsam** | `open5e-wz` — 1 kart (`Order of Revenge`); korpüs geneli de 1 (ölçüldü) |
| **Checklist** | checklist A3 (uydurma değer yok) |
| **Kategori / etki** | `spell` — `duration_amount` + `duration_unit_ref`; kaynağın `duration` sütunu `1 hour/caster level`, kartta `Hours` / `1` |
| **Cause code (öneri)** | `M` — `mappers/spell.dart:238` — süre regexi ilk sayı+birim çiftini kapıp arkasındaki `/caster level`'ı görmezden geliyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** Regex serbest metnin ilk sayı+birim çiftini alıyor, kalanına bakmıyor.
`1 hour/caster level` böylece `Hours 1` oluyor: 10. seviye bir büyücünün 10 saati
karta 1 saat olarak iniyor. Fonksiyonun kendi yedeği (`spell.dart:248`,
`return (null, 'Special')`) bu satır için dürüst olanı verirdi — "özel, gövdeye
bak" der, yanlış bir sayı vermez.

**Neden önemli.** Süre kartta yalnız bu iki alanda yaşıyor; `Order of Revenge`'in
`description`'ı süreden hiç söz etmiyor ("…until the spell expires"), yani
kullanıcının okuyabileceği başka yer yok. F-pass0-11 kaynağın söylemediği bir
mekanik ekliyordu; bu kayıt kaynağın söylediği ölçeği **küçültüyor**.

**Kanıt.**
```sh
# flutter_app'ten — korpüsteki "…/level", "per …" süreleri
python3 - <<'EOF'
import json,glob
for f in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json'):
    for r in json.load(open(f,encoding='utf-8')):
        d=(r['fields'].get('duration') or '').lower()
        if 'level' in d or ' per ' in d or '/' in d:
            print(f.split('/data/')[1], r['fields']['name'], repr(d))
EOF
# v2/kobold-press/wz/Spell.json Order of Revenge '1 hour/caster level'

python3 -c "
import json
p=json.load(open('assets/open5e_packs/open5e-wz.pkg.json'))
for e in p['entities'].values():
    if e['name']=='Order of Revenge':
        a=e['attributes']; print(a['duration_unit_ref']['name'], a.get('duration_amount'))"
# Hours 1
```

**Seçenekler.**
1. **Regex'i kuyruk kontrolüyle sıkılaştır** — eşleşmeden sonra kalan metinde
   `/`, `per`, `level` varsa `Special`'a düş. Tek satır, ölçek 1 kart.
2. **`duration_text` alanı** — serbest metni olduğu gibi taşıyan bir alan
   (F-pass0-12 de bunu çözer), ama built-in şema değişikliği demek.
3. **Kapsam dışı** — 1 kart; o hâlde "ilk sayı yeterlidir" kararı `§5.6`'ya
   yazılmalı, bugün yazılı değil.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-wz-02 — kaynağın süresi "concentration + 1 round", kart `requires_concentration: false` diyor

| | |
|---|---|
| **Kapsam** | `open5e-wz` — 1 kart (`Storm of Axes`); v2'de korpüs geneli de 1 (ölçüldü) |
| **Checklist** | checklist A3 (uydurma değer yok) |
| **Kategori / etki** | `spell` — `requires_concentration` (zorunlu alan); kaynağın `duration` sütunu `concentration + 1 round`, `concentration` sütunu `false` → kart `false` + `Rounds 1` |
| **Cause code (öneri)** | `M` — `mappers/spell.dart:46` (`'requires_concentration': s['concentration'] == true`) yalnız bool sütunu okuyor, `duration` metnine hiç bakmıyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** Kaynak aynı mekaniği iki yere yazmış: `concentration` bool'u ve
`duration` metni. `Storm of Axes`'te bool `false`, metin `concentration + 1 round`.
Mapper bool'a inanıyor, kart "konsantrasyon gerekmez" diyor — kaynağın kendi
satırıyla çelişen bir iddia. Süre tarafı da kırpılıyor: `Rounds 1`, yani
"konsantrasyon boyunca + 1 tur" yerine yalnız 1 tur.

İkinci satır aynı ailede ama sebebi farklı: `Eternal Echo`'nun **v1**
`duration`'ı `Concentration`, **v2**'si `special`; bool iki tarafta da boş/`false`.
Mapper v2 okuyor, kart `Special` + konsantrasyonsuz. Burada kayıp mapper'da değil
kaynağın iki sürümü arasında (`S`), ama sonucu kullanıcı için aynı.

**Neden önemli.** `requires_concentration` **zorunlu** bir şema alanı ve oyunda
sert bir kural: aynı anda tek konsantrasyon büyüsü. Yanlış `false`, sihirbazın ve
kart görünümünün taşıdığı en sık kullanılan kısıtı sessizce kaldırıyor.

**Kanıt.**
```sh
# flutter_app'ten — süre metninde "concentration" geçen satırlar
python3 - <<'EOF'
import json,glob
for f in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json')+glob.glob('../open5e-api-staging/data/v1/*/Spell.json'):
    for r in json.load(open(f,encoding='utf-8')):
        fl=r['fields']; d=(fl.get('duration') or '').lower()
        if 'concentration' in d:
            print(f.split('/data/')[1], fl['name'], repr(fl.get('duration')), 'bool=', fl.get('concentration'))
EOF
# v2/kobold-press/wz/Spell.json  Storm of Axes  'concentration + 1 round' bool= False
# v1/warlock/Spell.json          Eternal Echo   'Concentration'           bool= None
# v1/warlock/Spell.json          Storm of Axes  'Concentration + 1 round' bool= None

python3 -c "
import json
p=json.load(open('assets/open5e_packs/open5e-wz.pkg.json'))
for e in p['entities'].values():
    if e['name'] in ('Storm of Axes','Eternal Echo'):
        a=e['attributes']; print(e['name'], a['requires_concentration'], a['duration_unit_ref']['name'], a.get('duration_amount'))"
# Storm of Axes False Rounds 1
# Eternal Echo  False Special None
```

**Seçenekler.**
1. **Bool'u metinle birlikte oku** — `duration` metni `concentration` içeriyorsa
   `requires_concentration: true`. İki satırlık mapper değişikliği; v2'de ölçek
   1 kart, ama kural bütün paketler için doğru olur.
2. **Yalnız kaydet, düzeltme** — kaynak tutarsızlığı olarak `S` say ve §5.6'ya
   "bool otoritedir" cümlesini yaz. Bugün böyle bir cümle yok.
3. **Kapsam dışı** — 1 kart. Ama alan zorunlu olduğu için sessiz yanlış değer,
   boş alandan daha pahalı.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-12 — "1 year" süreler karta `Special` olarak iniyor, sayı büsbütün kayboluyor

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli 3 kart (`open5e-wz` 1, `open5e-deepm` 2) |
| **Checklist** | checklist A3 (uydurma değer yok — burada *eksik* değer) |
| **Kategori / etki** | `spell` — `duration_unit_ref` + `duration_amount`; kaynağın `1 year` dediği satırlar kartta `Special` / `null` |
| **Cause code (öneri)** | `M` — `mappers/spell.dart:238` regexi yalnız tur/dakika/saat/gün tanıyor, `year` yok; `lookups.dart:1388-1396` sözlüğünün en büyük birimi `Days` |
| **Durum** | ❓ danışılacak |

**Bulgu.** Kaynak ölçülebilir bir süre veriyor (`1 year`), kart hiçbir sayı
taşımıyor. `Special` kanonik bir satır olduğu için ne `unmapped_report.json`'a
ne de `verify_packs`'e düşüyor — `duration_unit_ref` kural tablosunda yok
(F-pass0-11 ile aynı kör nokta). Şemada serbest metin süre alanı da olmadığı için
"1 yıl" bilgisi paketten tamamen çıkıyor.

**Neden önemli.** F-pass0-11 kaynağın söylemediğini ekliyor, bu kayıt kaynağın
söylediğini siliyor — ikisi de aynı kök nedenden: yedi satırlık Tier-0 süre
sözlüğü, üçüncü taraf metinlerinin kuyruğunu taşımıyor. `Days 365` yazılabilir
olduğu için burada kayıp gereksiz.

**Dağılım** *(yayılan bulgu kuralı — 2026-08-18'de ölçüldü)*

| Paket | Etkilenen kart |
|---|--:|
| `open5e-deepm` | 2 (`Bloom`, `Desolation`) |
| `open5e-wz` | 1 (`Toxic Pollen`) |
| **Toplam** | **3** |

**Kanıt.**
```sh
# flutter_app'ten — yıl/hafta/ay ölçekli süreler
python3 - <<'EOF'
import json,glob
for f in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json'):
    for r in json.load(open(f,encoding='utf-8')):
        d=(r['fields'].get('duration') or '').lower()
        if any(w in d for w in ('year','week','month')):
            print(f.split('/data/')[1], r['fields']['name'], repr(d))
EOF
# v2/kobold-press/deepm/Spell.json Bloom '1 year'
# v2/kobold-press/deepm/Spell.json Desolation '1 year'
# v2/kobold-press/wz/Spell.json    Toxic Pollen '1 year'

python3 -c "
import json
p=json.load(open('assets/open5e_packs/open5e-wz.pkg.json'))
for e in p['entities'].values():
    if e['name']=='Toxic Pollen':
        a=e['attributes']; print(a['duration_unit_ref']['name'], a.get('duration_amount'))"
# Special None
```

**Seçenekler.**
1. **`year`/`week`/`month`'u güne çevir** — regexe üç birim ekle, `Days 365` /
   `Days 7` / `Days 30` yaz. Ölçek 3 kart, sözlük değişmez.
2. **`duration_text` alanı** — serbest metni taşı (F-wz-01 de bunu çözer);
   built-in şema değişikliği.
3. **Kapsam dışı** — 3 kart; o hâlde "`Special` kabul edilebilir kayıptır"
   kararı §5.6'ya yazılmalı, bugün yazılı değil.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-13 — koşullu ve değişken süreler karta düz sayı olarak iniyor: "2-12 hours" → `Hours 12`

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli 4 kart (`open5e-deepmx` 2, `open5e-deepm` 2) |
| **Checklist** | checklist A3 (kaynağın söylemediği kesinlik) |
| **Kategori / etki** | `spell` — `duration_amount`; kaynak "2-12 saat" ya da "24 saat **ya da** şu olana kadar" derken kart tek bir sayı iddia ediyor |
| **Cause code (öneri)** | `M` — `mappers/spell.dart:238`; süre regexi metindeki ilk sayı+birim çiftini alıp kuyruğu atıyor, aralığın alt sınırı ve "…until" koşulu düşüyor. Şemada serbest metin süre alanı yok (`N` yanı) |
| **Durum** | ❓ danışılacak |

**Bulgu.** İki ayrı metin şekli, aynı satırda birleşiyor:

- **Aralık:** `Risen Road` kaynakta `2-12 hours` (gövdesi "2d6 saat sonra biter"
  diyor), kartta `Hours 12` — regex `2` ile `-` çiftini eşleyemeyip `12 hours`'ı
  yakalıyor, yani sessizce **üst sınırı** seçiyor.
- **Koşul:** `Gift of Azathoth` kaynakta `24 hours or until the target attempts a
  third death saving throw`, kartta `Hours 24`; `Grasp of the Tupilak`
  (`1 hour or until triggered`) ve `Mass Surge Dampener`
  (`1 minute, or until expended`) aynı şekilde koşulsuz iniyor.

**Neden önemli.** F-pass0-12 kaynağın verdiği sayıyı siliyordu, bu kayıt tersini
yapıyor: kaynağın **belirsiz** bıraktığı süreyi kart kesin sayı olarak yazıyor.
Ne `verify_packs` ne gate görüyor, çünkü `duration_unit_ref` kural tablosunda yok
(F-pass0-11/12 ile aynı kör nokta). Mapper'ın kendi `Special` dalı bu satırlar
için dürüst değer olurdu — nitekim `kp`/`Feed the Worms` (`until destroyed`) hiç
dalla eşleşmediği için `Special`/`null` iniyor ve **kayıp yok**; kayıp yalnız
metin bir sayıyla başladığında oluşuyor.

**Dağılım** *(yayılan bulgu kuralı — 2026-08-18'de ölçüldü)*

| Paket | Etkilenen kart |
|---|--:|
| `open5e-deepmx` | 2 (`Risen Road`, `Gift of Azathoth`) |
| `open5e-deepm` | 2 (`Grasp of the Tupilak`, `Mass Surge Dampener`) |
| **Toplam** | **4** |

**Kanıt.**
```sh
# flutter_app'ten — kaynak süresi aralık ya da "…or until" olan satırlar + kartın değeri
python3 - <<'EOF'
import json,glob,re
pat=re.compile(r'\d+\s*[-–]\s*\d+|or,? until')
for p in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json'):
    doc=p.split('/')[4]
    src={r['fields']['name']:r['fields'] for r in json.load(open(p,encoding='utf-8'))}
    try: pk=json.load(open('assets/open5e_packs/open5e-%s.pkg.json'%doc,encoding='utf-8'))['entities']
    except FileNotFoundError: continue
    for e in pk.values():
        f=src.get(e['name'])
        if f and pat.search((f.get('duration') or '').lower()):
            a=e['attributes']
            print(doc, e['name'], '|', f['duration'], '->', a['duration_unit_ref']['name'], a.get('duration_amount'))
EOF
# deepmx Gift of Azathoth | 24 hours or until ... -> Hours 24
# deepmx Risen Road       | 2-12 hours            -> Hours 12
# deepm  Grasp of the Tupilak | 1 hour or until triggered -> Hours 1
# deepm  Mass Surge Dampener  | 1 minute, or until expended -> Minutes 1
```

**Seçenekler.**
1. **Belirsizse `Special` yaz** — regex eşleşmesinden önce aralık/koşul deseni
   ara, bulursan mapper'ın kendi `Special` dalına düş. Dört kart, iki satır kod;
   kesin ama yanlış sayı yerine dürüst boşluk.
2. **`duration_text` alanı** — serbest metni taşı (F-wz-01 ve F-pass0-12 de bunu
   çözer); built-in şema değişikliği, üç kaydı birden kapatır.
3. **Kapsam dışı** — 4 kart; o hâlde "süre alanı yalnız üst sınırı taşır" kararı
   §5.6'ya yazılmalı, bugün yazılı değil.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-14 — kuralları "konsantrasyonu kaybedersen" diyen 7 büyünün kartı `requires_concentration: false`

| | |
|---|---|
| **Kapsam** | `pass0` — korpüs geneli 7 kart, 5 pakete yayılı (`deepmx` 2, `deepm` 2, `toh` 1, `wz` 1, `a5e-ag` 1) |
| **Checklist** | checklist A3 (kartın kendi gövdesiyle çelişen zorunlu alan) |
| **Kategori / etki** | `spell` — `requires_concentration`; 7 kartın düzyazısı "konsantrasyonu bırakırsan büyü biter" derken **zorunlu** alan `false` |
| **Cause code (öneri)** | `S` — kaynağın `Spell.concentration` bool sütunu bu satırlarda `false`; `deepmx`'te 64 satırın 64'ü `false`, v1 `dmag-e` sütunu ise 64/64 `null`. Mapper sadık kopyalıyor (`spell.dart:46`) |
| **Durum** | ❓ danışılacak |

**Bulgu.** `Shadow Realm Gateway` gövdesi *"the portal remains open for one minute
or until you lose concentration on it"* diyor; `Summon Old One's Avatar`
*"each round you maintain concentration on the spell…"* diyor. İkisinin de bool'u
`false`, dolayısıyla kart "konsantrasyon gerekmez" iddiasında. Aynı desen beş
belgede 7 kartta var. `wz`/`Storm of Axes` bu listede ama zaten **F-wz-02** olarak
yazılı (orada delil `duration` metniydi, burada gövde metni) — aynı kart, iki
farklı okumadan görüldü.

**Neden önemli.** F-wz-02 mapper'ın bakmadığı bir sütunu (`duration` metni)
gösteriyordu; bu kayıt kaynağın sütununun **kendisinin** yanlış olduğunu
gösteriyor, yani kod düzeltmesiyle kapanmaz. Alan zorunlu ve oyunda doğrudan
mekanik: "konsantrasyon gerekmez" diyen bir kart, masada aynı anda ikinci bir
konsantrasyon büyüsüne izin verir.

**Dağılım** *(yayılan bulgu kuralı — 2026-08-18'de ölçüldü)*

| Paket | Etkilenen kart |
|---|--:|
| `open5e-deepmx` | 2 (`Shadow Realm Gateway`, `Summon Old One's Avatar`) |
| `open5e-deepm` | 2 (`Caustic Touch`, `Stench of Rot`) |
| `open5e-toh` | 1 (`Gale`) |
| `open5e-wz` | 1 (`Storm of Axes` — F-wz-02 ile aynı kart) |
| `open5e-a5e-ag` | 1 (`Plane Shift`) |
| **Toplam** | **7** |

**Kanıt.**
```sh
# flutter_app'ten — bool false ama gövde konsantrasyon kuralı yazıyor
python3 - <<'EOF'
import json,glob,re,collections
pat=re.compile(r'lose concentration|maintain(ing)? concentration|stop concentrating|concentrating on (the|this) spell', re.I)
c=collections.Counter()
for p in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json'):
    for r in json.load(open(p,encoding='utf-8')):
        f=r['fields']
        if not f.get('concentration') and pat.search(f.get('desc') or ''):
            print(p.split('/')[4], f['name']); c[p.split('/')[4]]+=1
print(dict(c))
EOF
# {'deepmx': 2, 'deepm': 2, 'toh': 1, 'wz': 1, 'a5e-ag': 1}
```

**Seçenekler.**
1. **Gövdeden çıkar** — düzyazıda konsantrasyon kuralı geçen ve bool'u `false`
   olan satırlarda `true` yaz. 7 kart; ama metin sezgisi, yanlış pozitif riski
   var (`deepmx`/`Extract Foyson` "concentrating it into a powder" diyor ve
   büyüyle ilgisi yok — bu yüzden desen "lose/maintain/stop concentrating on the
   spell" kalıplarıyla sınırlandı).
2. **Yukarı bildir** — kusur kaynakta; Open5e tarafına satır satır bildir,
   pakette dokunma. Kayıt açık kalır, `S` gerekçesi §5.6'ya yazılır.
3. **Kapsam dışı** — 7 kart; "kaynak ne derse o" kararı yazılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-spells-that-dont-suck-01 — "Self (60-foot radius)" yazan menzilin yarıçapı hiçbir alana yazılmıyor

| | |
|---|---|
| **Kapsam** | `open5e-spells-that-dont-suck` — 8 kart (korpüste bu deseni kullanan tek belge) |
| **Checklist** | checklist A3 (kaynakta yazılı bir sayı kartta hiç görünmüyor) |
| **Kategori / etki** | `spell` — `range_ft` / `area_size_ft`; **8 kartta** `range_text` parantezindeki yarıçap/çap düşüyor, kart yalnız `range_type: Self` diyor |
| **Cause code (öneri)** | `M` — `_range` (`mappers/spell.dart:~120`) `range_text` içinde `self` görünce dalı orada bitiriyor; parantezin içindeki sayıyı okuyan kod yok. Kaynak sütunu (`range`) bu satırlarda `0`, yani sayı yalnızca metinde |
| **Durum** | ❓ danışılacak |

**Bulgu.** Kaynağın 8 satırı menzili *"Self (60-foot radius)"*, *"Self (10-foot
dome)"*, *"Self (1-mile radius)"* biçiminde yazıyor. Kart bunların hepsinde
`range_type: Self`, `range_ft: null`, `area_shape_ref: null`,
`area_size_ft: null` taşıyor — yani **sayı da şekil de yok**. `Drink Life`'ın
60 feetlik küresi, `Alter Weather`'ın 1 millik alanı ve `Arcane Shelter`'ın
10 feetlik kubbesi kartta hiçbir yerde durmuyor.

**Neden önemli.** Bunlar alan büyüleri: yarıçap büyünün tek nicel etkisi.
Şemada iki uygun ev de **var** (`area_shape_ref` + `area_size_ft`, B4'ün açtığı
çift) ve `sphere`/`cylinder` satırları Tier-0 kanonunda zaten duruyor. Kaynak
`shape_type`/`shape_size` sütunlarını bu 8 satırda doldurmamış, ama metin
tek anlamlı. `verify_packs` bunu göremiyor: `range_ft` zaten "yazılı kural ile
`range_text`'ten türetiliyor" diye **unverifiable** sayılıyor (68 satır).

**Dağılım** *(2026-08-18'de ölçüldü — korpüste `Self (N …)` yazan başka belge yok)*

| Paket | Etkilenen kart |
|---|--:|
| `open5e-spells-that-dont-suck` | 8 (`Alter Weather`, `Arcane Shelter`, `Drink Life`, `Earth Forming`, `Earth Rumble`, `Eldritch Rift`, `Flickering Strikes`, `Glacial Orbs`) |
| **Toplam** | **8** |

**Kanıt.**
```sh
# flutter_app'ten — kaynakta parantezli sayı var, kartta ne range_ft ne area_size_ft
python3 - <<'EOF'
import json,glob,os,re,collections
pat=re.compile(r'self\s*\((.*?)\)',re.I); num=re.compile(r'(\d[\d,]*)[- ]?(?:foot|feet|ft|mile)',re.I)
packs={}
for p in glob.glob('assets/open5e_packs/*.pkg.json'):
    pk=json.load(open(p,encoding='utf-8'))
    packs[pk['metadata'].get('source_doc_slug')]={e['name']:e['attributes']
                                                  for e in pk['entities'].values() if e['type']=='spell'}
c=collections.Counter()
for p in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json'):
    doc=os.path.basename(os.path.dirname(p))
    if doc not in packs: continue
    for r in json.load(open(p,encoding='utf-8')):
        f=r['fields']; m=pat.search(f.get('range_text') or '')
        a=packs[doc].get(f['name'])
        if m and num.search(m.group(1)) and a and not a.get('range_ft') and not a.get('area_size_ft'):
            print(doc, f['name'], '|', f['range_text']); c[doc]+=1
print(dict(c))
EOF
# {'spells-that-dont-suck': 8}
```

**Seçenekler.**
1. **Parantezi oku** — `self (N-foot radius|dome|cube|cone|line)` kalıbını
   `area_shape_ref` + `area_size_ft`'e çevir (mil → ×5280). 8 kart; şekil sözcüğü
   beşi de kanonda var, `dome` yalnızca `sphere`e yuvarlanır (tek kart).
2. **Yalnız sayıyı kurtar** — şekil tahmini yapma, `area_size_ft` yerine
   `range_ft` yaz. Daha ucuz, ama "Self" bir menzil değil alan olduğu için
   `range_ft`'i yanlış anlamda kullanır.
3. **Kapsam dışı** — 8 kart, tek belge; sayı `description` metninde zaten
   okunuyor. Gerekçe §5.6'ya yazılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-spells-that-dont-suck-02 — malzeme metni "worth at least 665 gp" diyor, kart "Material Cost (gp): 0" yazıyor

| | |
|---|---|
| **Kapsam** | `open5e-spells-that-dont-suck` — 5 kart |
| **Checklist** | checklist A3 (kartın kendi başka alanıyla çelişen değer) |
| **Kategori / etki** | `spell` — `material_cost_gp`; **5 kartta** alan `0` yazıyor, aynı kartın `material_description`'ı fiyatı açıkça söylüyor |
| **Cause code (öneri)** | `S` — kaynağın `material_cost` sütunu bu satırlarda `'0'`; doğru değer kaynağın **başka** sütununda (`material_specified` metni). Mapper sadık kopyalıyor (`spell.dart:78-79`) |
| **Durum** | ❓ danışılacak |

**Bulgu.** `Devil Binding`'in malzemesi *"a vial of blood and an obsidian chalice
worth at least 665 gp"*, `Arcanist's Sword`'ünki *"…worth 250 gp"*. İkisinde de
`material_cost` sütunu `'0'`, dolayısıyla kart **Material Cost (gp): 0** — yani
"bedava" — diye okunuyor. Aynı belgede sütunu gerçekten dolduran 18 satır da var
(`Befriend` → `0.01`, `100`, `250`, `500`, `1500`), yani `0` burada "ücretsiz"
değil "girilmemiş" anlamına geliyor.

**Neden önemli.** Bu belge, korpüste `material_specified`'ı dolduran **iki**
belgeden biri (öbürü `deepm`) — yani alanın hiç ölçülmediği bir bölge.
`deepm`'de aynı desen zarar vermiyor: orada `material_cost` `null` kalıyor,
mapper'ın `if (cost != null)` koşulu alanı **hiç yazmıyor** ve kart sessiz
kalıyor (288 malzemeli kartın **0**'ında `material_cost_gp == 0`). Zarar yalnız
sütunun sıfırla doldurulduğu bu belgede oluşuyor: yazılmamış bir değerle
"masrafsız" iddiası arasındaki fark, pahalı bileşenli büyülerde doğrudan oyun
kararı.

**Dağılım** *(2026-08-18'de ölçüldü)*

| Paket | `material_cost_gp == 0` **ve** metinde fiyat |
|---|--:|
| `open5e-spells-that-dont-suck` | 5 (`Arcanist's Sword`, `Devil Binding`, `Divine Temple`, `Sparking Shot`, `Wayfinding`) |
| `open5e-deepm` | 0 (sütun `null`, alan hiç yazılmıyor) |
| **Toplam** | **5** |

**Kanıt.**
```sh
# flutter_app'ten — kartta 0, kartın kendi malzeme metninde fiyat
python3 - <<'EOF'
import json,glob,re,collections
pat=re.compile(r'worth (?:at least )?([\d,]+(?:\.\d+)?)\s*(gp|gold|sp|cp|pp)\b', re.I)
c=collections.Counter()
for p in glob.glob('assets/open5e_packs/*.pkg.json'):
    pk=json.load(open(p,encoding='utf-8'))
    for e in pk['entities'].values():
        if e['type']!='spell': continue
        a=e['attributes']
        if a.get('material_cost_gp')==0 and pat.search(a.get('material_description') or ''):
            print(pk['package_name'], e['name'], '|', a['material_description']); c[pk['package_name']]+=1
print(dict(c))
EOF
# {'open5e-spells-that-dont-suck': 5}
```

**Seçenekler.**
1. **Sıfırı yazma** — `if (cost != null && cost > 0)`; 63 kartta alan boşalır,
   5 çelişkili kart susar. En küçük diff, ama gerçekten bedava malzemeyi de
   susturur (bu belgede öyle bir satır ayırt edilemiyor).
2. **Metinden oku** — `material_description` içindeki `worth (at least) N gp`
   kalıbını sütun `0`/`null` iken kullan; 5 kartta doğru fiyat, `cp`/`sp`
   çevrimi gerekir (`Sparking Shot` 1 cp = 0.01 gp — kaynağın kendi `Befriend`
   satırı bu çevrimi zaten yapıyor).
3. **Yukarı bildir / kapsam dışı** — kusur kaynağın sütununda; 5 kart için
   gerekçe §5.6'ya yazılır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

### F-pass0-15 — `spell.effects`'in ⚪ gerekçesinin ikinci yarısı ölçümle uyuşmuyor: kaynakta zar sütunu var

| | |
|---|---|
| **Kapsam** | `pass0` — yazılı gerekçe korpüs geneli; ölçüm 8 belgede **303** satır |
| **Checklist** | checklist C8 (boş kalan alanın yazılı sebebi doğru mu) |
| **Kategori / etki** | `spell` — `effects` 0/1.297; gerekçenin "yukarıda doldurulacak yapılandırılmış hasar satırı yok" yarısı **303 kartta** yanlış |
| **Cause code (öneri)** | `A` — alanın gerçek sebebi uygulama tarafı ("`domain/`/`application/` içinde okuyucusu yok", M3'ün kapsam sınırı) ve o yarı **ayakta**; düzeltilmesi gereken şey verdict değil, yazılı gerekçe |
| **Durum** | ❓ danışılacak |

**Bulgu.** `open5e_content_audit.md` §5.8, `spell.effects`'i ⚪ ile kapatırken iki
sebep yazıyor: *"editörü olan ama `domain/` ya da `application/` içinde okuyucusu
olmayan canlı bir alan"* **ve** *"onu dolduracak yapılandırılmış hasar satırı
yukarıda yok"*. İkincisi ölçülünce tutmuyor: v2 `Spell.json` bir `damage_roll`
sütunu taşıyor ve gönderilen 8 büyü belgesinde **303 satırda** dolu
(`deepm` 116, `spells-that-dont-suck` 94, `a5e-ag` 46, `toh` 25, `deepmx` 9,
`wz` 8, `kp` 4, `open5e` 1). Değerlerin **285'i** düpedüz zar ifadesi
(`2d6`, `4d8`, `1d8 + 4`); yanına `damage_types` (85 satır bu pakette) ve
`saving_throw_ability` sütunları da geliyor — yani tipli bir efekt satırının
üç bileşeninden üçü de kaynakta duruyor.

**Neden önemli.** Bu, `monster.lair_action_refs`'in §5.8'de "**Reason was
wrong**" diye düzeltilen satırıyla aynı desen: verdict doğru olabilir ama
gerekçe ölçüme dayanmıyorsa bir sonraki faz onu "zaten baktık" diye atlar.
Burada verdict muhtemelen ⚪ kalır — okuyucu yokluğu tek başına yeterli sebep —
ama gerekçenin "veri yok" yarısı silinmeli, yoksa `effects` bir okuyucu
kazandığı gün kimse kaynağa yeniden bakmaz.

**Dağılım** *(2026-08-18'de ölçüldü — yalnız gönderilen büyü belgeleri)*

| Belge | `damage_roll` dolu |
|---|--:|
| `deepm` | 116 / 515 |
| `spells-that-dont-suck` | 94 / 180 |
| `a5e-ag` | 46 / 371 |
| `toh` | 25 / 91 |
| `deepmx` | 9 / 64 |
| `wz` | 8 / 43 |
| `kp` | 4 / 31 |
| `open5e` | 1 / 2 |
| **Toplam** | **303 / 1.297** |

**Kanıt.**
```sh
# flutter_app'ten — gönderilen büyü belgelerinde damage_roll doluluğu
python3 - <<'EOF'
import json,glob,os,re,collections
ship={'a5e-ag','deepm','deepmx','kp','open5e','spells-that-dont-suck','toh','wz'}
tot=collections.Counter(); n=collections.Counter(); vals=collections.Counter()
for p in glob.glob('../open5e-api-staging/data/v2/*/*/Spell.json'):
    doc=os.path.basename(os.path.dirname(p))
    if doc not in ship: continue
    rows=[x['fields'] for x in json.load(open(p,encoding='utf-8'))]
    n[doc]=len(rows)
    for f in rows:
        v=(f.get('damage_roll') or '').strip()
        if v: tot[doc]+=1; vals[v]+=1
print({d:f'{tot[d]}/{n[d]}' for d in sorted(ship)}, 'toplam', sum(tot.values()))
print('saf zar ifadesi:', sum(c for v,c in vals.items() if re.fullmatch(r'\d+d\d+(\s*[+-]\s*\d+)?', v)))
EOF
# toplam 303, saf zar ifadesi 285
# okuyucu yarısı: grep -rn "effects" lib/domain lib/application --include=*.dart | grep -v spellEffect
```

**Seçenekler.**
1. **Gerekçeyi düzelt** — §5.8'in `spell.effects` satırından "yapılandırılmış
   hasar satırı yok" yarısını çıkar, yerine ölçümü yaz (303/1.297 `damage_roll`),
   verdict ⚪ kalsın; sebep tek ayak üstünde ama **doğru** ayakta durur.
   Kod değişmez.
2. **Alanı aç** — `damage_roll` + `damage_types` + `saving_throw_ability`
   üçlüsünden tipli efekt satırı üret. Okuyucu hâlâ yok, yani M3'ün kapsam
   sınırını genişletir; ölçülmesi gereken ilk şey `spellEffectList`'in şeması.
3. **Aynen bırak** — ⚪ verdict'i değişmediği için gerekçenin yarısı yanlış
   kalsın; kayıt "kabul edildi" diye kapanır.

**Karar.** — · **Tarih:** — · **Kapatan:** —

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
