---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/character_resolver.dart
layer: domain
language: dart
status: stable
updated: 2026-07-29
tags: [file]
---

# `character_resolver.dart`

> [!abstract] Primary Purpose
> Pure, stateless read-time resolver. `CharacterResolver.resolve(pc, entitiesById, {config})` walks a `Character`'s raw stored choices (`class_levels`, `subclass_id`, `feat_ids`, `equipment_choices`, `race_id`, `subspecies_id`, `background_id`, `base_abilities`) plus every referenced source entity, reads the **grant-block fields** each card declares, and folds everything into an immutable `EffectiveCharacter` for the sheet/editor. Recomputed on every read; not memoized at this layer (wrap with a Riverpod `Provider.family` for caching).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — static methods only. Caller supplies `Character pc`, `Map<String, Entity> entitiesById` (the merged campaign/package entity map), optional `RuleConfig config` (default `RuleConfig.dnd5eDefaults`).
- Reads (DAOs / Drift tables): none directly — operates on the already-loaded `pc.entity.fields` and the entity map.
- Supabase / CDC subscribed: none.
- Events consumed: none.
- Triggers: none — invoked synchronously on read.

**Outputs**
- Public API: `static EffectiveCharacter resolve(...)`; `static const Set<String> grantFieldKeys` — the complete, closed contract of grant-block field keys (41) an authored card may set. There is no effect DSL, no kind registry and no predicate language behind it.
- Writes: none — never persists; returns a value object.

## Dependencies & Links
- Depends on: [[entity_ref]] (`resolveEntityRef` / `findEntityIdByName` — wraps as `_resolveRef`/`_findEntityIdByName`), [[effective_character]] (output type), `count_formula.dart` (`evalCountFormula`), `schema/rule_config.dart` (`RuleConfig` — `abilityModifier`, `acShieldBonus`, `acUnarmoredBase`, `proficiencyBonusFor`), `entity.dart`, `character.dart`.
- Used by: the character sheet/editor and [[level_up_planner]]-adjacent UI (read its output); typically wrapped in a Riverpod provider.
- Keep in sync with: `data/schema/rule_effects_migration.dart` ([[rule_effects_migration]]) — the one-shot converter targets exactly `grantFieldKeys`; and `_FB.grantBlock` in `builtin/content.dart`, which emits them onto categories.
- Domain map: [[Character-System]]
- System flow: [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]], [[Ref-Resolution-Hard-vs-Soft]]

