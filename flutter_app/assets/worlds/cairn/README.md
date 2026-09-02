# Cairn 2e → Content Pack Aktarım Planı

Kaynak: <https://github.com/yochaigal/cairn> (yerel klon: `/home/eren/GitHub/cairn`)
Hedef: **iki content pack** (`.pkg.json`) + ileride `adventures/` içeriğinden dünyalar.

Bu dizin **authoring kaynağıdır**, uygulamaya paketlenmez —
`pubspec.yaml`'da `assets/worlds/` bloğu yorumda ([pubspec.yaml](../../../pubspec.yaml) §assets)
ve `cairn` dizini `assets/worlds/manifest.json`'a **yazılmaz**, dolayısıyla
`bundled_worlds_blueprint_test.dart` ve `BundledWorldsInstaller` bu dizini görmez.

---

## 0. Neden pack, neden dünya değil

Repo taraması sonucu: **oynanabilir macera sıfır.**

| Görünen | Gerçek |
|---|---|
| `adventures/originals/` (57 dosya) | 57/57 sadece `redirect_to:` frontmatter — gövde yok |
| `adventures/first-party/` (4 dosya) | 4/4 aynı şekilde redirect |
| `adventures/conversions/` (61 dosya, 9358 satır) | Üçüncü tarafın ticari macerasına yamalı çevirme notu; oda içeriği başka üründe |
| `localization/` (19 dosya) | 3'ü gerçek çeviri (tr / pt-BR / ru), 16'sı redirect |
| `img/backgrounds/` (31 JPG) | 1e dönemi isimler (alchemist, beggar…), 2e'nin 20 background'ıyla eşleşmiyor |

Elde kalan: **bir kural sistemi + büyük bir referans kütüphanesi + ima edilmiş bir setting (Vald).**
Bu tam olarak `srd_core` / `open5e-*` paketlerinin şekli → **content pack**.

## 1. Paket bölümü: `cairn-2e-core` + `cairn-community`

Bölme sebebi estetik değil, **atıf hukuku**. Repo iki farklı atıf rejimi taşıyor.

| Pack | Kaynak | Lisans / atıf |
|---|---|---|
| **`cairn-2e-core`** | `second-edition/**`, `resources/monsters/`, `resources/hirelings.md` | Tek yazar: Yochai Gal, CC BY-SA 4.0 — tek atıf satırı |
| **`cairn-community`** | `resources/more-relics.md`, `more-spellbooks.md`, `more-equipment.md` | Topluluk katkısı, **kaynak başına** `### From [X](url)` atfı; "copied with permission" |

Daha fazla bölmek (bestiary'yi ayırmak vb.) **şu an gereksiz** — toplam boyut
tahminen <2 MB, open5e paketlerinin çok altında. Boyut sorun olursa
`cairn-2e-bestiary` sonradan ayrılır.

### Lisans notları — bağlayıcı

- Kök `LICENSE` **GPLv3'tür ama sadece Jekyll teması içindir** (dosyanın kendi
  ifadesiyle `_config.yml` / `_data/` / `_drafts/` hariç). Oyun içeriğinin
  lisansı değildir; karıştırma.
- Oyun metni: **CC BY-SA 4.0** — `README.md` ve `resources/third-party-content.md`
  ("You do **not** need permission…") ile teyitli.
- **ShareAlike zincirleme:** türetilmiş paket de CC BY-SA 4.0 olmak zorunda.
  `metadata.license = "cc-by-sa-40"`.
- **Görseller aktarılmayacak.** README yalnızca "the full text" için lisans
  beyan ediyor; `img/` için ayrı beyan yok. Belirsiz lisanslı 89 MB'ı paketleme.

## 2. Kategori eşlemesi (5e template, yeni şema yazılmıyor)

Şema: `builtin-dnd5e-default-v2` (39 Tier-0 + 22 Tier-1 + 15 Tier-2 = 76 kategori).
Alan adları [content.dart](../../../lib/domain/entities/schema/builtin/content.dart) /
[dm.dart](../../../lib/domain/entities/schema/builtin/dm.dart) sözleşmesidir —
**şemada olmayan anahtar sessizce kaybolur.**

