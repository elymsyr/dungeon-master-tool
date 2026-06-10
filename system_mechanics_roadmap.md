# System Mechanics Roadmap

> Automated System Architecture Inspector — development roadmap derived from a
> full audit of the **official** (Open5e first-party catalog — 19 packs /
> 20,712 cards) and **built-in** (SRD 5.2.1 core — ~2,260 cards) content
> packages. Companion ledger: [`entity_audit_log.md`](entity_audit_log.md).
> Branch: `list`.

## Executive summary

The content layer is **well-typed in identity and uneven in behavior.**
Classification/identity fields — monster stat blocks, weapon/armor stats, spell
metadata, item rarity/attunement flags, ability-score prereqs, creature-action
attack lines — are largely typed and consumed by the runtime. The resolver
already implements ~50 effect kinds and *enforces* feat prerequisites and
multiclass entry rules where the data is typed. The gap is twofold:

1. **Three whole content classes have no executable effect channel** — spells,
   magic items, and traits store ~100% of their behavior as prose strings that
   no resolver path reads.
2. **The official (imported) catalog under-populates the typed fields that the
   engine *does* support** — feat prerequisites, leveled class features, gear
   cost/weight, and magic-item attunement restrictions are left in prose even
   though the schema and gate already exist for them.

Distribution of the ~22,970 audited cards: **Clean ≈ 7,400** (built-in
equipment/feats/monsters, official monster stat blocks + attack actions,
well-modeled species/subspecies); **Missing Mechanic ≈ 14,700** (all spells, all
traits, magic items, non-attack actions, leveled features); **Poor Data
Structure ≈ 1,500** (magic-item effects-as-prose, empty official gear, untagged
spells); **Unimplemented Prerequisite ≈ 30** (official feats with prose-only
prereqs, magic-item attunement-by-class).

> **Correction vs. naive assumptions:** the system is **not** missing a
> prerequisite *engine* (`pending_choice_resolver_dialog._computeEligibleFeats`
> + `multiclass_helper` enforce typed prereqs), and creature **attack** actions
> and **spell save/damage-type** tags *are* partially typed. The deficiencies
> below are precise about engine-gap vs. data-coverage-gap.

The sections below detail each missing system, the fields/mechanics it requires,
and the architecture change needed. Ordered by leverage.

---

## 1. Spell-effect engine — *missing engine* (highest leverage)

**Problem.** Spells (1,638 cards: 1,297 official + 341 built-in) carry only
*identity* fields (level, school, casting time, range, components, duration,
ritual/concentration, material, and partial `save_ability_ref`/
`damage_type_refs`/`attack_type` tags). There is **no `damage_dice`/amount, no
per-slot/per-level scaling, no save-outcome resolution, and no `effects`
channel.** Every spell's behavior is a prose `description`.

**Needs.**
- A typed `spell.effects` list (reuse the existing effect-DSL vocabulary) with
  spell-specific kinds: `damage{dice, type, on_save}`, `apply_condition{cond,
  save, duration}`, `heal{dice}`, `area{shape, size}`, `scales_with{slot|level,
  per_step}`, `attack_roll{type}`.
- `save_dc_source` (spell save DC = 8 + prof + ability) wired to the caster.
- Slot-level / character-level scaling table per spell ("At Higher Levels").

**Architecture.** Extend the schema (`content.dart` spell category) with the
typed `effects` field; teach `character_resolver` / a new combat-time spell
resolver to roll/scale/apply it; backfill the importer mapper
(`tool/open5e_import/mappers/`) and the hand-authored `spells.dart` to emit the
list. Until then the app can *display* every spell but *apply* none.

## 2. Trait effect channel — *missing engine*

**Problem.** Traits (6,661 cards: 6,423 official + 238 built-in) are the largest
unenforced cohort. The trait shape (official `trait_kind`+`description`; built-in
`_t()` = name/kind/description) has **no effects channel at all**, so every
species and monster special ability (Pack Tactics, Magic Resistance, Legendary
Resistance, Undead Fortitude, regeneration, innate-spellcasting lines, auras) is
prose and unenforced — and species `trait_refs` therefore deliver nothing
mechanical onto the character sheet.

**Needs.** Add an `effects` list (and where relevant `save_dc`, `recharge`,
`uses_per_day`, `aura{shape,size,damage}`) to the trait schema and the `_t()`
builder; map the common SRD traits to effect kinds (advantage/disadvantage,
damage-resistance, condition-immunity, regeneration, on-hit rider).

**Architecture.** Schema + builder change; resolver support for the
species-side kinds (it already has advantage/resistance/immunity kinds, so
species traits are low-hanging); combat-side support for monster-only kinds.

## 3. Magic-item effect & attunement model — *missing engine + data gap*

**Problem.** Magic items (1,349 cards) type rarity/attunement-flag/cursed/
activation, but the `effects` attribute is a **verbatim copy of the prose
description** (official) or absent (built-in) — not a typed effect list, so no
bonus/resistance/charge/attack-rider is applied. Attunement *restrictions*
("requires attunement by a wizard / spellcaster") are prose; the existing typed
`attunement_prereq` field (`content.dart:1002`) is never populated, so the
restriction is an **Unimplemented Prerequisite**.

