# Built-in D&D 5e Template — Design Document

Design reference for the rebuilt `builtin-dnd5e-default` `WorldSchema`. Target: 1:1 with **SRD 5.2.1 (CC-BY-4.0)** — every rule-glossary term becomes either a lookup-catalog category (damage types, conditions, skills, …) or a content category (spells, classes, monsters, …), so nothing in the SRD is free-form text when a canonical list exists.

Supersedes the 19-category schema in [flutter_app/lib/domain/entities/schema/default_dnd5e_schema.dart](flutter_app/lib/domain/entities/schema/default_dnd5e_schema.dart). See [TEMPLATES_FIELDS_GROUPS_RULES.md](TEMPLATES_FIELDS_GROUPS_RULES.md) for the schema engine itself (`WorldSchema` / `EntityCategorySchema` / `FieldSchema` / `RuleV2`).

**Status:** design only. No code until approved.

---

## 1. Goals and Non-Goals

### Goals

- Every SRD 5.2.1 section reachable from the template as first-class data — **no free-text where a canonical list exists**.
- Every categorizable SRD value (damage type, condition, skill, …) reified as its own category so that other entities point at real rows, not strings.
- Relation fields (`FieldType.relation`) carry `allowedTypes` with the target slug — typos become impossible.
- Schema is **built-in / read-only**: `isBuiltin=true` on every category and field. User-added categories live alongside but never collide (reserved slug prefix `srd:`? see §9).
- Deterministic `originalHash` so every install agrees on the lineage. Bump suffix if shape changes in a breaking way.
- Encounter-tracker (initiative, HP, conditions) keeps working without custom config — fields are named the same as the engine expects.

### Non-Goals

- Full combat rule engine (damage resolution, spell casting, …) — that is RuleEngineV2 + the typed combat services; template only carries **data shape**, not behavior.
- Campaign content (specific locations, quests, NPCs) — those are user entities, not template categories.
- Homebrew classes/subclasses beyond the SRD 12 — users author those as normal entities in the same categories.
- Pathfinder / other systems — separate template, separate doc.

---

## 2. Source Mapping

SRD page → category. Page numbers reference `docs/SRD_CC_v5.2.1.pdf`.

| SRD pages | SRD section | Categories produced |
|-----------|-------------|---------------------|
| 5–8 | Playing the Game / Abilities / D20 Tests | Ability (lookup), Skill (lookup) |
| 9 | Skills table | Skill (18 rows) |
| 10 | Actions | Action (12 standard rows) |
| 11 | Vision/Light, Senses | Illumination (lookup), Sense (lookup) |
| 12 | Hazards, Travel | Hazard (lookup), Travel Pace (lookup) |
| 13–15 | Combat, Cover, Size, Movement | Cover (lookup), Size (lookup) |
| 16–17 | Damage and Healing | Damage Type (lookup, 13) |
| 19–27 | Character Creation / Trinkets | Alignment (lookup, 9+1), Trinket (100 rows), Tier of Play (lookup, 4) |
| 28–82 | Classes (12) + Subclasses | Class, Subclass |
| 83–86 | Character Origins | Species, Background, Language |
| 87–88 | Feats | Feat, Feat Category (lookup, 4) |
| 89–91 | Weapons + Properties + Mastery | Weapon, Weapon Property (lookup, 11), Weapon Mastery (lookup, 8), Weapon Category (lookup, 2) |
| 92 | Armor | Armor, Armor Category (lookup, 4) |
| 93–94 | Tools | Tool, Tool Category (lookup, 3) |
| 94–99 | Adventuring Gear + Packs + Ammunition | Adventuring Gear, Ammunition, Pack, Arcane Focus (lookup, 5), Druidic Focus (lookup, 3), Holy Symbol (lookup, 3) |
| 100–101 | Mounts, Vehicles, Lifestyle | Mount, Vehicle, Lifestyle (lookup, 7) |
| 101 | Food, Drink, Lodging | (values embedded on Lifestyle rows) |
| 102–103 | Hirelings, Spellcasting services, Crafting | Hireling, Service (lookup) |
| 104–175 | Spells | Spell, Spell School (lookup, 8) |
| 176–191 | Rules Glossary | Condition (lookup, 15), Area of Effect Shape (lookup, 6), Attitude (lookup, 3), Creature Type (lookup, 14), Speed Type (lookup, 5) |
| 192–203 | Gameplay Toolbox | Curse, Environmental Effect, Trap, Poison |
| 204–253 | Magic Items | Magic Item, Magic Item Category (lookup, 9), Rarity (lookup, 6), Plane (lookup, 17) |
| 254–363 | Monsters + Animals | Monster, Monster Tag (lookup) |

Plus five campaign-author categories with no SRD mapping but required for the DM tool: **NPC**, **Player Character**, **Location**, **Scene**, **Quest**, **Encounter**, **Condition Effect** (instance-level applied condition, separate from `Condition` lookup).

---

## 3. Category Tiers

Three tiers by role. Each category carries `isBuiltin=true`.

### Tier 0 — Lookup Catalogs (enum-as-entity)

Small, closed SRD lists. Row count fixed by RAW. Entries are typically **1 name field + optional description/effect + icon/color**. Other entities reference them via `FieldType.relation` with `allowedTypes: ['<slug>']`.

