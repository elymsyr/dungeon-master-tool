---
type: file-note
domain: content-pipeline
path: flutter_app/lib/domain/entities/schema/builtin/srd_core/_helpers.dart
layer: domain
language: dart
status: stable
updated: 2026-08-20
tags: [file]
---

# `srd_core/_helpers.dart`

> [!abstract] Primary Purpose
> Shared builders + placeholder helpers used across every hand-authored SRD 5.2.1 content file AND the Open5e mappers. Defines the wire-format `packEntity` shape, the two reference-placeholder kinds (`lookup` for Tier-0, `ref` for inter-Tier-1), the build-time `withFeatureGrant` marker, and the equipment-choice-group constructors. A small leaf file — card mechanics are written as plain map literals against the named grant-block keys, not through builders.

## Inputs / Outputs
**Inputs**
- N/A (pure constructors).

**Outputs**
- `packEntity({slug, name, description, source, tags, attributes})` → the wire-format entity map `PackageImportService` consumes (`{name, type, source, description, image_path, images, tags, dm_notes, pdfs, location_id, attributes}`). `attributes` keys must match the target category's `FieldSchema.fieldKey`.
- `lookup(slug, name)` → `{_lookup, name}` (Tier-0, resolved at import).
- `ref(slug, name)` → `{_ref, name}` (inter-Tier-1, resolved during pack-build).
- `withFeatureGrant(row, {source, sourceName, atLevel, featureName})` → the same row plus a `srdFeatureGrantKey` (`_feature_grant`) marker.
- `eqItem(slug, name, {qty})`, `eqOption({optionId, label, items, goldGp})`, `eqGroup({groupId, label, prompt, options})`.
- `saves(List<String> proficient, {misc})` / `skills(Map<String, String> rows, {misc})` → a full `proficiencyTable` value (`{rows: [{name, ability, proficient, expertise, misc}]}`) built from `kDnd5eSavingThrows` / `kDnd5eSkills`.

## Dependencies & Links
- Depends on: `domain/entities/schema/dnd5e_constants.dart` (proficiency-table presets); otherwise a leaf helper.
- Used by: [[srd_core_pack]], [[srd-pack-content]] (all content files), [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]], [[normalize]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]], [[Grant-Resolution]]
- Spec / reference: [[srd_core_pack]], `field_schema`

## Key Logic / Variables
- Uses Dart's null-aware map-entry spread (`'gold_gp': ?goldGp`) so absent optional fields are omitted entirely (keeps the wire format compact).
- **`autoGrantBy` is gone.** The edge was inverted: a feat no longer names the card that grants it. The granting card states it once — `class`/`subclass` on the `features` row for that level, `species`/`subspecies` on `granted_feat_refs`, `background` on `origin_feat_ref`. `withFeatureGrant` is only an *authoring* convenience: it stamps a build-time-only `_feature_grant` marker that [[srd_core_pack]]'s Pass 0 (`wireFeatureGrants`) consumes and strips, so the shipped entity carries the class-side edge and no marker. Pre-existing data is converted by `invertAutoGrants` (`data/schema/auto_grant_inversion.dart`).
- **The effect-DSL builders are gone** (removed 2026-07-28 with the rule system): `effect()`, `predicate()`, `scalesByClass()` and `activation()` no longer exist. Content authors write the grant-block keys directly, e.g. `'granted_damage_resistances': [_dt('Bludgeoning'), …]`, `'extra_attack_count_by_level': {5: 2, 11: 3, 20: 4}`, `'active_while_state_ref': lookup('character-state', 'state:raging')`. See [[Grant-Resolution]] for the full key list.
- **`saves` / `skills` (R7, 2026-08-20)** are the only builders that write a *whole* field value rather than a placeholder. They always emit the complete preset row set — six saving throws, eighteen skills — so a card can never hand the widget a short table, and `'p'` / `'e'` mark proficient vs expertise. `misc` carries the remainder a source's PB does not explain (four SRD cards). Unknown row names hit an `assert`, which turns a typo into a test failure rather than a silently missing row. Written by `monsters.dart` (123 saves / 159 skills) and `animals.dart` (20 / 61); the ~82 creatures whose SRD statblock prints no such line deliberately write neither field.

## Notes
- This is the contract layer between authored content and the runtime resolver — changing a key here ripples through every content file and the importer. The mechanical half of that contract now lives in `CharacterResolver.grantFieldKeys` rather than in builders here.
