# Paket İçerik Uygunluk Taraması — Bulgular (Stage F2)

**Ölçüt:** `pack_conformance_checklist.md` · **Süreç:** `pack_conformance_plan.md`
· **Yol haritası:** `open5e_content_audit.md`

> **Durum: tarama başlamadı.** Checklist onaylanınca Pass 0 ile açılır.
> Bu dosya o ana kadar boş bir defter — formatı ve sayaçları hazır.

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
Kapsam ya paketin kısa adı, ya `builtin`, ya da korpüs geneli için `pass0`.

## Durum sözlüğü

| Durum | Anlam |
|---|---|
| 🔎 **açık** | Bulundu, yazıldı, henüz danışılmadı |
| ❓ **danışılacak** | Karar senden bekleniyor — seçenekler yazılı |
| 🛠 **faz dosyalandı** | Karar "düzelt"; iş `open5e_content_audit.md` §6'da bir faz |
| ✅ **kapandı** | Düzeltildi veya gerekçesi yazıldı; kapatan faz/commit belirtildi |
| ⚪ **kapsam dışı** | Bilinçli olarak yapılmayacak; sebebi yazılı |
| ❌ **geçersiz** | Yanlış alarm; neden yanlış olduğu yazılı (silinmez, kayıt kalır) |

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

## Bulgu formatı

Her bulgu aşağıdaki şablonla yazılır. Şablonun kendisi bir örnek taşıyor —
**gerçek bir bulgu değil**, yalnızca nasıl doldurulacağını göstermek için.

<details>
<summary><b>Şablon + örnek (gerçek bulgu değildir)</b></summary>

### F-örnek-00 — `subclass.features` üç kartta boş

| | |
|---|---|
| **Kapsam** | `open5e-örnek` |
| **Checklist** | C1 (class/subclass seviye tablosu) |
| **Kategori / etki** | `subclass` — 76 varlığın 3'ü |
| **Cause code (öneri)** | `M` — dosya yükleniyor, mapper yazmıyor |
| **Durum** | ❓ danışılacak |

**Bulgu.** Üç subclass `parent_class_ref`'i doğru çözüyor ama `features` listesi
boş; sihirbazda seçilebiliyor, seçilince hiçbir şey vermiyor.

**Kanıt.**
```
audit_packs --packs /tmp/one --only subclass  →  features 73/76
örneklem #12, #40, #57: features: []
```

**Neden önemli.** Denetimin en başta bulduğu hatanın aynısı (101 subclass /
0 grant), üç satırlık kalıntısı.

**Seçenekler.**
1. **Düzelt** — `ClassFeatureItem.json`'da bu üç subclass'ın satırları var mı diye
   bakılır; varsa mapper eşleşmesi düzeltilir. Yeni faz gerekir.
2. **Gerekçe yaz** — kaynakta gerçekten yoksa ⚪ olarak §5.2'ye işlenir.
3. **Kapsam dışı** — üç kart için maliyet yüksekse yazılı kararla bırakılır.

**Karar.** *(seninkini buraya)* · **Tarih:** — · **Kapatan:** —

</details>

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
| 4 | 85 paketli büyü hiçbir yoldan görünmüyor | U2 ölçümü | Açık |
| 5 | `magic-item.cost_gp` 1.063/1.063 = `0.00` | §5.6 | ⚪ kaynakta sütun yok |
| 6 | D1 publish — `DMT_WORKER_URL` + `ADMIN_TOKEN` CI secret'ı, upload hiç çalışmadı | §6 Stage D | Açık |
