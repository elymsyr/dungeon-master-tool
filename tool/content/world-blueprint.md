# World Blueprint — Campaign → World Aktarım Rehberi

> Bu dosya, agent'lar tarafından campaign/setting içeriğinden world entity'leri
> oluşturulurken kullanılacak **alan sözleşmesidir**. Her Tier-2 kategorisi
> için alan adları, tipleri ve JSON şekilleri burada tanımlıdır.
> 
> **Agent Notu:** Bu dosyayı referans alarak `world-blueprint.json` oluşturun.
> Alanları doldururken kaynak PDF/içerikten bilgiyi doğru kategoriye aktarın —
> **birebir**, özetlemeden. Süreç, çıkarma ve doğrulama: [README.md](README.md).
> Bu dosyadaki tüm örnekler (`The Sunken Keep`, `Amara the Pale`…) **uydurmadır**,
> sadece biçim gösterir; kendi aktarımında kaynakta geçen adları kullan.

## 1. World Entity Nedir?

Her world öğesi bir `Entity`'dir ve `categorySlug` Tier-2 kategorilerinden biridir.
**Agent olarak yapmanız gereken:** PDF/inçerikten okuduğunuz bilgiyi doğru kategoriye
aktararak `world-blueprint.json` dosyasını doldurmak.

**Temel JSON yapısı:**
```json
{
  "id": "<uuid>",
  "name": "Öğe Adı",
  "categorySlug": "<tier-2 slug>",
  "description": "markdown metin",
  "tags": [],
  "imagePath": "",
  "dmNotes": "",
  "source": "",
  "fields": { "...alanlar..." }
}
```

**Kullanılabilir Tier-2 slug'ları:** `npc`, `location`, `scene`, `quest`,
`encounter`, `trap`, `poison`, `curse`, `environmental-effect`, `hireling`,
`service`, `lore`, `campaign`

## 2. Alanlar Nasıl Doldurulur?

**Agent Talimatları:**

1. **Enum alanları** — Kapalı listeden doğru değeri seçin (ör. `danger_level: "Medium"`).
   Liste dışı değerler reddedilir.

2. **Relation alanları** — `{lookup, match, value}` formatında yazın:
   ```json
   "location_ref": {"lookup": "location", "match": "name", "value": "The Antechamber"}
   ```
   `match` türleri: `"name"` (varsayılan), `"slug"`, `"abbreviation"`, `"manual"`.

3. **Medya alanları** — Dosya yollarını modül dizinine göre relative yazın:
   ```json
   "map": "media/Maps/Sunken-Keep-1.webp"
   ```

4. **Metin alanları** — Markdown formatında yazın. Uzun açıklamalar için `description_long` kullanın.

5. **Entity mention'ları (markdown içi link)** — Bir metin başka bir entity'den
   bahsediyorsa link bırakın:
   ```
   "description_long": "Kapıyı @[Rafiq al-Sayyid](entity:npc/Rafiq al-Sayyid) açar."
   ```
   Biçim: `@[Görünen Ad](entity:<kategori-slug>/<Entity Adı>)`. `<Entity Adı>`
   **aynı blueprint'te tanımlı** olmalı; converter onu entity id'sine çevirir ve
   uygulamada link tıklanabilir olur (`markdown_text_area.dart`). Hedef bu
   blueprint'te yoksa build hata verir — SRD ve Tier-0 satırlarının id'si başka
   namespace'ten geldiği için onlara link verilemez.

6. **DM-only alanlar** — `secrets`, `tactics` gibi alanlar oyuncu ekranında gizlenir.

7. **Yazılmayan alanlar** — Şema default'unu alır, yazmanıza gerek yok.

## 3. Kategori Sözleşmeleri

**Agent Notu:** Aşağıdaki tablolar her kategorinin alanlarını gösterir.
PDF'den okuduğunuz bilgiyi bu alanlara aktarın.

Kısaltmalar: **T** = FieldType, **Z** = zorunlu, **D** = default.

