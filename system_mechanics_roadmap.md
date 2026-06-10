# System Mechanics Roadmap

> Automated System Architecture Inspector — development roadmap derived from a
> full audit of the official (Open5e first-party catalog) and built-in (SRD
> 5.2.1 core) content packages. Companion ledger:
> [`entity_audit_log.md`](entity_audit_log.md).

## Executive summary

The content layer is **structurally ahead of the rules engine in identity, and
behind it in behavior.** Identity/classification fields (stat blocks, spell
metadata, item rarity, prereq scores, weapon properties) are largely well-typed,
and the resolver already implements ~95 typed effect kinds and applies most
character-sheet ones. But the **functional rules** those cards describe are
overwhelmingly stranded in prose `description` / `effects` / `benefits` fields
that no resolver path reads. The result: the app can *display* the SRD faithfully
but can *mechanically apply* only a fraction of it.

Audited surface: **~2,280 built-in SRD cards** (each enumerated in the ledger)
plus **20,712 official-catalog cards** across 19 packs (audited pack × category).
Roughly **Clean ≈ 610 / Missing Mechanic ≈ 1,160 / Poor Data Structure ≈ 660 /
Unimplemented Prerequisite ≈ 60** in the built-in pack; **zero** official cards
are Clean. The Clean set is almost entirely *identity-only* cards (armor,
ammunition, spell foci, plain beasts, mounts/vehicles, well-wired combat/AC/
resource feats, and the subspecies — the one consistently well-modeled domain).

Five architectural holes dominate and account for the large majority of every
per-entity finding:

1. **No effect DSL for three whole content classes** — spells, magic items, and
   traits each store ~100% of their mechanics as a markdown string (341 spells,
   286 magic items, 238 trait cards built-in; +1,297 / 1,063 / 6,423 imported).
2. **The trait builder has no effects channel at all** — `_t()` exposes only
   `name/kind/description`, so *every* species and monster special ability is
   prose and unenforced.
3. **No enforced prerequisite system** — prerequisites are typed only partially
   and surfaced only as non-blocking warnings; the capable `prereq_clauses` gate
   is never populated.
4. **No structured model for leveled features and in-feature choices** — class /
   subclass progression past L1–L3, and every "choose N of a list" branch, is
   prose with no level field and no typed option binding.
5. **A cohort of attack/weapon effect kinds are deferred markers with no
   confirmed downstream consumer** — recognized by the resolver but never applied
   to the sheet.

> **Correction vs prior audits:** `speed_bonus` is **implemented** (resolver
> line 403 accumulates it); it is no longer a no-op. The remaining "inert" kinds
> are the *deferred markers* in §6, which is a different (and narrower) problem.

The sections below detail each missing system, the fields/mechanics required,
and the architecture changes needed.

---

## 1. Spell-effect engine (highest leverage)

**Problem.** Spells carry only *identity* fields (`level`, `school`, casting
time, range, components, duration, classes, ritual/concentration, material,
`saveAbility`, `attackType`, `damageTypes`, `conditions`). Even the typed
damage-type / save / condition fields are inert classification tags: **no dice,
no DC math, no on-fail/on-success branch, no scaling, no healing amount** is
attached. All of it lives in `description`. The resolver can never roll or apply
a spell. Affects **all 341 built-in spells + 1,297 imported spells; 0 are Clean.**

**Missing mechanics / fields.**
- A typed **spell-effect block**: `{outcome_roll(s), save: {ability, dc_source,
  on_fail, on_success: none|half}, attack: {to_hit_source}, area: {shape, size},
  condition: {ref, save-to-end}, healing: {dice, mod_source}, temp_hp}`.
- A **scaling model**: `cantrip_scaling` (by character level 5/11/17) and
  `upcast` (`per_slot_above_base`) — currently all in prose.
- A **typed heal-amount field** — no healing spell in either pack has one.
- Variable-at-cast spells (Eyebite, Chromatic Orb, Dragon's Breath, Prismatic
  Spray, Glyph of Warding, Symbol) need a **cast-time choice** of damage type /
  condition / sub-effect.

**Architecture changes.** Introduce a `SpellEffect` DSL parallel to the feat
`effect()` builders; teach the resolver/combat tracker to consume it for
auto-rolling damage/healing, computing save DCs (8 + PB + ability mod), and
queuing conditions; extend `_spell` + the Open5e spell mapper to emit it.
**Concrete data bugs surfaced in passing:** `Heat Metal` is mis-tagged with a
Constitution save; `Wall of Thorns` is missing its damage dice in prose;
`Pass Without Trace` is duplicated.

