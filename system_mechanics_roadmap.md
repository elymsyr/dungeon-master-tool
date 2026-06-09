# System Mechanics Roadmap — Official & Built-in Package Support

> Automated System Architecture Inspector · audit date **2026-06-09** · branch `list`
> Companion ledger: [`entity_audit_log.md`](entity_audit_log.md)

## Audit basis

| Source | Location | Scale |
|---|---|---|
| Built-in SRD 5.2.1 Core pack (in-code, hand-authored) | `flutter_app/lib/domain/entities/schema/builtin/srd_core/` | ~488 `packEntity` + ~341 spells + ~287 magic items |
| Official / bundled Open5e packages (also in first-party catalog) | `flutter_app/assets/open5e_packs/*.pkg.json` · `assets/first_party/manifest.json` | 19 packs · **20,712 entity cards** |

Engine reference points used to judge "implemented":
`CharacterResolver` (`lib/domain/services/character_resolver.dart`, ~80 Effect-DSL kinds),
`pending_choice_resolver_dialog.dart` (prereq gating: `prereq_clauses`, `prereq_min_score`, `prereq_ability_ref`, `prereq_min_character_level`),
`multiclass_helper.dart` (multiclass ability prereq), and the content schema in
`lib/domain/entities/schema/builtin/content.dart`.

**Headline finding:** the gap is overwhelmingly *content-side, not engine-side*. The engine already supports structured prerequisites and a deep effect system, but the official Open5e corpus was imported under a *descriptive-only* policy and feeds almost none of it. Where the engine is genuinely missing capability, it is concentrated in **leveled features, spell/item effect automation, and clause-based prerequisites**.

---

## 1. Prerequisite validation — present but content-starved, and too narrow

**Observed.** The engine *does* enforce prerequisites when fields are populated (feat selection dialog + multiclass helper). But of **73 Open5e feats, only 11 carry any structured `prereq_*` field**; 27 have a prerequisite written as **narrative text only** (e.g. *Ace Driver* → "Proficiency with a type of vehicle", *Battle Caster* → "ability to cast at least one spell"). The richer `prereq_clauses` evaluator is authored by **zero** content rows — even in the hand-authored SRD pack, *Grappler*'s "Strength **or** Dexterity 13+" can't be expressed because `prereq_ability_ref` is single-valued. Class `primary_ability_ref` is empty for **all** base classes, so multiclass-entry ability gates can't fire.

