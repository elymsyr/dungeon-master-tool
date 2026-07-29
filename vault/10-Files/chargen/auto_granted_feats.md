---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/auto_granted_feats.dart
layer: application
language: dart
status: stable
updated: 2026-07-29
tags: [file]
---

# `auto_granted_feats.dart`

> [!abstract] Primary Purpose
> Single reader for *"which feats does this Class / Subclass hand out by level N"*. `autoGrantedFeatsAt({classEntity, subclassEntity, level, entities})` walks the cards' `features` rows at or below the level and returns the referenced `feat` entities, de-duplicated.

## Inputs / Outputs
**Inputs**
- `Entity? classEntity`, `Entity? subclassEntity` — the cards whose level tables are walked.
- `int level` — the character's level **in that class**. Subclass rows use the same number: a subclass is only ever taken inside its parent class, so its L6 row lands at class level 6.
- `Map<String, Entity> entities` — the world, for `resolveEntityRef` and the `feat` slug check.

**Outputs**
- `List<Entity>` of feats, in table order. Empty for `level < 1`, an empty world, or a card with no `features`.

## Dependencies & Links
- Depends on: [[entity_ref]] (`resolveEntityRef`, so a row may carry an id or a `{slug, name}` envelope).
- Consumed by: [[extra_attack_resolver]], [[weapon_mastery_resolver]], [[resource_pool_resolver]].
- Mirrors: [[character_resolver]] Pass 4b, which does the same walk for the resolved sheet. `grant_reader_agreement_test` pins the two against each other across 12 SRD classes × 12 levels.
- Domain map: [[Character-System]]
- System flow: [[Grant-Resolution]]

## Key Logic / Variables
- A row with **no** `level` is treated as level 1 — a narrative header should not silently swallow its grants.
- A `granted_feat_refs` entry pointing at a non-`feat` card is skipped rather than returned; that is bad data, not a grant.

## Notes
- **Why it exists.** Before the 2026-07-29 edge inversion each of the three callers carried a byte-identical private `_isAutoGranted` that scanned every entity in the world for `auto_granted_by`. Three copies of one rule meant any drift between them silently showed the player a wrong chargen preview — and the scan was O(world) per call. See [[Grant-Resolution]].