| Slug | Rows | Source |
|------|------|--------|
| `ability` | 6 | STR/DEX/CON/INT/WIS/CHA |
| `skill` | 18 | p9 Skills table |
| `damage-type` | 13 | p180 — Acid, Bludgeoning, Cold, Fire, Force, Lightning, Necrotic, Piercing, Poison, Psychic, Radiant, Slashing, Thunder |
| `condition` | 15 | p179 — Blinded, Charmed, Deafened, Exhaustion, Frightened, Grappled, Incapacitated, Invisible, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious |
| `size` | 6 | p14 — Tiny, Small, Medium, Large, Huge, Gargantuan |
| `creature-type` | 14 | p179 — Aberration, Beast, Celestial, Construct, Dragon, Elemental, Fey, Fiend, Giant, Humanoid, Monstrosity, Ooze, Plant, Undead |
| `alignment` | 10 | p20-21 — 9 named + Unaligned |
| `language` | 19 | p20 — 10 Standard + 9 Rare |
| `weapon-category` | 2 | Simple, Martial |
| `weapon-property` | 11 | p89 — Ammunition, Finesse, Heavy, Light, Loading, Range, Reach, Thrown, Two-Handed, Versatile, Improvised (glossary) |
| `weapon-mastery` | 8 | p90 — Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex |
| `armor-category` | 4 | Light, Medium, Heavy, Shield |
| `tool-category` | 3 | Artisan's Tools, Other Tools, Gaming Set — plus instrument and gaming set as subtype (see §5.Tool) |
| `spell-school` | 8 | Abjuration, Conjuration, Divination, Enchantment, Evocation, Illusion, Necromancy, Transmutation |
| `magic-item-category` | 9 | p204 — Armor, Potions, Rings, Rods, Scrolls, Staffs, Wands, Weapons, Wondrous Items |
| `rarity` | 6 | p206 — Common, Uncommon, Rare, Very Rare, Legendary, Artifact |
| `speed-type` | 5 | Walking, Burrow, Climb, Fly, Swim |
| `sense` | 4 | Blindsight, Darkvision, Tremorsense, Truesight |
| `action` | 12 | p9-10 — Attack, Dash, Disengage, Dodge, Help, Hide, Influence, Magic, Ready, Search, Study, Utilize |
| `area-shape` | 6 | Cone, Cube, Cylinder, Emanation, Line, Sphere |
| `attitude` | 3 | Friendly, Indifferent, Hostile |
| `cover` | 3 | Half, Three-Quarters, Total |
| `illumination` | 3 | Bright Light, Dim Light, Darkness |
| `hazard` | 5 | Burning, Dehydration, Falling, Malnutrition, Suffocation |
| `feat-category` | 4 | Origin, General, Fighting Style, Epic Boon |
| `lifestyle` | 7 | p101 — Wretched, Squalid, Poor, Modest, Comfortable, Wealthy, Aristocratic |
| `coin` | 5 | CP, SP, EP, GP, PP |
| `tier-of-play` | 4 | p23 — Tier 1 (1-4), Tier 2 (5-10), Tier 3 (11-16), Tier 4 (17-20) |
| `travel-pace` | 3 | Fast, Normal, Slow |
| `arcane-focus` | 5 | Crystal, Orb, Rod, Staff, Wand |
| `druidic-focus` | 3 | Sprig of mistletoe, Wooden staff, Yew wand |
| `holy-symbol` | 3 | Amulet, Emblem, Reliquary |
| `plane` | 17 | p209 — Material, Astral, Ethereal, 6 Inner, 8 Outer (upper), 8 Outer (lower) grouped |
| `casting-component` | 3 | Verbal, Somatic, Material |
| `casting-time-unit` | 7 | Action, Bonus Action, Reaction, Minute, Hour, Ritual, Special |
| `duration-unit` | 5 | Instantaneous, Rounds, Minutes, Hours, Days + Concentration flag |

**Total Tier 0: 35 lookup categories.**

### Tier 1 — SRD Content Entities

Large, open catalogs that reference Tier 0 lookups.

| Slug | Rough SRD row count | Source |
|------|---------------------|--------|
| `class` | 12 | p28-82 |
| `subclass` | 12 (one per class, SRD only) | p28-82 |
| `species` | 9 | p84-86 |
| `background` | 16 (SRD-CC backgrounds) | p83 + Gameplay Toolbox |
| `feat` | ~50 (Origin + General + FightingStyle + EpicBoon) | p87-88 + later |
| `spell` | ~360 | p104-175 |
| `weapon` | 37 | p91 |
| `armor` | 13 | p92 |
| `tool` | ~28 | p93-94 |
| `adventuring-gear` | ~70 | p94-99 |
| `ammunition` | 5 | p96 |
| `pack` | 7 | p95 |
| `mount` | 8 | p100 |
| `vehicle` | 7 (+ drawn) | p100 |
| `trinket` | 100 | p26-27 |
| `magic-item` | ~200 | p209-253 |
| `monster` | ~300 | p258-363 |
| `animal` | ~50 | p344-363 |

### Tier 2 — DM / Campaign Categories

User-authored; no SRD rows shipped by default.

