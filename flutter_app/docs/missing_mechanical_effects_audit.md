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
| Tough | `hpBonusPerLevel` +2 | **MISSING** | one-line `hp_bonus_per_level: 2` |
| Magic Initiate | cantrip + spell lists | **OK** | choice_group resolved |
| Skilled | skill list | **OK** | |
| Crafter | tool list | **OK** | (discount/speed out-of-scope) |
| Musician | tool list | **OK** | (inspiration out-of-scope) |
| Tavern Brawler | ASI | **OK** | (d4 unarmed die has no PC field — OUT until unarmed-strike die field added) |
| Lucky | `resourcePools` (PB Luck Points/day) | **MISSING** | declare `resource_pool_grant` |
| Healer | (no field impact — Hit-Die reroll out-of-scope) | OUT | — |
| Alert | (no field — initiative formula uses `initiativeBonus`, but Alert's +PB is roll-time) | OUT | — |
| Savage Attacker | (reroll dmg, no field) | OUT | — |

### 2.2 General

ASI typed fields wire on every general feat. Non-ASI field impact only:

| Feat | Field impact | Status |
|------|--------------|--------|
| Resilient | adds save proficiency | **MISSING** (post-pick `proficiency_grant: saving_throw`) |
| Lightly Armored | adds Light armor cat to `armorCategoryIds` | **MISSING** |
| Moderately Armored | adds Medium armor + Shield | **MISSING** |
| Heavy Armor Master | adds Heavy armor proficiency | **MISSING** (the dmg reduction part is out-of-scope) |
| Skill Expert | adds 1 skill + 1 expertise | **MISSING** (post-pick `proficiency_grant: skill` + `expertise_grant`) |
| Fey-Touched | +1 INT/WIS/CHA + Misty Step + 1 L1 divination/enchantment always prepared | **PARTIAL** (ASI works; spell adds missing) |
| Shadow-Touched | +1 INT/WIS/CHA + Invisibility + 1 L1 illusion/necromancy always prepared | **PARTIAL** (same) |
| Telekinetic | +1 INT/WIS/CHA + Mage Hand cantrip | **PARTIAL** (cantrip add missing) |
| Telepathic | +1 INT/WIS/CHA + Detect Thoughts always prepared | **PARTIAL** (spell add missing) |
| Ritual Caster | adds rituals to spellbook (field) | **MISSING** (`spell_grant` rows for chosen list) |
| Inspiring Leader | grants temp HP to N allies after rest | **STUB** (temp_hp_grant no-op; PC `temp_hp` field exists) |
| Elemental Adept | adds a damage-type tag to PC (no current field) | OUT (no PC-side field stores this) |
| Martial Adept | adds maneuvers (no current field) | OUT (no maneuver-list field yet) |

Out-of-scope (roll-time): Charger, Crossbow Expert, Defensive Duelist, Dual Wielder,
Durable, Grappler, Great Weapon Master, Keen Mind, Mage Slayer, Mobile, Mounted
Combatant, Observant, Polearm Master, Sentinel, Sharpshooter, Shield Master, Spell
Sniper, War Caster, Weapon Master, Athlete.

### 2.3 Fighting Styles

| Style | Field impact | Status | Fix |
|-------|--------------|--------|-----|
| Defense | `acBonus +1` while armored | **MISSING** | declare `ac_bonus 1` with `equipped_armor_kind: not_none` predicate (predicate already supported) |
| Blind Fighting | adds blindsight 10ft to senses | **MISSING** | declare `blindsight_grant` (sense entity needed) |

Out-of-scope (roll-time): Archery, Dueling, Great Weapon Fighting, Two-Weapon Fighting,
Interception, Protection, Thrown Weapon Fighting, Unarmed Fighting.

### 2.4 Epic Boons

| Boon | Field impact | Status |
|------|--------------|--------|
| Boon of Truesight | senses list + truesight 60ft | **MISSING** — declare `truesight_grant` |
| Boon of Night Spirit | conditional resistance addition | **STUB** (state-conditional, see §6 Tier 2) |

Dropped (no field surface): Dimensional Travel, Spell Recall (no slot-recall pool yet), Fate, Combat Prowess, Irresistible Offense.

### 2.5 Class feats (`feats_class.dart`)

Field-impacting gaps only:

| Feat | Field impact | Status |
|------|--------------|--------|
| Rage (Barbarian) | adds damage_resistance entries while raging | **PARTIAL** — predicate `has_state` returns false at resolve time, list never lights up |
| Mindless Rage (Berserker L6) | adds `Charmed`/`Frightened` condition immunity while raging | **MISSING** — needs predicated entry + state predicate evaluator |
| Cunning Action (Rogue) | adds 3 bonus-action refs to `grantedBonusActionIds` | **MISSING** — declare `granted_bonus_action_refs` for Dash/Disengage/Hide |
| Slippery Mind (Rogue L15) | adds Wisdom + Charisma save prof | **PARTIAL** — verify both `proficiency_grant: saving_throw` rows ship |
| Second-Story Work (Thief) | adds climb speed = walk | **STUB** (`climb_speed_equals_speed` no-op) |
| Acrobatic Movement (Monk L9) | climb + swim = walk | **STUB** (same) |
| Roving (Ranger L3) | adds +5 speed + climb + swim | **PARTIAL** — `speed_bonus` wired, swim/climb stubs |
| Draconic Resilience (Sorcerer Sub) | `hp_max_bonus_total` + unarmored AC formula | **PARTIAL** — HP works, AC formula stored but not always evaluated |
| Dragon Wings (Sorcerer Sub L14) | fly speed = walk | **STUB** (`fly_speed` no-op) |
| Aura of Courage (Paladin L10) | adds `Frightened` immunity while in aura | OUT (aura predicate runtime) |
| Dark One's Blessing (Fiend Warlock) | writes to PC `temp_hp` | **STUB** (`temp_hp_grant` no-op) |
| Divine Smite (Paladin L2) | adds Smite spell to `alwaysPreparedSpellIds` | **PARTIAL** (declared, verify presence) |
| Hunter's Mark (Ranger Favored Enemy) | always-prepared spell | **PARTIAL** |
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
| Drow | senses list — Superior Darkvision 120ft (range overrides default 60ft) | **STUB** — `sense_grant` has no `range_ft` payload; sheet renders single line |
| High Elf | cantrip list — "a Wizard cantrip" of player choice | **MISSING** — declare `choice_group` with cantrip-from-list payload |
| Goliath | `size` field at L5 (Large Form) | **MISSING** — no `size_override` effect kind; PC `size` field exists but never gets written |
| Wood Elf | speed +5 + base = 35 | **OK** |
| Stout Halfling | poison resistance | **OK** |
| Mountain Dwarf | +2 flat HP | **OK** (via `hp_bonus_flat`) |
| Hill Dwarf | Insight skill prof | **OK** |
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
- **Rage (L1)** — `damage_resistance` rows w/ state predicate: **PARTIAL** (predicate
  drops at resolve). Fix: emit `conditionalDamageResistances` on EffectiveCharacter so
  sheet can render gated entries.
- **Primal Champion (L20)** — STR/CON cap raised to 24. **MISSING** — needs ability cap
  override path (currently hardcoded to 20 in `applyEffect`).

### Bard
- **Bardic Inspiration (L1)** — `resource_pool_grant` max OK. Pool current value
  decrement on use is field mutation — **PARTIAL** (no spend UI).
- **Magical Secrets (L10)** — adds spells from any list to `grantedSpellIds`.
  **MISSING** (`choice_group` not authored).

### Cleric
- **Divine Order (L1)** — Protector adds Martial weapon cat + heavy armor; Thaumaturge
  adds a cantrip + spell-save bonus to one cantrip cast/turn. Field impact:
  proficiency lists OR cantrip list. **MISSING** (no pending choice + no post-pick
  effect rows).
- **Channel Divinity (L2)** — pool max **OK**; current-value spend **PARTIAL**.

### Druid
- **Wild Companion (L2)** — slot→Find Familiar conversion mutates current slot map.
  **STUB** (no current-slot-decrement consumer; field exists).

### Fighter
- **Second Wind (L1)** — pool max **OK**; spend **PARTIAL**.
- **Action Surge (L2)** — pool max **OK**; spend **PARTIAL**.
- **Indomitable (L9)** — pool max **PARTIAL**.

### Monk
- **Unarmored Defense (L1)** — `unarmored_ac_formula` stored; sheet evaluation
  inconsistent. **PARTIAL**.
- **Monk's Focus (L2)** — Ki pool **PARTIAL**.
- **Acrobatic Movement (L9)** — climb/swim = walk. **STUB**.

### Paladin
- **Lay on Hands (L1)** — pool max **OK**; spend **PARTIAL**.
- **Divine Smite (L2)** — `spell_always_prepared` Smite spell. **PARTIAL** (declared,
  verify).
- **Restoring Touch (L14)** — removes condition ids from PC `active_conditions` list via pool spend. **STUB** (consumer not wired).

### Ranger
- **Favored Enemy (L1)** — Hunter's Mark always prepared + free casts/day (pool). 
  **PARTIAL** (always prepared OK, pool of free casts not declared).
- **Roving (L3)** — speed +5 + swim/climb. **PARTIAL** (speed_bonus OK, others stub).
- **Tireless (L10)** — temp HP. **STUB**.
- **Nature's Veil (L14)** — Invisibility status on PC. OUT (no `active_conditions` writer wired; runtime).

### Rogue
- **Cunning Action (L2)** — `granted_bonus_action_refs` for Dash/Disengage/Hide.
  **MISSING** (declare three bonus-action refs).
- **Slippery Mind (L15)** — adds WIS + CHA save prof. **PARTIAL**.

### Sorcerer
- **Font of Magic (L2)** — Sorcery Points pool max **OK**; SP↔slot conversion mutates
  current slots/SP fields. **STUB**.
- **Metamagic (L2)** — pick 2 from list; stores chosen metamagic ids on PC.
  **MISSING** (no PC field for chosen metamagics; need schema add + `choice_group`).
- **Sorcerous Restoration (L5)** — SP regain on short rest. Pool current = field 
  mutation. **STUB**.

### Warlock
- **Eldritch Invocations (L1, cumulative)** — adds invocation ids to PC field.
  **MISSING** (no PC field, no choice_group).
- **Pact Boon (L3)** — Tome → +3 cantrips (`granted_cantrip_refs`); Chain → Find Familiar in `alwaysPreparedSpellIds`; Blade → bonded-weapon (needs new PC `pact_blade_weapon_id` field, Tier-3). **MISSING** — needs `choice_group` + per-option grant rows.
- **Magical Cunning (L2)** — short-rest pact slot regain. Current-slot field. **STUB**.

### Wizard
- **Ritual Adept (L1)** — adds rituals from any class to spellbook. **MISSING**
  (extend `spell_grant` ingestion to mark them ritual-only).
- **Arcane Recovery (L1)** — short-rest slot recovery formula. **STUB**.
- **Spell Mastery (L18)** — adds 1×L1 + 1×L2 spell to free-cast list. **MISSING** — needs PC `free_cast_spell_ids` field (Tier-3).
- **Signature Spells (L20)** — always-prepared L3 + 1/short rest each. **PARTIAL**.

---

## 5. Subclasses — field-impacting gaps

| Subclass | Feature | Field impact | Status |
|----------|---------|--------------|--------|
| Berserker | Mindless Rage (L6) | conditional `Charmed`/`Frightened` immunity while raging | **MISSING** — needs state-predicate evaluator + conditional surface |
| College of Lore | Bonus Proficiencies (L3) | adds 3 skill proficiencies | **MISSING** — needs `PendingChoiceKind.skillProficiency` dialog body |
| Life Domain | Preserve Life (L3) | pool max | **PARTIAL** (pool tracked) |
| Hunter (Ranger) | Hunter's Prey (L3) / Defensive Tactics (L7) / Multiattack (L11) | writes chosen-option id to PC `subclass_option_picks` map | **MISSING** — needs PC field (Tier-3) + subclass-pick `choice_group` resolver |
| Thief | Fast Hands (L3) | adds bonus-action refs (Sleight of Hand / Use Object / Tools) | **MISSING** — declare `granted_bonus_action_refs` |
| Thief | Second-Story Work (L3) | climb speed | **STUB** |
| Thief | Use Magic Device (L13) | (no current field for magic-item attune list) | OUT |
| Draconic Sorcery | Draconic Resilience (L3) | HP max + AC formula | **PARTIAL** |
| Draconic Sorcery | Draconic Spells (L3) | always-prepared spell list by element | **PARTIAL** — verify `spell_always_prepared` rows ship |
| Draconic Sorcery | Dragon Wings (L14) | fly speed | **STUB** |
| Draconic Sorcery | Dragon Companion (L18) | Summon Dragon → `alwaysPreparedSpellIds` + 1/long rest pool | **MISSING** — declare `spell_always_prepared` + `resource_pool_grant` |
| Fiend | Dark One's Blessing (L3) | temp HP field | **STUB** |
| Fiend | Fiendish Resilience (L10) | adds chosen damage resistance after rest | **MISSING** — daily-pick choice_group writing to `damageResistanceIds` |
| Evoker | (sculpt/potent/empowered/overchannel all roll-time) | — | OUT |

---

## 6. Prioritised roadmap (field-mutation only)

### Tier 1 — pure data edits (resolver already supports the kind)

Each <10 min, no resolver change:

1. **Tough** → declare `hp_bonus_per_level: 2`.
2. **Defense (Fighting Style)** → declare `ac_bonus: 1` with `equipped_armor_kind: not_none` predicate.
3. **Resilient** → wire post-choice `proficiency_grant: saving_throw`.
4. **Lightly / Moderately / Heavy Armored** → declare armor-category `proficiency_grant`.
5. **Skill Expert** → post-choice `proficiency_grant: skill` + `expertise_grant`.
6. **Boon of Truesight** → declare `truesight_grant` referencing Truesight 60ft sense entity.
7. **College of Lore — Bonus Proficiencies (L3)** → declare `choice_group` of 3× `proficiency_grant: skill`.
8. **Cleric — Divine Order (L1)** → declare both Protector and Thaumaturge as a `choice_group`; each option emits its `proficiency_grant` / `cantrip_grant`.
9. **Rogue — Cunning Action (L2)** → declare three `granted_bonus_action_refs` (Dash, Disengage, Hide).
10. **Thief — Fast Hands (L3)** → declare three `granted_bonus_action_refs`.
11. **Innate Spellcasting (player-facing variants only)** → replace narrative text with `granted_spell_refs` / `granted_cantrip_refs` / `granted_spells_at_level` rows on the trait.
12. **Fey-Touched / Shadow-Touched / Telekinetic / Telepathic** → declare the `cantrip_grant` / `spell_grant` / `spell_always_prepared` rows already promised by the feat description.

### Tier 2 — small resolver / planner extensions

13. **Pending choice: `skillProficiency` dialog body** — surfaces Tier 1 #7 + any other "pick N skills" rows.
14. **Pending choice: generic subclass-option picker** — closes Hunter (Prey/Defensive/Multiattack), Fiend Fiendish Resilience daily-pick, Draconic Companion option, Cleric Divine Order interactive resolve.
15. **Pending choice: cumulative pick (Metamagic / Pact Boon / Eldritch Invocations)** — needs PC schema fields for the chosen lists first (`metamagic_ids`, `pact_boon_id`, `invocation_ids`).
16. **`sense_grant` range payload** — add `range_ft` and resolver pass that keeps max range per sense id. Closes Drow 120ft.
17. **State-conditional grants surface** — when an effect carries a `has_state` predicate, instead of dropping it, emit a parallel list on `EffectiveCharacter` (e.g. `conditionalDamageResistances: [{state: 'Raging', ids: [...]}]`). Closes Rage, Mindless Rage, Boon of Night Spirit.
18. **Wire `temp_hp_grant`** — write to PC `temp_hp` field; rest pipeline clears on long rest. Closes Inspiring Leader, Dark One's Blessing, Tireless, Ranger Tireless.
19. **Wire `climb_speed_equals_speed`, `swim_speed_equals_speed`, `fly_speed`** — add `extraSpeeds: Map<String, int>` to EffectiveCharacter; sheet renders each. Closes Spider Climb, Second-Story Work, Acrobatic Movement, Roving, Dragon Wings.
20. **Wire `cantrip_count_bonus`** — applies to cantrips_known cap. Used by some boons / feats.
21. **`size_override` effect kind + Goliath Large Form** — extend `applyEffect`, add `size` to EffectiveCharacter.
22. **`ability_score_cap_override`** — Primal Champion (24), Epic Boon ASI (30). Today the cap is hardcoded.

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

31. Lay on Hands point spend (writes `granted_pool_uses_remaining`).
32. Channel Divinity option spend (same field).
33. Bardic Inspiration / Second Wind / Action Surge / Indomitable / Preserve Life / Monk Focus pool spend (same field).
34. Sorcery Points ↔ slot conversion (mutates SP pool + current slot map).
35. Wizard Arcane Recovery (mutates current slot map).
36. Warlock Magical Cunning + Wild Companion (current slot map mutation).

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
