# Missing Mechanical Effects — Field-Mutation Audit (2026-05-14)

Scoped to mechanics that **mutate a stored field on the PC/NPC/monster sheet** — or
add/remove an entry from one of its lists. Runtime roll modifiers (advantage,
disadvantage, extra damage, reroll, attack/damage bonus, save resolution, passive-score
math, aura predicates, evasion) are **out of scope** for this pass — they belong to the
future combat tracker and don't change sheet state.

Companion docs: [srd_missing_effects_audit.md](srd_missing_effects_audit.md) (subclass +
weaponMastery pending choices, shipped) and
[../../docs/srd_5e_mechanic_audit.md](../../docs/srd_5e_mechanic_audit.md) (schema/lookup).

---

## 0. In-scope field surfaces

Per `EffectiveCharacter` + PC schema, every field a grant can write to:

- `effectiveAbilities` (STR/DEX/CON/INT/WIS/CHA scores)
- `acBonus`, `unarmoredFormulas`
- `speedBonus`, base `speed_ft` (species), plus future swim/climb/fly speeds
- `size` (species default + future overrides)
- `hpBonusFlat`, `hpBonusPerLevel`, `hp_max_bonus_total`
- `initiativeBonus`
- `extraAttackCount`, `critRangeMin`
- `proficiencies.skillIds`, `.toolIds`, `.savingThrowAbilityIds`, `.languageIds`,
  `.weaponCategoryIds`, `.armorCategoryIds`
- `expertiseSkillIds`
- `senseEntityIds` (incl. range, currently single-id only)
- `damageResistanceIds`, `damageImmunityIds`, `damageVulnerabilityIds`,
  `conditionImmunityIds`
- `grantedSpellIds`, `grantedCantripIds`, `alwaysPreparedSpellIds`
- `grantedActionIds`, `grantedBonusActionIds`, `grantedReactionIds`
- `autoGrantedTraitIds`, `autoGrantedFeatIds`
- `resourcePools` (max value per pool — count_increase or pool_grant)
- `weapon_masteries` (PC field; list of weapon ids), `weapon_mastery_count` cap
- `pending_choices` (added/removed entries)
- `class_levels`, `subclass_id`, `feat_ids`, `fighting_style_id`
- `temp_hp` (PC live field)

