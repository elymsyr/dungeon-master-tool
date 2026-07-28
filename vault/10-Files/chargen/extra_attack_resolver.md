---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/extra_attack_resolver.dart
layer: application
language: dart
status: stable
updated: 2026-07-28
tags: [file]
---

# `extra_attack_resolver.dart`

> [!abstract] Primary Purpose
> Pure resolver `resolveExtraAttackCountAt(...)` for the `extra_attack_count` / `extra_attack_count_by_level` grant fields on auto-granted class/subclass feats. A feat declares either a flat integer or a `{lvl: count}` level table (Fighter: 5→2, 11→3, 20→4); the runtime takes the **maximum** across matching grants — matching the precedence `CharacterResolver` already uses (multiclass takes max, not sum).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — single top-level function.
- Reads: `Entity? classEntity`, `Entity? subclassEntity`, `int level`, `Map<String,Entity> entities`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `int resolveExtraAttackCountAt({...})`. Returns 0 when no class, `level < 1`, empty entities, or no matching feat at/below the level.

## Dependencies & Links
- Depends on: `entity.dart`.
- Used by: [[level_up_planner]] (`prevExtraAttackCount`/`newExtraAttackCount`, `isExtraAttackLevel`).
- Domain map: [[Character-System]]
- System flow: [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Builds the set of class+subclass *names*, then scans all `feat` entities; `_isAutoGranted` keeps a feat if any `auto_granted_by` row's `source_ref` name is in that set with `at_level <= level`.
- Among matched feats reads `extra_attack_count_by_level` first (highest `lvl ≤ level` wins), falling back to the flat `extra_attack_count`, and keeps `best = max(best, value)`.

## Notes
- `_isAutoGranted` is the same shape as in [[resource_pool_resolver]] and [[weapon_mastery_resolver]]. `CharacterResolver.applyGrantsFrom` independently reads these same fields at sheet-read time (also max), so the planner preview and the resolved sheet agree.