### 3.1 NPC — `npc`

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `species_ref` | relation→`species` | | — | Tek uuid string. |
| `class_refs` | relation→`class` (list) | | `[]` | `["<class-uuid>", ...]` |
| `level` | integer | | — | 1..20. |
| `background_ref` | relation→`background` | | — | Tek uuid string. |
| `alignment_ref` | relation→`alignment` | | — | Tek uuid string. |
| `attitude_ref` | relation→`attitude` | ✓ | — | Tek uuid string (lookup: Hostile/Friendly/Neutral...). |
| `location_ref` | relation→`location` | | — | NPC'nin bulunduğu mekan. |
| `faction` | text | | `''` | Serbest metin. |
| `stat_block` | statBlock | | `{STR:10,...}` | Altı anahtarın tamamı int: `{"STR":10,"DEX":12,...}` |
| `combat_stats` | combatStats | | boş string'li map | `{hp:int, max_hp:int, ac:int, speed:text, level:int, initiative:dice, cr:text, xp:int}` |
| `proficiency_bonus` | integer | | `2` | 2..9. |
| `initiative_modifier` | integer | | `0` | İmzalı int. |
| `saving_throws` | proficiencyTable | | 6 preset satır | `{rows:[{name,ability,proficient,expertise,misc}]}` |
| `skills` | proficiencyTable | | 18 preset satır | Aynı şekil. |
| `resistance_refs` / `vulnerability_refs` / `damage_immunity_refs` | relation→`damage-type` (list) | | `[]` | `["<uuid>", ...]` |
| `condition_immunity_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `senses` | relation→`sense` (list) | | `[]` | `["<uuid>", ...]` |
| `passive_perception` | integer | | `10` | 0..30. |
| `language_refs` | relation→`language` (list) | | `[]` | `["<uuid>", ...]` |
| `telepathy_ft` | integer | | — | ≥ 0. |
| `trait_refs` | relation→`trait` (list) | | `[]` | `["<uuid>", ...]` |
| `action_refs` / `special_action_refs` | relation→`creature-action` (list) | | `[]` | `["<uuid>", ...]` |
| `equipment_refs` | relation list→`weapon`,`armor`,`tool`,`adventuring-gear`,`ammunition`,`pack`,`mount`,`vehicle`,`trinket`,`magic-item` | | `[]` | `["<uuid>", ...]` |
| `spell_refs` | relation→`spell` (list) | | `[]` | `["<uuid>", ...]` |
| `goals` / `appearance` / `mannerisms` | markdown | | `''` | Serbest metin. |
| `secrets` | markdown | | `''` | **DM-only.** |

### 3.2 Player Character — `player-character`

Sözleşmenin tamamı [character-blueprint.md](character-blueprint.md) — dünya
blueprint'inde PC aktarılmaz; karakterler `blueprint.json`'a gider.

### 3.3 Applied Condition — `applied-condition`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `condition_ref` | relation→`condition` | ✓ | — | Tek uuid string. |
| `source_entity_ref` | relation→`npc`,`player-character`,`monster`,`animal` | | — | Tek uuid string. |
| `duration_rounds` | integer | | — | ≥ 0; yoksa süresiz. |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `save_frequency` | enum | | — | `none` / `start-of-turn` / `end-of-turn` / `when-damaged` |
| `notes` | textarea | | `''` | Serbest metin. |

### 3.4 Location — `location`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `danger_level` | enum | | — | `Safe` / `Low` / `Medium` / `High` / `Deadly` |
| `environment` | text | | `''` | Serbest metin (ör. "Yeraltı mağarası"). |
| `parent_location_ref` | relation→`location` | | — | Üst mekan (hiyerarşi). |
| `plane_ref` | relation→`plane` | | — | Tek uuid string. |
| `illumination_ref` | relation→`illumination` | | — | Tek uuid string (lookup: Bright/Dim/Darkness...). |
| `hazard_refs` | relation→`hazard` (list) | | `[]` | `["<uuid>", ...]` |
| `description_long` | markdown | | `''` | Mekan açıklaması. |
| `secrets` | markdown | | `''` | **DM-only.** |
| `map` | image (battleMap) | | — | Tek asset yolu: `media/Maps/Cave.webp` |
| `map_per_era` | imagePerEra (battleMap) | | — | `Map<eraId, assetRef>` — era başına harita varyantı. |
| `battlemaps` | image list (battleMap) | | `[]` | `["media/Maps/A1.webp", ...]` |

### 3.5 Scene — `scene`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `location_ref` | relation→`location` | | — | Tek uuid string. |
| `status` | enum | | — | `Planned` / `Active` / `Completed` / `Skipped` |
| `illumination_ref` | relation→`illumination` | | — | Tek uuid string. |
| `travel_pace_ref` | relation→`travel-pace` | | — | Tek uuid string (lookup: Slow/Normal/Fast...). |
| `beats` | markdown | | `''` | Sahne akışı / beat listesi. |
| `npc_refs` | relation→`npc` (list) | | `[]` | Sahnede yer alan NPC'ler. |
| `quest_refs` | relation→`quest` (list) | | `[]` | Bağlı quest'ler. |

### 3.6 Quest — `quest`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `status` | enum | | — | `Not Started` / `Active` / `Completed` / `Failed` |
| `giver_ref` | relation→`npc` | | — | Quest veren NPC. |
| `reward_item_refs` | relation list→`magic-item`,`adventuring-gear`,`weapon`,`armor`,`trinket` | | `[]` | Ödül eşyalar (bitişte otomatik verilir). |
| `reward_xp` | integer | | — | ≥ 0. |
| `reward_gp` | integer | | — | ≥ 0. |
| `reward` | markdown | | `''` | Narrative ödül. |
| `objective` | markdown | | `''` | Görev tanımı. |
| `secrets` | markdown | | `''` | **DM-only.** |

### 3.7 Encounter — `encounter`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `location_ref` | relation→`location` | | — | Tek uuid string. |
| `difficulty` | enum | | — | `Trivial` / `Low` / `Moderate` / `High` / `Deadly` |
| `monsters_refs` | relation→`monster`,`animal` (list) | | `[]` | Savaşçı yaratıklar. |
| `npcs_refs` | relation→`npc` (list) | | `[]` | Savaşa katılan NPC'ler. |
| `environmental_effect_refs` | relation→`environmental-effect` (list) | | `[]` | Aktif çevre etkileri. |
| `trap_refs` | relation→`trap` (list) | | `[]` | Aktif tuzaklar. |
| `setup` | markdown | | `''` | Encounter girişi / sahne kurulumu. |
| `tactics` | markdown | | `''` | **DM-only.** |
| `xp_budget` | integer | | — | ≥ 0. |

### 3.8 Trap — `trap`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `trigger_kind` | enum | | — | `Pressure` / `Tripwire` / `Proximity` / `Sound` / `Magical` / `Touch` / `Other` |
| `trigger` | markdown | | `''` | Narrative tetikleyici. |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `damage_dice` | dice | | — | Zar notasyonu string: `"2d6"`, `"1d20+5"` |
| `damage_type_ref` | relation→`damage-type` | | — | Tek uuid string. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `detection_dc` | integer | | — | 1..30. |
| `disable_dc` | integer | | — | 1..30. |
| `disable_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `countermeasures` | markdown | | `''` | Narrative karşı önlemler. |

### 3.9 Poison — `poison`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `poison_kind` | enum | ✓ | — | `Contact` / `Ingested` / `Inhaled` / `Injury` |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `damage_dice` | dice | | — | `"2d6"` gibi. |
| `damage_type_ref` | relation→`damage-type` | | — | Tek uuid string. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `duration_rounds` | integer | | — | ≥ 0. |
| `effect` | markdown | | `''` | Narrative etki. |
| `cost_gp` | integer | | — | ≥ 0. |

### 3.10 Curse — `curse`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `trigger` | markdown | | `''` | Narrative tetikleyici. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `removed_by_spell_refs` | relation→`spell` (list) | | `[]` | Kaldıran büyüler. |
| `mechanical_notes` | textarea | | `''` | Satır başına bir mekanik kural; düz metin. |
| `effect` | markdown | | `''` | Narrative etki. |
| `removed_by` | markdown | | `''` | Narrative kaldırma koşulu. |

### 3.11 Environmental Effect — `environmental-effect`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `damage_dice` | dice | | — | `"1d10"` gibi. |
| `damage_type_ref` | relation→`damage-type` | | — | Tek uuid string. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `mechanical_notes` | textarea | | `''` | Satır başına bir mekanik kural; düz metin. |
| `effect` | markdown | | `''` | Narrative etki. |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |

### 3.12 Hireling — `hireling`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `skill_ref` | relation→`skill` | | — | Tek uuid string. |
| `daily_cost_cp` | integer | ✓ | — | ≥ 0. |
| `skilled` | boolean | ✓ | — | `true` / `false` |

### 3.13 Service — `service`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `kind` | enum | ✓ | — | `Spellcasting` / `Transport` / `Shelter` / `Other` |
| `cost_cp` | integer | ✓ | — | ≥ 0. |
| `availability` | text | | `''` | Serbest metin. |

### 3.14 Monster — `monster` (Tier-1)

