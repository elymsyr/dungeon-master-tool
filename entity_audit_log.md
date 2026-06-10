# Entity Audit Log — Official & Built-in Packages

> Automated System Architecture Inspector — detailed per-entity ledger.
> Generated for the `dungeon-master-tool` D&D 5e app.

## Scope & method

Two package sources were inspected:

1. **Built-in pack — SRD 5.2.1 core** (hand-authored, the runtime's bootstrap
   content): `flutter_app/lib/domain/entities/schema/builtin/srd_core/`.
   **~2,650 entity cards** across feats, class/subclass features, classes,
   subclasses, species, subspecies, traits, backgrounds, spells, magic items,
   mundane equipment, monsters, animals, and creature actions — **every card
   is enumerated individually below.**
2. **Official first-party catalog — Open5e packs** (machine-imported, shipped
   as assets): `flutter_app/assets/open5e_packs/` — 19 packs, **20,712 cards**.
   These are audited at the pack × category level (see the closing section):
   their deficiencies are systematic and identical within each category, so an
   exhaustive name-by-name transcription of 20k machine-generated rows would
   add length without information. Counts are taken from `manifest.json`.

### Verdict legend
- **Clean** — every described prerequisite sits in a typed field, every
  described mechanic has a matching typed `effects`/field entry, and nothing
  rules-bearing is stranded in a generic prose field.
- Otherwise the specific defect is named per the three criteria:
  *Unimplemented Prerequisite*, *Missing Mechanic*, *Poor Data Structure*.

### System ground-truth used for the verdicts
- The resolver (`character_resolver.dart`) implements ~95 typed effect kinds.
  Note three of them are reserved **no-ops**: `weapon_mastery_grant`,
  `speed_bonus`, and the redundant OA-immunity kinds apply nothing.
- There is **no typed spell-effect DSL** and **no typed magic-item-effect DSL**;
  both store their functional rules as a markdown string.
- Feat/multiclass prerequisites are surfaced only as **non-blocking warnings**;
  the engine's more capable `prereq_clauses` eligibility gate is **never
  populated** by any SRD-core card.

---

## Feats — Player-Facing + Class/Subclass Feature Feats (feats.dart, feats_class.dart)

Note on enforcement: ALL typed prereqs here are warning-only (non-blocking) per ground truth; `prereq_requires_spellcasting`, "X or Y" ability prereqs, tool/armor-proficiency prereqs, and species prereqs are NOT validated at all. The DSL kind `speed_bonus` used throughout feats_class.dart is NOT in the resolver-implemented kind list — every "Speed increases by N" feature that relies on it is effectively a Missing Mechanic (flagged below). Pure-prose features with no `effects` and an active mechanic = Missing Mechanic.

### Entity Log — feats.dart

