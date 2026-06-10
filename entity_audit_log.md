# Entity Audit Log

> Automated System-Architecture Inspection — per-entity ledger.
> Audit date **2026-06-10** · branch `list` · read-only (no source files modified).
> Companion roadmap: [`system_mechanics_roadmap.md`](system_mechanics_roadmap.md)

**Legend** — issues per entity:
`PREREQ` = unimplemented/incorrect prerequisite · `MECH` = missing mechanic (described in
text, no typed effect) · `STRUCT` = poor data structure (dumped into one text field) ·
`Clean` = all described mechanics typed & all prerequisites enforced.

**Method note.** The built-in SRD Core pack (~1,900 entities) is enumerated per-entity below.
The 19 official open5e packs (~20,700 entities) are reported per-pack and per-category with
named examples and real coverage numbers — enumerating all ~20.7k cards individually is
impractical, and within a pack every entity of a category shares the same typed-field shape, so
findings are category-uniform. Resolver = `character_resolver.dart` (~110 effect kinds), which
reads `effects` only from `feat` entities.

---

# PART A — Built-in SRD 5.2.1 Core pack

## A.1 General / Origin / Fighting-Style / Epic-Boon Feats (`feats.dart`, 53)

> Feat prereqs are enforced only via flat `prereq_min_character_level` + single
> `prereq_ability_ref`/`prereq_min_score`. `prereq_requires_spellcasting`, proficiency
> prereqs, and OR-of-ability prereqs are **not** enforced for these built-in feats.

### Origin
- **Alert**: MECH — Initiative Proficiency + Initiative Swap are prose-only (no `initiative_bonus`/effect).
- **Magic Initiate**: Clean (typed `choice_group` effects for list/cantrips/level-1 spell).
- **Savage Attacker**: MECH — once/turn reroll weapon damage has no `reroll_damage` effect.
- **Skilled**: Clean (typed `skill_or_tool` choice).
- **Crafter**: Partial — tool-choice typed; discount/faster-crafting are non-mechanical (acceptable).
- **Healer**: MECH — Battle Medic / Healing Surge prose-only.
- **Lucky**: Clean (Luck Points `resource_pool_grant`, pb/long_rest).
- **Musician**: Partial — instrument-choice typed; Encouraging Song (Heroic Inspiration) prose-only.
- **Tavern Brawler**: Partial — ASI choice typed; unarmed d4 / improvised prof / push prose-only.
- **Tough**: Clean (`hp_bonus_per_level`).

### General
- **Ability Score Improvement**: Clean (typed ASI, level-4 gate).
- **Grappler**: PREREQ — "Strength or Dexterity 13+" ships `prereq_min_score:13` with no `prereq_ability_ref`, so the ability gate is dropped (unenforced); level gate OK. MECH — Punch-and-Grab / Attack Advantage / Fast Wrestler prose-only.
- **Athlete / Charger / Dual Wielder / Durable / Keen Mind / Mage Slayer / Martial Adept / Mobile / Mounted Combatant / Observant / Polearm Master / Sentinel / Sharpshooter / Skill Expert / Weapon Master / Great Weapon Master**: MECH — ASI typed + level gate OK, but the named combat riders are prose-only (no effects). Skill Expert additionally carries typed `bonus_skill_pick_count`/`bonus_expertise_pick_count` (good).
- **Crossbow Expert**: Clean-ish — DEX 13 + level gate enforced (`prereq_ability_ref`+`prereq_min_score`); MECH — ignore-loading / firing-in-melee / bonus shot prose-only.
- **Defensive Duelist**: DEX 13 + level enforced; MECH — Parry reaction prose-only.
- **Inspiring Leader**: CHA 13 + level enforced; temp-HP modeled via `temp_hp_grant` (good).
- **Elemental Adept**: PREREQ — `prereq_requires_spellcasting:true` not consumed → spellcasting gate unenforced. MECH — energy mastery prose-only.
- **Spell Sniper / War Caster**: PREREQ — spellcasting prereq unenforced. MECH — benefits prose-only.
- **Heavy Armor Master / Medium Armor Master / Shield Master / Moderately Armored**: PREREQ — armor/shield proficiency prereq exists only in `prerequisite` text (no field) → unenforced. MECH — damage reduction / stealth / interpose prose-only (Lightly/Moderately Armored do grant `proficiency_grant`).
- **Ritual Caster**: PREREQ — "Intelligence or Wisdom 13+" has no `prereq_min_score`/`prereq_ability_ref` at all → unenforced. MECH — ritual book prose-only.
- **Resilient**: Clean (typed `grants_save_prof_from_asi`).
- **Lightly Armored / Moderately Armored**: Clean (typed `proficiency_grant`).
- **Fey-Touched / Shadow-Touched / Telepathic**: Partial — `spell_always_prepared` typed for the fixed spell; the "+1 spell of your choice" and riders prose-only.
- **Telekinetic**: Partial — `cantrip_grant` Mage Hand typed; telekinetic shove prose-only.