**Architecture work needed.**
- Generalise prerequisites to a **clause model** (`prereq_clauses`: AND/OR of typed atoms — ability-min, character/class level, proficiency, spellcasting ability, known-feat, class/subclass, species). The UI evaluator already reads `prereq_clauses`; make it the canonical representation and retire the single-value `prereq_ability_ref`/`prereq_min_score` pair.
- Extend the import parser (`tool/open5e_import/mappers/chargen.dart`) to emit clauses for the common phrasings it currently leaves as prose: "Proficiency with …", "ability to cast …", "X or Y 13+", "Nth level".
- Populate class `primary_ability_ref` (requires a curated table — empty in Open5e source) so multiclass entry prereqs are enforceable.
- Add prerequisite enforcement to **magic-item attunement** (see §4) and **background**/**species** selection where source defines gates.

## 2. Feat / class / subclass benefits — descriptive-only, not folded into the sheet

**Observed.** The resolver supports ~80 effect kinds (`ac_bonus`, `attack_bonus_typed`, `reroll_damage`, `extra_attack_bump`, `proficiency_grant`, `resource_pool_grant`, …), yet **64 / 73 Open5e feats have no `effects` array**, and **44 / 62 SRD built-in feats** describe numeric/active benefits purely in `benefits` markdown (*Archery* +2 ranged attack, *Defense* +1 AC, *Savage Attacker* reroll). These bonuses never reach `EffectiveCharacter`. Only proficiency-choice effects (`choice_group`) were ever wired during import.

**Architecture work needed.**
- Build an **effect-extraction pass** (import-time pattern matching, or a curated overlay keyed by entity slug) that converts the recurring benefit phrasings into Effect-DSL entries — start with the highest-frequency patterns: flat `ac_bonus`, typed `attack_bonus_typed`/`damage_bonus_typed`, `reroll_damage`, `advantage_on`, `speed_bonus`, `proficiency_grant`, `resource_pool_grant`.
- Add a **coverage report** to the importer (per-type "% of cards with ≥1 effect") so descriptive-only content is visible rather than silently inert.
- Add any missing effect kinds surfaced by the corpus (e.g. expertise-die / superiority-die mechanics used heavily by the A5e packs).

## 3. Leveled features — no level field anywhere

**Observed.** Subclass and class features are freeform prose. No entity carries `granted_at_level`, so the resolver applies **every subclass feature at level 1**; the level-up planner cannot grant features per level. All **101 Open5e subclasses** are `description`-only (+ `parent_class_ref`), and the two Open5e classes (*Marshal*, *Mechanist*) keep their entire level progression in prose.

**Architecture work needed.**
- Introduce a **leveled-feature schema**: an ordered list of feature rows, each with `granted_at_level`, an optional `effects` array, and a body. Wire `level_up_planner.dart` to grant them at the right level and `CharacterResolver` to apply their effects.
- Provide a class **spell-list** structure (per-class, per-level) so prepared/known casters resolve correctly — currently prose only.
- Because Open5e source has no level field, this requires a **curated progression table** (or a structured re-import from a level-aware source); flag as content-authoring work, not just a parser change.

## 4. Magic items — single-field rules dump + lost attunement conditions

**Observed.** All **1,063 Vault-of-Magic items** dump their entire ruleset into one free-text `effects` string. `requires_attunement` is a bare boolean (452 true); the **conditional** attunement clause ("requires attunement by a spellcaster / by a creature of good alignment") is **stripped from source entirely** — `attunement_prereq` (which the schema defines, `content.dart:1002`) is empty for every item. No structured AC/attack/save bonuses, so item effects aren't applied and attunement conditions aren't enforced.

**Architecture work needed.**
- Add a **magic-item Effect DSL** (passive bonuses + activated abilities) mirroring the feat/species effect path, plus `charges` / `recharge` modelling.
- Populate and enforce **`attunement_prereq`** (class/species/alignment/spellcasting clause — reuse the §1 clause model), and track the **3-slot attunement cap** on the character sheet.
- Capture the conditional-attunement text at the import source (it is dropped before it reaches the pack), or backfill from a curated table.

## 5. Spells — metadata typed, effect resolution is prose

**Observed.** The **1,297 Open5e spells** have excellent typed metadata (level, school, casting time, range, components, duration, concentration, `save_ability_ref`, `damage_type_refs`, `attack_type`) but **no damage-dice / amount field and no structured upcast (`at higher levels`) field**. Damage, save-for-half outcomes, and upcasting all live in the prose `description`.

**Architecture work needed.**
- Add structured **effect fields**: damage formula(s) keyed by damage type, save effect (none/half/negates), and a **scaling table** (per-slot-level and per-cantrip-tier).
- Add a **spell-resolution / "cast at higher level"** mechanic that consumes those fields for automated rolls and slot scaling.

## 6. Backgrounds — partial ASI typing, untyped equipment/gold

**Observed.** `granted_skill_refs` and (often) `ability_score_options` are typed, but **`asi_distribution_options` is empty for nearly every background** (the +2/+1 vs +1/+1/+1 distribution rule isn't enforced), and several non-SRD backgrounds lack `ability_score_options` entirely. Equipment, starting gold, tool proficiencies, and the background feature remain in prose; `origin_feat_ref` is set for only a handful.

**Architecture work needed.**
- Populate/enforce **`asi_distribution_options`** and complete `ability_score_options` coverage.
- Add typed **starting-equipment**, **starting-gold**, **tool-proficiency**, and **origin-feat** fields with chargen-wizard consumption.

## 7. Adventuring gear & reference statblocks (lower priority)

- **Adventuring gear (159):** `is_focus` is uniformly `false` and many `cost_cp`/`weight_lb` are `0` — spellcasting-focus and encumbrance validation have nothing to key on. Backfill focus flags and costs/weights.
- **Monsters / traits / creature-actions (17,920):** correctly normalised into separate reference cards, but all behaviour (multiattack, recharge, save DCs, legendary/lair actions) is prose. An **encounter-automation layer** (structured attack/action/save-DC fields) would be required to run them mechanically; acceptable as reference content for now.

---

## Roadmap summary (priority order)

| # | Capability gap | Type | Effort driver |
|---|---|---|---|
| 1 | Clause-based prerequisite model + import parser coverage | Prereq / data | Schema + parser + UI evaluator (engine mostly exists) |
| 2 | Effect extraction for benefit prose (feats/species/items) | Missing mechanic | Importer overlay + new effect kinds |
| 3 | Leveled-feature schema (`granted_at_level` + effects) | Missing mechanic | Schema + level_up_planner + **curated tables** |
| 4 | Magic-item effect DSL + conditional attunement + slot cap | Missing mechanic / prereq | Schema + resolver + source backfill |
| 5 | Spell damage/save/scaling fields + upcasting resolver | Missing mechanic / data | Schema + spell resolver |
| 6 | Background ASI distribution + typed equipment/gold/feat | Data / prereq | Schema + parser + wizard |
| 7 | Gear focus/cost backfill; monster encounter automation | Data | Backfill / future layer |

**One-line architecture statement:** the resolver and prereq engine are largely capable; the system needs **(a)** a clause-based prerequisite representation, **(b)** an effect-extraction/authoring pipeline that fills the existing Effect DSL from the descriptive corpus, and **(c)** a genuinely new **leveled-feature + spell/item effect-resolution** layer — the only places where the engine itself, not just the data, is missing.