**Needs.** Real typed item `effects` (bonuses to AC/attack/save/ability, granted
resistances/senses/spells, charges + recharge); populate `attunement_prereq`
(class / spellcaster / alignment) and *enforce* it at equip/attune time.

**Architecture.** Extend item schema with a typed effects list and structured
attunement gate; add an attune-time validator (mirror the feat-prereq gate);
backfill importer + `magic_items.dart`.

## 4. Leveled-feature & in-feature-choice model — *missing engine*

**Problem.** Imported classes/subclasses type only L1 identity (hit die, saves,
proficiencies, caster kind, skill choices); **all L1–20 progression is prose**
with no per-level feature rows and no `at_level`. "Choose N of a list" branches
(Fighting Style, Expertise, Metamagic, Invocations) have no typed option
binding. (Built-in classes partly dodge this by auto-granting effect-carrying
*feature feats* — but that pattern was never applied to the imported catalog.)

**Needs.** A typed `features[]` model on class/subclass: `{at_level, name,
effects[], choices[]}`, with `choices` binding to typed option pools the
`PendingChoice` system already understands.

**Architecture.** Schema addition (`features` DSL with a level field);
`level_up_planner` + `character_resolver` already walk `at_level`-gated
features, so the main work is the importer parse (currently blocked by Open5e's
freeform ClassFeature prose having no level field) and authoring tables.

## 5. Prerequisite data coverage — *engine exists, data under-populated*

**Problem.** The prereq **engine is present and enforced**
(`_computeEligibleFeats` evaluates typed `prereq_clauses` —
character_level / ability_min(OR) / spellcasting / armor- / weapon- /
skill-proficiency — and `multiclass_helper` gates entry). But the **official
catalog under-fills it**: of 27 official feats with a `prerequisite` string,
only ~22 carry `prereq_clauses` and 8 the legacy `prereq_ability_ref`; the rest
state a requirement that **never gates** the pick. Magic-item attunement
restrictions (§3) are similarly untyped.

**Needs.** Backfill the importer to parse every `prerequisite` string into
`prereq_clauses`; add a build-time lint that flags any card whose prose names a
requirement (`requires`, `proficiency with`, `Nth level`, `<Ability> N`) while
the typed clause list is empty.

**Architecture.** No engine change — importer mapper + a content-integrity lint
in the pack-build/CI pipeline.

## 6. Adventuring-gear data backfill — *data gap*

**Problem.** All 159 official adventuring-gear cards ship **empty**
(`cost_cp: 0`, `weight_lb: 0`, no description, no `is_focus`) — name + category
only. (Built-in gear is fully typed, so the schema is fine; the importer simply
maps nothing.)

**Needs.** Importer mapping for gear cost/weight/description/`is_focus`/
`consumable` from the Open5e source; a build lint flagging all-zero gear rows.

**Architecture.** Importer mapper only; optional CI lint.

## 7. Effect-application surface for typed-but-inert tags — *partial engine*

**Problem.** Several typed fields are *recorded* but not *applied*: spell
`save_ability_ref`/`damage_type_refs` (classification only, §1), creature-action
non-attack `save`/rider text, and attack-action on-hit riders. The data exists;
no consumer rolls or applies it.

**Needs.** A combat-time resolver that consumes typed action/spell save+damage
to produce rolls and condition application (this is the VTT-side counterpart to
the chargen-time `character_resolver`).

**Architecture.** New combat resolver service consuming the typed creature-action
/ spell fields once §1 lands; wire into the initiative/turn engine.

---

## Priority ordering

| # | System | Type of gap | Leverage | Engine work |
|---|---|---|--:|---|
| 1 | Spell-effect engine | Missing engine | ~1,640 cards | High |
| 2 | Trait effect channel | Missing engine | ~6,660 cards | Med (species kinds exist) |
| 3 | Magic-item effects + attunement gate | Missing engine + data | ~1,350 cards | Med |
| 4 | Leveled-feature / choice model | Missing engine | classes/subclasses | High (+ authoring) |
| 5 | Prereq data coverage + lint | Data + lint | feats/items | Low (no engine) |
| 6 | Gear cost/weight backfill | Data | 159 cards | Low (importer) |
| 7 | Combat-time effect application | Partial engine | spells/actions | High (depends on 1) |

**Cross-cutting recommendation.** Adopt the built-in pattern as the target shape
for the whole catalog: typed `effects` lists + `at_level`-gated feature rows +
populated `prereq_clauses`/`attunement_prereq`, plus a **pack-build content lint**
(in the Content-Pipeline / CI) that fails any card whose prose names a mechanic
or requirement that no typed field carries. That lint converts every "Missing
Mechanic / Unimplemented Prerequisite" finding in the ledger into a
build-time-visible, trackable debt.