| Cairn içeriği | Adet | Slug | Taşıyıcı alanlar |
|---|---|---|---|
| Canavarlar (`resources/monsters/`) | 145 | `monster` | `hp_average`, `ac`, `stat_block`, `traits_md`, `action_refs`, `tags_line` |
| Canavar saldırıları | ~170 | `creature-action` | `damage_dice`, `is_attack`, `description` |
| Backgrounds | 20 | `background` | `description`(md), `default_inventory_refs`, `starting_gold_gp` |
| Zırh (marketplace) | 5 | `armor` | `base_ac`, `cost_gp` |
| Silah (marketplace) | 6 | `weapon` | `damage_dice`, `cost_gp`, `is_melee` |
| Gear (marketplace) | ~50 | `adventuring-gear` | `cost_cp`, `consumable`, `description` |
| Transport | 4 | `mount` / `vehicle` | `cost_gp` |
| Relic (reliquary) | 46 | `magic-item` | `charges_max`, `charge_regain`, `effects` |
| Relic (more-relics) | 129 | `magic-item` | ↑ (community pack) |
| Spellbook (core d100) | 100 | `spell` | `description`, `range_type` |
| Spellbook (d666) | 216 | `spell` | ↑ (community pack) |
| Hirelings | 12 | `hireling` | `daily_cost_cp`, `skilled` |
| Upkeep & Recovery | ~10 | `service` | `kind`, `cost_cp`, `availability` |
| Core rules, procedures, seeds, Vald, tablolar | ~2.500 satır | `lore` | `pages[]` (markdownList) |

**Kullanılmayan 5e kategorileri:** `class`, `subclass`, `species`, `subspecies`,
`feat`, `trait`, `pack`, `starter-bundle`. Cairn'de karşılığı yok — boş bırak,
uydurma.

### 2.1 Sayısal dönüşüm — yazarın kendi tablosu

`resources/5e-notes.md` resmî 5e→Cairn matematiğini veriyor. **Tersine çevirip**
kullanıyoruz; bu sayede uydurma değil, kaynağın kendi kuralı oluyor.

```
STR  → stat_block.STR      (Cairn 3-18, 5e ability score ile aynı aralık)
DEX  → stat_block.DEX
WIL  → stat_block.WIS      (5e-notes: WIL = max(WIS, CHA))
HP   → hp_average          (Cairn "Hit Protection", birebir)

Armor → ac      0 → 10  |  1 → 13  |  2 → 16  |  3 → 20
                (5e-notes'un AC→Armor eşiklerinin tersi: ≤12 / 13+ / 16+ / 20+)
```

`CON` / `INT` / `CHA`: **yazılmaz.** Cairn'de karşılıkları yok; şema neutral
değerini kullanır. Ham stat satırı her canavarın `description` alanına
**birebir** yazılır — dönüşümde kaybolan hiçbir şey olmasın.

`_detachment_` (23 canavar) → `tags_line: "detachment"` + `traits_md`'ye kural
notu. `_enhanced_` / `_impaired_` hasar notları `traits_md`'ye birebir.

### 2.2 Bilinçli kabuller (karar verildi, tartışma kapandı)