## 2. Magic-item effect engine

**Problem.** `_mi.effects` is a single markdown string (copied into
`description`); there is no typed item-effect DSL. Every numeric bonus is inert:
+1/+2/+3 weapons/armor/shields, Cloak/Ring of Protection, Bracers of Defense,
ability-score-setting items (Gauntlets of Ogre Power, Belts/Headbands),
resistances, fly/sense grants, temp-HP/healing — none applied, even though
equivalent effect kinds (`ac_bonus`, `ability_score_bonus`, `damage_resistance`,
`fly_speed`, `sense_grant`, `temp_hp_grant`) already exist for feats/species.
Affects **286 built-in + 1,063 imported items.**

**Missing mechanics / fields.**
- Reuse the existing **effect DSL** on items (the kinds exist — the builder just
  carries no `effects: List`), plus an application-context flag
  (*while-equipped* / *while-attuned* / *on-activation*).
- A real **charge model**: `maxCharges`/`chargeRegain` are typed, but per-use
  consumption and the spell/effect each charge buys are prose-only (~30 items).
- A **curse model**: `isCursed` is a toothless bool on 8 items (Potion of Poison,
  Eye/Hand of Vecna, Demon Armor, Armor of Vulnerability, Bag of Devouring, Dust
  of Sneezing and Choking, Shield of Missile Attraction, Berserker Axe) — penalty,
  attunement-trap, and Remove-Curse removal all unmodeled. `isSentient` is unused
  everywhere — **Eye of Vecna's prose says "sentient" but the flag is left
  false.**
- **Data bug:** "Periapt of Proof against Poison" is duplicated (two entries,
  differing only in capitalization).
- See §3 for `attunementPrereq` enforcement (free text on ~47 items).

**Architecture changes.** Add an `effects: List` channel + application-context
enum to the item schema and builder; route equipped/attuned items through the
resolver's existing fold; add charge-tracking + cursed-item state to the
inventory/attunement layer.

## 3. Prerequisite validation system

**Problem.** Prerequisites are advisory, not enforced, and inconsistently typed.
- **Feats:** typed `prereq_ability_ref` / `prereq_min_score` /
  `prereq_min_character_level` / `prereq_requires_spellcasting` exist but only
  drive a **non-blocking warning**; the more capable `prereq_clauses` gate is
  **never populated by any SRD feat**. "X or Y" ability prereqs (Grappler, Boon
  of Irresistible Offense, Ritual Caster) collapse to the first ability.
  Spellcasting / armor-proficiency / cantrip / "Fighting Style Feature" prereqs
  are stored as **unvalidated free text** (~45 feats affected).
- **Multiclassing:** `checkMulticlassPrereq` is warning-only, and multi-ability
  classes (**Fighter, Monk, Paladin, Ranger**) pair two ability refs with one
  `min_score` under **AND**, while SRD needs **OR** → the warning is *wrong*.
- **Magic items:** `attunementPrereq` is free text never checked (~47 items:
  class lists, species "Dwarf", item-dependency chains, alignment, even
  situational "worn outdoors at night").

**Missing mechanics / fields.** A **clause-based prereq model** that is
multi-valued and typed across all gate types (ability with AND/OR groups,
character/class level, class/subclass membership, species, proficiency,
spellcasting, other-feat-held), plus a single **eligibility evaluator** shared by
feat pick, multiclass entry, and item attunement, with a *block* vs *warn* flag.

**Architecture changes.** Back-fill `prereq_clauses` onto every SRD feat + class
+ item; fix the multiclass AND/OR semantics; extend attunement to call the
evaluator.

## 4. Trait effects DSL (species + monster mechanics)

**Problem.** `traits.dart` `_t()` emits only `name` / `kind` / `description` — it
has **no `effects` parameter and never calls `effect()`**. So all 238 built-in
trait cards (and 6,423 imported) are prose, and since species *and* monsters defer
their special abilities to `trait_refs`, **every racial/creature trait mechanic is
unenforced**: Dwarven Resilience, Fey Ancestry, Gnomish Cunning, Brave, plus
monster Legendary Resistance, Magic Resistance, Pack Tactics, Undead Fortitude,
Regeneration, Sunlight Sensitivity, Shapechanger, etc.