### Fighting Style (prereq "Fighting Style Feature" is display text; these are gated by feature pick)
- **Defense**: Clean (`ac_bonus` with `equipped_armor_kind` predicate).
- **Blind Fighting**: Clean (`blindsight_grant` 10 ft).
- **Archery / Great Weapon Fighting / Two-Weapon Fighting / Dueling / Interception / Protection / Thrown Weapon Fighting / Unarmed Fighting**: MECH — flat attack/damage/reaction benefits prose-only (no `attack_bonus_typed`/`damage_bonus_typed`/reaction effect).

### Epic Boon (all level-19 gate enforced; ASI typed)
- **Boon of Combat Prowess / Dimensional Travel / Fate / Irresistible Offense / the Night Spirit**: MECH — the boon power is prose-only (Night Spirit *does* type its conditional `damage_resistance` rows — partial).
- **Boon of Truesight**: Clean (`truesight_grant`).
- **Boon of Spell Recall**: PREREQ — `prereq_requires_spellcasting:true` not consumed (level gate OK). MECH — free-casting prose-only.

## A.2 Class / Subclass option & feature feats (`feats_class.dart`, 155)

> Built via `_opt`, which writes prereqs to a free-text `prerequisite` field — **every prereq
> in this file is unenforced** (low practical risk: picks are gated behind their parent
> feature). The dominant issue is MECH: ~two-thirds carry their rule in prose with empty/absent
> `effects`. Auto-grant rows correctly set `at_level`.

**Mechanically Clean (typed):** Rage, Unarmored Defense (Barbarian/Monk), Weapon Mastery
(all classes), Danger Sense, Fast Movement, Extra Attack (all classes), Primal Champion,
Bardic Inspiration (base), Expertise (Bard/Rogue/Ranger), Jack of All Trades, Channel Divinity,
Blessed Strikes, Improved Blessed Strikes, Divine Intervention, Second Wind, Action Surge,
Indomitable, Two/Three Extra Attacks, Monk's Focus, Unarmored Movement, Lay On Hands,
Paladin's Smite, Favored Enemy, Deft Explorer, Roving, Tireless, Relentless Hunter, Sneak
Attack, Cunning Action, Slippery Mind, Stroke of Luck, Pact Magic, Magical Cunning, Mystic
Arcanum L6–L9, Eldritch Master, Arcane Recovery, Font of Magic, Sorcerous Restoration,
Draconic Resilience, Dragon Wings, Dragon Companion, Dark One's Blessing, Dark One's Own Luck,
Fiendish Vigor (subclass), Hurl Through Hell, Mindless Rage, Nature's Ward, Improved Critical,
Superior Critical, Aura of Devotion, Fast Hands, and the 12 **Fiendish Resilience** damage-type
options (each typed `damage_resistance`).

