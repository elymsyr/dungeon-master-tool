# System Mechanics Roadmap

> Automated System-Architecture Inspection — official + built-in package audit.
> Audit date **2026-06-10** · branch `list` · read-only (no source files modified).
> Companion ledger: [`entity_audit_log.md`](entity_audit_log.md)

This document summarizes the **global, system-wide deficiencies** surfaced by auditing
every official and built-in content package against three criteria: *unimplemented
prerequisites*, *missing mechanics*, and *poor data structure*. Per-entity findings live
in [`entity_audit_log.md`](entity_audit_log.md).

## Scope audited

| Source | Where | Entities | Notes |
|---|---|---|---|
| **Built-in SRD 5.2.1 Core pack** | `flutter_app/lib/domain/entities/schema/builtin/srd_core/*.dart` (`buildSrdCorePack`, `srdCorePackVersion 1.0.3`) | ~1,900 | Hand-authored; the most mechanically-typed content. |
| **Official first-party packs** | `flutter_app/assets/open5e_packs/*.pkg.json` (19 packs) + `assets/first_party/manifest.json` (catalog `2026-06-01`) | ~20,700 | Open5e / A5E / Kobold Press imports; typed-field coverage partial by the original descriptive policy. |

Effect application is performed by the pure resolver `character_resolver.dart`, which already
supports ~110 typed effect kinds. The audit measures how much of each entity's *described*
behaviour is actually expressed in resolver-readable typed fields versus dumped into prose.

---

## 1. Missing system-wide mechanics & rules

### 1.1 Prerequisite validation is incomplete and partly incorrect

The system can gate feats on a **single ability score** + **character level** only, plus an
optional typed `prereq_clauses` list. Everything else described as a "requirement" is
cosmetic text the system does not enforce.

- **`prereq_requires_spellcasting` is never consumed.** The field exists and is authored
  (Elemental Adept, Spell Sniper, War Caster, Boon of Spell Recall…) but no code path reads
  it. Spellcasting prerequisites are unenforced everywhere.
- **No armor/weapon-proficiency prerequisite mechanic.** "Proficiency with Heavy Armor /
  Medium Armor / Shields" (Heavy/Medium Armor Master, Shield Master, Moderately Armored)
  exists only inside the narrative `prerequisite` string — no typed field, no enforcement.
- **No OR-of-ability prerequisite on built-in feats.** The flat `prereq_ability_ref` holds a
  single ability, so "Strength *or* Dexterity 13+" (Grappler) cannot be expressed; Grappler
  even ships `prereq_min_score: 13` with **no** `prereq_ability_ref`, so its ability gate is
  silently dropped. The richer `prereq_clauses` form *can* model OR, but **no built-in SRD
  feat carries `prereq_clauses`** — only some imported packs do, and those drop non-ability
  clauses.
- **Non-ability prerequisites are entirely unrepresentable.** Official packs contain race/size
  ("A Small or smaller race" — Giant Foe), class-feature ("Ki/Sorcery Points feature"),
  trait/spell ("Shadow Traveler trait or *misty step*" — Harrier), vehicle-proficiency
  (Ace Driver), weapon-proficiency (Stunning Sniper), and "prestige"-style prerequisites
  (Well-Heeled). None has any typed representation.