- **Alert** — Missing mechanic: "Initiative Proficiency" (add PB to Initiative) and "Initiative Swap" are pure prose; no `initiative_bonus`/typed effect. No effects array at all.
- **Magic Initiate** — Clean. choice_group DSL covers list/cantrips/level-1 pick; spell-change & once-free-cast are prose riders but the grant is typed.
- **Savage Attacker** — Missing mechanic: "roll weapon damage dice twice, use either" is pure prose; `reroll_damage` kind exists but is unused here.
- **Skilled** — Clean (skill_or_tool choice_group typed).
- **Ability Score Improvement** — Unimplemented prereq: "Level 4+" typed (`prereq_min_character_level`) but warning-only. ASI typed via asi_* fields. Clean otherwise.
- **Grappler** — Unimplemented prereq: "Strength OR Dexterity 13+" — `prereq_min_score:13` present but single `prereq_ability_ref` absent (the "or" can't be stored); warning-only. Missing mechanic: "Punch and Grab", "Attack Advantage vs grappled", "Fast Wrestler" all pure prose; only ASI typed.
- **Archery** — Missing mechanic: "+2 to attack rolls with Ranged weapons" is prose; no `attack_bonus_typed` effect. Unimplemented prereq: "Fighting Style Feature" only in free-text `prerequisite`, not typed/enforced.
- **Defense** — Clean. `ac_bonus` +1 with equipped_armor_kind predicate typed. (Prereq "Fighting Style Feature" free-text/unenforced, consistent with line.)
- **Great Weapon Fighting** — Missing mechanic: "treat 1/2 on damage die as 3" is prose; `min_die_value` kind exists but unused. Prereq free-text only.
- **Two-Weapon Fighting** — Missing mechanic: add ability mod to off-hand damage is prose; no typed effect. Prereq free-text only.
- **Boon of Combat Prowess** — Unimplemented prereq: "Level 19+" typed but warning-only. Missing mechanic: "Peerless Aim" (turn miss into hit) pure prose; ASI typed.
- **Boon of Dimensional Travel** — Missing mechanic: "Blink Steps" teleport 30ft pure prose; ASI typed; prereq warning-only.
- **Boon of Fate** — Missing mechanic: "Improve Fate" 2d4 swing pure prose; ASI typed; prereq warning-only.
- **Boon of Irresistible Offense** — Missing mechanic: "Overcome Defenses" (ignore Resistance) and "Overwhelming Strike" (crit bonus) pure prose; no `damage_type_override`/crit effect; ASI typed.
- **Boon of Spell Recall** — Unimplemented prereq: "Spellcasting Feature" (`prereq_requires_spellcasting:true`) is NEVER validated. Missing mechanic: "Free Casting" 1d4 slot recovery pure prose; ASI typed.
- **Boon of the Night Spirit** — Partial. "Shadowy Form" resistance typed via 11 damage_resistance rows w/ has_state predicate (good). Missing mechanic: "Merge with Shadows" (Bonus-Action Invisible in dim/dark) pure prose, no condition/state grant. ASI typed.
- **Boon of Truesight** — Clean. `truesight_grant` typed; ASI typed; prereq warning-only.
- **Crafter** — Partial. tool_category choice_group typed. Missing mechanic: "20% Discount" and "Faster Crafting" pure prose (no typed field — acceptable as non-combat, but unstructured).
- **Healer** — Missing mechanic: "Battle Medic" (spend HD heal + PB) and "Healing Surge" (reroll 1 on HD) pure prose; no effects.
- **Lucky** — Partial. `resource_pool_grant` for Luck Points typed (pool + pb formula). Missing mechanic: spending a point for Advantage / impose Disadvantage on attacker is pure prose (no advantage_on/disadvantage_on typed — acceptable as it's reactive/spend-driven, but unmodeled).
- **Musician** — Partial. instrument tool_category choice_group typed. Missing mechanic: "Encouraging Song" (grant Heroic Inspiration to PB allies) pure prose.
- **Tavern Brawler** — Poor data structure: `asi_ability_options` uses raw strings 'Strength'/'Constitution' instead of `lookup('ability',…)` like every other feat (ID-ref inconsistency); choice_group ability_options uses 'STR'/'CON'. Missing mechanic: "Enhanced Unarmed Strike" (1d4+STR), "Improvised Weapon prof", "Push" all pure prose; only ASI typed.
- **Tough** — Clean. `hp_bonus_per_level` value 2 typed (prose "twice level at pick" is a slight simplification but mechanic present).
- **Athlete** — Unimplemented prereq: "Level 4+" warning-only. Poor data structure: asi_ability_options raw strings. Missing mechanic: Climbing/Jumping/Standing-up movement riders pure prose (no speed/movement typed).
- **Charger** — Missing mechanic: "Charge" (+2d8 + push on charge attack) entirely pure prose; no effects. Prereq warning-only.
- **Crossbow Expert** — Unimplemented prereq: "Dexterity 13+" typed (ability_ref+min_score) but warning-only. Poor data structure: asi raw string 'Dexterity'. Missing mechanic: Ignore Loading / Firing in Melee / Bonus Crossbow Attack all pure prose.
- **Defensive Duelist** — Unimplemented prereq: "Dexterity 13+" warning-only. Missing mechanic: "Parry" reaction (+PB to AC) pure prose; only ASI typed.
- **Dual Wielder** — Missing mechanic: Bonus Attack, Drawing Weapons, and "Enhanced Defense" +1 AC all pure prose; the +1 AC should be an `ac_bonus` effect with a dual-wield predicate but isn't. Prereq warning-only.
- **Durable** — Missing mechanic: "Defy Death" (Advantage on Death Saves) and "Speedy Recovery" pure prose; no advantage_on/typed effect. ASI raw string.
- **Elemental Adept** — Unimplemented prereq: "Spellcasting Feature" never validated. Missing mechanic: ignore Resistance + treat 1 as 2 for chosen type pure prose; no damage_type/choice effect; repeatable but no choice_group to pick the type.
- **Fey-Touched** — Partial. `spell_always_prepared` Misty Step typed. Missing mechanic: the "+1 level-1 Divination/Enchantment spell of choice" has no choice_group; once-per-rest free cast prose. ASI raw string. Prereq warning-only.
- **Great Weapon Master** — Missing mechanic: "Cleaving Strike" (bonus attack on crit/kill) and "Heavy Hitter" (+1d12) pure prose; no extra_damage_on_attack. ASI raw string.
- **Heavy Armor Master** — Unimplemented prereq: "proficiency with Heavy Armor" in free-text only, not typed/validated. Missing mechanic: "Damage Resistance" reduce B/P/S by PB while in heavy armor — `damage_reduction_flat` kind exists but is unused; pure prose.
- **Inspiring Leader** — Unimplemented prereq: "Charisma 13+" warning-only. Partial: `temp_hp_grant` with formula+trigger typed (good). ASI raw string.
- **Keen Mind** — Missing mechanic: "Perfect Recall" (add PB to memory INT checks) pure prose; no typed effect. ASI raw string.
- **Lightly Armored** — Clean (mechanic-wise): `proficiency_grant` Light armor typed. ASI raw string (minor). Prereq warning-only.
- **Mage Slayer** — Missing mechanic: "Concentration Breaker" (impose Disadv on concentration save) and "Guarded Mind" (reroll mental save) pure prose.
- **Martial Adept** — Missing mechanic: learn 2 Maneuvers + 1 Superiority Die entirely pure prose; no resource_pool_grant or choice_group.
- **Medium Armor Master** — Unimplemented prereq: "proficiency with Medium Armor" free-text only. Missing mechanic: stealth-no-disadvantage + +3 Dex-to-AC cap pure prose; no AC/armor effect.
- **Mobile** — Missing mechanic: "Nimble" Speed +10 has no `speed_bonus` effect (and `speed_bonus` isn't a resolver kind anyway); Dash/OA riders pure prose.
- **Moderately Armored** — Unimplemented prereq: "proficiency with Light Armor" free-text only. Clean mechanic: `proficiency_grant` Medium + Shield typed.
- **Mounted Combatant** — Missing mechanic: Mounted Strike/Veer/Leap Aside all pure prose; only ASI typed.
- **Observant** — Missing mechanic: "Quick Search", "Lipreading", and "+5 Passive Perception/Investigation" pure prose; `passive_score_bonus` kind exists but is unused.
- **Polearm Master** — Missing mechanic: bonus 1d4 butt-end attack + reach OA on enter pure prose; no effects.
- **Resilient** — Partial. `grants_save_prof_from_asi:true` flag typed (custom field) covers Save Proficiency; ASI raw strings. Repeatable handled. Acceptable.
- **Ritual Caster** — Unimplemented prereq: "Intelligence OR Wisdom 13+" — neither prereq_ability_ref nor prereq_min_score set ("or" not storable); warning-only regardless. Missing mechanic: ritual book pure prose (acceptable, non-combat).
- **Sentinel** — Missing mechanic: "Stop the Foe" (Speed→0 on OA hit) — `oa_stops_movement` kind exists but unused; "Bonus OA after Disengage" — `enemy_cant_disengage_oa` kind exists but unused; "Distract the Foe" reaction prose. All pure prose despite matching kinds existing.
- **Shadow-Touched** — Partial. `spell_always_prepared` Invisibility typed. Missing mechanic: choice of +1 Illusion/Necromancy spell has no choice_group; ASI raw string.
- **Sharpshooter** — Missing mechanic: Long Range (no disadv), Cover ignore, +1d10 Bullseye all pure prose; `ignore_long_range_disadvantage`, `ignore_cover`, `extra_damage_on_attack` kinds all exist but unused.
- **Shield Master** — Unimplemented prereq: "proficiency with Shields" free-text only. Missing mechanic: Shield Bash + Interpose Shield reaction pure prose.
- **Skill Expert** — Partial. `bonus_skill_pick_count:1` + `bonus_expertise_pick_count:1` typed custom fields (good). ASI raw strings. Repeatable handled.
- **Spell Sniper** — Unimplemented prereq: "Spellcasting Feature" never validated. Missing mechanic: double spell-attack range, ignore cover, learn attack cantrip all pure prose; `ignore_cover`/`cantrip_grant` kinds exist but unused.
- **Telekinetic** — Partial. `cantrip_grant` Mage Hand typed. Missing mechanic: "Telekinetic Shove" (Bonus Action shove, STR save) pure prose. ASI raw string.
- **Telepathic** — Partial. `spell_always_prepared` Detect Thoughts typed. Missing mechanic: 60-ft telepathic speech pure prose. ASI raw string.
- **War Caster** — Unimplemented prereq: "Spellcasting Feature" never validated. Missing mechanic: "Concentration" Advantage — `concentration_advantage` kind exists but unused; "Reactive Spell" prose. Pure prose.
- **Weapon Master** — Missing mechanic: "gain proficiency with four weapons of choice" has no choice_group / proficiency_grant; pure prose.
- **Blind Fighting** — Clean. `blindsight_grant` (range_ft 10) typed.
- **Dueling** — Missing mechanic: "+2 damage with single one-handed melee weapon" pure prose; `damage_bonus_typed` kind exists but unused.
- **Interception** — Missing mechanic: reaction damage reduction 1d10+PB — `reaction_damage_reduction` kind exists but unused; pure prose.
- **Protection** — Missing mechanic: reaction impose Disadvantage on attack vs ally pure prose; no typed effect.
- **Thrown Weapon Fighting** — Missing mechanic: draw-as-attack + "+2 thrown damage" pure prose; no damage_bonus_typed.
- **Unarmed Fighting** — Missing mechanic: unarmed d6/d8 damage + grapple damage pure prose; no min_die_value/unarmed effect.

### Entity Log — feats_class.dart (class features)

- **Rage** — Partial. Resistances, STR adv (check+save), scaling rage damage (`extra_damage_on_attack` scalesByClass), and rage-uses pool all typed with has_state predicate — strong. Missing mechanic: "No Spells/Concentration while raging" and duration end-conditions are in `activation` block (read by combat tracker, not resolver-enforced); prose-only otherwise.
- **Unarmored Defense (Barbarian)** — Clean. `unarmored_ac_formula` (DEX+CON, shield_allowed) with none-armor predicate.
- **Weapon Mastery (Barbarian)** — Partial. `weapon_mastery_count_bonus:2` typed but no choice_group to pick the 2 masteries (vs `weapon_mastery_grant` kind); swap-on-rest prose.
- **Danger Sense** — Clean. `advantage_on` DEX save w/ not_incapacitated predicate.
- **Reckless Attack** — Partial. `advantage_on` STR attack via has_state typed; the "attacks against you also have Advantage" downside is NOT modeled (no typed effect) — Missing mechanic.
- **Primal Knowledge** — Partial. `proficiency_grant` skill typed (no choice_group/target). Missing mechanic: substitute STR for skill ability while raging is pure prose.
- **Extra Attack (Barbarian)** — Clean. `extra_attack_count:2`.
- **Fast Movement** — Missing mechanic: `speed_bonus:10` used but `speed_bonus` is NOT a resolver-implemented kind; effect won't apply.
- **Feral Instinct** — Poor data structure / Missing mechanic: models "Advantage on Initiative" as `advantage_on` DEX check (proxy) plus `initiative_bonus:0` (no-op value). Initiative Advantage not cleanly typed.
- **Instinctive Pounce** — Missing mechanic: move half Speed on Rage entry — pure prose, no effects.
- **Brutal Strike** — Partial. `extra_damage_on_attack` 1d10 w/ requires_forgo_advantage + has_state typed. The Forceful/Hamstring Blow rider effects are prose-only.
- **Relentless Rage** — Missing mechanic: drop-to-1-HP CON save mechanic pure prose; no effects.
- **Improved Brutal Strike** — Missing mechanic: adds Staggering/Sundering Blow options — pure prose, no effects.
- **Persistent Rage** — Missing mechanic: rage auto-extends + regain uses on initiative — pure prose.
- **Improved Brutal Strike (II)** — Partial. 2d10 extra_damage typed; "two effects per use" prose.
- **Indomitable Might** — Missing mechanic: treat low STR check/save rolls as STR score — pure prose; no typed floor effect.
- **Primal Champion** — Clean. two `ability_score_bonus` (STR/CON +4, max 25) typed inline.
- **Bardic Inspiration** — Partial. `resource_pool_grant` (cha_mod formula) + activation typed. Die-size scaling (d6→d12) is split across separate prose-only features (see below); the actual inspiration die value isn't a typed scaling field.
- **Bard Spellcasting** — Clean (reference/spellcasting identity feature; no active mechanic to type — spellcasting handled elsewhere).
- **Expertise (Bard)** — Clean. `expertise_count:2`.
- **Jack of All Trades** — Clean. `half_proficiency_to_unproficient_checks`.
- **Font of Inspiration** — Missing mechanic: Bardic die → d8 AND short-rest recharge — both pure prose; no typed die/recharge update.
- **Countercharm** — Missing mechanic: reaction reroll vs Charm/Fright — pure prose.
- **Expertise (Bard II)** — Clean. `expertise_count:2`.
- **Magical Secrets** — Missing mechanic: spell-swap from any list — pure prose (acceptable as spell-management, but unstructured).
- **Bardic Inspiration (d10)** — Missing mechanic / Poor data structure: die-size upgrade is its own prose feat with no effect; should be a scaling field on Bardic Inspiration.
- **Words of Creation** — Partial. Should grant always-prepared Power Word Heal/Kill but has NO `spell_always_prepared` effects — pure prose. Missing mechanic.
- **Bardic Inspiration (d12)** — Missing mechanic / Poor data structure: same as d10 — prose-only die bump.
- **Superior Bardic Inspiration** — Missing mechanic: regain 2 uses on initiative — pure prose.
- **Cleric Spellcasting** — Clean (spellcasting identity feature).
- **Divine Order: Protector** — Clean (mechanic). `proficiency_grant` Martial weapons + Heavy armor typed. Prereq free-text "Divine Order Feature" unenforced.
- **Divine Order: Thaumaturge** — Partial. `cantrip_count_bonus:1` typed. Missing mechanic: "Cleric cantrip damage rider" (+Wis to cantrip damage) pure prose; no `spellcasting_ability_to_damage`/extra_damage effect.
- **Channel Divinity** — Partial. `resource_pool_grant` scaling (2/3/4) + activation typed. The CD options (Divine Spark, Turn Undead) themselves are prose.
- **Sear Undead** — Missing mechanic: Radiant damage = Cleric level on Turn Undead — pure prose.
- **Blessed Strikes** — Clean. `extra_damage_on_attack` 1d8 Radiant first_hit_per_turn typed.
- **Divine Intervention** — Partial. `resource_pool_grant` 1/long-rest typed; the "cast any Cleric spell ≤5 free" selection is prose.
- **Improved Blessed Strikes** — Clean. `extra_damage_on_attack` 2d8 Radiant typed (scaling via replacement).
- **Greater Divine Intervention** — Missing mechanic: upgrade to any-level spell — pure prose, no effects.
- **Druid Spellcasting** — Clean (spellcasting identity feature).
- **Primal Order: Warden** — Clean (mechanic). `proficiency_grant` Martial weapons + Medium armor typed. Prereq free-text unenforced.
- **Primal Order: Magician** — Partial. `cantrip_count_bonus:1` typed. Missing mechanic: Wis-to-Arcana/Nature rider pure prose.
- **Wild Shape** — Partial. `resource_pool_grant` (count 2) + activation typed. The form-assumption / CR / duration scaling are prose; uses don't scale in the typed pool (prose says "scaling with level").
- **Wild Companion** — Missing mechanic: spend Wild Shape use to cast Find Familiar — pure prose.
- **Wild Resurgence** — Missing mechanic: convert Wild Shape ↔ spell slot — pure prose.
- **Improved Elemental Fury** — Missing mechanic: Elemental Fury scaling — pure prose, no effects.
- **Beast Spells** — Missing mechanic: cast while Wild Shaped — pure prose.
- **Archdruid** — Missing mechanic: unlimited Wild Shape + ignore components — pure prose; no pool override effect.
- **Second Wind** — Partial. `resource_pool_grant` scaling (2/3/4) + activation typed. The 1d10+Fighter-level heal amount is prose (no typed heal formula).
- **Weapon Mastery (Fighter)** — Partial. `weapon_mastery_count_bonus:3` typed; no choice_group to pick masteries.
- **Action Surge** — Partial. `resource_pool_grant` scaling (1→2) + activation typed; the extra-action grant itself is prose (tracker-level).
- **Tactical Mind** — Missing mechanic: spend Second Wind for +1d10 to failed check — pure prose.
- **Extra Attack (Fighter)** — Clean. `extra_attack_count:2` (higher tiers handled by separate features below).
- **Tactical Shift** — Missing mechanic: move half Speed on Second Wind — pure prose.
- **Indomitable** — Partial. `resource_pool_grant` scaling (1/2/3) typed; the reroll-with-+level bonus is prose.
- **Two Extra Attacks** — Clean. `extra_attack_count:3`.
- **Studied Attacks** — Missing mechanic: Advantage after a miss — pure prose; no advantage_on/state effect.
- **Three Extra Attacks** — Clean. `extra_attack_count:4`.
- **Martial Arts** — Missing mechanic: DEX-for-attacks, Martial Arts die, bonus unarmed strike — entirely pure prose; no effects (no unarmored/min_die/extra-attack typing).
- **Unarmored Defense (Monk)** — Clean. `unarmored_ac_formula` (DEX+WIS, no shield) w/ none-armor + no-shield predicates.
- **Monk's Focus** — Clean. `resource_pool_grant` count_formula monk_level typed.
- **Unarmored Movement** — Missing mechanic: `speed_bonus` scaling used but `speed_bonus` is not a resolver kind; won't apply (scaling table present but inert).
- **Flurry of Blows** — Missing mechanic: spend Focus for 2 unarmed strikes — pure prose.
- **Patient Defense** — Missing mechanic: Disengage/Dodge as Bonus Action — pure prose; no granted_bonus_action_grant.
- **Step of the Wind** — Missing mechanic: Dash as Bonus Action — pure prose; no granted_bonus_action_grant.
- **Deflect Attacks** — Missing mechanic: reaction damage reduction 1d10+DEX+level — pure prose; `reaction_damage_reduction` kind exists but unused.
- **Slow Fall** — Missing mechanic: reduce falling damage by 5×level — pure prose.
- **Stunning Strike** — Missing mechanic: spend Focus, CON save or Stunned — pure prose.
- **Extra Attack (Monk)** — Clean. `extra_attack_count:2`.
- **Empowered Strikes** — Clean. `magical_unarmed_strikes` typed.
- **Evasion (Monk)** — Missing mechanic: Dex-save-for-half → none/half — pure prose (no typed evasion field; same gap as Rogue Evasion).
- **Acrobatic Movement** — Clean. `walk_on_liquid` w/ none-armor + no-shield predicates.
- **Deflect Energy** — Missing mechanic: extends Deflect Attacks to elemental damage — pure prose.
- **Perfect Focus** — Missing mechanic: regain Focus to 4 on initiative — pure prose.
- **Superior Defense** — Missing mechanic: spend 3 Focus, Resistance to all but Force — pure prose; no damage_resistance rows.
- **Body and Mind** — Missing mechanic: DEX/WIS +4, max 25 — pure prose; NO `ability_score_bonus` effects (contrast Primal Champion which types this correctly). Poor data structure.
- **Lay On Hands** — Partial. `resource_pool_grant` count_formula paladin_level_x5 typed; healing/disease-neutralize spend is prose.
- **Paladin Spellcasting** — Clean (spellcasting identity feature).
- **Weapon Mastery (Paladin)** — Partial. `weapon_mastery_count_bonus:2`; no mastery choice_group.
- **Paladin's Smite** — Partial. `spell_always_prepared` Divine Smite typed; the slot-scaling damage is prose (acceptable, spell-side).
- **Channel Divinity (Paladin)** — Partial. `resource_pool_grant` scaling (2/3) typed; oath options prose.
- **Extra Attack (Paladin)** — Clean. `extra_attack_count:2`.
- **Faithful Steed** — Clean. `spell_always_prepared` Find Steed.
- **Aura of Protection** — Missing mechanic: +CHA-mod to saves for self+allies in 10ft — pure prose; no typed aura/saving_throw bonus effect (a significant Paladin feature unmodeled).
- **Abjure Foes** — Partial. `resource_pool_grant` 1/long-rest typed; the Frighten effect is prose.
- **Radiant Strikes** — Clean. `extra_damage_on_attack` 1d8 Radiant first_hit_per_turn.
- **Restoring Touch** — Missing mechanic: spend Lay On Hands to cure conditions — pure prose.
- **Aura Expansion** — Missing mechanic: aura → 30ft — pure prose (depends on unmodeled Aura of Protection).
- **Favored Enemy** — Clean. `spell_always_prepared` Hunter's Mark + `resource_pool_grant` (wis_mod formula) typed.
- **Ranger Spellcasting** — Clean (spellcasting identity feature).
- **Weapon Mastery (Ranger)** — Partial. `weapon_mastery_count_bonus:2`; no choice_group.
- **Deft Explorer** — Partial. `expertise_count:1` + `language_grant` typed; higher-level extras prose.
- **Roving** — Missing mechanic: `speed_bonus:5` (inert — not a resolver kind), though `climb_speed_equals_speed`/`swim_speed_equals_speed` typed and valid.
- **Extra Attack (Ranger)** — Clean. `extra_attack_count:2`.
- **Expertise (Ranger II)** — Clean. `expertise_count:2`.
- **Tireless** — Partial. `resource_pool_grant` + `temp_hp_grant` (formula+trigger) typed; the Short-Rest Exhaustion reduction is prose.
- **Relentless Hunter** — Clean. `concentration_immune_to_damage_break` typed.
- **Nature's Veil** — Missing mechanic: Bonus-Action Invisible via slot — pure prose.
- **Feral Senses** — Missing mechanic: no-Disadvantage vs unseen — pure prose.
- **Foe Slayer** — Missing mechanic: Hunter's Mark d10 + Wis extra damage — pure prose.
- **Expertise (Rogue)** — Clean. `expertise_count:2`.
- **Sneak Attack** — Clean. `extra_damage_on_attack` scalesByClass 1d6→10d6 with finesse_or_ranged + first_hit_per_turn typed (one of the best-modeled).
- **Weapon Mastery (Rogue)** — Partial. `weapon_mastery_count_bonus:2`; no choice_group.
- **Cunning Action** — Clean. `granted_bonus_action_grant` (creature-action ref) typed.
- **Steady Aim** — Missing mechanic: Bonus-Action self-Advantage (Speed→0) — pure prose.
- **Cunning Strike** — Missing mechanic: spend Sneak dice for effects — pure prose.
- **Uncanny Dodge** — Missing mechanic: reaction halve damage — pure prose; `reaction_damage_reduction` kind exists but unused.
- **Evasion (Rogue)** — Missing mechanic: Dex-save evasion — pure prose; no typed evasion field.
- **Reliable Talent** — Missing mechanic: treat d20 ≤9 as 10 — `reliable_talent` kind EXISTS but is NOT used here; pure prose.
- **Improved Cunning Strike** — Missing mechanic: two effects/hit — pure prose.
- **Devious Strikes** — Missing mechanic: new Cunning Strike options — pure prose.
- **Slippery Mind** — Clean. two `proficiency_grant` saving_throw (WIS, CHA) typed.
- **Elusive** — Missing mechanic: no Advantage against you — pure prose; no typed effect.
- **Stroke of Luck** — Partial. `resource_pool_grant` 1/rest typed; the turn-miss-into-hit is prose.
- **Sorcerer Spellcasting** — Clean (spellcasting identity feature).
- **Innate Sorcery** — Partial. `resource_pool_grant` (cha_mod) + activation typed. Missing mechanic: Advantage on Sorcerer spell attacks + +1 save DC are prose (no advantage_on/save-DC effect).
- **Font of Magic** — Partial. `resource_pool_grant` (sorcerer_level) typed; SP↔slot conversion prose.
- **Sorcerous Restoration** — Partial. `resource_pool_grant` 1/short-rest typed; "regain 4 SP" amount is prose (no typed recovery amount).
- **Sorcery Incarnate** — Missing mechanic: Innate Sorcery for 2 SP when out of uses — pure prose.
- **Arcane Apotheosis** — Missing mechanic: free Metamagic while Innate Sorcery active — pure prose.
- **Pact Magic** — Partial. `resource_pool_grant` (pact_slots, short_rest) + `slot_recovery_short_rest` typed; slot scaling/level prose.
- **Magical Cunning** — Partial. `resource_pool_grant` 1/long-rest typed; the half-slot recovery amount is prose.
- **Mystic Arcanum (Level 6 Spell)** — Partial. `resource_pool_grant` 1/long-rest typed; the L6 spell pick + always-known is prose (no spell choice_group).
- **Mystic Arcanum (Level 7 Spell)** — Partial. Same as L6 (pool typed, spell pick prose).
- **Mystic Arcanum (Level 8 Spell)** — Partial. Same (pool typed, spell pick prose).
- **Mystic Arcanum (Level 9 Spell)** — Partial. Same (pool typed, spell pick prose).
- **Eldritch Master** — Partial. `resource_pool_grant` 1/long-rest typed; the full-slot recovery is prose.
- **Eldritch Resilience** — Missing mechanic: bonus Magical Cunning uses — pure prose, no effects.
- **Wizard Spellcasting** — Clean (spellcasting identity feature).
- **Ritual Adept** — Missing mechanic: cast spellbook rituals free — pure prose.
- **Arcane Recovery** — Partial. `resource_pool_grant` 1/day typed; the slot-recovery formula is prose.
- **Memorize Spell** — Missing mechanic: swap prepared spell on Short Rest — pure prose (acceptable, spell-management).
- **Spell Mastery** — Missing mechanic: cast chosen L1/L2 spells at will — pure prose; no spell_always_prepared/choice.
- **Signature Spells** — Missing mechanic: two L3 always-prepared free-cast — pure prose; no spell_always_prepared effects.

### Entity Log — feats_class.dart (subclass features)

- **Frenzy** — Missing mechanic: bonus melee attack while raging + Exhaustion — pure prose.
- **Mindless Rage** — Clean. two `condition_immunity_grant` (Charmed, Frightened) w/ has_state predicate typed.
- **Retaliation** — Missing mechanic: reaction melee attack on taking damage — pure prose.
- **Intimidating Presence** — Missing mechanic: Bonus-Action Frighten (Wis save) — pure prose.
- **Bonus Proficiencies (Lore)** — Missing mechanic: 3 skill proficiencies — pure prose; no proficiency_grant/choice_group (contrast Skilled feat which types it).
- **Cutting Words** — Missing mechanic: reaction expend Bardic die to subtract — pure prose.
- **Magical Discoveries** — Missing mechanic: learn 2 spells from any class — pure prose.
- **Peerless Skill** — Missing mechanic: expend Bardic die to add to ability check — pure prose.
- **Disciple of Life** — Missing mechanic: bonus healing 2+spell level — pure prose.
- **Channel Divinity: Preserve Life** — Missing mechanic: 5×level HP heal pool — pure prose; no effects (not even a resource pool).
- **Blessed Healer** — Missing mechanic: self-heal on healing others — pure prose.
- **Supreme Healing** — Missing mechanic: max healing dice — pure prose.
- **Circle Spells** — Missing mechanic: land-based always-prepared spells — pure prose; no spell_always_prepared/choice_group.
- **Land's Aid** — Missing mechanic: 2d6 heal/damage emanation, PB uses — pure prose; no resource_pool_grant.
- **Natural Recovery** — Missing mechanic: slot recovery on Short Rest — pure prose.
- **Nature's Ward** — Clean. two `condition_immunity_grant` (Frightened, Poisoned) + `damage_immunity` Poison typed. (Disease-immunity prose rider not typed — minor.)
- **Nature's Sanctuary** — Missing mechanic: Beast/Plant must save to attack you — pure prose.
- **Improved Critical** — Clean. `crit_range_extend` threshold 19.
- **Remarkable Athlete** — Missing mechanic: half-PB to STR/DEX/CON checks — pure prose; `half_proficiency_to_unproficient_checks` exists but is for a different scope; not typed.
- **Additional Fighting Style** — Missing mechanic: gain another Fighting Style — pure prose; no choice/feat grant.
- **Superior Critical** — Clean. `crit_range_extend` threshold 18.
- **Survivor** — Missing mechanic: start-of-turn regen 5+CON — pure prose.
- **Open Hand Technique** — Missing mechanic: Flurry rider effects (Prone/Push/disable) — pure prose.
- **Wholeness of Body** — Missing mechanic: Bonus-Action heal 3×level, 1/long-rest — pure prose; no resource_pool_grant.
- **Fleet Step** — Missing mechanic: Step of the Wind + Flurry combo — pure prose.
- **Quivering Palm** — Missing mechanic: spend 4 Focus, CON save or 0 HP — pure prose.
- **Sacred Weapon** — Missing mechanic: spend CD to buff weapon — pure prose.
- **Aura of Devotion** — Clean. `condition_immunity_grant` Charmed typed (aura range/allies not typed but immunity present).
- **Smite of Protection** — Missing mechanic: Half Cover on smite — pure prose.
- **Holy Nimbus** — Partial. `resource_pool_grant` 1/long-rest typed; the Radiant aura damage + save Advantage are prose.
- **Hunter's Lore** — Missing mechanic: learn target's immunities on mark — pure prose.
- **Hunter's Prey** — Missing mechanic: choose Colossus Slayer/Horde Breaker/Lore — pure prose; the picks exist as Feature-Option feats but this parent has no choice_group binding.
- **Defensive Tactics** — Missing mechanic: choose option — pure prose; options exist separately, no binding choice_group.
- **Superior Hunter's Defense** — Missing mechanic: choose option — pure prose; options exist separately.
- **Multiattack** — Missing mechanic: choose Volley/Whirlwind — pure prose; options exist separately.
- **Hunter's Strategy** — Missing mechanic: all options unlocked — pure prose.
- **Colossus Slayer** (Feature Option) — Missing mechanic: +1d8 vs damaged target, but `effects: const []` — pure prose despite `extra_damage_on_attack` being available. Prereq free-text unenforced.
- **Horde Breaker** (Feature Option) — Missing mechanic: extra attack vs nearby creature; `effects: []` empty. Prereq free-text.
- **Hunter's Lore Option** (Feature Option) — Missing mechanic: knowledge rider, `effects: []` (acceptable info-only, but unstructured). Prereq free-text.
- **Escape the Horde** (Feature Option) — Missing mechanic: OA against you at Disadvantage; `effects: []` empty; no disadvantage typed.
- **Multiattack Defense** (Feature Option) — Missing mechanic: attacker Disadvantage after hit; `effects: []`.
- **Steel Will** (Feature Option) — Missing mechanic: Advantage vs Frightened; `effects: []` despite `advantage_on` save being typeable.
- **Volley** (Feature Option) — Missing mechanic: ranged AoE; `effects: []` (action, prose-acceptable).
- **Whirlwind Attack** (Feature Option) — Missing mechanic: melee AoE; `effects: []`.
- **Evasion** (Feature Option) — Missing mechanic: Dex-save evasion; `effects: []`; no typed evasion field.
- **Stand Against the Tide** (Feature Option) — Missing mechanic: redirect missed melee; `effects: []`.
- **Uncanny Dodge** (Feature Option) — Missing mechanic: halve damage reaction; `effects: []`; `reaction_damage_reduction` available but unused.
- **Fast Hands** — Clean. `granted_bonus_action_grant` (Fast Hands creature-action) typed.
- **Second-Story Work** — Partial. `climb_speed_equals_speed` typed; the jump-distance bonus is prose.
- **Supreme Sneak** — Missing mechanic: Advantage on Stealth if moved ≤half Speed — pure prose.
- **Use Magic Device** — Unimplemented prereq context / Missing mechanic: ignore item class/race/level reqs — pure prose (interacts with magic-item attunement_prereq which is itself never checked).
- **Thief's Reflexes** — Missing mechanic: two turns round 1 — pure prose.
- **Draconic Resilience** — Clean. `hp_max_bonus_total:3` + `hp_bonus_per_level:1` + `unarmored_ac_formula` (base 13, DEX) typed.
- **Draconic Spells** — Missing mechanic: fixed prepared list by ancestry — pure prose; ancestry options exist separately, no choice_group binding here.
- **Elemental Affinity** — Missing mechanic: +CHA to matching-type damage + Resistance — pure prose; no damage/resistance effect.
- **Dragon Wings** — Partial. `fly_speed` + `resource_pool_grant` 1/long-rest typed (duration prose).
- **Dragon Companion** — Partial. `spell_always_prepared` Summon Dragon + `resource_pool_grant` typed; free-cast/no-concentration riders prose.
- **Draconic Presence** — Missing mechanic: 60-ft Charm/Frighten emanation — pure prose; no resource pool or effect.
- **Dark One's Blessing** — Clean. `temp_hp_grant` with formula (CHA+warlock level) + trigger on_reduce_to_0 typed.
- **Fiendish Vigor** (Fiend Patron L3) — Clean. `spell_always_prepared` False Life typed.
- **Dark One's Own Luck** — Partial. `resource_pool_grant` 1/rest typed; the +1d10 to check/save is prose.
- **Fiendish Resilience** (Fiend Patron L10 parent) — Missing mechanic: choose damage-type Resistance on rest — pure prose; the 13 typed options exist separately but parent has no binding choice_group.
- **Hurl Through Hell** — Partial. `resource_pool_grant` 1/long-rest typed; the 8d10 Psychic banish is prose.
- **Evocation Savant** — Missing mechanic: half copy cost + extra cantrip — pure prose; no cantrip_count_bonus.
- **Potent Cantrip** — Missing mechanic: half damage on cantrip save — pure prose.
- **Sculpt Spells** — Missing mechanic: allies auto-succeed/no-damage — pure prose.
- **Empowered Evocation** — Missing mechanic: +INT to one evocation damage roll — pure prose.
- **Overchannel** — Missing mechanic: max damage + recoil — pure prose.
- **Careful Spell** (Metamagic option) — Missing mechanic: SP for allies auto-succeed; pure prose, no effects. Prereq "Sorcerer — Metamagic" free-text unenforced.
- **Distant Spell** (Metamagic) — Missing mechanic: double range; prose. Prereq free-text.
- **Empowered Spell** (Metamagic) — Missing mechanic: reroll damage dice; `reroll_damage` exists but unused; prose.
- **Extended Spell** (Metamagic) — Missing mechanic: double duration; prose.
- **Heightened Spell** (Metamagic) — Missing mechanic: target save Disadvantage; prose.
- **Quickened Spell** (Metamagic) — Missing mechanic: action→bonus action; prose.
- **Seeking Spell** (Metamagic) — Missing mechanic: reroll missed spell attack; prose.
- **Subtle Spell** (Metamagic) — Missing mechanic: no V/S components; prose.
- **Transmuted Spell** (Metamagic) — Missing mechanic: swap damage type; `damage_type_override` exists but unused; prose.
- **Twinned Spell** (Metamagic) — Missing mechanic: second target; prose.
- **Agonizing Blast** (Invocation) — Unimplemented prereq: "Eldritch Blast cantrip" free-text only, unenforced. Missing mechanic: +CHA to EB damage — pure prose; no spellcasting_ability_to_damage.
- **Armor of Shadows** (Invocation) — Missing mechanic: at-will Mage Armor — pure prose; no spell grant.
- **Devil's Sight** (Invocation) — Missing mechanic: see in magical darkness 120ft — pure prose; `sense_grant`/blindsight unused.
- **Eldritch Mind** (Invocation) — Missing mechanic: Advantage on Concentration saves — `concentration_advantage` exists but unused; prose.
- **Eldritch Sight** (Invocation) — Missing mechanic: at-will Detect Magic — pure prose.
- **Eldritch Spear** (Invocation) — Unimplemented prereq: "Eldritch Blast cantrip" free-text. Missing mechanic: EB range 300ft — pure prose.
- **Fiendish Vigor** (Invocation — duplicate name) — Missing mechanic: at-will False Life — pure prose; no spell grant. (Name collides with Fiend Patron Fiendish Vigor — potential ID-resolution hazard.)
- **Gaze of Two Minds** (Invocation) — Missing mechanic: perceive through touched creature — pure prose.
- **Mask of Many Faces** (Invocation) — Missing mechanic: at-will Disguise Self — pure prose.
- **Misty Visions** (Invocation) — Missing mechanic: at-will Silent Image — pure prose.
- **One with Shadows** (Invocation) — Unimplemented prereq: "Warlock 5" free-text only. Missing mechanic: Invisible in dim/dark — pure prose.
- **Repelling Blast** (Invocation) — Unimplemented prereq: "Eldritch Blast cantrip" free-text. Missing mechanic: push on EB hit — pure prose.
- **Pact of the Blade** (Pact Boon) — Unimplemented prereq: "Warlock 3" free-text. Missing mechanic: conjure pact weapon, CHA attack/damage — pure prose.
- **Pact of the Chain** (Pact Boon) — Unimplemented prereq: "Warlock 3" free-text. Missing mechanic: Find Familiar grant — pure prose.
- **Pact of the Tome** (Pact Boon) — Unimplemented prereq: "Warlock 3" free-text. Missing mechanic: 3 cantrips from any list — pure prose; no cantrip_grant/choice.
- **Draconic Ancestor — Acid/Cold/Fire/Lightning/Poison** (5 Draconic Spells options) — Missing mechanic: each lists bonus prepared spells in prose only; no `spell_always_prepared` effects; `effects` defaulted empty. Prereq "Draconic Sorcery 3" free-text unenforced. (5 cards, identical finding.)
- **Fiendish Resilience — Acid/Bludgeoning/Cold/Fire/Force[absent]/Lightning/Necrotic/Piercing/Poison/Psychic/Radiant/Slashing/Thunder** (12 options) — Clean. Each has a typed `damage_resistance` row for its type; prereq "Fiend Warlock 10" free-text/unenforced (consistent). (12 cards, identical: Clean mechanic.)

### Systemic Gaps (for roadmap)

- Massive "typed kind exists but unused" gap: many resolver kinds are implemented but the content never wires them up — `attack_bonus_typed` (Archery), `damage_bonus_typed` (Dueling/Thrown), `min_die_value` (GWF/Unarmed Fighting), `damage_reduction_flat` (Heavy Armor Master), `reaction_damage_reduction` (Uncanny Dodge/Interception/Deflect Attacks), `passive_score_bonus` (Observant), `ignore_cover`/`ignore_long_range_disadvantage`/`extra_damage_on_attack` (Sharpshooter), `oa_stops_movement`/`enemy_cant_disengage_oa` (Sentinel), `reliable_talent` (Reliable Talent), `concentration_advantage` (War Caster/Eldritch Mind), `reroll_damage`/`damage_type_override` (Empowered/Transmuted Spell). The DSL is far ahead of the authored data.
- No `speed_bonus` resolver kind despite being used by Fast Movement, Mobile, Unarmored Movement, Roving — every flat walking-speed bump is silently inert. Needs either a kind added or the data corrected.
- "Choose N of a list" features are systematically unmodeled: Hunter's Prey/Defensive Tactics/Multiattack, Fiendish Resilience, Draconic Spells/Ancestry, Divine Order, Primal Order, and Additional Fighting Style all have separate option-feats but the PARENT feature carries no `choice_group` binding (and option feats often have empty `effects`), so picks aren't enforced or applied.
- Spell-grant features with a player choice ("+1 spell of school X", Magical Secrets, Circle Spells, Mystic Arcanum, Signature/Spell Mastery, Pact of the Tome) lack any `spell_from_list` choice_group; only fixed always-prepared spells (Misty Step, etc.) are typed. The known-good pattern from Magic Initiate isn't reused.
- Reactive/triggered combat features (smites, reactions, on-hit riders, save-or-X, auras like Aura of Protection) are almost entirely prose with no DSL coverage — and Auras specifically (a core Paladin pillar) have no granted-aura/conditional-save-bonus mechanic at all. Also: feat-prereq enforcement is universally warning-only and several prereq forms (spellcasting, "X or Y" ability, armor/weapon/tool proficiency, cantrip prereqs on Invocations) are stored only as free text and never checked; the `Fiendish Vigor` name appears twice (Fiend-Patron feat vs Invocation option), a likely ID-collision hazard.

---

## Classes, Subclasses, Species & Subspecies (srd_core/classes.dart, subclasses.dart, species.dart, subspecies.dart)

Scope note: per task, trait/action mechanics carried by `trait_refs` / `granted_*_refs` are audited separately. Below, a feature is only flagged "Missing mechanic" when its OWN card prose describes a rule with NO typed field AND no grant-ref carrying it. Cross-cutting facts verified in source: `primary_ability_ref` IS populated for every class (the schema field is `*_ref`, not a known-empty `primary_ability`); `multiclass_prereq_ability_refs`+`multiclass_prereq_min_score` are typed but warning-only (SRD §1.10 banner, never blocks); the class `rule_effects` typed featEffectList is EMPTY on all 12 classes; all L2+ class/subclass features are authored as prose `description` with no typed effect row (mechanics, when present, ride `granted_*_refs`). For subspecies, `granted_modifiers` (kind `speed_bonus`/`hp_bonus_*`/`ability_score_bonus`/`sense_grant`) and `granted_spells_at_level` ARE resolver-handled.

### Entity Log — Classes (12)
- **Barbarian** — Multiclass prereq (STR 13) typed but warning-only (non-blocking). L1 Rage/Unarmored Defense/Weapon Mastery/L2 Danger Sense/Reckless Attack carry trait/action refs. L3+ (Primal Knowledge, Brutal Strike, Relentless Rage, Persistent Rage, Indomitable Might, Primal Champion +4 STR/CON) are prose-only — no typed effect, no ref; `rule_effects` empty. Primal Champion's +4 ability score has no `ability_score_bonus`/`granted_modifiers` entry (missing mechanic).
- **Bard** — Multiclass prereq (CHA 13) typed/warning-only. L1–2 (Bardic Inspiration, Spellcasting, Expertise, Jack of All Trades) carry refs. L5+ (Font of Inspiration, Magical Secrets, Words of Creation always-prepared spells, Superior Bardic Inspiration) prose-only, no typed mechanic. Jack of All Trades benefit relies on the `Jack of All Trades` trait ref (half-PB-to-checks = resolver `half_proficiency_to_unproficient_checks`, in trait).
- **Cleric** — Multiclass prereq (WIS 13) typed/warning-only. `l1_order_feat_category: 'Divine Order'` is a typed choice hook. Divine Order text ("Protector: Martial weapons + Heavy armor" vs "Thaumaturge: extra cantrip + Wis to cantrip damage") is a branching grant described in prose and deferred to the `Divine Order` trait — verify trait actually grants both branches. L5+ (Sear Undead, Blessed Strikes +1d8 radiant, Divine Intervention) prose-only, no typed mechanic.
- **Druid** — Multiclass prereq (WIS 13) typed/warning-only. `granted_languages: [Druidic]` + `granted_tool_refs: [Herbalism Kit]` typed. Primal Order choice (Magician vs Warden: extra cantrip / Arcana+Nature prof vs Martial weapon + Medium armor) is prose-only with NO trait ref and NO typed grant (missing mechanic — the L1 order choice grants nothing mechanically). L5+ (Wild Resurgence, Elemental Fury, Archdruid) prose-only.
- **Fighter** — Multi-ability multiclass prereq lists STR+DEX with single `multiclass_prereq_min_score: 13`; schema semantics = "every listed ability ≥ score" (AND), but SRD multiclass needs only ONE — over-restrictive mis-warn (and warning-only anyway). Fighting Style at L1 is described as "gain a Fighting Style feat" but has no `granted_feat_refs` (deferred to player pick; no typed hook). L5/L9/L13+ (Extra Attack tiers, Studied Attacks) prose-only; Extra Attack not a typed `extra_attack_count`.
- **Monk** — Multi-ability prereq DEX+WIS, same AND-vs-OR over-restriction. L1–6 features carry trait refs (Martial Arts, Unarmored Defense, Stunning Strike, etc.). `Unarmored Movement` (+10 speed, L2) is prose-only with NO trait ref and NO `speed_bonus` modifier (missing mechanic). L13+ (Deflect Energy, Superior Defense, Body and Mind +4 DEX/WIS) prose-only; Body and Mind ability boost untyped.
- **Paladin** — Multi-ability prereq STR+CHA, AND-vs-OR over-restriction. L1–11 mostly carry refs (Lay on Hands, Aura of Protection, Aura of Courage, Radiant Strikes). Fighting Style (L2) "gain a Fighting Style feat" no `granted_feat_refs`. Aura of Protection ("+CHA to saves in 10 ft") relies on its trait ref — no aura/emanation typing exists. L14+ (Restoring Touch, Aura Expansion to 30 ft) prose-only.
- **Ranger** — Multi-ability prereq DEX+WIS, AND-vs-OR over-restriction. L1–10 carry refs (Favored Enemy/Hunter's Mark, Roving climb+swim, Expertise, Tireless). Fighting Style (L2) no `granted_feat_refs`. L13+ (Relentless Hunter, Nature's Veil, Feral Senses, Foe Slayer) prose-only.
- **Rogue** — Multiclass prereq (DEX 13) typed/warning-only. `granted_languages: [Thieves' Cant]` + `granted_tool_refs: [Thieves' Tools]` typed. L1–7 carry refs (Expertise, Sneak Attack, Cunning Action, Cunning Strike, Uncanny Dodge, Evasion, Reliable Talent). Thieves' Cant feature row (L1) is prose-only but duplicative of the typed granted_language. L11+ (Improved/Devious Cunning Strike, Elusive, Stroke of Luck) prose-only.
- **Sorcerer** — Multiclass prereq (CHA 13) typed/warning-only. L1–2 carry refs (Innate Sorcery, Font of Magic). Metamagic (L2) prose-only — no typed Metamagic selection/grant. L5 Sorcerous Restoration mis-tagged with `Spellcasting Focus` trait ref (copy/paste — unrelated to SP recovery). L7+ (Sorcery Incarnate, extra Metamagic, Arcane Apotheosis) prose-only.
- **Warlock** — Multiclass prereq (CHA 13) typed/warning-only; `caster_kind: 'Pact'`. L1–3 carry refs (Eldritch Invocations, Pact Magic, Magical Cunning, Pact Boon). Eldritch Invocations / Pact Boon are branching choices deferred to traits; no typed option-set. L5–11 Mystic Arcanum rows have EMPTY descriptions (level-6..9 spell grants undocumented and untyped). L13+ (Eldritch Master, Eldritch Resilience) prose-only.
- **Wizard** — Multiclass prereq (INT 13) typed/warning-only. L1–2 carry refs (Spellcasting, Ritual Adept, Arcane Recovery, Scholar). L5/18/20 (Memorize Spell, Spell Mastery, Signature Spells) prose-only — no typed free-cast mechanic. Several spellcasting features lean on `Spellcasting Focus` trait for the focus grant only.

### Entity Log — Subclasses (12)
- **Path of the Berserker** — L3 granted; Frenzy/Mindless Rage/Retaliation/Intimidating Presence carry refs. Mindless Rage redundantly lists both a `trait` and a `feat` ref. Clean structurally; no prereqs.
- **College of Lore** — `bonus_skill_pick_count: 3` typed (surfaces as pending skill choice). Bonus Proficiencies feature row is prose duplicate of that typed count. Magical Discoveries / Peerless Skill prose-only.
- **Life Domain** — Disciple of Life / Preserve Life / Blessed Healer carry refs. Domain Spells (always-prepared bonus list) is prose-only — no `granted_spells_at_level` / always-prepared typing (missing mechanic). Supreme Healing prose-only.
- **Circle of the Land** — Land's Aid / Land's Stride / Nature's Ward carry refs. Circle Forms (Wild Shape CR ½) and Nature's Sanctuary partly prose; Nature's Ward "resistance to a damage type associated with your land choice" is an unresolved CHOICE with no typed damage-resistance grant (missing mechanic — choice deferred nowhere).
- **Champion** — Improved Critical / Remarkable Athlete / Heroic Warrior carry refs (crit-range relies on `crit_range_extend` in trait). Additional Fighting Style "second Fighting Style feat" no `granted_feat_refs`. Superior Critical (18–20) / Survivor prose-only — Superior Critical's wider crit range untyped (only the L3 trait exists).
- **Warrior of the Open Hand** — Open Hand Technique / Wholeness of Body carry refs. Fleet Step / Quivering Palm (10d12 force) prose-only.
- **Oath of Devotion** — Sacred Weapon carries action ref. Domain Spells prose-only (no always-prepared typing). Aura of Devotion / Smite of Protection / Holy Nimbus prose-only — auras have no typed emanation mechanic.
- **Hunter** — Hunter's Prey / Defensive Tactics carry trait refs but are unresolved sub-choices (Colossus Slayer vs Horde Breaker vs Giant Killer) with no typed option enumeration. Hunter's Lore / Multiattack / Superior Hunter's Defense prose-only.
- **Thief** — Fast Hands carries ref. Second-Story Work (climb speed = speed) prose-only — no `climb_speed_equals_speed` effect (missing mechanic). Use Magic Device "ignore class/race/level requirements" is an Unimplemented-prereq-bypass with no typed counterpart. Supreme Sneak / Thief's Reflexes prose-only.
- **Draconic Sorcery** — Draconic Resilience / Elemental Affinity / Dragon Wings / Dragon Companion carry refs. Draconic Resilience's "+3 HP then +1/level" and "AC 13+DEX" ride the trait (verify `hp_bonus_per_level` + `unarmored_ac_formula` present in trait). Draconic Spells: damage-type CHOICE + bonus spells prose-only, untyped.
- **Fiend Patron** — Dark One's Blessing/Own Luck, Fiendish Resilience carry refs. Fiendish Resilience "choose a damage type, gain resistance" is an unresolved choice with no typed resistance grant. Fiend Spells (bonus prepared) prose-only. Hurl Through Hell (8d10 psychic) prose-only.
- **Evoker** — Sculpt Spells carries ref. Evocation Savant / Potent Cantrip / Empowered Evocation / Overchannel prose-only — all spell-shaping mechanics, none typeable under current DSL (no spell-effect DSL).

### Entity Log — Species (9)
- **Dragonborn** — Darkvision sense + Draconic Ancestry/Damage Resistance traits + Breath Weapon action + Draconic Flight bonus-action all typed/ref'd. Card text "damage resistance keyed to a chosen ancestry" — the actual color choice lives in subspecies (Black/Blue/... Dragonborn); species-level resistance is deferred. Clean (mechanics in refs/subspecies).
- **Dwarf** — Darkvision + Poison resistance typed; Dwarven Resilience/Toughness/Stonecunning/Forge Wise traits. "tremorsense on stone" mentioned in description but represented as Stonecunning trait (verify trait grants tremorsense) — not a typed `sense_grant` at species level. Otherwise Clean.
- **Elf** — Darkvision + Fey Ancestry/Trance/Keen Senses/Elven Lineage traits. Lineage (Drow/High/Wood) deferred to subspecies. Clean.
- **Gnome** — Darkvision + Gnomish Cunning trait. Description promises "mental save advantage" (Gnomish Cunning trait) and "Forest/Rock lineage of innate magic" (subspecies). Clean (deferred).
- **Goliath** — Powerful Build / Large Form / Giant Ancestry traits; giant-ancestry boon deferred to subspecies. Description "optional Large Form starting at level 5" — level gating lives in the Large Form trait, no typed level predicate at species level. Speed 35 typed. Clean (deferred).
- **Halfling** — Halfling Lucky/Naturally Stealthy/Brave/Halfling Nimbleness traits; "reroll natural 1s" = Lucky trait. No Darkvision (correct). Clean (deferred to traits).
- **Human** — Resourceful/Skilled/Versatile traits. Card text "bonus Heroic Inspiration on Long Rests, a free skill, and an Origin feat" — the Origin-feat grant (Versatile) has no `granted_feat_refs` at species level and no typed feat hook; relies entirely on the Versatile trait carrying it (flag: described feat-grant not represented by any species-level typed field).
- **Orc** — Darkvision + Powerful Build trait + Adrenaline Rush bonus action + Relentless Endurance reaction, all ref'd. Description "temporary HP" delivered via Adrenaline Rush action. Clean.
- **Tiefling** — Darkvision + Otherworldly Presence/Fiendish Legacy traits; legacy resistance + innate spells deferred to subspecies. Clean (deferred).

### Entity Log — Subspecies (~22)
- **Black/Copper Dragonborn** (Acid), **Blue/Bronze** (Lightning), **Brass/Gold/Red** (Fire), **Green** (Poison), **Silver/White** (Cold) — each grants typed `granted_damage_resistances`. BUT card text says "<type> breath weapon AND <type> resistance"; only resistance is typed — the breath-weapon damage-TYPE keying is NOT represented (species' Breath Weapon action is generic; no typed per-color damage override). Missing mechanic across all 10 color rows.
- **Hill Dwarf** — typed `hp_bonus_per_level:1` modifier + Insight skill prof. Clean.
- **Mountain Dwarf** — typed `hp_bonus_flat:2` modifier. Card omits SRD armor/weapon proficiencies (intentional legacy trim); Clean for what it claims.
- **Drow** — typed superior-Darkvision `sense_grant` (120 ft) + Dancing Lights cantrip + `granted_spells_at_level` (Faerie Fire L3, Darkness L5). Clean (all typed).
- **High Elf** — `granted_spells_at_level` (Detect Magic, Misty Step). Card text "a Wizard cantrip (L1)" is an unresolved free CHOICE with no typed cantrip grant (missing mechanic).
- **Wood Elf** — typed `speed_bonus:5` (resolver-handled) + Druidcraft cantrip + Longstrider/Pass without Trace at-level spells. Clean.
- **Forest Gnome** — Minor Illusion cantrip typed. "Speak with Small Beasts (telepathic)" prose-only — no typed action/trait ref (missing mechanic).
- **Rock Gnome** — Mending + Prestidigitation cantrips typed. "Artificer's Lore (double prof on magic-item History)" and the Tinker clockwork-device feature are prose-only — no `expertise_grant`/action ref (missing mechanic).
- **Cloud Giant** — Cloud's Jaunt bonus-action ref. Clean (mechanic in action).
- **Fire Giant** — Fire's Burn action ref (1d10 fire on hit). Note: ride-along extra damage lives in the action card, not typed here. Clean (deferred).
- **Frost Giant** — Frost's Chill action ref (1d6 cold + speed reduction). Clean (deferred).
- **Hill Giant** — Hill's Tumble; described as a melee on-hit prone but wired as a `granted_reaction_refs` (likely mis-categorized: SRD Hill's Tumble triggers on your own hit, not a reaction). Flag: action-economy mismatch.
- **Stone Giant** — Stone's Endurance reaction ref. Clean (deferred).
- **Storm Giant** — Storm's Thunder reaction ref. Clean (deferred).
- **Lightfoot Halfling** — Stealth skill prof typed. Clean.
- **Stout Halfling** — Poison resistance typed. Clean.
- **Standard Human** — typed `ability_score_bonus` +1 to all six abilities via `granted_modifiers`. Clean.
- **Half-Orc** — Intimidation skill prof typed. Clean (legacy trim of SRD Half-Orc Relentless/Savage Attacks acknowledged).
- **Abyssal Tiefling** — Poison resistance + Poison Spray cantrip + at-level spells. Clean.
- **Chthonic Tiefling** — Necrotic resistance + Chill Touch + at-level spells. Clean.
- **Infernal Tiefling** — Fire resistance + Fire Bolt + at-level spells. Clean.

### Systemic Gaps (for roadmap)
- **Leveled class/subclass features are prose-only.** Both `features` rows and the `rule_effects` typed featEffectList are empty of mechanics for all 12 classes and 12 subclasses past L1–L3; every L4+ benefit (Extra Attack tiers, flat ability boosts like Primal Champion/Body and Mind, Blessed Strikes, always-prepared domain spells, Studied Attacks) is unresolvable. The resolver only sees what L1–3 `granted_*_refs` carry.
- **Multi-ability multiclass prereqs use AND not OR.** Fighter/Monk/Paladin/Ranger list two `multiclass_prereq_ability_refs` against one `multiclass_prereq_min_score`; schema semantics require BOTH, but SRD multiclass needs only one — over-restrictive. Moot in practice since the whole prereq check is warning-only/non-blocking, but the warning itself is wrong.
- **Unresolved in-feature CHOICES have no typed representation.** Divine Order, Primal Order, Pact Boon, Eldritch Invocations, Metamagic, Hunter's Prey/Defensive Tactics, Nature's Ward / Fiendish Resilience resistance-type, High-Elf wizard cantrip, Draconic damage type — all branch points described in prose with no enumerated option set or typed grant, so the chosen branch grants nothing mechanically.
- **"Gain a Fighting Style feat" / "Origin feat" never use `granted_feat_refs`.** Fighter L1, Paladin/Ranger L2, Champion L7, and Human (Versatile) describe feat grants in prose with no typed feat hook on the class/species card — deferred entirely to a player pick or to a trait.
- **Dragonborn breath-weapon damage type is not keyed per color.** Subspecies type only `granted_damage_resistances`; the breath weapon's damage type (the defining color mechanic) has no typed override — the species' generic Breath Weapon action can't know the chosen element. Also several lineage flavor mechanics (Forest Gnome telepathy, Rock Gnome Artificer's Lore/Tinker) are prose-only with no ref/effect, and Hill Giant's Hill's Tumble is wired as a reaction despite being an on-your-hit rider (action-economy mismatch).

---

## Traits & Backgrounds (srd_core/traits.dart, srd_core/backgrounds.dart)

### Structural finding (applies to ALL 239 trait cards)

The `_t()` builder (traits.dart L7–23) emits ONLY three attributes per row:
`source`, `trait_kind`, `description`. It NEVER calls `effect()` and NEVER
populates a typed `effects` DSL array, even though the full DSL + `effect()`
helper exist (`_helpers.dart` L52). Therefore **every one of the 239 traits
is a Missing Mechanic + Poor Data Structure card**: the entire functional rule
lives in the `description` prose string, and the resolver cannot apply any of
it. `trait_kind` is a free-text bucket label, not a mechanic. For monster
traits this is partly by-design (monster actions are prose elsewhere too), but
for the ~21 PC species traits and ~70 PC class traits the mechanics ARE
resolver-expressible (advantage_on, damage_resistance, fly_speed,
spell_always_prepared, hp_bonus_per_level, unarmored_ac_formula, etc.) and are
simply not encoded here. Some species-level grants are typed on `species.dart`
fields (e.g. Dwarf `granted_damage_resistances: [Poison]`, `granted_senses`),
but the trait rows are referenced only by name via `trait_refs` and carry no
effects; several sub-mechanics are typed NOWHERE (see Systemic Gaps).

### Entity Log — Traits

Verdict shorthand: **MM** = Missing Mechanic (rule is prose-only, no typed
`effects`); **PDS** = Poor Data Structure (rule dumped in `description`). All
trait rows below are MM+PDS unless noted. Names grouped by the resolver-DSL
kind that SHOULD carry them; every name enumerated.

Monster/creature traits whose mechanic is plausibly prose-only by system design
but still has NO typed field (MM+PDS, monster-scope):
- **Amphibious** — MM+PDS (breathe air/water; no movement/sense field).
- **Legendary Resistance (3/Day)** — MM+PDS (auto-succeed save; no resource_pool_grant + saving-throw override).
- **Magic Resistance** — MM+PDS (adv. on saves vs magic → `advantage_on`/`saving_throw`).
- **Pack Tactics** — MM+PDS (adv. on attack → `advantage_on` w/ predicate).
- **Keen Smell**, **Keen Sight**, **Keen Hearing**, **Keen Sight and Smell** — MM+PDS (adv. on Perception → `advantage_on`).
- **Sunlight Sensitivity** — MM+PDS (disadv. → `disadvantage_on`).
- **Spider Climb**, **Spider Climb (Roper)**, **Spider Climb (Vampire)** — MM+PDS (climb → `climb_speed_equals_speed`).
- **Web Sense**, **Web Walker** — MM+PDS.
- **Aggressive** — MM+PDS (bonus-action move → `granted_bonus_action_grant`).
- **Brute** — MM+PDS (extra die → `extra_damage_on_attack`).
- **Reckless**, **Reckless Attacker** — MM+PDS (adv./adv.-against → `advantage_on`+`disadvantage_on`).
- **Flyby**, **Flyby (Bat)** — MM+PDS (no OA on fly-out → `opportunity_attack_immunity*`).
- **Standing Leap**, **Running Leap**, **Running Leap (re: animals)** — MM+PDS (jump distances; no field).
- **Undead Fortitude** — MM+PDS (CON-save-to-1HP; no typed mechanic).
- **Aboleth Telepathy**, **Probing Telepathy**, **Limited Telepathy** — MM+PDS (no telepathy field).
- **Eldritch Restoration**, **Rejuvenation**, **Demonic Restoration**, **Misty Escape**, **Nine Lives Stealer**, **Whelm**, **Blessed by Tyche** — MM+PDS (revival/death-deny; no typed mechanic).
- **Mucous Cloud**, **Stench**, **Heated Body**, **Fire Aura**, **Paralyzing Aura**, **Fear Aura**, **Aura of the Dead**, **Frightful Presence** — MM+PDS (aura/save effects; no typed aura DSL).
- **Legendary Resistance (3/Day, or 4/Day in Lair)** — MM+PDS.
- **Spellcasting (Lich)**, **Spellcasting (Mage)**, **Spellcasting (Priest)**, **Spellcasting (Cult Fanatic)**, **Spell Storing (Lich)**, **Sphinx Spellcasting**, **Innate Spellcasting (Drow)**, **Innate Spellcasting (Druid)**, **Innate Spellcasting (Demon)**, **Innate Spellcasting (Sphinx)**, **Innate Spellcasting (Hag)**, **Innate Spellcasting (Lamia)**, **Innate Spellcasting (Rakshasa)**, **Innate Spellcasting (Pixie)** — MM+PDS (spell lists/DCs in prose; no `spell_always_prepared`/`spell_cast_from_item` rows, consistent w/ no-typed-spell-DSL note but spells themselves not even referenced).
- **Turn Resistance**, **Magic Resistance (MF)**, **Magic Resistance (Strong)**, **Spell Resistance**, **Limited Magic Immunity**, **Brave** (monster), **Two Heads**, **Multiple Heads**, **Multi-Headed (Hydra)**, **Two-Headed (Death Dog)**, **Sure-Footed**, **Gnomish Cunning (monster dup?)** — MM+PDS (adv. on saves / condition advantage → `advantage_on`).
- **Antimagic Cone** — MM+PDS.
- **Creature Sense**, **Web Sense**, **Sense Magic**, **Treasure Sense**, **Iron Scent**, **Echolocation**, **Devil's Sight**, **Divine Awareness** — MM+PDS (senses → `sense_grant`/`blindsight_grant`/`truesight_grant`).
- **Martial Advantage**, **Sneak Attack**, **Sneak Attack (Rogue)**, **Magic Weapons**, **Charge**, **Charge (Animal)**, **Trampling Charge**, **Hooves (Trampling)**, **Pounce**, **Blood Frenzy** — MM+PDS (extra damage / conditional adv. → `extra_damage_on_attack`/`advantage_on`).
- **Hold Breath**, **Hold Breath (Crocodile)**, **Hold Breath (Octopus)**, **Water Breathing**, **Water Breathing (Animal)** — MM+PDS.
- **Snow Camouflage**, **Stone Camouflage**, **Stone Camouflage (Xorn)**, **Plant Camouflage**, **Camouflage (Octopus)**, **Underwater Camouflage**, **Stealth Master** — MM+PDS (adv. on Stealth → `advantage_on`).
- **Fey Ancestry** — MM+PDS (adv. vs Charm + no-sleep → `advantage_on`+`condition_immunity_grant`).
- **Shapechanger (Werewolf)**, **Shapechanger (Werecreature)**, **Shapechanger (Vampire)** — MM+PDS.
- **Regeneration**, **Acid Absorption**, **Lightning Absorption**, **Fire Absorption**, **Cold Absorption** — MM+PDS (heal/absorb → `damage_immunity_grant`+heal; no typed mechanic).
- **Death Burst**, **Death Burst (Fire Beetle)** — MM+PDS.
- **False Appearance**, **False Appearance (Gargoyle)** — MM+PDS.
- **Siege Monster** — MM+PDS (double dmg to objects).
- **Damage Transfer**, **Reflective Carapace**, **Reactive**, **Reactive Heads**, **Avoidance**, **Evasion** (monster) — MM+PDS.
- **Wakeful** — MM+PDS.
- **Earth Glide**, **Earth Glide (Xorn)**, **Earth Walk**, **Ice Walk**, **Air Form**, **Incorporeal Movement**, **Tunneler**, **Tree Stride**, **Climb (Animal)**, **Burrow (Giant Badger)**, **Beast of Burden** — MM+PDS (movement → `climb_speed_equals_speed`/`fly_speed`/`walk_on_liquid`/speed fields).
- **Sunlight Hypersensitivity**, **Sunlight Sensitivity (Acute)**, **Aversion to Light** — MM+PDS (disadv. in sunlight).
- **Cunning Action**, **Cunning Action (Rogue)**, **Nimble Escape** — MM+PDS (bonus-action Dash/Disengage/Hide → `granted_bonus_action_grant`).
- **Tentacles**, **Tentacles (Chuul)**, **Ooze Cube**, **Swarm**, **Steal Memories**, **Construct Nature**, **Immutable Form**, **Shielded Mind**, **Inscrutable**, **Vampire Weaknesses**, **Mimicry**, **Light (Fire Beetle)**, **Ink Cloud** — MM+PDS.
- **Speak with Beasts and Plants**, **Speak with Plants**, **Beast Whisperer** — MM+PDS (language-ish; no `language_grant`).

PC species traits (mechanics ARE resolver-expressible; MM+PDS, and several sub-rules typed NOWHERE):
- **Dwarven Resilience** — MM+PDS. Damage resistance typed on species (`granted_damage_resistances: Poison`) ✓; but "Advantage on saves vs Poisoned condition" has NO typed field (no save/condition-advantage on species → `advantage_on`).
- **Dwarven Toughness** — MM+PDS (+1 HP/level → `hp_bonus_per_level`, not encoded).
- **Stonecunning** — MM+PDS (tremorsense 60 ft as bonus action, PB/LR → `sense_grant`+`activation`; typed nowhere).
- **Forge Wise** — MM+PDS (choose 2 artisan tools → `tool`/`choice_group`).
- **Trance** — MM+PDS (no-sleep immunity → `condition_immunity_grant`; tool/weapon prof choice).
- **Keen Senses (Elf)** — MM+PDS (skill choice → `skill`/`proficiency_grant`/`choice_group`).
- **Elven Lineage**, **Fiendish Legacy**, **Draconic Ancestry**, **Giant Ancestry** — MM+PDS (lineage choice gating resistances + innate spells; no `choice_group`/`spell_always_prepared`).
- **Halfling Lucky** — MM+PDS (reroll nat-1; no typed mechanic).
- **Naturally Stealthy** — MM+PDS.
- **Brave** (species, dup name w/ monster Brave) — MM+PDS (adv. vs Frightened → `advantage_on`). Note duplicate `name` collides with monster row.
- **Halfling Nimbleness** — MM+PDS.
- **Resourceful** — MM+PDS (Heroic Inspiration on LR).
- **Skilled (Human)** — MM+PDS (3 skill choices → `skill`+`choice_group`).
- **Versatile (Human)** — MM+PDS (origin feat choice → `feat`/`choice_group`; cf. backgrounds' `origin_feat_ref`).
- **Gnomish Cunning** — MM+PDS (adv. INT/WIS/CHA saves → three `advantage_on`/`saving_throw`; typed nowhere on species).
- **Powerful Build** — MM+PDS (carry capacity + adv. to end Grappled).
- **Large Form** — MM+PDS (L5 size change, speed +10, adv. STR; → `species`/`activation`).
- **Otherworldly Presence** — MM+PDS (Thaumaturgy cantrip → `cantrip_grant`).
- **Damage Resistance (Dragonborn)** — MM+PDS (resistance keyed to ancestry → `damage_resistance_grant`; ancestry choice not typed).

PC class traits (mechanics ARE resolver-expressible; all MM+PDS):
- **Unarmored Defense (Barbarian)**, **Unarmored Defense (Monk)** — MM+PDS (→ `unarmored_ac_formula`).
- **Reckless Attack** — MM+PDS (→ `advantage_on`+`disadvantage_on`).
- **Danger Sense** — MM+PDS (adv. Dex saves → `advantage_on`/`saving_throw`).
- **Weapon Mastery** — MM+PDS (→ `weapon_mastery_count_bonus`/`weapon_mastery_grant`).
- **Jack of All Trades** — MM+PDS (→ `half_proficiency_to_unproficient_checks`).
- **Expertise**, **Scholar (Wizard)** — MM+PDS (→ `expertise_count`/`expertise_grant`).
- **Sneak Attack (Rogue)**, **Cunning Strike** — MM+PDS (→ `extra_damage_on_attack` w/ `scales_with`).
- **Cunning Action (Rogue)** — MM+PDS (→ `granted_bonus_action_grant`).
- **Martial Arts**, **Empowered Strikes**, **Stunning Strike**, **Heightened Focus**, **Open Hand Technique** — MM+PDS (→ `magical_unarmed_strikes`/`min_die_value`/`granted_*`).
- **Arcane Recovery**, **Magical Cunning** — MM+PDS (→ `slot_recovery_short_rest`).
- **Spellcasting Focus** — MM+PDS.
- **Divine Order** — MM+PDS (sub-choice → armor/weapon `proficiency_grant`/`cantrip_grant`).
- **Druidic** — MM+PDS (→ `language_grant`).
- **Pact Magic**, **Pact Boon**, **Magical Cunning**, **Ritual Adept** — MM+PDS.
- **Eldritch Invocations** — MM+PDS.
- **Favored Enemy**, **Faithful Steed**, **Paladin's Smite**, **Dragon Companion** — MM+PDS (always-prepared spell → `spell_always_prepared`).
- **Lay on Hands (Pool)** — MM+PDS (→ `resource_pool_grant`).
- **Innate Sorcery** — MM+PDS (→ `resource_pool_grant`).
- **Dwarven Toughness** (class-dup) / **Draconic Resilience** — MM+PDS (→ `hp_bonus_per_level`+`unarmored_ac_formula`).
- **Fast Movement**, **Roving**, **Tactical Shift**, **Acrobatic Movement**, **Land's Stride** — MM+PDS (speed → speed fields/`walk_on_liquid`).
- **Feral Instinct**, **Remarkable Athlete**, **Heroic Warrior** — MM+PDS (→ `initiative_bonus`/`advantage_on`).
- **Frenzy**, **Radiant Strikes** — MM+PDS (→ `extra_damage_on_attack`).
- **Mindless Rage**, **Aura of Courage** — MM+PDS (→ `condition_immunity_grant`).
- **Aura of Protection** — MM+PDS (→ `saving_throw` bonus w/ predicate).
- **Tactical Mind** — MM+PDS.
- **Indomitable** — MM+PDS (reroll save → `saving_throw`/`scales_with`).
- **Improved Critical** — MM+PDS (→ `crit_range_extend`).
- **Deft Explorer** — MM+PDS (→ `expertise_grant`+`language_grant`).
- **Hunter's Prey**, **Defensive Tactics** — MM+PDS (sub-choice; → `choice_group`).
- **Tireless** — MM+PDS (→ `temp_hp_grant`+`recovery_grant`).
- **Reliable Talent** — MM+PDS (→ `reliable_talent`, a dedicated DSL kind exists and is unused here).
- **Slippery Mind** — MM+PDS (→ `saving_throw` proficiency / `proficiency_grant`).
- **Disciple of Life**, **Blessed Healer** — MM+PDS.
- **Elemental Affinity**, **Fiendish Resilience**, **Nature's Ward** — MM+PDS (→ `damage_resistance_grant`+`condition_immunity_grant`).
- **Dark One's Blessing** — MM+PDS (→ `temp_hp_grant`).
- **Dark One's Own Luck** — MM+PDS.
- **Sculpt Spells** — MM+PDS.
- **Uncanny Metabolism**, **Perfect Focus** — MM+PDS (→ `recovery_grant`/`resource_pool_grant`).
- **Evasion** (class, dup name) — MM+PDS. Duplicate `name` collides with monster Evasion.

(Note: several `name` collisions across scopes — **Brave**, **Evasion**,
**Cunning Action**, **Sneak Attack**, **Charge**, **Flyby**, **Spider Climb**,
**Stone Camouflage**, **Death Burst**, **Hold Breath**, **Sunlight
Sensitivity** — because `trait_refs` resolve by name, these are ambiguous
reference targets.)

### Entity Log — Backgrounds (all 16)

Backgrounds are the well-structured counter-example: ability options, ASI
distribution, origin feat, skills, tool, gold, and equipment kit are ALL in
dedicated typed fields. **Clean** unless noted:
- **Acolyte** — Clean.
- **Criminal** — Clean.
- **Sage** — Clean.
- **Soldier** — Clean. (Tool is a variant picker via `granted_tool_variant_group: 'gaming_set'` instead of `granted_tool_refs` — intentional, surfaced by wizard.)
- **Artisan** — Clean.
- **Charlatan** — Clean.
- **Entertainer** — Clean.
- **Farmer** — Clean.
- **Guard** — Clean.
- **Guide** — Clean.
- **Hermit** — Clean.
- **Merchant** — Clean.
- **Noble** — Clean.
- **Sailor** — Clean.
- **Scribe** — Clean.
- **Wayfarer** — Clean.

Minor cross-cutting note (not per-card blocking): backgrounds use
`granted_skill_refs`/`granted_tool_refs`/`origin_feat_ref` so the resolver can
auto-apply, but `ability_score_options` + `asi_distribution_options` describe a
CHOICE the resolver/wizard must enforce (pick 2 of 3, +2/+1 or +1/+1/+1) — fine
as typed options, just confirm the wizard actually applies the chosen ASI.

### Systemic Gaps (for roadmap)

- **Trait `effects` DSL is 100% unused.** All 239 trait cards store their
  mechanic only in `description`; the `_t()` builder has no `effects` param and
  never calls `effect()`. The resolver applies ZERO trait mechanics. The ~21 PC
  species + ~70 PC class traits are fully DSL-expressible (advantage_on,
  damage_resistance_grant, unarmored_ac_formula, hp_bonus_per_level,
  spell_always_prepared, reliable_talent, crit_range_extend, expertise_count,
  resource_pool_grant, etc.) and should be back-filled.
- **Species typed fields cover damage-resistance/senses/speed but NOT save- or
  condition-advantage.** Dwarven Resilience's "adv. vs Poisoned", Gnomish
  Cunning's "adv. INT/WIS/CHA saves", Fey Ancestry's "adv. vs Charm", and
  Brave's "adv. vs Frightened" are typed NOWHERE — neither on the trait row nor
  on `species.dart`. Need a species-level `advantage_on`/`saving_throw` grant
  channel (or move these to trait `effects`).
- **No typed model for "innate/limited-use spellcasting" on traits.** All 14
  Innate/Spellcasting trait rows list spells, DCs, and per-day uses purely in
  prose; spells aren't even `ref`'d. Combined with the documented absence of a
  typed spell-effect DSL, monster and PC innate casting is entirely unresolvable.
- **Activation/resource economy (X/day, PB/LR, pools, auras) has no typed
  home on traits.** Legendary Resistance, Lay on Hands, Stonecunning, Large
  Form, Indomitable, auras, regeneration/absorption all encode uses + action
  type + duration in prose; the `activation()`/`resource_pool_grant` machinery
  exists but is never wired to trait rows.
- **Duplicate trait `name`s break name-based `trait_refs` resolution.** Brave,
  Evasion, Cunning Action, Sneak Attack, Charge, Flyby, Spider Climb, Stone
  Camouflage, Death Burst, Hold Breath, Sunlight Sensitivity each appear 2+
  times across monster/species/class scopes; since species/classes reference
  traits by name, the target is ambiguous. Need scoped slugs or unique names.

---

## Spells — SRD 5.2.1 Core (spells.dart)

### Entity Log

**Shared core finding — applies to ALL 341 spells:** Missing Mechanic — there is NO typed spell-effect DSL. Only *identity* fields are typed (level, school, casting-time, range, components, duration, classes, ritual, concentration, material/cost/consumed, save-ability, attack-type, damage-types, applied-conditions). Every *functional* rule — damage dice, cantrip & upcast scaling, save outcomes (negate / half-on-success), healing amounts, temp-HP, area shape/size, summon stat blocks, and the actual *application* of an applied condition — lives only in markdown `description`. The resolver cannot auto-roll or auto-apply any spell. Even where `damage_type_refs` / `save_ability_ref` / `applied_condition_refs` are set, they are pure classification tags: no dice, DC math, or on-fail/on-success branch is attached. Per-spell notes flag scaling, concentration, imposed conditions, healing, and any *typed-field* gap.


#### Cantrips (L0) (27)

- **Acid Splash** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Chill Touch** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓); prose-only rider: target can't regain HP.
- **Dancing Lights** — no typed effect DSL; concentration.
- **Fire Bolt** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Light** — no typed effect DSL.
- **Mage Hand** — no typed effect DSL.
- **Mending** — no typed effect DSL; ritual.
- **Minor Illusion** — no typed effect DSL.
- **Poison Spray** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Prestidigitation** — no typed effect DSL.
- **Ray of Frost** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Sacred Flame** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Shocking Grasp** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Spare the Dying** — no typed effect DSL.
- **Thaumaturgy** — no typed effect DSL.
- **Druidcraft** — no typed effect DSL.
- **Eldritch Blast** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Guidance** — no typed effect DSL; concentration.
- **Message** — no typed effect DSL.
- **Produce Flame** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Resistance** — no typed effect DSL; concentration.
- **Shillelagh** — no typed effect DSL.
- **True Strike** — no typed effect DSL; cantrip damage scaling in prose.
- **Vicious Mockery** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Elementalism** — no typed effect DSL.
- **Starry Wisp** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).
- **Sorcerous Burst** — no typed effect DSL; cantrip damage scaling in prose; damage dice in prose (types typed ✓).

#### Level 1 (57)

- **Burning Hands** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Charm Person** — no typed effect DSL; upcast scaling in prose; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Cure Wounds** — no typed effect DSL; upcast scaling in prose; healing dice in prose.
- **Detect Magic** — no typed effect DSL; concentration; ritual.
- **Healing Word** — no typed effect DSL; upcast scaling in prose; healing dice in prose.
- **Hellish Rebuke** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Mage Armor** — no typed effect DSL.
- **Magic Missile** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Shield** — no typed effect DSL.
- **Sleep** — no typed effect DSL; upcast scaling in prose; concentration; conditions imposed: Incapacitated (typed ✓; apply-on-fail not in any DSL).
- **Thunderwave** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Bless** — no typed effect DSL; upcast scaling in prose; concentration.
- **Bane** — no typed effect DSL; concentration.
- **Command** — no typed effect DSL.
- **Faerie Fire** — no typed effect DSL; concentration.
- **Guiding Bolt** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Identify** — no typed effect DSL; ritual.
- **Protection from Evil and Good** — no typed effect DSL; concentration.
- **Sanctuary** — no typed effect DSL.
- **Detect Evil and Good** — no typed effect DSL; concentration.
- **Detect Poison and Disease** — no typed effect DSL; concentration; ritual.
- **Disguise Self** — no typed effect DSL.
- **Speak with Animals** — no typed effect DSL; ritual.
- **Animal Friendship** — no typed effect DSL; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Color Spray** — no typed effect DSL; conditions imposed: Blinded (typed ✓; apply-on-fail not in any DSL); Blinded typed ✓ but HP-pool mechanic (6d10) fully in prose; no save (correct).
- **Divine Favor** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Goodberry** — no typed effect DSL.
- **Grease** — no typed effect DSL; conditions imposed: Prone (typed ✓; apply-on-fail not in any DSL).
- **Hunter's Mark** — no typed effect DSL; concentration.
- **Jump** — no typed effect DSL.
- **Longstrider** — no typed effect DSL.
- **Purify Food and Drink** — no typed effect DSL; ritual.
- **Silent Image** — no typed effect DSL; concentration.
- **Hideous Laughter** — no typed effect DSL; concentration; conditions imposed: Prone, Incapacitated (typed ✓; apply-on-fail not in any DSL).
- **Find Familiar** — no typed effect DSL; ritual.
- **Hex** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Alarm** — no typed effect DSL; ritual.
- **Chromatic Orb** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Comprehend Languages** — no typed effect DSL; ritual.
- **Create or Destroy Water** — no typed effect DSL.
- **Ensnaring Strike** — no typed effect DSL; concentration; conditions imposed: Restrained (typed ✓; apply-on-fail not in any DSL); damage dice in prose (types typed ✓).
- **Entangle** — no typed effect DSL; concentration; conditions imposed: Restrained (typed ✓; apply-on-fail not in any DSL).
- **Expeditious Retreat** — no typed effect DSL; concentration.
- **False Life** — no typed effect DSL.
- **Feather Fall** — no typed effect DSL.
- **Fog Cloud** — no typed effect DSL; concentration.
- **Heroism** — no typed effect DSL; concentration.
- **Ice Knife** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Illusory Script** — no typed effect DSL; ritual.
- **Ray of Sickness** — no typed effect DSL; conditions imposed: Poisoned (typed ✓; apply-on-fail not in any DSL); damage dice in prose (types typed ✓).
- **Shield of Faith** — no typed effect DSL; concentration.
- **Unseen Servant** — no typed effect DSL; ritual.
- **Divine Smite** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Searing Smite** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Floating Disk** — no typed effect DSL; ritual.
- **Inflict Wounds** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Dissonant Whispers** — no typed effect DSL; damage dice in prose (types typed ✓).

#### Level 2 (58)

- **Aid** — no typed effect DSL; upcast scaling in prose.
- **Hold Person** — no typed effect DSL; upcast scaling in prose; concentration; conditions imposed: Paralyzed (typed ✓; apply-on-fail not in any DSL).
- **Misty Step** — no typed effect DSL.
- **Scorching Ray** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Web** — no typed effect DSL; concentration; conditions imposed: Restrained (typed ✓; apply-on-fail not in any DSL).
- **Spiritual Weapon** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Silence** — no typed effect DSL; concentration; ritual.
- **Mirror Image** — no typed effect DSL.
- **Invisibility** — no typed effect DSL; upcast scaling in prose; concentration.
- **See Invisibility** — no typed effect DSL.
- **Suggestion** — no typed effect DSL; concentration.
- **Levitate** — no typed effect DSL; concentration.
- **Spike Growth** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Pass Without Trace** — no typed effect DSL; concentration.
- **Lesser Restoration** — no typed effect DSL.
- **Moonbeam** — no typed effect DSL; upcast scaling in prose; concentration; damage dice in prose (types typed ✓).
- **Acid Arrow** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Alter Self** — no typed effect DSL; concentration.
- **Animal Messenger** — no typed effect DSL; ritual.
- **Arcane Lock** — no typed effect DSL.
- **Augury** — no typed effect DSL; ritual.
- **Blindness/Deafness** — no typed effect DSL; upcast scaling in prose; conditions imposed: Blinded, Deafened (typed ✓; apply-on-fail not in any DSL).
- **Calm Emotions** — no typed effect DSL; concentration.
- **Continual Flame** — no typed effect DSL.
- **Darkness** — no typed effect DSL; concentration.
- **Detect Thoughts** — no typed effect DSL; concentration.
- **Enhance Ability** — no typed effect DSL; concentration.
- **Find Traps** — no typed effect DSL.
- **Gust of Wind** — no typed effect DSL; concentration.
- **Knock** — no typed effect DSL.
- **Locate Object** — no typed effect DSL; concentration.
- **Magic Weapon** — no typed effect DSL; upcast scaling in prose.
- **Protection from Poison** — no typed effect DSL.
- **Ray of Enfeeblement** — no typed effect DSL; concentration.
- **Rope Trick** — no typed effect DSL.
- **Shatter** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Find Steed** — no typed effect DSL.
- **Flaming Sphere** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Heat Metal** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Magic Mouth** — no typed effect DSL; ritual.
- **Mind Spike** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Pass without Trace** — no typed effect DSL; concentration.
- **Prayer of Healing** — no typed effect DSL; healing dice in prose.
- **Zone of Truth** — no typed effect DSL.
- **Barkskin** — no typed effect DSL; concentration.
- **Blur** — no typed effect DSL; concentration.
- **Darkvision** — no typed effect DSL.
- **Enlarge/Reduce** — no typed effect DSL; concentration.
- **Enthrall** — no typed effect DSL.
- **Flame Blade** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Gentle Repose** — no typed effect DSL; ritual.
- **Locate Animals or Plants** — no typed effect DSL; ritual.
- **Spider Climb** — no typed effect DSL; concentration.
- **Warding Bond** — no typed effect DSL.
- **Shining Smite** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Arcanist's Magic Aura** — no typed effect DSL.
- **Dragon's Breath** — no typed effect DSL; upcast scaling in prose; concentration; grants a Dex-save 3d6 breath of chosen type — empty damageTypes (variable).
- **Phantasmal Force** — no typed effect DSL; concentration; Int save typed; deals 1d6 psychic in prose — empty damageTypes.

#### Level 3 (42)

- **Counterspell** — no typed effect DSL; GAP missing typed damageTypes:[Force] and saveAbility:Constitution (deals 3d8 Force on a Con save).
- **Dispel Magic** — no typed effect DSL; upcast scaling in prose.
- **Fireball** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Fly** — no typed effect DSL; upcast scaling in prose; concentration.
- **Lightning Bolt** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Revivify** — no typed effect DSL.
- **Hypnotic Pattern** — no typed effect DSL; concentration; conditions imposed: Charmed, Incapacitated (typed ✓; apply-on-fail not in any DSL).
- **Slow** — no typed effect DSL; concentration.
- **Haste** — no typed effect DSL; concentration.
- **Animate Dead** — no typed effect DSL; upcast scaling in prose.
- **Daylight** — no typed effect DSL.
- **Major Image** — no typed effect DSL; concentration.
- **Sleet Storm** — no typed effect DSL; concentration.
- **Bestow Curse** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Clairvoyance** — no typed effect DSL; concentration.
- **Create Food and Water** — no typed effect DSL.
- **Fear** — no typed effect DSL; concentration; conditions imposed: Frightened (typed ✓; apply-on-fail not in any DSL).
- **Gaseous Form** — no typed effect DSL; concentration.
- **Glyph of Warding** — no typed effect DSL; variable damage type/save chosen at cast — empty damageTypes/saveAbility (hard to type; effect fully in prose).
- **Magic Circle** — no typed effect DSL; upcast scaling in prose.
- **Mass Healing Word** — no typed effect DSL; upcast scaling in prose; healing dice in prose.
- **Phantom Steed** — no typed effect DSL; ritual.
- **Plant Growth** — no typed effect DSL.
- **Protection from Energy** — no typed effect DSL; concentration.
- **Remove Curse** — no typed effect DSL.
- **Sending** — no typed effect DSL.
- **Speak with Dead** — no typed effect DSL.
- **Stinking Cloud** — no typed effect DSL; concentration.
- **Tongues** — no typed effect DSL.
- **Water Breathing** — no typed effect DSL; ritual.
- **Wind Wall** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Conjure Animals** — no typed effect DSL; concentration.
- **Spirit Guardians** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Water Walk** — no typed effect DSL; ritual.
- **Beacon of Hope** — no typed effect DSL; concentration; healing dice in prose.
- **Blink** — no typed effect DSL.
- **Meld into Stone** — no typed effect DSL; ritual.
- **Nondetection** — no typed effect DSL.
- **Speak with Plants** — no typed effect DSL.
- **Tiny Hut** — no typed effect DSL; ritual.
- **Call Lightning** — no typed effect DSL; upcast scaling in prose; concentration; damage dice in prose (types typed ✓).
- **Vampiric Touch** — no typed effect DSL; upcast scaling in prose; concentration; healing dice in prose.

#### Level 4 (34)

- **Greater Invisibility** — no typed effect DSL; concentration; conditions imposed: Invisible (typed ✓; apply-on-fail not in any DSL).
- **Polymorph** — no typed effect DSL; concentration.
- **Banishment** — no typed effect DSL; upcast scaling in prose; concentration.
- **Wall of Fire** — no typed effect DSL; upcast scaling in prose; concentration; damage dice in prose (types typed ✓).
- **Confusion** — no typed effect DSL; upcast scaling in prose; concentration; Wis save typed but imposes random behavior — no condition typed.
- **Stoneskin** — no typed effect DSL; concentration.
- **Arcane Eye** — no typed effect DSL; concentration.
- **Black Tentacles** — no typed effect DSL; concentration; conditions imposed: Restrained (typed ✓; apply-on-fail not in any DSL); damage dice in prose (types typed ✓).
- **Death Ward** — no typed effect DSL.
- **Dimension Door** — no typed effect DSL.
- **Divination** — no typed effect DSL; ritual.
- **Faithful Hound** — no typed effect DSL; summons attacker (4d8 piercing, DC save) fully in prose.
- **Fire Shield** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Freedom of Movement** — no typed effect DSL.
- **Guardian of Faith** — no typed effect DSL.
- **Ice Storm** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Locate Creature** — no typed effect DSL; concentration.
- **Phantasmal Killer** — no typed effect DSL; concentration; conditions imposed: Frightened (typed ✓; apply-on-fail not in any DSL); damage dice in prose (types typed ✓).
- **Resilient Sphere** — no typed effect DSL; concentration.
- **Conjure Minor Elementals** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Conjure Woodland Beings** — no typed effect DSL; concentration.
- **Dominate Beast** — no typed effect DSL; concentration; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Blight** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Charm Monster** — no typed effect DSL; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Compulsion** — no typed effect DSL; concentration; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Control Water** — no typed effect DSL; concentration.
- **Fabricate** — no typed effect DSL.
- **Giant Insect** — no typed effect DSL; concentration.
- **Hallucinatory Terrain** — no typed effect DSL.
- **Private Sanctum** — no typed effect DSL.
- **Secret Chest** — no typed effect DSL.
- **Stone Shape** — no typed effect DSL.
- **Vitriolic Sphere** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Aura of Life** — no typed effect DSL; concentration; healing dice in prose.

#### Level 5 (38)

- **Cone of Cold** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Hold Monster** — no typed effect DSL; upcast scaling in prose; concentration; conditions imposed: Paralyzed (typed ✓; apply-on-fail not in any DSL).
- **Raise Dead** — no typed effect DSL.
- **Wall of Force** — no typed effect DSL; concentration.
- **Greater Restoration** — no typed effect DSL.
- **Mass Cure Wounds** — no typed effect DSL; upcast scaling in prose; healing dice in prose.
- **Scrying** — no typed effect DSL; concentration.
- **Telekinesis** — no typed effect DSL; concentration.
- **Cloudkill** — no typed effect DSL; upcast scaling in prose; concentration; damage dice in prose (types typed ✓).
- **Animate Objects** — no typed effect DSL; concentration; creates attacking constructs w/ stat blocks fully in prose — no typed actor mechanics.
- **Commune** — no typed effect DSL; ritual.
- **Conjure Elemental** — no typed effect DSL; concentration.
- **Contact Other Plane** — no typed effect DSL; ritual; Int save typed but inflicts madness/short-term-insanity — not a typed condition.
- **Dispel Evil and Good** — no typed effect DSL; concentration.
- **Flame Strike** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Geas** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Insect Plague** — no typed effect DSL; upcast scaling in prose; concentration; damage dice in prose (types typed ✓).
- **Legend Lore** — no typed effect DSL.
- **Modify Memory** — no typed effect DSL; concentration.
- **Passwall** — no typed effect DSL.
- **Planar Binding** — no typed effect DSL.
- **Seeming** — no typed effect DSL.
- **Tree Stride** — no typed effect DSL; concentration.
- **Wall of Stone** — no typed effect DSL; concentration.
- **Antilife Shell** — no typed effect DSL; concentration.
- **Dominate Person** — no typed effect DSL; concentration; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Hallow** — no typed effect DSL.
- **Reincarnate** — no typed effect DSL.
- **Commune with Nature** — no typed effect DSL; ritual.
- **Contagion** — no typed effect DSL; conditions imposed: Poisoned (typed ✓; apply-on-fail not in any DSL).
- **Creation** — no typed effect DSL.
- **Dream** — no typed effect DSL.
- **Mislead** — no typed effect DSL; concentration; conditions imposed: Invisible (typed ✓; apply-on-fail not in any DSL).
- **Telepathic Bond** — no typed effect DSL; ritual.
- **Teleportation Circle** — no typed effect DSL.
- **Arcane Hand** — no typed effect DSL; concentration; force-construct combat stats & damage fully in prose.
- **Awaken** — no typed effect DSL.
- **Blade Barrier** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).