**Agent Notu:** SRD'de olmayan özel yaratıklar bu kategoride world'e eklenir. SRD canavarları için `monster` lookup kullanılır.

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `size_ref` | relation→`size` | ✓ | — | Tek uuid string. |
| `creature_type_ref` | relation→`creature-type` | ✓ | — | Tek uuid string. |
| `tags_line` | text | | `''` | Serbest etiket satırı. |
| `alignment_ref` | relation→`alignment` | | — | Tek uuid string. |
| `alignment_note` | text | | `''` | Hizalama notu (ör. "any evil alignment"). |
| `ac` | integer | ✓ | — | 0..30. |
| `ac_note` | text | | `''` | AC notu (ör. "natural armor"). |
| `initiative_modifier` | integer | ✓ | — | Initiative bonusu. |
| `initiative_score` | integer | ✓ | — | Sabit initiative skoru. |
| `hp_average` | integer | ✓ | — | ≥ 0. |
| `hp_dice` | dice | ✓ | — | Zar notasyonu string. |
| `speed_walk_ft` | integer | ✓ | — | ≥ 0. |
| `speed_burrow_ft` | integer | | — | ≥ 0. |
| `speed_climb_ft` | integer | | — | ≥ 0. |
| `speed_fly_ft` | integer | | — | ≥ 0. |
| `speed_swim_ft` | integer | | — | ≥ 0. |
| `can_hover` | boolean | | — | true/false. |
| `stat_block` | statBlock | | — | `{STR:int, DEX:int, CON:int, INT:int, WIS:int, CHA:int}` |
| `save_bonuses` | proficiencyTable | | — | `{rows:[{name,ability,proficient,expertise,misc}]}` |
| `skill_bonuses` | proficiencyTable | | — | `{rows:[{name,ability,proficient,expertise,misc}]}` |
| `resistance_refs` | relation→`damage-type` (list) | | `[]` | Dayanıklılıklar. |
| `vulnerability_refs` | relation→`damage-type` (list) | | `[]` | Zaaflar. |
| `damage_immunity_refs` | relation→`damage-type` (list) | | `[]` | Hasar bağışıklıkları. |
| `condition_immunity_refs` | relation→`condition` (list) | | `[]` | Durum bağışıklıkları. |
| `resistance_note` | text | | `''` | Dayanıklılık notu. |
| `immunity_note` | text | | `''` | Bağışıklık notu. |
| `senses` | rangedSenseList | | — | `[{sense_ref, range_ft}, ...]` |
| `passive_perception` | integer | ✓ | — | 0..30. |
| `language_refs` | relation→`language` (list) | | `[]` | Dil uuid'leri. |
| `telepathy_ft` | integer | | — | ≥ 0. |
| `language_note` | text | | `''` | Dil notu (ör. "understands Common but can't speak"). |
| `cr` | enum | ✓ | — | `0` / `1/8` / `1/4` / `1/2` / `1`..`30` |
| `xp` | integer | ✓ | — | ≥ 0. |
| `proficiency_bonus` | integer | ✓ | — | 2..9. |
| `cr_helper` | crCalculator | | — | `{atk_bonus?, dpr_avg?, save_dc?}` |
| `trait_refs` | relation→`trait` (list) | | `[]` | Pasif özellikler. |
| `action_refs` | relation→`creature-action` (list) | ✓ | `[]` | Aksiyonlar. |
| `bonus_action_refs` | relation→`creature-action` (list) | | `[]` | Bonus aksiyonlar. |
| `reaction_refs` | relation→`creature-action` (list) | | `[]` | Tepkiler. |
| `legendary_action_uses` | integer | | — | 0..5. |
| `legendary_action_refs` | relation→`creature-action` (list) | | `[]` | Eylem eylemleri. |
| `lair_action_refs` | relation→`creature-action` (list) | | `[]` | In dział eylemleri. |
| `spell_refs` | relation→`spell` (list) | | `[]` | Bilinen büyüler. |
| `gear_refs` | relation list→`adventuring-gear`,`weapon`,`armor` | | `[]` | Taşınan ekipmanlar. |

### 3.15 Magic Item — `magic-item` (Tier-1)

**Agent Notu:** SRD'de olmayan özel eşyalar bu kategoride world'e eklenir. SRD eşyaları için `magic-item` lookup kullanılır.

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `magic_category_ref` | relation→`magic-item-category` | ✓ | — | Tek uuid string. |
| `rarity_ref` | relation→`rarity` | ✓ | — | Tek uuid string. |
| `body_slot_ref` | relation→`body-slot` | | — | Tek uuid string. |
| `requires_attunement` | boolean | ✓ | — | true/false. |
| `attunement_class_refs` | relation→`class` (list) | | `[]` | Sınıf kısıtlamaları. |
| `attunement_species_refs` | relation→`species` (list) | | `[]` | Irk kısıtlamaları. |
| `attunement_alignment_refs` | relation→`alignment` (list) | | `[]` | Hizalama kısıtlamaları. |
| `attunement_min_ability_ref` | relation→`ability` | | — | Minimum yetenek. |
| `attunement_min_ability_score` | integer | | — | 1..30. |
| `attunement_spellcaster_only` | boolean | | — | true/false. |
| `attunement_prereq` | markdown | | `''` | Özel koşul. |
| `is_cursed` | boolean | ✓ | — | Lanetli mi? |
| `base_item_ref` | relation→`weapon`,`armor`,`adventuring-gear` | | — | Temel eşya. |
| `charges_max` | integer | | — | ≥ 0. |
| `charge_regain` | text | | `''` | Yenileme açıklaması. |
| `activation` | enum | ✓ | — | `None` / `Magic Action` / `Bonus Action` / `Reaction` / `Utilize` / `Command Word` / `Consumable` |
| `command_word` | text | | `''` | Komut kelimesi. |
| `effects` | markdown | ✓ | — | Efekt açıklaması. |
| `cost_gp` | float | | — | ≥ 0. (ondalık) |
| `weight_lb` | float | | — | ≥ 0. |
| `is_sentient` | boolean | ✓ | — | Düşünceli mi? |
| `sentient_int` | integer | | — | 3..30. |
| `sentient_wis` | integer | | — | 3..30. |
| `sentient_cha` | integer | | — | 3..30. |
| `sentient_alignment_ref` | relation→`alignment` | | — | Düşünceli hizalama. |
| `sentient_communication` | text | | `''` | İletişim yöntemi. |
| `sentient_senses` | text | | `''` | Duyular. |
| `sentient_special_purpose` | text | | `''` | Özel amaç. |

### 3.16 Lore — `lore` / 3.17 Campaign — `campaign`

Referans doküman kategorileri; harita/encounter katılımcısı değildir.

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `pages` | markdown (list) | | `[]` | Sayfa metinleri listesi. |
| `pdfs` | pdf (list) | | `[]` | Relative PDF yolları listesi. |

### 3.18 Class — `class`

Karakter sınıfı tanımı. SRD dışı sınıflar world'e eklenir; karakter `lookup` ile referans alır.

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `primary_ability_ref` | relation→`ability` | ✓ | — | Birincil yetenek. |
| `secondary_ability_ref` | relation→`ability` | | — | İkincil yetenek. |
| `hit_die` | enum | ✓ | — | `d6` / `d8` / `d10` / `d12` |
| `saving_throw_refs` | relation→`ability` (list) | ✓ | — | Kurtulma taslakları. |
| `skill_proficiency_choice_count` | integer | | — | Seçilen beceri sayısı (0..4). |
| `skill_proficiency_options` | relation→`skill` (list) | | — | Seçenekler. |
| `weapon_proficiency_categories` | relation→`weapon-category` (list) | | — | Silah yetenekleri. |
| `weapon_proficiency_specifics` | relation→`weapon` (list) | | — | Özel silah yetenekleri. |
| `tool_proficiency_count` | integer | | — | Araç yetenek sayısı (0..3). |
| `tool_proficiency_options` | relation→`tool` (list) | | — | Seçenekler. |
| `armor_training_refs` | relation→`armor-category` (list) | | — | Zırh eğitimleri. |
| `granted_tool_refs` | relation→`tool` (list) | | — | Verilen araçlar. |
| `granted_languages` | relation→`language` (list) | | — | Verilen diller. |
| `l1_order_feat_category` | text | | | — |
| `weapon_mastery_filter` | text | | | — |
| `default_inventory_refs` | relation list→`adventuring-gear`,`weapon`,`armor`,`tool`,`pack`,`ammunition` | | | Başlangıç ekipmanları. |
| `equipment_choice_groups` | equipmentChoiceGroups | | | Seçimli ekipman grupları. |
| `starting_gold_dice` | dice | | | Başlangıç altını. |
| `complexity` | enum | | — | `Low` / `Average` / `High` |
| `casting_ability_ref` | relation→`ability` | | | Büyü yeteneği. |
| `caster_kind` | enum | ✓ | — | `None` / `Full` / `Half` / `Third` / `Pact` / `Ritual` |
| `spellcasting_focus_ref` | relation→`arcane-focus`,`druidic-focus`,`holy-symbol` | | | Büyü odağı. |
| `features` | classFeatures | | | Sınıf özellikleri. |
| `cantrips_known_by_level` | levelTable | | | Seviye başına bilinen cantrip'ler. |
| `prepared_spells_by_level` | levelTable | | | Seviye başına hazırlanan büyüler. |
| `spell_slots_by_level` | spellSlotProgression | | | Büyü slotu ilerlemesi. |
| `multiclass_prereq_ability_refs` | relation→`ability` (list) | | | Çoklu sınıf ön koşulu. |
| `multiclass_prereq_min_score` | integer | | | Minimum yetenek (1..30). |
| `multiclass_requirements` | markdown | | | Çoklu sınıf koşulları. |
| `multiclass_granted_proficiencies` | markdown | | | Verilen yetenekler. |