| Slug | Purpose |
|------|---------|
| `npc` | Named adversaries/allies beyond stat-block-only monsters |
| `player-character` | PC sheet (ties to a user profile) |
| `location` | Places on the world map |
| `scene` | Mind-map scene / session beat |
| `quest` | Tracked objective |
| `encounter` | Combat scenario with monster roster |
| `applied-condition` | Runtime instance of a condition on a combatant (duration + effect) |
| `trap` | Gameplay Toolbox p199 |
| `poison` | Gameplay Toolbox p197 |
| `curse` | Gameplay Toolbox p193 |
| `environmental-effect` | Gameplay Toolbox p195 |
| `hireling` | p102 |
| `service` | p102 spellcasting service prices etc. |

**Total categories shipped: ~60** (35 lookup + 18 content + ~10 DM).

---

## 4. Field Conventions

Before per-category specs, the rules that hold across all categories.

### 4.1 Identity fields (every category)

Every `Entity` already carries `id`, `name`, `categorySlug`, `source`, `description`, `images`, `tags`, `dmNotes`, `pdfs`, `locationId` via the base `Entity` class. Template never redefines these; it only adds `fields: Map<String, dynamic>`.

### 4.2 Naming

- `fieldKey` is `snake_case` ASCII.
- Label is Title Case English.
- Relation field keys end with `_ref` for single, plural noun for list (`race_ref`, `spells`, `resistances`).
- Dice fields end with `_dice` (`damage_dice`, `hit_die`).
- Integer stats never carry units in the key; units carried in the helpText (`speed_ft`, not `speed`).

### 4.3 Units

- Distance: **feet** (integer). Key suffix `_ft`.
- Weight: **pounds** (float, allows ½). Key suffix `_lb`.
- Currency: **copper pieces** (integer) to dodge fractional GP; display layer converts. Key suffix `_cp`. Alt: store a `{amount, coin_ref}` object — see §9 open questions.
- Time: shortest integer granularity the SRD uses for that field (rounds for effects, minutes for travel, hours for rest). Unit baked into the key.

### 4.4 Validation

Every numeric field gets `minValue`/`maxValue` where the SRD is explicit (ability score 1–30, character level 1–20, CR 0–30, spell level 0–9, …). Validation blocks impossible data entry at the FieldWidget layer.

### 4.5 Groups

Every category carries at least the groups its fields need. Standard group ids (reused across categories):

| Group id | Label | Grid cols | Where it appears |
|----------|-------|-----------|------------------|
| `grp-identity` | Identity | 2 | all (name/source/description) |
| `grp-ability-scores` | Ability Scores | 1 | Monster, NPC, PC |
| `grp-combat` | Combat | 2 | Monster, NPC, PC |
| `grp-resistances` | Defenses | 2 | Monster, NPC, PC |
| `grp-senses-languages` | Senses & Languages | 2 | Monster, NPC, PC |
| `grp-traits-actions` | Traits & Actions | 1 | Monster, NPC |
| `grp-spells` | Spells | 1 | Monster, NPC, PC, Class |
| `grp-meta` | Meta | 2 | all (tags, source, xp, cr) |
| `grp-rules` | Rules Text | 1 | Spell, Feat, Feature |
| `grp-cost-weight` | Cost & Weight | 2 | physical-item categories |
| `grp-properties` | Properties | 2 | Weapon, Armor, Magic Item |

### 4.6 Relation cardinality markers

- Single-ref: `FieldType.relation`, `isList=false`.
- Multi-ref ordered list: `FieldType.relation`, `isList=true`.
- Multi-ref unordered set: same but rules consume as a set (no dup detection in engine today — see §9).

---

## 5. Per-Category Specifications

Each entry lists fields in storage order. **Legend:** `K` field key · `T` field type · `R?` required · `V` validation / notes.

### 5.1 Tier 0 — Lookup Catalogs

All Tier-0 categories share a minimal shape. Generic spec (used by every one unless overridden):

| K | T | R? | V |
|---|---|----|---|
| `abbreviation` | text | n | short code (e.g. "STR", "CP", "LG") |
| `summary` | textarea | n | one-line glossary definition |
| `effects` | markdown | n | full glossary body, where applicable |
| `icon_name` | text | n | Material Icons name |
| `color` | text | n | hex |

Extra fields per catalog:

#### damage-type

- `example_sources` — textarea, examples from p180 table ("Corrosive liquids, digestive enzymes").
- `is_physical` — boolean (true for Bludgeoning/Piercing/Slashing only).

#### condition

- `stacks` — boolean (Exhaustion only — p179).
- `ends_on` — textarea — removal rules.
- `grants_incapacitated` — boolean (Paralyzed/Petrified/Stunned/Unconscious imply Incapacitated).

#### skill

- `ability_ref` — relation → `ability`, required. Drives the d20 roll.
- `examples` — textarea.

#### ability

- `order_index` is fixed 0–5 (STR→CHA) — filter sort uses this not name.

#### size

- `space_ft` — float — diameter (2.5 / 5 / 10 / 15 / 20).
- `squares` — float (4-per-square / 1 / 4 / 9 / 16).
- `hit_die_size` — enum `d4/d6/d8/d10/d12/d20` (p255 monster HP rule).

#### creature-type

- `default_skills_note` — textarea (e.g. Beasts → Animal Handling).

#### alignment

- `morality` — enum `Good/Neutral/Evil`.
- `order` — enum `Lawful/Neutral/Chaotic`.

#### language

- `tier` — enum `Standard/Rare`.
- `typical_speakers` — textarea.
- `script` — text (Dwarvish/Elvish/Common/etc. — not in SRD 5.2.1; leave blank).

