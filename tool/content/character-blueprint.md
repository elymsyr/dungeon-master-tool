# Karakter Kağıdı Blueprint — `player-character` Alan Referansı

> Bu dosya, uygulamadaki `player-character` kategorisinin **tek yetkili alan sözleşmesidir**.
> Diğer content'lerden (GCS dosyaları, module PDF'leri, SRD kartları) karakter verisi
> çekileceği zaman buradaki alan adları, tipleri ve JSON şekilleri kullanılır.
> Kaynak kod: `flutter_app/lib/domain/entities/schema/builtin/dm.dart` → `_playerCharacterCategory`.

## 1. Karakter nedir?

Karakter, `categorySlug: "player-character"` olan bir `Entity`'dir
(`flutter_app/lib/domain/entities/entity.dart`). Tüm tip-spesifik veri `fields`
map'inde saklanır; kartın temeli şudur:

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
  "fields": { "...aşağıdaki alanlar..." }
}
```

`Character` sarmalayıcısı (`lib/domain/entities/character.dart`) yalnızca
`entity` + `templateId` + `worldId` + `ownerId` ekler; oyun verisi tamamen
`entity.fields` içindedir.

## 2. Alanlar nasıl doldurulur?

Üç kaynak vardır:

1. **Oluşturma sihirbazı** (`character_creation_wizard_screen.dart → buildSeedFields`)
   — karakter kaydedilirken PC entity'sinin `fields` map'ine şunları yazar:
   seçili species/class/background/alignment relation'ları, `class_levels`,
   toplam `stat_block`, hesaplanmış `combat_stats` (HP/AC/hız), `proficiency_bonus`,
   sınıf/ırk/background grant'larından **flatten edilmiş** `skills` + `saving_throws`
   tabloları (satır `proficient` bayrakları), equipment choice'lardan `inventory`,
   `spells_known` satırları (`equipped` = hazırlanmış), `spell_slots` max/remaining,
   diller, tool proficiencies, weapon/armor kategori listeleri ve kişilik metinleri.
2. **Read-time `CharacterResolver`** (`lib/domain/services/character_resolver.dart`)
   — kartın *grant bloklarını* okuyup **türetilmiş** `EffectiveCharacter` üretir:
   AC, save/skill bonusları, ekstra hızlar, duyular, dirençler, resource pool'lar,
   spell slot üst limitleri. Bunlar depolanmaz, her okumada yeniden hesaplanır.
3. **Manuel / oyun sırası** — HP delta (`extra_hp`), death save'ler, koşullar,
   para, kalan spell slotları, XP, kişilik metinleri editörden yazılır.

## 3. Tam alan listesi

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
| `class_levels` | levelTable | | — | `{"<class-entity-id>": <int seviye>}`. Anahtar sınıfın **id**'si, değer o sınıftaki seviye. Multiclass = birden çok giriş. |

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
| `action_refs` / `bonus_action_refs` / `reaction_refs` | relation→`creature-action` (list) | | `[]` | NPC/monster ile aynı alan şekli. |

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

## 6. Blueprint JSON formatı (içerik aktarımı)

Blueprint, kaynak content → uygulama alanı eşlemesini tanımlar. **Yalnızca kaynakta
karşılığı olan alanlar yazılır**; yazılmayan alanlar şema default'unu alır.
İmporter, blueprint'i okurken şu dönüşümleri uygular:

1. `lookup` + `match` + `value` → hedef kategori entity'sini bul, relation alanına
   **id** yaz (list ise listeye ekle).
2. `class_levels` anahtarları, `class_refs` ile çözülen sınıf id'leriyle eşleştirilir.
3. `skills` / `saving_throws` satırları preset üzerine **isimle** merge edilir
   (eksik `expertise`/`misc` = `false`/`0`).
4. `inventory` / `spells_known` satırları `{id, equipped}` şekline çevrilir
   (`spells_known`'da `equipped` = `prepared`).
5. `stat_block` / `combat_stats` / sayısal alanlar aynen kopyalanır.
6. `combat_stats.speed` **text** olarak yazılmalıdır: `"30 ft"`.

`match` türleri: `"name"` (varsayılan), `"slug"`, `"abbreviation"` (ability için),
`"manual"` (kaynakta karşılığı yoksa elle girilen değer).

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
        "backstory": "The Black Spear of Basra, feared pirate of the southern seas..."
      }
    }
  ]
}
```

## 7. Kısa eşleme tablosu (kaynak → uygulama)

| Kaynak | Uygulama alanı | Tür |
|---|---|---|
| Name | `name` | Entity name |
| Race/Species | `species_ref` | relation→species |
| Subrace | `subspecies_id` (+ `subspecies_options` eşleşmesi) | resolver girdisi |
| Class | `class_refs` | relation list→class |
| Level | `class_levels` | levelTable `{classId: level}` |
| Subclass | `subclass_refs` / `subclass_id` | relation list / resolver girdisi |
| Alignment | `alignment_ref` | relation→alignment |
| Background | `background_ref` | relation→background |
| STR/DEX/CON/INT/WIS/CHA | `stat_block` | statBlock map (int) |
| HP | `combat_stats.hp` + `.max_hp` | int |
| AC | `combat_stats.ac` | int |
| Speed | `combat_stats.speed` | **text** `"30 ft"` |
| Skills | `skills` | proficiencyTable satırları |
| Saving Throws | `saving_throws` | proficiencyTable satırları |
| Proficiencies | `tool_proficiencies`, `languages`, `weapon_proficiency_categories`, `armor_trainings` | relation listeleri |
| Equipment | `inventory` | relation list (`{id, equipped}`) |
| Spells | `spells_known` | relation list (`{id, equipped=prepared}`) |
| Features/Traits | `trait_refs`, `action_refs`, `bonus_action_refs`, `reaction_refs` | relation listeleri |
| Personality | `personality_traits`, `ideals`, `bonds`, `flaws` | markdown |
| Backstory / Appearance | `backstory`, `appearance` | markdown |
| Money | `cp` / `sp` / `ep` / `gp` / `pp` | integer |
