# Karakter Blueprint — Player Character Aktarım Rehberi

> Bu dosya, agent'lar tarafından karakterleri `player-character` kategorisine
> aktarırken kullanılacak **alan sözleşmesidir**. Her alanın tipi, zorunluluğu
> ve JSON şekli burada tanımlıdır.
> 
> **Agent Notu:** Bu dosyayı referans alarak `blueprint.json` oluşturun.
> Kaynak PDF/GCS dosyalarından karakter bilgilerini buradaki alanlara eşleştirin.
> Süreç, doğrulama ve içerik sadakati kuralları: [README.md](README.md).

## 1. Karakter Nedir?

Karakter, `categorySlug: "player-character"` olan bir `Entity`'dir.
**Agent olarak yapmanız gereken:** PDF/GCS dosyalarından okuduğunuz karakter bilgisini
buradaki alanlara aktararak `blueprint.json` dosyasını doldurmak.

**Temel JSON yapısı:**
```json
{
  "id": "<uuid>",
  "name": "Karakter Adı",
  "categorySlug": "player-character",
  "description": "markdown metin",
  "tags": [],
  "imagePath": "",
  "dmNotes": "",
  "source": "",
  "fields": { "...alanlar..." }
}
```

**Kaynak kontrol:** Her karaktere `source` alanını ekleyin:
```json
"source": "Örnek Macera, Shadowdark"
```

## 2. Alanlar Nasıl Doldurulur?

**Agent Talimatları:**

1. **Relation alanları** — `{lookup, match, value}` formatında yazın:
   ```json
   "species_ref": {"lookup": "species", "match": "name", "value": "Human"}
   ```

2. **Enum alanları** — Kapalı listeden doğru değeri seçin.

3. **Sayısal alanlar** — Doğru tipi kullanın (int, text, dice).

4. **Metin alanları** — Markdown formatında yazın. `description`, `backstory`,
   `personality_traits` gibi alanlara kaynaktaki metin **birebir** taşınır;
   özetleme yok ([README § 0](README.md)). Kaynak sistemin sayısal sayfası 5e
   alanlarına oturmuyorsa ham sayfayı `backstory` içine bir markdown bölümü
   olarak yapıştır — sayı uydurma.

5. **Entity mention'ları** — Metin bir world entity'sinden bahsediyorsa link bırak:
   ```json
   "backstory": "@[Amara the Pale](entity:npc/Amara the Pale) ona borçlu."
   ```
   Biçim `@[Görünen Ad](entity:<kategori-slug>/<Entity Adı>)`; hedef
   `world-blueprint.json`'da tanımlı olmalı, converter id'ye çevirir. Hedef yoksa
   build hata verir.

6. **Yazılmayan alanlar** — Şema default'unu alır.

**`match` türleri:**
- `"name"` — İsim ile eşle (en yaygın)
- `"slug"` — Slug ile eşle
- `"abbreviation"` — Kısaltma ile eşle (ability scores için)
- `"manual"` — Manuel değer

## 3. Tam Alan Listesi

**Agent Notu:** Aşağıdaki tablolar her alanın tipini ve zorunluluğunu gösterir.
PDF/GCS'den okuduğunuz karakter bilgisini bu alanlara aktarın.

Kısaltmalar: **T** = FieldType, **Z** = zorunlu, **D** = default.

### 3.1 Identity grubu

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `species_ref` | relation→`species` | ✓ | — | Tek uuid string. Hedef: species entity id. |
| `class_refs` | relation→`class` (list) | ✓ | `[]` | `["<class-uuid>", ...]` |
| `subclass_refs` | relation→`subclass` (list) | | `[]` | `["<subclass-uuid>", ...]` |
| `background_ref` | relation→`background` | ✓ | — | Tek uuid string. |
| `alignment_ref` | relation→`alignment` | | — | Tek uuid string. |
| `feats` | relation→`feat` (list) | | `[]` | `["<feat-uuid>", ...]` |
| `languages` | relation→`language` (list) | ✓ | `[]` | `["<language-uuid>", ...]` |
| `tool_proficiencies` | relation→`tool` (list) | | `[]` | `["<tool-uuid>", ...]` |
| `weapon_proficiency_categories` | relation→`weapon-category` (list) | | `[]` | `["<kategori-uuid>", ...]` |
| `weapon_masteries` | relation→`weapon` (list) | | `[]` | `["<weapon-uuid>", ...]` |
| `armor_trainings` | relation→`armor-category` (list) | | `[]` | `["<kategori-uuid>", ...]` |
| `xp` | integer | ✓ | `0` | Deneyim puanı, ≥ 0. |
| `proficiency_bonus` | integer | ✓ | `2` | 2..6. Sihirbaz seviyeden hesaplar. |
| `age` / `height` / `weight` / `eyes` / `skin` / `hair` | text | | `''` | Serbest metin. |

