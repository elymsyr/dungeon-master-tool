# SRD 5.2.1 — Full Template Uyarlaması

Bu döküman, D&D 5e SRD 5.2.1 Core Compatible içeriğinin mevcut `WorldSchema` / `EntityCategorySchema` / `FieldSchema` / `FieldGroup` altyapısına **tam** uyarlamasıdır. Kural motoru (rule engine) içeriği ayrı bir dökümanda — bu dosya yalnızca **veri modeli** ve **seed içerik** haritasıdır.

Mevcut altyapı referansı: [TEMPLATES_FIELDS_GROUPS_RULES.md](TEMPLATES_FIELDS_GROUPS_RULES.md)

Kaynak: SRD_CC_v5.2.1.pdf (WotC, CC-BY-4.0).

---

## 1. WorldSchema — "D&D 5e SRD 5.2.1"

```
schemaId         : 'builtin-dnd5e-srd-v5.2.1'
originalHash     : 'builtin-dnd5e-srd-v5.2.1'
name             : 'D&D 5e (SRD 5.2.1)'
version          : '5.2.1'
baseSystem       : 'dnd5e'
description      : 'Built-in D&D 5e template — full SRD 5.2.1 coverage (33 categories).'
```

Toplam: **33 kategori**, ~600 seed entity, ~60 built-in RuleV3 (ayrı dökümana bakınız).

---

## 2. Kategori Envanteri (33)

### A. Karakter Stat-Block (3)

| # | Slug | İsim | Section'lar | hasStatBlock | hasActions | hasSpells |
|---|------|------|-------------|--------------|------------|-----------|
| 1 | `player` | Player Character | encounter, mindmap, worldmap, projection | ✓ | ✓ | ✓ |
| 2 | `npc` | NPC | encounter, mindmap, worldmap, projection | ✓ | ✓ | ✓ |
| 3 | `monster` | Monster | encounter, mindmap, worldmap, projection | ✓ | ✓ | ✓ |

### B. Karakter Yapı Taşları (8)

