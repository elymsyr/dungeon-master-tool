# System Mechanics Roadmap — Official & Built-in Package Support

> Automated System Architecture Inspector · audit date **2026-06-10** · branch `list`
> Companion ledger: [`entity_audit_log.md`](entity_audit_log.md)

## Audit basis

| Source | Location | Scale |
|---|---|---|
| Hand-authored SRD 5.2.1 Core pack (in-code, reference quality) | `flutter_app/lib/domain/entities/schema/builtin/srd_core/` | ~488 `packEntity` rows + spell/item tables |
| Official Open5e packages (also in first-party catalog) | `flutter_app/assets/open5e_packs/*.pkg.json` · `assets/first_party/manifest.json` | **19 packs · 20,712 entity cards** |

Engine reference points used to decide "implemented":
- `CharacterResolver` (`lib/domain/services/character_resolver.dart`) — **68 Effect-DSL kinds** (`ac_bonus`, `attack_bonus_typed`, `proficiency_grant`, `resource_pool_grant`, `choice_group`, …).
- Prerequisite evaluator in `pending_choice_resolver_dialog.dart` — clause atoms: `character_level`, `ability_min`, `spellcasting`, `armor_proficiency`, `weapon_proficiency` (simple/martial/any), `skill_proficiency`, `other`.
- `multiclass_helper.dart` — multiclass ability prereq.
- Content schema in `lib/domain/entities/schema/builtin/content.dart`.

**Headline finding.** The gap is **overwhelmingly content/import-pipeline, not engine**. The schema already defines the fields needed (`prereq_*`, `attunement_*`, `granted_at_level`, `features[]`, `effects[]`, `asi_distribution_options`, `origin_feat_ref`) and the resolver already consumes most of them — but the Open5e corpus was imported under a **descriptive-only policy** and leaves those fields empty, so almost nothing reaches `EffectiveCharacter`. A **smaller, genuine engine gap** remains in three places: **runtime attunement enforcement**, **formalizing/​widening the prerequisite clause model**, and **spell numeric-effect automation**. The bestiary (monsters + attack actions) is already well structured and needs no work.

Quantified deficiency surface (Open5e corpus):

| Area | Cards | Structured? | Gap |
|---|--:|---|---|
| Feats — effects | 73 | 9 have `effects[]` | **64** numeric/active benefits never applied |
| Feats — prerequisites | 73 | 22 clauses + flat fields | **5** prose-only prereqs unenforceable; atom model too narrow |
| Backgrounds | 53 | skills/equipment yes | `asi_distribution_options` 0/53, `origin_feat_ref` 0/53 |
| Subclasses | 101 | **0** | no `granted_at_level`/`features[]`/`rule_effects` — features never granted |
| Classes | 2 | proficiencies yes | `primary_ability_ref` 0/2, `features[]` 0/2 |
| Species / subspecies | 41 | modifiers/speed yes | `trait_refs` empty on all → named traits unlinked |
| Magic items | 1,063 | bools only | `effects` is a single string; `attunement_prereq` 0/1,063; `rule_effects` 0/1,063 |
| Spells | 1,297 | metadata yes | `effects[]` 0/1,297 → all numeric resolution is prose |

---

## 1. Prerequisite validation — engine present, content-starved, atom model too narrow

**Observed.** The engine *does* enforce prerequisites (feat-selection dialog + multiclass helper). Of 73 Open5e feats, **22 carry `prereq_clauses`** and the flat `prereq_*` fields cover the rest — only **5** feats keep a prerequisite as free text with no structured field: *Ace Driver* ("Proficiency with a type of vehicle"), *Stunning Sniper* ("Proficiency with a ranged weapon"), *Giant Foe* ("A Small or smaller race"), *Harrier* ("the Shadow Traveler trait **or** the ability to cast *misty step*"), *Well-Heeled* ("Prestige rating of 2+"). These expose **missing atom types**: specific-proficiency, creature size, *known-trait*, *known-spell*, and "X **or** Y". Separately, both base classes have **empty `primary_ability_ref`**, so the multiclass-entry ability gate can never fire.