### 3.2 Progression grubu

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `class_levels` | levelTable | | — | `{"<class-entity-id>": <int seviye>}`. Anahtar sınıfın **id**'si, değer o sınıftaki seviye. Multiclass = birden çok giriş. **Not:** Section 7.1'de isim example olarak `"Fighter"` kullanılmış; gerçek kullanımda UUID olmalı. |

### 3.3 Ability Scores grubu

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `stat_block` | statBlock | | `{STR:10,DEX:10,CON:10,INT:10,WIS:10,CHA:10}` | `{"STR":16,"DEX":12,"CON":14,"INT":10,"WIS":13,"CHA":8}` — **altı anahtarın tamamı int**, pratikte 3–30. Sihirbaz buraya *toplam* (base + feat + ırk/background ASI) değeri yazar; `CharacterResolver` grant ASI'lerini tekrar eklemez, `base_abilities` + `background_asi` ham girdileriyle doğrular. |

### 3.4 Combat grubu

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `combat_stats` | combatStats | | `{hp:'',max_hp:'',ac:'',speed:'',cr:'',xp:'',initiative:'',level:''}` | Alt alanlar: `hp` (int, güncel), `max_hp` (int), `ac` (int), `speed` (**text**, `"30 ft"` gibi), `level` (int), `initiative` (**dice metni**, `"+2"`), `cr` (text), `xp` (int). |
| `extra_hp` | integer | | `0` | İmzalı delta (`+n` / `-n`); commit'te `combat_stats.max_hp` + `hp`'ye işlenir. |
| `death_saves_successes` | integer | ✓ | `0` | 0..3. |
| `death_saves_failures` | integer | ✓ | `0` | 0..3. |
| `heroic_inspiration` | integer | ✓ | `0` | 0..3 yük. |
| `saving_throws` | proficiencyTable | | 6 preset satır | `{"rows":[{"name":"Strength","ability":"STR","proficient":true,"expertise":false,"misc":0}, ...]}` — 6 satır: Strength/STR, Dexterity/DEX, Constitution/CON, Intelligence/INT, Wisdom/WIS, Charisma/CHA. |
| `skills` | proficiencyTable | | 18 preset satır | Aynı şekil; 18 satır: Acrobatics/DEX, Animal Handling/WIS, Arcana/INT, Athletics/STR, Deception/CHA, History/INT, Insight/WIS, Intimidation/CHA, Investigation/INT, Medicine/WIS, Nature/INT, Perception/WIS, Performance/CHA, Persuasion/CHA, Religion/INT, Sleight of Hand/DEX, Stealth/DEX, Survival/WIS. |

### 3.5 Senses

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `senses` | relation→`sense` (list) | | `[]` | `["<sense-uuid>", ...]` |
| `passive_perception` / `passive_insight` / `passive_investigation` | integer | | `10` | 0..30. |

### 3.6 Inventory grubu

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `inventory` | relation list→`weapon`,`armor`,`adventuring-gear`,`magic-item` (`hasEquip`) | | `[]` | Satır şekli: `{"id":"<item-uuid>","equipped":true,"source":"auto"}` — düz `"<uuid>"` stringi de widget tarafından okunur. `equipped`: zırh giyili mi / silah elde mi / item attuned mu. AC hesabı giyili zırhı bu bayraktan okur. |
| `current_lifestyle_ref` | relation→`lifestyle` | | — | Tek uuid string. |

### 3.7 Currency grubu

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `cp` / `sp` / `ep` / `gp` / `pp` | integer | | `0` | Bakır / gümüş / elektrum / altın / platin, ≥ 0. |