In-scope effect kinds (resolver already wires every one that's marked **Applied**):

| Status | Field-impacting kinds |
|--------|-----------------------|
| Applied | `ability_score_bonus`, `ac_bonus`, `speed_bonus`, `hp_bonus_per_level`, `hp_bonus_flat`, `hp_max_bonus_total`, `initiative_bonus`, `proficiency_grant`, `language_grant`, `spell_grant`, `cantrip_grant`, `spell_always_prepared`, `damage_resistance`, `damage_immunity`, `damage_vulnerability`, `condition_immunity_grant`, `sense_grant`, `truesight_grant`, `blindsight_grant`, `expertise_grant`, `unarmored_ac_formula`, `extra_attack_count`/`extra_attack_bump`, `crit_range_extend`, `resource_pool_grant` |
| Partial | `weapon_mastery_count_bonus` (queues pending choice; final list appends to `weapon_masteries` field), `weapon_mastery_grant` (no-op kind but should append to same list), `damage_resistance` w/ `has_state` predicate (predicate eval drops at resolve time — Rage etc.) |
| No-op but field-bound | `temp_hp_grant` (writes to PC's live `temp_hp`), `cantrip_count_bonus` (caps `cantrips_known`), `fly_speed`, `swim_speed_equals_speed`, `climb_speed_equals_speed`, `slot_recovery_short_rest` (mutates current spell-slot field) |
| Out of scope (runtime roll mod) | `advantage_on`, `disadvantage_on`, `extra_damage_on_attack`, `reroll_d20`, `reroll_damage`, `attack_bonus_typed`, `damage_bonus_typed`, `min_die_value`, `passive_score_bonus`, `reliable_talent`, `half_proficiency_to_unproficient_checks`, `damage_reduction_flat`, `ignore_cover`, `ignore_long_range_disadvantage`, `concentration_advantage`, all `reaction_*`, `state_grant`, `damage_type_override`, `magical_unarmed_strikes`, `spellcasting_ability_to_damage`, `walk_on_liquid`, `oa_*` |

---

## 1. Traits

Only field-mutating gaps. Trait list filtered against the in-scope effect set.

| Trait | Field impact | Currently | Status | Fix |
|-------|--------------|-----------|--------|-----|
| Innate Spellcasting (×6 variants) | `grantedSpellIds` / `grantedCantripIds` + optional `resourcePools` for 1/day | empty effects on trait; spell lists only in description | **MISSING** | declare `granted_spell_refs` / `granted_cantrip_refs` / `granted_spells_at_level` rows |
| Spider Climb (×3) | adds climb speed entry | empty | **STUB** | wire `climb_speed_equals_speed` → new `extraSpeeds` field on EffectiveCharacter |
| Legendary Resistance (×2/×3) | `resourcePools` max +N | empty | **MISSING** | declare `resource_pool_grant` with daily recharge |
| Multiple Heads / Reactive Heads | `grantedReactionIds` extra entry | empty | **MISSING** | declare extra `granted_reaction_refs` |

Dropped (no PC field surface today; revisit if schema gains the field):
- Earth Glide / Earth Walk — no movement-mode field.
- Standing / Running Leap — no jump-distance field.
- Aboleth Telepathy — speculative language entry.
- Amphibious / Hold Breath — no breathing flag.

Traits already wired correctly (don't touch): Stonecunning, Dwarven Toughness (`hp_bonus_per_level`), Mask of the Wild (no field impact — moves to out-of-scope).

Out-of-scope traits (roll-time only, deferred): Sneak Attack, Brute, Pack Tactics, all
Keen Senses, Sunlight Sensitivity, Reckless, Camouflage variants, Sure-Footed, Magic
Resistance, Lucky (halfling), Brave, Fey Ancestry advantage portion, Jack of All Trades,
Reliable Talent, Evasion, Regeneration, Absorption (heal trigger), Death Burst, Heated
Body, Pounce, Charge, Siege Monster, Blood Frenzy, Undead Fortitude.

---

## 2. Feats

### 2.1 Origin (`feats.dart`)

| Feat | Field impact | Status | Fix |
|------|--------------|--------|-----|
| Tough | `hpBonusPerLevel` +2 | ✓ SHIPPED 2026-05-14 | `hp_bonus_per_level: 2` |
| Magic Initiate | cantrip + spell lists | **OK** | choice_group resolved |
| Skilled | skill list | **OK** | |
| Crafter | tool list | **OK** | (discount/speed out-of-scope) |
| Musician | tool list | **OK** | (inspiration out-of-scope) |
| Tavern Brawler | ASI | **OK** | (d4 unarmed die has no PC field — OUT until unarmed-strike die field added) |
| Lucky | `resourcePools` (PB Luck Points/day) | ✓ SHIPPED 2026-05-14 | `resource_pool_grant` w/ `pool:luck_points` + `count_formula: 'pb'`; resolver `_evalCountFormula` resolves PB |
| Healer | (no field impact — Hit-Die reroll out-of-scope) | OUT | — |
| Alert | (no field — initiative formula uses `initiativeBonus`, but Alert's +PB is roll-time) | OUT | — |
| Savage Attacker | (reroll dmg, no field) | OUT | — |

### 2.2 General

ASI typed fields wire on every general feat. Non-ASI field impact only:

| Feat | Field impact | Status |
|------|--------------|--------|
| Resilient | adds save proficiency | ✓ SHIPPED 2026-05-14 — `grants_save_prof_from_asi: true` triggers `featAsi` pending; resolution writes `saving_throws.rows[i].proficient = true` |
| Lightly Armored | adds Light armor cat to `armorCategoryIds` | ✓ SHIPPED 2026-05-14 — `proficiency_grant` w/ target_kind `armor_category` (Light) |
| Moderately Armored | adds Medium armor + Shield | ✓ SHIPPED 2026-05-14 — `proficiency_grant` Medium armor_category + Shield |
| Heavy Armor Master | adds Heavy armor proficiency | OUT — SRD prereq already requires heavy armor proficiency; remaining dmg reduction is roll-time |
| Skill Expert | adds 1 skill + 1 expertise | ✓ SHIPPED 2026-05-14 — both sides via `bonus_skill_pick_count: 1` + `bonus_expertise_pick_count: 1`; new `skillProficiency` + `expertise` pending choice kinds + dialog bodies |
| Fey-Touched | +1 INT/WIS/CHA + Misty Step + 1 L1 divination/enchantment always prepared | ◐ Misty Step `spell_always_prepared` shipped; second L1 div/ench picker still open |
| Shadow-Touched | +1 INT/WIS/CHA + Invisibility + 1 L1 illusion/necromancy always prepared | ◐ Invisibility `spell_always_prepared` shipped; second L1 illusion/necromancy picker still open |
| Telekinetic | +1 INT/WIS/CHA + Mage Hand cantrip | ✓ SHIPPED — `cantrip_grant` Mage Hand wired |
| Telepathic | +1 INT/WIS/CHA + Detect Thoughts always prepared | ✓ SHIPPED — `spell_always_prepared` Detect Thoughts wired |
| Ritual Caster | adds rituals to spellbook (field) | **MISSING** (`spell_grant` rows for chosen list) |
| Inspiring Leader | grants temp HP to N allies after rest | ✓ SHIPPED 2026-05-14 (`temp_hp_grant` declared, surfaced in Temp HP Grants chips; auto-apply UX pending) |
| Elemental Adept | adds a damage-type tag to PC (no current field) | OUT (no PC-side field stores this) |
| Martial Adept | adds maneuvers (no current field) | OUT (no maneuver-list field yet) |

Out-of-scope (roll-time): Charger, Crossbow Expert, Defensive Duelist, Dual Wielder,
Durable, Grappler, Great Weapon Master, Keen Mind, Mage Slayer, Mobile, Mounted
Combatant, Observant, Polearm Master, Sentinel, Sharpshooter, Shield Master, Spell
Sniper, War Caster, Weapon Master, Athlete.

### 2.3 Fighting Styles

| Style | Field impact | Status | Fix |
|-------|--------------|--------|-----|
| Defense | `acBonus +1` while armored | ✓ SHIPPED 2026-05-14 | `ac_bonus 1` w/ `equipped_armor_kind: not_none` predicate |
| Blind Fighting | adds blindsight 10ft to senses | ✓ SHIPPED 2026-05-14 | `blindsight_grant` → `sense:Blindsight` w/ `range_ft: 10`; resolver writes max-wins to `senseRanges` |

Out-of-scope (roll-time): Archery, Dueling, Great Weapon Fighting, Two-Weapon Fighting,
Interception, Protection, Thrown Weapon Fighting, Unarmed Fighting.

### 2.4 Epic Boons

| Boon | Field impact | Status |
|------|--------------|--------|
| Boon of Truesight | senses list + truesight 60ft | ✓ SHIPPED 2026-05-14 — `truesight_grant` references Truesight 60ft sense entity |
| Boon of Night Spirit | conditional resistance addition | ✓ SHIPPED 2026-05-14 — 11 damage_resistance rows w/ `has_state state:in_dim_or_darkness`; routed to `conditionalGrants`, surfaced in Conditional Grants block |

Dropped (no field surface): Dimensional Travel, Spell Recall (no slot-recall pool yet), Fate, Combat Prowess, Irresistible Offense.

### 2.5 Class feats (`feats_class.dart`)

Field-impacting gaps only:

| Feat | Field impact | Status |
|------|--------------|--------|
| Rage (Barbarian) | adds damage_resistance entries while raging | ✓ SHIPPED 2026-05-14 — state-conditional split routes BPS resistances to `conditionalGrants` w/ `state:raging` |
| Mindless Rage (Berserker L6) | adds `Charmed`/`Frightened` condition immunity while raging | ✓ SHIPPED 2026-05-14 — 2× `condition_immunity_grant` w/ `state:raging` predicate |
| Cunning Action (Rogue) | adds 3 bonus-action refs to `grantedBonusActionIds` | ✓ SHIPPED 2026-05-14 — `granted_bonus_action_grant` declared → Cunning Action creature-action |
| Slippery Mind (Rogue L15) | adds Wisdom + Charisma save prof | ✓ VERIFIED 2026-05-14 — both `proficiency_grant: saving_throw` rows shipped (WIS + CHA) |
| Second-Story Work (Thief) | adds climb speed = walk | ✓ SHIPPED 2026-05-14 — `climb_speed_equals_speed` resolves to walk speed at post-pass, chipped under Extra Speeds |
| Acrobatic Movement (Monk L9) | walk_on_liquid + vertical surface movement | ✓ SHIPPED — `walk_on_liquid` w/ armor + shield predicates (RAW: no climb-speed grant in 2024 SRD) |
| Roving (Ranger L3) | adds +5 speed + climb + swim | ✓ SHIPPED 2026-05-14 — speed_bonus +5, plus climb_speed_equals_speed + swim_speed_equals_speed routed through Extra Speeds |
| Draconic Resilience (Sorcerer Sub) | `hp_max_bonus_total` + unarmored AC formula | ◐ HP works; AC formula now surfaced via new `Unarmored AC` row on `ResolvedGrantsCard` (sheet's AC field still manual — auto-set blocked on equipment-context evaluation) |
| Dragon Wings (Sorcerer Sub L14) | fly speed = walk | ✓ SHIPPED 2026-05-14 — `fly_speed` declared, post-pass resolves to walk speed, chipped under Extra Speeds |
| Aura of Courage (Paladin L10) | adds `Frightened` immunity while in aura | OUT (aura predicate runtime) |
| Dark One's Blessing (Fiend Warlock) | writes to PC `temp_hp` | ✓ SHIPPED 2026-05-14 — `temp_hp_grant` declared (`CHA_mod + warlock_level (min 1)`, trigger `on_reduce_creature_to_0_hp`); surfaced in Temp HP Grants chips |
| Divine Smite (Paladin L2) | adds Smite spell to `alwaysPreparedSpellIds` | ✓ VERIFIED 2026-05-14 — `spell_always_prepared` Divine Smite present (feats_class.dart:906) |
| Hunter's Mark (Ranger Favored Enemy) | always-prepared spell + free casts | ✓ VERIFIED 2026-05-14 — `spell_always_prepared` Hunter's Mark + `resource_pool_grant` pool:hunters_mark_no_slot_uses (wis_mod_min_1, long_rest) |
| Signature Spells (Wizard L20) | always-prepared L3 spells + 1/short rest pool | **PARTIAL** |
| Mystic Arcanum (Warlock) | adds L6–L9 spells + 1/long rest cast | **OK** (caster progression) |

Class feats whose only mechanic is roll-time (out of scope):
Reckless Attack, Danger Sense, Brutal Strike, Sneak Attack, Indomitable reroll, Stunning
Strike, Evasion, Reliable Talent, Stroke of Luck, Innate Sorcery advantage, Cutting
Words, Disciple of Life rider, Sculpt Spells, Potent Cantrip, Empowered Evocation,
Overchannel, Studied Attacks, Sacred Weapon attack bonus, Tactical Mind, Survivor
passive regen (no HP-regen field stored).

---

## 3. Species & subspecies

| Source | Field impact | Status |
|--------|--------------|--------|
| Drow | senses list — Superior Darkvision 120ft (range overrides default 60ft) | ✓ SHIPPED 2026-05-14 — Drow subspecies `sense_grant` carries `range_ft: 120`; resolver writes max-wins to `senseRanges`; sheet senses chip shows range overlay |
| High Elf | cantrip list — "a Wizard cantrip" of player choice | **MISSING** — declare `choice_group` with cantrip-from-list payload |
| Goliath | `size` field at L5 (Large Form) | **MISSING** — no `size_override` effect kind; PC `size` field exists but never gets written |
| Wood Elf | speed +5 + base = 35 | **OK** |
| Stout Halfling | poison resistance | **OK** |
| Mountain Dwarf | +2 flat HP | **OK** (via `hp_bonus_flat`) |
| Hill Dwarf | Insight skill prof + Dwarven Toughness (+1 HP/level) | ✓ SHIPPED 2026-05-14 — `granted_modifiers` now carries `hp_bonus_per_level: 1`; Insight prof already wired |
| Lightfoot Halfling | Stealth skill prof | **OK** |
| Half-Orc legacy | Intimidation prof | **OK** |
| Standard Human legacy | +1 to all six abilities | **OK** |
| Tiefling (Abyssal/Chthonic/Infernal) | damage resistance + level-gated innate spells | **OK** |
| Dragonborn | damage resistance per ancestry + breath action + flight bonus action | **OK** |
| Orc | darkvision + Adrenaline Rush bonus + Relentless reaction | **OK** |
| Forest Gnome | Minor Illusion cantrip | **OK** (Speak with Small Beasts has no field surface — OUT) |
| Rock Gnome | Mending + Prestidigitation cantrips | **OK** (Artificer's Lore is roll-time — OUT) |

Out-of-scope (roll-time): Gnomish Cunning advantage, Halfling Lucky/Brave, Fey Ancestry
advantage, Stonecunning expertise/movement (the History expertise *is* a field — see if
already declared in trait).

---

## 4. Classes — field-impacting gaps

Only items missing/partial; OK rows omitted.

### Barbarian
- **Rage (L1)** — `damage_resistance` rows w/ state predicate: ✓ SHIPPED 2026-05-14 — state-predicate split routes BPS resistances to `EffectiveCharacter.conditionalGrants` w/ `state:raging`; sheet's `_conditionalGrantsBlock` renders them.
- **Primal Champion (L20)** — STR/CON cap raised to 24: ✓ SHIPPED 2026-05-14 — STR/CON +4 max:25 declared.

### Bard
- **Bardic Inspiration (L1)** — pool max ✓ VERIFIED — `resource_pool_grant pool:bardic_inspiration` w/ `count_formula: cha_mod_min_1`. Pool current value decrement on use Tier 4 (no spend UI). Die-size scaling (d6→d8→d10→d12) is roll-time, OUT.
- **Magical Secrets (L10)** — adds spells from any list to `grantedSpellIds`.
  **MISSING** (`choice_group` not authored).

### Cleric
- **Divine Order (L1)** — Protector adds Martial weapon cat + Heavy armor; Thaumaturge
  adds a cantrip + spell-save bonus to one cantrip cast/turn. ✓ SHIPPED 2026-05-14 —
  new `PendingChoiceKind.divineOrder` (plumbed through `LevelUpPlan.isDivineOrderLevel`,
  pendingChoicesFromPlan emission, resolver dialog body, seed-on-creation in wizard's
  `buildSeedFields`). Two pickable feats authored under new `feat-category: Divine Order`:
  Protector emits `proficiency_grant` rows for Martial weapons + Heavy armor; Thaumaturge
  declares `cantrip_count_bonus: 1` (free-pick cantrip surface still pending — kind is
  recognized as no-op by resolver today).
- **Channel Divinity (L2)** — pool max ✓ SHIPPED 2026-05-14 — switched from hardcoded 2 to `scales_with` Cleric-level table `[(2,2),(6,3),(18,4)]`; current-value spend Tier 4.
- **Divine Intervention (L10)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:divine_intervention` (1/long_rest). Spend UX Tier 4.

### Druid
- **Wild Companion (L2)** — slot→Find Familiar conversion mutates current slot map.
  **STUB** (no current-slot-decrement consumer; field exists).

### Fighter
- **Second Wind (L1)** — pool max ✓ VERIFIED — `scales_with` Fighter `[(1,2),(4,3),(10,4)]`. Spend Tier 4.
- **Action Surge (L2)** — pool max ✓ VERIFIED — `scales_with` Fighter `[(2,1),(17,2)]`. Spend Tier 4.
- **Indomitable (L9)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:indomitable_uses` w/ `scales_with` Fighter-level table `[(9,1),(13,2),(17,3)]`, long_rest recharge. Spend UI deferred to Tier 4.

### Monk
- **Unarmored Defense (L1)** — `unarmored_ac_formula` stored; surfaced as text formula via `ResolvedGrantsCard._unarmoredFormulasBlock`. Sheet's AC field still manual; auto-set requires equipment-context evaluation. ◐ partial.
- **Monk's Focus (L2)** — Focus pool ✓ VERIFIED 2026-05-14 — `resource_pool_grant pool:focus_points` (monk_level, short_rest); spend UI Tier 4.
- **Acrobatic Movement (L9)** — walk_on_liquid + vertical surface movement: ✓ SHIPPED — `walk_on_liquid` w/ armor + shield predicates. (RAW 2024: not a climb-speed grant.)

### Paladin
- **Lay on Hands (L1)** — pool max ✓ VERIFIED — `resource_pool_grant pool:lay_on_hands_hp` w/ `count_formula: paladin_level_x5`. Spend Tier 4.
- **Divine Smite (L2)** — `spell_always_prepared` Smite spell. ✓ VERIFIED 2026-05-14.
- **Channel Divinity (Paladin L3)** — pool max ✓ SHIPPED 2026-05-14 — upgraded to `scales_with` Paladin-level table `[(3,2),(11,3)]` on dedicated `pool:paladin_channel_divinity` (separate from Cleric's pool to keep multiclass max independent).
- **Abjure Foes (L9)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:abjure_foes` (1/long_rest). Spend UX Tier 4.
- **Holy Nimbus (Devotion L20)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:holy_nimbus` (1/long_rest). Spend UX Tier 4. Aura damage emission still combat-tracker territory (OUT).
- **Restoring Touch (L14)** — removes condition ids from PC `active_conditions` list via pool spend. **STUB** (consumer not wired).

### Ranger
- **Favored Enemy (L1)** — Hunter's Mark always prepared + free casts/day (pool): ✓ VERIFIED 2026-05-14 — both rows present.
- **Roving (L3)** — speed +5 + swim/climb: ✓ SHIPPED 2026-05-14 — speed_bonus +5, plus `climb_speed_equals_speed` + `swim_speed_equals_speed` routed through Extra Speeds.
- **Tireless (L10)** — temp HP: ✓ SHIPPED 2026-05-14 — `resource_pool_grant` (pool:tireless_temp_hp_uses, wis_mod_min_1, long_rest) + `temp_hp_grant` (1d8 + WIS_mod, magic_action_self) declared.
- **Nature's Veil (L14)** — Invisibility status on PC. OUT (no `active_conditions` writer wired; runtime).

### Rogue
- **Cunning Action (L2)** — bonus-action grant: ✓ SHIPPED 2026-05-14 — `granted_bonus_action_grant` → "Cunning Action" creature-action (Bonus Action). SRD 2024 packs Dash/Disengage/Hide as a single bonus-action option, so a single creature-action covers it.
- **Slippery Mind (L15)** — adds WIS + CHA save prof: ✓ VERIFIED 2026-05-14 — both `proficiency_grant: saving_throw` rows present.
- **Stroke of Luck (L20)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:stroke_of_luck` (1/short_rest). Spend UX Tier 4.

### Sorcerer
- **Innate Sorcery (L1)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:innate_sorcery_uses` w/ `cha_mod_min_1` formula, long_rest recharge. Spend UX Tier 4.
- **Font of Magic (L2)** — Sorcery Points pool max **OK**; SP↔slot conversion mutates
  current slots/SP fields. **STUB**.
- **Metamagic (L2)** — pick 2 from list; stores chosen metamagic ids on PC.
  **MISSING** (no PC field for chosen metamagics; need schema add + `choice_group`).
- **Sorcerous Restoration (L5)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:sorcerous_restoration_per_short_rest` (1/short_rest). SP regain spend UX deferred to Tier 4.

### Warlock
- **Eldritch Invocations (L1, cumulative)** — adds invocation ids to PC field.
  **MISSING** (no PC field, no choice_group).
- **Pact Boon (L3)** — Tome → +3 cantrips (`granted_cantrip_refs`); Chain → Find Familiar in `alwaysPreparedSpellIds`; Blade → bonded-weapon (needs new PC `pact_blade_weapon_id` field, Tier-3). **MISSING** — needs `choice_group` + per-option grant rows.
- **Magical Cunning (L2)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:magical_cunning_per_day` (1/long_rest). Short-rest pact-slot recovery spend UX deferred to Tier 4 #34.
- **Mystic Arcanum (L11/13/15/17)** — pool max ✓ SHIPPED 2026-05-14 — per-level `resource_pool_grant pool:mystic_arcanum_{6..9}` (1/long_rest each). Spend UX Tier 4.
- **Eldritch Master (L13)** — pool max ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:eldritch_master` (1/long_rest). Spend UX Tier 4.

### Wizard
- **Ritual Adept (L1)** — adds rituals from any class to spellbook. **MISSING**
  (extend `spell_grant` ingestion to mark them ritual-only).
- **Arcane Recovery (L1)** — pool max ✓ VERIFIED — `resource_pool_grant pool:arcane_recovery_per_day` (1/long_rest). Short-rest slot-recovery spend UX deferred to Tier 4 #33.
- **Spell Mastery (L18)** — adds 1×L1 + 1×L2 spell to free-cast list. **MISSING** — needs PC `free_cast_spell_ids` field (Tier-3).
- **Signature Spells (L20)** — always-prepared L3 + 1/short rest each. **PARTIAL**.

---

## 5. Subclasses — field-impacting gaps

| Subclass | Feature | Field impact | Status |
|----------|---------|--------------|--------|
| Berserker | Mindless Rage (L6) | conditional `Charmed`/`Frightened` immunity while raging | ✓ SHIPPED 2026-05-14 — 2× `condition_immunity_grant` w/ `state:raging` predicate; routed to `conditionalGrants` |
| College of Lore | Bonus Proficiencies (L3) | adds 3 skill proficiencies | ✓ SHIPPED 2026-05-14 — declared `bonus_skill_pick_count: 3`; subclass-pick scans field + emits follow-on `skillProficiency` pending |
| Life Domain | Preserve Life (L3) | pool max | ✓ OK — Channel Divinity option (spends Cleric `pool:channel_divinity`); no separate pool needed |
| Hunter (Ranger) | Hunter's Prey (L3) / Defensive Tactics (L7) / Multiattack (L11) / Superior Hunter's Defense (L11) | writes chosen-option id to PC `feat_ids` via generic featureOption picker | ✓ SHIPPED 2026-05-14 — new `PendingChoiceKind.featureOption` + `LevelUpPlan.featureOptionPicks`; 11 option feats authored under `feat-category: Feature Option: <name>` (Colossus Slayer / Horde Breaker / Hunter's Lore Option / Escape the Horde / Multiattack Defense / Steel Will / Volley / Whirlwind Attack / Evasion / Stand Against the Tide / Uncanny Dodge); effect bodies still narrative pending Tier 3 combat tracker |
| Thief | Fast Hands (L3) | adds bonus-action refs (Sleight of Hand / Use Object / Tools) | ✓ SHIPPED 2026-05-14 — `granted_bonus_action_grant` → "Fast Hands" creature-action |
| Thief | Second-Story Work (L3) | climb speed | ✓ SHIPPED 2026-05-14 — `climb_speed_equals_speed`, post-pass resolves to walk speed |
| Thief | Use Magic Device (L13) | (no current field for magic-item attune list) | OUT |
| Draconic Sorcery | Draconic Resilience (L3) | HP max + AC formula | **PARTIAL** |
| Draconic Sorcery | Draconic Spells (L3) | always-prepared spell list by element | **PARTIAL** — verify `spell_always_prepared` rows ship |
| Draconic Sorcery | Dragon Wings (L14) | fly speed + 1/long_rest pool | ✓ SHIPPED 2026-05-14 — `fly_speed` declared, post-pass resolves to walk speed, chipped under Extra Speeds. Added `resource_pool_grant pool:dragon_wings` (1/long_rest). |
| Draconic Sorcery | Dragon Companion (L18) | Summon Dragon → `alwaysPreparedSpellIds` + 1/long rest pool | ✓ SHIPPED 2026-05-14 — new `_sf Dragon Companion` declares `spell_always_prepared` (Summon Dragon) + `resource_pool_grant pool:dragon_companion` (1/long_rest) |
| Fiend | Dark One's Blessing (L3) | temp HP field | ✓ SHIPPED 2026-05-14 — `temp_hp_grant` declared (CHA_mod + warlock_level (min 1), trigger `on_reduce_creature_to_0_hp`); surfaced in Temp HP Grants chips |
| Fiend | Dark One's Own Luck (L6) | 1/short_rest pool | ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:dark_ones_own_luck` (1/short_rest) |
| Fiend | Fiendish Resilience (L10) | adds chosen damage resistance after rest | **MISSING** — daily-pick choice_group writing to `damageResistanceIds` |
| Fiend | Hurl Through Hell (L14) | 1/long_rest pool | ✓ SHIPPED 2026-05-14 — `resource_pool_grant pool:hurl_through_hell` (1/long_rest) |
| Evoker | (sculpt/potent/empowered/overchannel all roll-time) | — | OUT |

---

## 6. Prioritised roadmap (field-mutation only)

### Tier 1 — pure data edits (resolver already supports the kind)

Each <10 min, no resolver change:

1. ✓ **Tough** → `hp_bonus_per_level: 2`. **SHIPPED 2026-05-14.**
2. ✓ **Defense (Fighting Style)** → `ac_bonus: 1` with `equipped_armor_kind: not_none` predicate. **SHIPPED 2026-05-14.** Resolver `equipped_armor_kind` extended with `not_none` arm.
3. ✓ **Resilient** → new `PendingChoiceKind.featAsi` covers feat-side ASI sub-picker. Feat schema gains `grants_save_prof_from_asi: bool`; Resilient declares true. `featAsi` resolution payload carries `abilityBumps` + `saveProfAbilityAbbrevs`. Editor flips `saving_throws.rows[i].proficient` for the chosen ability. Honors feat's `asi_max_score` (also fixes Epic Boon ASI cap 30). **SHIPPED 2026-05-14.**
4. ✓ **Lightly / Moderately Armored** → armor-category `proficiency_grant`. **SHIPPED 2026-05-14.** Resolver `proficiency_grant` extended with `armor_category` + `weapon_category` target_kinds. Heavy Armor Master skipped — SRD prereq already requires heavy armor proficiency (feat itself grants damage reduction, which is roll-time).
5. ✓ **Skill Expert** → both sides shipped. Skill side via `bonus_skill_pick_count: 1` → follow-on `skillProficiency` pending choice. Expertise side via new `bonus_expertise_pick_count: 1` + new `PendingChoiceKind.expertise` + dialog body filtered to PC's currently proficient skills lacking expertise. Editor applies both: `skills.rows[i].proficient = true` for skill picks, `expertise = true` for expertise picks. **SHIPPED 2026-05-14.**
6. ✓ **Boon of Truesight** → `truesight_grant` referencing Truesight 60ft sense entity. **SHIPPED 2026-05-14.**
7. ✓ **College of Lore — Bonus Proficiencies (L3)** → encoded as `bonus_skill_pick_count: 3` on the subclass entity. Subclass-pick resolution scans this field and queues a follow-on `skillProficiency` pending choice. **SHIPPED 2026-05-14.**
8. ✓ **Cleric — Divine Order (L1)** → SHIPPED 2026-05-14. Two pickable feats (`Divine Order: Protector`, `Divine Order: Thaumaturge`) under new `feat-category: Divine Order`. Picker plumbed through new `PendingChoiceKind.divineOrder` + `LevelUpPlan.isDivineOrderLevel` (feature-name match on "Divine Order"). Editor + wizard both seed/emit the pending; resolution writes feat id to `feat_ids`. Protector folds Martial weapon + Heavy armor proficiency_grants. Thaumaturge declares `cantrip_count_bonus: 1` (free-pick cantrip surface still TBD).
9. ✓ **Rogue — Cunning Action (L2)** → resolver gains three new effect kinds (`granted_action_grant`, `granted_bonus_action_grant`, `granted_reaction_grant`). New `Cunning Action` creature-action entity describes the bonus-action form; feat declares `granted_bonus_action_grant` → that entity. **SHIPPED 2026-05-14.**
10. ✓ **Thief — Fast Hands (L3)** → references existing `Fast Hands` creature-action entity via `granted_bonus_action_grant`. **SHIPPED 2026-05-14.**
11. ~~**Innate Spellcasting (player-facing variants only)**~~ → PC species (Drow, High Elf, Wood Elf, Tieflings) already encode `granted_cantrip_refs` + `granted_spells_at_level` on subspecies — not on the shared trait. **N/A.**
12. ✓ **Fey-Touched / Shadow-Touched / Telekinetic / Telepathic** → fixed-spell rows declared (Misty Step / Invisibility / Mage Hand / Detect Thoughts). **SHIPPED 2026-05-14.** The "pick 1 L1 spell from school X" portion still blocks on Tier 2 #15 (cumulative pick).

### Tier 2 — small resolver / planner extensions

13. ✓ **Pending choice: `skillProficiency` dialog body** — surfaces Tier 1 #7 + any other "pick N skills" rows. **SHIPPED 2026-05-14.** Dialog renders skill picker filtered to skills the PC isn't already proficient in. Resolution flips `skills.rows[i].proficient = true` on the matching row. Emission hooks: subclass-pick (Lore L3 via `bonus_skill_pick_count`) + feat-pick (Skill Expert via `bonus_skill_pick_count`). Resilient covered by parallel `featAsi` pending (grants_save_prof_from_asi).
14. ✓ **Pending choice: generic subclass-option picker** — Cleric Divine Order (dedicated `PendingChoiceKind.divineOrder`, 2026-05-14) + Hunter Ranger pickers + Pact Boon + Draconic Spells + Fiendish Resilience (generic `PendingChoiceKind.featureOption`, 2026-05-14) shipped. The featureOption kind carries `featureName` on the pending; dialog filters feats by category `Feature Option: <name>`. Planner `featureOptionPicks: List<String>` populated via feature-name trigger set in `level_up_planner.dart`. **SHIPPED 2026-05-14** for Pact Boon (3 options: Blade/Chain/Tome), Draconic Spells (5 ancestries: Acid/Cold/Fire/Lightning/Poison) and Fiendish Resilience (12 damage-type options; recurring rest-bound re-pick is still narrative — single emission at L10). To add a new picker: append the feature name to `featureOptionTriggers` + author 2-N option feats under `feat-category: Feature Option: <name>`.
15. ✓ **Pending choice: cumulative pick (Metamagic / Eldritch Invocations)** — **SHIPPED 2026-05-14** via new `_cumulativePickProgression` table in `level_up_planner.dart` keyed by class name + feature name → `{level: picksGained}`. Sorcerer Metamagic emits 2 picks at L2, +1 at L10, +1 at L17. Warlock Eldritch Invocations emits 2 picks at L1, +1 at L5/7/9/12/15/18. Each pick is a separate `featureOption` pending; dialog filters by feat category and excludes already-picked option feats so consecutive pendings yield distinct options. Authored 10 Metamagic feats (Careful/Distant/Empowered/Extended/Heightened/Quickened/Seeking/Subtle/Transmuted/Twinned) + 12 core Invocation feats (Agonizing Blast / Armor of Shadows / Devil's Sight / Eldritch Mind / Eldritch Sight / Eldritch Spear / Fiendish Vigor / Gaze of Two Minds / Mask of Many Faces / Misty Visions / One with Shadows / Repelling Blast). Pact Boon went through #14 instead. Battle Master Maneuvers blocked on Battle Master subclass content (not yet authored). PC field for chosen list = existing `feat_ids` (no new schema needed). Effect bodies for Metamagic/Invocations remain narrative — pure roll-time mechanics, surfaces in combat tracker (Tier 3).
16. ✓ **`sense_grant` range payload** — `range_ft` accepted on `sense_grant` / `truesight_grant` / `blindsight_grant` payloads (or top-level). Resolver tracks per-sense-id max range in new `EffectiveCharacter.senseRanges: Map<String,int>`. Drow subspecies declares Superior Darkvision via `granted_modifiers` → `sense_grant Darkvision` payload `range_ft: 120`. Sheet's `ResolvedGrantsCard` renders the range suffix on every sense chip (`Darkvision 120 ft`). **SHIPPED 2026-05-14.**
17. ✓ **State-conditional grants surface** — `EffectiveCharacter.conditionalGrants: List<Map>` added. Resolver splits state predicates from non-state predicates; eligible kinds (`damage_resistance`, `damage_immunity`, `damage_vulnerability`, `condition_immunity_grant`) gated by `has_state` / `has_condition` / `target_has_condition` are routed to this list when the non-state predicates all pass. Mindless Rage now declares the two `condition_immunity_grant` rows for Charmed + Frightened with Raging predicate. Rage damage resistances flow automatically (already authored). Boon of the Night Spirit declares 11 `damage_resistance` rows (every damage type except Psychic + Radiant) gated on new `state:in_dim_or_darkness` tier-0 character-state. Sheet's `ResolvedGrantsCard` buckets entries by `(kind, state)` and renders one chip row per bucket labelled `Resistances (while raging)` / `Resistances (while in_dim_or_darkness)` etc. **SHIPPED 2026-05-14.**
18. ◐ **Wire `temp_hp_grant`** — minimal surface shipped. Resolver collects `temp_hp_grant` rows into `EffectiveCharacter.tempHpGrants: List<Map>` (entries `{source, formula, trigger, activation}`). Sheet's `ResolvedGrantsCard` renders a "Temp HP Grants" row of pink chips. Inspiring Leader (+character_level + CHA_mod after speech), Ranger Tireless (1d8 + WIS_mod, Magic action), and Dark One's Blessing (CHA_mod + warlock_level (min 1), on reduce to 0 HP) declare the effect. **SHIPPED 2026-05-14.** Auto-apply to PC `temp_hp` still requires runtime trigger UX (button + rest pipeline).
19. ✓ **Wire `climb_speed_equals_speed`, `swim_speed_equals_speed`, `fly_speed`** — `extraSpeeds: Map<String, int>` added to EffectiveCharacter; resolver writes per mode, post-pass resolves `-1` sentinel to walking speed (species `speed_ft` + `speedBonus`). Roving (already wired), Second-Story Work (already wired), Dragon Wings now declare `fly_speed`. Sheet's `ResolvedGrantsCard` renders an "Extra Speeds" row with `mode N ft` chips. **SHIPPED 2026-05-14.** Spider Climb monster traits still narrative only.
20. ~~**Wire `cantrip_count_bonus`**~~ — no SRD content currently authors this kind. **N/A.** Revisit if a feat/boon needs it.
21. **`size_override` effect kind + Goliath Large Form** — deferred. Goliath's Large Form is a runtime bonus-action toggle, not a permanent grant; needs runtime trigger UX before the effect kind matters.
22. ✓ **`ability_score_cap_override`** — resolver `ability_score_bonus` honors `eff.max`. Primal Champion declares STR +4 max:25 + CON +4 max:25. Epic Boon ASI cap of 30 fixed via the new `featAsi` pending — dialog reads feat's `asi_max_score` and gates the bump accordingly. **SHIPPED 2026-05-14.**

### Tier 3 — needs new PC schema fields

23. **PC `metamagic_ids: List<String>`** + Sorcerer Metamagic picker.
24. **PC `invocation_ids: List<String>`** + Warlock Invocations picker.
25. **PC `pact_boon_id: String?`** + `pact_blade_weapon_id: String?` + Warlock Pact Boon picker (Tome cantrips, Chain familiar, Blade bonded-weapon).
26. **PC `maneuver_ids: List<String>`** — unblocks Battle Master + Martial Adept feat.
27. **PC `free_cast_spell_ids: List<String>`** — Wizard Spell Mastery, Sorcerer Restoration, Warlock Mystic Arcanum free casts.
28. **PC `ritual_book_spell_ids: List<String>`** — Ritual Caster feat, Wizard Ritual Adept.
29. **PC `subclass_option_picks: Map<String,String>`** — Hunter Prey/Defensive/Multiattack, Fiendish Resilience daily-pick, Cleric Divine Order choice.
30. **PC `active_conditions: List<String>` writer/clearer** — Restoring Touch removes; rest pipeline / Nature's Veil add.

### Tier 4 — pool-spending UX (field mutation; pool max already wired)

31. ✓ Class-pool counters wired on the sheet via `ResolvedGrantsCard._grantedPoolEntries` + `_displayPoolName` (`pool:rage_uses` → "Rage Uses"). `PC.granted_pool_uses_remaining` already persists per-pool current value. Resolver gained a `count_formula` evaluator (`_evalCountFormula`) covering `<ability>_mod`, `<ability>_mod_min_1`, `<class>_level`, `paladin_level_x5`, `character_level` — closes pools whose max was previously unresolved (Lay on Hands HP = `paladin_level_x5`, Tireless temp-HP uses = `wis_mod_min_1`, Sorcery Points = `sorcerer_level`, etc.). Pool entries with non-positive max are filtered out so unresolved formulas no longer pollute the sheet. **SHIPPED 2026-05-14.**
32. Sorcery Points ↔ slot conversion (mutates SP pool + current slot map). **Deferred.**
33. Wizard Arcane Recovery (mutates current slot map). **Deferred.**
34. Warlock Magical Cunning + Wild Companion (current slot map mutation). **Deferred.**

All reduce pool current or restore slot — pure field deltas, no combat resolution.

---

## Out of scope (roll-time / runtime — not field mutations)

Documented here so they aren't re-asked-for under this audit's lens:

- All `advantage_on` / `disadvantage_on` (Reckless, Brave, Lucky-halfling, Pack Tactics, Keen Senses, Fey Ancestry charm advantage, Gnomish Cunning, Cutting Words, Steady Aim, Innate Sorcery, Sunlight Sensitivity)
- All `extra_damage_on_attack` (Sneak Attack, Divine Smite damage rider, Brutal Strike, Blessed Strikes, Radiant Strikes, Hunter's Prey damage, Brute)
- All `attack_bonus_typed` / `damage_bonus_typed` (Archery, Dueling, Two-Weapon Fighting damage mod, Polearm Master, Great Weapon Master, Sharpshooter, Empowered Evocation, Elemental Affinity, Sacred Weapon)
- All save-resolution riders (Evasion, Stunning Strike DC, Sculpt Spells bypass, Disciple of Life HP rider, Aura of Protection/Devotion save bonus, Aura of Courage condition immunity while in aura)
- `reroll_d20` / `reroll_damage` / `min_die_value` / `reliable_talent` / `passive_score_bonus` / `half_proficiency_to_unproficient_checks` consumers
- Monster mechanics: Regeneration tick, Absorption heal-on-typed-dmg, Death Burst, Heated Body, Legendary Resistance reroll trigger, Undead Fortitude, Pounce/Charge bonus, Siege Monster x2 to objects, Trampling Charge
- Wild Shape transformation, Channel Divinity option resolution (Turn Undead radius/DC), Holy Nimbus damage emission, Hurl Through Hell psychic damage

Move these to the Combat Tracker doc once that surface lands.
