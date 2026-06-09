# System Mechanics Roadmap

> Automated System Architecture Inspection — development roadmap derived from a full audit of
> the **SRD 5.2.1 Core** built-in/official content pack
> (`flutter_app/lib/domain/entities/schema/builtin/srd_core/`). This is the only first-party /
> built-in package the app ships; all official content is authored here and consumed at read
> time by `CharacterResolver` (the Effect-DSL engine). Companion ledger: `entity_audit_log.md`
> (2 341 entities reviewed).

## Executive summary

The SRD Core pack is, on the **data-structure** axis, in good shape: nearly every category
(weapons, armor, classes, subclasses, species, subspecies, backgrounds, monsters, animals,
creature-actions, feats) is authored into **typed, dedicated fields**, and the chargen
`CharacterResolver` already understands ~75 effect kinds (`knownEffectKinds`). The discrepancies
the audit found are concentrated in a handful of **system-wide capability gaps** where written
content describes a rule the runtime has no mechanic for. The biggest two are **spells** and
**magic items**, which carry rich metadata but push the *actual rule* into a single prose field.

| # | System-wide gap | Entities affected | Criterion |
|---|---|---|---|
| 1 | No spell-effect / casting resolution engine | 341 spells | Missing Mechanics |
| 2 | Magic items have no effect DSL (single prose `effects` field) | 286 magic items (87 confer un-applied passive bonuses) | Poor Data Structure + Missing Mechanics |
| 3 | No combat / action-economy engine for feat & feature riders | 178 prose-only feats/features | Missing Mechanics |
| 4 | Runtime state/condition predicates always evaluate `false` at resolve time | conditional grants across feats/subclasses/traits | Missing Mechanics |
| 5 | Feat **armor/shield proficiency** prerequisites unenforced | 4 feats | Unimplemented Prerequisite |
| 6 | Magic-item **attunement** prerequisites unenforced; no attunement-slot limit | 32 magic items | Unimplemented Prerequisite |
| 7 | Monster trait / action mechanics are narrative-only (no VTT enforcement) | 238 traits + 109 non-attack actions | Missing Mechanics |
| 8 | Active-use equipment effects live in prose `utilize_description` | 58 gear/tool items | Missing Mechanics |

---

## 1. Spell-effect / casting resolution engine — **missing**

**Finding.** Every spell stores its metadata in dedicated fields (`level`, `school_ref`,
`casting_time_*`, `range_*`, `components`, `duration_*`, `requires_concentration`, `class_refs`,
`damage_type_refs`, `save_ability_ref`, `attack_type`, `applied_condition_refs`). But the *effect
of casting the spell* — damage dice, cantrip/upcast scaling, area shape, save-for-half, healing
amount, condition application — exists **only in the prose `description`**. There is no
machine-readable model, so a spell does nothing mechanical when cast.

**System needs.**
- A structured **spell-effect block** (new dedicated fields): `damage_rolls` (dice + type +
  scaling rule: per-cantrip-tier and per-upcast-slot), `area` (shape + size), `save` (ability +
  DC formula + half-on-success), `healing_roll`, `attack_roll` (to-hit vs save), `applied_conditions`
  (with save/duration), `targets`.
- A **casting resolver** + combat-tracker integration that rolls/applies the above, reusing the
  existing `scales_with` table mechanism already proven for class features.