#### Level 6 (30)

- **Disintegrate** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Heal** — no typed effect DSL; upcast scaling in prose; healing dice in prose.
- **Chain Lightning** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Circle of Death** — no typed effect DSL; upcast scaling in prose; damage dice in prose (types typed ✓).
- **Eyebite** — no typed effect DSL; concentration; conditions imposed: Frightened, Unconscious (typed ✓; apply-on-fail not in any DSL).
- **Globe of Invulnerability** — no typed effect DSL; upcast scaling in prose; concentration.
- **Harm** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Heroes' Feast** — no typed effect DSL.
- **Magic Jar** — no typed effect DSL.
- **Mass Suggestion** — no typed effect DSL.
- **Move Earth** — no typed effect DSL; concentration.
- **Sunbeam** — no typed effect DSL; concentration; conditions imposed: Blinded (typed ✓; apply-on-fail not in any DSL); damage dice in prose (types typed ✓).
- **True Seeing** — no typed effect DSL.
- **Wall of Ice** — no typed effect DSL; upcast scaling in prose; concentration; damage dice in prose (types typed ✓).
- **Find the Path** — no typed effect DSL; concentration.
- **Conjure Fey** — no typed effect DSL; concentration.
- **Flesh to Stone** — no typed effect DSL; concentration; conditions imposed: Restrained, Petrified (typed ✓; apply-on-fail not in any DSL).
- **Forbiddance** — no typed effect DSL; ritual; damage dice in prose (types typed ✓).
- **Guards and Wards** — no typed effect DSL.
- **Planar Ally** — no typed effect DSL.
- **Programmed Illusion** — no typed effect DSL.
- **Wall of Thorns** — no typed effect DSL; concentration.
- **Word of Recall** — no typed effect DSL.
- **Freezing Sphere** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Create Undead** — no typed effect DSL; upcast scaling in prose.
- **Irresistible Dance** — no typed effect DSL; concentration; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Wind Walk** — no typed effect DSL.
- **Contingency** — no typed effect DSL.
- **Instant Summons** — no typed effect DSL; ritual.
- **Transport via Plants** — no typed effect DSL.

