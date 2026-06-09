---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/character_resolver.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `character_resolver.dart`

> [!abstract] Primary Purpose
> Pure, stateless read-time resolver. `CharacterResolver.resolve(pc, entitiesById, {config})` walks a `Character`'s raw stored choices (`class_levels`, `subclass_id`, `feat_ids`, `equipment_choices`, `race_id`, `subspecies_id`, `background_id`, `base_abilities`) plus every referenced source entity, applies the Effect-DSL, and folds everything into an immutable `EffectiveCharacter` for the sheet/editor. Recomputed on every read; not memoized at this layer (wrap with a Riverpod `Provider.family` for caching).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — static methods only. Caller supplies `Character pc`, `Map<String, Entity> entitiesById` (the merged campaign/package entity map), optional `RuleConfig config` (default `RuleConfig.dnd5eDefaults`).
- Reads (DAOs / Drift tables): none directly — operates on the already-loaded `pc.entity.fields` and the entity map.
- Supabase / CDC subscribed: none.
- Events consumed: none.
- Triggers: none — invoked synchronously on read.

**Outputs**
- Public API: `static EffectiveCharacter resolve(...)`; `static const Set<String> knownEffectKinds` (the ~80 effect kinds with a real `applyEffect` case; a debug assert in `ruleCatalogProvider` enforces the Rule Catalog declares a superset).
- Writes: none — never persists; returns a value object.

## Dependencies & Links
- Depends on: [[entity_ref]] (`resolveEntityRef` / `findEntityIdByName` — wraps as `_resolveRef`/`_findEntityIdByName`), [[effective_character]] (output type), `count_formula.dart` (`evalCountFormula`), `rule_config.dart` (`RuleConfig` — `abilityModifier`, `acShieldBonus`, `acUnarmoredBase`, `proficiencyBonusFor`), `entity.dart`, `character.dart`.
- Used by: the character sheet/editor and [[level_up_planner]]-adjacent UI (read its output); typically wrapped in a Riverpod provider.
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]], [[Ref-Resolution-Hard-vs-Soft]]

## Key Logic / Variables
Resolution runs as ordered passes inside `resolve`:
1. **Raw reads** — typed-read the PC fields (`_readStringList`/`_readIntMap`/etc). `feat_asi_choices` map `{featId:{ABBR:amt}}` records user ASI picks.
2. **Pass 1** — feat `class_level_grant` effects add levels into `classLevels` before feature-by-level walks. Each feat in `feat_ids` applies once; duplicates stack additively (repeatable feats).
3. **Pass 2** — `_collectFeaturesByLevel` for each class (gated by its level) and the subclass. **Subclass gating is by the parent class's level** (`parent_class_ref` → `classLevels[parent]`), falling back to max-of-all-classes; further gated by `granted_at_level`. Inline row `effects` are deferred into `pendingFeatureEffects`.
4. **`applyEffect(eff, source)`** — the central switch over effect `kind`. Predicate gate: `predicatesPass` AND-combines closed-enum predicates (`class_level_at_least`, `equipped_armor_kind` with none/light/medium/heavy/not_heavy/not_none, `equipped_shield`, `not_incapacitated`). **State predicates (`has_state`/`has_condition`/`target_has_condition`) always return false at resolve time**; `splitStatePredicates` routes the subset of `conditionalKinds` (damage_resistance/immunity/vulnerability, condition_immunity_grant) into `conditionalGrants` when non-state predicates pass. `scales_with` tables resolved via `evalScalesWith` (class_level / character_level / static). Effects mutate working accumulators (abilities, acBonus, speedBonus, extraSpeeds, senses+senseRanges, damage res/imm/vuln, condition imm, granted action/bonus/reaction, resourcePools, unarmoredFormulas, expertise, alwaysPrepared, extraAttackCount **takes max not sum**, critRangeMin floor). Unknown kinds append a warning.
5. **Pass 4b auto-grant walker** — scans every `feat`/`trait` entity; `matchesAutoGrant` checks `auto_granted_by` rows against class+`at_level`, subclass (parent-class-level gated), species (`race_id`), or background. Feats → `autoGrantedFeatIds` (effects applied); traits → `autoGrantedTraitIds` (narrative only).
6. **Pass 3** — apply each feat's `effects` + scalar ASI (honoring recorded `feat_asi_choices`, else heuristic first-uncapped option) + legacy `granted_modifiers` via `_modifierAsEffect`.
7. **Pass 4** — apply the deferred `pendingFeatureEffects`.
8. **Pass 5** — species + subspecies grants via `applyGrantsFrom` (innate speeds `speed_*_ft`, `granted_senses`, damage res/imm/vuln, condition imm, languages, skills, `trait_refs`, action/bonus-action/reaction refs, spell/cantrip refs, `granted_spells_at_level` via `_applyLevelGatedSpells`). Subspecies resolved as first-class `subspecies` entity (by id/name/`legacy_subspecies_key`) or legacy nested `subspecies_options` row. Background: `granted_skill_refs`, `granted_tool_refs`, and `background_asi` (SRD 2024: +2/+1 or +1/+1/+1, total 3, capped 20, gated by `ability_score_options` with a warning on out-of-list).
9. **Pass 5b** — uniform `rule_effects` field on class/subclass/species/background/trait/equipped-item (additive; empty on current SRD).
10. **Pass 8** — class+subclass top-level proficiency grants (`saving_throw_refs`, `granted_tool_refs`, `weapon_proficiency_categories`, `armor_training_refs`).
11. **Armor-worn conditions** (`armorNotes`) — STR-requirement → `speedBonus -= 10`; untrained-armor warning; stealth disadvantage. `_equippedArmor` excludes shields (`category_ref` name contains "shield").
12. **Pass 6 equipment** — `mergeChoiceGroups` resolves `equipment_choice_groups` against picks stored **scoped by source** (`$entityId:$groupId`), plus `default_inventory_refs`.
13. **extraSpeeds sentinels** — `-1` means "equals walking speed" (`speed_ft` default 30 + speedBonus).
- AC (`_computeArmorClass`): armored = `base_ac + cappedDex + shield + acBonus`; unarmored = `max(acUnarmoredBase + Dex + shield, each unarmoredFormula's base + ability_mods (+shield if shield_allowed)) + acBonus`.
- `grantSources` maps grant-id → ordered deduped clean source names (`cleanSource` strips `kind:` prefix; subspecies `Sp/Sub` → "Sub Sp").

## Notes
- Largest chargen file (~1460 LOC). The `applyEffect` switch is the single source of truth for which effect kinds are mechanically live vs reserved-for-later-passes (combat tracker, choice resolution, weapon pipeline).
- Many memory entries touch this file: Drow 120ft sense range, count_formula resource pools, Berserker state-predicate conditional grants, subclass `at_level` gating, subspecies first-class category.