- Upcast/cantrip scaling tables (the prose universally says "+1d6 per slot above Nth" / "scales at
  levels 5/11/17").

## 2. Magic-item effect DSL — **missing**

**Finding.** The `_mi` builder collapses the entire rules text into one prose `effects` string
(surfaced as the entity `description`). Items carry typed `rarity_ref`, `magic_category_ref`,
`requires_attunement`, `activation`, `is_cursed`, `is_sentient` — but **no per-effect DSL**.
Consequently:
- **87** items confer a passive numeric/advantage benefit (e.g. *Cloak of Protection* +1 AC &
  saves, *Ring of Protection*, +N weapons/armor, *Boots of Elvenkind* Stealth advantage) that is
  **never applied to the character sheet**.
- **45** items have charges that are **not tracked as a resource**.
- **32** items have **attunement prerequisites** that are narrative-only (§6).

**System needs.**
- Reuse the existing character Effect-DSL: add an `effects: [...]` list field to magic items and
  have `CharacterResolver` apply it for **equipped / attuned** items. The resolver already has a
  **Pass 5b** that reads a `rule_effects` field on equipped items — it is currently empty on SRD
  content; this is the natural hook to populate.
- A **charges/uses resource** model (`max_charges`, `recharge` formula) wired into the same
  resource-pool machinery used for Rage/Ki.
- **Attunement-slot limit** (max 3) as a validated character-level constraint.

## 3. Combat / action-economy engine — **missing**

**Finding.** **178** feats and class/subclass features have their benefits entirely in prose
`benefits`/`description` with no machine-readable `effects`, because they describe **action-economy
and attack-pipeline** rules the system cannot model: *Charger* (replace an attack), *Great Weapon
Master* (extra die on hit / bonus attack on crit), *Polearm Master* / *Crossbow Expert* (bonus
attacks), *Defensive Duelist* (reaction +AC), etc. The DSL already defines an **`activation`** block
(action type, uses, duration) and the resolver carries it through — **but nothing consumes it**;
there is no combat tracker that triggers these effects.

**System needs.**
- A **combat/turn engine** that consumes the authored `activation` blocks and the new
  trigger-based effects (on-hit, on-crit, on-take-damage, on-attack-action, reaction windows).
- New effect kinds for triggered riders (extra damage on-hit, bonus-attack grants, reaction
  effects) tied to combat events rather than read-time resolution.

## 4. Runtime state & condition predicates — **inert at resolve time**

**Finding.** The resolver explicitly returns `false` for `has_state` / `has_condition` /
`target_has_condition` predicates ("State predicates always return false at resolve time"). Any
feature gated on a live state — *Rage*, *while Raging*, *while wearing Heavy Armor and not
Incapacitated* (the not-incapacitated half is honoured; the state half is not) — cannot be
evaluated. Conditional grants are partially routed into `conditionalGrants` but never *activated*.

**System needs.**
- A **live combat-state layer** (active conditions, toggled states like Raging) that feeds both
  the resolver and the combat tracker so state predicates can be evaluated when the state is on.

## 5. Feat prerequisite enforcement — **partial; proficiency clause missing**

**Finding.** Feat prerequisites are **mostly enforced**: typed fields `prereq_min_character_level`,
`prereq_min_score` + `prereq_ability_ref`, and `prereq_requires_spellcasting` are honoured by the
`_computeEligibleFeats` eligibility filter, and multiclass `multiclass_prereq_*` is enforced. The
gap: feats whose prerequisite is an **armor/shield proficiency** — *Heavy Armor Master*, *Medium
Armor Master*, *Moderately Armored*, and the Shields variant — encode that requirement **only in the
narrative `prerequisite` string**. There is no typed proficiency-prerequisite field, so the filter
cannot enforce it.

**System needs.**
- A typed **proficiency prerequisite clause**. The richer `prereq_clauses` model already exists in
  the schema and the resolver dialog (it supports `character_level`, `ability_min`, and a
  display-only `other`) — add a `proficiency` clause type that actually gates, and **upgrade the
  built-in SRD feats** to populate `prereq_clauses` instead of (or alongside) the legacy flat
  fields. (Today the SRD pack populates zero `prereq_clauses`.)

## 6. Magic-item attunement prerequisites — **unenforced**

**Finding.** 32 items carry an `attunement_prereq` (e.g. "by a Spellcaster") that is narrative-only,
and there is no attunement-slot accounting.

**System needs.** Validate attunement prerequisites against the character (class/spellcasting/
ability) and enforce the 3-item attunement limit — same machinery as §5's prerequisite clauses.

## 7. Monster trait & action mechanics — **narrative-only**

**Finding.** Monster/animal stat blocks are fully structured and reference `trait` and
`creature-action` rows. But **238 traits** are narrative prose (`description` + `trait_kind`, no
machine effect) and **109 non-attack creature actions** describe their save/condition/damage rider
only in prose. The resolver intentionally treats monster `trait_refs` as narrative. This is
acceptable for a DM reading a stat block, but means the **VTT combat tracker cannot auto-apply**
Pack Tactics, Magic Resistance, Undead Fortitude, recharge breath weapons, save-or-condition riders,
etc.

**System needs.** Structured effect/rider fields on `creature-action` (save ability + DC + on-fail
effect, recharge) and an opt-in trait-effect model, consumed by the combat tracker.

## 8. Active-use equipment effects — **prose-only**

**Finding.** 58 gear/tool rows (*Acid*, *Alchemist's Fire*, *Ball Bearings*, *Antitoxin*, *Caltrops*,
poisons, healer's kit, etc.) describe a DC/damage/save active use in the prose `utilize_description`
field. Some carry typed `utilize_dc` / `utilize_ability`, but the *effect* (damage dice, condition)
is not a structured, triggerable mechanic.

**System needs.** A small structured active-use effect block on consumable gear, reusing the same
damage/save effect primitives introduced for spells (§1) and creature actions (§7).

---

## Proposed architecture changes (rollup)

1. **Unify on one Effect-DSL.** Extend the existing character Effect-DSL + `CharacterResolver` to
   also drive **magic-item** passive effects (via the already-present but empty `rule_effects` /
   Pass 5b hook) and consumable active-use effects. One DSL, three more consumers.
2. **Add a spell-effect model** (damage/area/save/scaling/healing/condition) and a **casting
   resolver**, reusing the proven `scales_with` table mechanism for upcast/cantrip scaling.
3. **Build a combat / action-economy engine** that consumes the authored `activation` blocks
   (currently produced but unconsumed) plus new **event-triggered** effect kinds (on-hit, on-crit,
   on-take-damage, reaction). This is the single largest missing subsystem and unblocks ~178 feats
   and 109 monster actions.
4. **Introduce a live combat-state layer** so `has_state` / `has_condition` predicates evaluate at
   combat time instead of always returning `false`.
5. **Extend the prerequisite system:** add `proficiency` (and attunement) clause types to the
   typed `prereq_clauses` model, enforce attunement-slot limits, and **upgrade the SRD pack content**
   to populate `prereq_clauses` (currently 0 rows use it).
6. **Add the dedicated schema fields** the above require in `content.dart`: spell-effect block,
   magic-item `effects` list + `charges`, creature-action save/condition/recharge, feat
   proficiency-prereq clause, consumable active-use effect. Then re-author the SRD pack rows to fill
   them (and bump `srdCorePackVersion`).
