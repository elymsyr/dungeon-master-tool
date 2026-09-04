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
| Backgrounds | 20 | `background` | `description`(md) — bkz. §2.2/6 |
| Zırh (marketplace) | 6 | `armor` | `base_ac`, `cost_gp` |
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
STR  → stat_block.STR      (ham değer, dönüştürülmeden — aşağıya bak)
DEX  → stat_block.DEX
WIL  → stat_block.WIS      (5e-notes: WIL = max(WIS, CHA))
HP   → hp_average          (Cairn "Hit Protection", birebir)

Armor → ac      0 → 10  |  1 → 13  |  2 → 16  |  3 → 20
                (5e-notes'un AC→Armor eşiklerinin tersi: ≤12 / 13+ / 16+ / 20+)
```

⚠️ **Ham stat yazılıyor, ama "aynı ölçek" olduğu için değil.** `5e-notes.md`
tersi bir şey söylüyor: *"add 10 to the equivalent 5e modifier"* — yani Cairn
14 STR = 5e **+4 modifier** = 5e 18–19 score. Sayı aralığı aynı, anlamı değil.
Formülü tersine çevirmek (`2×cairn − 10`) gerçek veride kırılıyor:
`bronze-construct`/`golem`/`skeleton` 0 WIL taşıyor (→ −10), `cobblehounds`
1 DEX (→ −8), `red-dragon` 18 STR (→ 26) — şemanın kabul etmeyeceği değerler.
Bu yüzden ham değer yazılıyor: **uygulanabilir tek seçenek bu**, "iki taraf
aynı şeyi ölçüyor" olduğu için değil.

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
   ✅ **Faz 2'de doğrulandı (2026-09-03).** Wizard'ın üç `origin_feat_ref`
   okuyucusunun üçü de null-güvenli
   ([feats_step.dart:122](../../../lib/presentation/screens/characters/wizard/steps/feats_step.dart#L122),
   [character_creation_wizard_screen.dart:816](../../../lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart#L816)
   ve `:1569`), resolver'ın background pass'i de (`asi.isNotEmpty` /
   `allowed.isNotEmpty` / `variantGroup.isNotEmpty` kapıları). Kanıt sadece
   okuma değil: paket `assets/open5e_packs/`e kopyalanıp
   `wizard_pack_families_test.dart` koşuldu — `background origin_feat_ref
   çözülür` ve `paket seçimleriyle taslak commit edilir` (buildSeedFields +
   `CharacterResolver.resolve`) **geçti**. Kabul ayakta; background'lar
   `background` olarak kalıyor.
3. **Background'ın iki d6 tablosu** typed bir eve sahip değil → `description`
   içinde markdown tablosu olarak birebir kalır. Bazıları gerçek mekanik veriyor
   (spellbook, bağışıklık, +1 Armor) — bu yüzden atlanamaz.
4. **`lore` / `hireling` / `service` Tier-2'dir** ve normalde pack ile
   tohumlanmaz. `cold-bounty-5e.pkg.json` bunun çalıştığını kanıtlıyor
   (`npc`/`location`/`lore` içeriyor). Kural metninin başka evi yok.
5. **Zırh `base_ac` ikiye ayrılır.** Kaynak iki farklı şey söylüyor:
   `(+1 Armor)` bir **bonus** (Shield / Helmet / Gambeson → `base_ac: 1`),
   `(N Armor, _bulky_)` bir **gövde zırhı** (Brigandine/Chainmail/Plate →
   `acForArmor()` eşiği 13/16/20). Aynı alana iki anlam yazmak marketplace'i
   bozmuyor: SRD'nin kendi Shield satırı da `base_ac: 2`yi bonus olarak
   taşıyor ([content.dart](../../../lib/domain/entities/schema/builtin/content.dart)
   `_armorCategory`, `min: 0` yorumu bunu açıkça söylüyor).
6. **Background'ın `starting_gold_gp` ve `default_inventory_refs` alanları
   boş.** 20/20 background "3d6 Gold Pieces" diyor; alan `integer` ve
   background'da `starting_gold_dice` yok (o class'ta) — ortalama yazmak sayı
   uydurmak olurdu. `default_inventory_refs` yalnız
   `adventuring-gear|ammunition|armor|pack|tool|weapon` hedefi kabul ediyor,
   Starting Gear maddeleri ise eşya *adı değil*: ad + satır içi mekanik
   ("Leech (restores 1 STR, 3 uses)"), biri iki satıra sarılmış tam bir büyü
   metni (half-witch), biri `vehicle` (mountebank'in Cart'ı — alanın kabul
   etmediği kategori), biri hedefi olmayan tablo göndermesi ("Bow (see table)",
   fletchwind). Ref'lemek ~110 yeni eşya kartı basmak, yarısını marketplace
   satırlarının farklı yazımıyla ikizlemek ("Crossbow (d8, _bulky_)" vs
   "Crossbow (d8 damage, _bulky_)") ve adı mekanikten ayırmak için kaynağın
   vermediği bir sezgi yazmak demek. Liste `description`'da birebir duruyor →
   kayıp yok. Faz 7'de Cairn dünyaları gelip oyuncu gerçekten Cairn karakteri
   yarattığında ref'lenir.
7. **Türkçe 1e SRD** (`localization/first-edition/turkish.md`, 1022 satır,
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

### 4.1 Kapsam denetimi — ölçüldü

Her iki paket de `audit_coverage.py`'nin %95 eşiğini geçiyor. Eşik altında kalan
cümlelerin **hepsi** cümle bölücünün tablo artıkları (birden çok tablo satırını tek
"cümle" sanıyor; satırların kendisi tek tek entity `description`'larında duruyor) —
spot kontrolle doğrulandı.

| Paket | Cümle | Eşik altı | Kapsam |
|---|---|---|---|
| `cairn-2e-core` | 3991 | 16 | **%99.6** |
| `cairn-community` | 716 | 15 | **%97.9** |

```bash
cat /home/eren/GitHub/cairn/{resources/monsters/*,second-edition/backgrounds/*,\
    second-edition/players-guide/*,second-edition/wardens-guide/*,resources/hirelings}.md \
  > /tmp/cairn-core-source.txt
python3 tool/content/audit_coverage.py /tmp/cairn-core-source.txt assets/worlds/cairn/cairn-2e-core

cat /home/eren/GitHub/cairn/resources/more-{relics,spellbooks,equipment}.md \
  > /tmp/cairn-community-source.txt
python3 tool/content/audit_coverage.py /tmp/cairn-community-source.txt assets/worlds/cairn/cairn-community
```

**`bestiary.md` gerçekten alt küme mi — denetlendi.** 84 canavarın 84'ü de
`resources/monsters/`'ta var (isim farkı yok). 15 satır birebir örtüşmüyor, ama
farkların tamamı imla/noktalama: `arachnides`/`arachnids`, `liquifies`/`liquefies`,
`shortsword`/`short sword`, `d4`/`1d4`, `beak (d10) or claws`/`beak (d10), claws`.
İçerik kaybı yok; `resources/monsters/` kanonik alınıyor (canavar sayısı 145 vs 84,
ve `or` ayrımı saldırı bölmesini besliyor). Core kapsamındaki 4 sıfır-isabet cümle
bunlar — kanonik yazımıyla pakette duruyorlar.

### 4.2 Faz 4'te ek iş çıkmadı

`lore` 27 (players-guide 4 + Vald, wardens-guide 19 + Vald, `Monster Categories`),
`hireling` 12 ve `service` 6 zaten Faz 1-2'de bağlanmıştı; Faz 4 bunların **denetimi**
oldu. Kaynakta karşılıksız kalan tek dosya `second-edition/tools/character-generator.md`
— içeriği bir `<iframe>`, metin yok.

## 5. Faz 5 — girdi başına atıf

Kabul kriteri "atıf entity `source`'unda" idi ve `source` blueprint'ten
yazılamıyordu: `convert_blueprint.dart` onu manifest `title`'ından sabitliyordu.
Converter'a satır seviyesinde (`mapping`'in **kardeşi**) bir `source` eklendi —
verilmezse eski davranış:

```json
{ "source_name": "Gaea's Grasp, 5 charges",
  "source": "Glass Bird Games",
  "mapping": { "name": "Gaea's Grasp, 5 charges", "…": "…" } }
```

`mapping`'in *içine* konmadı: `creature-action` ve `trait` şemaları gerçek bir
`source` **alanı** tanımlıyor, iki anlam çakışırdı. Alan zaten UI'da görünür ve
sıralanabilir (`SourceBadge`, `entity_sidebar` source facet'i), yani atıf hem
görülüyor hem filtreleniyor. `entity.source` her satırda ayrıca `description`'da da
bağlantısıyla birlikte birebir duruyor — kaybı olmayan bir tekrar.

| Kaynak | `source` | Adet |
|---|---|---|
| `### From [Glass Bird Games](…)` | `Glass Bird Games` | 20 |
| `### From [Ialath](…)` | `Ialath` | 10 |
| `### From The NSR Discord` | `The NSR Discord` | 96 |
| `more-equipment.md` kredi satırı | `Oskar Swida` | 282 (244 gear + 38 service) |
| `more-spellbooks.md` | *(paket başlığı)* | 216 |

**d666 büyülerine girdi başına atıf yazılmadı.** Dosyanın `### References` bloğu
sekiz kaynağı **tablonun tamamı** için sayıyor, hangi satırın hangisinden geldiğini
söylemiyor. Uydurmak yerine blok olduğu gibi bir `lore` sayfasında duruyor.

Faz 5'te kapatılan üç sadakat açığı (kapsam denetimi buldu):

1. `more-relics.md` önsözü ("…copied with permission.") — izin beyanı, hiçbir
   relic'e ait değil → `lore`.
2. `more-spellbooks.md` girişi + `### References` atıf listesi → `lore`.
3. `more-equipment.md` tablolarının **kalın sütun başlıkları** atılıyordu. Bu
   mekanik veri kaybıydı: Specialists bölümünde gövde metni "wage per week" derken
   tablo başlığı "**Wage (per month)**" diyor. Kaynak kendiyle çelişiyor; hangisinin
   doğru olduğuna karar vermiyoruz, ikisi de girdinin `description`'ında duruyor.

## 6. Fazlar

| # | İş | Çıktı | Doğrulama |
|---|---|---|---|
| 0 ✅ | `flutter_app/tool/content/cairn/build_cairn.dart` iskeleti + `manifest.json`'lar + eşleme tablosunun koda dökümü | 2 boş blueprint | `--check` temiz (0 entity) |
| 1 ✅ | **145 canavar + creature-action'lar** | `monster` 145, `creature-action` 163 | `--check` temiz; 145/145 kaynak satırı `description`'da birebir (otomatik denetim), spot: acolyte / air-elemental / aranea |
| 2 ✅ | **20 background** + marketplace (armor/weapon/gear/transport/upkeep/hireling) | `background` 20, `armor` 6, `weapon` 6, `adventuring-gear` 49, `mount` 2, `vehicle` 2, `service` 6, `hireling` 12 | `--check` temiz; 20/20 background birebir; kabul #2 wizard testiyle doğrulandı |
| 3 ✅ | 46 relic + 100 spellbook | `magic-item` 46, `spell` 100 | `--check` temiz |
| 4 ✅ | Kural metni, Vald, Bonds/Omens/trait tabloları, seeds, hirelings, upkeep | `lore` 27, `hireling` 12, `service` 6 | `audit_coverage.py` **%99.6** (3991 cümle, 16 eşik altı) — bkz. §4.1 |
| 5 ✅ | **`cairn-community`**: more-relics / more-spellbooks / more-equipment, kaynak başına atıf | `magic-item` 126, `spell` 216, `adventuring-gear` 244, `service` 38, `lore` 3 | `--check` temiz; üç `### From` bloğunun atfı (20 / 10 / 96) entity `source`'unda birebir; kapsam **%97.9** |
| 6 ✅ | `assets/open5e_packs/` + `build_catalog` (`publish_catalog` **koşulmadı** — worker URL + `ADMIN_TOKEN` gerektiren dışa açık bir yükleme) | `manifest.json`'a 2 paket, `assets/first_party/manifest.json`'a 2 `package` girdisi (21 paket + 3 dünya) | `flutter analyze` 0 hata/uyarı; tam suite 78 → 79 hata, aradaki tek fark `content_store_test`'in bilinen kararsızlığı (aynı dosya ikinci koşuda 2 hata veriyor) — bkz. §6.1 |

> ✅ **Faz 2'de ölçülen engel (a) ile kapandı.** `wizard_pack_families_test.dart`
> artık `metadata.game_system`'e bakıyor: 5e ailesi (`5e-*` / `a5e`) dışındaki
> paketlerde *"spell adımı paket büyülerini bir sınıfın altında gösterir"*
> koşulmuyor. **Faz 2'nin "mevcut 20 pakette bu alan yok" ölçümü yanlıştı** —
> 20/20'sinde var (`5e-2014` ×16, `a5e` ×4, `5e-2024` ×1), yani kapı hiçbir 5e
> paketini testin dışına düşürmüyor; ölçüldü.

| 7 | *(sonra)* `adventures/` → dünyalar, paketleri `links` ile bağla | world manifest'lerinde `"links": [{"slug": "cairn-2e-core"}]` | katalogda `requires` görünmeli |

Faz 1 tek başına kullanılabilir bir paket üretir; oradan sonrası additive.

### 6.1 Faz 6 — nüfus sayacı iki testte bayattı, ve bir engel Cairn'in değil

Paketleri `assets/open5e_packs/` içine koymak **iki sayım nöbetçisini** düşürüyor;
ikisi de dizini `listSync` ile tarayıp `hasLength(19)` diyordu:

| Test | Ne koruyor |
|---|---|
| `spell_slot_grid_reach_test.dart:106` | "paketlenmiş hiçbir sınıf kartı caster değil" |
| `bundled_pack_resolve_test.dart:478` | "her (paket, mekanik alan) çifti sayfada bir etki üretir" |

**19 zaten yanlıştı**: `dnd5e-srd.pkg.json` dizine girdiğinde sayı bumplanmamış,
yani ikisi de temiz ağaçta **19 vs 20** ile kırmızıydı (ölçüldü: cairn dosyaları
dışarı alınıp koşuldu). Sabit gerçek değere (**22**) çekildi.

Sayı düzeldiği an ikisi de **bir sonraki iddiada** düşüyor ve orası da Cairn'in
değil:

- `spell_slot_grid_reach`: `dnd5e-srd.pkg.json` 12 caster sınıf kartı taşıyor,
  test ise "korpusun tamamı a5e-ag Marshal + bfrd Mechanist" diyor. Cairn sıfır
  `class` kartı basıyor.
- `bundled_pack_resolve`: `dnd5e-srd`'nin ~24 `feat.*` alanı ile
  `magic-item.charges_max` / `charge_regain` `notResolverRead`/`unreadByAnyone`
  listelerinde beyan edilmemiş. Cairn paketleri **yeni bir alan adı eklemiyor** —
  aynı iki `magic-item` alanını yazıyorlar, ki onları `dnd5e-srd` zaten yazıyor
  (ölçüldü: cairn dışarı alınıp sayaç 20'ye çekilince liste aynı kalıyor).

Yani ikisi de `dnd5e-srd.pkg.json`'ın terfisinden kalma borç. Kapatmak o paketin
`feat` sözleşmesine karar vermek demek — **Faz 6'nın işi değil**, ayrı iş.

## 7. Doğrulama — ikisi de zorunlu

[tool/content/README.md](../../../../tool/content/README.md) §5 kuralı burada da geçerli.

```bash
cd flutter_app
dart run tool/content/cairn/build_cairn.dart --src /home/eren/GitHub/cairn
for d in cairn-2e-core cairn-community; do
  dart run tool/content/convert_blueprint.dart --dir assets/worlds/cairn/$d --check
done
# içerik sadakati: §4.1'deki iki `audit_coverage.py` koşusu

# Faz 6 — pakete promote (ayrı `.pkg.json` kopyası yok, `--out` doğrudan yazıyor)
for d in cairn-2e-core cairn-community; do
  dart run tool/content/convert_blueprint.dart \
    --dir assets/worlds/cairn/$d --out assets/open5e_packs/$d.pkg.json
done
# assets/open5e_packs/manifest.json'a girdi (asset/package_name/title/publisher/
# license/game_system/is_srd_overlap/counts) — elle tutulan dosya, build_packs yazmıyor
dart run tool/catalog_publish/bin/build_catalog.dart
# dışa açık, ayrı karar: dart run tool/catalog_publish/bin/publish_catalog.dart --worker <url>
```

**Değişmez kural (README §0):** kaynaktaki her cümle pakete girer. Özetleme,
yeniden yazma yok. Kaynak bir alanı söylemiyorsa alan **boş bırakılır**, tahmin
edilmez. `--check` şemayı doğrular, **sadakati doğrulamaz** — kapsam denetimi
bu yüzden zorunlu.

## 8. Faz 7 önizlemesi — adventures nasıl dünya olur

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

## 9. Kaynak envanteri (referans)

Toplam 29.366 satır markdown. Kullanılabilir:

**145** canavar · **20** background · **46**+**129** relic · **100**+**216**
spellbook · **~90** marketplace satırı · **~200** ek ekipman · **12** hireling ·
20 Bond · 20 Omen · 8×d10 karakter özelliği tablosu · seed/naming üreteçleri ·
Vald (251 satır) · 3 tam çeviri (tr / pt-BR / ru).

Kullanılmayan: `adventures/` (redirect + üçüncü taraf delta), `scripts/`
(LaTeX/PDF boru hattı), `img/` (lisans beyanı yok), `fonts/` (OFL, gereksiz),
`first-edition/` + `barebones/` (ayrı sürümler), `hacks/third-party/`.