### 3.19 Subclass — `subclass`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `parent_class_ref` | relation→`class` | ✓ | — | Ana sınıf. |
| `granted_at_level` | integer | ✓ | — | Açıldığı seviye (1..20). |
| `bonus_skill_pick_count` | integer | | — | Ek beceri seçimi (0..6). |
| `saving_throw_refs` | relation→`ability` (list) | | | Ek kurtulma taslakları. |
| `weapon_proficiency_categories` | relation→`weapon-category` (list) | | | Ek silah yetenekleri. |
| `armor_training_refs` | relation→`armor-category` (list) | | | Ek zırh eğitimleri. |
| `caster_kind` | enum | | — | Büyüci türü. |
| `features` | classFeatures | | | Alt sınıf özellikleri. |
| `flavor_description` | markdown | | | Hikayevi açıklama. |

### 3.20 Species — `species`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `size_ref` | relation→`size` | ✓ | — | Boyut. |
| `creature_type_ref` | relation→`creature-type` | ✓ | — | Yaratık türü. |
| `age` | text | | | Yaş açıklaması. |
| `speed_ft` | integer | ✓ | — | Hız (0..120). |
| `speed_burrow_ft` | integer | | | Kazma hızı. |
| `speed_climb_ft` | integer | | | Tırmanma hızı. |
| `speed_fly_ft` | integer | | | Uçuş hızı. |
| `speed_swim_ft` | integer | | | Yüzme hızı. |
| `granted_feat_refs` | relation→`feat` (list) | | | Verilen feat'ler. |
| `subspecies_options` | subspeciesOptions | | | Alt tür seçenekleri. |
| **Grant Block** | — | | | Hız hariç tüm grant alanları. |
| `granted_skill_proficiencies` | relation→`skill` (list) | | | Verilen beceriler. |
| `granted_tool_proficiencies` | relation→`tool` (list) | | | Verilen araçlar. |
| `granted_save_proficiencies` | relation→`ability` (list) | | | Verilen kurtulma taslakları. |
| `granted_weapon_proficiencies` | relation→`weapon-category`,`weapon` (list) | | | Verilen silah yetenekleri. |
| `granted_armor_proficiencies` | relation→`armor-category` (list) | | | Verilen zırh yetenekleri. |
| `granted_expertise_skills` | relation→`skill` (list) | | | Uzmanlık alanları. |
| `granted_languages` | relation→`language` (list) | | | Verilen diller. |
| `granted_spell_refs` | relation→`spell` (list) | | | Verilen büyüler. |
| `granted_cantrip_refs` | relation→`spell` (list) | | | Verilen cantrip'ler. |
| `always_prepared_spell_refs` | relation→`spell` (list) | | | Hazır büyüler. |
| `granted_spells_at_level` | spellsAtLevel | | | Seviyede açılan büyüler. |
| `ability_bonuses` | statBlock | | | Yetenek bonusları. |
| `ability_bonus_cap` | integer | | | Bonus tavanı (20..30). |
| `ac_bonus` | integer | | | AC bonusu. |
| `speed_bonus_ft` | integer | | | Hız bonusu. |
| `initiative_bonus` | integer | | | Initiative bonusu. |
| `hp_bonus_flat` | integer | | | Düz HP bonusu. |
| `hp_bonus_per_level` | integer | | | Seviye başına HP bonusu. |
| `extra_attack_count` | integer | | | Ek saldırı hakkı. |
| `extra_attack_count_by_level` | levelTable | | | Seviye başına ek saldırı hakkı. |
| `crit_threshold` | integer | | | Kritik eşik (2..20). |
| `weapon_mastery_count` | integer | | | Silah ustalığı sayısı. |
| `unarmored_ac_base` | integer | | | Zıhsız AC tabanı. |
| `unarmored_ac_abilities` | relation→`ability` (list) | | | Zıhsız AC yetenekleri. |
| `unarmored_ac_shield_allowed` | boolean | | | Kalkan izni. |
| `granted_damage_resistances` | relation→`damage-type` (list) | | | Verilen dayanıklılıklar. |
| `granted_damage_immunities` | relation→`damage-type` (list) | | | Verilen bağışıklıklar. |
| `granted_damage_vulnerabilities` | relation→`damage-type` (list) | | | Verilen zaaflar. |
| `granted_condition_immunities` | relation→`condition` (list) | | | Verilen durum bağışıklıkları. |
| `granted_senses` | rangedSenseList | | | Verilen duyular. |
| `granted_action_refs` | relation→`creature-action` (list) | | | Verilen aksiyonlar. |
| `granted_bonus_action_refs` | relation→`creature-action` (list) | | | Verilen bonus aksiyonlar. |
| `granted_reaction_refs` | relation→`creature-action` (list) | | | Verilen tepkiler. |
| `trait_refs` | relation→`trait` (list) | | | Verilen trait'ler. |
| `resource_pool_grants` | resourcePoolGrants | | | Kaynak havuzu grantları. |
| `player_choices` | playerChoices | | | Oyuncu kararları. |
| `mechanical_notes` | textarea | | | Mekanik notlar. |

### 3.21 Subspecies — `subspecies`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `parent_species_ref` | relation→`species` | ✓ | — | Üst tür. |
| `size_ref` | relation→`size` | | | Boyut. |
| `creature_type_ref` | relation→`creature-type` | | | Yaratık türü. |
| `speed_ft` | integer | | | Hız. |
| `speed_burrow_ft` | integer | | | Kazma hızı. |
| `speed_climb_ft` | integer | | | Tırmanma hızı. |
| `speed_fly_ft` | integer | | | Uçuş hızı. |
| `speed_swim_ft` | integer | | | Yüzme hızı. |
| `legacy_subspecies_key` | text | | | Eski alt tür anahtarı. |
| `granted_feat_refs` | relation→`feat` (list) | | | Verilen feat'ler. |
| **Grant Block** | — | | | Species ile aynı grant alanları. |