**MECH (prose-only rule, empty/absent effects):** Reckless Attack (downside missing), Primal
Knowledge, Feral Instinct (STRUCT — dummy `initiative_bonus:0`), Instinctive Pounce, Brutal
Strike + Improved Brutal Strike, Relentless Rage, Persistent Rage, Indomitable Might; all nine
`*Spellcasting` feats (Bard/Cleric/Druid/Paladin/Ranger/Sorcerer/Warlock/Wizard — spell-list
access invisible to resolver); Font of Inspiration, Countercharm, Magical Secrets, Bardic
Inspiration d10/d12, Words of Creation, Superior Bardic Inspiration; Sear Undead, Greater
Divine Intervention, Divine Order: Thaumaturge rider; Primal Order: Magician rider, Wild
Companion, Wild Resurgence, Improved Elemental Fury, Beast Spells, Archdruid; Tactical Mind,
Tactical Shift, Studied Attacks; Martial Arts (STRUCT — core mechanic prose-only), Flurry of
Blows, Patient Defense, Step of the Wind, Deflect Attacks/Energy, Slow Fall, Stunning Strike,
Evasion (Monk), Perfect Focus, Superior Defense, **Body and Mind** (+4 DEX/+4 WIS with no
`ability_score_bonus`); **Aura of Protection** (signature +CHA-to-saves, no effects), Faithful
Steed, Restoring Touch, Aura Expansion, Innate Sorcery rider; Nature's Veil, Feral Senses, Foe
Slayer; Steady Aim, Cunning Strike + Improved Cunning Strike, Devious Strikes, Uncanny Dodge,
Evasion (Rogue), Reliable Talent, Elusive; Sorcery Incarnate, Arcane Apotheosis, Elemental
Affinity (resistance not typed), Draconic Presence; Eldritch Resilience, Ritual Adept, Memorize
Spell, Spell Mastery, Signature Spells; subclass features — Frenzy, Retaliation, Intimidating
Presence, **Bonus Proficiencies (Lore)** (no `proficiency_grant`), Cutting Words, Magical
Discoveries, Peerless Skill, Disciple of Life, Preserve Life, Blessed Healer, Supreme Healing,
Circle Spells, Land's Aid, Natural Recovery, Nature's Sanctuary, Remarkable Athlete, Additional
Fighting Style, Survivor, Open Hand Technique, Wholeness of Body, Fleet Step, Quivering Palm,
Sacred Weapon, Smite of Protection, Holy Nimbus (partial), Hunter gateways (Hunter's Lore/Prey,
Defensive Tactics, Multiattack, Superior Hunter's Defense, Hunter's Strategy), Supreme Sneak,
Use Magic Device, Thief's Reflexes, Second-Story Work (partial), Draconic Spells,
Draconic Presence, Evocation Savant, Potent Cantrip, Sculpt Spells, Empowered Evocation,
Overchannel.

**Feature-option picks with empty `effects` (clear resolver candidates unimplemented):**
Colossus Slayer, Horde Breaker, Escape the Horde, Multiattack Defense, **Steel Will**, Volley,
Whirlwind Attack, Evasion (Hunter), Stand Against the Tide, Uncanny Dodge (Hunter); Pact of the
Blade/Chain/Tome; Draconic Ancestor — Acid/Cold/Fire/Lightning/Poison; the 12 Eldritch
Invocations (Agonizing Blast, Armor of Shadows, Devil's Sight, **Eldritch Mind**, Eldritch
Sight, Eldritch Spear, Fiendish Vigor, Gaze of Two Minds, Mask of Many Faces, Misty Visions,
One with Shadows, Repelling Blast).

**STRUCT (prose, no typed payload):** the 10 **Metamagic** options (Careful, Distant,
Empowered, Extended, Heightened, Quickened, Seeking, Subtle, Transmuted, Twinned) — runtime
modifiers with zero structured cost/kind fields.

**Data hygiene:** name collision — "Fiendish Vigor" appears 3× (subclass feat + invocation);
"Evasion" / "Uncanny Dodge" exist as both class features and Hunter option feats.

## A.3 Backgrounds (`backgrounds.dart`, 16) — uniformly Clean

All carry typed `ability_score_options`, `asi_distribution_options`, `origin_feat_ref`,
`granted_skill_refs`, tool grant, `starting_gold_gp`/`gold_alternative_gp`, and
`equipment_choice_groups`; descriptions are pure flavor; SRD backgrounds have no prereqs.

Acolyte, Criminal, Sage, **Soldier** (correctly uses `granted_tool_variant_group:'gaming_set'`),
Artisan, Charlatan, Entertainer, Farmer, **Guard** (nit: generic `Gaming Set` ref vs Soldier's
variant group — cosmetic), Guide, Hermit, Merchant, Noble, Sailor, Scribe, Wayfarer — **Clean**.

## A.4 Species (`species.dart`, 9)

Physical chassis typed; active/passive traits referenced via prose-only `trait_refs` (no
`effects` key on the species rows).

