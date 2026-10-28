# SRD 5.2.1 Free Template — alan ayıklama listesi

> **Durum:** onaylandı, uygulamada (2026-10-28). S1, S2, S3 ve S5 karara bağlandı (§10). Yol
> haritası §11'de: A1–A10. Güncel faz: **A1** (uygulandı, otomatik kapı yeşil; elle kontrol
> bekliyor).
> **Kaynaklar:** `builtin/content.dart`, `lookups.dart`, `dm.dart`, `free_template.dart`,
> `free_srd_levels.dart`, SRD paketinin dökümü (~1 900 kart, alan alan doluluk sayıları) ve
> `docs/SRD_CC_v5.2.1.pdf`.

---

## 1. Ne yapıyoruz?

Yerleşik SRD'de bir kartın alanlarının çoğu **kural motoru** için var. Motor, "Tough feat'i her
seviyede +2 HP verir" bilgisini `hp_bonus_per_level` alanından okuyup karaktere ekliyor. Free
template'te bu motor yok: oyuncu kartı okuyor ve kendisi uyguluyor. Bu yüzden o alanlar free'de
sadece kalabalık yapıyor. Örneğin bir feat kartında 60 alan var, bunların 55'i ya boş ya da metnin
tekrarı.

Free SRD'de (template ve "SRD 5.2.1 Core - Free Template" paketi) yapılacaklar:

1. Sadece motorun kullandığı alanları çıkarmak.
2. Çıkan alanın bilgisi metinde yoksa, onu **SRD'nin kendi yazım biçimiyle** metne yazmak.
3. Karaktere kendiliğinden geçebilecek kartları (direnç, duyu, dil, trait, eylem, büyü…)
   **Verilenler**'e koymak.
4. Kategorileri olabildiğince SRD dokümanındaki başlıklara indirmek. Örneğin büyüde Casting Time,
   Range, Components ve Duration.
5. Her yeni İngilizce metnin Türkçesini çeviri tablosuna eklemek.

Yerleşik (otomatik) SRD template'i ve paketi **hiç değişmez**.

## 2. Sistem bugün nasıl çalışıyor?

- Free SRD template'i kodda üretiliyor: yerleşik template kopyalanıyor ve bazı alan tipleri free
  tarzlara çevriliyor (`copyAsFreeTemplate`). Bu sırada neredeyse hiçbir alan silinmiyor; yalnızca
  CR hesaplayıcı ve büyü slotu tablosu gidiyor.
- Free SRD paketi, yerleşik paketin **birebir kopyası**; yalnızca id'ler farklı. Kart verisi SRD
  şeklinde kalıyor. Free template bazı alanları **okurken** dönüştürüyor:
  - sınıf özellikleri → seviye tablosu,
  - kaynak havuzları → Verilenler / kaynak,
  - başlangıç ekipmanı → markdown,
  - canavarın AC/HP'si → Savaş değerleri.
- SRD soyundan gelen bir free dünyaya "SRD içeriğini ekle" denince bugün **yerleşik** SRD verisi
  geliyor, free paket değil.
- Türkçe: veri İngilizce kalıyor. Ekranda `assets/srd_l10n/tr/<kategori>.json` tablosundan
  çevriliyor ve **anahtar, İngilizce metnin birebir kendisi**. Bu yüzden metin değişirse çevirisi
  düşer; yeni her metin yeni bir çeviri ister.

Free'de hâlâ **otomatik çalışan** ve bu yüzden dokunmamamız gereken şeyler:

| Ne | Okuduğu alan |
|---|---|
| Seviye tablosu (sınıf/alt sınıf özellikleri, seviyeyle gelen büyüler, büyü slotları) | `features`, `granted_spells_at_level` |
| Verilenler (kart bir listeye girince öğelerini taşıyıcıya geçirir) | eski `resource_pool_grants` |
| Havuz + Kısa/Uzun dinlenme | oyuncu kartının Havuz'u |
| Savaş değerleri + encounter (HP, AC, İnisiyatif, XP, Durumlar) | `combat_stats` |
| Yetenek tablosu toplamları | skill/save tabloları + **`proficiency_bonus`** |
| Stat tablosu değiştiricileri | `stat_block` |
| Zar alanına dokununca atma | her zar alanı (hasar zarı, HP zarı) |
| Liste filtreleri | kategorinin filtre alanları (büyüde Level, School vb.) |

Bunların dışındaki her alanı motor okuyordu. Free'de bu alanları okuyan bir şey kalmadı.

## 3. Karar kuralları

Her alan için aynı soruları sordum:

| # | Soru | Cevap evetse |
|---|---|---|
| **R1** | Free'de otomatik çalışan bir şey (yukarıdaki tablo) bu alanı okuyor mu? | **Kalır** |
| **R2** | Alan, SRD dokümanında görünen bir bilgi mi (tablo sütunu, başlık satırı)? | **Kalır**, gerekiyorsa SRD'deki yazımına dönüşür |
| **R3** | Alanı sadece motor mu kullanıyor ve bilgisi kartın metninde zaten yazıyor mu? | **Çıkar**, bilgi kaybı olmaz |
| **R4** | Alanı sadece motor kullanıyor ama bilgisi metinde yok mu? | Önce SRD biçimiyle **metne yazılır**, sonra çıkar |
| **R5** | Karaktere kalıcı ve koşulsuz bir **kart** mı veriyor (direnç, duyu, dil, araç, zırh eğitimi, trait, eylem, büyü)? | Ayrıca **Verilenler**'e kart öğesi olur ve karakterin ilgili listesine kendiliğinden girer |
| **R6** | Koşullu bir şey mi (ör. Öfke *sırasında* direnç) ya da bir sayı/işaret mi (stat +1, AC +1, skill yeterliliği)? | **Yalnızca metin.** Verilenler sayı ya da işaret değiştiremez; koşullu bir şeyi kalıcı yazmak da yanlış olur |
| **R7** | Hiçbir SRD kartında dolu değil ve SRD'de bir karşılığı yok mu? | **Çıkar** |

R3 için veriyi taradım. Feat'lerdeki önkoşul, ASI, direnç, duyu, hız ve büyü gibi yapılı alanların
neredeyse hepsi `benefits` ya da `prerequisite` metninde zaten yazıyor. İstisnalar, ilgili
kategorinin altında ayrıca belirtildi. Alet ve eşyalardaki DC'lerin hepsi açıklama metninde var.

## 4. Grant bloğu (Feat, Trait, Tür, Alt tür, Büyülü eşya)

Beş kategoride aynı 42 alanlık "bu kart ne verir" bloğu var ve tamamı motor için yazılmış. Free
SRD'deki karşılıkları:

| Grant alanları | Free SRD'de nereye gider | Kural |
|---|---|---|
| `granted_damage_resistances`, `_immunities`, `_vulnerabilities` | Verilenler: hasar türü kartı → karakterin Dirençler / Bağışıklıklar / Zayıflıklar listesi | R5 |
| `granted_condition_immunities` | Verilenler: durum kartı → Durum bağışıklıkları | R5 |
| `granted_senses` | Verilenler: duyu kartı → Duyular. **Menzil** ("60 ft") metne yazılır | R5. Karakterin duyu listesi menzil tutmuyor |
| `granted_languages` | Verilenler: dil kartı → Diller | R5 |
| `granted_tool_proficiencies` | Verilenler: araç kartı → Araç yeterlilikleri | R5 |
| `granted_weapon_proficiencies`, `granted_armor_proficiencies` | Verilenler: silah/zırh kategorisi kartı → ilgili liste | R5 |
| `granted_spell_refs`, `granted_cantrip_refs`, `always_prepared_spell_refs` | Verilenler: büyü kartı → Büyüler | R5 |
| `granted_action_refs`, `_bonus_action_refs`, `_reaction_refs`, `trait_refs` | Verilenler: eylem/trait kartı → ilgili liste | R5 |
| `granted_spells_at_level` | **Seviye tablosu** (bugünkü gibi) | R1 |
| `resource_pool_grants` | **Verilenler**'de kaynak öğesi ya da veren kartın seviye tablosu. Bugün okurken yapılan dönüşüm artık veriye yazılır | R1 |
| `granted_skill_proficiencies`, `granted_save_proficiencies`, `granted_expertise_skills` | Metin | R6. Verilenler skill tablosuna işaret koyamıyor |
| `ability_bonuses`, `ability_bonus_cap`, `ac_bonus`, `speed_bonus_ft`, `initiative_bonus`, `hp_bonus_flat`, `hp_bonus_per_level`, `extra_attack_count`, `extra_attack_count_by_level`, `crit_threshold`, `weapon_mastery_count`, `unarmored_ac_*` (3 alan), `speed_fly/swim/climb/burrow_ft` | Metin | R6. Hepsi sayı; oyuncu uygular |
| `player_choices` | Metin (bugün de markdown olarak gösteriliyor) | R6 |
| `active_while_state_ref` | Metin. Bu alanı dolu olan kartın grant'leri **Verilenler'e konmaz** | R6. Örneğin Öfke'nin B/P/S direnci kalıcı değil |
| `mechanical_notes` | Metin. 27 kartta dolu ve hepsi `benefits`'in kısaltması | R3 |

Sonuç olarak blok, **Seviye tablosu + Verilenler** ikilisine iner.

## 5. Kategori kategori

Her kategoride önce **kalan** alanlar kısaca sayılıyor, ardından **çıkan / değişen** alanlar
tabloda veriliyor. "Metinde var" = R3 (kayıp yok); "metne yazılır" = R4.

### 5.1 Büyü (Spell) — 25 → 10 alan

SRD'de bir büyü şöyle yazılır:

```
Fireball
Level 3 Evocation (Sorcerer, Wizard)
Casting Time: Action
Range: 150 feet
Components: V, S, M (a ball of bat guano and sulfur)
Duration: Instantaneous
<metin> … Using a Higher-Level Spell Slot. …
```

Free SRD'de alanlar bu satırlara iner.

**Kalan:** Level, School, Classes, Ritual, Concentration, metin.