**Architecture work needed.**
- **Formalize `prereq_clauses` in the schema.** The UI evaluator already reads it, but the field is not declared in `content.dart` — make it the canonical, schema-validated representation and treat the legacy single-value `prereq_ability_ref`/`prereq_min_score` pair as a compatibility shim.
- **Widen the atom set** beyond the current 7: add `specific_proficiency` (named weapon/tool/vehicle), `creature_size`, `known_trait`, `known_spell`, and explicit **AND/OR grouping** so "X or Y 13+" and "trait or spell" are expressible.
- **Extend the import parser** to emit clauses for the prose phrasings it currently drops ("Proficiency with …", "A Small or smaller race", "the ability to cast …").
- **Populate class `primary_ability_ref`** (curated — empty in Open5e source) so multiclass entry prereqs enforce.
- **Re-validate at resolve time, not only at selection.** Prereqs are checked in the selection dialog only; a character whose stats later drop below a feat's prereq is never re-flagged.
- Add prerequisite enforcement to **magic-item attunement** (§4) and **background/species** gates where source defines them.

## 2. Feat / class / subclass benefits — descriptive-only, not folded into the sheet

**Observed.** The resolver supports 68 effect kinds, yet **64/73 Open5e feats have no `effects[]`** — only proficiency/spell *choice* effects (`choice_group`) were ever emitted. Numeric/active benefits (expertise dice, AC bonuses, advantage, extra reactions) stay in `description` prose and never reach `EffectiveCharacter`. The hand-authored SRD pack is far better but still leaves a few numeric benefits in `benefits` markdown (e.g. *Alert*'s Initiative Proficiency has no `proficiency_grant`/`initiative_bonus` effect).

**Architecture work needed.**
- Build an **effect-extraction pass** (import-time pattern matching, or a curated overlay keyed by slug) converting recurring benefit phrasings into Effect-DSL entries — start with the highest-frequency patterns: flat `ac_bonus`, `attack_bonus_typed`/`damage_bonus_typed`, `reroll_damage`, `advantage_on`, `speed_bonus`, `proficiency_grant`, `resource_pool_grant`.
- Add the **expertise-die / superiority-die** mechanics the A5e packs lean on heavily (not in the current 68 kinds).
- Add a **coverage report to the importer** (per-type "% of cards with ≥1 effect") so descriptive-only content is visible rather than silently inert.

## 3. Leveled features — schema supports it, content does not populate it

**Observed.** The schema and resolver **do** support leveled features: subclasses have a required `granted_at_level` and a `features[]` table (`{level, description, effects}`), and the resolver filters rows by character level (`character_resolver.dart`, `if (lvl > level) continue;`). But **all 101 Open5e subclasses are `description` + `parent_class_ref` only** — `granted_at_level`, `features[]`, and `rule_effects` are empty, so the resolver has nothing to grant. Both Open5e classes likewise keep their entire progression (and spell tables) in prose.

**Architecture work needed.** This is **content-authoring + import**, not new engine capability:
- Author a **curated progression table** per subclass/class (Open5e source has no per-level field) to populate `features[]` with `granted_at_level` and an `effects` array per row.
- Populate class **spell tables** (`spell_slots_by_level`, `cantrips_known_by_level`, `prepared_spells_by_level`) — currently prose.
- Wire `level_up_planner.dart` to surface these at level-up (resolver already applies them once populated).

## 4. Magic items — single-field rules dump + unenforced attunement

**Observed.** All **1,063 Vault-of-Magic items** dump their ruleset into one free-text `effects` **string**. The schema defines structured attunement (`attunement_class_refs`, `attunement_spellcaster_only`, `attunement_min_ability_*`, `attunement_prereq`) and `rule_effects`/`granted_modifiers`/`charges_max` — **all empty (0/1,063)**. The conditional attunement clause ("by a spellcaster / by a creature of good alignment") is stripped before it reaches the pack. The engine, in turn, **does not enforce attunement at all**: no `attuned` flag on inventory rows, no 3-slot cap, `attunement_prereq` is never read.

**Architecture work needed.**
- **Runtime attunement (engine).** Add an `attuned` flag to inventory rows, a **3-slot attunement cap** on the character, and validation of `attunement_prereq` / structured attunement refs at attune time.
- **Item effect DSL (content + import).** Populate `rule_effects`/`granted_modifiers` for passive bonuses and `charges_max`/`charge_regain` for activated abilities, mirroring the feat/species path.
- **Capture conditional attunement at the source** (it is dropped pre-pack) or backfill from a curated table into `attunement_prereq` + the structured attunement refs.

## 5. Spells — metadata typed, effect resolution is prose

**Observed.** Spell metadata is well-typed (level, school, casting time, range, components, `save_ability_ref`, `damage_type_refs`, `attack_type`). But `effects[]` (the `spellEffectList` DSL) is **empty for all 1,297** spells and `at_higher_levels_text` is unused, so dice, healing, conditions, and upcast scaling exist only in `description`. Damage **type** is tagged (294 spells) with no structured **dice** to attach it to.

**Architecture work needed.**
- Define and populate a **structured spell-effect block** (damage dice + type, healing, save-for-half, applied condition, area) plus a **per-slot scaling table**, and have the resolver/combat layer apply it.
- Add a **damage-dice field** so the existing `damage_type_refs`/`save_ability_ref` tags become actionable in the VTT.

## 6. Background structure — partial fields, missing ASI rule and feat link

**Observed.** Backgrounds populate skills/equipment well, but `asi_distribution_options` (the +2/+1 vs +1/+1/+1 choice) is **0/53** and `origin_feat_ref` is **0/53**; the background feature and advancement tables are dumped in `description`.

**Architecture work needed.** Populate `asi_distribution_options` and `origin_feat_ref` at import (curated mapping), and extract the background **feature** into a dedicated structured field/effect rather than free text.

## 7. Bestiary — already structured (no engine work)

Monsters (2,885) carry full structured stat blocks; attack creature-actions (3,549) carry structured `attack_bonus`/`attack_kind`/`damage_dice`/`reach_ft`. The only residual is **[M]**: save-based *rider* effects within attacks and passive trait numbers (resistances, Pack Tactics, regeneration) remain prose. Optional future work: a lightweight monster-trait/save-rider effect schema for full VTT automation — low priority relative to §§1–6.

## 8. Content pipeline — catalog gaps

`flutter_app/assets/open5e_packs/unmapped_report.json` shows source lookups that never resolved to a Tier-0/Tier-1 catalog entry (sizes like `titanic`; languages like `void-speech`, `thieves-cant`). Extend the catalogs (or add alias mappings) so these non-SRD values map cleanly instead of being dropped.

---

## Priority summary

| # | Work item | Layer | Effort | Impact |
|---|---|---|---|---|
| 1 | Formalize `prereq_clauses` in schema + widen atom set (proficiency/size/trait/spell, AND-OR) + resolve-time re-validation | Engine + import | M | High |
| 2 | Runtime attunement (attuned flag, 3-slot cap, prereq enforcement) | Engine | M | High |
| 3 | Structured spell-effect block + per-slot scaling + damage-dice field | Engine + content | L | High |
| 4 | Effect-extraction pass for feat/species benefits (+ expertise/superiority-die kinds) | Import + engine | L | High |
| 5 | Curated subclass/class `features[]` + `granted_at_level` + class spell tables | Content + import | L | High |
| 6 | Magic-item `rule_effects`/`granted_modifiers`/`charges` + structured attunement refs | Content + import | M | Medium |
| 7 | Background `asi_distribution_options` + `origin_feat_ref` + extracted feature field | Import | S | Medium |
| 8 | Populate class `primary_ability_ref`; species `trait_refs` | Content | S | Medium |
| 9 | Importer coverage report (% cards with effects) | Tooling | S | Medium |
| 10 | Catalog aliases for unmapped sizes/languages | Pipeline | S | Low |

**Bottom line:** ~4 of these are genuine engine extensions (clause model, attunement runtime, spell-effect application, a few new effect kinds); the rest are import-pipeline + curated-content work to populate fields the schema already exposes.