- **Multiclass prerequisite uses the wrong default and a missing schema field.**
  `multiclass_helper.dart` treats a multi-ability list as **AND** unless the class declares
  `multiclass_prereq_any_of: true`. That flag is **not defined in the schema**
  (`content.dart`) and **not set by any class**. Result: **Fighter** (SRD: "Strength 13 *or*
  Dexterity 13") is enforced as STR 13 **AND** DEX 13 — a correctness bug, not just a gap.
  (Paladin STR+CHA, Ranger DEX+WIS, Monk DEX+WIS are correctly AND.)
- **Magic-item attunement restriction is unenforceable.** The `requires_attunement` boolean is
  typed, but the *restriction* ("by a spellcaster", "by a Paladin", "by a creature of good
  alignment") is free text on only ~32/286 built-in items and **0/1063** in the Vault of Magic
  pack (the clause is dropped from the imported text entirely). It is also inconsistent
  ("A spellcaster" vs "Spellcaster"). No reliable gate is possible.

### 1.2 Class / subclass / species feature mechanics are not resolved

The typed `effects` system is wired **only to `feat` entities** (`character_resolver.dart`
reads `feat.fields['effects']`). As a consequence:

- **All 12 classes and all 12 subclasses (built-in) carry zero typed mechanics.** Signature
  features — Rage, Sneak Attack, Channel Divinity, **Aura of Protection** (+CHA to saves),
  Sorcery Points, Pact slots, crit-range expansion (Champion 19–20 → 18–20), Martial Arts die —
  live entirely in prose `description` or in a name-referenced `trait`/`creature-action` whose
  body is also prose. None is machine-resolved.
- **Species passive traits are prose-only.** Species carry a typed physical chassis
  (`size_ref`, `speed_ft`, `creature_type_ref`, `granted_senses`, resistances) and action-economy
  traits via action refs, but passive mechanics referenced through `trait_refs` (Dwarven
  Resilience, Gnomish Cunning, Brave, Halfling Lucky, Powerful Build, Human Skilled/Versatile,
  Otherworldly Presence…) resolve to nothing — the underlying `trait` rows hold only a
  `description`, no typed effects, despite the resolver already supporting `advantage_on`,
  `damage_resistance`, `resource_pool_grant`, `spell_grant`, `proficiency_grant`,
  `ability_score_bonus`, etc.
- **Class/subclass *option* feats (`feats_class.dart`, 155 entities) routinely ship empty
  `effects`.** Many have obvious resolver candidates left unimplemented: Colossus Slayer
  (`extra_damage_on_attack`), Steel Will / Eldritch Mind (`advantage_on`), Pact of the Tome /
  Evocation Savant (`cantrip_count_bonus`), Draconic Ancestor spells (`spell_always_prepared`),
  Elemental Affinity / Fiendish Resilience gateway (`damage_resistance`), Body and Mind
  (`ability_score_bonus`).

### 1.3 Spell damage & scaling are not machine-readable

Spells are otherwise well-typed (school, range, components, duration, concentration,
`class_refs`, `save_ability_ref`, `damage_type_refs`, `applied_condition_refs`), but:

- **No typed damage-dice field and no higher-level / cantrip scaling table.** "8d6",
  "+1d6 per slot above 3rd", and cantrip upgrade tables (Fire Bolt 1d10 → 4d10) live only in
  prose. The system knows a spell's *save* and damage *type* but not its *magnitude* — it
  cannot compute or scale spell damage. True for built-in spells (341) and ~1,100 spells across
  the official packs (where `damage` / `effects` / `higher_level` = 0).

### 1.4 Magic-item effects have no typed representation

- **Magic-item `effects` is a single prose string — literally equal to the description.** Zero
  resolver-applicable effect rows exist across 286 built-in items and 1,063 Vault-of-Magic
  items (`description == attributes.effects` for all 1,063). Flat-bonus items (Cloak/Ring of
  Protection +1 AC & saves, Bracers of Defense +2 AC, +N weapons/armor, ability-score setters
  like Gauntlets of Ogre Power / Headband of Intellect, Cloak of Resistance, Goggles of Night)
  contribute nothing to a character's computed stats.
- **Charges are partly typed** (`charges_max`, `charge_regain`) but *which spell each charge
  casts* and per-charge cost remain prose.

### 1.5 Creature stat-block schema gaps

- **No `saving_throws` field and no `skills` field for monsters/animals.** Proficient saves and
  skills (e.g. Aboleth, Lich) are simply unrepresentable — a schema omission, not a text dump.
- **Monster spellcasting is an opaque `trait_ref`** with no typed spell list, slots, or DC.

### 1.6 Choice / selection scaffolding is untyped for many features

Branching picks are rendered as prose ("Choose A, B, or C") with no typed sub-choice field:
Cleric Divine Order, Druid Primal Order, Warlock Pact Boon / Eldritch Invocations, Sorcerer
Metamagic, Hunter's four pick-one tiers, Draconic damage-type choice. Several feature rows are
**empty placeholders** carrying only a label (Bard L6/L13/L17, Warlock's four Mystic Arcanum
rows, Paladin L20, Sorcerer "Metamagic (extra II)").

---

## 2. Dedicated data fields the content needs (poor-structure remediation)

The "everything in one text field" anti-pattern concentrates in a few categories. Required
new/typed fields:

- **Magic items:** replace the prose `effects` string with a typed effect-row list (reuse the
  feat `effect()` DSL); add a typed `attunement_restriction` (class / alignment / feature enum),
  typed `charges.spells`, and `is_cursed`.
- **Spells:** add typed `damage_dice`, `damage_at_slot_level` / `cantrip_scaling` tables.
- **Classes/subclasses:** add a typed leveled-features table whose rows carry `effects`; add
  typed selection fields (`metamagic_pick`, `invocation_pick`, `pact_boon_pick`,
  `subclass_choice_group`) instead of prose "choose" text; remove empty placeholder rows.
- **Species/traits:** move PC trait mechanics out of the prose `trait` rows into typed
  `granted_modifiers` / `effects` on the species (or onto typed trait rows the resolver reads).
- **Feats:** universally adopt `prereq_clauses` (ability-OR, level, spellcasting, armor/weapon
  proficiency, class-feature, race/size); deprecate the single-valued `prereq_ability_ref` path
  for authoring.
- **Monsters:** add `saving_throws` and `skills` fields and a typed spellcasting block.

---

## 3. Architecture changes required

1. **Resolver fold sources.** Extend `character_resolver.dart` to read `effects` from `class`,
   `subclass`, and `trait` entities (and from class/subclass leveled-feature rows), not just
   `feat`. This is the single highest-leverage change — it unlocks the already-supported ~110
   effect kinds for the majority of described mechanics.
2. **Prerequisite engine.** Make `prereq_clauses` the canonical prerequisite representation and
   have the eligibility path (`pending_choice_resolver_dialog._computeEligibleFeats`) and the
   rule validator evaluate the full clause set (ability-OR, level, spellcasting, armor/weapon
   proficiency, class-feature, race/size). Consume `prereq_requires_spellcasting`, or fold it
   into a clause.
3. **Multiclass fix.** Add `multiclass_prereq_any_of` to the schema (`content.dart`) and set it
   on Fighter (and any future OR-class); or change the helper default. Keep Paladin/Ranger/Monk
   as AND.
4. **Attunement gating.** Add a typed `attunement_restriction` and enforce it where items are
   equipped/attuned; normalize the legacy free-text values during import.
5. **Spell damage model.** Add typed damage + scaling fields and a small evaluator so the
   combat/VTT layer can roll/scale spell damage.
6. **Magic-item effect rows.** Type item bonuses as `effects` so equipped items feed
   `EffectiveCharacter` (AC, saves, ability scores, resistances, senses).
7. **Creature schema.** Add `saving_throws`, `skills`, and a spellcasting block to the
   monster/animal category schema; surface them in the stat-block renderer.
8. **Importer/mapper coverage.** Extend `tool/open5e_import/mappers/chargen.dart` (and the
   magic-item/spell mappers) to populate the new typed fields so the 19 official packs reach
   parity with the hand-authored pack, continuing the effort tracked in
   `flutter_app/docs/chargen_mechanics_wiring.md`.
9. **Choice scaffolding.** Introduce typed selection fields for metamagic/invocations/pact
   boon/subclass-internal picks, plus a validator to flag empty placeholder feature rows.

### Suggested sequencing

1. Resolver fold-source extension (1) + multiclass fix (3) — small, high-impact, correctness.
2. Prerequisite engine (2) + attunement gating (4) — closes the enforcement gaps.
3. Magic-item effect rows (6) + spell damage model (5) — biggest content-typing payload.
4. Creature schema (7) + importer coverage (8) + choice scaffolding (9) — breadth & parity.