- **Dragonborn**: physical chassis + action refs typed; MECH — Draconic Ancestry / Damage Resistance traits carry no effects (resistance is on subspecies, correct).
- **Dwarf**: poison resist + darkvision typed; MECH — Stonecunning, Dwarven Toughness, Forge Wise prose-only.
- **Elf**: darkvision typed; MECH — Fey Ancestry, Trance, Keen Senses prose-only.
- **Gnome**: chassis typed; MECH — Gnomish Cunning (advantage on INT/WIS/CHA saves) prose-only.
- **Goliath**: speed 35 typed; MECH — Powerful Build, Large Form, Giant Ancestry prose-only.
- **Halfling**: chassis typed; MECH — Halfling Lucky, Naturally Stealthy, Brave, Nimbleness prose-only.
- **Human**: chassis typed; MECH — Resourceful, Skilled (3 skills), Versatile (Origin feat) prose-only (most under-typed species).
- **Orc**: darkvision + Adrenaline Rush/Relentless Endurance typed (action/reaction refs); MECH — Powerful Build prose-only.
- **Tiefling**: darkvision typed (resist + spells on subspecies); MECH — Otherworldly Presence (Thaumaturgy) prose-only on base.

## A.5 Subspecies (`subspecies.dart`, 33) — strongest file, near-Clean

Most carry real typed `granted_modifiers` / `granted_damage_resistances` / `granted_cantrip_refs`
/ `granted_spells_at_level` / `granted_skill_proficiencies` / action refs.

- **10 Dragonborn colors**: Clean. · **Hill/Mountain Dwarf**: Clean. · **Drow**: Clean (120 ft sense + cantrip + leveled spells). · **Wood Elf**: Clean. · **6 Goliath giants** (Cloud/Fire/Frost/Hill/Stone/Storm): Clean (action refs). · **Lightfoot/Stout Halfling**: Clean. · **Standard Human**: Clean. · **Half-Orc**: Clean. · **Abyssal/Chthonic/Infernal Tiefling**: Clean.
- **High Elf**: MECH — leveled spells typed but the L1 "Wizard cantrip of choice" is prose-only.
- **Forest Gnome**: MECH — Minor Illusion typed; "Speak with Small Beasts" prose-only.
- **Rock Gnome**: MECH — Mending/Prestidigitation typed; Artificer's Lore + Tinker prose-only.

## A.6 Traits (`traits.dart`, ~270) — prose-only by architecture (STRUCT)

Every `_t(...)` row is `{source, trait_kind, description}` with the mechanic in free text; no
`effects`/`granted_*`. Acceptable for the ~210 monster-statblock display traits; it is the **root
cause** of the species MECH findings for the ~58 PC species/class trait rows (Dwarven Resilience,
Stonecunning, Forge Wise, Trance, Keen Senses, Gnomish Cunning, Brave, Resourceful, Skilled
(Human), Versatile (Human), Powerful Build, Large Form, Otherworldly Presence, Damage Resistance
(Dragonborn), Dwarven Toughness, …) which describe resolver-supported effects but type none.

## A.7 Classes (`classes.dart`, 12)

Typed *scaffolding* is consistent (primary ability, hit die, saving-throw refs, skill choices,
armor/weapon categories, caster kind, equipment, gold, multiclass prereq); **typed per-feature
mechanics are absent in all 12** (effects only read from feats).

