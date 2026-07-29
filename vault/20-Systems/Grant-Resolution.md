---
type: system
domain: chargen
updated: 2026-07-29
tags: [system]
---

# Grant Resolution

> [!summary] What this is
> How descriptive content entities (class/subclass/species/subspecies/background/feat/trait/magic-item) become a typed `EffectiveCharacter`. Cards declare what they grant in **plainly named fields**; [[character_resolver]] folds them into derived stats at read time. Owned by [[Character-System]].
>
> **Supersedes the Effect DSL (removed 2026-07-28).** There is no longer a `kind`/`target_kind`/`value`/`predicates`/`scales_with`/`activation` row language, no effect-kind catalog and no predicate evaluator. See [[#What replaced the Effect DSL]].

## Participants
- [[srd_helpers]] — authoring side: `packEntity`, `lookup`/`ref` placeholders, `withFeatureGrant`, `eqGroup`/`eqOption`/`eqItem`. (The `effect`/`predicate`/`scalesByClass`/`activation` builders are gone, and so is `autoGrantBy` — see [[#The auto-grant edge was inverted]].)
- `builtin/content.dart` — `_FB.grantBlock(...)` emits the shared grant-block fields onto a category.
- [[character_resolver]] — application side: `applyGrantsFrom` is the **single reader** of those fields.
- [[effective_character]] — output view (carries `warnings` for dropped refs and `mechanicalNotes` for prose rules).
- [[level_up_planner]] + the three count resolvers ([[extra_attack_resolver]], [[weapon_mastery_resolver]], [[resource_pool_resolver]]) — read the same named fields directly, independently of the sheet resolve.
- `data/schema/rule_effects_migration.dart` — one-shot converter for pre-existing data still in the old row format.

## The contract
`CharacterResolver.grantFieldKeys` is the complete, closed list of grant-block field keys (41). Adding a mechanic means adding a key there, a line in `applyGrantsFrom`, a field in `_FB.grantBlock` and an isolation case — the four guards in `grant_contract_test.dart` / `grant_field_isolation_test.dart` fail until all four exist. Grouped by what a DM is looking for:

| Group | Keys |
|---|---|
| Condition | `active_while_state_ref` |
| Proficiency | `granted_skill_proficiencies`, `granted_tool_proficiencies`, `granted_save_proficiencies`, `granted_weapon_proficiencies`, `granted_armor_proficiencies`, `granted_expertise_skills`, `granted_languages` |
| Spells | `granted_spell_refs`, `granted_cantrip_refs`, `always_prepared_spell_refs`, `granted_spells_at_level` |
| Numeric | `ability_bonuses`, `ability_bonus_cap`, `ac_bonus`, `speed_bonus_ft`, `initiative_bonus`, `hp_bonus_flat`, `hp_bonus_per_level`, `extra_attack_count`, `extra_attack_count_by_level`, `crit_threshold`, `weapon_mastery_count` |
| Unarmored AC | `unarmored_ac_base`, `unarmored_ac_abilities`, `unarmored_ac_shield_allowed` |
| Defense | `granted_damage_resistances`, `granted_damage_immunities`, `granted_damage_vulnerabilities`, `granted_condition_immunities` |
| Senses & movement | `granted_senses`, `speed_fly_ft`, `speed_swim_ft`, `speed_climb_ft`, `speed_burrow_ft` |
| Actions & traits | `granted_action_refs`, `granted_bonus_action_refs`, `granted_reaction_refs`, `trait_refs` |
| Structured | `resource_pool_grants`, `player_choices` |
| Prose | `mechanical_notes` |

Feat, Trait, Magic Item, Species, Subspecies and the nested `subspecies_options` rows all speak these same keys, so one reader covers every source. Proven per-source by `test/domain/services/grant_source_matrix_test.dart`, which hangs one identical bundle off every card type and demands the same sheet.

**Class, Subclass and Background do not carry the block.** Every grant they make already had a typed home — `saving_throw_refs`, `weapon_proficiency_categories`, `armor_training_refs`, `granted_skill_refs`, `granted_tool_refs`, `granted_languages` — read by the resolver's class/background passes rather than by `applyGrantsFrom`. Giving them the block too would put two fields for one mechanic on one card, which is exactly what the removal was for; `grant_contract_test.dart` asserts no category ever declares both names of a synonym pair. Note `granted_languages` deliberately keeps the *same* key on a class as on a feat: one mechanic, one name, wherever it is authored.

## Flow
1. Character holds `class_levels`, `subclass_id`, `feat_ids`, `race_id`, `subspecies_id`, `background_id`, `equipment_choices`, `base_abilities`.
2. Resolver gathers auto-granted feats/traits by walking the **granting card**: the Class / Subclass `features` rows at or below the character's level in that class, plus `species`/`subspecies` `granted_feat_refs` and `trait_refs` (see [[character_resolver]] Pass 4b). It then adds the explicitly chosen feats.
3. For each source card, `applyGrantsFrom(card.fields, sourceLabel)` folds every populated grant key into the working accumulators.
4. Missing refs are silently dropped → surfaced as warnings on [[effective_character]].

## Key Constants / Invariants
- Resolver is **stateless / pure** — safe to call per read; no side effects.
- **Level scaling is a table, not a DSL.** `extra_attack_count_by_level` and `resource_pool_grants[].count_by_level` are `{lvl: value}` maps; the resolver picks the highest `lvl ≤` the character's level. An optional `class_ref` scopes the lookup to that class's level instead of total character level (multiclass correctness).
- **Speed sentinel:** `-1` in a `speed_*_ft` field means "equal to walking speed". An explicit distance is more specific and always beats the sentinel regardless of fold order; between two explicit distances the larger wins.
- **Senses: largest range wins** — Drow's Superior Darkvision 120 beats the base 60. Rows accept `{sense_ref, range_ft}` or a bare ref (a sense with no stated range).
- **Extra attack takes max, not sum** across multiclass grants. Same for `weapon_mastery_count` and same-pool `resource_pool_grants`.
- **State gating replaces predicates.** A card that sets `active_while_state_ref` (a `character-state` Tier-0 ref such as `state:raging`) is conditional: only the four defense keys in `_conditionalGrantKinds` land in `EffectiveCharacter.conditionalGrants` for the sheet to draw as "while raging" chips. Every other grant on that card is skipped — a state-gated numeric bonus must not be folded into a resting sheet total — and its `mechanical_notes` lines are prefixed with the state label.
- **Nothing is silently dropped.** Rules the engine cannot pre-compute (advantage/disadvantage, reroll rules, roll-time damage riders, action-economy timing) live in `mechanical_notes` as one rule per line and render on the sheet under "Other Effects". Under the old DSL these were no-op `kind`s that vanished.
- Refs may be hard or soft → see [[Ref-Resolution-Hard-vs-Soft]].

## What replaced the Effect DSL
Removed 2026-07-28. Measured before the change: of 70 catalogued effect kinds, 25 were both live and used, 8 were live but unused, and **37 were no-ops** — declared in the catalog, authored onto cards, and silently ignored by the resolver.

| Old | New |
|---|---|
| `rule_effects` / `effects` (`FieldType.featEffectList`) | the named grant-block fields above |
| `granted_modifiers` (`FieldType.grantedModifiers`) | same — the second DSL is gone too |
| `kind: proficiency_grant` + `target_kind` | one `granted_*_proficiencies` field per target kind |
| `predicates: [has_state]` | `active_while_state_ref` |
| `predicates: [equipped_armor_kind: none, equipped_shield]` | `unarmored_ac_base` / `unarmored_ac_shield_allowed` (the meaning is in the field name) |
| `scales_with` class-level table | `*_by_level` `{lvl: value}` maps |
| `activation` sub-editor (never read) | `mechanical_notes` prose |
| 37 no-op kinds | `mechanical_notes` prose — now visible for the first time |
| `rules/dnd5e_rule_catalog.dart`, `rule_definition.dart`, `rule_validator.dart`, `rule_catalog_provider.dart` | deleted; `rule_config.dart` (ASI levels, PB breakpoints, hit-die→HP, AC constants) survives at `schema/rule_config.dart` |

Existing data is converted by `migrateRuleEffects` ([[rule_effects_migration]]), wired into world load, built-in synth and package import, so no card loses a mechanic. Unconvertible rows become prose notes rather than disappearing.

## The auto-grant edge was inverted
Removed 2026-07-29, same principle one level up. A Feat used to name the card that hands it out (`feat.auto_granted_by: [{source, source_ref, at_level}]`), so "Paladin gains this at level 9" was stated on the *feat*, invisible on the Paladin card, and the resolver had to scan every feat in the world to answer "what does this class grant?".

Now the **granting card states it, once**: `class`/`subclass` on the `features` row for that level (`granted_feat_refs` / `granted_trait_refs`), `species`/`subspecies` on flat `granted_feat_refs` (no level table), `background` on `origin_feat_ref`. `feat.auto_granted_by` and `FieldType.autoGrantSources` are deleted; [[character_resolver]] Pass 4b now walks the chosen cards instead of the world.

Authoring keeps the old ergonomics without the old data shape: `withFeatureGrant` stamps a build-time-only `_feature_grant` marker that `buildSrdCorePack` Pass 0 (`wireFeatureGrants`) moves onto the source card and strips, so it never reaches `attributes`. Pre-existing world/package data is converted by `invertAutoGrants` (`data/schema/auto_grant_inversion.dart`), a cross-entity migration hooked into world load and package import; a missing source card becomes a `mechanical_notes` line rather than a dropped grant. Guarded by `test/domain/services/feature_grant_edge_test.dart` (15 tests).

> **Consequence for imported content.** A class or subclass with no `features` rows grants nothing, whatever its description says. Every bundled Open5e subclass is currently in that state — see `flutter_app/docs/open5e_content_audit.md`.

## Related
- MoCs: [[Character-System]], [[Content-Pipeline]]
- Coverage: `test/domain/services/srd_grants_integration_test.dart` (13 tests against the real SRD content), `test/data/schema/rule_effects_migration_test.dart` (17).