### 3.8 Defenses grubu

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `resistance_refs` | relation→`damage-type` (list) | | `[]` | `["<uuid>", ...]` |
| `vulnerability_refs` | relation→`damage-type` (list) | | `[]` | `["<uuid>", ...]` |
| `damage_immunity_refs` | relation→`damage-type` (list) | | `[]` | `["<uuid>", ...]` |
| `condition_immunity_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `current_conditions` | relation→`applied-condition` (list) | | `[]` | `["<uuid>", ...]` |

### 3.9 Traits & Actions grubu

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `trait_refs` | relation→`trait` (list) | | `[]` | Species/class grant'larından doldurulur. |
| `action_refs` / `bonus_action_refs` / `reaction_refs` | relation→`creature-action` (list) | | `[]` | Aksiyonlar (sadece PC'de var — NPC'de `bonus_action_refs`/`reaction_refs` yoktur). |

### 3.10 Spells grubu

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `spell_save_dc` | integer | | — | 0..30. |
| `spell_attack_bonus` | integer | | — | İmzalı int. |
| `spell_slots` | spellSlotGrid | | — | `{"max":{"1":4,"2":3},"remaining":{"1":4,"2":3}}` — anahtar **spell seviyesi (string)**, değer slot sayısı. `max` sınıfın `caster_kind` + seviyesinden otomatik türetilir; `remaining` oyuncu harcadıkça düşer. |
| `spells_known` | relation→`spell` (list, `hasEquip`) | | `[]` | Satır: `{"id":"<spell-uuid>","equipped":true,"source":"auto"}` — `equipped` = **hazırlanmış** bayrağı. Cantrip'ler default hazırlanmış yazılır. |

### 3.11 Features grubu

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `class_resources` | proficiencyTable | | — | `{rows:[...]}` — sınıf kaynak takibi (ör. Rage kullanımı). Editör genel render'ında gizlidir; resolver kaynak pool'larından beslenir. |

### 3.12 Rules (kişilik / geçmiş / görünüm)

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `trinket` | markdown | | `''` | Serbest metin biblosu. |
| `personality_traits` / `ideals` / `bonds` / `flaws` | markdown | | `''` | PHB §1 kişilik blokları. |
| `appearance` | markdown | | `''` | Görünüm. |
| `backstory` | markdown | | `''` | Geçmiş. |
| `allies_organizations` | markdown | | `''` | Müttefikler ve örgütler. |
| `trinket_ref` | relation→`trinket` | | — | Biblonun entity referansı (çoğu PC'de boş; metin alanı kullanılır). |

## 4. Şema dışı resolver girdileri (fields map'inde, şemada alan yok)

`CharacterResolver` bunları ham seçim kaydı olarak okur; sihirbaz yazar, editör okur.
Template-agnostic oldukları için `player-character` şemasında görünmezler:

| key | Şekil |
|---|---|
| `race_id` / `background_id` / `subclass_id` / `subspecies_id` | uuid string (`''` = yok) |
| `feat_ids` | `["<feat-uuid>", ...]` (origin feat + L1 order feat + seçilen feat'lar) |
| `base_abilities` | `{"STR":15,"DEX":8,...}` — ham dağılım (point buy / array / random + feat pick'leri) |
| `background_asi` | `{"CHA":2,"DEX":1}` — background ASI dağılımı (resolver gating yapar) |
| `feat_asi_choices` | `{"<featId>":{"STR":1}}` — feat ASI pick kayıtları |
| `skill_choice_ids` / `tool_choice_ids` / `language_choice_ids` | `["<uuid>", ...]` |
| `cantrip_ids` / `prepared_spell_ids` | `["<spell-uuid>", ...]` |
| `weapon_masteries` | `["<weapon-uuid>", ...]` |
| `equipment_choices` | `{"<entityId>:<groupId>":"<option_id>"}` — kaynak entity id ile scoped |
| `feat_choices` | `{"<origin-feat>":"<seçim>"}` |
| `pending_choices` | `playerChoices` listesi — ertelenmiş "pick N" kararları |

## 5. İçerik kartlarından karaktere akan grant sözleşmesi

Başka content'lerden **karakter kartı değil de** içerik kartı (species, class, feat,
spell, item…) üretilecekse: resolver bu kartların grant alanlarını okuyup karakter
kağıdına katlar. Kapalı sözleşme `CharacterResolver.grantFieldKeys` (41 anahtar,
`lib/domain/services/character_resolver.dart:26`):

- **Proficiency:** `granted_skill_proficiencies`, `granted_tool_proficiencies`,
  `granted_save_proficiencies`, `granted_weapon_proficiencies`,
  `granted_armor_proficiencies`, `granted_expertise_skills`
- **Diller:** `granted_languages`
- **Büyüler:** `granted_spell_refs`, `granted_cantrip_refs`,
  `always_prepared_spell_refs`, `granted_spells_at_level` (satır:
  `{spell_ref, at_level, is_cantrip?, uses_per_long_rest?}`)
- **Sayısal:** `ability_bonuses` (statBlock map), `ability_bonus_cap`, `ac_bonus`,
  `speed_bonus_ft`, `initiative_bonus`, `hp_bonus_flat`, `hp_bonus_per_level`,
  `extra_attack_count`, `extra_attack_count_by_level` (levelTable), `crit_threshold`,
  `weapon_mastery_count`
- **Unarmored AC:** `unarmored_ac_base`, `unarmored_ac_abilities`,
  `unarmored_ac_shield_allowed`
- **Savunma:** `granted_damage_resistances`, `granted_damage_immunities`,
  `granted_damage_vulnerabilities`, `granted_condition_immunities`
- **Duyular:** `granted_senses` (rangedSenseList: `[{sense_ref, range_ft}]`)
- **Hızlar:** `speed_fly_ft`, `speed_swim_ft`, `speed_climb_ft`, `speed_burrow_ft`
  (`-1` = yürüme hızına eşit)
- **Aksiyonlar:** `granted_action_refs`, `granted_bonus_action_refs`,
  `granted_reaction_refs`
- **Traits:** `trait_refs`
- **Kaynaklar:** `resource_pool_grants` (`{pool_ref, recharge, count?, count_formula?,
  count_by_level?, class_ref?}`), `player_choices`
- **Durum kapısı:** `active_while_state_ref` (→ `character-state`)
- **Notlar:** `mechanical_notes` (satır başına bir kural; kağıtta aynen gösterilir)

Sınıf kartının kendi tipli alanları (grant bloğu taşımaz):
`saving_throw_refs`, `armor_training_refs`, `weapon_proficiency_categories`,
`granted_tool_refs`, `granted_languages`, `hit_die`, `caster_kind`
(None/Full/Half/Third/Pact/Ritual), `features` (classFeatures satırları,
satır = `{level, name, description?, granted_*_refs...}`), `default_inventory_refs`,
`equipment_choice_groups`, `cantrips_known_by_level`, `prepared_spells_by_level`,
`spell_slots_by_level`.

Background kartı: `granted_skill_refs`, `granted_tool_refs`,
`granted_tool_variant_group`, `granted_language_count`, `granted_languages`,
`ability_score_options`, `asi_fixed_ability_ref`, `asi_free_bonus_count`,
`asi_distribution_options` (`['+2/+1','+1/+1/+1']`), `origin_feat_ref`,
`default_inventory_refs`, `equipment_choice_groups`, `starting_gold_gp`,
`gold_alternative_gp`.

## 6. Blueprint JSON Formatı

**Agent Talimatları:** `blueprint.json` dosyasını şu formatta oluşturun:

```json
{
  "version": "1.0.0",
  "source_system": "shadowdark",
  "app_schema": "builtin-dnd5e-default-v2",
  "characters": [
    {
      "source_name": "Karakter Adı",
      "source_file": "media/GCS Characters/Example.gcs",
      "mapping": { "...alanlar..." }
    }
  ]
}
```

**Dönüşüm kuralları:**
1. `{lookup, match, value}` → hedef entity'yi bulup `id` yazın
2. `class_levels` anahtarları `class_refs` ile çözülür
3. `skills` / `saving_throws` preset üzerine isimle merge edilir
4. `combat_stats.speed` **text** olarak: `"30 ft"`

**Kaynak kontrol:** Her karaktere `source_name` ve `mapping.source` ekleyin.

### Örnek blueprint karakteri

```json
{
  "version": "1.0.0",
  "source_system": "shadowdark",
  "app_schema": "builtin-dnd5e-default-v2",
  "characters": [
    {
      "source_name": "Jamal the Black Spear",
      "source_file": "media/GURPS GCS Characters/PC-Jamal-the-Black-Spear.gcs",
      "character_type": "pc",
      "mapping": {
        "name": "Jamal the Black Spear",
        "species_ref": {"lookup": "species", "match": "name", "value": "Human"},
        "class_refs": [{"lookup": "class", "match": "name", "value": "Barbarian"}],
        "class_levels": {"Barbarian": 2},
        "background_ref": {"lookup": "background", "match": "name", "value": "Outlander"},
        "alignment_ref": {"lookup": "alignment", "match": "name", "value": "Chaotic Neutral"},
        "xp": 300,
        "proficiency_bonus": 2,
        "stat_block": {"STR": 17, "DEX": 13, "CON": 15, "INT": 8, "WIS": 12, "CHA": 10},
        "combat_stats": {
          "hp": 24, "max_hp": 24, "ac": 14, "speed": "40 ft",
          "level": 2, "initiative": "+1", "cr": "", "xp": 300
        },
        "saving_throws": {
          "rows": [
            {"name": "Strength", "ability": "STR", "proficient": true},
            {"name": "Constitution", "ability": "CON", "proficient": true}
          ]
        },
        "skills": {
          "rows": [
            {"name": "Athletics", "ability": "STR", "proficient": true},
            {"name": "Survival", "ability": "WIS", "proficient": true}
          ]
        },
        "languages": [{"lookup": "language", "match": "name", "value": "Common"}],
        "inventory": [
          {"lookup": "weapon", "match": "name", "value": "Longsword", "equipped": true},
          {"lookup": "armor", "match": "name", "value": "Shield", "equipped": true}
        ],
        "gp": 10,
        "personality_traits": "Loud and boastful, laughs at danger.",
        "backstory": "Bir zamanlar güney denizlerinin korkulan korsanı..."
      }
    }
  ]
}
```

## 7. Eşleme Tablosu (Karakter → Uygulama)

**Agent Referansı:** PDF/GCS'den okuduğunuz karakter bilgilerini şu alanlara aktarın.

### 7.1 Temel Kimlik Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Name | `name` | Entity name | "Jamal the Black Spear" |
| Race / Species | `species_ref` | relation→species | `{lookup: "species", match: "name", value: "Human"}` |
| Class | `class_refs` | relation→class (list) | `[{lookup: "class", match: "name", value: "Fighter"}]` |
| Subclass | `subclass_refs` | relation→subclass (list) | `[{lookup: "subclass", match: "name", value: "Champion"}]` |
| Level | `class_levels` | `{classId: level}` | `{"<class-uuid>": 5}` — anahtar sınıf UUID'si, değer seviye |
| Background | `background_ref` | relation→background | `{lookup: "background", match: "name", value: "Soldier"}` |
| Alignment | `alignment_ref` | relation→alignment | `{lookup: "alignment", match: "name", value: "Lawful Neutral"}` |
| XP | `xp` | integer | 300 |
| Proficiency Bonus | `proficiency_bonus` | integer | 2 (seviyeden hesaplanır) |

### 7.2 Yetenek Değerleri Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| STR | `stat_block.STR` | int | 10–30 arası |
| DEX | `stat_block.DEX` | int | 10–30 arası |
| CON | `stat_block.CON` | int | 10–30 arası |
| INT | `stat_block.INT` | int | 10–30 arası |
| WIS | `stat_block.WIS` | int | 10–30 arası |
| CHA | `stat_block.CHA` | int | 10–30 arası |
| **Toplam stat_block** | `stat_block` | `{STR:16, DEX:14, ...}` | Altı anahtarın tamamı int |

### 7.3 Savaş İstatistikleri Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| HP | `combat_stats.hp` | int | Güncel can puanı |
| Max HP | `combat_stats.max_hp` | int | Maksimum can puanı |
| AC | `combat_stats.ac` | int | Zırh sınıfı |
| Speed | `combat_stats.speed` | **text** | `"30 ft"` — mutlaka text |
| Level | `combat_stats.level` | int | Toplam seviye |
| Initiative | `combat_stats.initiative` | **dice** | `"+2"` — bonus olarak |
| CR | `combat_stats.cr` | text | Challenge Rating (boş olabilir) |
| XP | `combat_stats.xp` | int | Deneyim puanı |

### 7.4 Beceri ve Kurtulma Taslağı Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| **Saving Throws** | `saving_throws` | proficiencyTable | 6 satır: STR/DEX/CON/INT/WIS/CHA |
| Strength save | `saving_throws.rows[0]` | `{name:"Strength", ability:"STR", proficient:true/false}` | |
| Dexterity save | `saving_throws.rows[1]` | `{name:"Dexterity", ability:"DEX", proficient:true/false}` | |
| Constitution save | `saving_throws.rows[2]` | `{name:"Constitution", ability:"CON", proficient:true/false}` | |
| Intelligence save | `saving_throws.rows[3]` | `{name:"Intelligence", ability:"INT", proficient:true/false}` | |
| Wisdom save | `saving_throws.rows[4]` | `{name:"Wisdom", ability:"WIS", proficient:true/false}` | |
| Charisma save | `saving_throws.rows[5]` | `{name:"Charisma", ability:"CHA", proficient:true/false}` | |
| **Skills** | `skills` | proficiencyTable | 18 satır |
| Acrobatics | `skills.rows[0]` | `{name:"Acrobatics", ability:"DEX", proficient:true/false}` | |
| Animal Handling | `skills.rows[1]` | `{name:"Animal Handling", ability:"WIS", proficient:true/false}` | |
| Arcana | `skills.rows[2]` | `{name:"Arcana", ability:"INT", proficient:true/false}` | |
| Athletics | `skills.rows[3]` | `{name:"Athletics", ability:"STR", proficient:true/false}` | |
| Deception | `skills.rows[4]` | `{name:"Deception", ability:"CHA", proficient:true/false}` | |
| History | `skills.rows[5]` | `{name:"History", ability:"INT", proficient:true/false}` | |
| Insight | `skills.rows[6]` | `{name:"Insight", ability:"WIS", proficient:true/false}` | |
| Intimidation | `skills.rows[7]` | `{name:"Intimidation", ability:"CHA", proficient:true/false}` | |
| Investigation | `skills.rows[8]` | `{name:"Investigation", ability:"INT", proficient:true/false}` | |
| Medicine | `skills.rows[9]` | `{name:"Medicine", ability:"WIS", proficient:true/false}` | |
| Nature | `skills.rows[10]` | `{name:"Nature", ability:"INT", proficient:true/false}` | |
| Perception | `skills.rows[11]` | `{name:"Perception", ability:"WIS", proficient:true/false}` | |
| Performance | `skills.rows[12]` | `{name:"Performance", ability:"CHA", proficient:true/false}` | |
| Persuasion | `skills.rows[13]` | `{name:"Persuasion", ability:"CHA", proficient:true/false}` | |
| Religion | `skills.rows[14]` | `{name:"Religion", ability:"INT", proficient:true/false}` | |
| Sleight of Hand | `skills.rows[15]` | `{name:"Sleight of Hand", ability:"DEX", proficient:true/false}` | |
| Stealth | `skills.rows[16]` | `{name:"Stealth", ability:"DEX", proficient:true/false}` | |
| Survival | `skills.rows[17]` | `{name:"Survival", ability:"WIS", proficient:true/false}` | |

### 7.5 Eşya ve Teçhizat Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Weapons | `inventory` | relation list | `[{id:"weapon-uuid", equipped:true}]` |
| Armor | `inventory` | relation list | `[{id:"armor-uuid", equipped:true}]` |
| Shield | `inventory` | relation list | `[{id:"shield-uuid", equipped:true}]` |
| Adventuring Gear | `inventory` | relation list | `[{id:"gear-uuid", equipped:false}]` |
| Magic Items | `inventory` | relation list | `[{id:"item-uuid", equipped:true}]` |
| Tools | `tool_proficiencies` | relation→tool (list) | `["tool-uuid", ...]` |
| Weapon Proficiencies | `weapon_proficiency_categories` | relation→weapon-category (list) | `["kategori-uuid", ...]` |
| Armor Trainings | `armor_trainings` | relation→armor-category (list) | `["kategori-uuid", ...]` |

### 7.6 Dil ve Yetenek Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Languages | `languages` | relation→language (list) | `[{lookup:"language", match:"name", value:"Common"}]` |
| Tool Proficiencies | `tool_proficiencies` | relation→tool (list) | `[{lookup:"tool", match:"name", value:"Thieves' Tools"}]` |
| Feats | `feats` | relation→feat (list) | `[{lookup:"feat", match:"name", value:"Great Weapon Master"}]` |
| Senses | `senses` | relation→sense (list) | `[{lookup:"sense", match:"name", value:"Darkvision"}]` |
| Passive Perception | `passive_perception` | integer | 10 (10 + WIS modu) |
| Passive Insight | `passive_insight` | integer | 10 (10 + WIS modu) |
| Passive Investigation | `passive_investigation` | integer | 10 (10 + INT modu) |

### 7.7 Büyü Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Spells Known | `spells_known` | relation→spell (list) | `[{id:"spell-uuid", equipped:true}]` |
| Prepared Spells | `spells_known` | relation list | `equipped: true` = hazırlanmış |
| Cantrips | `spells_known` | relation list | `equipped: true` (default) |
| Spell Slots (max) | `spell_slots.max` | `{seviye: adet}` | `{"1":4, "2":3}` |
| Spell Slots (remaining) | `spell_slots.remaining` | `{seviye: adet}` | Oyuncu harcadıkça düşer |
| Spell Save DC | `spell_save_dc` | integer | 8 + proficiency + WIS/CHA modu |
| Spell Attack Bonus | `spell_attack_bonus` | integer | proficiency + WIS/CHA modu |

### 7.8 Kişilik ve Görünüm Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Personality Traits | `personality_traits` | markdown | "Loud and boastful..." |
| Ideals | `ideals` | markdown | "Code of Honor..." |
| Bonds | `bonds` | markdown | "Fascinated by history..." |
| Flaws | `flaws` | markdown | "Honesty - must obey the law..." |
| Backstory | `backstory` | markdown | "Ghazi Holy Warrior..." |
| Appearance | `appearance` | markdown | "Tall, with dark eyes..." |
| Allies & Organizations | `allies_organizations` | markdown | "Member of the Silver Order..." |
| Trinket | `trinket` | markdown | "A tiny packet of desert salt..." |

### 7.9 Para Birimi Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Copper Pieces | `cp` | integer | ≥ 0 |
| Silver Pieces | `sp` | integer | ≥ 0 |
| Electrum Pieces | `ep` | integer | ≥ 0 |
| Gold Pieces | `gp` | integer | ≥ 0 |
| Platinum Pieces | `pp` | integer | ≥ 0 |

### 7.10 Savunma Eşleme

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Damage Resistances | `resistance_refs` | relation→damage-type (list) | `["damage-type-uuid", ...]` |
| Damage Vulnerabilities | `vulnerability_refs` | relation→damage-type (list) | `["damage-type-uuid", ...]` |
| Damage Immunities | `damage_immunity_refs` | relation→damage-type (list) | `["damage-type-uuid", ...]` |
| Condition Immunities | `condition_immunity_refs` | relation→condition (list) | `["condition-uuid", ...]` |
| Current Conditions | `current_conditions` | relation→applied-condition (list) | `["applied-condition-uuid", ...]` |

### 7.11 Aksiyon ve Trait Eşleme

**Agent Notu:** NPC'de `bonus_action_refs` ve `reaction_refs` yoktur — sadece `action_refs` + `special_action_refs` vardır.

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Traits | `trait_refs` | relation→trait (list) | `["trait-uuid", ...]` |
| Actions | `action_refs` | relation→creature-action (list) | `["action-uuid", ...]` |
| Bonus Actions (PC only) | `bonus_action_refs` | relation→creature-action (list) | Sadece player-character'da var |
| Reactions (PC only) | `reaction_refs` | relation→creature-action (list) | Sadece player-character'da var |

### 7.12 Ek Alanlar (PC)

| Kaynak Alan | Uygulama Alanı | Format | Not |
|---|---|---|---|
| Extra HP | `extra_hp` | integer | Default 0 |
| Death Saves (successes) | `death_saves_successes` | integer | 0..3 |
| Death Saves (failures) | `death_saves_failures` | integer | 0..3 |
| Heroic Inspiration | `heroic_inspiration` | integer | 0..3 |

---

## 8. Tier-1 İçerik Kategorileri (World'den Lookup ile Referans)

**Agent Notu:** Bu kategorilerdeki içerikler **önce world'e eklenir** (world-blueprint.md §3.18-3.37), ardından karakter `lookup` ile referans alır. SRD'de olan内容 zaten world'de mevcuttur; SRD dışı内容 blueprint'e eklenerek world'e yazılır. Karakter bu içeriklere `lookup` ile bağlanır, kendi içine kopyalamaz.

### 8.1 Class — `class`

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

### 8.2 Subclass — `subclass`

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

### 8.3 Species — `species`

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
| `unarmored_ac_base` | integer | | | Zırhsız AC tabanı. |
| `unarmored_ac_abilities` | relation→`ability` (list) | | | Zırhsız AC yetenekleri. |
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

### 8.4 Background — `background`

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

### 8.5 Feat — `feat`

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

### 8.6 Spell — `spell`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `level` | integer | ✓ | — | Büyü seviyesi (0..9). |
| `school_ref` | relation→`spell-school` | ✓ | — | Okul. |
| `casting_time_amount` | integer | ✓ | — | büyü süresi miktarı. |
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

### 8.7 Weapon — `weapon`

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

### 8.8 Armor — `armor`

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

### 8.9 Creature Action — `creature-action`

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

### 8.10 Trait — `trait`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `source` | text | | | Kaynak. |
| `trait_kind` | enum | | | `Passive` / `Sense` / `Defensive` / `Movement` / `Spellcasting` / `Other` |
| `description` | markdown | | | Açıklama. |
| `benefits` | markdown | | | Faydalar. |
| `chooseable` | boolean | | | Seçilebilir mi? (default: false) |
| **Grant Block** | — | | | `traits: false` — tüm grant alanları (trait_refs hariç). |

### 8.11 Tool — `tool`

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

### 8.12 Adventuring Gear — `adventuring-gear`

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

### 8.13 Ammunition — `ammunition`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `storage_container` | text | | | Depolama kabı. |
| `cost_gp` | float | ✓ | — | Maliyet (≥0). |
| `weight_lb` | float | ✓ | — | Ağırlık (≥0). |
| `bundle_count` | integer | ✓ | — | Paket adedi. |

### 8.14 Equipment Pack — `pack`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `cost_gp` | integer | ✓ | — | Maliyet (≥0). |
| `weight_lb` | float | | | Ağırlık (≥0). |
| `content_refs` | relation list→`adventuring-gear`,`weapon`,`armor`,`tool`,`ammunition` | | | İçerik eşyaları. |
| `content_quantities` | levelTable | | | İçerik miktarları. |
| `contents` | markdown | | | İçerik açıklaması. |

### 8.15 Mount — `mount`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `carrying_capacity_lb` | integer | ✓ | — | Taşıma kapasitesi (≥0). |
| `speed_ft` | integer | ✓ | — | Hız (≥0). |
| `cost_gp` | integer | ✓ | — | Maliyet (≥0). |
| `is_trained` | boolean | | | Eğitimli mi? |

### 8.16 Vehicle — `vehicle`

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

### 8.17 Trinket — `trinket`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `roll_d100` | integer | ✓ | — | Zar sonucu (1..100). |
| `description` | markdown | ✓ | — | Açıklama. |

### 8.18 Animal — `animal`

Monster ile aynı alanlara sahiptir (§8 Monster'a bakın). Farkı: `animal`slug'u ile world'e eklenir, encounter'larda `encounter.monsters_refs` ile referans verilir.

### 8.19 Starter Bundle — `starter-bundle`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `starting_level` | integer | ✓ | — | Başlangıç seviyesi (1..20). |
| `starting_gold_gp` | integer | ✓ | — | Başlangıç altını (≥0). |
| `magic_item_choice_refs` | relation→`magic-item` (list) | | | Seçilebilir sihirli eşyalar. |
| `magic_item_choice_count` | integer | | | Seçim sayısı (0..5). |
| `granted_magic_items` | relation→`magic-item` (list) | | | Verilen sihirli eşyalar. |
| `notes` | markdown | | | Notlar. |

**SRD kontrol:** Bu kategorilerdeki içerik SRD'de varsa world'de zaten mevcuttur, `lookup` ile referans verin. SRD dışı内容 world'e ekleyin, sonra karakter `lookup` ile bağlayın.

**SRD kontrol:** Karakter sınıfı, ırkı veya feat'i SRD'de varsa world'de zaten mevcuttur, `lookup` ile referans verin.
