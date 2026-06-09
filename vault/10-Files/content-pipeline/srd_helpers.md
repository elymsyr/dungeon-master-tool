---
type: file-note
domain: content-pipeline
path: flutter_app/lib/domain/entities/schema/builtin/srd_core/_helpers.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `srd_core/_helpers.dart`

> [!abstract] Primary Purpose
> Shared builders + placeholder helpers used across every hand-authored SRD 5.2.1 content file AND the Open5e mappers. Defines the wire-format `packEntity` shape, the two reference-placeholder kinds (`lookup` for Tier-0, `ref` for inter-Tier-1), and the structured DSL constructors for the `CharacterResolver` (effects, predicates, scales_with, activation, auto-grant, equipment choice groups).

## Inputs / Outputs
**Inputs**
- N/A (pure constructors).

**Outputs**
- `packEntity({slug, name, description, source, tags, attributes})` → the wire-format entity map `PackageImportService` consumes (`{name, type, source, description, image_path, images, tags, dm_notes, pdfs, location_id, attributes}`). `attributes` keys must match the target category's `FieldSchema.fieldKey`.
- `lookup(slug, name)` → `{_lookup, name}` (Tier-0, resolved at import).
- `ref(slug, name)` → `{_ref, name}` (inter-Tier-1, resolved during pack-build).
- `effect(kind, {targetKind, targetRef, value, payload, predicates, scalesWith, activation})`, `predicate(kind, [args])`, `scalesByClass(className, rows)`, `activation({...})`, `autoGrantBy({source, sourceName, atLevel, choiceRequired})`.
- `eqItem(slug, name, {qty})`, `eqOption({optionId, label, items, goldGp})`, `eqGroup({groupId, label, prompt, options})`.

## Dependencies & Links
- Depends on: nothing (leaf helper).
- Used by: [[srd_core_pack]], [[srd-pack-content]] (all content files), [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]], [[normalize]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]], [[Effect-DSL-Resolution]]
- Spec / reference: [[srd_core_pack]], `field_schema`

## Key Logic / Variables
- Uses Dart's null-aware map-entry spread (`'gold_gp': ?goldGp`) so absent optional fields are omitted entirely (keeps the wire format compact).
- `effect` wrappers honored by `CharacterResolver`: `predicates` are AND-combined per row; `scales_with` picks the largest table row with `lvl ≤` the character's class level; `activation` carries action-economy/duration/uses (no resolver effect — the combat tracker reads it).
- `autoGrantBy` emits `{source, source_ref: ref(slug, sourceName), at_level?, choice_required?}` where `source` ∈ `class | subclass | species | background` — declares a feat auto-applied at the matching class+level/species/background.
- `scalesByClass` builds `{kind: class_level, class_ref: ref('class', …), table: [{lvl, v}]}`.

## Notes
- This is the contract layer between authored content and the runtime resolver — changing a key here ripples through every content file and the importer.