### 3.22 Background — `background`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `granted_skill_refs` | relation→`skill` (list) | ✓ | — | Verilen beceriler. |
| `granted_tool_refs` | relation→`tool` (list) | | | Verilen araçlar. |
| `granted_tool_variant_group` | text | | | Araç varyant grubu. |
| `granted_language_count` | integer | | | Dil sayısı (0..10). |
| `granted_languages` | relation→`language` (list) | | | Verilen diller. |
| `ability_score_options` | relation→`ability` (list) | ✓ | — | Yetenek seçimi. |
| `asi_fixed_ability_ref` | relation→`ability` | | | Sabit yetenek. |
| `asi_free_bonus_count` | integer | | | Serbest bonus (0..3). |
| `asi_distribution_options` | enum (list) | ✓ | — | `+2/+1` / `+1/+1/+1` |
| `origin_feat_ref` | relation→`feat` | ✓ | — | Köken feat'i. |
| `default_inventory_refs` | relation list→`adventuring-gear`,`weapon`,`armor`,`tool`,`pack`,`ammunition` | | | Başlangıç ekipmanları. |
| `equipment_choice_groups` | equipmentChoiceGroups | | | Seçimli ekipman grupları. |
| `starting_gold_gp` | integer | | | Başlangıç altını (≥0). |
| `gold_alternative_gp` | integer | | | Alternatif altın (≥0). |

### 3.23 Feat — `feat`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `category_ref` | relation→`feat-category` | ✓ | — | Feat kategorisi. |
| `prereq_ability_ref` | relation→`ability` | | | Ön koşul yeteneği. |
| `prereq_min_score` | integer | | | Minimum skor (1..30). |
| `prereq_class_refs` | relation→`class` (list) | | | Sınıf ön koşulu. |
| `prereq_species_refs` | relation→`species` (list) | | | Irk ön koşulu. |
| `prereq_min_character_level` | integer | | | Minimum seviye (1..20). |
| `prereq_requires_spellcasting` | boolean | | | Büyücü ön koşulu. |
| `prerequisite` | markdown | | | Özel ön koşul. |
| `repeatable` | boolean | ✓ | — | Tekrarlanabilir mi? |
| `repeatable_limit` | integer | | | Tekrar limiti (1..20). |
| `chooseable` | boolean | | | Seçilebilir mi? (default: true) |
| `asi_ability_options` | relation→`ability` (list) | | | ASI yetenek seçenekleri. |
| `asi_amount` | integer | | | ASI miktarı (0..2). |
| `asi_max_score` | integer | | | ASI max skor (1..30). |
| `bonus_skill_pick_count` | integer | | | Ek beceri seçimi (0..4). |
| `bonus_expertise_pick_count` | integer | | | Ek uzmanlık seçimi (0..4). |
| `grants_save_prof_from_asi` | boolean | | | ASI'dan kurtulma verir mi? |
| `benefits` | markdown | ✓ | — | Faydalar. |
| **Grant Block** | — | | | Tüm grant alanları. |
| `granted_skill_proficiencies` | relation→`skill` (list) | | | Verilen beceriler. |
| `granted_tool_proficiencies` | relation→`tool` (list) | | | Verilen araçlar. |
| `granted_save_proficiencies` | relation→`ability` (list) | | | Verilen kurtulma taslakları. |
| `granted_weapon_proficiencies` | relation→`weapon-category`,`weapon` (list) | | | Verilen silah yetenekleri. |
| `granted_armor_proficiencies` | relation→`armor-category` (list) | | | Verilen zırh yetenekleri. |
| `granted_expertise_skills` | relation→`skill` (list) | | | Uzmanlık alanları. |
| `granted_languages` | relation→`language` (list) | | | Verilen diller. |
| `granted_spell_refs` | relation→`spell` (list) | | | Verilen büyüler. |
| `granted_cantrip_refs` | relation→`spell` (list) | | | Verilen cantrip'ler. |
| `always_prepared_spell_refs` | relation→`spell` (list) | | | Hazır büyüler. |
| `granted_spells_at_level` | spellsAtLevel | | | Seviyede açılan büyüler. |
| `ability_bonuses` | statBlock | | | Yetenek bonusları. |
| `ac_bonus` | integer | | | AC bonusu. |
| `speed_bonus_ft` | integer | | | Hız bonusu. |
| `initiative_bonus` | integer | | | Initiative bonusu. |
| `hp_bonus_flat` | integer | | | Düz HP bonusu. |
| `hp_bonus_per_level` | integer | | | Seviye başına HP bonusu. |
| `extra_attack_count` | integer | | | Ek saldırı hakkı. |
| `extra_attack_count_by_level` | levelTable | | | Seviye başına ek saldırı hakkı. |
| `crit_threshold` | integer | | | Kritik eşik (2..20). |
| `weapon_mastery_count` | integer | | | Silah ustalığı sayısı. |
| `granted_damage_resistances` | relation→`damage-type` (list) | | | Verilen dayanıklılıklar. |
| `granted_damage_immunities` | relation→`damage-type` (list) | | | Verilen bağışıklıklar. |
| `granted_damage_vulnerabilities` | relation→`damage-type` (list) | | | Verilen zaaflar. |
| `granted_condition_immunities` | relation→`condition` (list) | | | Verilen durum bağışıklıkları. |
| `granted_senses` | rangedSenseList | | | Verilen duyular. |
| `granted_action_refs` | relation→`creature-action` (list) | | | Verilen aksiyonlar. |
| `granted_bonus_action_refs` | relation→`creature-action` (list) | | | Verilen bonus aksiyonlar. |
| `granted_reaction_refs` | relation→`creature-action` (list) | | | Verilen tepkiler. |
| `trait_refs` | relation→`trait` (list) | | | Verilen trait'ler. |
| `resource_pool_grants` | resourcePoolGrants | | | Kaynak havuzu grantları. |
| `player_choices` | playerChoices | | | Oyuncu kararları. |
| `mechanical_notes` | textarea | | | Mekanik notlar. |

### 3.24 Spell — `spell`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `level` | integer | ✓ | — | Büyü seviyesi (0..9). |
| `school_ref` | relation→`spell-school` | ✓ | — | Okul. |
| `casting_time_amount` | integer | ✓ | — | Büyü süresi miktarı. |
| `casting_time_unit_ref` | relation→`casting-time-unit` | ✓ | — | Büyü süresi birimi. |
| `reaction_trigger` | text | | | Tepki tetikleyici. |
| `is_ritual` | boolean | ✓ | — | Ritüel mi? |
| `range_type` | enum | ✓ | — | `Self` / `Touch` / `Ranged` / `Sight` / `Unlimited` |
| `range_ft` | integer | | | Menzil (≥0). |
| `area_shape_ref` | relation→`area-shape` | | | Alan şekli. |
| `area_size_ft` | integer | | | Alan boyutu. |
| `components` | relation→`casting-component` (list) | ✓ | — | Bileşenler. |
| `material_description` | text | | | Malzeme açıklaması. |
| `material_cost_gp` | integer | | | Malzeme maliyeti. |
| `material_consumed` | boolean | | | Tüketilen malzeme? |
| `duration_unit_ref` | relation→`duration-unit` | ✓ | — | Süre birimi. |
| `duration_amount` | integer | | | Süre miktarı. |
| `requires_concentration` | boolean | ✓ | — | Konsantrasyon gerektirir mi? |
| `description` | markdown | ✓ | — | Açıklama. |
| `effects` | spellEffectList | | | Efekt listesi. |
| `at_higher_levels_text` | levelTextTable | | | Yüksek seviye açıklaması. |
| `class_refs` | relation→`class` (list) | ✓ | — | Sınıflar. |
| `damage_type_refs` | relation→`damage-type` (list) | | | Hasar türleri. |
| `save_ability_ref` | relation→`ability` | | | Kurtulma yeteneği. |
| `attack_type` | enum | | | `None` / `Melee` / `Ranged` |
| `applied_condition_refs` | relation→`condition` (list) | | | Uygulanan durumlar. |