- **Barbarian / Bard / Cleric / Druid / Monk / Paladin / Ranger / Rogue / Sorcerer / Warlock / Wizard / Fighter**: MECH — signature features (Rage, Bardic Inspiration scaling, Channel Divinity, Wild Shape, Martial Arts/Focus, Lay on Hands/**Aura of Protection**, Hunter's Mark, Sneak Attack scaling, Sorcery Points, Pact slots/Invocations, Arcane Recovery, Action Surge/Indomitable) are prose-only.
- **Fighter**: PREREQ — multiclass prereq lists STR+DEX but is evaluated as **AND** (should be OR per SRD); `multiclass_prereq_any_of` not set / not in schema. Other classes' multiclass prereqs are correct.
- STRUCT — empty-label placeholder rows: Bard L6/L13/L17, Warlock's four Mystic Arcanum rows, Paladin L20, Sorcerer "Metamagic (extra II)"; Monk feature list partly out of level order; Sorcerous Restoration mis-tagged with a generic `Spellcasting Focus` trait ref.

## A.8 Subclasses (`subclasses.dart`, 12)

All carry typed `parent_class_ref` + `granted_at_level:3` (Clean scaffolding); **zero typed
feature mechanics**.

- **Path of the Berserker / College of Lore / Life Domain / Circle of the Land / Champion / Warrior of the Open Hand / Oath of Devotion / Hunter / Thief / Draconic Sorcery / Fiend Patron / Evoker**: MECH — all features prose-only (Frenzy, Cutting Words, Preserve Life, Land's Aid, Improved/Superior Critical crit-range, Quivering Palm, Aura of Devotion, Draconic Resilience, Dark One's Blessing, Sculpt Spells, etc.).
- College of Lore uses typed `bonus_skill_pick_count:3` (good). · PREREQ/STRUCT — Hunter's four nested pick-one tiers and Draconic damage-type choice are prose "choose A/B/C" with no typed sub-choice field; domain/patron spell lists are prose, not typed always-prepared grants.

## A.9 Monsters (`monsters.dart`, 64) & Animals (`animals.dart`, 30)

Strongly typed: size/type/alignment refs, `ac`, `hp_average`+`hp_dice`, per-mode speeds,
`stat_block` (6 scores), `cr`, `xp`, `proficiency_bonus`, `passive_perception`, `senses[]`,
`language_refs`, damage resistance/immunity/vulnerability refs, condition-immunity refs,
`trait_refs`, action/bonus/legendary action refs (+uses), `telepathy_ft`.

- **All 64 monsters + 30 animals**: MECH (schema-level) — **no `saving_throws` field and no
  `skills` field exist**, so proficient saves/skills are unrepresentable (e.g. Aboleth CON/INT/WIS
  saves + History/Perception; Lich CON/INT/WIS saves + Arcana/History/Insight/Perception are
  lost). STRUCT — none: the `description` restates the attack line but every value is also in a
  typed field (redundant, not load-bearing). Caveat: monster spellcasting (e.g. Lich) is an
  opaque `trait_ref` with no typed spell list/slots/DC.
- Monster roster (sample): Aboleth, Goblin Warrior, Skeleton, Zombie, Adult Red/Black/Blue/Green/White Dragon, Lich, Beholder, Mind Flayer, Ogre, Owlbear, Hobgoblin, Bandit, Giant Spider, Kobold, Orc, Gnoll, Bugbear, Drow, Werewolf, Troll, Hydra, Vampire, Balor, Pit Fiend, 4 Elementals, Ghoul, Wight, Specter, Animated Armor, Stone/Hill Giant, Manticore, Minotaur, Basilisk, Cockatrice, Ettin, Harpy, Will-o'-Wisp, Mummy, Treant, Chuul, Otyugh, Roper, Nothic, Dryad, Gargoyle, Couatl, Sphinx, Death Dog, Knight, Veteran, Gladiator, Mage, Priest, Cult Fanatic, Spy, Assassin.

## A.10 Creature actions (`creature_actions.dart`, 137) — Clean

Typed `action_type`, `is_attack`, `attack_kind`, `attack_bonus`, `reach_ft`, range,
`damage_dice`, `damage_type_ref`, `save_dc`, `save_ability_ref`, `recharge_kind/min_roll`,
`uses_per_day`, `applied_condition_refs`. No prereqs. **Clean.**

## A.11 Equipment — Clean

- **weapons.dart (37)**: Clean — `damage_dice`, `damage_type_ref`, `property_refs` (Finesse/Heavy/Versatile…), `mastery_ref`, `versatile_damage_dice`, range fields, `category_ref`.
- **armor.dart (13)**: Clean — `base_ac`, `adds_dex`, `dex_cap`, **typed `strength_requirement`** (Plate/Splint 15, Chain Mail 13 — a requirement that *is* typed, not prose), typed `stealth_disadvantage` bool, don/doff, `category_ref`.
- **tools.dart (40)**: Clean — `category_ref`, `ability_ref`, `utilize_check_dc`, `craftable_items`, `variant_of_ref` (`utilize_description` legitimately holds prose alongside typed DC/ability).
- **gear.dart (~100)**: Clean — cost/weight/consumable/focus/utilize typed.
- **ammunition.dart (5) / mounts.dart (8) / vehicles.dart (13) / packs.dart (7)**: Clean — all stats typed.

---

# PART B — Official open5e first-party packs (19 packs, ~20,700 entities)

Each pack is `{package_name, metadata, entities(uuid-keyed)}`; entities have top-level
`name/type/...` + a typed `attributes` object. Chargen-relevant categories appear only in
**toh, a5e-ag/ddg/gpg, open5e, tdcs, vom, bfrd, deepm/deepmx/kp/wz/spells-that-dont-suck**; the
monster packs (tob*, ccdx, a5e-mm) carry only monster/trait/creature-action. Findings are
category-uniform within a pack.

## B.1 Pack inventory

| id | title | publisher / system | counts |
|---|---|---|---|
| open5e-a5e-ag | Adventurer's Guide | EN Publishing / a5e | spell 371, class 1, subclass 3, gear 44, background 21, feat 59 |
| open5e-a5e-ddg | Dungeon Delver's Guide | EN Publishing / a5e | gear 9, background 4 |
| open5e-a5e-gpg | Gate Pass Gazette | EN Publishing / a5e | gear 10, background 2 |
| open5e-a5e-mm | Monstrous Menagerie | EN Publishing / a5e | trait 829, creature-action 1657, monster 586 |
| open5e-bfrd | Black Flag SRD | Kobold Press / 5e-2014 | trait 776, creature-action 1339, monster 360, class 1, subclass 1 |
| open5e-ccdx | Creature Codex | Kobold Press / 5e-2014 | trait 921, creature-action 1148, monster 356 |
| open5e-deepm | Deep Magic 5e | Kobold Press / 5e-2014 | spell 515 |
| open5e-deepmx | Deep Magic Extended | Kobold Press / 5e-2014 | spell 64 |
| open5e-kp | Kobold Press Compilation | Kobold Press / 5e-2014 | spell 31 |
| open5e-open5e | Open5e Originals | Open5e / 5e-2014 | spell 2, subclass 17, subspecies 1, gear 8, background 2 |
| open5e-spells-that-dont-suck | Spells That Don't Suck | SoMany Robots / 5e-2014 | spell 180 |
| open5e-tdcs | Tal'dorei Campaign Setting | Green Ronin / 5e-2014 | trait 11, creature-action 10, monster 4, subclass 4, gear 13, background 5, feat 1 |
| open5e-tob | Tome of Beasts | Kobold Press / 5e-2014 | trait 1039, creature-action 1303, monster 391 |
| open5e-tob-2023 | Tome of Beasts 1 (2023) | Kobold Press / 5e-2014 | trait 1021, creature-action 1658, monster 408 |
| open5e-tob2 | Tome of Beasts 2 | Kobold Press / 5e-2014 | trait 1014, creature-action 1209, monster 383 |
| open5e-tob3 | Tome of Beasts 3 | Kobold Press / 5e-2014 | trait 812, creature-action 291, monster 397 |
| open5e-toh | Tome of Heroes | Kobold Press / 5e-2014 | spell 91, subclass 76, subspecies 29, species 11, gear 75, background 19, feat 13 |
| open5e-vom | Vault of Magic | Kobold Press / 5e-2014 | magic-item 1063 |
| open5e-wz | Warlock Zine | Kobold Press / 5e-2014 | spell 43 |

## B.2 Findings by category (with real coverage numbers & named examples)

### Feats (a5e-ag 59, toh 13, tdcs 1 = 73)
- PREREQ — single-valued `prereq_ability_ref`/`prereq_min_score` captures only **4/59** (a5e-ag) and **4/13** (toh); `prereq_clauses` present 15/59 and 7/13 but drops non-ability clauses. Fully untyped prereqs: **Giant Foe** ("A Small or smaller race"), **Harrier** ("Shadow Traveler trait or *misty step*"), **Stunning Sniper** ("Proficiency with a ranged weapon"), **Ace Driver** ("Proficiency with a type of vehicle"), **Well-Heeled** ("Prestige rating 2+"). Partial-drop: **Monster Hunter** (keeps level 8, drops "Proficiency with Survival"), **Boundless Reserves / Sorcerous Vigor** (drop "Ki/Sorcery Points feature"), **Rite Master** ("Intelligence or Wisdom 13" keeps only first ability).
- MECH — `effects` present only 9/59 (a5e-ag), 0/13 (toh), 0/1 (tdcs). · `category_ref` 59/59 (a5e-ag).

### Species (toh, 11)
- MECH/STRUCT — `creature_type_ref` 11/11; **`size_ref` 7/11**, `speed_ft` 8/11, `granted_languages` 10/11, `granted_modifiers` 9/11, `granted_skill_proficiencies` 5/11, `granted_damage_resistances` 4/11. Remaining trait mechanics in prose.

### Subspecies (toh 29, open5e 1 = 30)
- `parent_species_ref`/`creature_type_ref` 29/29; `granted_modifiers` 26/29; `speed_ft` 13/29; `granted_skill_proficiencies` 8/29; `granted_damage_resistances` 3/29. Partial.

### Backgrounds (a5e-ag 21, toh 19, tdcs 5, a5e-ddg 4, a5e-gpg 2, open5e 2 = 53)
- `granted_skill_refs` + `equipment_choice_groups` near-100%. PREREQ/STRUCT — `ability_score_options` 21/21 (a5e-ag), 4/4 (a5e-ddg) but **0/19 (toh)** and **0/5 (tdcs)** (5e-2014 packs). MECH — `granted_tool_refs`, `feature_name`, `effects` = **0 across every pack**: the named background feature is description-only.

### Subclasses (toh 76, open5e 17, tdcs 4, a5e-ag 3, bfrd 1 = 101)
- `parent_class_ref` near-100% — but **`effects` / `granted_modifiers` / `spellcasting` = 0/96** sampled: every subclass feature is pure prose (MECH/STRUCT).

### Classes (a5e-ag "Marshal", bfrd "Mechanist" = 2)
- Char-creation basics typed (`hit_die`, `saving_throw_refs`, `armor_training_refs`, `weapon_proficiency_categories`, skill choices) but **no typed leveled-features table** — a 14k–21k-char description holds all level features (MECH/STRUCT); `caster_kind:'None'`.

### Spells (deepm 515, a5e-ag 371, spells-that-dont-suck 180, toh 91, deepmx 64, wz 43, kp 31, open5e 2 ≈ 1,297)
- Well-typed headers — `school_ref`, `range_type`, `components` ~100%; `save_ability_ref` 59–94% where applicable; `range_ft` ~58–73%; `requires_concentration` correctly sparse. MECH/STRUCT — **`damage` / `effects` / `higher_level` = 0 everywhere**: damage dice, attack rolls, and at-higher-level scaling live only in prose; `level` itself missing for some (deepm 477/515, a5e-ag 342/371).

### Magic items (vom, 1063)
- `rarity_ref` 1063/1063; `requires_attunement` bool 452/1063. STRUCT — **`effects` is a verbatim copy of the description string** for all 1063 (`description == attributes.effects`), not typed effect rows. PREREQ — `attunement_requirement` **0/1063** (the "requires attunement by a …" clause is dropped from text entirely). MECH — `granted_modifiers` / `charges` / `is_cursed` = 0/1063.

### Monsters / traits / creature-actions (a5e-mm, bfrd, ccdx, tdcs, tob, tob-2023, tob2, tob3 — 2,885 monsters, 6,423 traits, 8,615 creature-actions)
- Same shape as the built-in monster content: combat stats typed; **no `saving_throws`/`skills` schema fields**; monster traits are prose `description` rows; spellcasting via opaque trait refs. STRUCT — acceptable for display traits; MECH — proficient saves/skills and typed spellcasting unrepresentable across all monster packs.

---

## Summary of the ledger

- **Clean / near-Clean:** all 16 built-in backgrounds; 33 built-in subspecies (3 partial);
  built-in creature-actions (137) and all equipment files; built-in spells' header metadata;
  many `_helpers`-typed feats and class-feat features (Rage, Sneak Attack, pools, Weapon Mastery,
  Extra Attack, resistances, etc.).
- **Dominant gap — MECH:** class/subclass/species feature mechanics are prose-only because the
  resolver folds `effects` from feats alone; magic-item and spell-damage mechanics are untyped;
  ~155 class-feat options and ~96 imported subclasses ship empty/absent `effects`.
- **PREREQ gaps:** unenforced spellcasting/proficiency/OR-ability/race/class-feature
  prerequisites; the Fighter multiclass AND-vs-OR correctness bug; unenforceable magic-item
  attunement restrictions.
- **STRUCT gaps:** Metamagic & invocation prose dumps, empty placeholder feature rows, magic-item
  `effects == description`, imported subclass/background/spell bodies funneled into `description`.
- **Schema omissions:** monster `saving_throws` / `skills` fields; typed spell damage/scaling;
  typed magic-item effect rows; `multiclass_prereq_any_of`.

See [`system_mechanics_roadmap.md`](system_mechanics_roadmap.md) for the consolidated remediation
plan and architecture changes.