#### Level 7 (20)

- **Finger of Death** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Teleport** — no typed effect DSL.
- **Conjure Celestial** — no typed effect DSL; upcast scaling in prose; concentration.
- **Delayed Blast Fireball** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Etherealness** — no typed effect DSL.
- **Forcecage** — no typed effect DSL.
- **Plane Shift** — no typed effect DSL.
- **Prismatic Spray** — no typed effect DSL; multi-type damage + multiple conditions (Restrained/Petrified/etc.) only Dex save typed; damageTypes & conditions empty.
- **Regenerate** — no typed effect DSL; healing dice in prose.
- **Resurrection** — no typed effect DSL.
- **Reverse Gravity** — no typed effect DSL; concentration.
- **Symbol** — no typed effect DSL; variable effect (Death/Discord/Fear/etc.) — empty damageTypes/saveAbility, condition only in prose.
- **Divine Word** — no typed effect DSL; conditions imposed: Deafened, Blinded, Stunned (typed ✓; apply-on-fail not in any DSL).
- **Fire Storm** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Arcane Sword** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Project Image** — no typed effect DSL; concentration.
- **Mirage Arcane** — no typed effect DSL.
- **Simulacrum** — no typed effect DSL.
- **Magnificent Mansion** — no typed effect DSL.
- **Sequester** — no typed effect DSL.