| Alan(lar) | Karar | Bilgi nereye | Neden |
|---|---|---|---|
| `casting_time_amount`, `casting_time_unit_ref`, `reaction_trigger` | Çıkar → **yeni `Casting Time` (yazı)** | "Action", "1 minute or Ritual", "Reaction, which you take when …" | SRD'de tek satır. 3 alan ve 1 lookup yerine 1 alan |
| `range_type`, `range_ft` | Çıkar → **yeni `Range` (yazı)** | "150 feet", "Self", "Touch" | Aynı |
| `components`, `material_description`, `material_cost_gp`, `material_consumed` | Çıkar → **yeni `Components` (yazı)** | "V, S, M (a diamond worth 300+ GP, which the spell consumes)" | Aynı |
| `duration_unit_ref`, `duration_amount` | Çıkar → **yeni `Duration` (yazı)** | "Concentration, up to 1 minute" | Aynı |
| `area_shape_ref`, `area_size_ft` | Çıkar | Metinde var. Bir test, her büyünün metninde şekli ve sayıyı arıyor | R3 |
| `at_higher_levels_text` | Çıkar | Metinde var ("Using a Higher-Level Spell Slot.") | R3, birebir tekrar |
| `damage_type_refs`, `save_ability_ref`, `attack_type`, `applied_condition_refs` | Çıkar | Metinde var | R3. Motorun hasar/kurtarma hesabı içindi |
| `effects` (etki tablosu) | Çıkar | — | R7. 341 büyünün hiçbirinde dolu değil |
| `is_ritual`, `requires_concentration` | **Kalır** | — | SRD'nin büyü listelerindeki "Special" sütunu (C, R). Filtrede de işe yarar. Casting Time ve Duration yazısında da görünür |

### 5.2 Sınıf (Class) — 29 → 14

SRD'de her sınıfın bir "Core … Traits" tablosu var: Primary Ability · Hit Point Die · Saving
Throw Proficiencies · Skill Proficiencies · Weapon Proficiencies · (Tool Proficiencies) · Armor
Training · Starting Equipment. Ardından "Becoming a …" kutusu (1. seviye / çok sınıflı) ve
özellik tablosu geliyor.

