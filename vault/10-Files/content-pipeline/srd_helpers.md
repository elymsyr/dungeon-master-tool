---
type: file-note
domain: content-pipeline
path: flutter_app/lib/domain/entities/schema/builtin/srd_core/_helpers.dart
layer: domain
language: dart
status: stable
updated: 2026-07-28
tags: [file]
---

# `srd_core/_helpers.dart`

> [!abstract] Primary Purpose
> Shared builders + placeholder helpers used across every hand-authored SRD 5.2.1 content file AND the Open5e mappers. Defines the wire-format `packEntity` shape, the two reference-placeholder kinds (`lookup` for Tier-0, `ref` for inter-Tier-1), the `autoGrantBy` edge, and the equipment-choice-group constructors. A small leaf file (~87 lines) — card mechanics are written as plain map literals against the named grant-block keys, not through builders.

## Inputs / Outputs
**Inputs**
- N/A (pure constructors).

**Outputs**
- `packEntity({slug, name, description, source, tags, attributes})` → the wire-format entity map `PackageImportService` consumes (`{name, type, source, description, image_path, images, tags, dm_notes, pdfs, location_id, attributes}`). `attributes` keys must match the target category's `FieldSchema.fieldKey`.
- `lookup(slug, name)` → `{_lookup, name}` (Tier-0, resolved at import).
- `ref(slug, name)` → `{_ref, name}` (inter-Tier-1, resolved during pack-build).
- `autoGrantBy({source, sourceName, atLevel, choiceRequired})`.
- `eqItem(slug, name, {qty})`, `eqOption({optionId, label, items, goldGp})`, `eqGroup({groupId, label, prompt, options})`.

## Dependencies & Links
- Depends on: nothing (leaf helper).
- Used by: [[srd_core_pack]], [[srd-pack-content]] (all content files), [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]], [[normalize]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]], [[Grant-Resolution]]
- Spec / reference: [[srd_core_pack]], `field_schema`

## Key Logic / Variables
- Uses Dart's null-aware map-entry spread (`'gold_gp': ?goldGp`) so absent optional fields are omitted entirely (keeps the wire format compact).
- `autoGrantBy` emits `{source, source_ref: ref(slug, sourceName), at_level?, choice_required?}` where `source` ∈ `class | subclass | species | background` — declares a feat auto-applied at the matching class+level / species / background.
- **The effect-DSL builders are gone** (removed 2026-07-28 with the rule system): `effect()`, `predicate()`, `scalesByClass()` and `activation()` no longer exist. Content authors write the grant-block keys directly, e.g. `'granted_damage_resistances': [_dt('Bludgeoning'), …]`, `'extra_attack_count_by_level': {5: 2, 11: 3, 20: 4}`, `'active_while_state_ref': lookup('character-state', 'state:raging')`. See [[Grant-Resolution]] for the full key list.

## Notes
- This is the contract layer between authored content and the runtime resolver — changing a key here ripples through every content file and the importer. The mechanical half of that contract now lives in `CharacterResolver.grantFieldKeys` rather than in builders here.