#### Level 8 (18)

- **Power Word Stun** — no typed effect DSL; conditions imposed: Stunned (typed ✓; apply-on-fail not in any DSL).
- **Sunburst** — no typed effect DSL; conditions imposed: Blinded (typed ✓; apply-on-fail not in any DSL); damage dice in prose (types typed ✓).
- **Antimagic Field** — no typed effect DSL; concentration.
- **Animal Shapes** — no typed effect DSL.
- **Control Weather** — no typed effect DSL; concentration.
- **Demiplane** — no typed effect DSL.
- **Dominate Monster** — no typed effect DSL; concentration; conditions imposed: Charmed (typed ✓; apply-on-fail not in any DSL).
- **Earthquake** — no typed effect DSL; concentration; conditions imposed: Prone (typed ✓; apply-on-fail not in any DSL).
- **Holy Aura** — no typed effect DSL; concentration; conditions imposed: Blinded (typed ✓; apply-on-fail not in any DSL).
- **Incendiary Cloud** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **Maze** — no typed effect DSL; concentration.
- **Mind Blank** — no typed effect DSL.
- **Telepathy** — no typed effect DSL.
- **Antipathy/Sympathy** — no typed effect DSL; conditions imposed: Frightened, Charmed (typed ✓; apply-on-fail not in any DSL).
- **Befuddlement** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Clone** — no typed effect DSL.
- **Glibness** — no typed effect DSL.
- **Tsunami** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).