#### weapon-property / weapon-mastery / weapon-category / armor-category / tool-category / spell-school / magic-item-category / rarity / action / area-shape / attitude / cover / illumination / hazard / feat-category / lifestyle / tier-of-play / travel-pace / plane / casting-component / casting-time-unit / duration-unit / sense / speed-type / arcane-focus / druidic-focus / holy-symbol / coin

Mostly just `summary` + `effects`. Extras noted where interesting:

- **rarity**: `value_gp` (int), `crafting_time_days` (int), `crafting_cost_gp` (int) — from p207 table.
- **lifestyle**: `cost_per_day_gp` (float).
- **coin**: `value_in_gp` (float — 1/100, 1/10, 1/2, 1, 10).
- **spell-school**: `description` already covered by `summary`.
- **magic-item-category**: `crafting_tool_ref` → `tool` (p207 Magic Item Tools table).
- **area-shape**: `origin_behavior` — text (cube: face / cone: tip / emanation: creature / sphere: center / line: path).
- **plane**: `group` — enum `Material/Inner/Outer-Upper/Outer-Lower/Transitive` (Astral/Ethereal group).
- **tier-of-play**: `min_level` int, `max_level` int.
- **duration-unit**: `is_concentration_compatible` bool.

### 5.2 Tier 1 — Content Entities

#### class (p28-82)

Groups: identity / core-traits / progression / spellcasting / features.

| K | T | R? | V |
|---|---|----|---|
| `primary_ability_ref` | relation→ability | y | |
| `secondary_ability_ref` | relation→ability | n | some classes list two |
| `hit_die` | enum | y | d6/d8/d10/d12 |
| `saving_throw_refs` | relation[]→ability | y | exactly 2 |
| `skill_proficiency_choice_count` | integer | y | min 0 max 4 |
| `skill_proficiency_options` | relation[]→skill | y | class list |
| `weapon_proficiency_categories` | relation[]→weapon-category | n | Simple/Martial/None |
| `weapon_proficiency_specifics` | relation[]→weapon | n | rare: specific weapons only |
| `tool_proficiency_count` | integer | n | 0..3 |
| `tool_proficiency_options` | relation[]→tool | n | |
| `armor_training_refs` | relation[]→armor-category | n | Light/Medium/Heavy/Shield subset |
| `starting_equipment_options` | markdown | y | "(A) ... or (B) ..." — freeform until we model loadouts |
| `starting_gold_dice` | dice | n | e.g. "5d4 × 10" |
| `complexity` | enum | n | Low/Average/High (p19) |
| `casting_ability_ref` | relation→ability | n | null if non-caster |
| `caster_kind` | enum | y | None / Full / Half / Third / Pact / Ritual |
| `spellcasting_focus` | text | n | Arcane Focus / Holy Symbol / Druidic Focus / Musical Instrument |
| `feature_table` | levelTable | y | level → list of feature ids / strings |
| `cantrips_known_by_level` | levelTable | n | per-level integer |
| `prepared_spells_by_level` | levelTable | n | |
| `spell_slots_by_level` | levelTable | n | nested map per slot level |
| `multiclass_requirements` | markdown | n | p24 |

#### subclass

| K | T | R? | V |
|---|---|----|---|
| `parent_class_ref` | relation→class | y | |
| `granted_at_level` | integer | y | 3 for most (p23) |
| `feature_table` | levelTable | y | level → rows |
| `flavor_description` | markdown | n | "Channel Rage into…" |

#### species (p84-86)

| K | T | R? | V |
|---|---|----|---|
| `size_ref` | relation→size | y | Small / Medium |
| `speed_ft` | integer | y | 25 / 30 / 35 |
| `creature_type_ref` | relation→creature-type | y | Humanoid for all SRD species |
| `traits` | markdown | y | species-specific paragraphs |
| `granted_languages` | relation[]→language | n | Common always implicit |
| `granted_senses` | relation[]→sense | n | e.g. Darkvision 60 ft |
| `granted_damage_resistances` | relation[]→damage-type | n | e.g. Dwarf → Poison |
| `granted_skill_proficiencies` | relation[]→skill | n | |
| `age` | text | n | |

#### background (p83)

| K | T | R? | V |
|---|---|----|---|
| `granted_skill_refs` | relation[]→skill | y | exactly 2 |
| `granted_tool_refs` | relation[]→tool | n | 1 tool typically |
| `granted_language_count` | integer | n | usually 0 |
| `ability_score_options` | relation[]→ability | y | background suggests 3 abilities; +2/+1 or +1×3 (p20) |
| `origin_feat_ref` | relation→feat | y | 2024 backgrounds grant one Origin feat |
| `starting_equipment` | markdown | y | |
| `starting_gold_gp` | integer | n | |

#### feat (p87-88)

| K | T | R? | V |
|---|---|----|---|
| `category_ref` | relation→feat-category | y | Origin/General/FightingStyle/EpicBoon |
| `prerequisite` | markdown | n | "Level 4+", "STR 13", "Spellcasting feature" |
| `repeatable` | boolean | y | |
| `repeatable_limit` | integer | n | null=unlimited |
| `ability_score_increase` | markdown | n | "+1 to STR or DEX (max 20)" |
| `benefits` | markdown | y | mechanical effect text |

#### spell (p104-175)

