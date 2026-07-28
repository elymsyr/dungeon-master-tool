---
type: file-note
domain: world-content
path: flutter_app/lib/data/schema/rule_effects_migration.dart
layer: data
language: dart
status: stable
updated: 2026-07-28
tags: [file]
---

# `rule_effects_migration.dart`

> [!abstract] Primary Purpose
> One-shot converter from the retired rule-effect DSLs to the named grant fields (`CharacterResolver.grantFieldKeys`). Pre-existing content — user worlds, imported Open5e packs, bundled asset packs — carries mechanics as `rule_effects` / `effects` (feats) / `granted_modifiers` rows shaped `{kind, target_kind, target_ref, value, payload, predicates, scales_with, activation}`. The engine no longer interprets that shape. This rewrites each row into the field it maps to, and renders every row with no mechanical home as a human-readable `mechanical_notes` line, so **nothing an author wrote is silently dropped**.

## Inputs / Outputs
**Inputs**
- `migrateRuleEffects(Map<String, dynamic> fields)` — one entity's raw attribute map.

**Outputs**
- The same map (`identical`, no copy) when none of the three legacy keys are present; otherwise a new map with the legacy keys removed and the named fields populated.
- Also exports `legacyKindNotes` — the `kind → sentence` table, public so the coverage test can assert every historically-accepted kind has a destination.

## Dependencies & Links
- Depends on: nothing (pure leaf; no entity map, no ref resolution — refs are copied through as-authored placeholders).
- Used by (three ingestion seams, all converting on the way in):
  - [[world_repository_impl]] `_loadFromDb` — every world entity on load, so existing local worlds convert transparently the first time they open and persist converted on the next save.
  - `data/database/util/builtin_synth.dart` — the built-in schema synth path.
  - [[package_payload_importer]] `install` — every pack entity on install, so old-format bundled/R2 payloads land already converted.
- Keep in sync with: [[character_resolver]] (`grantFieldKeys` is the target vocabulary).
- Domain map: [[World-and-Content]]
- System flow: [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
Five lookup tables drive the conversion; a row that matches none of them falls to the notes path.
- **`_kindAliases`** — normalises Open5e-importer spellings (`resistance_grant` → `damage_resistance`, `spell_known_grant` → `spell_grant`, …) before dispatch.
- **`_kindToRefList`** — kinds that append their `target_ref` to a ref-list field (`language_grant` → `granted_languages`, `expertise_grant` → `granted_expertise_skills`, the three `damage_*` kinds, `condition_immunity_grant`, the three `granted_*_grant` action kinds, `spell_grant` / `cantrip_grant` / `spell_always_prepared`).
- **`_profTargetToField`** — the single `proficiency_grant` kind fans out by `target_kind` into six fields (skill / tool / saving_throw / save / ability / weapon_category / armor_category), which is exactly the collapse the rule removal was after.
- **`_kindToIntField`** — scalar kinds → int fields; note `hp_bonus_flat` and `hp_max_bonus_total` **both** land on `hp_bonus_flat` (the old pair was a distinction without a difference), and `weapon_mastery_count_bonus` → `weapon_mastery_count`.
- **`legacyKindNotes`** — the ~37 no-op kinds → prose. `{target}` interpolates the target's display name, `{value}` the row's int, `{value:+}` a signed int. `feature_text` maps to the empty string (narrative-only rows contribute nothing). These are the kinds the old resolver accepted and then ignored; after migration they are visible on the sheet for the first time.

Beyond the tables: `has_state` predicates become `active_while_state_ref`; `scales_with` tables become `*_by_level` maps; `unarmored_ac_formula` payloads split into `unarmored_ac_base` / `_abilities` / `_shield_allowed`; `resource_pool_grant` payloads become `resource_pool_grants` rows; `choice_group` becomes `player_choices`. `_sameRef` / `_refName` de-duplicate refs that arrive in mixed placeholder shapes.

## Notes
- **Idempotent by construction** — the guard `_hasLegacyEffects` means a converted map short-circuits on one key lookup, so running this on every world load is cheap.
- Covered by `test/data/schema/rule_effects_migration_test.dart` (17 tests), including a coverage assertion that no kind in the historical set falls through without either a field or a note.
- This is a **compatibility shim, not the destination**. Content authored today writes the named fields directly, and packs rebuilt after 2026-07-28 need no conversion; the shim exists for already-installed packs and saved worlds. See [[mapper_chargen]] for the producer side — until the Open5e packs are re-emitted, every install pays this conversion and some mechanics arrive as prose notes rather than typed fields.