**Kalan:** Hit Point Die, Saving Throw Proficiencies, Armor Training, Spellcasting Ability,
Complexity (SRD'nin sınıf özeti tablosunda var), Features (seviye tablosu), Cantrips Known ve
Prepared Spells (SRD özellik tablosunun sütunları).

| Alan(lar) | Karar | Bilgi nereye | Neden |
|---|---|---|---|
| `primary_ability_ref` + `secondary_ability_ref` | → **`Primary Ability` (yazı)** | "Strength or Dexterity", "Dexterity and Wisdom" | İki bağlantı "ve / veya" farkını tutamıyor, SRD yazısı tutuyor |
| `skill_proficiency_choice_count` + `skill_proficiency_options` | → **`Skill Proficiencies` (yazı)** | "Choose 2: Animal Handling, Athletics, …" | Sayı + liste sihirbaz içindi; SRD'de tek satır |
| `weapon_proficiency_categories`, `weapon_proficiency_specifics`, `weapon_mastery_filter` | → **`Weapon Proficiencies` (yazı)** | "Simple and Martial weapons" | Aynı. Filtre bir makine anahtarı |
| `tool_proficiency_count`, `tool_proficiency_options`, `granted_tool_refs` | → **`Tool Proficiencies` (yazı)** | "Choose one type of Artisan's Tools or Musical Instrument" | Aynı |
| `equipment_choice_groups` | → **`Starting Equipment` (markdown)** | "Choose A or B: (A) Greataxe, 4 Handaxes, Explorer's Pack, and 15 GP; or (B) 75 GP" | Bugün de okurken markdown'a çevriliyor; artık veri doğrudan bu |
| `granted_languages` (Druidic, Thieves' Cant) | Çıkar → **1. seviye satırının öğesi** (dil kartı → Diller) | Seviye tablosu | SRD'de bunlar 1. seviye özelliği ve çok sınıflı karaktere de gelir |
| `multiclass_prereq_ability_refs`, `multiclass_prereq_min_score`, `multiclass_requirements`, `multiclass_granted_proficiencies` | → **yeni `Becoming a …` (markdown)** | SRD kutusu: "As a Level 1 Character … / As a Multiclass Character: Gain … Hit Point Die, proficiency with Martial weapons, and training with Shields." + önkoşul (13) | Son iki alan pakette **boş**. Çok sınıflı karakterin hangi yeterlilikleri aldığı bugün hiçbir yerde yazmıyor, bu yüzden SRD'den yazılır (R4) |
| `caster_kind`, `spell_slots_by_level` | Çıkar | Slotlar seviye tablosu satırlarına **veri olarak** yazılır (bugün okurken hesaplanıyor) | Hesaplama yerine sabit satır |
| `starting_gold_dice` ("2d4 × 10") | Çıkar | — | 2014 kuralı; SRD 5.2.1'de yok. 5.2.1'in altın seçeneği zaten Starting Equipment'ın (B) şıkkında |
| `l1_order_feat_category` | Çıkar | — | Sihirbaz filtresi (makine anahtarı) |
| `default_inventory_refs`, `spellcasting_focus_ref` | Çıkar | — | R7, ikisi de boş |

**Sınıfa neden Verilenler eklenmiyor:** Verilenler, kart listeye girdiği anda *her zaman* işler.
SRD'de ikinci bir sınıf alınırken yeterliliklerin tamamı değil, yalnızca bir kısmı veriliyor;
Verilenler bu ayrımı yapamaz. Bu yüzden Core Traits yazı olarak kalır ve oyuncu uygular. Karakter
oluşturma rehberi bunu zaten söylüyor.

Filtre: `caster_kind` çıkınca sınıf filtresi de kalkar. 12 kart için filtreye gerek yok.

### 5.3 Alt sınıf (Subclass) — 9 → 4

**Kalan:** Parent Class, Granted at Level, Features (seviye tablosu), Flavor.

| Alan(lar) | Karar | Neden |
|---|---|---|
| `bonus_skill_pick_count` | Çıkar | Sihirbaz sayacı; metinde var (R3) |
| `saving_throw_refs`, `weapon_proficiency_categories`, `armor_training_refs`, `caster_kind` | Çıkar | R7. 12 alt sınıfın hiçbirinde dolu değil |

### 5.4 Tür (Species) — 48 → 5

SRD'deki yazım: "Creature Type: Humanoid · Size: Medium (about 4–5 feet tall) · Speed: 30 feet".
Ardından "As a Dwarf, you have these special traits." ve trait paragrafları geliyor.

**Kalan:** Creature Type, Speed, Verilenler.

| Alan(lar) | Karar | Bilgi nereye | Neden |
|---|---|---|---|
| `size_ref` | → **`Size` (yazı)** | "Medium (about 4–5 feet tall)". İnsan'da: "Medium … or Small …, chosen when you select this species" | Bağlantı ne boyu ne de seçimi tutabiliyor |
| — | **yeni `Traits` (markdown)** | SRD biçiminde trait paragrafları: "**Darkvision.** You have Darkvision with a range of 60 feet." … | Bugün kartın açıklaması tek satırlık, bizim yazdığımız bir özet. Asıl bilgi yapılı alanlarda ve ayrı trait kartlarında duruyor. Yapılı alanlar gidince bu yazının bir yeri olmalı (R4) |
| `trait_refs`, `granted_senses`, `granted_damage_resistances`, `granted_*_action_refs`, `granted_languages` | → Verilenler (kart öğeleri) + Traits yazısı | | R5 |
| Grant bloğunun geri kalanı, `speed_burrow/climb/fly/swim_ft`, `granted_feat_refs`, `subspecies_options`, `player_choices`, `granted_spells_at_level` | Çıkar | 1 karttaki `mechanical_notes` Traits yazısına gider | R7. 10 türün hiçbirinde dolu değil |
| `age` | Çıkar | — | Yalnızca Half-Elf'te dolu ("180 years"), Half-Elf de SRD 5.2.1'de yok (bkz. §9) |

### 5.5 Alt tür (Subspecies) — 48 → 3

SRD'de bir alt tür, türün "Lineages" tablosunun bir satırıdır (Level 1 / Level 3 / Level 5
sütunları). Seviye tablosu bunu birebir karşılıyor.

**Kalan:** Parent Species, seviye tablosu (satır yazısı = SRD tablosundaki hücre), Verilenler.

| Alan(lar) | Karar | Bilgi nereye | Neden |
|---|---|---|---|
| `granted_cantrip_refs` (7 kart) | → 1. seviye satırı: büyü kartı → Büyüler | Seviye tablosu | SRD tablosunun Level 1 hücresi |
| `granted_damage_resistances` (14), eylemler (6) | → Verilenler | | R5 (Draconic Ancestry direnci, Breath Weapon…) |
| `granted_skill_proficiencies` (3), `ability_bonuses`, `speed_bonus_ft`, `hp_bonus_*` | → satır yazısı | | R6 |
| `legacy_subspecies_key` | Çıkar | — | Eski kayıtlar için göç anahtarı; free'de eski kayıt yok |
| `size_ref`, `creature_type_ref`, hızlar, bloğun geri kalanı | Çıkar | — | R7. 30 alt türün hiçbirinde dolu değil |

### 5.6 Geçmiş (Background) — 14 → 6

SRD'deki başlıklar: Ability Scores · Feat · Skill Proficiencies · Tool Proficiency · Equipment.
Free'de alanlar tam olarak bunlar oluyor.

**Kalan:** Ability Scores, Feat, Skill Proficiencies, Tool Proficiency. Etiketler SRD'deki gibi
olur.

| Alan(lar) | Karar | Bilgi nereye | Neden |
|---|---|---|---|
| `equipment_choice_groups`, `starting_gold_gp`, `gold_alternative_gp` | → **`Equipment` (markdown)** | "Choose A or B: (A) …, 8 GP; or (B) 50 GP" | Altın iki şıkta zaten yazılı; 3 alan → 1 |
| `asi_distribution_options` | Çıkar | Karakter oluşturma rehberinde var ("+2 / +1 ya da +1 / +1 / +1") | 16 geçmişin hepsinde aynı genel kural (R3) |
| `granted_tool_variant_group` | Çıkar | Tool Proficiency yazısı | Makine anahtarı |
| `granted_language_count`, `granted_languages`, `asi_fixed_ability_ref`, `asi_free_bonus_count`, `default_inventory_refs` | Çıkar | — | R7, hepsi boş |
| — | **Yeni: Verilenler.** Origin feat → Feat'ler; araç → Araç yeterlilikleri | | R5. Geçmiş bir kez seçilir, çok sınıf sorunu yok. Feat'in kendi Verilenler'i de zincirle işler |

### 5.7 Feat — 60 → 5

SRD'deki yazım: "Alert / Origin Feat / You gain the following benefits." ya da "General Feat
(Prerequisite: Level 4+, Dexterity 13+)", ardından fayda paragrafları.

**Kalan:** Category, Prerequisite (yazı), Benefits (metin), seviye tablosu (Lucky gibi seviyeyle
büyüyen kaynaklar için), Verilenler.

| Alan(lar) | Karar | Neden |
|---|---|---|
| `prereq_ability_ref`, `prereq_min_score`, `prereq_class_refs`, `prereq_species_refs`, `prereq_min_character_level`, `prereq_requires_spellcasting` | Çıkar | `Prerequisite` yazısında var (R3, tarandı) |
| `repeatable`, `repeatable_limit` | Çıkar | SRD'de "Repeatable." diye bir paragraf; metinde var (R3) |
| `asi_ability_options`, `asi_amount`, `asi_max_score`, `grants_save_prof_from_asi`, `bonus_skill_pick_count`, `bonus_expertise_pick_count` | Çıkar | "Ability Score Increase." ve ilgili paragraflar metinde var (R3) |
| `chooseable` | Çıkar | Seçim ekranı yok |
| Grant bloğu | §4'teki gibi | Verilenler / metin |

Taramada tek istisna Skill Expert çıktı: tekrar alınabilir işaretli ama metninde bu yazmıyor. Kart
zaten SRD 5.2.1'de yok (bkz. §9).

### 5.8 Trait — 46 → 3

**Kalan:** Trait Kind (filtre), metin, Verilenler. Verilenler bugün hepsinde boş; bir türün trait'i
bir şey verecekse zincir için orada duruyor.

| Alan(lar) | Karar | Neden |
|---|---|---|
| `source` | Çıkar | 239 kartın hepsinde "SRD 5.2.1" yazıyor; bu, kartın kendi kaynak bilgisinin tekrarı. Filtreden de çıkar |
| `benefits`, `chooseable` | Çıkar | R7, boş |
| Grant bloğu (39 alan) | Çıkar | 239 trait'in hiçbirinde dolu değil |

### 5.9 Büyülü eşya (Magic Item) — 64 → 10

SRD'deki yazım: "Wand, Uncommon (Requires Attunement by a Spellcaster)" ve ardından metin.

**Kalan:** Category, Rarity, Requires Attunement, Attunement Prerequisite (yazı: "by a
Spellcaster"), Base Item, Max Charges, Charge Regain, Effects, Cost, Weight.

| Alan(lar) | Karar | Neden |
|---|---|---|
| Grant bloğu (36 alan) | Çıkar | 286 eşyanın hiçbirinde dolu değil. Ayrıca eşya ancak *uyumlanınca* etki eder; Verilenler bunu bilemez |
| `attunement_class_refs`, `_species_refs`, `_alignment_refs`, `_min_ability_ref`, `_min_ability_score`, `_spellcaster_only` | Çıkar | Boş; `attunement_prereq` yazısı aynı bilgiyi taşıyor |
| `body_slot_ref` | Çıkar | Boş; SRD 5.2.1'de beden yuvası kavramı yok |
| `activation` | Çıkar | Uygulamanın kendi sınıflaması ("Magic Action" gibi); metinde yazıyor (R3) |
| `is_cursed` | Çıkar | 9 eşyada dolu; metinde "Curse." paragrafı var (R3) |
| `command_word`, `is_sentient`, `sentient_*` (7 alan) | Çıkar | R7, hepsi boş |

### 5.10 Canavar ve Hayvan (Monster / Animal) — 45 → 27

SRD stat bloğu sırasıyla şunları içerir: AC · HP 7 (2d6) · Speed 30 ft., Fly 60 ft. (hover) ·
Initiative +2 (12) · stat tablosu · Skills · Resistances / Immunities · Gear · Senses …; Passive
Perception 9 · Languages · CR 1/4 (XP 50; PB +2) · Traits · Actions · Bonus Actions · Reactions ·
Legendary Actions.

**Kalan:** Size, Creature Type, Tags, Alignment, Savaş değerleri (AC, HP, İnisiyatif, XP,
Durumlar), HP Dice, Ability Scores, Saves, Skills, direnç/bağışıklık listeleri (4), Senses, Passive
Perception, Languages, Telepathy, CR, Proficiency Bonus (yetenek tablosu toplamı için şart),
Traits, Actions, Bonus Actions, Reactions, Legendary Action Uses, Legendary Actions, Gear.

| Alan(lar) | Karar | Bilgi nereye | Neden |
|---|---|---|---|
| `speed_walk_ft`, `speed_burrow_ft`, `speed_climb_ft`, `speed_fly_ft`, `speed_swim_ft`, `can_hover` | → **`Speed` (yazı)** | "30 ft., Fly 60 ft. (hover)" | SRD'de tek satır; 6 alan → 1 |
| `ac`, `hp_average`, `initiative_modifier` | Çıkar (bugün de görünmüyorlar) | Savaş değerleri bloğuna **veri olarak** yazılır | Bugün okurken çevriliyorlar |
| `xp` (düz alan) | Çıkar | Savaş değerleri bloğundaki XP'ye | Kopyada şu an iki XP var (düz alan + blok) |
| `initiative_score` | Çıkar | — | 10 + değiştirici. Bloğun İnisiyatif değeri zaten bunu tutuyor |
| `description` (alan), `alignment_note`, `ac_note`, `resistance_note`, `immunity_note`, `language_note` | Çıkar | — | R7. 345 kartın hiçbirinde dolu değil |
| `traits_md`, `spells_md`, `equipment_md`, `spell_refs` | Çıkar | — | Boş; Traits / Actions / Gear listelerinin tekrarı |
| `lair_action_refs` | Çıkar | — | Boş. 5.2.1'de in eylemleri Legendary Actions'ın içinde |

### 5.11 Eylem (Creature Action) — 20 → 3

SRD'deki yazım tek satır: "Scimitar. *Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2)
Slashing damage."

**Kalan:** Action Type (filtre; SRD'deki Actions / Bonus Actions / … başlıkları), Damage Dice
(dokununca atılıyor), metin.

| Alan(lar) | Karar | Neden |
|---|---|---|
| `is_attack`, `attack_kind`, `attack_bonus`, `reach_ft`, `range_normal_ft`, `range_long_ft`, `damage_type_ref`, `applied_condition_refs` | Çıkar | Metinde var (tarandı, 528/528) |
| `save_dc`, `save_ability_ref` | Çıkar → 9 kartta **DC metne yazılır** | 67 kartın 57'sinde DC metinde var. 9 kartta yok: ejderhaların Wing Attack ve Breath'leri, iki Engulf, Sprite'ın Touch'ı (R4). Commanding Presence'ın metni "Spellcasting'deki DC'yi kullanır" diyor, orada kayıp yok |
| `recharge_kind`, `recharge_min_roll`, `uses_per_day` | Çıkar → **metnin başına yazılır** | 16 kartta "Recharge 5–6", 10 kartta "3/Day" metinde **yok** (R4). SRD bunu başlıkta yazar: "Acid Breath (Recharge 5–6)." |
| `source` | Çıkar | 528 kartın hepsinde "SRD 5.2.1" (tekrar) |
| `recharge`, `legendary_action_cost`, `effects` | Çıkar | R7, boş |

### 5.12 Silah, zırh, alet, eşya, cephane, paket, binek, taşıt

Bunlar çoğunlukla SRD tablolarının sütunları olduğu için az alan çıkıyor.

| Kategori | Çıkan / değişen | Neden |
|---|---|---|
| Silah (12 → 11) | `is_melee` çıkar | Kategori zaten "Martial Melee / Simple Ranged" diyor (38/38 tutarlı) |
| Zırh (10 → 6) | `base_ac`, `adds_dex`, `dex_cap` → **`Armor Class (AC)` (yazı)**: "14 + Dex modifier (max 2)", "+2" | SRD tablosunun sütunu bu. Free'de AC hesaplanmıyor |
| Zırh | `don_time_minutes`, `doff_time_minutes` çıkar → **zırh kategorisi kartlarının metnine** (SRD'nin "Donning and Doffing Armor" tablosu) | SRD'de bu süreler zırh başına değil, kategori başına |
| Alet (8 → 7) | `utilize_check_dc` çıkar | DC, 34 kartın hepsinde Utilize yazısında var |
| Alet | `craftable_items` (boş bağlantı listesi) → **`Craft` (yazı)** | SRD her alette "Craft: Acid, Alchemist's Fire, …" satırı yazıyor; pakette bu bilgi hiç yok (bkz. S5) |
| Macera eşyası (8 → 4) | `utilize_check_dc`, `utilize_ability_ref` çıkar | Utilize yazısında var (8/8) |
| Macera eşyası | `consumable`, `is_focus` çıkar | İlki motor bayrağı; ikincisini `focus_kind_ref` zaten söylüyor |
| Paket (5 → 3) | `content_refs`, `content_quantities` çıkar | `contents` yazısında aynı liste adetleriyle var (7/7) |
| Cephane, Binek, Taşıt | Değişmez | SRD tablo sütunları |

### 5.13 Oyuncu kartı ve NPC

Bunlar içerik değil, oyuncunun doldurduğu kağıt; alanların çoğu kalır. Yalnızca motorun
yardımcıları çıkar:

| Kategori | Alan | Karar | Neden |
|---|---|---|---|
| Oyuncu | `current_conditions` | Çıkar | Savaş değerleri bloğundaki Durumlar aynı şeyi tutuyor ve encounter onu okuyor; şu an iki ayrı durum listesi var |
| Oyuncu | `extra_hp` | Çıkar | Yerleşikte Maks HP'ye eklenen bir yardımcıydı; free'de hiçbir şeye eklenmiyor |
| Oyuncu | `trinket_ref` | Çıkar | Trinket kartı yok; `trinket` yazısı kalıyor |
| NPC | `initiative_modifier` | Çıkar | Bloğun İnisiyatif değeri aynı şey |

Oyuncu kartındaki şu listeler **kalmalı**, çünkü Verilenler'in kart öğeleri bunlara iniyor: Feat'ler,
Traits, Actions, Bonus Actions, Reactions, Spells, Senses, Languages, Tool Proficiencies,
Weapon/Armor, Dirençler, Bağışıklıklar.

### 5.14 Lookup kategorileri (Ability, Skill, Condition, …)

| Ne | Karar | Neden |
|---|---|---|
| Her lookup'taki `icon_name` ve `color` | Çıkar (39 kategori × 2) | Hiçbir SRD kartında dolu değil ve hiçbir kod okumuyor |
| Condition: `stacks`, `ends_on`, `grants_incapacitated` | Çıkar → **SRD durum metni `effects`'e yazılır** | Bayraklar motor içindi. Durum kartlarında bugün **hiç kural metni yok**. SRD sözlüğündeki metin hem bayrağın bilgisini ("Paralyzed: You have the Incapacitated condition") hem de fazlasını taşıyor (R4) |
| Weapon Property: `mechanic_kind` | Çıkar → **SRD özellik metni** | Makine kodu (`ability_choice_str_dex` gibi); kartlarda metin yok |
| Weapon Mastery: `effect_kind`, `effect_value`, `save_ability` | Çıkar → **SRD ustalık metni** | Aynı |
| Damage Type: `is_physical`, `bypassable_by_magical` | Çıkar | Motor bayrağı. "Examples" sütunu kalır |
| Creature Type `default_skills_note`, Language `script`, Magic Item Category `crafting_tool_ref`, Sense `default_range_ft`, Ability `order_index`, Skill `examples` | Çıkar | Boş ya da yalnızca motor/sıralama için |
| Size (`space_ft`, `hit_die_size`, `carrying_multiplier`), Rarity (değer, yapım süresi/maliyeti), Coin, Lifestyle, Language `tier` | **Kalır** | SRD tablolarının sütunları |
| **Kategori olarak çıkar:** Character State, Resource Pool | | Motorun iç anahtarları (`state:raging`, `pool:rage_uses`). Kaynaklar artık Verilenler'de adıyla duruyor |
| **Kategori olarak çıkar:** Body Slot | | SRD 5.2.1'de yok. Tek kullanıcısı boş `body_slot_ref` |
| **Kategori olarak çıkar:** Duration Unit, Casting Time Unit, Casting Component | | Tek kullanıcıları büyünün yapılı alanlarıydı. Bunlar yazıya dönünce sahipsiz kalıyorlar ve kendi metinleri de yok |
| Area Shape | Kalır | SRD sözlüğünde her şeklin kuralı var (Cone, Emanation…). Bağlantısız da sözlük kartı olarak işe yarar |

### 5.15 Diğerleri

| Kategori | Karar | Neden |
|---|---|---|
| Starter Bundle | Kategori çıkar. SRD'nin "Starting at Higher Levels" tablosu karakter oluşturma rehberine taşınır | Onu sihirbaz okuyordu; pakette bu kategoriden kart da yok |
| Trinket | Kalır (d100 + metin) | SRD'de 1d100 Trinkets tablosu var ama pakette kart yok (bkz. S5) |
| DM kategorileri (Location, Scene, Quest, Encounter, Trap, Poison, Curse, …) | Değişmez | SRD içeriği yok; alanlar DM'in yazdığı bilgi |

## 6. Yeni ya da değişen alanların özeti

| Kategori | Alan | Tarz | Yerine geçtiği |
|---|---|---|---|
| Spell | Casting Time, Range, Components, Duration | Yazı | 13 yapılı alan |
| Class | Primary Ability, Skill Proficiencies, Weapon Proficiencies, Tool Proficiencies | Yazı | 11 alan |
| Class | Starting Equipment | Markdown | `equipment_choice_groups` |
| Class | Becoming a … | Markdown | 4 çok sınıf alanı (2'si boştu) |
| Species | Size | Yazı | `size_ref` |
| Species | Traits | Markdown | Yapılı grant alanları + bizim yazdığımız özet |
| Background | Equipment | Markdown | 3 alan |
| Background | Verilenler | Verilenler | (yeni) |
| Armor | Armor Class (AC) | Yazı | 3 alan |
| Tool | Craft | Yazı | `craftable_items` |
| Monster / Animal | Speed | Yazı | 6 alan |

Toplam: 22 içerik kategorisinde **521 alan → 167**. Lookup'lardan ayrıca 78 alan (`icon_name` /
`color`) ve birkaç motor bayrağı çıkar. 7 kategori tamamen çıkar: Character State, Resource Pool,
Body Slot, Duration Unit, Casting Time Unit, Casting Component, Starter Bundle.

## 7. Türkçe

- Yeni etiketler (Casting Time, Primary Ability, …) `_schema.json`'a, yeni metinler kategorinin
  tablosuna (`spell.json`, `class.json`, …) eklenir.
- Çeviri anahtarı İngilizce metnin kendisi olduğu için, yeri değişen ama içeriği aynı kalan metin
  (ör. feat `benefits`) çevirisini **korur**. Yeni oluşan metin ise yeni bir çeviri ister:
  "Concentration, up to 1 minute", türün Traits paragrafları gibi.
- Türün Traits yazısı trait kartlarının metninden kurulacak, ama çeviri tablosu kategori başına
  tutuluyor. Bu yüzden `trait.json`'daki çeviriler `species.json`'a taşınır.
- Kurallar `docs/srd-tr/ROADMAP.md`'dekiyle aynı: sayı, zar, DC ve birim birebir korunur; terim önce
  sözlükten gelir; `check_pairs` 0 hata vermeli.

## 8. Nasıl uygulanır

- **Tek dönüştürücü.** Free SRD verisi, yerleşik SRD paketinin satırlarından **tek bir saf
  fonksiyonla** üretilir: `lib/domain/services/free_srd_pack.dart` (yeni). `builtin/`
  dosyalarına dokunulmaz, `srdCorePackVersion` artmaz.
  - Bugün ekranda yapılan okuma dönüşümleri (seviye tablosu, kaynaklar, slotlar, Savaş değerleri,
    başlangıç ekipmanı) veriye yazılır. Bugünkü okuyucular (`free_srd_levels.dart`,
    `combatStatsValue`, `structuredListAsMarkdown`) dönüştürücünün içinden çağrılır; mantık iki
    kez yazılmaz.
  - Alanlar birleştirilir (Casting Time, Speed…), Verilenler doldurulur, R4 metinleri yazılır.
  - SRD'den alınan metinler (R4 ve S5: Becoming a…, durum kuralları, Craft, sözlük metinleri,
    Trinket tablosu…) tek bir veri dosyasında durur: `lib/domain/services/free_srd_texts.dart`
    (yeni). Metin PDF'ten birebir alınır.
  - Tier-0 `_lookup` yer tutucuları çıktıda kalır; dünyaya sentezlenirken bugünkü gibi çözülür.
- **Şema.** `copyAsFreeTemplate` yerleşikten kopyalarken her kategorinin çıkan alanlarını atar,
  yenilerini ekler. Çıkan 7 kategori kopyaya hiç girmez. Bir kategorinin şema değişikliği ile veri
  değişikliği aynı fazda, aynı commit'te yapılır.
- **Free paket.** `_ensureFree` paketi kurarken satırları dönüştürücüden geçirir. Paketin yeniden
  kurulma koşuluna bir dönüştürücü sürümü (`freeSrdPackVersion`) eklenir; böylece yalnız
  dönüştürücü değiştiğinde de paket yenilenir.
- **Free dünya.** SRD soyundan gelen bir free dünyada "SRD içeriğini ekle", yerleşik paket yerine
  **free paketi** bağlar. Kartlar bugünkü gibi okunurken sentezlenir (`synthesizeWorldBuiltins`),
  dünyaya kopyalanmaz. Yerleşik pakete bakan yerler (sentez, Tier-0 dizini, yabancı ref dizini,
  `builtinPackageIdProvider`, paket ekranının SRD referans kartları) iki paketi de yerleşik sayar.
  Yerleşik dünya yine yerleşik paketi bağlar.
- **Türkçe.** Yeni İngilizce metin `assets/srd_l10n/tr/` tablolarına eklenir. Parçalardan kurulan
  bir metnin (Components satırı, Recharge başlığı, türün Traits yazısı…) Türkçe önerisi aynı
  kurucuyla, parçaların mevcut çevirilerinden üretilir ve sonra gözden geçirilir. PDF'ten gelen
  yeni metin sözlükle çevrilir ([docs/srd-tr/ROADMAP.md](../srd-tr/ROADMAP.md) kuralları).
- **Eski veri.** Geçiş kodu yazılmaz ([ROADMAP.md](ROADMAP.md) Y1). A1'den önce kurulan SRD soylu
  free dünyalar yerleşik paketle kalır. Kullanıcının kaydettiği SRD kopyaları da eski alanlarıyla
  kalır. Testte ikisi de yeniden kurulur.
- İş fazlara bölünür ve her faz sonunda uygulamada elle kontrol edilir (§11).

## 9. Gözlemler (karar gerektiren)

1. **Paket verisi SRD 5.2.1'den sapıyor.** Örnekler:
   - Goblin Warrior pakette AC 12 / HP 7 (2d6) / Humanoid; SRD'de AC 15 / HP 10 (3d6) / Fey ve bir
     "Redirect Attack" tepkisi var.
   - Cüce'nin Darkvision'ı pakette 60 ft, SRD'de 120 ft. Cüce'de SRD'de olmayan bir "Forge Wise"
     trait'i var.
   - Half-Elf (tür) ve Skill Expert (feat) SRD 5.2.1'de yok.
   - Lightning Bolt'un malzemesi 2014 metninden.
   - Metinler genel olarak SRD'nin kısaltılmış hâli.

   Alanları taşımak bunları düzeltmez → **S2**.
2. **Sınıf özellikleri iki kart veriyor.** 93 sınıf/alt sınıf satırı hem bir "Class Feature"
   feat'i hem de aynı adlı bir trait ya da eylem veriyor (ör. Unarmored Defense hem feat hem
   trait). Free'de satır işlediğinde karaktere ikisi birden düşüyor → **S3**.
3. **Bizim yazdığımız açıklamalar.** Feat (76), sınıf, tür, alt tür, geçmiş ve canavar kartlarının
   üstteki açıklaması, SRD'de olmayan ve bizim yazdığımız özetler ("A small, sneaky humanoid…").
   Spell, eşya, trait ve eylemde ise üstteki açıklama, alttaki metin alanının birebir aynısı; kartta
   iki kez görünüyor → **S1**.

## 10. Sorular ve kararlar

- **S1 — Kartın üstteki açıklaması.** Öneri: kural metni tek bir yerde, kategorinin kendi metin
  alanında durur (SRD sırasına uygun olarak başlık satırlarından sonra). Üstteki açıklamaya, SRD'de
  bir giriş cümlesi varsa o yazılır (alt sınıfın "Channel Rage into Violent Fury" satırı gibi);
  yoksa boş kalır. Bizim yazdığımız özetler silinir. Alternatif: özetler kalır.
  **Karar (2026-10-28): öneri.** Her kategori kendi fazında uygular.
- **S2 — SRD sapmaları.** Bu işte düzeltilsin mi? Öneri: hayır, ayrı bir iş olsun (~1 900 kartın
  PDF'le karşılaştırılması gerekiyor). Bu iş yalnızca alanları taşır. Yine de "SRD'ye sadık" hedefi
  için bu sapmaların bilinmesi gerekiyor.
  **Karar (2026-10-28): ayrı iş.** Fazlarda görülen yeni sapma §9'a eklenir, düzeltilmez (K13).
- **S3 — Çift kartlar.** Öneri: free SRD'de satır yalnızca feat'i verir. Eylem kartı (Rage gibi)
  feat'in Verilenler'inden zincirle gelir; aynı adlı trait kopyası verilmez.
  **Karar (2026-10-28): öneri.** A5'te uygulanır.
- **S4 — Eşya şarjları.** Büyülü eşyaya Verilenler eklenip şarjlar Havuz'a kaynak olarak gitsin
  mi? Eşya envantere girince "Wand of Magic Missiles: 7" kutucuğu çıkar. Ancak "şafakta 1d6+1" gibi
  kısmi dolum kaynakta yok; dinlenmede dokunulmaz ve kural metinde kalır. Öneri: şimdilik hayır,
  alanlar veri olarak kalsın.
  *A7'nin başında onaylanır.*
- **S5 — SRD'den eksik metinler eklensin mi?** Durum kuralları, silah özelliği / ustalık metinleri
  ve sınıfların "Becoming a…" kutusu, çıkan bayrakların yerine geçtiği için gerekli (öneri: evet).
  Aletlerin "Craft" satırı, Trinket tablosu ve diğer lookup'ların sözlük metinleri isteğe bağlı
  (öneri: Craft evet, diğerleri sonra).
  **Karar (2026-10-28): hepsi.** Gerekli olanlar ve Craft kendi kategorilerinin fazında, Trinket
  tablosu ve diğer sözlük metinleri A9'da.
- **S6 — Ritual / Concentration onay kutuları** kalsın mı? Öneri: kalsın (SRD listelerindeki C/R
  sütunları; filtrede işe yarar).
  *A2'nin başında onaylanır.*

## 11. Yol haritası

İş, her biri kendi başına çalışan ve **uygulama açılarak elle kontrol edilen** fazlara bölündü.
Süreç [ROADMAP.md](ROADMAP.md) §1 ile aynı:

- Bir faz, kullanıcı elle kontrol edip onaylamadan kapanmaz; sonraki faza onaysız geçilmez.
- Bulgular aynı fazda düzeltilir; düzeltmeden sonra yalnız ilgili kontroller ve R turu tekrarlanır.
- Fazın başında, o fazın dayandığı karar ya da onay kullanıcıya hatırlatılır.
- Her faz sonunda faz raporu verilir (ROADMAP §1.1 biçimi) ve bu dokümana **"Ax sonucu"** olarak
  yazılır; durum tablosu güncellenir.
- Commit ve push yalnız kullanıcı isteyince yapılır. Öneri: her faz kendi commit'iyle kapanır.

| Faz | Konu | Alanlar (kopyada) | Boyut | Durum |
|---|---|---|---|---|
| A1 | Altyapı: dönüştürücü, free paket, free dünya | değişmez (görünür fark yok) | M | ⏳ uygulandı, elle kontrol bekliyor |
| A2 | Büyü | 25 → 10; 3 lookup kategorisi çıkar | M | |
| A3 | Grant bloğu, Feat, Trait | 60 → 5, 46 → 3 | M | |
| A4 | Tür, Alt tür | 48 → 5, 48 → 3 | M | |
| A5 | Sınıf, Alt sınıf, Geçmiş | 29 → 14, 9 → 4, 14 → 6 | L | |
| A6 | Canavar, Hayvan, Eylem | 45 → 27, 20 → 3 | M | |
| A7 | Büyülü eşya ve ekipman | 64 → 10; §5.12 | M | |
| A8 | Lookup'lar, oyuncu kartı, NPC, çıkan kategoriler | §5.13–5.15 | M | |
| A9 | SRD sözlük metinleri ve Trinket tablosu | (S5: hepsi) | L | |
| A10 | Kapanış | 521 → 167 doğrulanır | S | |

Sıra bağımlılığa göre: A1 her şeyin altyapısı. A3'teki grant dönüşümünü A4 (tür), A5 (S3) ve A7
(büyülü eşya) kullanır. A8, A1'den beri kaynak adları veride olduğu için Resource Pool'u
kaldırabilir.

### 11.1 Kesin kurallar

[ROADMAP.md](ROADMAP.md) §2'deki K1–K9 aynen geçerli; en önemlisi K1: `builtin/` altında hiçbir
dosya değişmez, `srdCorePackVersion` artmaz. Bu işe özel kurallar:

| # | Kural | Neden |
|---|---|---|
| **K10** | Yerleşik SRD'nin görünüşü değişmez: yerleşik dünyada kart, çeviri ve karakter aynı kalır. Çeviri tablolarına yalnız anahtar **eklenir**; mevcut çeviri silinmez ya da değiştirilmez. `trait.json`'dan `species.json`'a geçen çeviriler kopyalanır, taşınmaz. | Tablolar yerleşikle ortak. |
| **K11** | Free SRD verisini yalnız dönüştürücü üretir (§8). Bir kategorinin şema ve veri değişikliği aynı commit'te yapılır. | Şema ile veri ayrışırsa alan boş görünür ya da veri gizlenir. |
| **K12** | SRD metni uydurulmaz. R4 ve S5 metinleri PDF'ten birebir alınır; birleştirilen satırlar SRD'nin yazım biçimini izler. Her faz, örnek kartları PDF'le karşılaştırır ve sonucu faz raporuna yazar. | §1'in hedefi: SRD'ye sadık free SRD. |
| **K13** | Sapmalar düzeltilmez (S2). Paket verisi SRD'den farklıysa free paket de aynı farkı taşır; görülen yeni sapma §9'a eklenir. | S2 kararı. |
| **K14** | Geçiş kodu yok (§8, "Eski veri"). | ROADMAP Y1. |

### 11.2 Faz kapısı

ROADMAP §3.1'deki G1–G6 ve §3.2'deki R turu her fazda çalışır. G1'in tabanı olarak `1d3eba6b`
yerine `main` ile birleşme tabanı kullanılır (`git merge-base HEAD main`; eski hash branch yeniden
tabanlandığı için yok). Ek olarak:

```
[ ] G7  Dönüştürücü bekçisi:
        flutter test test/domain/services/free_srd_pack_test.dart                     → PASS
        - dönüşmüş her kartın her dolu alanı, kopyanın o kategorisinde tanımlı;
        - hiçbir kart, kopyada olmayan bir kategoriye bağlanmıyor;
        - kopyaya eklenen her yeni alan en az bir kartta dolu;
        - kapanan her kategorinin alan sayısı §5'teki hedefle aynı.
[ ] G8  Türkçe:
        dart run tool/srd_l10n/bin/check_pairs.dart                                    → 0 FAIL
        flutter test test/tool/srd_l10n_coverage_test.dart                             → PASS
        (A2'den itibaren kapsam testi, kapanan kategorilerin free metinlerini de ister)
```

### 11.3 Test dünyaları

- **SRD-A:** A1'de hazır free template'le ("D&D 5e (SRD 5.2.1) - Free Template"), "SRD içeriğini
  ekle" açık kurulur; içinde Aria (Faz 7b'deki karakter). Sonraki her fazda açılınca template
  güncellemesi teklif edilir: **uygula**. Böylece kartlar ve güncelleme yolu birlikte sınanır.
- **Yeni dünya:** her faz, hazır template'le temiz bir dünya da kurar.
- **Yerleşik dünya:** R turu için.

### 11.4 Fazlar

Her faz aynı yapıda: **Amaç · Faz başı · Yapılacaklar · Kapsam dışı · Otomatik testler · Elle
kontrol · Çıkış kriteri.** Her fazda dokunulan yerler aynı: `free_srd_pack.dart` (dönüştürücü),
`free_srd_texts.dart` (SRD metinleri), `free_template.dart` (`_srdCopyFields`: kopyanın alanları),
`assets/srd_l10n/tr/*.json` ve `free_srd_pack_test.dart`. Farklı olanlar fazında yazılı.

Her faz kendi kategorilerinde S1'i de uygular: kural metni kategorinin metin alanında kalır,
üstteki açıklama SRD'nin giriş cümlesi olur ya da boşalır.

---

#### A1 — Altyapı: dönüştürücü, free paket ve free dünya

**Amaç:** free SRD'nin verisi tek dönüştürücüden çıksın ve SRD soylu free dünya bu veriyi
kullansın. Ekranda hiçbir şey değişmez: bugün okurken yapılan dönüşümler veriye yazılır.

**Faz başı:** tam testin temel çizgisi HEAD'de yeniden alınır (bugün 4 kırmızı:
`bundled_pack_resolve`, `srd_tr_entity_card`, `free_character_sheet` uzun dinlenme ve takılan
`entity_card_flush`).

**Yapılacaklar:**

1. **Dönüştürücü** (`free_srd_pack.dart`, saf). Girdisi yerleşik paketin satırları (id, kategori,
   ad, açıklama, alanlar), çıktısı aynı satırların free şekli. Bu fazda yalnız bugünkü okuma
   dönüşümlerini veriye yazar:
   - `srd_read` alanları (sınıf / alt sınıf özellikleri, seviyeyle gelen büyüler, kaynak
     havuzları) → kayıtlı Seviye tablosu satırları ve Verilenler öğeleri (`srdLevelValue`);
   - Canavar / Hayvan'ın düz AC / HP / İnisiyatif'i → Savaş değerleri bloğu (`combatStatsValue`);
   - başlangıç ekipmanı, oyuncu seçimleri, alt tür seçenekleri → markdown yazısı
     (`structuredListAsMarkdown`).
2. **Free paket:** `_ensureFree` satırları dönüştürücüden geçirir; `freeSrdPackVersion` değişince
   paket yeniden kurulur.
3. **Free dünya free paketi bağlar** (§8): dünya oluşturma (`WorldRepositoryImpl.create`) ve
   açılıştaki onarım; `SrdCoreBootstrap.ensureImported` hangi paketi bağlayacağını template'e göre
   seçer. Yerleşik paketi zaten bağlı olan eski dünyaya dokunulmaz (K14).
4. **Yerleşik pakete bakan yerler iki paketi de tanır:** `synthesizeWorldBuiltins`,
   `buildTier0LookupIndex` (`builtin_synth.dart`), `WorldPackageInstaller.buildForeignRefIndex`,
   `builtinPackageIdProvider` ve tüketicileri.
5. **Paket ekranı:** SRD soylu template'le "SRD içeriğini ekle" açık kurulan paketin SRD
   referans kartları free paketten gelir (`packageReferenceOverlayProvider`).
6. **Vault:** yeni `free_srd_pack` notu; `free_srd_levels`, `free_template` notları; Vault-Changelog.

**Kapsam dışı:** şema değişikliği (A2'den itibaren). `srd_read` okuyucuları yerinde kalır; ne
olacakları A10'da kararlaşır.

**Otomatik testler** (`free_srd_pack_test.dart`, yeni):

- **Eşdeğerlik:** her kart ve kopyadaki her alan için dönüşmüş kartın kayıtlı değeri, bugünkü
  okuyucunun eski karttan gösterdiği değerle aynı (`freeFieldValue`). "Ekranda fark yok"un kanıtı
  budur.
- Bekçinin (G7) ilk hâli.
- `_ensureFree`: sürüm değişince paketi yeniden kurar; sürüm aynıysa dokunmaz.
- Dünya: SRD soylu free dünya free paketi bağlar ve kartları sentezlenir (Fighter'ın özellikleri
  kayıtlı, `_id`'li satırlar); yerleşik dünya yerleşik paketi bağlar.

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA1.1 | **SRD-A**'yı kur (§11.3). | SRD kartları gelir; kenar çubuğu bugünkü gibi. |
| EA1.2 | Aria: Fighter ekle, 2. seviyeye çıkar, Wizard ekle. | E7b.2–E7b.4 ile aynı: Second Wind, Action Surge, slotlar, Arcane Recovery. |
| EA1.3 | Barbarian 8; Bard; Warlock 2; 5. seviyede Lucky. | E7b.9–E7b.12 ile aynı Havuz. |
| EA1.4 | Elf + Drow, 3. seviye. | Faerie Fire (E7b.16). |
| EA1.5 | Fighter kartını ve Acolyte'in başlangıç ekipmanını aç. | Seviye tablosu ve ekipman yazısı bugünkü gibi. |
| EA1.6 | Encounter'a Goblin Warrior ve Aria'yı koy. | AC / HP / İnisiyatif dolu. |
| EA1.7 | Packages: free paketi aç; SRD soylu template'le "SRD içeriğini ekle" açık yeni bir paket kur. | Kartlar bugünkü gibi; yeni pakette SRD referans kartları var. |
| EA1.8 | TR modunda SRD-A'da bir büyü ve bir sınıf. | Bugünkü gibi çevrili. |
| EA1.9 | R turu (özellikle R1, R2, R6, R7). | Aynen. |

**Çıkış kriteri:** eşdeğerlik testi yeşil; SRD-A'da Faz 7b'nin SRD kontrolleri aynı sonucu
veriyor; R turu temiz.

**A1 sonucu** (2026-10-28, Linux, Flutter 3.47; elle kontrol bekliyor):

- **Yapılanlar:**
  - **Dönüştürücü** ([free_srd_pack.dart](../../flutter_app/lib/domain/services/free_srd_pack.dart),
    yeni): `freeSrdFields(card, byId)`, kopyadaki her alan için `freeFieldValue`'nun gösterdiğini
    veriye yazar; markdown alanındaki SRD listesi yazıya döner. `freeSrdPackVersion = 1`.
  - **Free paket** (`_ensureFree`): satırlar dönüştürücüden geçer; durumda `_free_version`
    tutulur, değişince paket yeniden kurulur. Ölçüm: ilk kurulum 2 s, yeniden kurulum 0,65 s.
  - **Free dünya:** `SrdCoreBootstrap.ensureImported(free: true)` SRD soylu dünyada free paketi
    bağlar. Dünyada zaten bir yerleşik bağ varsa dokunmaz (K14). Yerleşik dünyada kontrol eskisi
    gibi yalnız çekirdek bağa bakar.
  - **İki paketi tanıyan yerler:** `linkedBuiltinPackage` (`builtin_synth.dart`, yeni): dünyanın
    sentezlediği paket, önce çekirdek, yoksa free. Sentez, Tier-0 dizini ve
    `WorldPackageInstaller.buildForeignRefIndex` bunu kullanır.
  - **Paket ekranı:** `srdReferenceEntitiesProvider` paket adıyla *family* oldu. Free bir paket
    (SRD'li) free paketin kartlarını, diğerleri çekirdeğinkileri gösterir.
  - `entityRefName` ([entity_ref.dart](../../flutter_app/lib/domain/services/entity_ref.dart),
    yeni): markdown alanının SRD listesi yazısı ve dönüştürücü aynı adı kullanır.
  - Vault: yeni `free_srd_pack` notu; `free_srd_levels`, `free_template`,
    `builtin_package_provider`, `world_package_installer`, `entity_ref` notları; World-and-Content
    MoC; Vault-Changelog.
- **Uygulamada verilen kararlar ve plandan farklar:**
  - Okununca boş çıkan ama boş olmayan SRD değeri (sınıf satırlarından verilen seviyeli havuzu
    olan 10 feat'in `resource_pool_grants`'ı) **boş yazılır**; SRD şekliyle bırakılmaz. Ekranda
    fark yok, veri artık free.
  - `builtinPackageIdProvider` ve tüketicileri **değişmedi** (madde 4'te sayılmıştı): yalnız
    paylaşım için (paylaş düğmesi, kenar çubuğunun paylaşım filtresi, oyuncu görünürlüğü); free
    dünya online olmaz (K6). Online katılma (`world_join_service`) da çekirdeği bağlamaya devam
    eder.
  - **Eski SRD'li free paketler:** A1'den önce SRD soylu template'le "SRD içeriğini ekle" açık
    kurulan bir paketin kartları çekirdeğin SRD kartlarına bağlıydı. Paket ekranı artık free
    paketi gösterdiği için bu bağlar boş görünür (K14; testte yeniden kurulur).
  - G1'in ROADMAP'teki tabanı `1d3eba6b` artık repoda yok (branch yeniden tabanlandı). G1, `HEAD`'e
    ve `main` ile birleşme tabanı `0d586cf8`'e karşı denetlendi.
- **Otomatik kapı:**
  - **Temel çizgi** (HEAD `4bbaadee`, ayrı worktree, `entity_card_flush` hariç): 1937 geçti, 3
    kırmızı: `bundled_pack_resolve` M1, `free_character_sheet` uzun dinlenme (RenderFlex
    taşması), `srd_tr_entity_card` TR okuma.
  - G1 boş · G2, G3 yeşil · G4 32 info, 0 warning, 0 error (temel çizgiyle aynı).
  - G5: `free_srd_pack_test` 6/6 (eşdeğerlik, "kayıtlı veri okuma istemez", Fighter / Rage /
    Goblin Warrior / Acolyte örnekleri, bekçinin üç maddesi); `world_free_template_test` +2 (free
    bağ, yerleşik bağ, K14); `package_free_template_test` +1 (paket verisi, sürümle yeniden
    kurulum). Dokunulan dosyaların 45 test dosyası: 477 geçti, 1 kırmızı (temel çizgideki
    `free_character_sheet`).
  - G6 (`entity_card_flush` hariç): 1946 geçti (temel çizgi 1937 + 9 yeni), 3 kırmızı; üçü de
    temel çizgidekiyle aynı. Yeni kırmızı yok. `srd_l10n_coverage_test` yeşil (G8).
  - G7: bekçi yeşil. Bugün kopyada tanımsız dolu alanlar: Class `spell_slots_by_level` (A5),
    Monster / Animal `ac`, `hp_average`, `initiative_modifier` (A6).
  - G8: çeviri tabloları değişmedi.
- **Nasıl açılır:** [ROADMAP.md](ROADMAP.md) §1.2. Paket ilk açılışta kendiliğinden yeniden
  kurulur (sürüm 1).
- **Elle kontrol:** EA1.1–EA1.9 (yukarıda). Önce **SRD-A**'yı yeni kur: A1'den önce kurulan SRD
  soylu dünyalar çekirdek pakette kalır (K14).

---

#### A2 — Büyü (§5.1)

**Amaç:** büyü kartı SRD'deki gibi okunsun: Level · School · Classes · Casting Time · Range ·
Components · Duration · Ritual · Concentration · metin.

**Faz başı:** S6 onayı (Ritual / Concentration kutuları kalır).

**Yapılacaklar:**

1. **Dönüştürücü:** dört yazı SRD biçiminde kurulur.
   - Casting Time: "Action", "Bonus Action", "1 minute", ritüelde "… or Ritual", tepkide
     "Reaction, which you take when …" (`reaction_trigger`).
   - Range: "150 feet", "Self", "Touch"…
   - Components: "V, S, M (a ball of bat guano and sulfur)"; maliyet ve tüketim SRD yazımıyla
     ("… worth 300+ GP, which the spell consumes").
   - Duration: "Instantaneous", "Concentration, up to 1 minute", "Until Dispelled"…
2. **Şema:** §5.1'de çıkan 19 alan kopyadan çıkar, dört yazı alanı eklenir. Çıkan alana bakan
   liste filtresi kalkar.
3. **Çıkan kategoriler:** Duration Unit, Casting Time Unit, Casting Component (kopyadan ve free
   paketin Tier-0 satırlarından).
4. **S1:** büyünün üstteki açıklaması metin alanının tekrarı; boşalır.
5. **Türkçe:**
   - Çıkarma aracı (`tool/srd_l10n/bin/extract.dart`, `collectSrdTexts`) kapanan kategorilerin free
     metinlerini de toplar; kapsam testi bunları da ister.
   - **Türkçe öneri aracı** (yeni, sonraki fazlar da kullanır): kurulan satırın Türkçesini aynı
     kurucuyla, parçaların çevirisinden önerir. Öneriler gözden geçirilir.
   - Yeni etiketler `_schema.json`'a.

**Otomatik testler:**

- Örnek büyüler PDF'teki satırlarla birebir: Fireball, Counterspell (tepki), Identify (ritüel,
  maliyetli malzeme), Raise Dead (tüketilen malzeme), Bless (konsantrasyon), Wish, Fire Bolt.
- 341 büyünün hepsinde dört satır dolu; Spell kategorisi 10 alan (G7).

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA2.1 | SRD-A'yı aç. | Template güncellemesi teklif edilir; uygula. |
| EA2.2 | Fireball, Counterspell, Identify, Raise Dead, Bless'i aç. | Satırlar SRD'deki gibi; kural metni tek yerde, üstte tekrar yok. |
| EA2.3 | Büyü listesinde Level, School, Ritual, Concentration filtreleri. | Çalışır; çıkan alanların filtresi yok. |
| EA2.4 | Kenar çubuğu. | Duration Unit, Casting Time Unit, Casting Component yok. |
| EA2.5 | Aria'nın büyülerinden birine uzun bas. | Önizleme yeni satırlarla. |
| EA2.6 | TR modunda aynı büyüler. | Dört satır Türkçe; sayılar ve birimler aynı. |
| EA2.7 | Yeni dünya. | EA2.2–EA2.6 aynı. |
| EA2.8 | R turu. | Yerleşik Fireball aynen (R1). |

**Çıkış kriteri:** büyüler SRD'nin başlık satırlarıyla okunuyor; G7 ve G8 yeşil.

---

#### A3 — Grant bloğu, Feat ve Trait (§4, §5.7, §5.8)

**Amaç:** "bu kart ne verir" bloğu Verilenler'e ve metne insin; feat ve trait kartı SRD'deki gibi
okunsun.

**Yapılacaklar:**

1. **Grant dönüşümü** (dönüştürücüde tek fonksiyon; A4, A5 ve A7 de kullanır): R5 alanları →
   kartın Verilenler'inde hedef listeli kart öğeleri (§4 tablosu; hedefler oyuncu kartının
   listeleri, Faz 7b'deki `srdFeatureTargets` gibi). `active_while_state_ref` dolu kartın
   grant'leri öğe olmaz. R6 alanları metinde kalır.
2. **R3 taraması testte:** çıkan sayı / işaret alanının (ASI, AC, hız, skill…) bilgisi kartın
   metninde yazıyor. İstisna çıkarsa bilgi SRD biçimiyle metne yazılır (R4).
3. **Şema:** Feat 60 → 5, Trait 46 → 3 (Trait'in `source` filtresi kalkar).
4. **S1:** feat'teki bizim özetimiz boşalır; trait'teki tekrar boşalır.
5. **Türkçe:** yeni metin az (etiketler); feat ve trait kapsam testine girer.

**Otomatik testler:** verilen her R5 kartı Verilenler'de aynı hedefle; Rage feat'inin B/P/S
direnci Verilenler'de **yok**; Lucky'nin Seviye tablosu A1'deki gibi; R3 taraması; G7.

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA3.1 | SRD-A'yı aç, güncellemeyi uygula. | — |
| EA3.2 | Alert, Tough, Lucky, Magic Initiate'i aç. | Category · Prerequisite · Benefits; Lucky'de Seviye tablosu. |
| EA3.3 | 5. seviyedeki Aria'ya Lucky ekle. | Havuz'da Luck Points 3. |
| EA3.4 | 1. seviye bir Barbarian. | Rage gelir; Dirençler'e B/P/S **gelmez**. |
| EA3.5 | Verilenler'inde kart olan bir feat'i ekle, sonra çıkar (adı faz raporunda). | Kart ilgili listeye girer, özet çıkar; çıkarınca geri alma önerisi. |
| EA3.6 | Trait listesi. | Trait Kind filtresi çalışır; Source filtresi yok. |
| EA3.7 | TR; yeni dünya; R turu. | — |

**Çıkış kriteri:** feat ve trait kartları SRD'deki gibi; verilen kartlar karaktere iniyor.

---

#### A4 — Tür ve Alt tür (§5.4, §5.5)

**Amaç:** tür kartı SRD'deki gibi okunsun (Creature Type · Size · Speed · Traits); alt tür,
SRD'nin Lineages tablosunun bir satırı olsun.

**Faz başı:** K13 hatırlatması: Cüce'nin Darkvision'ı pakette 60 ft (SRD'de 120); free paket de 60
ft taşır.

**Yapılacaklar:**

1. **Dönüştürücü:**
   - Size yazısı: boy bilgisi veride yok, `free_srd_texts.dart`'tan (İnsan'da seçim cümlesiyle).
   - Traits markdown: "As a Dwarf, you have these special traits." ve trait kartlarının metni SRD
     biçiminde (`**Darkvision.** …`). Duyu menzili ve tek karttaki `mechanical_notes` bu yazıya
     girer.
   - Verilenler (A3'teki fonksiyon): trait kartları → Traits; duyular, dirençler, eylemler,
     diller → ilgili listeler.
   - Alt tür: Seviye tablosu satırları. Satır yazısı SRD tablosunun hücresi
     (`free_srd_texts.dart`); 1. seviye cantrip'i büyü kartı öğesi; direnç ve eylem Verilenler'de;
     skill / ASI / hız / HP yazıda.
2. **Şema:** Species 48 → 5, Subspecies 48 → 3.
3. **Çevirmen free tarzları da çevirir** (`content_translator.dart`): Seviye tablosu satır yazısı
   ve Verilenler'in yazı öğeleri. Bugün çevrilmiyorlar; Faz 7b'den beri sınıf satırları da
   İngilizce görünüyor.
4. **S1:** tür ve alt tür özetleri boşalır.
5. **Türkçe:** trait çevirileri `species.json`'a kopyalanır (K10); Traits yazısının Türkçesi öneri
   aracıyla, Size ve hücre metinleri sözlükle.

**Otomatik testler:** Dwarf'ın Traits yazısı ve Verilenler'i; Drow satırları (1: Darkvision
yazısı ve Dancing Lights, 3: Faerie Fire, 5: Darkness); Dragonborn soyunun direnci; İnsan'ın Size
yazısı; G7.

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA4.1 | SRD-A'yı aç, güncellemeyi uygula. | — |
| EA4.2 | Dwarf, Human, Dragonborn, Tiefling'i aç. | Creature Type · Size · Speed · Traits; Traits paragrafları SRD'deki gibi. |
| EA4.3 | 1. seviye bir karaktere Elf + Drow koy, 3'e ve 5'e çıkar. | Dancing Lights, Faerie Fire, Darkness; Havuz'da günlük kullanımlar. |
| EA4.4 | Dragonborn + bir soy. | Direnç Dirençler'e, Breath Weapon eylemlere iner. |
| EA4.5 | Aria'nın Tür'ünü değiştir. | Eski türün kartları için geri alma önerisi. |
| EA4.6 | TR modunda tür, alt tür ve bir sınıfın Seviye tablosu. | Traits ve satır yazıları Türkçe. |
| EA4.7 | Yeni dünya; R turu. | — |

**Çıkış kriteri:** tür ve alt tür SRD'deki gibi; Verilenler karaktere iniyor; satır yazıları
çevriliyor.

---

#### A5 — Sınıf, Alt sınıf ve Geçmiş (§5.2, §5.3, §5.6)

**Amaç:** sınıf kartı SRD'nin Core Traits tablosu, "Becoming a…" kutusu ve özellik tablosu olsun;
geçmiş SRD'nin başlıklarıyla okunsun; çift kartlar bitsin (S3).

**Faz başı:** S3 veriyle doğrulanır: 93 satırın listesi ve bir feat'i birden çok sınıf veriyorsa
satırların farklı kart verip vermediği. Çakışma çıkarsa kullanıcıya sorulur.

**Yapılacaklar:**

1. **Dönüştürücü:**
   - Primary Ability, Skill Proficiencies ("Choose 2: …"), Weapon Proficiencies, Tool
     Proficiencies yazıları.
   - Starting Equipment: A1'deki markdown SRD biçimine geçer ("Choose A or B: (A) …; or (B) 75 GP").
   - Becoming a …: SRD kutusu, 12 sınıf (`free_srd_texts.dart`).
   - Druidic / Thieves' Cant: 1. seviye satırında dil kartı öğesi.
   - **S3:** satır feat veriyorsa satırdaki diğer kart öğeleri feat'in Verilenler'ine geçer;
     feat'le aynı adlı trait düşer.
   - Alt sınıf: SRD'nin giriş cümlesi üstteki açıklamaya (S1).
   - Geçmiş: Equipment markdown (3 alan → 1); Verilenler: origin feat → Feat'ler, araç → Araç
     yeterlilikleri (feat'in kendi Verilenler'i zincirle işler).
2. **Şema:** Class 29 → 14, Subclass 9 → 4, Background 14 → 6; sınıf filtresi kalkar. Slotlar
   A1'den beri veride; `caster_kind` ve `spell_slots_by_level` artık okunmaz.
3. **Türkçe:** Becoming a… metinleri; kurulan satırlar ve Seviye tablosu satır yazıları
   (`**Rage.** …`) öneri aracıyla.

**Otomatik testler:** Barbarian'ın Core Traits ve Becoming a… yazısı PDF'le birebir; Fighter'ın
Starting Equipment'ı; S3: Barbarian'ın 1. satırı yalnız Rage feat'ini veriyor, Rage eylemi
feat'in Verilenler'inde; `free_srd_levels_test`'teki Aria senaryoları dönüşmüş veriyle; Acolyte →
Magic Initiate zinciri; G7.

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA5.1 | SRD-A'yı aç, güncellemeyi uygula. | — |
| EA5.2 | Barbarian, Fighter, Wizard, Warlock kartları. | Core Traits satırları, Becoming a…, Starting Equipment, Seviye tablosu SRD'deki gibi. |
| EA5.3 | Yeni bir karakter: Fighter 1 → 2, sonra Wizard. | Özette çift kart yok; Second Wind, Action Surge, slotlar. |
| EA5.4 | Barbarian 1 ve 8. | Rage feat'i ve eylemi; Havuz'da Rage 4. |
| EA5.5 | Path of the Berserker. | Üstte SRD'nin giriş cümlesi. |
| EA5.6 | Background'a Acolyte koy. | Magic Initiate feat'i ve araç yeterliliği gelir; feat'in Verilenler'i işler. |
| EA5.7 | TR; yeni dünya; R turu (R3, R4). | — |

**Çıkış kriteri:** sınıf ve geçmiş kartları SRD'deki gibi; Faz 7b'nin seviye kontrolleri çift
kartsız aynı sonucu veriyor.

---

#### A6 — Canavar, Hayvan ve Eylem (§5.10, §5.11)

**Amaç:** stat bloğu SRD'nin sırasıyla okunsun; eylemin Recharge / günlük kullanımı ve DC'si
metinde olsun.

**Yapılacaklar:**

1. **Dönüştürücü:**
   - Speed yazısı ("30 ft., Fly 60 ft. (hover)").
   - Eylem: Recharge / X/Day metnin başına SRD biçiminde ("(Recharge 5–6)"); DC'si metinde olmayan
     9 karta DC yazılır.
2. **Şema:** Monster / Animal 45 → 27 (düz AC / HP / İnisiyatif ve XP, `initiative_score`, boş
   alanlar çıkar; blok A1'den beri veride), Creature Action 20 → 3.
3. **S1:** canavar özetleri boşalır; eylemdeki tekrar boşalır.
4. **Türkçe:** başına Recharge eklenen metnin anahtarı değişir; Türkçesi öneri aracıyla mevcut
   çeviriden kurulur. Speed yazıları.

**Otomatik testler:** Adult Red Dragon (Fire Breath "(Recharge 5–6)", efsanevi eylemler), Goblin
Warrior, Sprite (DC yazısı), Wolf; `free_encounter` testleri aynı; G7.

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA6.1 | SRD-A'yı aç, güncellemeyi uygula. | — |
| EA6.2 | Adult Red Dragon, Goblin Warrior, Sprite, Wolf. | Speed tek satır; eylemlerde Recharge / DC; üstte özet yok. |
| EA6.3 | Encounter: iki canavar, bir oyuncu; inisiyatif at; HP +/−. | Değerler A1'deki gibi. |
| EA6.4 | Bir eylemin hasar zarına dokun. | Zar atılır. |
| EA6.5 | TR; yeni dünya; R turu (R5). | — |

**Çıkış kriteri:** stat blokları SRD'deki gibi; encounter aynı çalışıyor.

---

#### A7 — Büyülü eşya ve ekipman (§5.9, §5.12)

**Faz başı:** S4 onayı (şarjlar veri olarak kalır, Verilenler eklenmez).

**Yapılacaklar:**

1. **Büyülü eşya** 64 → 10: grant bloğu, `attunement_*`, `body_slot_ref`, `activation`,
   `is_cursed`, `command_word`, `sentient_*` çıkar.
2. **Silah:** `is_melee`. **Zırh:** `Armor Class (AC)` yazısı ("14 + Dex modifier (max 2)", "+2");
   giyme / çıkarma süreleri zırh kategorisi kartlarının metnine (SRD'nin "Donning and Doffing
   Armor" tablosu). **Alet:** `utilize_check_dc` çıkar; `Craft` yazısı (`free_srd_texts.dart`,
   S5). **Macera eşyası** 8 → 4. **Paket:** `content_refs`, `content_quantities` çıkar.
3. **S1:** eşya açıklamalarındaki tekrar boşalır.
4. **Türkçe:** AC yazıları, Craft satırları, giyme / çıkarma metni.

**Otomatik testler:** Chain Mail ve Shield'ın AC yazısı; Alchemist's Supplies'ın Craft satırı
PDF'le birebir; Wand of Magic Missiles'ın şarj alanları; G7.

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA7.1 | SRD-A'yı aç, güncellemeyi uygula. | — |
| EA7.2 | Wand of Magic Missiles, Bag of Holding. | SRD başlık satırı (tür, nadirlik, uyumlanma) ve metin. |
| EA7.3 | Chain Mail, Shield, Longsword, Alchemist's Supplies, Explorer's Pack, Rope. | AC yazısı, Craft satırı; paket içeriği yazıda. |
| EA7.4 | Heavy Armor kategori kartı. | Giyme / çıkarma süresi metinde. |
| EA7.5 | TR; yeni dünya; R turu. | — |

**Çıkış kriteri:** eşya kartları SRD tablolarının sütunlarıyla okunuyor.

---

#### A8 — Lookup'lar, oyuncu kartı, NPC ve çıkan kategoriler (§5.13–5.15)

**Yapılacaklar:**

1. **Lookup'lar:** `icon_name` / `color` çıkar (39 kategori). Condition: bayraklar çıkar,
   `effects`'e SRD durum metni (15). Weapon Property ve Weapon Mastery: makine alanları çıkar, SRD
   metni gelir. Damage Type bayrakları ve §5.14'teki diğer boş / motor alanları çıkar.
2. **Çıkan kategoriler:** Character State, Resource Pool (kaynak adları A1'den beri veride), Body
   Slot, Starter Bundle. "Starting at Higher Levels" tablosu karakter oluşturma rehberine
   (`_srdGuide`) geçer.
3. **Oyuncu kartı:** `current_conditions`, `extra_hp`, `trinket_ref` çıkar. **NPC:**
   `initiative_modifier` çıkar. Rehber adımları ve özet çipleri çıkan bir alana bakıyorsa
   güncellenir.
4. **Türkçe:** durum, özellik ve ustalık metinleri; rehber yazısı.

**Otomatik testler:** Paralyzed, Grappled, Finesse, Topple metinleri PDF'le birebir; çıkan
kategorilere hiçbir kart bağlanmıyor (G7); rehber ve çipler yalnız var olan alanlara bakıyor.

**Elle kontrol:**

| # | Adım | Beklenen |
|---|---|---|
| EA8.1 | SRD-A'yı aç, güncellemeyi uygula. | — |
| EA8.2 | Paralyzed, Grappled, Finesse, Versatile, Topple. | SRD metni var. |
| EA8.3 | Kenar çubuğu. | Character State, Resource Pool, Body Slot, Starter Bundle yok. |
| EA8.4 | Aria'nın kağıdı; encounter'da Aria'ya bir durum ekle. | Durumlar tek yerde (Savaş değerleri); Havuz aynen. |
| EA8.5 | Rehberle yeni bir karakter. | "Starting at Higher Levels" adımı var; adımlar doğru alana gidiyor. |
| EA8.6 | TR; yeni dünya; R turu. | — |

**Çıkış kriteri:** §5'teki bütün kategoriler hedef alanlarında; çıkan 7 kategori yok.

---

#### A9 — SRD sözlük metinleri ve Trinket tablosu (S5: hepsi)

**Faz başı:** PDF'le envanter: hangi lookup'un SRD'de sözlük metni var (Ability, Skill, Creature
Type, Size, Sense, Area Shape, Cover, Illumination, Action, Travel Pace, Lifestyle, Hazard…). Liste
faz raporunda kullanıcıya onaylatılır.

**Yapılacaklar:**

1. Her lookup kartının metin alanına SRD metni (`free_srd_texts.dart`).
2. **Trinket:** SRD'nin 1d100 Trinkets tablosu → 100 Trinket kartı (d100 + metin); free pakete
   eklenir.
3. **Türkçe:** hepsi sözlükle; yeni terim gerekirse kullanıcı onayı (SRD-TR K7).

**Otomatik testler:** örnek sözlük metinleri ve üç Trinket satırı PDF'le birebir; 100 Trinket
kartı, d100 değerleri 1–100 tekrarsız; G7, G8.

**Elle kontrol:** birkaç lookup kartı (Cover, Illumination, Cone, Darkvision); Trinket listesi ve
d100 alanına dokunma; TR; yeni dünya; R turu.

**Çıkış kriteri:** S5'in bütün metinleri free pakette ve Türkçesiyle.

---

#### A10 — Kapanış

**Faz başı:** okurken yapılan SRD dönüşümleri (`srd_read` okuyucuları, markdown alanının liste
çevirisi, `combatStatsValue`'nun düz alan doldurması) A1'den sonra yalnız eski kopyalar için
çalışıyor (K14). Öneri: okuma yolundan kaldırılır, dönüştürücünün içinde kalır. Kullanıcıya
sorulur.

**Yapılacaklar:**

1. Faz başındaki karara göre okuma yolları.
2. Bekçinin son hâli: bütün kategoriler kapalı; §6'nın toplamı (521 → 167) testle doğrulanır.
3. Türkçe: tam `check_pairs`; kapsam testi bütün free paketi okur.
4. Belgeler: bu doküman (durum, sonuçlar), DESIGN §16 (SRD kopyası artık veriyle), ROADMAP §6'ya
   not, vault notları, `_Architecture-Overview`, Vault-Changelog.
5. Tam test ve analiz; tam R turu; uçtan uca tur: hazır template'le dünya → rehberle karakter →
   5. seviye → dinlenme → encounter → `.dmtz` ile taşıma.

**Çıkış kriteri:** kullanıcının uçtan uca turu ve R turu onayı.

---

### 11.5 Kapsam dışı

- **SRD sapmaları** (S2, §9.1): ayrı iş. Free paket yerleşik paketin sapmalarını taşır.
- **Eşya şarjlarının Havuz'a gitmesi** (S4): A7'de onaylanırsa kapsam dışı kalır.
- **Yerleşik SRD template'i ve paketi:** hiç değişmez (K1).
- **Eski SRD kopyalarının ve dünyalarının yeni veriye geçirilmesi** (K14).
