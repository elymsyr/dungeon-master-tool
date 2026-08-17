# Paket İçerik Uygunluk Taraması — Bulgular (Stage F2)

**Ölçüt:** `pack_conformance_checklist.md` · **Süreç:** `pack_conformance_plan.md`
· **Yol haritası:** `open5e_content_audit.md`

> **Durum: tarama başlamadı.** Format **F2'de onaylandı (2026-08-17)** —
> yazılarak değil, gerçek bir ölçümü şablona **doldurarak** (§ "Kuru çalışma").
> Defterin kendisi `python3 tool/check_findings.py` ile denetleniyor: her kaydın
> checklist maddesi, etkilenen varlık sayısı, kanıt bloğu, cause code'u ve
> seçenekleri var mı — ve üç özet sayaç gerçek kayıtlarla aynı şeyi söylüyor mu.
> Bulgular F3'te, Pass 0 ile gelmeye başlar.

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
ile `mappers/*.dart` içine iner. Bu taramanın **E / F / G** grubu maddeleri
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
| 0 | 0 | 0 | 0 | 0 | 0 | **0** |

**Checklist maddesine göre** *(bulgu geldikçe doldurulur)*

| Madde | Bulgu | Madde | Bulgu | Madde | Bulgu |
|---|--:|---|--:|---|--:|
| A1 | 0 | B1 | 0 | C1 | 0 |
| A2 | 0 | B2 | 0 | C2 | 0 |
| A3 | 0 | B3 | 0 | C3 | 0 |
| A4 | 0 | B4 | 0 | C4 | 0 |
| A5 | 0 | B5 | 0 | C5 | 0 |
| D1 | 0 | E1 | 0 | C6 | 0 |
| D2 | 0 | E2 | 0 | C7 | 0 |
| D3 | 0 | E3 | 0 | C8 | 0 |
| F1 | 0 | F3 | 0 | G1 | 0 |
| F2 | 0 | F4 | 0 | G2 | 0 |
| | | | | G3 | 0 |

**Pakete göre**

| Kapsam | Bulgu | Kapsam | Bulgu |
|---|--:|---|--:|
| `pass0` | 0 | `open5e-vom` | 0 |
| `builtin` | 0 | `open5e-ccdx` | 0 |
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

*(henüz yok)*

### Dalga 0 — built-in SRD

*(henüz yok)*

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
