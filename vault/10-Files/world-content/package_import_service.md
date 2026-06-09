---
type: file-note
domain: world-content
path: flutter_app/lib/application/services/package_import_service.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `package_import_service.dart`

> [!abstract] Primary Purpose
> One-shot (copy-in) import of a package's entities into the active world. Mints fresh UUIDs, matches package categories to world categories by NAME, maps fields key-then-label-then-default, remaps relation refs to the new IDs, and pushes the whole import as a single undo step. Distinct from the live-link path in `PackageSyncService`.

## Inputs / Outputs
**Inputs**
- `importPackage(packageEntities, packageSchema, worldSchema, entityNotifier, pushUndo)`.
- Static `resolveLookupPlaceholder(value, tier0NameToId)` — resolves `{'_lookup': slug, 'name': row}` placeholders to real per-world UUIDs.

**Outputs**
- Returns the count of imported entities; calls `entityNotifier.addEntities(newEntities)` and (unless `pushUndo == false`) `entityNotifier.pushUndo(currentEntities)`.
- No direct DB writes — persistence happens through `EntityNotifier`.

## Dependencies & Links
- Depends on: [[entity]], [[world_schema]], [[entity_category_schema]], [[field_schema]]
- Used by: package install UI, [[srd_core_pack]] bootstrap (`pushUndo: false`), `EntityNotifier`
- Domain map: [[World-and-Content]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: [[Content-Pipeline]]

## Key Logic / Variables
- **ID remap**: builds `idMapping[oldId] = uuid.v4()` for every package entity FIRST, so intra-batch relation refs resolve in one pass.
- **Category match by name**: pkg slug -> pkg category name -> world category by name. Unknown pkg category or missing world category => entity SKIPPED.
- **Field mapping** (`_mapFields`) per world field, in priority order: (1) same `fieldKey` present in pkg attrs; (2) label-based match (`pkgLabelToKey[worldField.label]`); (3) `_defaultValue`. Relation-type fields run `_remapRelation` (rewrites string + list refs through `idMapping`; leaves external refs untouched).
- **`_defaultValue`** returns per-`FieldType` zero values; notable typed defaults — `statBlock` => all-10 ability map, `combatStats` => empty hp/max_hp/ac/speed/cr/xp/initiative, `proficiencyTable` => `{'rows': []}`, and empty lists for `classFeatures`/`spellEffectList`/`rangedSenseList`/`grantedModifiers`/`equipmentChoiceGroups`/`featEffectList`. `defaultValue`/`isList` on the schema win first.
- **`resolveLookupPlaceholder`** (Tier-0 lookup resolution): a `{_lookup, name}` map resolves to `tier0NameToId[slug][name]` (or `''` if absent). Recurses into nested maps/lists, coercing keys to `String` so downstream `jsonEncode` never sees `_Map<dynamic,dynamic>`.

## Notes
- This is the descriptive copy-in path; for live-linked packs that re-sync on pack update see [[package_sync_service]].