| K | T | R? | V |
|---|---|----|---|
| `level` | integer | y | 0–9 |
| `school_ref` | relation→spell-school | y | |
| `casting_time_amount` | integer | y | 1 by default |
| `casting_time_unit_ref` | relation→casting-time-unit | y | Action / Bonus Action / Reaction / Minute / Hour |
| `reaction_trigger` | text | n | "which you take when …" |
| `is_ritual` | boolean | y | |
| `range_type` | enum | y | Self / Touch / Ranged / Sight / Unlimited |
| `range_ft` | integer | n | for Ranged |
| `area_shape_ref` | relation→area-shape | n | |
| `area_size_ft` | integer | n | sphere radius / cone length / cube side / … |
| `components` | relation[]→casting-component | y | subset of V/S/M |
| `material_description` | text | n | |
| `material_cost_gp` | integer | n | |
| `material_consumed` | boolean | n | |
| `duration_unit_ref` | relation→duration-unit | y | Instantaneous / Rounds / Minutes / … |
| `duration_amount` | integer | n | |
| `requires_concentration` | boolean | y | |
| `description` | markdown | y | body text |
| `at_higher_levels` | markdown | n | |
| `class_refs` | relation[]→class | y | class spell lists |
| `damage_type_refs` | relation[]→damage-type | n | primary types dealt |
| `save_ability_ref` | relation→ability | n | |
| `attack_type` | enum | n | Melee / Ranged / None |

#### weapon (p91)

| K | T | R? | V |
|---|---|----|---|
| `category_ref` | relation→weapon-category | y | Simple / Martial |
| `is_melee` | boolean | y | |
| `damage_dice` | dice | y | 1d6 / 2d6 / 1 (blowgun) |
| `damage_type_ref` | relation→damage-type | y | |
| `property_refs` | relation[]→weapon-property | n | |
| `mastery_ref` | relation→weapon-mastery | y | every weapon has one (p89) |
| `normal_range_ft` | integer | n | for Ammunition/Thrown |
| `long_range_ft` | integer | n | |
| `versatile_damage_dice` | dice | n | when Versatile |
| `ammunition_type_ref` | relation→ammunition | n | arrows / bolts / bullets / needles |
| `cost_gp` | float | y | |
| `weight_lb` | float | y | |

#### armor (p92)

| K | T | R? | V |
|---|---|----|---|
| `category_ref` | relation→armor-category | y | |
| `base_ac` | integer | y | 11 / 14 / 16 / 18 / +2 (shield) |
| `adds_dex` | boolean | y | Light: full, Medium: capped, Heavy: none |
| `dex_cap` | integer | n | 2 for Medium |
| `strength_requirement` | integer | n | 13 / 15 |
| `stealth_disadvantage` | boolean | y | |
| `don_time_minutes` | integer | y | 1 / 5 / 10 |
| `doff_time_minutes` | integer | y | 1 / 1 / 5 |
| `cost_gp` | float | y | |
| `weight_lb` | float | y | |

#### tool (p93-94)

| K | T | R? | V |
|---|---|----|---|
| `category_ref` | relation→tool-category | y | Artisan / Other / GamingSet / MusicalInstrument |
| `variant_of_ref` | relation→tool | n | Gaming Set / Musical Instrument variants link back to their family row |
| `ability_ref` | relation→ability | y | |
| `utilize_check_dc` | integer | n | |
| `utilize_description` | textarea | n | |
| `craftable_items` | relation[]→adventuring-gear | n | alt: textarea when undecided |
| `cost_gp` | float | y | |
| `weight_lb` | float | y | |

#### adventuring-gear (p94-99)

Includes packs (could be merged) — keep `pack` separate for its `contents` field.

| K | T | R? | V |
|---|---|----|---|
| `cost_cp` | integer | y | |
| `weight_lb` | float | y | |
| `utilize_description` | markdown | n | |
| `consumable` | boolean | y | |
| `is_focus` | boolean | n | if this item can serve as spellcasting focus |
| `focus_kind_ref` | relation→arcane-focus / druidic-focus / holy-symbol | n | |

#### ammunition

Small table — 5 rows. Fields: `storage_container` text, `cost_gp` float, `weight_lb` float, `bundle_count` int (20 / 50).

#### pack (p95)

`contents` — relation[]→adventuring-gear with quantity subField (backpack × 1, oil × 7, …). Until the engine supports a quantity-on-relation item, model as markdown and plain text list.

#### mount (p100)

`carrying_capacity_lb` int, `speed_ft` int, `cost_gp` int, `is_trained` bool.

#### vehicle (p100)

`vehicle_kind` enum (Airborne / Waterborne / Land), `speed_mph` float, `crew` int, `passengers` int, `cargo_tons` float, `ac` int, `hp` int, `damage_threshold` int, `cost_gp` int.

#### trinket

Just `name` + `description` + `roll_d100` int (1-100) for table recovery.

#### magic-item (p209-253)

| K | T | R? | V |
|---|---|----|---|
| `magic_category_ref` | relation→magic-item-category | y | |
| `rarity_ref` | relation→rarity | y | |
| `requires_attunement` | boolean | y | |
| `attunement_prereq` | markdown | n | class/race/spellcasting req |
| `is_cursed` | boolean | y | |
| `base_item_ref` | relation→weapon / armor / adventuring-gear | n | for +1 Longsword etc. |
| `charges_max` | integer | n | |
| `charge_regain` | text | n | "1d6+4 at dawn" |
| `activation` | enum | y | None / Magic action / Bonus Action / Reaction / Utilize / Command Word / Consumable |
| `command_word` | text | n | |
| `effects` | markdown | y | full body |
| `cost_gp` | integer | n | rarity-derived default, overridable |
| `weight_lb` | float | n | |
| `is_sentient` | boolean | y | see §5.2 sentient-item panel if true |