| # | Slug | İsim | Seed Sayısı |
|---|------|------|-------------|
| 4 | `class` | Class | 12 (Barbarian, Bard, Cleric, Druid, Fighter, Monk, Paladin, Ranger, Rogue, Sorcerer, Warlock, Wizard) |
| 5 | `subclass` | Subclass | 12 (Path of Berserker, College of Lore, Life Domain, Circle of Land, Champion, Warrior of Open Hand, Oath of Devotion, Hunter, Thief, Draconic Sorcery, Fiend Patron, Evoker) |
| 6 | `species` | Species | 9 (Dragonborn, Dwarf, Elf, Gnome, Goliath, Halfling, Human, Orc, Tiefling) |
| 7 | `lineage` | Lineage | 11 (Draconic Ancestors x10, Elven Lineages x3, Fiendish Legacies x3, Gnomish Lineages x2, Giant Ancestries x6 — örtüşme var, örnekleme) |
| 8 | `background` | Background | 4 (Acolyte, Criminal, Sage, Soldier) |
| 9 | `feat` | Feat | ~40 (Origin: 4, General: 10, Fighting Style: 4, Epic Boon: 6 — SRD'den aynen) |
| 10 | `language` | Language | 12 standard + 8 rare = 20 |
| 11 | `deity` | Deity | 0 (opsiyonel, boş) |

### C. Ability/Action/Spell Parçaları (6)

| # | Slug | İsim | Seed |
|---|------|------|------|
| 12 | `trait` | Trait | 0 (seed eklenebilir — species traits vs.) |
| 13 | `action` | Action | 10 SRD standart action (Attack, Dash, Dodge, Disengage, Help, Hide, Influence, Magic, Ready, Search, Study, Utilize) |
| 14 | `reaction` | Reaction | 2 seed (Opportunity Attack, Counterspell vb.) |
| 15 | `legendary-action` | Legendary Action | 0 (monster başına tanımlı) |
| 16 | `spell` | Spell | ~340 SRD spell |
| 17 | `condition` | Condition | 15 (Blinded, Charmed, Deafened, Exhaustion, Frightened, Grappled, Incapacitated, Invisible, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious) |

### D. Kural Boyutu (3)

| # | Slug | İsim | Seed |
|---|------|------|------|
| 18 | `skill` | Skill | 18 (18 SRD skill, ability bağlantılı) |
| 19 | `damage-type` | Damage Type | 13 (Acid, Bludgeoning, Cold, Fire, Force, Lightning, Necrotic, Piercing, Poison, Psychic, Radiant, Slashing, Thunder) |
| 20 | `creature-type` | Creature Type | 14 (Aberration, Beast, Celestial, Construct, Dragon, Elemental, Fey, Fiend, Giant, Humanoid, Monstrosity, Ooze, Plant, Undead) |

### E. Equipment (5)

| # | Slug | İsim | Seed |
|---|------|------|------|
| 21 | `weapon` | Weapon | 38 (Simple Melee: 10, Simple Ranged: 4, Martial Melee: 18, Martial Ranged: 6) |
| 22 | `armor` | Armor | 13 (Light: 3, Medium: 5, Heavy: 4, Shield: 1) |
| 23 | `tool` | Tool | ~25 (Artisan: 18, Other: 7) |
| 24 | `gear` | Adventuring Gear | ~80 (SRD p.94-99 tablosu + 8 pack) |
| 25 | `vehicle` | Vehicle / Mount | ~15 (Mounts + tack + drawn + large vehicles) |

### F. Magic Items (1)

| # | Slug | İsim | Seed |
|---|------|------|------|
| 26 | `magic-item` | Magic Item | ~170 SRD Magic Items A-Z |

### G. Dünya / Kampanya (5)

| # | Slug | İsim |
|---|------|------|
| 27 | `location` | Location |
| 28 | `plane` | Plane (2: Material + outer planes referans) |
| 29 | `quest` | Quest |
| 30 | `lore` | Lore |
| 31 | `status-effect` | Status Effect (encounter-scope) |

### H. Oyun Sistemleri (2)

| # | Slug | İsim | Amaç |
|---|------|------|------|
| 32 | `encounter` | Encounter | Combat scene grouping (initiative order + participants + location) |
| 33 | `campaign-session` | Campaign Session | Session log, date, XP awarded, notes |

---

## 3. Field Group Standardı (genişletilmiş)

```
grp-identity           Identity: name/species/class/background/alignment
grp-abilities          Stat block + ability modifiers
grp-combat             HP/AC/initiative/speed/saves/skills
grp-proficiencies      Armor/weapon/tool/language
grp-resistances        Damage vuln/resist/immune + condition immune
grp-features           Traits/actions/reactions/legendary/feats
grp-spellcasting       Spells/slots/DC/attack/prepared
grp-equipment          Inventory/coins/attunement/carrying
grp-progression        Level table, class feature progression
grp-backstory          Personality/ideals/bonds/flaws/appearance/backstory
grp-mechanics          Type-specific mechanic fields (damage/properties/mastery/rarity)
grp-context            Location/quest/lore links
grp-origin             Character origin (species/lineage/background/languages)
grp-description        Description + text fields
grp-casting            Spell-specific (range/duration/components)
grp-condition-stats    Condition-specific (duration/effect/stack)
grp-requirements       Prerequisites (feats, multiclass, attunement)
```

Grid columns default: 2 (çoğu grup), 1 (uzun listeler: Features, Spells, Backstory).

---

## 4. Field Setleri — Kategori Başı Detay

### 4.1 `player` (Player Character)

**Identity** (grp-identity, cols=2):
- `species_ref` relation→species (single)
- `lineage_ref` relation→lineage (single, opt)
- `class_levels` relation→class (list, hasEquip=false; her entry'de `level` subField — class başına seviye; multiclass destekler)
- `subclass_refs` relation→subclass (list)
- `background_ref` relation→background (single)
- `alignment` enum[LG, NG, CG, LN, N, CN, LE, NE, CE, Unaligned]
- `xp` integer (default 0)
- `total_level` integer (Rule-computed: sum of class_levels[].level)
- `inspiration` boolean (Heroic Inspiration)
- `proficiency_bonus` integer (Rule-computed from total_level)
- `creature_type` relation→creature-type (default: Humanoid)
- `size` enum[Tiny, Small, Medium, Large] (Rule: from species)
- `speed` integer (Rule: from species, + bonuses)

**Abilities** (grp-abilities, cols=1):
- `stat_block` statBlock (STR/DEX/CON/INT/WIS/CHA, default 10)
- `str_mod`, `dex_mod`, `con_mod`, `int_mod`, `wis_mod`, `cha_mod` integer (Rule-computed)

**Combat** (grp-combat, cols=2):
- `combat_stats` combatStats — subFields: `hp`, `max_hp`, `temp_hp`, `ac`, `speed`, `initiative`, `hit_dice_total`, `hit_dice_spent`, `death_save_success`, `death_save_fail`, `level` (total_level alias)
- `saving_throws` proficiencyTable (6 ability row; `proficient`, `misc` columns)
- `skills` proficiencyTable (18 skill row; `proficient`, `expertise`, `misc` columns)
- `passive_perception` integer (Rule-computed)
- `passive_investigation` integer (Rule-computed)
- `passive_insight` integer (Rule-computed)
- `spell_save_dc` integer (Rule-computed)
- `spell_attack_bonus` integer (Rule-computed)
- `armor_class_base` integer (Rule-computed: 10+DEX or armor-driven)

**Proficiencies** (grp-proficiencies, cols=2):
- `armor_training` tagList [Light, Medium, Heavy, Shield]
- `weapon_category_profs` tagList [Simple, Martial]
- `weapon_specific_profs` relation→weapon (list)
- `tool_proficiencies` relation→tool (list)
- `languages` relation→language (list)

**Resistances** (grp-resistances, cols=2):
- `damage_vulnerabilities` relation→damage-type (list)
- `damage_resistances` relation→damage-type (list)
- `damage_immunities` relation→damage-type (list)
- `condition_immunities` relation→condition (list)

**Features** (grp-features, cols=1):
- `species_traits` relation→trait (list, Rule-populated from species)
- `class_features` relation→trait (list, Rule-populated from class+level)
- `background_feature` relation→trait (single, Rule-populated)
- `feats` relation→feat (list)
- `traits` relation→trait (list, custom)
- `actions` relation→action (list)
- `reactions` relation→reaction (list)
- `legendary_actions` relation→legendary-action (list, rare for PCs)

**Spellcasting** (grp-spellcasting, cols=1):
- `spellcasting_ability` enum [INT, WIS, CHA, None]
- `spellcasting_class` relation→class (single)
- `spells_known` relation→spell (list, hasEquip=true → equipped=prepared)
- `cantrips_known_count` integer (Rule-computed)
- `spell_slots` slot — subFields per level 1-9: `{total, expended}`
- `pact_magic_slots` slot (Warlock)
- `ritual_caster` boolean

**Equipment** (grp-equipment, cols=1):
- `equipment` relation→weapon|armor|gear|magic-item|tool (list, hasEquip=true)
- `attunements` relation→magic-item (list; max 3 Rule-gated)
- `coins` combatStats-style subFields: `cp`, `sp`, `ep`, `gp`, `pp`
- `total_wealth_gp` float (Rule-computed)
- `carrying_capacity` integer (Rule-computed: STR × 15)
- `current_load` float (Rule-computed: sum of equipment weight)
- `encumbered` boolean (Rule-computed)

**Backstory** (grp-backstory, cols=1):
- `personality_traits` textarea
- `ideals` textarea
- `bonds` textarea
- `flaws` textarea
- `appearance` markdown
- `backstory` markdown
- `allies_organizations` markdown
- `age` text; `height` text; `weight` text; `eyes` text; `skin` text; `hair` text
- `trinket` text (SRD p.26 trinket tablosu)

---

### 4.2 `npc`

`player` şablonunun kısaltılmış hali:
- Identity + Abilities + Combat + Resistances + Features + Spellcasting (opt) + Equipment
- Fazla olarak: `attitude` enum [Friendly, Indifferent, Hostile], `location_ref` relation→location, `faction` text, `role_in_story` markdown

### 4.3 `monster`

`npc` + SRD Monster Stat Block tam uyumlu:

**Identity**:
- `name`, `size`, `creature_type_ref` relation→creature-type
- `descriptive_tags` tagList (örn. "shapechanger", "demon", "giant")
- `alignment` enum
- `challenge_rating` enum [0, 1/8, 1/4, 1/2, 1, 2, …, 30]
- `xp_value` integer (Rule-computed from CR)

**Combat**:
- `armor_class` integer
- `hp_formula` text (örn. "20d10+40")
- `hp_average` integer
- `hp_current` integer (encounter-mode)
- `speed_subfields` subFields: `walk`, `burrow`, `climb`, `fly`, `swim`, `hover_bool`
- `saving_throw_modifiers` subFields (6 ability, not proficiencyTable — direkt modifier)
- `skill_modifiers` tagList (key=value: "Perception +5, Stealth +3")
- `senses` tagList ("Darkvision 60 ft.", "Truesight 120 ft.", "Blindsight 30 ft.", "Passive Perception 16")
- `languages` relation→language (list) + `telepathy` text
- `gear` relation→weapon|armor|gear (list)

**Features**:
- `traits` relation→trait (list)
- `actions` relation→action (list)
- `multiattack` text
- `bonus_actions` relation→action (list, filtered)
- `reactions` relation→reaction (list)
- `legendary_action_slots` integer (default 3)
- `legendary_action_uses_in_lair` integer (opt)
- `legendary_actions` relation→legendary-action (list)

---

### 4.4 `class`

**Identity** (grp-identity):
- `primary_ability` tagList (1-2 ability)
- `complexity` enum [Low, Average, High]
- `source_book` text

**Mechanics** (grp-mechanics, cols=2):
- `hit_die` enum [d6, d8, d10, d12]
- `hp_at_lvl1` text (formula: "1d_ + CON")
- `saving_throw_profs` tagList (2 ability)
- `skill_prof_count` integer (default 2)
- `skill_prof_choices` relation→skill (list, pool)
- `weapon_profs_category` tagList [Simple, Martial]
- `weapon_profs_specific` relation→weapon (list)
- `armor_training` tagList
- `tool_profs` relation→tool (list, grants)
- `starting_equipment_a` markdown
- `starting_equipment_b` integer (GP alternative)

**Spellcasting** (grp-spellcasting):
- `spellcasting_ability` enum [None, INT, WIS, CHA]
- `spellcasting_progression` enum [None, Full, Half, Third, PactMagic]
- `ritual_casting` boolean
- `spellcasting_focus` relation→gear (list, opt: Arcane Focus, Holy Symbol, Druidic Focus, Component Pouch)
- `spell_list` relation→spell (list)

**Progression** (grp-progression, cols=1):
- `feature_table` levelTable — 20 satır: her satırda `features`, `rages`, `rage_damage`, `weapon_mastery`, `cantrips`, `spells_known`, vb. sütunlar (subFields)
- `spell_slot_progression` levelTable (20 × 9)
- `cantrips_known_progression` levelTable
- `subclass_level` integer (subclass hangi seviyede alınır)
- `subclasses` relation→subclass (list)

**Features** (grp-features, cols=1):
- `level_features` relation→trait (list, grouped by level via trait.level_gained field)
- `multiclass_requirement_ability` enum
- `multiclass_requirement_score` integer (default 13)
- `multiclass_proficiencies_gained` markdown

### 4.5 `subclass`

- `parent_class` relation→class (single)
- `unlock_level` integer
- `feature_table` levelTable (subclass-specific rows)
- `features` relation→trait (list)
- `spell_list` relation→spell (list, opt: domain spells, oath spells, patron spells)
- `description` markdown

### 4.6 `species`

**Mechanics**:
- `creature_type` relation→creature-type (default Humanoid)
- `size_options` tagList [Small, Medium, Large] (some species pick)
- `speed` integer
- `speed_subfields` subFields: walk, climb, fly, swim, burrow (opt)
- `age_description` text
- `lineages` relation→lineage (list, opt)
- `lineage_required` boolean (true = species forces lineage pick)
- `traits` relation→trait (list)
- `innate_spellcasting_ability_options` tagList [INT, WIS, CHA]
- `special_notes` markdown

### 4.7 `lineage`

- `parent_species` relation→species (single)
- `unlock_level` integer (default 1)
- `benefits_level_1` markdown
- `benefits_level_3` relation→spell (opt)
- `benefits_level_5` relation→spell (opt)
- `traits` relation→trait (list)
- `damage_type` relation→damage-type (opt: draconic ancestors)

### 4.8 `background`

- `ability_scores` tagList (3 abilities user can boost)
- `origin_feat` relation→feat (single)
- `skill_profs` relation→skill (list, 2)
- `tool_prof` relation→tool (single)
- `tool_prof_choices` relation→tool (list, opt: Gaming Set)
- `equipment_a` markdown
- `equipment_b` integer (GP alt: default 50)
- `feature` relation→trait (single, opt)

### 4.9 `feat`

- `category` enum [Origin, General, FightingStyle, EpicBoon]
- `prerequisite_level` integer (default 1)
- `prerequisite_ability` enum (opt)
- `prerequisite_ability_score` integer (opt; default 13)
- `prerequisite_class` relation→class (list, opt)
- `prerequisite_other` text
- `repeatable` boolean
- `asi_amount` integer (0, 1, 2)
- `asi_options` tagList [STR, DEX, CON, INT, WIS, CHA] + "any"
- `asi_max_cap` integer (default 20, EpicBoon=30)
- `benefits` markdown
- `grants_spells` relation→spell (list, opt)
- `grants_cantrips` relation→spell (list, opt)

### 4.10 `language`

- `rarity` enum [Standard, Rare]
- `script` text (Common, Dwarvish, Elvish, Infernal, Celestial, Draconic, Primordial, Thieves' Cant, Deep, Undercommon)
- `typical_speakers` text
- `description` markdown

### 4.11 `skill`

- `ability` enum [STR, DEX, CON, INT, WIS, CHA]
- `description` markdown
- `typical_uses` markdown

### 4.12 `damage-type`

- `category` enum [Physical, Elemental, Esoteric]
- `examples` text
- `common_resistances` text (informational)

### 4.13 `creature-type`

- `description` markdown
- `examples` text
- `affected_by_spells_notes` markdown (informational: "Charm Person: Humanoid only")

### 4.14 `condition`

- `effects` markdown
- `is_stacking` boolean (Exhaustion only)
- `max_level` integer (default 0; Exhaustion=6)
- `remove_methods` markdown ("Lesser Restoration, end of turn, save succeeds")
- `icon` text (Material icon name)
- `color` text (hex)

### 4.15 `action` / `reaction` / `legendary-action`

**Common fields**:
- `action_economy` enum [Action, BonusAction, Reaction, Free, Legendary, Lair]
- `trigger` text (reaction-only)
- `description` markdown
- `recharge` text ("5-6", "1/Day", "Short Rest", "Long Rest", "At Will")
- `recharge_remaining` integer (encounter-mode)
- `to_hit` dice ("+8")
- `reach_or_range` text ("5 ft.", "30/120 ft.")
- `target` text
- `damage_dice` dice
- `damage_type` relation→damage-type
- `damage_additional_dice` dice (opt)
- `damage_additional_type` relation→damage-type (opt)
- `save_ability` enum (opt)
- `save_dc_formula` text ("8 + PB + CON")
- `half_damage_on_save` boolean
- `on_fail_effect` markdown
- `on_success_effect` markdown
- `area_of_effect` enum [None, Cone, Cube, Cylinder, Emanation, Line, Sphere]
- `aoe_size` text
- `legendary_cost` integer (1, 2, 3)

### 4.16 `spell`

- `level` enum [0 (Cantrip), 1, 2, 3, 4, 5, 6, 7, 8, 9]
- `school` enum [Abjuration, Conjuration, Divination, Enchantment, Evocation, Illusion, Necromancy, Transmutation]
- `casting_time_type` enum [Action, BonusAction, Reaction, Minute, Hour, Ritual]
- `casting_time_value` text
- `reaction_trigger` text (if Reaction)
- `range_type` enum [Self, Touch, Sight, Unlimited, Feet]
- `range_feet` integer
- `components_v` boolean
- `components_s` boolean
- `components_m` boolean
- `material_component` text
- `material_consumed` boolean
- `material_cost_gp` float (opt)
- `duration_type` enum [Instantaneous, Rounds, Minutes, Hours, Days, UntilDispelled, Special]
- `duration_value` integer
- `concentration` boolean
- `ritual_tag` boolean
- `classes` relation→class (list)
- `subclasses_only` relation→subclass (list, opt)
- `attack_type` enum [None, MeleeSpellAttack, RangedSpellAttack]
- `damage_dice` dice (opt)
- `damage_type` relation→damage-type (opt)
- `save_ability` enum (opt)
- `half_damage_on_save` boolean
- `area_of_effect` enum [None, Cone, Cube, Cylinder, Emanation, Line, Sphere]
- `aoe_size_feet` integer
- `description` markdown
- `higher_level` markdown
- `cantrip_upgrade` markdown (levels 5/11/17)

### 4.17 `weapon`

- `category` enum [Simple, Martial]
- `range_type` enum [Melee, Ranged]
- `damage_dice` dice
- `damage_type_ref` relation→damage-type
- `properties` tagList [Ammunition, Finesse, Heavy, Light, Loading, Range, Reach, Thrown, Two-Handed, Versatile]
- `versatile_dice` dice (opt; two-handed damage)
- `mastery` enum [Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex]
- `range_normal_ft` integer
- `range_long_ft` integer
- `ammunition_type` text (Arrow, Bolt, Needle, Bullet_Sling, Bullet_Firearm)
- `ammunition_ref` relation→gear (single, opt)
- `cost_gp` float
- `weight_lb` float
- `description` markdown

### 4.18 `armor`

- `category` enum [Light, Medium, Heavy, Shield]
- `base_ac` integer
- `dex_cap` integer (nullable: unlimited=null, Light=unlimited, Medium=2, Heavy=0, Shield=null)
- `min_str` integer (Heavy armor)
- `stealth_disadvantage` boolean
- `don_time` text
- `doff_time` text
- `cost_gp` float
- `weight_lb` float
- `description` markdown

### 4.19 `tool`

- `category` enum [ArtisanTools, GamingSet, MusicalInstrument, Other, VehicleLand, VehicleWater]
- `ability` enum [STR, DEX, CON, INT, WIS, CHA]
- `utilize_action` markdown
- `utilize_dc` integer
- `crafts` relation→gear|weapon|armor (list, opt)
- `variants` tagList (örn. Bagpipes/Drum/... for MusicalInstrument)
- `cost_gp` float
- `weight_lb` float

### 4.20 `gear`

- `category` enum [AdventuringGear, Pack, Ammunition, Focus, Mount, TackHarness, Vehicle, LiquidContainer, Light, Consumable]
- `cost_cp` integer
- `cost_sp` integer
- `cost_gp` float
- `weight_lb` float
- `capacity_lb` float (opt: Backpack, Chest…)
- `contents` relation→gear (list, opt: packs contain gear)
- `usage_notes` markdown
- `utilize_action` markdown (opt)
- `consumable` boolean
- `arcane_focus_subtype` text (opt: Crystal, Orb, Rod, Staff, Wand)
- `holy_symbol_subtype` enum [Amulet, Emblem, Reliquary] (opt)
- `druidic_focus_subtype` enum [Mistletoe, WoodenStaff, YewWand] (opt)

### 4.21 `vehicle`

- `category` enum [Mount, LandVehicle, WaterVehicle, AirVehicle]
- `speed_mph` float
- `speed_ft` integer (mount speed)
- `carrying_capacity_lb` integer
- `crew_min` integer
- `passengers` integer
- `cargo_tons` float
- `ac` integer
- `hp` integer
- `damage_threshold` integer
- `cost_gp` float

### 4.22 `magic-item`

- `category` enum [Armor, Potion, Ring, Rod, Scroll, Staff, Wand, Weapon, WondrousItem]
- `rarity` enum [Common, Uncommon, Rare, VeryRare, Legendary, Artifact]
- `attunement_required` boolean
- `attunement_prereq_text` text (class/species/alignment req)
- `attunement_prereq_class` relation→class (list, opt)
- `base_item_ref_weapon` relation→weapon (opt)
- `base_item_ref_armor` relation→armor (opt)
- `base_item_ref_gear` relation→gear (opt)
- `charges_max` integer
- `charges_regen` text ("daily at dawn", "1d4+1 at dawn")
- `charges_regen_formula` dice (opt)
- `cursed` boolean
- `sentient` boolean
- `sentient_stats` conditionStats-like subFields: `int_score`, `wis_score`, `cha_score`, `alignment`, `communication`, `senses_range`
- `sentient_purpose` text
- `effects` markdown
- `consumable` boolean
- `value_gp` float (Rule-computed from rarity)
- `crafting_time_days` integer
- `crafting_cost_gp` float
- `crafting_tool_ref` relation→tool (list, opt)

### 4.23 `location`

- `type` enum [Settlement, Dungeon, Wilderness, Building, Region, Plane]
- `danger_level` enum [Safe, Low, Medium, High, Deadly]
- `environment` text (Arctic, Coastal, Desert, Forest, Grassland, Hill, Mountain, Swamp, Underwater, Urban, Underdark)
- `population` integer
- `ruler_ref` relation→npc (single, opt)
- `parent_location` relation→location (single, opt)
- `child_locations` relation→location (list, opt)
- `plane_ref` relation→plane (single, opt)
- `linked_quests` relation→quest (list)
- `linked_lore` relation→lore (list)
- `visited_by_party` boolean
- `map_image` image
- `description` markdown

### 4.24 `plane`

- `type` enum [Material, Inner, Outer, Transitive]
- `inner_subtype` enum [Air, Earth, Fire, Water, Feywild, Shadowfell] (opt)
- `outer_subtype` enum [Arborea, Arcadia, Beastlands, Bytopia, Elysium, Mechanus, Mount_Celestia, Ysgard, Abyss, Acheron, Carceri, Gehenna, Hades, Limbo, Nine_Hells, Pandemonium] (opt)
- `dominant_alignment` enum
- `description` markdown

### 4.25 `quest`

- `status` enum [NotStarted, Active, Completed, Failed, OnHold]
- `giver_ref` relation→npc (single)
- `location_ref` relation→location (single)
- `reward_gold` float
- `reward_items` relation→magic-item|gear (list)
- `reward_xp` integer
- `objectives` textarea
- `completed_objectives` textarea
- `parent_quest` relation→quest (single, opt)
- `subquests` relation→quest (list)
- `deadline` date (opt)
- `priority` enum [Low, Medium, High, Urgent]

### 4.26 `lore`

- `category` enum [History, Geography, Religion, Culture, Politics, Flora_Fauna, Other]
- `secret_info` markdown
- `known_by` relation→npc (list)
- `tags` tagList
- `era` text (timestamp or period name)

### 4.27 `status-effect` (encounter-only)

- `condition_ref` relation→condition (single)
- `duration_turns` integer
- `duration_type` enum [Turns, Rounds, Minutes, UntilSaved, EndOfEncounter]
- `save_dc` integer
- `save_ability` enum
- `save_end_of_turn` boolean
- `level` integer (exhaustion)
- `source_ref` relation→spell|action|magic-item (single, opt)
- `applied_to_ref` relation→player|npc|monster (single)

### 4.28 `encounter`

- `participants` relation→player|npc|monster (list, hasEquip=active)
- `turn_order` textarea (initiative list)
- `current_round` integer
- `current_turn_index` integer
- `location_ref` relation→location (single)
- `environment_effects` markdown
- `loot` relation→magic-item|gear (list)
- `notes` markdown
- `resolved` boolean
- `xp_awarded` integer

### 4.29 `campaign-session`

- `session_number` integer
- `date` date
- `duration_hours` float
- `in_game_start_date` text
- `in_game_end_date` text
- `party_level` integer
- `summary` markdown
- `player_notes` markdown
- `dm_notes` markdown (private)
- `xp_awarded` integer
- `loot_awarded` relation→magic-item|gear (list)
- `quests_advanced` relation→quest (list)
- `npcs_introduced` relation→npc (list)

---

## 5. Seed Entity Listesi (örneklem)

Her seed isBuiltin=true + slug-like id (örn. `spell-fireball`, `class-wizard`, `condition-blinded`). Tam listeler ayrı JSON dosyalarında saklanacak (ilerleyen faz).

### Classes (12)
Barbarian, Bard, Cleric, Druid, Fighter, Monk, Paladin, Ranger, Rogue, Sorcerer, Warlock, Wizard

### Subclasses (12 — SRD kapsamında her class için 1)
Path of the Berserker, College of Lore, Life Domain, Circle of the Land, Champion, Warrior of the Open Hand, Oath of Devotion, Hunter, Thief, Draconic Sorcery, Fiend Patron, Evoker

### Species (9)
Dragonborn, Dwarf, Elf, Gnome, Goliath, Halfling, Human, Orc, Tiefling

### Lineages
- Draconic Ancestors: Black, Blue, Brass, Bronze, Copper, Gold, Green, Red, Silver, White
- Elven: Drow, High Elf, Wood Elf
- Gnomish: Forest Gnome, Rock Gnome
- Giant: Cloud's Jaunt, Fire's Burn, Frost's Chill, Hill's Tumble, Stone's Endurance, Storm's Thunder
- Fiendish: Abyssal, Chthonic, Infernal

### Backgrounds (4)
Acolyte, Criminal, Sage, Soldier

### Feats (tam liste)
- Origin: Alert, Magic Initiate, Savage Attacker, Skilled
- General: Ability Score Improvement, Grappler, ... (SRD p.87-88 aynen 10+)
- Fighting Style: Archery, Defense, Great Weapon Fighting, Two-Weapon Fighting
- Epic Boon: Combat Prowess, Dimensional Travel, Fate, Irresistible Offense, Spell Recall, Night Spirit, Truesight

### Languages (20)
**Standard (12)**: Common, Common Sign, Draconic, Dwarvish, Elvish, Giant, Gnomish, Goblin, Halfling, Orc, (2 more from species)
**Rare (8)**: Abyssal, Celestial, Deep Speech, Druidic, Infernal, Primordial, Sylvan, Thieves' Cant, Undercommon

### Skills (18) — constants.dart zaten tanımlı

### Damage Types (13)
Acid, Bludgeoning, Cold, Fire, Force, Lightning, Necrotic, Piercing, Poison, Psychic, Radiant, Slashing, Thunder

### Creature Types (14)
Aberration, Beast, Celestial, Construct, Dragon, Elemental, Fey, Fiend, Giant, Humanoid, Monstrosity, Ooze, Plant, Undead

### Conditions (15)
Blinded, Charmed, Deafened, Exhaustion, Frightened, Grappled, Incapacitated, Invisible, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious

### Actions (SRD p.176 tanımları)
Attack, Dash, Disengage, Dodge, Help, Hide, Influence, Magic, Ready, Search, Study, Utilize, Opportunity Attack (reaction)

### Weapons (38)

**Simple Melee (10)**: Club, Dagger, Greatclub, Handaxe, Javelin, Light Hammer, Mace, Quarterstaff, Sickle, Spear
**Simple Ranged (4)**: Dart, Light Crossbow, Shortbow, Sling
**Martial Melee (18)**: Battleaxe, Flail, Glaive, Greataxe, Greatsword, Halberd, Lance, Longsword, Maul, Morningstar, Pike, Rapier, Scimitar, Shortsword, Trident, Warhammer, War Pick, Whip
**Martial Ranged (6)**: Blowgun, Hand Crossbow, Heavy Crossbow, Longbow, Musket, Pistol

### Armor (13)

**Light (3)**: Padded, Leather, Studded Leather
**Medium (5)**: Hide, Chain Shirt, Scale Mail, Breastplate, Half Plate
**Heavy (4)**: Ring Mail, Chain Mail, Splint, Plate
**Shield (1)**: Shield

### Tools

**Artisan (18)**: Alchemist's Supplies, Brewer's Supplies, Calligrapher's Supplies, Carpenter's Tools, Cartographer's Tools, Cobbler's Tools, Cook's Utensils, Glassblower's Tools, Jeweler's Tools, Leatherworker's Tools, Mason's Tools, Painter's Supplies, Potter's Tools, Smith's Tools, Tinker's Tools, Weaver's Tools, Woodcarver's Tools
**Other (7)**: Disguise Kit, Forgery Kit, Gaming Set, Herbalism Kit, Musical Instrument, Navigator's Tools, Poisoner's Kit, Thieves' Tools

### Gear — SRD p.94-99 tablosu (~80 entry)
Acid, Alchemist's Fire, Ammunition (5 type), Antitoxin, Arcane Focus (5 subtype), Backpack, Ball Bearings, Barrel, Basket, Bedroll, Bell, Blanket, Block and Tackle, Book, Bottle (Glass), Bucket, **Burglar's Pack**, Caltrops, Candle, Case (Crossbow/Map), Chain, Chest, Climber's Kit, Clothes (Fine/Traveler's/Costume), Component Pouch, Crowbar, **Diplomat's Pack**, Druidic Focus (3 subtype), **Dungeoneer's Pack**, **Entertainer's Pack**, **Explorer's Pack**, Flask, Grappling Hook, Healer's Kit, Holy Symbol (3 subtype), Holy Water, Hunting Trap, Ink, Ink Pen, Jug, Ladder, Lamp, Lantern (Bullseye/Hooded), Lock, Magnifying Glass, Manacles, Map, Mirror, Net, Oil, Paper, Parchment, Perfume, Poison (Basic), Pole, Pot (Iron), Potion of Healing, Pouch, **Priest's Pack**, Quiver, Ram (Portable), Rations, Robe, Rope, Sack, **Scholar's Pack**, Shovel, Signal Whistle, Spell Scroll (Cantrip/Level 1), Spikes (Iron), Spyglass, String, Tent, Tinderbox, Torch, Vial, Waterskin

### Spells (~340 — SRD p.107-175 tam liste)
Abjuration, Conjuration, Divination, Enchantment, Evocation, Illusion, Necromancy, Transmutation — 8 okul, 10 seviye. Örnekler: Acid Arrow, Acid Splash, Aid, Alarm, Alter Self, Animal Friendship, Animate Dead, Animate Objects, Antilife Shell, Antimagic Field, Antipathy/Sympathy, Arcane Eye, Arcane Hand, Arcane Lock, Arcane Sword, ... (PDF p.107+ aynen).

### Monsters (~190 — SRD p.258-343 tam liste)
Örnek: Aboleth, Air Elemental, Ankheg, Assassin, Awakened Shrub, ..., Zombie.

### Magic Items (~170 — SRD p.204-253 tam liste)
Örnek: Adamantine Armor, Amulet of Health, Amulet of Proof against Detection and Location, Amulet of the Planes, Animated Shield, Apparatus of the Crab, Armor +1/+2/+3, Armor of Invulnerability, Armor of Resistance, ...

---

## 6. EncounterConfig Güncellemesi

```
combatStatsFieldKey  : 'combat_stats'
conditionStatsFieldKey: 'condition_stats'
statBlockFieldKey    : 'stat_block'
initiativeSubField   : 'initiative'
sortBySubField       : 'initiative'
sortDirection        : 'desc'
columns              : [
  {subFieldKey: 'level',       label: 'Lvl',  width: 36},
  {subFieldKey: 'initiative',  label: 'Init', width: 48},
  {subFieldKey: 'ac',          label: 'AC',   width: 36},
  {subFieldKey: 'hp',          label: 'HP',   width: 130, showButtons: true},
  {subFieldKey: 'speed',       label: 'Spd',  width: 48},
  {subFieldKey: 'passive_perception', label: 'PP', width: 36},
]
conditions           : [15 SRD conditions]
```

---

## 7. JSON Export Örneği (Fighter level 5)

```json
{
  "id": "pc-aragorn",
  "name": "Aragorn",
  "categorySlug": "player",
  "fields": {
    "species_ref": "species-human",
    "class_levels": [{"id": "class-fighter", "level": 5, "subclass": "subclass-champion"}],
    "background_ref": "background-soldier",
    "alignment": "LG",
    "total_level": 5,
    "xp": 6500,
    "proficiency_bonus": 3,
    "stat_block": {"STR":16,"DEX":14,"CON":14,"INT":10,"WIS":12,"CHA":10},
    "str_mod": 3, "dex_mod": 2, "con_mod": 2, "int_mod": 0, "wis_mod": 1, "cha_mod": 0,
    "combat_stats": {
      "hp": 44, "max_hp": 44, "temp_hp": 0,
      "ac": 18, "speed": 30, "initiative": 2,
      "hit_dice_total": 5, "hit_dice_spent": 0,
      "death_save_success": 0, "death_save_fail": 0
    },
    "saving_throws": {"rows":[
      {"name":"STR","ability":"STR","proficient":true,"misc":0},
      {"name":"DEX","ability":"DEX","proficient":false,"misc":0},
      ...
    ]},
    "skills": {"rows":[
      {"name":"Athletics","ability":"STR","proficient":true,"expertise":false,"misc":0},
      ...
    ]},
    "passive_perception": 11,
    "spell_save_dc": 0,
    "armor_training": ["Light","Medium","Heavy","Shield"],
    "weapon_category_profs": ["Simple","Martial"],
    "languages": ["language-common","language-orc"],
    "equipment": [
      {"id":"armor-plate","equipped":true,"source":"manual"},
      {"id":"weapon-longsword","equipped":true,"source":"manual"},
      {"id":"armor-shield","equipped":true,"source":"manual"}
    ],
    "attunements": [],
    "coins": {"cp":0,"sp":0,"ep":0,"gp":75,"pp":0},
    "feats": ["feat-savage-attacker"]
  }
}
```

---

## 8. Karakter Yaratma Akışı (UI için not)

SRD p.19 Character Creation 5-step:
1. **Choose Class** → `player.class_levels[0].id` pick
2. **Determine Origin** → `species_ref` + `lineage_ref` + `background_ref` + 3 language pick
3. **Determine Ability Scores** → Standard Array / Point Cost / 4d6 drop-lowest → `stat_block`
4. **Choose Alignment** → `alignment`
5. **Fill Details** → features, skills, equipment, backstory

Bu flow'u bir **Character Creation Wizard** içinde sırayla uygulayan UI widget — ayrı sprint.

---

## 9. Dosya Organizasyonu Önerisi

```
flutter_app/lib/domain/entities/schema/
├── dnd5e_constants.dart                 (genişletilecek — 13 damage type, 14 creature type, 15 condition, 20 language, 38 weapon, 13 armor, PB/XP tabloları)
├── default_dnd5e_schema.dart            (33 kategori tanımı — ana builder)
├── default_dnd5e_groups.dart            (yeni — 17 grup constant)
├── default_dnd5e_rules.dart             (yeni — RuleV3 seed listesi; ayrı dökümana bakınız)
└── default_dnd5e_seed_entities/
    ├── classes.json                     (12 class entity)
    ├── subclasses.json                  (12 subclass)
    ├── species.json                     (9 species)
    ├── lineages.json                    (~22 lineage)
    ├── backgrounds.json                 (4)
    ├── feats.json                       (~40)
    ├── languages.json                   (20)
    ├── skills.json                      (18)
    ├── damage_types.json                (13)
    ├── creature_types.json              (14)
    ├── conditions.json                  (15)
    ├── actions.json                     (~12)
    ├── spells.json                      (~340)
    ├── weapons.json                     (38)
    ├── armors.json                      (13)
    ├── tools.json                       (~25)
    ├── gear.json                        (~80)
    ├── magic_items.json                 (~170)
    └── monsters.json                    (~190)
```

Seed dosyaları asset olarak bundle edilir; ilk kampanya açılışında `WorldSchema.categories` + seed `Entity` listesi birlikte yüklenir.

---

## 10. Özet

| Metric | Değer |
|--------|-------|
| Kategori sayısı | 33 |
| Grup sayısı (unique) | 17 |
| Field tipi kullanımı | Tüm 18 tip (FieldType enum) |
| Seed entity sayısı | ~1150 (spells + monsters + magic items + base data) |
| Built-in RuleV3 | ~60 (ayrı dökümanda) |
| PDF coverage | 100% SRD 5.2.1 mekanikleri |
| Cloud backup boyut tahmini | ~12 MB gzip (.json.gz) |

Bu döküman, `WorldSchema` altyapısının **tam SRD uyumlu** hale gelmesi için gerekli veri modelini sağlar. Rule engine için [RULES_V3_SPECIFICATION.md](RULES_V3_SPECIFICATION.md). Kod tarafında uygulama için [RULES_V3_IMPLEMENTATION_GUIDE.md](RULES_V3_IMPLEMENTATION_GUIDE.md).
