# System Mechanics Roadmap

> Automated System Architecture Inspector — development roadmap derived from a
> full audit of the official (Open5e first-party catalog) and built-in (SRD
> 5.2.1 core) content packages. Companion ledger: [`entity_audit_log.md`](entity_audit_log.md).

## Executive summary

The content layer is **structurally ahead of the rules engine in identity, and
behind it in behavior.** Identity/classification fields (stat blocks, spell
metadata, item rarity, prereq scores) are largely well-typed, and the resolver
already implements ~95 typed effect kinds. But the **functional rules** that
those cards describe are overwhelmingly stranded in prose `description` /
`benefits` / string `effects` fields that no resolver path reads. The result:
the app can *display* the SRD faithfully but can *mechanically apply* only a
fraction of it.

Three architectural holes dominate and account for the large majority of every
per-entity finding in the ledger:

1. **No effect DSL for three whole content classes** — spells, magic items, and
   traits each store 100% of their mechanics as a markdown string. (~341 spells,
   ~286 magic items, ~239 trait cards in the built-in pack alone, plus ~8,700
   imported equivalents.)
2. **No enforced prerequisite system** — prerequisites are typed only partially
   and surfaced only as non-blocking warnings; the engine's own capable
   `prereq_clauses` gate is never populated by content.
3. **No structured model for leveled features and in-feature choices** — class /
   subclass progression past L1–L3, and every "choose N of a list" branch, is
   prose with no level field and no typed option set.

The sections below detail each missing system, the fields/mechanics required,
and the architecture changes needed.

---

## 1. Spell-effect engine (highest leverage)

**Problem.** Spells carry only *identity* fields (`level`, `school`, casting
time, range, components, duration, classes, ritual/concentration, material,
`save_ability_ref`, `attack_type`, `damage_type_refs`, `applied_condition_refs`).
Even the typed damage-type / save / condition fields are inert classification
tags: **no dice, no DC math, no on-fail/on-success branch, no scaling** is
attached. All of it lives in `description`. The resolver can never roll or apply
a spell. Affects all ~341 built-in spells + ~1,297 imported spells.

**Missing mechanics / fields.**
- A typed **spell-effect block**: `{outcome_roll(s), save: {ability, dc_source,
  on_fail, on_success: none|half}, attack: {to_hit_source}, area: {shape, size},
  condition: {ref, save-to-end}, healing: {dice, mod_source}, temp_hp}`.
- A **scaling model**: `cantrip_scaling` (by character level 5/11/17) and
  `upcast` (`per_slot_above_base`) — currently 13 cantrips + ~50 leveled spells
  bury this in prose.
- A **heal-amount field** — 12 genuine healing spells have no typed output.
- Variable-at-cast spells (Glyph of Warding, Symbol, Prismatic Spray, Dragon's
  Breath, Chromatic Orb) need a **cast-time choice** of damage type/condition.

**Architecture changes.** Introduce a `SpellEffect` DSL parallel to the feat
`effect()` builders; teach the resolver/combat tracker to consume it for
auto-rolling damage/healing, computing save DCs (8 + PB + ability mod), and
queuing conditions; extend the spell builder (`_spell`) + Open5e spell mapper to
emit it. **Concrete data bug to fix in passing:** `Counterspell` deals 3d8 force
on a CON save but ships with empty `damageTypes` and null `saveAbility`.

## 2. Magic-item effect engine

**Problem.** `_mi.effects` is a single markdown string (copied verbatim into
`description`); there is no typed item-effect DSL. Every numeric bonus is inert:
+1/+2/+3 weapons/armor/shields, Cloak/Ring of Protection (+1 AC & saves),
Bracers of Defense, Gauntlets of Ogre Power / Belts & Headbands that *set* an
ability score, resistances, fly/sense grants, temp-HP/healing — none are applied
even though equivalent effect kinds (`ac_bonus`, `ability_score_bonus`,
`damage_resistance`, `fly_speed`, `sense_grant`, `temp_hp_grant`) already exist
for feats/species. Affects ~286 built-in + ~1,063 imported items.