If `is_sentient=true`, the row's fields map also holds `sentient_int`, `sentient_wis`, `sentient_cha`, `sentient_alignment_ref` (→alignment), `sentient_communication` (enum), `sentient_senses` (enum), `sentient_special_purpose` (enum).

#### monster (p254-343) + animal

Monster / Animal share the same schema; `animal` slug keeps a flag so the beast list on p344 filters cleanly.

Groups: identity, combat, ability-scores, senses-languages, defenses, traits-actions, legendary, spellcasting.

| K | T | R? | V |
|---|---|----|---|
| `size_ref` | relation→size | y | |
| `creature_type_ref` | relation→creature-type | y | |
| `tags` | text[] | n | "(goblinoid)" etc. |
| `alignment_ref` | relation→alignment | n | |
| `ac` | integer | y | |
| `ac_note` | text | n | "natural armor", "studded leather" |
| `initiative_modifier` | integer | y | |
| `initiative_score` | integer | y | 10+modifier usually |
| `hp_average` | integer | y | |
| `hp_dice` | dice | y | "20d10+40" |
| `speed_walk_ft` | integer | y | |
| `speed_burrow_ft` | integer | n | |
| `speed_climb_ft` | integer | n | |
| `speed_fly_ft` | integer | n | |
| `speed_swim_ft` | integer | n | |
| `can_hover` | boolean | n | |
| `stat_block` | statBlock | y | 6 ability scores |
| `save_bonuses` | proficiencyTable | n | per-ability override (for non-standard saves) |
| `skill_bonuses` | proficiencyTable | n | |
| `resistance_refs` | relation[]→damage-type | n | |
| `vulnerability_refs` | relation[]→damage-type | n | |
| `damage_immunity_refs` | relation[]→damage-type | n | |
| `condition_immunity_refs` | relation[]→condition | n | |
| `sense_grants` | textarea | n | "Darkvision 60 ft." — structured alt: relation[]→sense with range subField |
| `passive_perception` | integer | y | |
| `language_refs` | relation[]→language | n | |
| `telepathy_ft` | integer | n | |
| `cr` | enum | y | 0, 1/8, 1/4, 1/2, 1, 2 … 30 |
| `xp` | integer | y | derived from CR but overridable |
| `proficiency_bonus` | integer | y | derived from CR |
| `traits` | markdown | n | combined passive/"at all times" |
| `actions` | markdown | y | Attack notation etc. |
| `bonus_actions` | markdown | n | |
| `reactions` | markdown | n | |
| `legendary_action_uses` | integer | n | |
| `legendary_actions` | markdown | n | |
| `lair_actions` | markdown | n | |
| `spellcasting_block` | markdown | n | |
| `gear_refs` | relation[]→adventuring-gear / weapon / armor | n | |

Actions authored as markdown for v1. A v2 pass may reify each attack into a structured sub-entity (see §9).

### 5.3 Tier 2 — DM Categories

#### npc

Merges monster stat block with campaign framing.

| K | T | R? | V |
|---|---|----|---|
| all monster fields (optional) | … | n | inline stat block |
| `race_ref` | relation→species | n | |
| `class_refs` | relation[]→class | n | multiclass-friendly |
| `level` | integer | n | 1–20 |
| `attitude_ref` | relation→attitude | y | default Indifferent |
| `background_ref` | relation→background | n | |
| `location_ref` | relation→location | n | |
| `faction` | text | n | |
| `goals` | markdown | n | |
| `secrets` | markdown | n | (DM-only visibility) |

#### player-character

Extends NPC with PC-only fields.

| K | T | R? | V |
|---|---|----|---|
| `species_ref` | relation→species | y | |
| `class_refs` | relation[]→class | y | |
| `class_levels` | levelTable | y | class slug → level (sums to total) |
| `subclass_refs` | relation[]→subclass | n | |
| `background_ref` | relation→background | y | |
| `alignment_ref` | relation→alignment | n | |
| `xp` | integer | y | |
| `proficiency_bonus` | integer | y | derived from total level |
| `feats` | relation[]→feat | n | |
| `languages` | relation[]→language | y | |
| `tool_proficiencies` | relation[]→tool | n | |
| `weapon_proficiencies` | relation[]→weapon-category / weapon | n | |
| `armor_trainings` | relation[]→armor-category | n | |
| `skill_proficiencies` | relation[]→skill | n | |
| `expertise_skills` | relation[]→skill | n | |
| `saving_throw_proficiencies` | relation[]→ability | y | |
| `inventory` | relation[]→weapon/armor/adventuring-gear/magic-item | n | hasEquip=true |
| `money` | map<coin,int> | y | |
| `spells_known` | relation[]→spell | n | |
| `prepared_spells` | relation[]→spell | n | |
| `spell_slots` | slot | y | one row per level 1–9 |
| `pact_magic_slots` | slot | n | warlock |
| `class_resources` | proficiencyTable | n | Rages, Ki, Sorcery Points, Bardic Inspiration, Channel Divinity |
| `hit_dice_remaining` | proficiencyTable | y | per die type |
| `temp_hp` | integer | y | default 0 |
| `death_saves_successes` | integer | y | 0–3 |
| `death_saves_failures` | integer | y | 0–3 |
| `heroic_inspiration` | boolean | y | |
| `current_conditions` | relation[]→applied-condition | n | runtime |
| `appearance` | markdown | n | |
| `backstory` | markdown | n | |
| `trinket_ref` | relation→trinket | n | |

