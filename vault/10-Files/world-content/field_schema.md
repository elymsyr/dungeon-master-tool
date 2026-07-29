---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/schema/field_schema.dart
layer: domain
language: dart
status: stable
updated: 2026-07-29
tags: [file]
---

# `field_schema.dart`

> [!abstract] Primary Purpose
> Defines the `FieldType` enum (the full catalog of supported field widgets, from plain text up to D&D-specific structured types), `FieldVisibility`, `FieldValidation`, and the `FieldSchema` Freezed model that describes a single field on an entity category. This is the heart of the schema-driven entity system — every entity's `fields` map is shaped by these definitions.

## Inputs / Outputs
**Inputs**
- `FieldSchema.fromJson` / `FieldValidation.fromJson`.

**Outputs**
- `FieldType` enum, `FieldVisibility` enum, `FieldValidation` + `FieldSchema` value types.

## Dependencies & Links
- Depends on: `freezed_annotation`
- Used by: [[entity_category_schema]], [[package_import_service]] (`_defaultValue` switch on `fieldType`), entity editors, [[character_resolver]] / [[effective_character]] (consume the grant-block field shapes)
- Domain map: [[World-and-Content]]
- System flow: [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- **`FieldType`** (closed enum, JSON-renamed where noted): scalars `text/textarea/markdown/integer/float_(@'float')/boolean_(@'boolean')/enum_(@'enum')/date/dice`; media `image/imagePerEra/file/pdf`; refs `relation` (allowedTypes targets categories), `tagList`; structured D&D types — `statBlock`, `combatStats`, `conditionStats`, `slot`, `proficiencyTable`, `levelTable`, `levelTextTable`, `classFeatures`, `spellEffectList`, `rangedSenseList`, `equipmentChoiceGroups`, `resourcePoolGrants`, `playerChoices`, `spellsAtLevel`, `autoGrantSources`, `spellSlotGrid`, `spellSlotProgression`, `subspeciesOptions`, `crCalculator`.
- **No effect-kind registry.** `featEffectList` and `grantedModifiers` — the two competing effect DSLs — were deleted in the 2026-07-28 rule-system removal along with `rules/dnd5e_rule_catalog.dart`. Card mechanics are now plainly named fields built on the ordinary types above (`relation` lists, `integer`, `statBlock`, `levelTable`, `textarea`); the closed contract is `CharacterResolver.grantFieldKeys`, emitted onto categories by `_FB.grantBlock` in `builtin/content.dart`. See [[Grant-Resolution]].
- The two structured types added in their place: **`resourcePoolGrants`** (`{pool_ref, recharge, count?, count_formula?, count_by_level?, class_ref?}` — per-rest pools like Rage/Ki/Bardic Inspiration) and **`playerChoices`** (`{group_id, label, prompt, pick_kind, pick, options?, list_group_id?, spell_level?}` — deferred "pick N of these" decisions read by [[pending_choices]]). Net zero: two types out, two in.
- **`spellsAtLevel`** (added 2026-07-29): `{spell_ref, at_level, is_cantrip?, uses_per_long_rest?}` — the level-gated sibling of `granted_spell_refs` (Drow's Faerie Fire at 3, Darkness at 5). The resolver had read `granted_spells_at_level` since the removal, but no `FieldType` and no schema field existed for it, so six shipped subspecies carried a mechanic nobody could see or edit.
- The inline doc comments on each enum value are the authoritative shape spec for that structured type.
- **`FieldSchema`** key fields: `fieldId`/`categoryId`/`fieldKey`/`label`/`fieldType` (required), `isRequired`, `defaultValue` (dynamic), `placeholder`, `helpText`, `validation`, `visibility` (default `shared`), `orderIndex`, `isBuiltin`, `isList`, `hasEquip`, `showSourceFilter` (relation-list "show all sources"), `allowedInSections`, `subFields` (combatStats sub-columns feeding the encounter table), `groupId`, `gridColumnSpan`, `mediaKindWire` (per-field upload-kind override stored as string to keep `MediaKind` out of the schema layer).
- **`FieldVisibility`**: `shared`, `dmOnly`, `private_(@'private')` — online-mode field visibility gating.

## Notes
- Header comment says "15 types" but the enum has grown well past that — treat the enum as the source of truth.
