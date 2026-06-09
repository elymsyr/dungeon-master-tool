---
type: file-note
domain: content-pipeline
path: flutter_app/tool/open5e_import/loaders.dart
layer: tool
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `loaders.dart`

> [!abstract] Primary Purpose
> Tiny fixture-reading utilities. Every Open5e data file is a JSON array of Django fixture records `{model, pk, fields}`. These helpers flatten each record to a `{_pk, ...fields}` map and provide the parent-grouping/indexing primitives the mappers use to reassemble the normalized v2 graph (Creature ← CreatureAction ← Attack, Creature ← CreatureTrait, Class ← ClassFeature, …).

## Inputs / Outputs
**Inputs**
- File paths to `*.json` Django-fixture arrays.

**Outputs**
- `typedef Fixture = Map<String, dynamic>` (one flattened record).
- `List<Fixture> loadFixtures(String path)` — `[]` if the file is absent (a doc may not carry every content type).
- `Map<String, List<Fixture>> groupBy(rows, key)` — group children by a parent-key value (e.g. `'parent'`).
- `Map<String, Fixture> byPk(rows)` — index by primary key.

## Dependencies & Links
- Depends on: `dart:io`, `dart:convert` only.
- Used by: [[build_packs]], [[mapper_monster]], [[mapper_spell]], [[mapper_item]], [[mapper_chargen]].
- Domain map: [[Content-Pipeline]]
- System flow: [[Pack-Build-Two-Pass-Refgraph]]
- Spec / reference: [[Open5e-API]]

## Key Logic / Variables
- `loadFixtures`: each record's `fields` map is spread into the output alongside `'_pk': r['pk']`. Non-Map records and records without a `fields` map are skipped. A missing file returns `const []` (no throw).
- Mappers rely on `_pk` as the join key: `groupBy(actions, 'parent')` keys child rows by the parent creature/class pk.

## Notes
- No app imports — purely a build-time helper. Trivial enough to read in full if ever needed.