### 3.25 Weapon — `weapon`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `category_ref` | relation→`weapon-category` | ✓ | — | Silah kategorisi. |
| `is_melee` | boolean | ✓ | — | Yakın dövüş mü? |
| `damage_dice` | dice | ✓ | — | Hasar zarı. |
| `damage_type_ref` | relation→`damage-type` | ✓ | — | Hasar türü. |
| `property_refs` | relation→`weapon-property` (list) | | | Özellikler. |
| `mastery_ref` | relation→`weapon-mastery` | ✓ | — | Ustalık. |
| `normal_range_ft` | integer | | | Normal menzil. |
| `long_range_ft` | integer | | | Uzun menzil. |
| `versatile_damage_dice` | dice | | | Çok yönlü hasar. |
| `ammunition_type_ref` | relation→`ammunition` | | | Mermi türü. |
| `cost_gp` | float | ✓ | — | Maliyet (≥0). |
| `weight_lb` | float | ✓ | — | Ağırlık (≥0). |

### 3.26 Armor — `armor`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `category_ref` | relation→`armor-category` | ✓ | — | Zırh kategorisi. |
| `base_ac` | integer | ✓ | — | Temel AC (0..20). |
| `adds_dex` | boolean | ✓ | — | DEX bonusu ekler mi? |
| `dex_cap` | integer | | | DEX tavanı (0..10). |
| `strength_requirement` | integer | | | Güç gereksinimi (0..30). |
| `stealth_disadvantage` | boolean | ✓ | — | Stealth dezavantajı? |
| `don_time_minutes` | integer | ✓ | — | Giyme süresi (≥0). |
| `doff_time_minutes` | integer | ✓ | — | Çıkarma süresi (≥0). |
| `cost_gp` | float | ✓ | — | Maliyet (≥0). |
| `weight_lb` | float | ✓ | — | Ağırlık (≥0). |

### 3.27 Tool — `tool`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `category_ref` | relation→`tool-category` | ✓ | — | Araç kategorisi. |
| `variant_of_ref` | relation→`tool` | | | Varyant olduğu araç. |
| `ability_ref` | relation→`ability` | ✓ | — | İlgili yetenek. |
| `utilize_check_dc` | integer | | | Kullanım DC'si. |
| `utilize_description` | textarea | | | Kullanım açıklaması. |
| `craftable_items` | relation→`adventuring-gear` (list) | | | Üretilebilir eşyalar. |
| `cost_gp` | float | ✓ | — | Maliyet (≥0). |
| `weight_lb` | float | ✓ | — | Ağırlık (≥0). |

### 3.28 Adventuring Gear — `adventuring-gear`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `cost_cp` | integer | ✓ | — | Maliyet (copper, ≥0). |
| `weight_lb` | float | ✓ | — | Ağırlık (≥0). |
| `utilize_check_dc` | integer | | | Kullanım DC'si. |
| `utilize_ability_ref` | relation→`ability` | | | Kullanım yeteneği. |
| `utilize_description` | markdown | | | Kullanım açıklaması. |
| `consumable` | boolean | ✓ | — | Tüketilebilir mi? |
| `is_focus` | boolean | | | Büyü odağı mı? |
| `focus_kind_ref` | relation→`arcane-focus`,`druidic-focus`,`holy-symbol` | | | Odak türü. |

### 3.29 Ammunition — `ammunition`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `storage_container` | text | | | Depolama kabı. |
| `cost_gp` | float | ✓ | — | Maliyet (≥0). |
| `weight_lb` | float | ✓ | — | Ağırlık (≥0). |
| `bundle_count` | integer | ✓ | — | Paket adedi. |

### 3.30 Equipment Pack — `pack`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `cost_gp` | integer | ✓ | — | Maliyet (≥0). |
| `weight_lb` | float | | | Ağırlık (≥0). |
| `content_refs` | relation list→`adventuring-gear`,`weapon`,`armor`,`tool`,`ammunition` | | | İçerik eşyaları. |
| `content_quantities` | levelTable | | | İçerik miktarları. |
| `contents` | markdown | | | İçerik açıklaması. |

### 3.31 Mount — `mount`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `carrying_capacity_lb` | integer | ✓ | — | Taşıma kapasitesi (≥0). |
| `speed_ft` | integer | ✓ | — | Hız (≥0). |
| `cost_gp` | integer | ✓ | — | Maliyet (≥0). |
| `is_trained` | boolean | | | Eğitimli mi? |

### 3.32 Vehicle — `vehicle`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `vehicle_kind` | enum | ✓ | — | `Land` / `Waterborne` / `Airborne` |
| `speed_mph` | float | | | Hız (mph). |
| `crew` | integer | | | Mürettebat. |
| `passengers` | integer | | | Yolcu kapasitesi. |
| `cargo_tons` | float | | | Kargo kapasitesi (ton). |
| `ac` | integer | | | AC. |
| `hp` | integer | | | HP. |
| `damage_threshold` | integer | | | Hasar eşiği. |
| `cost_gp` | integer | | | Maliyet (≥0). |

### 3.33 Trinket — `trinket`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `roll_d100` | integer | ✓ | — | Zar sonucu (1..100). |
| `description` | markdown | ✓ | — | Açıklama. |

### 3.34 Creature Action — `creature-action`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `source` | text | | | Kaynak. |
| `action_type` | enum | ✓ | — | `Action` / `Bonus Action` / `Reaction` / `Legendary Action` / `Lair Action` / `Mythic Action` / `Free` |
| `recharge_kind` | enum | | | `None` / `Roll` / `Short Rest` / `Long Rest` / `Day` / `Dawn` / `Dusk` |
| `recharge_min_roll` | integer | | | Minimum zar (1..6). |
| `recharge` | text | | | Yenileme açıklaması. |
| `uses_per_day` | integer | | | Günlük kullanım (≥0). |
| `legendary_action_cost` | integer | | | Maliyet (1..5). |
| `is_attack` | boolean | | | Saldırı mı? |
| `attack_kind` | enum | | | `Melee Weapon` / `Ranged Weapon` / `Melee Spell` / `Ranged Spell` |
| `attack_bonus` | integer | | | Saldırı bonusu. |
| `reach_ft` | integer | | | Uzunluk (≥0). |
| `range_normal_ft` | integer | | | Normal menzil. |
| `range_long_ft` | integer | | | Uzun menzil. |
| `damage_dice` | dice | | | Hasar zarı. |
| `damage_type_ref` | relation→`damage-type` | | | Hasar türü. |
| `save_dc` | integer | | | Kurtulma DC (1..30). |
| `save_ability_ref` | relation→`ability` | | | Kurtulma yeteneği. |
| `applied_condition_refs` | relation→`condition` (list) | | | Uygulanan durumlar. |
| `effects` | spellEffectList | | | Efekt listesi. |
| `description` | markdown | ✓ | — | Açıklama. |