#### applied-condition

Instance of a Condition on a combatant — distinct from the Condition lookup because it carries duration + caster.

| K | T | R? | V |
|---|---|----|---|
| `condition_ref` | relation→condition | y | |
| `source_entity_ref` | relation→any | n | who applied it |
| `duration_rounds` | integer | n | null=indefinite |
| `save_dc` | integer | n | |
| `save_ability_ref` | relation→ability | n | |
| `save_frequency` | enum | n | start-of-turn / end-of-turn / when-damaged / none |
| `notes` | textarea | n | |

#### location / scene / quest / encounter

Existing (see current 19-category schema) — keep fields roughly the same, swap plain-text `danger_level` / `environment` / `status` enums for relation refs where a lookup fits. Encounter gains `monsters_refs` relation[]→monster + `npcs_refs` relation[]→npc.

#### trap / poison / curse / environmental-effect / hireling / service

Gameplay Toolbox entries — small catalogs:

- **trap**: `trigger` text, `save_dc` int, `save_ability_ref` relation→ability, `damage_dice` dice, `damage_type_ref` relation→damage-type, `detection_dc` int, `disable_dc` int.
- **poison**: `poison_kind` enum (Contact / Ingested / Inhaled / Injury), `save_dc` int, `effect` markdown, `cost_gp` int.
- **curse**: `trigger` markdown, `effect` markdown, `removed_by` markdown.
- **environmental-effect**: from Gameplay Toolbox p195 (extreme cold/heat/wind/precipitation/altitude) — `effect` markdown, `save_dc` int.
- **hireling**: `skill_ref` relation→skill, `daily_cost_cp` int, `skilled` boolean.
- **service**: `kind` enum (Spellcasting / Transport / Shelter), `cost_cp` int, `availability` text.

---

## 6. Shared Seed Data (Row Content)

Tier-0 categories need their canonical rows seeded. Put them in
`flutter_app/assets/builtin_dnd5e/<slug>.json` as `List<Map>` blobs. Bootstrap
reads them at first launch and inserts into the Entity store with
`isBuiltin=true`. This keeps **shape (schema) vs. content (rows)** separate.

Critical row counts (already covered in §3 table):

| Slug | Rows | Status |
|------|------|--------|
| damage-type | 13 | canonical |
| condition | 15 | canonical |
| skill | 18 | canonical |
| size | 6 | canonical |
| creature-type | 14 | canonical |
| alignment | 10 | canonical |
| language | 19 | canonical |
| weapon-property | 11 | canonical |
| weapon-mastery | 8 | canonical |
| spell-school | 8 | canonical |
| rarity | 6 | canonical |
| magic-item-category | 9 | canonical |
| action | 12 | canonical |
| area-shape | 6 | canonical |

Tier-1 content rows (classes, spells, monsters, …) are **not** shipped in v1. The SRD-CC attribution is costly to author line-by-line and should go into a separate content pack (`srd_core.dnd5e-pkg.json`) whose bootstrap path already exists for typed content. This design doc defines **shape only**; content is a follow-up.

---

## 7. Rules (RuleV2) Shipped With the Template

Minimum set. Rules are cheap to add later; keep v1 list small and high-signal.

| Scope | Rule | Why |
|-------|------|-----|
| `monster` | Compute `initiative_score = 10 + DEX modifier` unless manually set | Lets the encounter tracker roll initiative with zero setup |
| `monster` | Derive `xp` from `cr` via static lookup (p256 table) | Avoid authoring drift |
| `monster` | Derive `proficiency_bonus` from `cr` via p256 table | same |
| `player-character` | Compute `proficiency_bonus` from total level | p23 |
| `player-character` | `passive_perception = 10 + WIS mod + perception_prof_bonus` | p22 |
| `armor` | `gate-equip` if `strength_requirement > wearer.STR` | p92 |
| `magic-item` | `gate-equip` if `requires_attunement` and wearer lacks prereq | p206 |
| `player-character` | Sum equipped-item AC bonuses into `ac` | standard |
| `spell` | Fade list items in a caster's `spells_known` where `class_refs ∌ wearer.class_refs` | usability |

Everything else (damage resolution, saves, concentration, …) is runtime/engine territory, not template rules.

---

## 8. Encounter / Combat Integration

Shared combat columns stay the same names current code already reads:

- `combat_stats.hp / ac / speed / initiative / level / cr / xp`
- `stat_block.{STR,DEX,CON,INT,WIS,CHA}`
- `conditions` — list of `applied-condition` entities (NOT raw strings)

Migration from the old schema: current `conditions: List<String>` becomes `conditions: List<entityId>` pointing at `applied-condition` rows. A one-shot migration script maps string → lookup row on first open.

`EncounterConfig.conditions` stops being a hardcoded list and instead reads every `condition` catalog row at runtime.

---

## 9. Open Questions

Decisions that block implementation — user input requested before we code:

