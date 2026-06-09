---
type: file-note
domain: world-content
path: flutter_app/lib/domain/entities/schema/field_schema.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
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
- Used by: [[entity_category_schema]], [[package_import_service]] (`_defaultValue` switch on `fieldType`), entity editors, [[character_resolver]] / [[effective_character]] (consume the DSL field shapes)
- Domain map: [[World-and-Content]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- **`FieldType`** (closed enum, JSON-renamed where noted): scalars `text/textarea/markdown/integer/float_(@'float')/boolean_(@'boolean')/enum_(@'enum')/date/dice`; media `image/imagePerEra/file/pdf`; refs `relation` (allowedTypes targets categories), `tagList`; structured D&D types — `statBlock`, `combatStats`, `conditionStats`, `slot`, `proficiencyTable`, `levelTable`, `levelTextTable`, `classFeatures`, `spellEffectList`, `rangedSenseList`, `grantedModifiers` (LEGACY typed-bonus DSL), `equipmentChoiceGroups`, `featEffectList` (the richer effect DSL behind `rule_effects`), `autoGrantSources`, `spellSlotGrid`, `spellSlotProgression`, `subspeciesOptions`, `crCalculator`.
- **Canonical effect-kind registry** lives in `rules/dnd5e_rule_catalog.dart` (NOT here) — debug-cross-checked against `CharacterResolver.knownEffectKinds`. `featEffectList` rows carry `predicates` (AND-combined closed enum), `scales_with`, `activation`. The inline doc comments are the authoritative shape spec for each structured type.
- **`FieldSchema`** key fields: `fieldId`/`categoryId`/`fieldKey`/`label`/`fieldType` (required), `isRequired`, `defaultValue` (dynamic), `placeholder`, `helpText`, `validation`, `visibility` (default `shared`), `orderIndex`, `isBuiltin`, `isList`, `hasEquip`, `showSourceFilter` (relation-list "show all sources"), `allowedInSections`, `subFields` (combatStats sub-columns feeding the encounter table), `groupId`, `gridColumnSpan`, `mediaKindWire` (per-field upload-kind override stored as string to keep `MediaKind` out of the schema layer).
- **`FieldVisibility`**: `shared`, `dmOnly`, `private_(@'private')` — online-mode field visibility gating.

## Notes
- Header comment says "15 types" but the enum has grown well past that — treat the enum as the source of truth.