**Missing mechanics / fields.**
- Reuse the existing **effect DSL** on items (the kinds already exist — the item
  builder just doesn't carry an `effects: List`), including a flag for
  *while-equipped* vs *while-attuned* vs *on-activation* application.
- A real **charge model**: `charges_max`/`charge_regain` exist, but per-use
  **consumption** and the spell/effect each charge buys are prose-only.
- A **curse model**: `is_cursed` is a toothless bool on 9 items — the penalty,
  the attunement-trap, and Remove-Curse removal are unmodeled. `is_sentient`
  likewise goes unused (Eye/Hand of Vecna describe sentience in prose).
- See §3 for `attunement_prereq` enforcement.

**Architecture changes.** Add an `effects: List` channel + application-context
enum to the magic-item schema and builder; route equipped/attuned items through
the resolver's existing fold; add charge-tracking + cursed-item state to the
inventory/attunement layer.

## 3. Prerequisite validation system

**Problem.** Prerequisites are advisory, not enforced, and inconsistently typed.
- **Feats:** typed `prereq_ability_ref`/`prereq_min_score`/
  `prereq_min_character_level`/`prereq_requires_spellcasting` exist but only
  drive a **non-blocking warning** dialog. The engine ships a far more capable
  `prereq_clauses` eligibility gate (it resolves live spellcasting + armor/weapon
  proficiency) — but **zero SRD-core feats populate it.** "X or Y" ability
  prereqs collapse to the first ability (single-valued field). Spellcasting /
  proficiency / cantrip prereqs are stored as unvalidated free text.
- **Multiclassing:** `checkMulticlassPrereq` enforces (still warning-only), but
  multi-ability classes (Fighter/Monk/Paladin/Ranger) pair two ability refs with
  one `min_score` under **AND**, while SRD needs **OR** → the warning is wrong.
- **Magic items:** `attunement_prereq` is free text never checked (33+ items:
  class lists, species "Dwarf", item-dependency chains, alignment, even
  situational "worn outdoors at night").

**Missing mechanics / fields.**
- A **clause-based prereq model** that is multi-valued and typed across all
  gate types: ability (with AND/OR groups), character/class level, class/
  subclass membership, species, proficiency (armor/weapon/tool/skill),
  spellcasting, and "other-feat-held".
- A single **eligibility evaluator** shared by feat pick, multiclass entry, and
  item attunement, with a config flag for *block* vs *warn*.

**Architecture changes.** Back-fill `prereq_clauses` (or a unified successor)
onto every SRD-core feat + class + item; fix the multiclass AND/OR semantics;
extend the attunement flow to call the evaluator.

## 4. Trait effects DSL (species + monster mechanics)

**Problem.** `traits.dart` (`_t()`) emits only `source` / `trait_kind` /
`description` — it has **no `effects` parameter and never calls `effect()`**. So
all 239 trait cards are prose, and since species *and* monsters defer their
special abilities to `trait_refs`, **every racial/creature trait mechanic is
unenforced**: Dwarven Resilience (adv vs Poisoned), Gnomish Cunning (adv mental
saves), Fey Ancestry (adv vs Charm), Brave (adv vs Frightened), Halfling Lucky,
plus monster Legendary Resistance, Magic Resistance, Pack Tactics, Undead
Fortitude, Regeneration, Sunlight Sensitivity, etc.

**Missing mechanics / fields.**
- Add the existing **`effects: List` channel to the trait builder** and back-fill
  the ~21 PC-species and ~70 PC-class traits (all DSL-expressible today).
- New typed kinds the traits need that the resolver still lacks: **save-advantage
  / condition-advantage** (`advantage_on` exists for checks but not "saves vs
  condition X"), **regeneration**, **innate/limited-use spellcasting** wired to
  `activation()` + `resource_pool_grant` (14 trait rows list spells/DCs/uses
  purely in prose, spells not even `ref`'d).

**Architecture changes.** Extend trait schema + builder; add the missing
advantage-vs-condition and regeneration kinds to the resolver and combat tracker.

## 5. Leveled class/subclass features & in-feature choices

**Problem.** Class features are authored as auto-granted feats with `effects`,
which works for L1–L3 grants — but **L4+ progression is prose-only** across all
12 classes + 12 subclasses. Unresolvable: Extra Attack tiers, flat boosts
(Primal Champion +4, Body and Mind +4), Blessed Strikes, always-prepared domain
spells, Aura of Protection (a core Paladin pillar), Smites, Uncanny Dodge /
Interception reactions, on-hit riders. **In-feature choices** (Divine/Primal
Order, Pact Boon, Eldritch Invocations, Metamagic, Hunter's Prey, Fighting Style,
Draconic/Fiendish resistance type, High-Elf cantrip) carry no `choice_group`
binding, so the chosen branch grants nothing.

**Missing mechanics / fields.**
- A **structured level field** on class/subclass features (the source — and the
  current builder — has none) so progression can be folded per class level.
- **`choice_group` bindings on parent features** + enumerated option sets, reusing
  the known-good Magic Initiate / `spell_from_list` pattern for choose-spell
  grants (Magical Secrets, Circle Spells, Mystic Arcanum, Pact of the Tome).
- **`granted_feat_refs`** actually used for feat-granting features (Fighting
  Style, Champion L7, Human Versatile) instead of prose.
- New resolver coverage for **auras**, **smite/extra-damage riders**, and
  **triggered reactions**.

## 6. Reserved no-op effect kinds (typed but inert)

Three already-emitted kinds apply nothing and should be implemented:
- **`speed_bonus`** — used by Fast Movement, Mobile, Unarmored Movement, Roving;
  every flat walking-speed bump silently does nothing.
- **`weapon_mastery_grant`** — all 39 weapons type `mastery_ref` and feats grant
  mastery, but the resolver treats it as a reserved no-op; **no weapon property**
  (Loading, Thrown, Versatile, Reach, Two-Handed, Finesse, mastery) has any
  mechanical consumer at all.
- Redundant OA-immunity kinds (`opportunity_attack_immunity_when_disengage_redundant`).

Plus the DSL-is-ahead-of-data feats that need no new engine work, only wiring:
`attack_bonus_typed` (Archery), `damage_bonus_typed` (Dueling), `min_die_value`
(Great Weapon Fighting), `damage_reduction_flat` (Heavy Armor Master),
`reaction_damage_reduction`, `passive_score_bonus` (Observant), `ignore_cover`,
`reliable_talent`, `oa_stops_movement`, `reroll_damage`.

## 7. Equipment & consumable mechanics

- **Consumables have no typed effect**: Acid, Alchemist's Fire, Holy Water, Net,
  Caltrops, Healer's Kit, Potion of Healing, light sources encode thrown attacks,
  save DCs, damage, healing, and light radii in `utilize_description`. The typed
  `utilize_check_dc` / `utilize_ability_ref` fields exist but are never read.
- **Equipment packs can't be expanded**: per-item quantities live only in a
  narrative string; the `content_quantities` ref→qty plumbing is unbuilt, so
  picking a pack grants no typed inventory.
- **Tool proficiency benefits / `craftable_items`** are prose and unwired (e.g.
  Thieves' Tools DC not linked to the Lock gear item).
- *(Counter-example — already Clean:)* armor STR-requirement and Stealth
  disadvantage are typed **and** applied; the 14 armor rows need no work.

## 8. Monster / NPC combat mechanics

- **Legendary actions declared-but-empty**: 18 monsters set
  `legendary_action_uses` with no `legendary_action_refs`; Tarrasque/Kraken
  declare none. No **lair-action** timing model exists.
- **Monster spellcasting** (14 stat blocks + 3 Spellcasting action cards): save
  DC, attack bonus, and at-will/N-per-day tiers entirely in prose — needs typed
  spell refs + per-tier use counters (depends on §1).
- **Single-damage attack model**: `_a()` exposes one `damage_dice` +
  one `damage_type_ref`, so ~74 attacks with "plus N (NdM) <type>" lose the
  secondary type; ~50 attacks/area actions state a save DC in prose without
  populating `save_dc` / `save_ability_ref` / `applied_condition_refs`. Need a
  **list-typed damage-component model** and a rule that prose-DCs must be typed.
- **Recharge enum inconsistency** (`'Roll'` vs `'Recharge'` for the same
  "Recharge 5–6"): standardize before building recharge tracking.

## 9. Importer typing for the Official catalog (Open5e packs)

The 19 first-party packs (20,712 cards) are emitted by `tool/open5e_import/` as
one `description` markdown blob per card; typed-field back-fill is partial and
limited to chargen entities (documented in
`flutter_app/docs/chargen_mechanics_wiring.md`). Once the DSLs in §1–§5 exist,
the mappers (`mappers/spell.dart`, `item.dart`, `chargen.dart`, `monster.dart`)
need parsers to populate them; until then every imported feat prerequisite
(plain `**Prerequisite:**` prose), spell effect, item bonus, and monster special
ability is unenforced.

## 10. Data-integrity nits surfaced by the audit

- **Duplicate trait `name`s** (Brave, Evasion, Cunning Action, Sneak Attack,
  Charge, Flyby, Spider Climb, …) break name-based `trait_refs` resolution —
  ambiguous targets. Same hazard: **Fiendish Vigor** appears as two cards
  (Fiend Patron feat + Invocation option); **Periapt of Proof against Poison**
  duplicated; Dragonborn breath damage type not keyed per color subspecies.
- **`Counterspell`** damage/save fields empty (see §1).
- **`is_sentient`** unused on the items that need it.

---

## Suggested sequencing

| Priority | Workstream | Why |
|---|---|---|
| **P0** | §1 Spell DSL · §2 Item DSL · §4 Trait DSL | Three engines unlock the largest share of inert content (spells, items, all racial + monster traits). Shared "effect block + application context" design. |
| **P0** | §6 wire reserved/idle kinds | Pure data wiring, no new engine — immediate mechanical wins (fighting styles, weapon mastery, speed bonuses). |
| **P1** | §3 Prereq evaluator | Make `prereq_clauses` real, multi-valued, AND/OR, shared by feats/multiclass/attunement. |
| **P1** | §5 Leveled features + choice_groups | Structured level field + option binding; depends on the choice/spell-from-list pattern. |
| **P2** | §7 Equipment · §8 Monster combat | Consumable effects, pack expansion, legendary/lair actions, list-typed damage. |
| **P2** | §9 Importer mappers | Back-fill the 20k-card official catalog once the DSLs land. |
| **P3** | §10 Data-integrity cleanup | De-dupe trait names, fix Counterspell, per-color breath typing. |