## Key Logic / Variables
### `applyGrantsFrom(Map fields, String src)` — the single reader
Feat, Trait, Magic Item, Species, Subspecies and the nested `subspecies_options` rows all speak the same grant-block keys, so this one function covers every source. Adding a mechanic = add a key to `grantFieldKeys` + a line here. Local helpers it composes:
- `_readAbilityList` — ability relation-list → `STR`/`DEX`/… abbreviations.
- **sense fold** — accepts `{sense_ref, range_ft}` *and* a bare ref (a sense with no stated range), so hand-authored and migrated data both read; **largest range per sense wins** (Drow's Superior Darkvision 120 beats the base 60).
- **level-table fold** — a `{lvl: value}` map resolved to the value for the highest level not above the character's; optional `class_ref` scopes the lookup to that class's level. This is what makes Fighter Extra Attack (5→2, 11→3, 20→4) and Barbarian Rage uses (1→2, 3→3, 6→4, …) work with no scaling DSL.
- **resource-pool fold** — max = `count_by_level` table, else `count_formula` (`cha_mod_min_1` and friends via `evalCountFormula`), else the flat `count`.
- **speed sentinels** — `-1` in a `speed_*_ft` field means "equal to walking speed". An explicit distance is more specific and wins over the sentinel *regardless of fold order*; between two explicit distances the larger wins.
- **state gating** — when the card sets `active_while_state_ref` (a `character-state` Tier-0 ref such as `state:raging`), only the four keys in `_conditionalGrantKinds` (damage resistance / immunity / vulnerability, condition immunity) land in `conditionalGrants` for the sheet to draw as "while raging" chips. Everything else on that card is skipped — a state-gated numeric bonus must not be folded into a resting sheet total — and its `mechanical_notes` lines are prefixed with the state label (`_stateLabel` turns `state:raging` into "while raging").

### Ordered passes inside `resolve`
1. **Raw choice reads** — typed-read the PC fields (`_readStringList`/`_readIntMap`/…). `feat_asi_choices` map `{featId:{ABBR:amt}}` records user ASI picks.
2. **Pass 1** — `_collectFeaturesByLevel` for each class (gated by its level) and the subclass. **Subclass gating is by the parent class's level** (`parent_class_ref` → `classLevels[parent]`), falling back to max-of-all-classes; further gated by `granted_at_level`. Feature rows are narrative only — mechanics live on the granted feat/trait entity, never inline on the class's features table.
3. **Working accumulators** — abilities, acBonus, speedBonus, extraSpeeds, senses + senseRanges, damage res/imm/vuln, condition immunities, granted action/bonus/reaction, resourcePools, unarmoredFormulas, expertise, alwaysPrepared, extraAttackCount (**max, not sum**), critRangeMin floor, mechanicalNotes.
4. **Pass 4b auto-grant walker** — scans every `feat`/`trait` entity; `matchesAutoGrant` checks `auto_granted_by` rows against class + `at_level`, subclass (parent-class-level gated), species (`race_id`), or background. Feats → `autoGrantedFeatIds` (grants applied); traits → `autoGrantedTraitIds`.
5. **Pass 3** — for each feat: scalar ASI (honoring recorded `feat_asi_choices`, else heuristic first-uncapped option, capped by `asi_max_score`), then `applyGrantsFrom(feat.fields, 'feat:<name>')`.
6. **Pass 5** — species, subspecies and background. Subspecies resolved as a first-class `subspecies` entity (by id / name / `legacy_subspecies_key`) or a legacy nested `subspecies_options` row; all three go through `applyGrantsFrom`. Background adds `granted_skill_refs`, `granted_tool_refs`, and `background_asi` (SRD 2024: +2/+1 or +1/+1/+1, total 3, capped 20, gated by `ability_score_options` with a warning on out-of-list).
7. **Pass 5b** — granted traits + equipped magic items, again via `applyGrantsFrom`.
8. **Class + subclass top-level proficiency grants** — `saving_throw_refs`, `granted_tool_refs`, `weapon_proficiency_categories`, `armor_training_refs`.
9. **Armor-worn conditions** (`armorNotes`) — STR-requirement → `speedBonus -= 10`; untrained-armor warning; stealth disadvantage. Runs after the proficiency pass so `armorCats` is complete. `_equippedArmor` excludes shields (`category_ref` name contains "shield").
10. **Pass 6 equipment** — `mergeChoiceGroups` resolves `equipment_choice_groups` against picks stored **scoped by source** (`$entityId:$groupId`), plus `default_inventory_refs`.

### Derived
- AC (`_computeArmorClass`): armored = `base_ac + cappedDex + shield + acBonus`; unarmored = `max(acUnarmoredBase + Dex + shield, each unarmoredFormula's base + ability_mods (+shield if shield_allowed)) + acBonus`. Formulas come from the `unarmored_ac_base` / `unarmored_ac_abilities` / `unarmored_ac_shield_allowed` fields — the field names carry the "while unarmored" meaning that used to require a predicate.
- `grantSources` maps grant-id → ordered deduped clean source names (`cleanSource` strips the `kind:` prefix; subspecies `Sp/Sub` → "Sub Sp").
- Missing refs are silently dropped and surfaced in `EffectiveCharacter.warnings`.

## Notes
- ~1190 LOC, down from ~1550 before the rule-system removal (2026-07-28), which deleted `applyEffect`, `evalPredicate`, `predicatesPass`, `splitStatePredicates`, `evalScalesWith`, `knownEffectKinds`, `sheetAppliedEffectKinds`, `legacyModifierKindAliases` and `_modifierAsEffect`. See [[Grant-Resolution]] for the before/after mapping.
- `grantFieldKeys` is the thing to read first: it *is* the contract, and this file is its only interpreter.
- Covered end-to-end against real SRD content by `test/domain/services/srd_grants_integration_test.dart` (13 tests: Barbarian Unarmored Defense + Rage pool scaling + state gating, Fighter attack table, Hill/Mountain Dwarf HP, Drow 120 ft darkvision, Monk unarmored AC, Magic Initiate choices, note survival, zero-warning invariant).