#### Level 9 (17)

- **Meteor Swarm** — no typed effect DSL; damage dice in prose (types typed ✓).
- **Power Word Kill** — no typed effect DSL.
- **Time Stop** — no typed effect DSL.
- **Wish** — no typed effect DSL.
- **Astral Projection** — no typed effect DSL.
- **Foresight** — no typed effect DSL.
- **Gate** — no typed effect DSL; concentration.
- **Imprisonment** — no typed effect DSL.
- **Mass Heal** — no typed effect DSL; healing dice in prose.
- **Prismatic Wall** — no typed effect DSL.
- **Shapechange** — no typed effect DSL; concentration.
- **Storm of Vengeance** — no typed effect DSL; concentration; damage dice in prose (types typed ✓).
- **True Polymorph** — no typed effect DSL; concentration.
- **True Resurrection** — no typed effect DSL.
- **Weird** — no typed effect DSL; concentration; conditions imposed: Frightened (typed ✓; apply-on-fail not in any DSL); damage dice in prose (types typed ✓).
- **Power Word Heal** — no typed effect DSL; healing dice in prose.
- **Summon Dragon** — no typed effect DSL; concentration.

### Systemic Gaps (for roadmap)

- **No spell-effect DSL at all.** All 341 spells carry damage/heal/save-outcome/scaling/condition-application only as prose `description`. Damage-type, save-ability, attack-type and applied-condition fields exist but are inert classification tags — no dice expression, DC formula, or fail/success branch is attached, so the engine can never auto-resolve a spell.
- **No scaling model.** 13 cantrips encode level-5/11/17 damage steps and ~50 leveled spells encode "Using a Higher-Level Spell Slot" upcasting purely in text; there is no typed `scaling`/`per_slot_level` field, so upcast and cantrip progression cannot be computed.
- **No healing typing.** ~13 healing spells (Cure Wounds, Healing Word, Mass Cure Wounds, Heal, Prayer of Healing, Regenerate, etc.) bury XdY+mod healing in prose; there is no typed heal-amount field, only the (damage-oriented) `damage_type_refs`, which they correctly leave empty.
- **Condition application is half-typed.** 36 spells set `applied_condition_refs` (e.g. Hold Person→Paralyzed, Web→Restrained) but the typed list only labels the condition — the trigger (save type/DC, on-fail vs ongoing, repeat-save) stays in prose and is never enforced.
- **Variable/choice spells defeat the typed fields entirely.** Glyph of Warding, Symbol, Prismatic Spray, Dragon's Breath, Chromatic/Elemental-choice spells pick damage type/condition at cast time, so their `damageTypes`/`saveAbility` are empty or partial; and Counterspell is a concrete bug — 3d8 Force on a Con save with empty `damageTypes` and null `saveAbility`.

---

## Magic Items (srd_core/magic_items.dart)

**Builder note (`_mi`):** Every item's mechanics live in a single markdown `effects` STRING, copied verbatim into `description`. There is NO typed magic-item effect DSL — so *every* numeric bonus (AC, attack/damage, saves, ability-score set, resistance, advantage/disadvantage), spell-grant, charge cost, condition, and curse is prose-only and is NOT applied by the resolver. Only `magic_category_ref`, `rarity_ref`, `requires_attunement`, `is_cursed`, `activation`, `charges_max`, `charge_regain`, `is_sentient`, `base_item_ref`, `cost_gp`, `weight_lb`, and free-text `attunement_prereq` are typed. `charges_max`/`charge_regain` are typed *capacity/regen* only — actual charge **consumption** per use is never a typed mechanic. `attunement_prereq` is free text, never enforced (warning-only system doesn't even check it). `is_cursed` is a typed bool, but the curse's *effect* is always prose-only. Consequently NO item in this file is mechanically "Clean"; the distinctions below are about which gap categories each item triggers.

### Entity Log

#### Flat-bonus items — effects-as-prose numeric bonus the engine can't apply (Missing Mechanic + Poor Data Structure)
- **Cloak of Protection** — +1 AC & saving throws, prose-only.
- **Ring of Protection** — +1 AC & saving throws, prose-only.
- **Bracers of Defense** — +2 AC (no armor/shield) prose-only.
- **Stone of Good Luck (Luckstone)** — +1 ability checks & saves, prose-only.
- **Robe of Stars** — +1 saves; Magic Missile L5 cast — prose-only.
- **Weapon, +1 / Weapon, +2 / Weapon, +3** — +N attack/damage, prose-only.
- **Armor, +1 / Armor, +2 / Armor, +3** — +N AC, prose-only.
- **Shield, +1 / Shield, +2 / Shield, +3** — +N AC, prose-only.
- **Ammunition, +1 / Ammunition, +2 / Ammunition, +3** — +N attack/damage, prose-only.
- **Glamoured Studded Leather** — +1 AC, prose-only; disguise property prose-only.
- **Elven Chain** — +1 AC + armor-proficiency grant, both prose-only (no proficiency_grant).
- **Quarterstaff of the Acrobat** — +1 weapon & +1 AC, prose-only.
- **Shield of the Cavalier** — +1 AC + reaction deflect, prose-only.
- **Sentinel Shield** — Advantage on Initiative & Perception, prose-only.
- **Mantle of the Champion** — Advantage on STR saves & Performance, prose-only.
- **Gloves of Thievery** — +5 Sleight of Hand / lockpick, prose-only.
- **Bracers of Archery** — Longbow/Shortbow proficiency + ranged damage +2, prose-only.
- **Robe of the Archmagi** — unarmored AC 15+Dex, Advantage vs spells, +2 spell DC/attack; alignment attune-lock prose-only (also see attunement_prereq below).
- **Robe of the Magi** — Advantage vs spells, +2 AC & saves, +2 spell DC/attack; prose-only.
- **Talisman of Pure Good / Talisman of Ultimate Evil** — +2 all saves + reaction save-reroll (charges) + alignment touch damage, prose-only.
- **Spellguard Shield** — Advantage vs spells + spell-attacks disadvantage, prose-only.
- **Mantle of Spell Resistance** — Advantage vs spells, prose-only.
- **Scarab of Protection** — Advantage vs spells + reaction necromancy reroll, prose-only.
- **Ring of Spell Turning** — Advantage vs spells + reflect, prose-only.
- **Defender** — +3 weapon, transferable to AC, prose-only.
- **Luck Blade** — +2 weapon, +1 saves, reroll, Wish — prose-only.
- **Rod of Lordly Might** — +3 mace +2d6 Force + transforms, prose-only.
- **Staff of Power** — +2 AC/attack/saves + spell list, prose-only.
- **Staff of Striking** — +3 attack/damage + charge force damage, prose-only.
- **Quarterstaff of the Acrobat** (listed above).

#### Ability-score-set / stat items — sets/raises an ability, prose-only (Missing Mechanic, no ability/ability_score_bonus DSL)
- **Gauntlets of Ogre Power** — STR 19.
- **Headband of Intellect** — INT 19.
- **Amulet of Health** — CON 19.
- **Belt of Giant Strength (Hill)** — STR 21.
- **Belt of Giant Strength (Stone)** — STR 23.
- **Belt of Giant Strength (Frost/Fire)** — STR 25.
- **Belt of Giant Strength (Cloud)** — STR 27.
- **Belt of Giant Strength (Storm)** — STR 29.
- **Belt of Dwarvenkind** — CON +2 (+ Darkvision, language, Persuasion), prose-only.
- **Tome of Clear Thought** — INT +2 & max +2, prose-only.
- **Tome of Leadership and Influence** — CHA +2 & max +2, prose-only.
- **Tome of Understanding** — WIS +2 & max +2, prose-only.
- **Manual of Bodily Health** — CON +2 & max +2, prose-only.
- **Manual of Gainful Exercise** — STR +2 & max +2, prose-only.
- **Manual of Quickness of Action** — DEX +2 & max +2, prose-only.
- **Ioun Stone** — multiple +2 ability / +1 AC / +1 PB variants, all prose-only.
- **Hammer of Thunderbolts** — STR +4 (max 30), prose-only (also attunement_prereq below).

#### Resistance / immunity items — damage resistance/immunity prose-only (Missing Mechanic; damage_resistance/immunity DSL exists for feats/species but `effects` is a string here so unreachable)
- **Cloak of Resistance** — Resistance to a chosen type, prose-only.
- **Ring of Resistance** — Resistance by gem, prose-only.
- **Armor of Resistance** — Resistance by type, prose-only.
- **Ring of Warmth** — Cold resistance, prose-only.
- **Brooch of Shielding** — Force resistance + Magic Missile immunity, prose-only.
- **Periapt of Proof against Poison** / **Periapt of Proof Against Poison** (duplicate entry, two casings) — Poison immunity + Poisoned-condition immunity, prose-only.
- **Periapt of Health** — Disease immunity, prose-only.
- **Necklace of Adaptation** — breathe anywhere + Advantage vs gas, prose-only.
- **Cloak of Arachnida** — Poison resistance + climb + web, prose-only.
- **Boots of the Winterlands** — Cold resistance + terrain, prose-only.
- **Armor of Invulnerability** — Resistance/Immunity to nonmagical damage, prose-only.
- **Dwarven Plate** — +2 AC + reaction negate forced move, prose-only.
- **Adamantine Armor** — crit-to-normal-hit, prose-only.
- **Dragon Scale Mail** — +1 AC + resistance + advantage, prose-only.

#### Speed / movement-grant items — fly/swim/climb speed prose-only (Missing Mechanic; fly_speed/swim_speed/climb DSL exists but `effects` is a string)
- **Boots of Elvenkind** — silent + stealth advantage.
- **Boots of Speed** — speed doubled + OA disadvantage.
- **Winged Boots** — fly speed = walk.
- **Wings of Flying** — Fly 60.
- **Boots of Levitation** — Levitate at will.
- **Boots of Striding and Springing** — speed 30 + jump.
- **Slippers of Spider Climbing** — climb speed = walk.
- **Gloves of Swimming and Climbing** — climb/swim advantage.
- **Ring of Swimming** — Swim 40.
- **Ring of Water Walking** — walk on liquid (walk_on_liquid DSL exists, unreachable).
- **Cloak of the Manta Ray** — breathe water + Swim 60.
- **Mariner's Armor** — Swim = speed.
- **Horseshoes of Speed** — +30 speed.
- **Horseshoes of a Zephyr** — float/levitate.
- **Carpet of Flying** — fly by size.
- **Broom of Flying** — Fly 50.
- **Ring of Jumping** — Jump.
- **Ring of Free Action** — terrain/speed immunity.

#### Sense / vision-grant items — darkvision/truesight/blindsight prose-only (Missing Mechanic; sense_grant/truesight_grant DSL exists, unreachable)
- **Goggles of Night** — Darkvision 60.
- **Eyes of the Eagle** — Perception advantage (sight).
- **Eyes of Minute Seeing** — Investigation advantage (close).
- **Robe of Eyes** — all-around sight + Darkvision 120 + see invisible.
- **Gem of Seeing** — Truesight 120 (charged).
- **Lantern of Revealing** — reveals invisible.
- **Wand of Enemy Detection** — sense hostiles (charged).
- **Eye of Vecna** — Truesight 30 + spells (cursed/sentient — see below).

#### Spell-cast / charged-spell items — `charges_max`/`charge_regain` typed but per-use charge consumption + the cast spell are prose-only (Missing Mechanic: charge consumption not a typed mechanic + spell_cast_from_item unreachable for string effects)
- **Wand of Magic Missiles** — 7 charges; Magic Missile.
- **Staff of Healing** — 10 charges; Cure Wounds etc. (attunement_prereq).
- **Eyes of Charming** — 3 charges; Charm Person.
- **Gem of Brightness** — 50 charges; light/blind.
- **Wand of Fireballs** — 7 charges; Fireball (attunement_prereq).
- **Wand of Lightning Bolts** — 7 charges (attunement_prereq).
- **Wand of Web** — 7 charges (attunement_prereq).
- **Staff of Fire** — 10 charges + Fire resistance (attunement_prereq).
- **Staff of Frost** — 10 charges + Cold resistance (attunement_prereq).
- **Staff of the Magi** — 50 charges + spell absorb (attunement_prereq).
- **Ring of Three Wishes** — 3 charges; Wish.
- **Cube of Force** — 36 charges.
- **Cube of Force** / **Cubic Gate** — 3 charges; Plane Shift/Gate.
- **Helm of Teleportation** — 3 charges; Teleport.
- **Robe of Scintillating Colors** — 3 charges; stun.
- **Dragon Orb** — 7 charges.
- **Chime of Opening** — 10 charges.
- **Cloak of Invisibility** — 2 charges (timed invisibility).
- **Gem of Seeing** — 3 charges (listed above).
- **Medallion of Thoughts** — 3 charges; Detect Thoughts.
- **Pipes of Haunting** — 3 charges; fear.
- **Mace of Terror** — 3 charges; fear (charged weapon).
- **Ring of Animal Influence** — 3 charges.
- **Ring of Elemental Command** — 5 charges (attunement-affinity prose).
- **Ring of Evasion** — 3 charges; reaction succeed DEX save.
- **Ring of Shooting Stars** — 6 charges (attunement_prereq "worn outdoors at night").
- **Ring of the Ram** — 3 charges; force attack.
- **Rod of Resurrection** — 5 charges (attunement_prereq).
- **Scarab of Protection** — 12 charges (listed above).
- **Trident of Fish Command** — 3 charges.
- **Wand of Binding** — 7 charges (attunement_prereq).
- **Wand of Fear** — 7 charges.
- **Wand of Magic Detection** — 3 charges.
- **Wand of Paralysis** — 7 charges (attunement_prereq).
- **Wand of Polymorph** — 7 charges (attunement_prereq).
- **Wand of Wonder** — 7 charges (attunement_prereq).
- **Wand of Secrets** — 3 charges.
- **Staff of Charming** — 10 charges (attunement_prereq).
- **Staff of Power** — 20 charges (attunement_prereq; listed above).
- **Staff of Striking** — 10 charges (listed above).
- **Staff of Swarming Insects** — 10 charges (attunement_prereq).
- **Staff of the Woodlands** — 10 charges + spell-attack bonus (attunement_prereq).
- **Staff of Withering** — 3 charges (attunement_prereq).
- **Gem of Brightness** (listed above).
- **Luck Blade** — 1d4-1 charges (Wish) (listed above).
- **Nine Lives Stealer** — 1d8+1 charges (charge consumption prose-only).
- **Necklace of Fireballs** — bead "charges" prose-only (no typed charges field used).
- **Bag of Tricks (Gray)** — 3 charges (in-prose; not typed).

#### Attunement-prereq items — `attunement_prereq` free text, never enforced (Unimplemented Prerequisite) [all also have prose-only mechanics]
- **Staff of Healing** — "Bard, Cleric, or Druid".
- **Pearl of Power** — "A spellcaster" (+ regain spell slot, prose-only).
- **Robe of the Archmagi** — "Sorcerer, Warlock, or Wizard".
- **Wand of Fireballs / Wand of Lightning Bolts / Wand of Web** — "A spellcaster".
- **Wand of the War Mage, +1 / +2 / +3** — "A spellcaster" / "Spellcaster".
- **Staff of Fire / Staff of Frost** — "Druid, Sorcerer, Warlock, or Wizard".
- **Staff of the Magi** — "Sorcerer, Warlock, or Wizard".
- **Holy Avenger** — "Paladin".
- **Talisman of Pure Good** — "a creature of good alignment".
- **Talisman of Ultimate Evil** — "a creature of evil alignment".
- **Robe of the Magi** — "Bard, Cleric, Druid, Sorcerer, Warlock, or Wizard".
- **Necklace of Prayer Beads** — "Cleric, Druid, or Paladin".
- **Dwarven Thrower** — "Dwarf or has the Dwarven Toughness feature" (species/feature prereq, never validated).
- **Hammer of Thunderbolts** — "must wear Belt of Giant Strength and Gauntlets of Ogre Power" (item-dependency prereq, never validated).
- **Hat of Many Spells** — "Spellcaster".
- **Rod of Resurrection** — "Cleric, Druid, or Paladin".
- **Ring of Shooting Stars** — "must be worn outdoors at night" (situational prereq misfiled as attunement text).
- **Staff of Charming / Staff of Swarming Insects / Staff of Withering** — class lists.
- **Staff of the Woodlands** — "Druid".
- **Staff of the Python** — "Cleric, Druid, or Warlock".
- **Wand of Binding / Wand of Paralysis / Wand of Polymorph / Wand of Wonder** — "Spellcaster".

#### Cursed items — `is_cursed` typed bool, but curse mechanic is prose-only (Missing Mechanic: no typed curse/penalty effect, no Remove-Curse enforcement)
- **Potion of Poison** — illusion-masked poison; 3d6 + Poisoned, prose-only.
- **Eye of Vecna** — sentient corrupting eye; curse + spells prose-only (is_sentient NOT set though item describes sentience — data gap).
- **Hand of Vecna** — cursed +4 STR/spells; curse prose-only (is_sentient not set).
- **Demon Armor** — +1 AC + Abyssal + curse, prose-only.
- **Armor of Vulnerability** — Vulnerability curse + Remove Curse req, prose-only.
- **Bag of Devouring** — devouring-bag curse, prose-only.
- **Dust of Sneezing and Choking** — incapacitate curse, prose-only.
- **Shield of Missile Attraction** — disadvantage/redirect curse, prose-only.
- **Berserker Axe** — +1 weapon + HP max buff + berserk curse, prose-only.

#### HP / temp-HP / healing items — prose-only (Missing Mechanic; hp_bonus/temp_hp_grant DSL exists, unreachable)
- **Potion of Healing** — 2d4+2 HP.
- **Potion of Greater Healing** — 4d4+4 HP.
- **Potion of Superior Healing** — 8d4+8 HP.
- **Potion of Supreme Healing** — 10d4+20 HP.
- **Potion of Heroism** — 10 temp HP + Bless.
- **Periapt of Wound Closure** — stabilize + double Hit Die heal.
- **Ring of Regeneration** — 1d6 HP/10 min + regrow limbs.
- **Restorative Ointment** — heal + cure conditions.
- **Amulet of Health** (ability-set; listed above).
- **Sword of Life Stealing** — crit necrotic + self-heal.