### 3.35 Trait — `trait`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `source` | text | | | Kaynak. |
| `trait_kind` | enum | | | `Passive` / `Sense` / `Defensive` / `Movement` / `Spellcasting` / `Other` |
| `description` | markdown | | | Açıklama. |
| `benefits` | markdown | | | Faydalar. |
| `chooseable` | boolean | | | Seçilebilir mi? (default: false) |
| **Grant Block** | — | | | Tüm grant alanları (trait_refs hariç). |

### 3.36 Animal — `animal`

Monster ile aynı alanlara sahiptir (§3.14 Monster'a bakın). Farkı: `animal` slug'u ile world'e eklenir.

### 3.37 Starter Bundle — `starter-bundle`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `starting_level` | integer | ✓ | — | Başlangıç seviyesi (1..20). |
| `starting_gold_gp` | integer | ✓ | — | Başlangıç altını (≥0). |
| `magic_item_choice_refs` | relation→`magic-item` (list) | | | Seçilebilir sihirli eşyalar. |
| `magic_item_choice_count` | integer | | | Seçim sayısı (0..5). |
| `granted_magic_items` | relation→`magic-item` (list) | | | Verilen sihirli eşyalar. |
| `notes` | markdown | | | Notlar. |

## 4. Blueprint JSON Formatı

**Agent Talimatları:** `world-blueprint.json` dosyasını şu formatta oluşturun:

```json
{
  "version": "1.0.0",
  "source_system": "shadowdark",
  "app_schema": "builtin-dnd5e-default-v2",
  "categories": {
    "npc": [...],
    "location": [...],
    "encounter": [...]
  },
  "cross_references": []
}
```

**Dönüşüm kuralları:**
1. `{lookup, match, value}` → hedef entity'yi bulup `id` yazın
2. Enum alanları birebir string olarak yazın
3. `combat_stats.speed` **text** olarak: `"30 ft"`
4. Dice alanları string: `"2d6"`
5. Medya yolları modül dizinine göre relative

**Kaynak kontrolü:** Entity'nin `source` alanı normalde manifest'in `title`'ı
olur — ayrıca yazmanız gerekmez. Tek istisna **girdi başına atıf** taşıyan
paketler (topluluk derlemeleri): satıra `mapping`'in **kardeşi** olarak bir
`source` koyun, o satır için manifest başlığını ezer.

```json
{
  "source_name": "Gaea's Grasp, 5 charges",
  "source": "Glass Bird Games",
  "mapping": { "name": "Gaea's Grasp, 5 charges", "...": "..." }
}
```

`mapping`'in **içine** yazmayın: `creature-action` ve `trait` şemaları gerçek
bir `source` alanı tanımlıyor, orada kategori alanı kazanır.

### Örnek world blueprint

Aşağıdaki içerik uydurma; sadece JSON biçimini gösterir.

```json
{
  "version": "1.0.0",
  "source_system": "shadowdark",
  "app_schema": "builtin-dnd5e-default-v2",
  "categories": {
    "npc": [
      {
        "source_name": "Amara the Pale",
        "mapping": {
          "name": "Amara the Pale",
          "species_ref": {"lookup": "species", "match": "name", "value": "Human"},
          "class_refs": [{"lookup": "class", "match": "name", "value": "Wizard"}],
          "level": 9,
          "alignment_ref": {"lookup": "alignment", "match": "name", "value": "Neutral"},
          "attitude_ref": {"lookup": "attitude", "match": "name", "value": "Friendly"},
          "location_ref": {"lookup": "location", "match": "name", "value": "The Sunken Keep"},
          "stat_block": {"STR": 8, "DEX": 14, "CON": 12, "INT": 18, "WIS": 13, "CHA": 15},
          "combat_stats": {"hp": 44, "max_hp": 44, "ac": 12, "speed": "30 ft"},
          "description": "Sarayın son kütüphanecisi, partiye rehberlik eder.",
          "secrets": "Aslında dev kralın torunu."
        }
      }
    ],
    "location": [
      {
        "source_name": "The Sunken Keep",
        "mapping": {
          "name": "The Sunken Keep",
          "danger_level": "Deadly",
          "environment": "Dev harabeleri",
          "illumination_ref": {"lookup": "illumination", "match": "name", "value": "Dim"},
          "description_long": "Çölün ortasında, 99 şeytanın beklediği saray.",
          "map": "media/Maps/Sunken-Keep-1.webp"
        }
      },
      {
        "source_name": "The Antechamber",
        "mapping": {
          "name": "The Antechamber",
          "danger_level": "High",
          "parent_location_ref": {"lookup": "location", "match": "name", "value": "The Sunken Keep"},
          "description_long": "Giriş holü; tavan 60 ft."
        }
      }
    ],
    "scene": [
      {
        "source_name": "Arrival at the Gate",
        "mapping": {
          "name": "Arrival at the Gate",
          "status": "Planned",
          "location_ref": {"lookup": "location", "match": "name", "value": "The Antechamber"},
          "beats": "1. Kapı gıcırdar ve kapanır.\n2. Parti feneri fark eder.\n3. İlk şeytan görünür.",
          "npc_refs": [{"lookup": "npc", "match": "name", "value": "Amara the Pale"}]
        }
      }
    ],
    "quest": [
      {
        "source_name": "Break the Binding",
        "mapping": {
          "name": "Break the Binding",
          "status": "Not Started",
          "giver_ref": {"lookup": "npc", "match": "name", "value": "Amara the Pale"},
          "objective": "Sarayın 99 bağını kır ve kralı serbest bırak.",
          "reward_xp": 2500,
          "reward_gp": 800,
          "secrets": "Son bağ ancak birinin kendini feda etmesiyle kırılır."
        }
      }
    ],
    "encounter": [
      {
        "source_name": "Antechamber Ambush",
        "mapping": {
          "name": "Antechamber Ambush",
          "location_ref": {"lookup": "location", "match": "name", "value": "The Antechamber"},
          "difficulty": "Moderate",
          "monsters_refs": [
            {"lookup": "monster", "match": "name", "value": "Imp", "count": 4}
          ],
          "trap_refs": [{"lookup": "trap", "match": "name", "value": "Floor Spikes"}],
          "setup": "Parti holün ortasına vardığında imps gölgelerden çıkar.",
          "tactics": "İmpler önce büyücüye odaklanır, iki turda bir geri çekilir.",
          "xp_budget": 800
        }
      }
    ],
    "trap": [
      {
        "source_name": "Floor Spikes",
        "mapping": {
          "name": "Floor Spikes",
          "trigger_kind": "Pressure",
          "trigger": "Giriş holünün orta taşına basılınca.",
          "save_dc": 14,
          "save_ability_ref": {"lookup": "ability", "match": "name", "value": "Dexterity"},
          "damage_dice": "3d10",
          "damage_type_ref": {"lookup": "damage-type", "match": "name", "value": "Piercing"},
          "detection_dc": 15,
          "disable_dc": 13,
          "disable_ability_ref": {"lookup": "ability", "match": "name", "value": "Intelligence"}
        }
      }
    ],
    "environmental-effect": [
      {
        "source_name": "Wailing Winds",
        "mapping": {
          "name": "Wailing Winds",
          "effect": "Saray avlusunda sürekli uluyan rüzgar.",
          "mechanical_notes": "Uzun menzilli saldırılar disadvantage.\nFısıldamak işitilmez."
        }
      }
    ]
  },
  "cross_references": []
}
```

## 5. Cross-Referanslar

**Agent Talimatları:** Entity'ler arası ilişkileri `cross_references` dizisinde tanımlayın.

**Format:**
```json
{
  "cross_references": [
    {
      "from_category": "npc",
      "from_name": "Amara the Pale",
      "from_field": "location_ref",
      "to_category": "location",
      "to_name": "The Sunken Keep"
    }
  ]
}
```

**Ne zaman kullanılır:**
- Blueprint içinde isimle referans verilen ilişkiler otomatik çözülür
- `cross_references` sadece **başka bir blueprint dosyasına** (ör. karakter → NPC) veya karmaşık ilişkiler için kullanılır

## 6. Eşleme Tablosu (Campaign → World)

**Agent Referansı:** PDF/inçerikten okuduğunuz içerikleri şu kategorilere aktarın.

### 6.1 Ana Kategori Eşleme

| Kaynak Tür | Uygulama Kategorisi | Ne Zaman Kullanılır | Örnek |
|---|---|---|---|
| Person / Character | `npc` |faction liderleri, mağazacılar, rehberler, önemli karakterler | "Amara the Pale", "Karim the Drifted Lord" |
| Place / Region / Room | `location` | Mekanlar, binalar, bölgeler, odalar (hiyerarşik) | "The Sunken Keep", "The Antechamber", "The Upper Level" |
| Combat / Encounter | `encounter` | Savaş planları, canavar/NPC grupları | "Antechamber Ambush", "The Keeper's Lair" |
| Quest / Mission / Goal | `quest` | Görevler, macera arc'ları, hedefler | "Reach the Keep", "Stop the Binding" |
| Scene / Beat / Act | `scene` | Senaryo akışı, sahne planları, beat listesi | "Arrival at the Gate", "The Keeper's Revelation" |
| Trap / Hazard | `trap` | Tuzaklar, mekanik tuzaklar | "Collapsing Ceiling", "Flame Jet" |
| Poison | `poison` | Zehirler (poison_kind zorunlu: Contact/Ingested/Inhaled/Injury) | "Assassin's Blood", "Crawler Mucus" |
| Curse | `curse` | Lanetler, mekanikler `mechanical_notes` düz metin | "Mummy's Rot", "Bag of Devouring" |
| Environmental Effect | `environmental-effect` | Çevresel etkiler, aura'lar, hava koşulları | "Guardian's Fire Aura", "Crumbling Ruins" |
| Hireling | `hireling` | Kiralık askerler (daily_cost_cp + skilled zorunlu) | "Mercenary Guard", "Porter" |
| Service | `service` | Hizmetler (kind + cost_cp zorunlu: Spellcasting/Transport/Shelter/Other) | "Healing", "Transportation" |
| Handout / Lore / Document | `lore` | Dünya bilgisi, el yazmaları, tarihçe | "The History of the Keep" |
| Campaign Guide / Overview | `campaign` | Genel kampanya notları, macera özeti | "The Sunken Keep" |
| Magic Item | → `magic-item` (Tier-1) | World'e eklenen özel eşyalar (SRD'de yoksa) | "Keeper's Artifact", "Blessed Scimitar" |
| Monster / Creature | → `monster` (Tier-1) | Özel yaratıklar (SRD'de yoksa) | "Clockwork Hound", "Ash Crow" |

### 6.2 Medya Eşleştirme

| Medya Türü | Hedef Alan | Format | Not |
|---|---|---|---|
| Battlemap / Harita | `location.map` | Tek dosya: `"media/Maps/Cave.webp"` | Ana harita için |
| Battlemap (çoklu) | `location.battlemaps` | Liste: `["media/Maps/A1.webp", ...]` | Çoklu harita varyantları |
| Battlemap (era) | `location.map_per_era` | Map: `{"era1": "media/Maps/v1.webp"}` | Dönem başına harita |
| Token / Canavar resmi | `encounter.monsters_refs` | SRD'de varsa lookup, yoksa monster entity | Canavar token'ları |
| Token / NPC resmi | `npc.imagePath` | Tek dosya: `"media/Tokens/NPC.webp"` | NPC portresi |
| PDF / El yazması | `lore.pdfs` | Liste: `["media/Handouts/Doc.pdf"]` | Döküman PDF'leri |
| PDF / Kampanya | `campaign.pdfs` | Liste: `["99-Devils.pdf"]` | Ana macera PDF'i |
| Handout / Görsel | `lore.pages` | Markdown olarak ekle | El yazması görselleri |
| Cover Image | `campaign.imagePath` | Tek dosya: `"media/Title-Image.webp"` | Kapak resmi |
| GCS / Karakter | `blueprint.json` | Ayrı dosya | PC'ler world'e değil, blueprint'e gider |

### 6.3 SRD Kontrol Tablosu

| İçerik Türü | SRD'de Var mı? | Aksiyon |
|---|---|---|
| Canavar (Goblin, Orc, Dragon...) | Evet → `monster` lookup | Blueprint'e ekleme, referans ver |
| Sihir (Fireball, Healing Word...) | Evet → `spell` lookup | Blueprint'e ekleme, referans ver |
| Silah (Sword, Bow...) | Evet → `weapon` lookup | Blueprint'e ekleme, referans ver |
| Zırh (Chain Mail, Shield...) | Evet → `armor` lookup | Blueprint'e ekleme, referans ver |
| Sınıf (Fighter, Wizard...) | Evet → `class` lookup | Blueprint'e ekleme, referans ver |
| Irk (Human, Elf...) | Evet → `species` lookup | Blueprint'e ekleme, referans ver |
| Background (Soldier, Sage...) | Evet → `background` lookup | Blueprint'e ekleme, referans ver |
| Özel canavar (Clockwork Hound...) | Hayır → `monster` entity oluştur | Blueprint'e ekle |
| Özel eşya (Keeper's Ring...) | Hayır → `magic-item` entity oluştur | Blueprint'e ekle |
| Özel tuzak (Keep Spikes...) | Hayır → `trap` entity oluştur | Blueprint'e ekle |
| Özel zehir (Custom Poison...) | Hayır → `poison` entity oluştur | Blueprint'e ekle |

### 6.4 Hiyerarşi Kuralları

| Durum | Kural | Örnek |
|---|---|---|
| Ana mekan | `parent_location_ref` boş | "The Sunken Keep" |
| Alt mekan | `parent_location_ref` ile üst mekana bağla | "The Antechamber" → "The Sunken Keep" |
| Encounter mekanı | `encounter.location_ref` ile location'a bağla | "Antechamber Ambush" → "The Antechamber" |
| NPC mekanı | `npc.location_ref` ile location'a bağla | "Amara the Pale" → "The Vault" |
| Scene mekanı | `scene.location_ref` ile location'a bağla | "The Keeper's Revelation" → "The Vault" |
