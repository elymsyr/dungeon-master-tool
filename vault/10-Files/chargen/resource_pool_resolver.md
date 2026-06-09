---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/resource_pool_resolver.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `resource_pool_resolver.dart`

> [!abstract] Primary Purpose
> Pure resolver `resolveResourcePoolsAt(...)` for class resource pools (Rage uses, Bardic Inspiration, Channel Divinity, Ki/Focus Points, Wild Shape, Lay on Hands, Sorcery Points, etc.). Walks every `feat` entity auto-granted by the active class/subclass at or below a level, reads each `resource_pool_grant` effect, and returns `{pool_ref.name → max count}`.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — single top-level function.
- Reads: `Entity? classEntity`, `Entity? subclassEntity`, `int level`, `Map<String,Entity> entities`, optional `Map<String,int> abilities`, `Map<String,int> classLevels`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `Map<String,int> resolveResourcePoolsAt({...})`. Empty when no class supplied, `level < 1`, or no feat applies.

## Dependencies & Links
- Depends on: `entity.dart`, `count_formula.dart` (`evalCountFormula`).
- Used by: [[level_up_planner]] (`prevResourcePools`/`newResourcePools`).
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Auto-grant match (`_isAutoGranted`, identical to the extra-attack / weapon-mastery resolvers): a feat is in scope if any `auto_granted_by` row's `source_ref` resolves to the class or subclass *name* and `at_level <= level`.
- Value resolution (`_resolveValue`) tries three sources in order: (1) `scales_with.table` — picks the entry with the highest `lvl <= level`; (2) `payload.count_formula` via `evalCountFormula` (e.g. `paladin_level_x5`, `monk_level`, `cha_mod_min_1`) — **skipped when both `abilities` and `classLevels` are empty** so planner-only callers fall through; (3) `payload.count` literal fallback (int or parseable string).
- When multiple effects grant the same pool name (base + subclass upgrade), keeps the **larger** value so the player isn't downgraded.

## Notes
- `count_formula` support in pools was a deliberate May-2026 fix (shared `evalCountFormula` helper threaded through `planLevelUp` via `_classLevelsForLevel`).
- `_isAutoGranted` is duplicated across this file, `extra_attack_resolver.dart`, and `weapon_mastery_resolver.dart`.