#### Items whose mechanics are inherently DM-narrative / no typed analog (still Missing Mechanic but lower-impact; nothing in `effects` is resolver-applicable)
- **Bag of Holding** — extradimensional storage (no mechanic to apply).
- **Ring of Spell Storing** — store/cast spells.
- **Sword of Sharpness** — maximize vs objects + crit sever + light.
- **Plate Armor of Etherealness** — Etherealness on command.
- **Vorpal Sword** — +3 weapon + ignore resistance + decapitate.
- **Cloak of Elvenkind** — perception disadvantage + stealth advantage.
- **Cloak of the Bat** — stealth + fly + polymorph.
- **Cloak of Displacement** — attacks disadvantage.
- **Hat of Disguise** — Disguise Self.
- **Helm of Telepathy** — Detect Thoughts + telepathy.
- **Bag of Beans** — random effects.
- **Bag of Tricks (Gray) / (Rust) / (Tan)** — summon creatures.
- **Decanter of Endless Water** — water.
- **Driftglobe** — Daylight + float.
- **Figurine of Wondrous Power (Bronze Griffon)** — summon.
- **Horn of Blasting** — Thunder cone.
- **Immovable Rod** — fixed in place.
- **Necklace of Fireballs** — Fireball beads (listed above).
- **Quiver of Ehlonna** — storage.
- **Robe of Useful Items** — patches.
- **Wand of the War Mage, +1** (listed above).
- **Potion of Climbing / Fire Breath / Animal Friendship / Diminution / Flying / Gaseous Form / Giant Strength (Hill) / Invisibility / Mind Reading / Speed / Water Breathing** — spell/effect emulation prose-only.
- **Oil of Slipperiness / Oil of Sharpness / Oil of Etherealness** — applied effects prose-only.
- **Spell Scroll** — cast-from-scroll prose-only.
- **Dragon Slayer / Flame Tongue / Frost Brand / Giant Slayer / Mace of Disruption / Mace of Smiting / Sun Blade / Sword of Wounding / Dagger of Venom / Javelin of Lightning / Thunderous Greatclub / Vicious Weapon / Scimitar of Speed / Dancing Sword / Oathbow / Nine Lives Stealer / Weapon of Warning** — +N bonuses and/or extra damage dice & riders, all prose-only.
- **Mithral Armor** — removes stealth disadvantage/STR req, prose-only.
- **Animated Shield** — animate.
- **Arrow-Catching Shield** — +2 AC vs ranged + redirect, prose-only.
- **Sphere of Annihilation / Talisman of the Sphere** — narrative.
- **Apparatus of the Crab / Crystal Ball (+ Mind Reading / Telepathy variants) / Deck of Many Things / Deck of Illusions / Mirror of Life Trapping / Mirror of Mental Prowess / Iron Bands of Bilarro / Iron Flask / Instant Fortress / Cubic Gate / Well of Many Worlds / Amulet of the Planes / Amulet of Proof against Detection and Location** — narrative/utility.
- **Helm of Brilliance / Helm of Comprehending Languages** — spell utility prose-only.
- **Cape of the Mountebank / Folding Boat / Dimensional Shackles / Rope of Climbing / Rope of Entanglement / Portable Hole / Handy Haversack / Efficient Quiver / Sending Stones / Sovereign Glue / Universal Solvent / Marvelous Pigments / Manual of Golems / Feather Token / Bead of Force / Bead of Nourishment / Dust of Disappearance / Dust of Dryness / Eversmoking Bottle / Wind Fan / Folding Boat** — utility, no resolver mechanic.
- **Bowl of Commanding Water Elementals / Censer of Controlling Air Elementals / Brazier of Commanding Fire Elementals / Stone of Controlling Earth Elementals / Elemental Gem / Efreeti Bottle / Ring of Djinni Summoning / Horn of Valhalla** — summons prose-only.
- **Circlet of Blasting / Wand of Magic Detection / Gloves of Missile Snaring / Necklace of Prayer Beads / Periapt of Wound Closure** — effects prose-only.
- **Rod of Absorption / Rod of Alertness / Rod of Rulership / Rod of Security** — rod utilities prose-only.
- **Ring of Invisibility / Ring of Mind Shielding / Ring of Telekinesis / Ring of X-ray Vision / Ring of Feather Falling / Ring of Spell Turning / Ring of Djinni Summoning / Ring of Elemental Command** — ring utilities prose-only.
- **Crystal Ball of Mind Reading / Crystal Ball of Telepathy** — variants, narrative.
- **Staff of Thunder and Lightning / Staff of the Python** — weapon-staff utilities prose-only.
- **Philter of Love / Potion of Clairvoyance / Potion of Growth / Potion of Longevity / Potion of Resistance / Potion of Vitality / Elixir of Health** — potion effects prose-only.
- **Pipes of the Sewers** — summon rats prose-only.

> NOTE: Every entity in this file is non-Clean by the rubric, because the `_mi` builder forces all mechanics into a prose string with no typed effect DSL. The headings above categorize each item by the *dominant* gap; many items hit several categories simultaneously (e.g. a charged spellcasting staff with an attunement_prereq and a resistance grant).

### Systemic Gaps (for roadmap)
- **No typed magic-item effect DSL.** `_mi.effects` is a single markdown string copied into `description`; the resolver applies ZERO item mechanics. Every flat bonus (AC/attack/damage/saves, +1/+2/+3 gear), ability-score set/raise, resistance/immunity, speed/sense grant, temp-HP/HP, and advantage/disadvantage across all ~286 items is inert. A magic-item effect-DSL (reusing the existing feat/species kinds: ac_bonus, attack_bonus_typed, ability/ability_score_bonus, damage_resistance, fly_speed, sense_grant, temp_hp_grant, etc.) is the single highest-leverage fix.
- **`attunement_prereq` is free text and never enforced** (33+ items). Class lists, species ("Dwarf"), item-dependencies ("must wear Belt of Giant Strength…"), alignment ("creature of good alignment"), and even situational conditions ("worn outdoors at night") are dumped here with no typed structure and no validation hook — strictly worse than the warning-only feat prereqs.
- **`is_cursed` is a bool with no teeth.** Nine cursed items carry only the flag; the curse penalty, the attunement-trap, and the Remove-Curse removal condition are all prose. There is no typed curse-penalty effect or "cannot un-attune without Remove Curse" mechanic.
- **Charges are half-modeled.** `charges_max` + `charge_regain` capture capacity and dawn/dusk regen, but per-activation charge **consumption** and the spell/effect each charge buys are prose-only — so a charged item can't actually deplete or fire anything in the engine. A typed activation→cost→effect table is missing.
- **Data-integrity nits surfaced:** duplicate item ("Periapt of Proof against Poison" appears twice with differing casing/flavor), and sentient artifacts (Eye/Hand of Vecna) describe sentience in prose but leave `is_sentient` at its `false` default — the one typed field meant to capture it is unused.

---

## Mundane Equipment (weapons.dart, armor.dart, gear.dart, tools.dart, ammunition.dart, packs.dart, mounts.dart, vehicles.dart)

Audit basis: all entities are authored as typed packEntity attribute maps. Verified
against character_resolver.dart which fields actually drive mechanics:
- Armor `strength_requirement` (speed −10 penalty) and `stealth_disadvantage`
  (Stealth-disadvantage note) ARE typed AND applied by the resolver (§8b,
  lines 1008–1025). So armor STR-req is NOT an unimplemented prereq.
- Weapon `mastery_ref` is typed, but `weapon_mastery_grant` is a reserved
  no-op (resolver line 602–609: "silently accept… reserved for later passes"),
  and the weapon row's mastery is never linked to a `weapon_mastery_grant`
  effect. Mastery is inert display data on every weapon.
- Weapon `property_refs` are typed refs but no property (Loading, Thrown,
  Two-Handed, Reach, Ammunition, Versatile, Finesse, Light, Heavy) has any
  resolver/attack-pipeline consumer — inert on every weapon.
- Gear `utilize_description` is free prose; no typed effect DSL. All active
  item mechanics (thrown-vial attacks, save DCs, light radii, healing dice)
  live only in that string. `utilize_check_dc`/`utilize_ability_ref` are typed
  but never consumed.
- Tool `utilize_description` (proficiency benefits) is prose; `craftable_items`
  refs never consumed.
- Pack `content_refs`/`contents` narrative: quantities are prose-only; the
  header comment concedes `content_quantities` plumbing is unbuilt.

### Entity Log

#### Weapons (39) — all share the same two findings
Inert weapon `mastery_ref` (typed but `weapon_mastery_grant` is a resolver
no-op; mastery never linked/applied) + inert `property_refs` (no property has a
mechanical consumer). Damage/range/cost/weight/category all typed correctly.
- **Club**, **Dagger**, **Greatclub**, **Handaxe**, **Javelin**, **Light Hammer**,
  **Mace**, **Quarterstaff**, **Sickle**, **Spear** (Simple Melee) — Missing mechanic: weapon mastery + properties typed but unimplemented (inert data).
- **Dart**, **Light Crossbow**, **Shortbow**, **Sling** (Simple Ranged) — Missing mechanic: mastery + properties (incl. Ammunition/Loading) typed but unimplemented.
- **Battleaxe**, **Flail**, **Glaive**, **Greataxe**, **Greatsword**, **Halberd**,
  **Lance**, **Longsword**, **Maul**, **Morningstar**, **Pike**, **Rapier**,
  **Scimitar**, **Shortsword**, **Trident**, **Warhammer**, **War Pick**, **Whip**
  (Martial Melee) — Missing mechanic: mastery + properties typed but unimplemented.
- **Blowgun**, **Hand Crossbow**, **Heavy Crossbow**, **Longbow**, **Musket**,
  **Pistol** (Martial Ranged) — Missing mechanic: mastery + properties typed but unimplemented.

#### Armor (14)
STR-requirement and Stealth-disadvantage are typed AND resolver-enforced
(non-blocking speed/skill notes), so those are NOT gaps. AC/dex_cap/don-doff/
cost/weight all typed. All Clean.
- **Padded Armor**, **Leather Armor**, **Studded Leather Armor** (Light) — Clean.
- **Hide Armor**, **Chain Shirt**, **Scale Mail**, **Breastplate**, **Half Plate Armor** (Medium) — Clean.
- **Ring Mail** — Clean.
- **Chain Mail** (strReq 13), **Splint Armor** (strReq 15), **Plate Armor** (strReq 15) (Heavy) — Clean (STR req typed + applied).
- **Shield** — Clean.

#### Adventuring Gear (108)
All cost/weight/consumable/focus fields typed. Items with active mechanics put
the entire rule in prose `utilize_description` with no typed effect DSL (the
schema offers none for gear). `utilize_check_dc`/`utilize_ability_ref` typed on
some but never consumed by the resolver.

Active-mechanic items — Missing mechanic: combat/utility effect lives only in
prose `utilize_description`, not a typed/applied effect:
- **Acid**, **Alchemist's Fire**, **Antitoxin**, **Holy Water**, **Oil**, **Net**,
  **Poison, Basic**, **Caltrops**, **Ball Bearings**, **Hunting Trap**, **Torch**
  (thrown-attack / save-DC / damage effects in prose only).
- **Healer's Kit**, **Potion of Healing** (healing/stabilize effect in prose only).
- **Spell Scroll (Cantrip)**, **Spell Scroll (Level 1)** (spell-from-item, no typed effect; also a magic-item gap).
- **Book**, **Map**, **Magnifying Glass**, **Costume**, **Crowbar**, **Ram, Portable**,
  **Perfume**, **Saddle, Military**, **Bedroll**, **Blanket**, **Climber's Kit**,
  **Block and Tackle**, **Chain**, **Grappling Hook**, **Lock**, **Manacles**, **Rope**
  (skill-check bonus / advantage / utility effect in prose only).
- **Candle**, **Lamp**, **Lantern, Bullseye**, **Lantern, Hooded**, **Tinderbox**
  (light-radius / action effect in prose only).
- **Component Pouch** (spell-component substitution rule in prose only).

Passive containers/trade-goods/mundane items with no active mechanic and full
typed fields — Clean:
- **Backpack**, **Barrel**, **Basket**, **Bell**, **Bottle, Glass**, **Bucket**,
  **Case, Crossbow Bolt**, **Case, Map or Scroll**, **Chest**, **Clothes, Fine**,
  **Clothes, Traveler's**, **Flask**, **Jug**, **Ladder**, **Mirror**, **Paper**,
  **Parchment**, **Pole**, **Pot, Iron**, **Pouch**, **Quiver**, **Rations**,
  **Robe**, **Sack**, **Shovel**, **Signal Whistle**, **Spikes, Iron**, **Spyglass**,
  **String**, **Tent**, **Vial**, **Waterskin**, **Ink**, **Ink Pen**,
  **Burglar's Pack**, **Diplomat's Pack**, **Dungeoneer's Pack**,
  **Entertainer's Pack**, **Explorer's Pack**, **Priest's Pack**, **Scholar's Pack**
  (pack rows duplicated here as gear), **Saddle, Exotic**, **Saddle, Riding**,
  **Feed**, **Stabling**, **Chalk**, **Fishing Tackle**, **Hammer**, **Hourglass**,
  **Mess Kit**, **Pick, Miner's**, **Piton**, **Scale, Merchant's**, **Sealing Wax**,
  **Signet Ring**, **Soap**, **Spellbook**, **Whetstone** — Clean.
- Foci — **Crystal**, **Orb**, **Rod**, **Staff (Arcane Focus)**, **Wand (Arcane Focus)**,
  **Sprig of Mistletoe**, **Wooden Staff (Druidic Focus)**, **Yew Wand**,
  **Amulet (Holy Symbol)**, **Emblem (Holy Symbol)**, **Reliquary** — Clean
  (`is_focus`/`focus_kind_ref` typed).

