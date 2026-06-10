---
type: file-note
domain: chargen
path: flutter_app/lib/domain/services/rules/rule_compiler.dart
layer: domain
language: dart
status: stable
updated: 2026-06-10
tags: [file]
---

# `rule_compiler.dart`

> [!abstract] Primary Purpose
> Field→rule interpreter of the rules engine (PR-R2). Compiles a content entity's mechanics — explicit `rule_effects`/`effects`/`granted_modifiers`/`features[].effects` rows PLUS implicit rules derived from typed fields (`granted_skill_refs`, `speed_fly_ft`, `saving_throw_refs`, `prereq_*`, ...) — into ordered [[bound_rule]] lists. "Dynamic rules read the fields on the card"; no data migration of the 20k pack cards.

## Inputs / Outputs
**Inputs**
- Constructor: `entitiesById` (ref resolution), `classLevels` (gates). Pure, stateless.

**Outputs**
- Granular entry points consumed by [[character_resolver]] at the legacy pass positions: `compileFeatures(e, gateLevel)` (Pass 2: `feature_row` display rules + when_level_up effect rules), `compileTopLevelProficiencies` (Pass 8; weapon/armor categories stay VERBATIM strings via `proficiency_grant_raw`), `compileGrantsMap(fieldsMap)` (Pass 5 species/subspecies/legacy-row grants in exact legacy statement order), `compileBackground` (skills/tools + internal `background_asi_apply`), `compileFeat` (`feat_asi_apply` + effects + granted_modifiers), `compileFeatPrereq` (→ prereq_to_grant rule via [[prereq_evaluator]] `effectivePrereqClauses`), `compileRuleEffects` (Pass 5b, trigger defaults per category).
- `compile(e, attachment:, gateLevel:)` — whole-entity aggregate for the editor's derived-rules panel (R3).
- `modifierAsEffect` — legacy grantedModifiers row → effect kind mapping (moved from resolver).

## Dependencies & Links
- Depends on: [[bound_rule]], [[rule_trigger]], [[prereq_evaluator]], [[entity_ref]].
- Used by: [[character_resolver]], derived-rules panel (R3), [[level_up_planner]] (R6).
- Domain map: [[Character-System]] · System flow: [[Effect-DSL-Resolution]], [[Rules-Engine-Triggers]]

## Key Logic / Variables
- **PARITY CONTRACT**: emission order mirrors legacy resolver pass bodies EXACTLY; only rules whose gates already pass are emitted (subclass `granted_at_level`, feature-row level ≤ gate). Debug assert in `effectiveCharacterProvider` diff-checks vs frozen `LegacyCharacterResolver`. Do not reorder emissions.
- Internal effect kinds (resolver wrapper only, never authored/cataloged): `trait_grant`, `alternate_speed`, `level_gated_spells`, `background_asi_apply`, `feat_asi_apply`, `proficiency_grant_raw`, `feature_row`, `prerequisite`.
- `noteSourceOverride` on action/spell/cantrip grant rules reproduces legacy paths that `noteSource`d where `applyEffect` doesn't (grantSources parity).
- `kind: prerequisite` rows without a `trigger` key are inferred prereq_to_grant (never reach applyEffect).