1. **Spellbook → `spell`, `magic-item` değil.** Cairn'de spellbook envanter
   slotu kaplayan bir nesnedir, ama 5e template'inde slot sistemi zaten yok —
   iki tarafta da o mekanik kaybolur. Ayrı kategori olmak arama/filtreleme
   kazandırır ve 175 relic'i 316 spellbook'la karıştırmaz. `spell.level` boş
   bırakılır (Cairn'de seviye yok).
2. **Background'ın zorunlu 5e alanları boş kalır.** `granted_skill_refs`,
   `ability_score_options`, `asi_distribution_options`, `origin_feat_ref` şemada
   `required_: true` ama Cairn'de karşılığı yok. Converter zorunluluğu **denetlemiyor**
   (sadece bilinmeyen alanı ve çözülemeyen ref'i kırıyor), dolayısıyla `--check` temiz geçer.
   ⚠️ **Faz 2'de doğrulanacak:** karakter yaratma sihirbazı `origin_feat_ref == null`
   ile patlıyor mu? Patlıyorsa bu kabul geri alınır ve background'lar `lore` +
   `adventuring-gear` ikilisine düşer.
3. **Background'ın iki d6 tablosu** typed bir eve sahip değil → `description`
   içinde markdown tablosu olarak birebir kalır. Bazıları gerçek mekanik veriyor
   (spellbook, bağışıklık, +1 Armor) — bu yüzden atlanamaz.
4. **`lore` / `hireling` / `service` Tier-2'dir** ve normalde pack ile
   tohumlanmaz. `cold-bounty-5e.pkg.json` bunun çalıştığını kanıtlıyor
   (`npc`/`location`/`lore` içeriyor). Kural metninin başka evi yok.
5. **Türkçe 1e SRD** (`localization/first-edition/turkish.md`, 1022 satır,
   çeviri: Deniz Ege Altınçiçek) **v1 kapsamına girmiyor** — 1e içeriği, 2e ile
   background'ları örtüşmüyor. Ama terim sözlüğü olarak `app_tr.arb` için
   kaydedilsin (ayrı iş).

## 3. Boru hattı — yeni araç minimumda

Ponytail: **`convert_blueprint.dart` yeniden kullanılıyor.** O bir *dünya* aracı
ama ürettiği `.pkg.json` wire formatı bir *paketle birebir aynı*
(`{package_name, metadata, entities}`), ve tüm doğrulamayı (şema dışı alan,
çözülemeyen ref, eksik medya) bedava veriyor. Ayrı bir pack emitter yazılmıyor.

```
cairn/ markdown
   │
   ├─ flutter_app/tool/content/cairn/build_cairn.dart   ← YENİ, tek dosya
   │     markdown → world-blueprint.json
   ▼
assets/worlds/cairn/<pack>/{manifest.json, world-blueprint.json}
   │
   ├─ dart run tool/content/convert_blueprint.dart --dir assets/worlds/cairn/<pack> --check
   ▼
   └─ dart run tool/content/convert_blueprint.dart --dir assets/worlds/cairn/<pack>
         → <slug>.pkg.json
   │
   ├─ cp → assets/open5e_packs/<slug>.pkg.json  +  manifest.json girdisi
   ▼
   dart run tool/catalog_publish/bin/build_catalog.dart     → assets/first_party/manifest.json
   dart run tool/catalog_publish/bin/publish_catalog.dart --worker <url>
```

> `ponytail:` `assets/open5e_packs/` dizin adı artık yanlış (içinde zaten
> open5e olmayan `dnd5e-srd.pkg.json` var). Yeniden adlandırmak
> `bundled_packs_bootstrap.dart` + `assets_pack_installer.dart` +
> `build_catalog.dart` + pubspec'i dokunmayı gerektirir — kazancı yok.
> Ad karışıklığı sorun olursa o zaman değiştirilir.

`generate_monster_json.rb` (repo kökünde) **kullanılmıyor**: pozisyonel
(`markdown[4]`, `markdown[6..-7]`), HTML üretiyor, stat satırını hiç
ayrıştırmıyor. Formatı doğrudan parse etmek daha kısa.

## 4. Parser sözleşmesi — format doğrulandı

Aşağıdaki sayılar **ölçüldü**, tahmin değil.

### Canavar (`resources/monsters/*.md`) — 145/145 tek regex'le parse oluyor

```
---frontmatter---
# <Ad>

<N> HP, [<N> Armor, ]<N> STR, <N> DEX, <N> WIL[, <silah> (<dX>)]…[, _detachment_]

- <madde>
- **<Yetenek>**: <metin>
```

Ölçüm: 53 dosyada Armor var · 23'ünde `_detachment_` · 4'ünde silah yok ·
22'sinde birden fazla silah. Hasar ifadeleri: `d6`(36) `d8`(33) `d10`(26)
`d8+d8`(16) `d6+d6`(14) `d12`(14) `d10+d10`(8), ayrıca `, _blast_` ve `, bulky`
ekleri. Satır şekilleri 11 varyanta düşüyor, hepsi aynı gramerin alt kümesi.

`bestiary.md` (84 canavar) **kullanılmıyor** — `resources/monsters/`'ın öz alt
kümesi; oradan sadece d20 "Monster Categories" tablosu `lore` sayfası olarak alınır.

### Background (`second-edition/backgrounds/*.md`) — 20/20 aynı yapı

```
# <Ad>
> <flavor blockquote>
## Names            → 10 isim, virgüllü
## Starting Gear    → madde listesi (ilk madde genelde "3d6 Gold Pieces")
## <soru> Roll 1d6: → markdown tablo
## <soru> Roll 1d6: → markdown tablo
```

Ölçüm: 20 dosyanın 20'sinde tam olarak 4 adet `##` başlığı, ilki `Names`,
ikincisi `Starting Gear`.

### Diğer

| Dosya | Yapı | Adet |
|---|---|---|
| `marketplace.md` | 6 `##` bölümü, 95 tablo satırı, `\| Ad (etiket) \| fiyat \|` | ~90 |
| `reliquary.md` | `## <Ad>[, <N> charges/uses][, +N Armor][ (dX)]` + madde + `- **Recharge**:` | 46 |
| `spellbooks.md` | `\| **N** \| **Ad** \| Etki. _Kitabın tuhaflığı._ \|` | 100 |
| `more-spellbooks.md` | d666 index + detay bölümleri | 216 |
| `hirelings.md` | `## <Ad> (<N>/day)` + stat satırı + gear maddeleri | 12 |
| `more-relics.md` | `### From [Kaynak](url)` grupları altında relic gramerı | 129 |

Etiket sözlüğü (her yerde geçerli): `_petty_` = 0 slot, `_bulky_` = 2 slot,
`(N uses)`, `(fits N)`, `(dX)` hasar.

## 5. Fazlar

| # | İş | Çıktı | Doğrulama |
|---|---|---|---|
| 0 | `flutter_app/tool/content/cairn/build_cairn.dart` iskeleti + `manifest.json`'lar + eşleme tablosunun koda dökümü | 2 boş blueprint | `--check` temiz (0 entity) |
| 1 | **145 canavar + creature-action'lar** | `monster`, `creature-action` | `--check` + spot: acolyte / air-elemental / aranea birebir |
| 2 | **20 background** + marketplace (armor/weapon/gear/transport) | `background`, `armor`, `weapon`, `adventuring-gear`, `mount`, `vehicle` | `--check` + ⚠️ kabul #2 doğrulaması (chargen wizard) |
| 3 | 46 relic + 100 spellbook | `magic-item`, `spell` | `--check` |
| 4 | Kural metni, Vald, Bonds/Omens/trait tabloları, seeds, hirelings, upkeep | `lore`, `hireling`, `service` | `audit_coverage.py` ≥ %95 |
| 5 | **`cairn-community`**: more-relics / more-spellbooks / more-equipment, kaynak başına atıf | ikinci `.pkg.json` | `--check` + her `### From` bloğunun atfı entity `source`'unda |
| 6 | `assets/open5e_packs/` + `build_catalog` + `publish_catalog` | katalog girdisi | `flutter analyze && flutter test` |
| 7 | *(sonra)* `adventures/` → dünyalar, paketleri `links` ile bağla | world manifest'lerinde `"links": [{"slug": "cairn-2e-core"}]` | katalogda `requires` görünmeli |

Faz 1 tek başına kullanılabilir bir paket üretir; oradan sonrası additive.

## 6. Doğrulama — ikisi de zorunlu

[tool/content/README.md](../../../../tool/content/README.md) §5 kuralı burada da geçerli.

```bash
cd flutter_app
dart run tool/content/convert_blueprint.dart --dir assets/worlds/cairn/cairn-2e-core --check
# içerik sadakati: kaynak markdown'ları tek dosyada birleştirip
cat /home/eren/GitHub/cairn/{second-edition/**,resources/monsters/*}.md > /tmp/cairn-source.txt
python tool/content/audit_coverage.py /tmp/cairn-source.txt assets/worlds/cairn/cairn-2e-core
```

**Değişmez kural (README §0):** kaynaktaki her cümle pakete girer. Özetleme,
yeniden yazma yok. Kaynak bir alanı söylemiyorsa alan **boş bırakılır**, tahmin
edilmez. `--check` şemayı doğrular, **sadakati doğrulamaz** — kapsam denetimi
bu yüzden zorunlu.

## 7. Faz 7 önizlemesi — adventures nasıl dünya olur

`adventures/` içindeki 61 conversion **kaynak macerayı içermiyor**; dünya
üretmek için asıl PDF/metin ayrıca temin edilmeli. Temin edildiğinde akış
standart: [tool/content/README.md](../../../../tool/content/README.md) +
[WORLD_CONTENT_ORDER.md](../../../../tool/content/WORLD_CONTENT_ORDER.md).

Paket bağı `manifest.json` üzerinden kurulur — `build_catalog.dart`
`metadata.links`'i katalog girdisinde `requires`'a çeviriyor:

```json
{ "slug": "…", "system": "cairn",
  "links": [{ "slug": "cairn-2e-core" }] }
```

Böylece dünya kurulurken Cairn paketleri **import edilmiş** gelir; canavar/relic
tekrar yazılmaz, referans verilir (WORLD_CONTENT_ORDER §Tier-1 durum 1).

## 8. Kaynak envanteri (referans)

Toplam 29.366 satır markdown. Kullanılabilir:

**145** canavar · **20** background · **46**+**129** relic · **100**+**216**
spellbook · **~90** marketplace satırı · **~200** ek ekipman · **12** hireling ·
20 Bond · 20 Omen · 8×d10 karakter özelliği tablosu · seed/naming üreteçleri ·
Vald (251 satır) · 3 tam çeviri (tr / pt-BR / ru).

Kullanılmayan: `adventures/` (redirect + üçüncü taraf delta), `scripts/`
(LaTeX/PDF boru hattı), `img/` (lisans beyanı yok), `fonts/` (OFL, gereksiz),
`first-edition/` + `barebones/` (ayrı sürümler), `hacks/third-party/`.