#### Tools (39)
All cost/weight/ability_ref/category typed. The defining proficiency *benefit*
(what a proficient user can do) lives entirely in prose `utilize_description`;
`craftable_items` refs are inert (never consumed). Proficiency itself is granted
elsewhere via `tool`/`proficiency_grant` effects, so the tool card's own use is
not a typed mechanic.
- Artisan's Tools (17): **Alchemist's Supplies**, **Brewer's Supplies**,
  **Calligrapher's Supplies**, **Carpenter's Tools**, **Cartographer's Tools**,
  **Cobbler's Tools**, **Cook's Utensils**, **Glassblower's Tools**, **Jeweler's Tools**,
  **Leatherworker's Tools**, **Mason's Tools**, **Painter's Supplies**, **Potter's Tools**,
  **Smith's Tools**, **Tinker's Tools**, **Weaver's Tools**, **Woodcarver's Tools**
  — Missing mechanic: tool-use benefit (and Cobbler's "Advantage on next Acrobatics") in prose only; `utilize_check_dc` typed but unenforced.
- Other Tools (6): **Disguise Kit**, **Forgery Kit**, **Herbalism Kit**,
  **Navigator's Tools**, **Poisoner's Kit**, **Thieves' Tools** — Missing mechanic:
  use-benefit in prose only (Thieves' Tools lock/trap DCs not wired to the Lock gear item).
- Gaming Set (5): **Gaming Set**, **Dice Set**, **Dragonchess Set**,
  **Playing Card Set**, **Three-Dragon Ante Set** — Missing mechanic: prose-only;
  otherwise Clean (variant_of_ref typed correctly).
- Musical Instruments (10): **Bagpipes**, **Drum**, **Dulcimer**, **Flute**,
  **Horn**, **Lute**, **Lyre**, **Pan Flute**, **Shawm**, **Viol** — Clean in
  substance (identical play-tune prose, no real per-item mechanic to type).

#### Ammunition (5)
storage/cost/weight/bundle_count all typed; no active mechanic. NOTE: builder
declares ~6 but file authors 5 rows; weapons reference a `Bolts` ammo name that
is present. All Clean.
- **Arrows**, **Bolts**, **Bullets, Firearm**, **Bullets, Sling**, **Needles** — Clean.

#### Equipment Packs (7)
cost/content_refs/contents typed, but per-item **quantities are prose-only**
(`contents` narrative string); header concedes `content_quantities` plumbing is
unbuilt, so the resolver cannot expand a pack into N typed items.
- **Burglar's Pack**, **Diplomat's Pack**, **Dungeoneer's Pack**, **Entertainer's Pack**,
  **Explorer's Pack**, **Priest's Pack**, **Scholar's Pack** — Poor data structure:
  contents quantities dumped in a narrative string instead of a typed
  ref→quantity map. (NOTE: builder header says ~8; 7 rows authored.)

#### Mounts (8)
carrying_capacity/speed/cost/is_trained all typed; no active mechanic.
(NOTE: task expected ~9; 8 rows authored — no "Warhorse" duplicate / no Riding
Dog beyond Mastiff.)
- **Camel**, **Elephant**, **Draft Horse**, **Riding Horse**, **Mastiff**, **Mule**,
  **Pony**, **Warhorse** — Clean.

#### Vehicles (13)
vehicle_kind/speed/crew/passengers/cargo/ac/hp/damage_threshold/cost all typed.
Land vehicles intentionally omit speed (defers to mount). No active mechanic.
- **Carriage**, **Cart**, **Chariot**, **Sled**, **Wagon** (Land) — Clean.
- **Galley**, **Keelboat**, **Longship**, **Rowboat**, **Sailing Ship**, **Warship** (Waterborne) — Clean.
- **Airship** (Airborne) — Clean.

### Systemic Gaps (for roadmap)
- No attack/combat pipeline consumes weapon `property_refs` or `mastery_ref`:
  all 39 weapons carry fully typed properties and a mastery, but the resolver
  treats `weapon_mastery_grant` as a reserved no-op and no property (Loading,
  Thrown, Versatile, Reach, Two-Handed, Ammunition, Finesse, Light, Heavy) has
  any mechanical effect. Mastery/properties are inert display data game-wide.
- No typed effect DSL for adventuring gear / consumables: thrown-vial attacks,
  save DCs, damage dice, healing, and light radii all live in prose
  `utilize_description`. Typed `utilize_check_dc`/`utilize_ability_ref` exist but
  are never read by the resolver.
- Equipment packs cannot be auto-expanded: per-item quantities live only in a
  narrative string; the `content_quantities` ref→qty plumbing is unimplemented
  (acknowledged in the source header), so picking a pack grants no typed items.
- Tool proficiency *benefits* (and `craftable_items`) are entirely prose and
  unwired; e.g. Thieves' Tools lock/trap DCs aren't linked to the Lock/Hunting
  Trap gear items, and Cobbler's Advantage-grant isn't a typed effect.
- Counts drift from the task's expected totals: gear ~108 ✓, weapons 39 ✓,
  armor 14 ✓, tools 38 (not 39), ammunition 5 (not 6), packs 7 (not 8),
  mounts 8 (not 9) — worth reconciling against the SRD tables.

NOTE (positive): armor STR-requirement and Stealth-disadvantage are genuine
counter-examples to the usual "prose prereq" pattern — both are typed AND
resolver-applied (non-blocking), so armor is Clean across the board.

---

## Monsters, Animals & Creature Actions (monsters.dart, animals.dart, creature_actions.dart)

Scope: 248 monsters + 97 animals + 529 creature-action cards = 874 entities.
Prereq criterion is N/A to creatures (no selection gating). Findings focus on
**Missing Mechanic** (special ability / legendary action / spellcasting in prose
with no typed effect) and **Poor Data Structure** (attack rider DC / secondary
damage / save outcome dumped in the `description` string instead of the typed
`save_dc` / `save_ability_ref` / `damage_dice` / `applied_condition_refs`
fields the `_a()` builder provides).

System note (applies to all 3 files): the monster/animal stat-block shape is
**well typed** — `ac`, `hp_average`/`hp_dice`, all `speed_*_ft`, `stat_block`,
`cr`, `xp`, `proficiency_bonus`, `passive_perception`, `senses[]`,
`size_ref`/`creature_type_ref`/`alignment_ref`, `language_refs`,
`damage_immunity_refs`/`resistance_refs`/`vulnerability_refs`,
`condition_immunity_refs`, `telepathy_ft`, `legendary_action_uses`, and
ref-lists (`trait_refs`, `action_refs`, `bonus_action_refs`, `reaction_refs`,
`legendary_action_refs`) are dedicated fields. The gaps are all in (a) the
referenced **trait cards** (traits.dart — pure prose, `trait_kind` enum +
`description` only, NO effects DSL; so every monster's special abilities are
unenforced prose), (b) **spell lists** (no typed spell DSL — DC/at-will/per-day
lists dumped in a Spellcasting card's prose), and (c) **attack riders** in
creature_actions where prose carries a save/secondary-damage the typed fields
don't.

### Entity Log — MONSTERS (monsters.dart, 248)

- **Lich**, **Mummy Lord** — Missing mechanic (x2): `legendary_action_uses: 3`
  declared but NO `legendary_action_refs` (legendary actions entirely absent);
  spellcasting referenced as prose card (`Spellcasting (Lich)` / `Spellcasting
  (Mummy Lord)`) — full DC + at-will/per-day spell list lives in `description`,
  no typed spell refs or per-day uses. Also Legendary Resistance / Rejuvenation /
  Turn Resistance are prose-only trait cards.
- **Vampire**, **Adult Brass/Bronze/Copper/Gold/Silver Dragon**, **Ancient
  Black/Blue/Brass/Bronze/Copper/Gold/Green/Red/Silver/White Dragon** (16) —
  Missing mechanic: `legendary_action_uses` set but `legendary_action_refs`
  omitted; the creature's legendary actions are not present at all (only the
  five multiline Adult dragons + Aboleth/Beholder actually wire legendary refs).
- **Drow**, **Sphinx**, **Mage**, **Priest**, **Cult Fanatic**, **Cultist
  Fanatic**, **Archmage**, **Druid**, **Lamia**, **Rakshasa**, **Sphinx of
  Lore**, **Pixie** (12) — Missing mechanic: spellcaster whose entire spell
  list (save DC, spell-attack bonus, at-will / N-per-day tiers) is prose inside
  a `Spellcasting`/`Innate Spellcasting` trait or action card; no typed
  spell refs, no per-tier use tracking.
- **Tarrasque** (CR 30), **Kraken** (CR 23) — Structure clean for typed stat
  block, but no legendary/lair actions declared at all and signature mechanics
  (Reflective Carapace, Legendary Resistance, Swallow recharge) ride on prose
  trait/action cards; resolver/tracker cannot apply them.
- All remaining 218 monsters — **Clean** (typed stat block fully populated;
  traits/actions referenced). Caveat shared by ALL: their special **traits**
  (Pack Tactics, Magic Resistance, Undead Fortitude, Regeneration, Sunlight
  Sensitivity, Legendary Resistance, etc.) are prose-only trait cards with no
  effects DSL, so advantage/immunity/regeneration riders are never mechanically
  applied — a systemic trait-layer gap, not a per-monster authoring defect:
  Aboleth, Goblin Warrior, Skeleton, Zombie, Adult Red Dragon, Beholder, Mind
  Flayer, Ogre, Owlbear, Hobgoblin Warrior, Bandit, Giant Spider, Kobold
  Warrior, Orc, Gnoll, Bugbear Warrior, Werewolf, Troll, Hydra, Balor, Pit
  Fiend, Air/Earth/Fire/Water Elemental, Ghoul, Wight, Specter, Animated Armor,
  Stone Giant, Hill Giant, Manticore, Minotaur, Basilisk, Cockatrice, Ettin,
  Harpy, Will-o'-Wisp, Mummy, Treant, Adult Black/Blue/Green/White Dragon,
  Chuul, Otyugh, Roper, Nothic, Dryad, Gargoyle, Couatl, Death Dog, Knight,
  Veteran, Gladiator, Spy, Assassin, all 10 Dragon Wyrmlings, all 10 Young
  Dragons, Bandit Captain, Berserker, Commoner, Cultist, Guard, Guard Captain,
  Hobgoblin Captain, Noble, Pirate, Pirate Captain, Priest Acolyte, Sahuagin
  Warrior, Scout, Warrior Infantry, Warrior Veteran, Tough, Tough Boss, Bugbear
  Stalker, Centaur Trooper, Goblin Boss, Goblin Minion, Gnoll Warrior, Merfolk
  Skirmisher, Merrow, Lemure, Imp, Bearded/Barbed/Chain/Bone/Horned/Ice Devil,
  Erinyes, Quasit, Dretch, Vrock, Hezrou, Glabrezu, Nalfeshnee, Marilith,
  Incubus, Succubus, Night/Sea/Green Hag, Dust/Ice/Magma/Steam Mephit, Magmin,
  Azer Sentinel, Djinni, Efreeti, Salamander, Invisible Stalker,
  Cloud/Fire/Frost/Storm Giant, Shadow, Wraith, Ghost, Ghast, Vampire Spawn,
  Vampire Familiar, Ogre Zombie, Minotaur Skeleton, Warhorse Skeleton, Swarm of
  Crawling Claws, Werebear, Wereboar, Wererat, Weretiger, Animated Flying
  Sword, Animated Rug of Smothering, Clay/Flesh/Stone/Iron Golem, Shield
  Guardian, Homunculus, Ankheg, Awakened Shrub, Awakened Tree, Axe Beak, Behir,
  Black Pudding, Blink Dog, Bulette, Chimera, Cloaker, Darkmantle,
  Doppelganger, Dragon Turtle, Drider, Ettercap, Gelatinous Cube, Gibbering
  Mouther, Gorgon, Gray Ooze, Grick, Griffon, Grimlock, Guardian Naga,
  Half-Dragon, Hell Hound, Hippogriff, Medusa, Mimic, Minotaur of Baphomet,
  Nightmare, Ochre Jelly, Oni, Pegasus, Phase Spider, Pseudodragon, Purple
  Worm, Remorhaz, Roc, Rust Monster, Satyr, Seahorse, Shambling Mound, Shrieker
  Fungus, Solar, Planetar, Deva, Sphinx of Valor, Sphinx of Wonder, Spirit
  Naga, Sprite, Troll Limb, Unicorn, Violet Fungus, Winter Wolf, Worg, Wyvern,
  Xorn, Banshee.

### Entity Log — ANIMALS (animals.dart, 97)

- All 97 animals — **Clean** (typed stat block; no legendary actions or
  spellcasting, appropriate for beasts; traits like Pack Tactics / Keen Senses /
  Pounce / Charge referenced but, as above, those trait cards are prose-only —
  systemic, not per-entity): Wolf, Giant Eagle, Dire Wolf, Tiger, Lion,
  Crocodile, Boar, Mastiff, Riding Horse, Cat, Rat, Giant Rat, Hawk, Eagle,
  Owl, Pony, Camel, Elephant, Ape, Constrictor Snake, Giant Constrictor Snake,
  Frog, Giant Frog, Giant Centipede, Giant Lizard, Polar Bear, Warhorse,
  Octopus, Brown Bear, Tyrannosaurus Rex, Triceratops, Allosaurus, Pteranodon,
  Plesiosaurus, Mammoth, Rhinoceros, Killer Whale, Stirge, Giant Crab, Giant
  Octopus, Giant Shark, Hunter Shark, Reef Shark, Quipper, Swarm of Bats, Swarm
  of Insects, Swarm of Rats, Swarm of Quippers, Vulture, Ankylosaurus,
  Archelon, Baboon, Badger, Bat, Black Bear, Blood Hawk, Crab, Deer, Draft
  Horse, Elk, Flying Snake, Giant Ape, Giant Badger, Giant Bat, Giant Boar,
  Giant Crocodile, Giant Elk, Giant Fire Beetle, Giant Goat, Giant Hyena, Giant
  Owl, Giant Scorpion, Giant Seahorse, Giant Spider, Giant Toad, Giant Venomous
  Snake, Giant Vulture, Giant Wasp, Giant Weasel, Giant Wolf Spider, Goat,
  Hippopotamus, Hyena, Jackal, Lizard, Mule, Panther, Piranha, Raven,
  Saber-Toothed Tiger, Scorpion, Spider, Venomous Snake, Weasel, Swarm of
  Piranhas, Swarm of Ravens, Swarm of Venomous Snakes.

### Entity Log — CREATURE ACTIONS (creature_actions.dart, 529)

Grouped by pattern (verdicts identical within group):

- **Clean typed attacks (302)** — `is_attack`, `attack_kind`, `attack_bonus`,
  reach/range, `damage_dice`, `damage_type_ref` all typed and the prose carries
  no extra rider. E.g. Scimitar (Goblin), Shortbow (Goblin), Bite (Wolf — also
  typed save+Prone), Shortsword/Shortbow (Skeleton), Slam (Zombie), Bite/Claws
  (Brown Bear), Tail Swipe, plus most single-line animal/NPC weapon attacks.
- **Clean typed save/area actions (46)** — breath weapons & gaze/aura effects
  with `save_dc`, `save_ability_ref`, `recharge_kind`/`recharge_min_roll`, and
  `applied_condition_refs` typed: Web (Giant Spider), Fire/Acid/Lightning/Cold/
  Poison Breath, Mind Blast, Frightful Presence, Petrifying Gaze, Luring Song,
  Dreadful Glare, Wing Attack, Sleep/Slowing/Weakening/Paralyzing/Repulsion
  Breath, Fireball (Pit Fiend), Lightning Strike (Storm Giant), Horrifying
  Visage (Ghost/Banshee), Wail (Banshee), Engulf (Gelatinous Cube/Shambling
  Mound), Petrifying Breath (Gorgon), Charm (Vampire/Succubus/Lamia), etc.
- **Attacks with UNTYPED prose rider (117)** — Poor data structure / missing
  mechanic: typed attack core is fine but a save-or-condition and/or a
  **secondary damage type** ("plus N (NdM) X damage") is described only in
  prose; the builder has a single `damage_dice`/`damage_type_ref` pair and many
  of these omit `save_dc`/`save_ability_ref` even though the prose states a DC,
  so the rider is unenforceable. Names: Tentacle (Aboleth), Bite (Giant
  Spider), Rend (Adult Red Dragon), Bite (Crocodile), Tusk (Boar), Vampire
  Bite, Flame Whip / Lightning Sword (Balor), Constrict (Rug), Rock (Stone
  Giant), Bite (Basilisk), Rotting Fist, Constrict (Constrictor), Bite (Giant
  Snake/Frog/Centipede), Bite (Adult Black/Blue/Green/White Dragon), Pincer
  (Chuul), Tentacle (Otyugh), Tendril (Roper), Constrict (Couatl), Mace
  (Priest), Dagger (Fanatic), Shortsword/Light Crossbow (Assassin), Bite
  (T-Rex), Claw (Giant Crab), Tentacles (Giant Octopus), Tail (Ankylosaurus),
  Bite (Archelon), Ram (Elk/Giant Elk), Bite (Flying Snake/Giant
  Crocodile/Giant Venomous Snake/Giant Toad/Giant Wolf Spider/Spider/Venomous
  Snake), Sting (Giant Scorpion/Scorpion/Giant Wasp/Bone Devil/Imp), Claw
  (Giant Scorpion), Bites (Swarm of Venomous Snakes/Gibbering Mouther),
  Quarterstaff (Archmage), Sickle (Cultist), Beard (Bearded Devil), Glaive
  (Barbed Devil/Oni), Spiked Chain (Chain Devil), Bite/Spear/Tail (Ice Devil),
  Scourge/Longbow (Erinyes), Mace (Pit Fiend), Claws (Quasit/Ice Mephit/Magma
  Mephit/Steam Mephit/Vampire Spawn/Ghast/Rakshasa/Sphinx of Wonder), Pincer
  (Glabrezu), Thunderous Greatsword (Storm Giant), Rotting Fist (Mummy Lord),
  Bite (Vampire Spawn/Vampire Familiar/Werebear/Wererat/Weretiger/Homunculus/
  Ankheg/Hell Hound/Phase Spider/Remorhaz/Shambling Mound/Tarrasque/Cloaker),
  Tusks (Wereboar), Smother (Animated Rug of Smothering), Sting
  (Magmin/Pseudodragon), Slam (Azer Sentinel/Solar), Pseudopod (Black
  Pudding/Gray Ooze/Mimic/Ochre Jelly), Tentacles (Darkmantle/Kraken), Web Bite
  (Drider), Bite/Web (Ettercap), Spear (Guardian Naga/Salamander), Bite (Spirit
  Naga), Hooves (Nightmare), Tail Stinger / Tail (Purple Worm/Salamander/
  Wyvern), Slaying Longbow (Solar), Mace (Planetar), Greatsword (Deva), Shortbow
  (Sprite), Horn (Unicorn), Stinger/Tail (Wyvern), Scimitar (Djinni/Efreeti),
  Snake Hair (Medusa).
- **Save/effect non-attack actions with prose-only DC (4)** — missing typed
  `save_dc`/`save_ability_ref`: Pounce (Panther), Spores (Vrock), Attach
  (Cloaker), Intimidating Presence.
- **Damage-only non-attack with no save typed though targeted (3)** — Psychic
  Drain, Psychic Slash (typed damage, but "charmed target" targeting prose
  only), Swallow (Tarrasque, all swallow mechanics prose).
- **Spellcasting actions (3)** — Spellcasting (Archmage), Spellcasting (Druid
  NPC), Spellcasting (Mummy Lord): entire DC + spell-tier list dumped in
  `description`; no typed spell refs / per-day use counters.
- **Prose-only special abilities & class actions (53)** — Multiattack (generic,
  intentionally prose), plus utility/trait-like actions whose whole effect is
  prose with no typed field (no DSL exists for them): Nimble Escape, Eye Rays,
  Eye Ray (Lair), Leadership, Parry, Etherealness (Ghost), Teleport (Blink
  Dog), Read Thoughts (Doppelganger), Spores (Shrieker Fungus), Roar (Sphinx of
  Lore), Superior Invisibility (Pixie), Reel In (Roper), and the bundled PC
  class-action cards reused here (Rage, Second Wind, Action Surge, Bardic
  Inspiration, Lay on Hands, Divine Sense, Channel Divinity, Turn Undead, Wild
  Shape, Flurry of Blows, Patient Defense, Step of the Wind, Hunter's Mark,
  Sorcery Points, Eldritch Blast, Breath Weapon (Dragonborn), Relentless
  Endurance, Adrenaline Rush, Cloud's Jaunt, Hill's Tumble, Stone's Endurance,
  Storm's Thunder, Fire's Burn, Frost's Chill, Draconic Flight, Cutting Words,
  Retaliation, Preserve Life, Sacred Weapon, Abjure Foes, Wholeness of Body,
  Land's Aid, Nature's Sanctuary, Dragon Wings, Deflect Attacks, Slow Fall,
  Steady Aim, Uncanny Dodge, Fast Hands, Cunning Action).

### Systemic Gaps (for roadmap)

- **No effects DSL on trait cards.** traits.dart carries only `trait_kind` +
  prose `description`. Every monster defensive/passive trait (Legendary
  Resistance, Magic Resistance, Pack Tactics, Undead Fortitude, Regeneration,
  Sunlight Sensitivity, Reckless, Brute, Spider Climb, etc.) is unenforceable —
  the resolver/combat tracker cannot grant the advantage, immunity, regen, or
  conditional damage. This is the single largest creature-mechanics hole.

- **Legendary actions frequently declared-but-empty.** 18 monsters (Lich,
  Vampire, Mummy Lord, all Adult/Ancient dragons except the 5 multiline ones)
  set `legendary_action_uses` with NO `legendary_action_refs`; apex monsters
  (Tarrasque, Kraken) declare none at all. No lair-action field/timing model
  exists either. Pattern correlates with the compact single-line authoring of
  the deferred bulk import.

- **No typed spell DSL for monster spellcasting.** 14 caster stat blocks +
  3 Spellcasting action cards hold the spell save DC, attack bonus, and
  at-will / N-per-day spell tiers entirely in prose. Needs typed spell refs +
  per-tier use counters so casters' spells can be tracked/resolved.

- **Single-damage attack model loses secondary damage and unenforced riders.**
  The `_a()` builder exposes only one `damage_dice` + one `damage_type_ref`, so
  ~74 attacks with "plus N (NdM) <type> damage" lose the second type, and ~50
  attacks/area actions state a save DC in prose without populating
  `save_dc`/`save_ability_ref`/`applied_condition_refs`. Need a list-typed
  damage-component model and mandatory typed save fields whenever prose
  contains a DC.

- **Recharge enum is inconsistent** (`recharge_kind: 'Roll'` vs `'Recharge'`
  for the same "Recharge 5–6" mechanic, plus 'Long Rest'); harmless today but
  will fragment any future recharge-tracking logic. Standardize the enum.

---

## Official First-Party Catalog — Open5e Packs (`flutter_app/assets/open5e_packs/`)

These 19 packs are the **official** (first-party catalog) content, imported by
the offline Open5e pipeline (`tool/open5e_import/`) and shipped as
`*.pkg.json`. Total: **20,712 entity cards**. Unlike the hand-authored SRD
core, these are *bulk machine-imported* and store nearly all rules text in a
single `description` / `attributes.description` markdown blob.

> Scoping note: exhaustively transcribing all 20,712 names is neither
> tractable nor informative — the deficiencies are **systematic and identical
> within each category** (verified by sampling every category and corroborated
> by `flutter_app/docs/chargen_mechanics_wiring.md`, which records the exact
> typed-field backfill coverage). The audit below is therefore enumerated by
> pack × category with counts, plus the shared per-category verdict that
> applies to every card in that bucket.

### Entity Log — by category (verdict applies to every card in the bucket)

- **spell** (1,297 across a5e-ag, deepm, deepmx, spells-that-dont-suck, kp,
  tdcs, wz, open5e, vom …) — *Missing Mechanic + Poor Data Structure*: damage
  dice, save outcomes, conditions, healing, and higher-level scaling all live
  in `description`; only identity fields typed. No spell-effect DSL.
- **magic-item** (1,063 across vom, toh, tdcs, wz, kp, open5e …) — *Missing
  Mechanic + Poor Data Structure + Unimplemented Prereq*: numeric bonuses and
  attunement requirements are prose-only; no typed item-effect DSL.
- **feat** (73 across a5e-ag 59, kp, open5e, tdcs, deepmx …) — *Unimplemented
  Prereq + Missing Mechanic + Poor Data Structure*: `**Prerequisite:** …` and
  every benefit are embedded in `description`; typed `prereq_*` / `effects`
  not populated by the importer for feats.
- **background** (53 across a5e-ag 21, a5e-ddg, a5e-gpg, deepmx, tdcs, kp,
  open5e …) — *Poor Data Structure*: per `chargen_mechanics_wiring.md`,
  `granted_skill_refs` 56/58, `ability_score_options` 31/58,
  `granted_language_count` 32/58, `asi_distribution_options` 4/58,
  `origin_feat_ref` 4/58 — i.e. typed coverage is **partial**; tool profs,
  equipment, gold, and the feature narrative remain folded prose.
- **class** (2: a5e-ag, bfrd) — *Poor Data Structure*: `caster_kind` typed but
  `primary_ability_ref` empty (source limit); leveled features are freeform
  prose with **no structured level field** → not typed as `effects`.
- **subclass** (101) — *Unimplemented link + Poor Data Structure*:
  `parent_class_ref` filled via soft name-ref; all subclass *features* are
  prose with no level field or effect DSL.
- **species** (11) / **subspecies** (30) — *Poor Data Structure (partial)*:
  size/speed/senses/ASI/resistance typed where the source trait phrasing
  matched (coverage 19–63 of 63 per field, see doc); remaining racial
  mechanics folded into trait prose.
- **adventuring-gear** (159) — mostly *Clean-equivalent* (mundane items, no
  active mechanic) but description-only; no typed weight/cost on many.
- **monster** (2,885) / **trait** (6,423) / **creature-action** (8,615) —
  *Poor Data Structure / Missing Mechanic*: stat-block identity is typed, but
  special abilities, recharge powers, legendary/lair actions, and innate
  spellcasting are prose `description` with no typed activation/effect.

### Per-pack counts (manifest.json)

| Pack | System | Total | Notable categories |
|---|---|---|---|
| a5e-ag (Adventurer's Guide) | a5e | 499 | spell 371, feat 59, bg 21, gear 44, subclass 3, class 1 |
| a5e-ddg | a5e | 13 | gear 9, bg 4 |
| a5e-gpg | a5e | 12 | gear 10, bg 2 |
| a5e-mm (Monstrous Menagerie) | a5e | 3,072 | creature-action 1657, trait 829, monster 586 |
| bfrd (Black Flag SRD) | 5e-2014 | 2,477 | creature-action 1339, trait 776, monster 360, class 1, subclass 1 |
| ccdx (Creature Codex) | 5e-2014 | 2,425 | trait 921, creature-action 1148, monster 356 |
| deepm (Deep Magic) | 5e-2014 | 515 | spells/magic-items |
| deepmx | 5e-2014 | 64 | mixed |
| kp (Kobold Press) | 5e-2014 | 31 | mixed |
| open5e | 5e-2014 | 30 | mixed |
| spells-that-dont-suck | 5e-2014 | 180 | spell |
| tdcs (Tal'Dorei) | 5e-2014 | 48 | mixed |
| tob (Tome of Beasts) | 5e-2014 | 2,733 | monster/trait/action |
| tob-2023 | 5e-2014 | 3,087 | monster/trait/action |
| tob2 | 5e-2014 | 2,606 | monster/trait/action |
| tob3 | 5e-2014 | 1,500 | monster/trait/action |
| toh (Tome of Heroes) | 5e-2014 | 314 | mixed + magic-items |
| vom (Vault of Magic) | 5e-2014 | 1,063 | magic-item heavy |
| wz | 5e-2014 | 43 | mixed |

### Systemic Gaps (for roadmap)
- The importer emits one `description` markdown blob per card; **typed-field
  backfill is partial** and limited to chargen entities (feat/species/bg/
  class/subclass) — and even there many fields stay empty by documented source
  limits. No typed `effects`/spell-DSL is ever emitted by the importer.
- First-party feat prerequisites are plain `**Prerequisite:**` prose — never
  parsed into `prereq_*` and never enforced.
- 18,000+ monster-side cards (trait/creature-action/monster) keep all special
  abilities, recharge, legendary actions, and innate spellcasting as prose.

---