**Missing mechanics / fields.**
- Add the existing **`effects: List` channel to the trait builder** and back-fill
  the ~26 DSL-expressible-today traits (mostly `advantage_on` Perception/Stealth,
  `sense_grant`/darkvision, climb/spider-climb movement, `damage_resistance`).
- New typed kinds the other ~185 traits need that the resolver still lacks:
  **save-advantage-vs-condition** (`advantage_on` covers checks, not "saves vs
  condition X"), **regeneration**, **limited-use auto-succeed-save** (Legendary
  Resistance), **innate/scheduled spellcasting** wired to `activation()` + uses,
  **auras**, and **on-hit damage riders**.

**Data-integrity:** two true unqualified-name clashes break name-based
`trait_refs` resolution — **"Brave"** (monster vs species) and **"Evasion"**
(monster vs class); many near-duplicates are disambiguated only by parenthetical
suffixes and should be normalized to stable ref ids.

**Architecture changes.** Extend trait schema + builder; add the advantage-vs-
condition, regeneration, aura, and innate-spellcasting kinds to the resolver and
combat tracker; move `trait_refs` from name-based to id-based resolution.

## 5. Leveled class/subclass features & in-feature choices

**Problem.** Class features are authored as auto-granted feats with `effects`,
which works for L1–L3 grants — but **L4+ progression is prose-only** across all
12 classes + 12 subclasses. Unresolvable: Extra Attack tiers, flat boosts
(Primal Champion, Body and Mind), Blessed/Radiant Strikes, always-prepared domain
spells, Aura of Protection, Smites, Uncanny Dodge / Interception reactions,
on-hit riders. **In-feature choices** (Divine/Primal Order, Pact Boon, Eldritch
Invocations, Metamagic, Hunter's Prey, Fighting Style, Draconic/Fiendish
resistance type, High-Elf cantrip) carry no `choice_group` binding, so the chosen
branch grants nothing.

**Missing mechanics / fields.**
- A **structured level field** on class/subclass features so progression folds
  per class level.
- **`choice_group` bindings on parent features** + enumerated option sets,
  reusing the known-good Magic Initiate / `spell_from_list` pattern for
  choose-spell grants (Magical Secrets, Circle Spells, Mystic Arcanum, Pact of
  the Tome).
- **`granted_feat_refs`** actually used for feat-granting features (Fighting
  Style, Champion, Human Versatile) instead of prose.
- New resolver coverage for **auras**, **smite/extra-damage riders**, and
  **triggered reactions**.

## 6. Recognized-but-deferred effect kinds (markers with no confirmed consumer)

A cohort of kinds is accepted by the resolver and then **`break`s** — deferred to
a downstream combat-tracker / weapon-attack / choice-resolution pass — but is
**not applied to the character sheet**, and the downstream consumer is unverified:
`extra_damage_on_attack` (Rage damage, Sneak Attack, Brutal Strike, Radiant/
Blessed Strikes), `attack_bonus_typed` (Archery), `damage_bonus_typed` (Dueling),
`min_die_value` (Great Weapon Fighting), `reroll_damage` (Savage Attacker),
`reliable_talent`, `passive_score_bonus` (Observant),
`half_proficiency_to_unproficient_checks` (Jack of All Trades),
`weapon_mastery_grant` / `weapon_mastery_count_bonus`, `expertise_count`,
`spell_cast_from_item`.

**Action.** Confirm (or build) the combat-tracker / weapon-attack pipeline that
consumes these markers; until it exists every fighting style, weapon mastery, and
on-hit damage rider silently does nothing. **No weapon property** (Loading,
Thrown, Versatile, Reach, Two-Handed, Finesse, mastery) has any mechanical
consumer at all — all 38 weapons type these fields inertly.

## 7. Equipment & consumable mechanics

- **Consumables have no typed effect**: Acid, Alchemist's Fire, Holy Water, Net,
  Caltrops, Healer's Kit, Potion of Healing, light sources encode thrown attacks,
  save DCs, damage, healing, and light radii in `utilize_description`. The typed
  `utilize_check_dc` / `utilize_ability_ref` fields exist but are **never read by
  the resolver** (~36 active tools, plus active gear).
- **Equipment packs can't be expanded**: per-item quantities live only in a
  narrative string; `content_quantities` **does not exist anywhere in the
  codebase**, so picking a pack grants no typed inventory (all 7 packs).