1. **Currency** — single `_cp` integer (simple, loss-free) vs. structured `{amount, coin_ref}` (UI-friendly, multi-denomination display). Recommendation: `_cp` internally, UI decomposes for display.
2. **Quantity on relation items** — packs / inventory need "3 × Oil". Schema engine doesn't have this today. Options: add `quantity` subField on relation, or model pack/inventory as a nested entity list. Recommendation: small engine extension adding optional `quantityField` to FieldSchema, default null.
3. **Monster actions structured vs. markdown** — v1 authors as markdown (fast, SRD-verbatim); v2 reifies each attack into a `monster-action` sub-entity (enables auto-damage rolls from the encounter tracker). Recommendation: markdown for v1, schedule structured pass after template ships.
4. **Content pack vs. in-schema rows** — Tier-0 rows ship inline with the schema (small, always needed). Tier-1 rows go into `srd_core.dnd5e-pkg.json` (large, optional, per-install SRD license attribution lives there). Confirm this split.
5. **Slug collision** — built-in slugs collide with user custom categories. Options: reserved prefix `srd:` on all built-ins, or `builtin: true` flag (already exists) + UI that blocks duplicate slugs. Recommendation: keep flag, UI-enforce.
6. **Legacy 19-category migration** — when the new template replaces the old, existing campaigns reference old category ids. Provide a per-slug migration map (`equipment` → `magic-item` / `weapon` / `armor` / `adventuring-gear` by heuristic). Recommendation: keep the old schema reachable by `originalHash: builtin-dnd5e-default-v1`; new one is `-v2`; old campaigns keep working.
7. **Subclass per class — only 1 in SRD** — the SRD CC 5.2.1 ships exactly one subclass per class (Berserker, Lore, Life, Land, Champion, Open Hand, Devotion, Hunter, Thief, Draconic, Fiend, Evoker). Users will want homebrew subclasses — confirm that `subclass` category accepts arbitrary rows, not just the 12 SRD ones.
8. **Relation target union** — `player-character.inventory` needs to accept weapon / armor / gear / magic-item. Current `allowedTypes: List<String>` already supports this. Confirm UI renders a type-picker.
9. **Planes grouping** — the SRD lists 6 Inner + 16 Outer + 3 Transitive = 25 total planes (p209 amulet table). Row count depends on whether we group Outer Planes by alignment pair. Recommendation: 25 rows with `group` field; UI groups at display time.

---

## 10. Implementation Plan

Phased rollout so the template ships incrementally and each phase is testable.

**Phase 1 — Tier 0 lookups** (1 PR).
- Add 35 lookup category defs + canonical row assets.
- Migration: create new categories beside old ones; no destructive change.
- Tests: schema builder + asset round-trip for every lookup.

**Phase 2 — Tier 1 content shapes** (1-2 PRs).
- Add content category schemas (class / subclass / species / background / feat / spell / weapon / armor / tool / gear / ammunition / pack / mount / vehicle / magic-item / monster / trinket).
- No row content yet (shape only).
- Tests: build/validate a blank campaign.

**Phase 3 — Tier 2 DM categories** (1 PR).
- Add NPC / PC / location / scene / quest / encounter / applied-condition / trap / poison / curse / environmental-effect / hireling / service.
- Rewire `EncounterConfig` to read conditions from the catalog.

**Phase 4 — Rules** (1 PR).
- Ship the 9 rules from §7.
- Tests: ensure each rule fires on the expected entity shape.

**Phase 5 — Legacy migration** (1 PR).
- Map old 19-category data → new schema (`equipment` disambiguation heuristic).
- Bump `originalHash` to `builtin-dnd5e-default-v2`.
- Tests: load a v1 export, verify every entity survives.

**Phase 6 — SRD content pack** (separate track).
- Author `srd_core.dnd5e-pkg.json` with the ~1200 Tier-1 rows.
- Lives outside this template — template is the shape, pack is the rows. Phase tracked in Doc 15 (per prior memory).

Estimated total: **5 PRs for shape** + separate long-running content effort.

---

## 11. File Layout

```
flutter_app/
  lib/
    domain/entities/schema/
      default_dnd5e_schema.dart          ← replaced / grown
      dnd5e_constants.dart               ← grown (ability ids, skill ids, etc.)
      builtin/
        lookups.dart                     ← 35 Tier-0 category defs
        content.dart                     ← 18 Tier-1 category defs
        dm.dart                          ← 13 Tier-2 category defs
        rules.dart                       ← 9 RuleV2 defs
        groups.dart                      ← shared FieldGroup ids
    data/bootstrap/
      builtin_dnd5e_bootstrap.dart       ← first-launch row seed
  assets/
    builtin_dnd5e/
      damage-type.json
      condition.json
      skill.json
      … (one per Tier-0 slug, 35 files)
docs/
  BUILTIN_DND5E_TEMPLATE_DESIGN.md       ← this file
  TEMPLATES_FIELDS_GROUPS_RULES.md       ← unchanged (engine reference)
```

---

## 12. Sign-off Checklist

Before coding starts, confirm:

- [ ] §2 Source mapping is complete — every SRD section lands somewhere.
- [ ] §3 Category list is approved — no missing/redundant slugs.
- [ ] §4 Field conventions (units, naming) are accepted.
- [ ] §5 Per-category specs are reviewed; no obviously-missing fields.
- [ ] §6 Lookup row seed plan (inline vs. pack) is decided.
- [ ] §9 Open questions all answered.
- [ ] §10 Phased plan is right-sized.

Once checked, Phase 1 can start.