- **Tool proficiency benefits / `craftable_items`** are prose and unwired (e.g.
  Thieves' Tools DC not linked to the Lock gear item).
- **Backgrounds** store ability options, skill/tool proficiencies, starting
  equipment, and the granted feat as prose with no typed grant plumbing (16/16).
- *(Counter-example — already Clean:)* armor STR-requirement and Stealth
  disadvantage are typed **and applied** (resolver lines 1008–1024); ammunition
  and spell foci are Clean. The 13 armor rows need no work.

## 8. Monster / NPC combat mechanics

- **Single-damage attack model**: `_a()` exposes one `damageDice` + one
  `damageType`, so every "plus N (NdM) <type>" rider drops its secondary
  component; ~75 actions are Missing-Mechanic and ~87 state a save DC/effect in
  prose without populating `saveDc` / `saveAbility` / `conditions`. Need a
  **list-typed damage-component model** and a rule that prose-DCs must be typed.
- **Legendary actions declared-but-empty**: **22 monsters** set
  `legendary_action_uses` with no `legendary_action_refs` (Lich, Vampire, Mummy
  Lord, all 5 Adult + 10 Ancient dragons); **4 more** (Kraken, Tarrasque, Solar,
  Sphinx) declare no legendary fields at all despite legendary status. No
  **lair-action** timing model exists.
- **Monster spellcasting**: all 4 `Spellcasting`/innate-cast action cards (and
  every imported equivalent) carry save DC, attack bonus, and at-will/N-per-day
  tiers entirely in prose — needs typed spell refs + per-tier use counters
  (depends on §1).
- **Recharge enum inconsistency**: `'Roll'` vs `'Recharge'` vs `'Long Rest'` vs
  `'Short or Long Rest'` for the same "Recharge 5–6" breaths; non-standard
  `actionType`s (`'Magic Action'`, `'Free Action'`). Standardize before building
  recharge/action-economy tracking.

## 9. Importer typing for the Official catalog (Open5e packs)

The 19 first-party packs (20,712 cards) are emitted by `tool/open5e_import/` as
**one `description` markdown blob per card** plus a thin `attributes` map;
typed-field back-fill is partial and limited to chargen entities (per
`flutter_app/docs/chargen_mechanics_wiring.md`). **No official card is Clean.**
Once the DSLs in §1–§5 exist, the mappers (`mappers/spell.dart`, `item.dart`,
`chargen.dart`, `monster.dart`) need parsers to populate them; until then every
imported feat prerequisite, spell effect, item bonus, trait, and monster special
ability is unenforced.

## 10. Data-integrity nits surfaced by the audit

- **Duplicate trait names** ("Brave", "Evasion") break name-based `trait_refs`;
  many near-duplicates rely on parenthetical disambiguation. Move to id-based refs.
- **"Periapt of Proof against Poison"** duplicated; **`isSentient`** unused
  (Eye of Vecna).
- **`Heat Metal`** mis-tagged CON save; **`Wall of Thorns`** missing damage dice;
  **`Pass Without Trace`** duplicated.
- **Dragonborn breath** action lives on the parent and is not re-keyed per color
  subspecies; **High Elf** cantrip choice is unbound.

---

## Suggested sequencing

| Priority | Workstream | Why |
|---|---|---|
| **P0** | §1 Spell DSL · §2 Item DSL · §4 Trait DSL+channel | Three engines unlock the largest share of inert content (all spells, items, and every racial + monster trait). Shared "effect block + application context" design. |
| **P0** | §6 confirm/build the deferred-marker consumer | Pure wiring — makes fighting styles, weapon mastery, Sneak Attack, and on-hit riders actually fire. |
| **P1** | §3 Prereq evaluator | Make `prereq_clauses` real, multi-valued, AND/OR, shared by feats/multiclass/attunement; fix the multi-ability OR bug. |
| **P1** | §5 Leveled features + choice_groups | Structured level field + option binding; reuse the spell-from-list pattern. |
| **P2** | §7 Equipment · §8 Monster combat | Consumable effects, pack expansion, list-typed damage, legendary/lair actions, recharge enum cleanup. |
| **P2** | §9 Importer mappers | Back-fill the 20k-card official catalog once the DSLs land. |
| **P3** | §10 Data-integrity cleanup | Id-based trait refs, de-dupe, fix mis-tagged spells, per-color breath typing. |
