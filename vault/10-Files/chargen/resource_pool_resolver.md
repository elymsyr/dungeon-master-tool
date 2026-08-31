---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/resource_pool_resolver.dart
layer: application
language: dart
status: stable
updated: 2026-08-31
tags: [file]
---

# `resource_pool_resolver.dart`

> [!abstract] Primary Purpose
> Pure resolver `resolveResourcePoolsAt(...)` for class resource pools (Rage uses, Bardic Inspiration, Channel Divinity, Ki/Focus Points, Wild Shape, Lay on Hands, Sorcery Points, etc.). Walks every `feat` entity auto-granted by the active class/subclass at or below a level, reads each `resource_pool_grants` row, and returns `{pool_ref.name → max count}`.

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
- System flow: [[Grant-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- Auto-grant match comes from the shared [[auto_granted_feats]] `autoGrantedFeatsAt(...)`, the same reader the extra-attack and weapon-mastery resolvers use. Before the inversion each of the three carried its own byte-identical copy of an `auto_granted_by` scan.
- Value resolution tries three sources in order: (1) `count_by_level` — a `{lvl: count}` table, picks the entry with the highest `lvl <= level`; (2) `count_formula` via `evalCountFormula` (e.g. `paladin_level_x5`, `monk_level`, `cha_mod_min_1`) — **skipped when both `abilities` and `classLevels` are empty** so planner-only callers fall through; (3) the flat `count` literal fallback (int or parseable string). Same precedence as `CharacterResolver.applyGrantsFrom`, so the planner preview and the resolved sheet agree.
- When multiple rows grant the same pool name (base + subclass upgrade), keeps the **larger** value so the player isn't downgraded.

## Notes
- `count_formula` support in pools was a deliberate May-2026 fix (shared `evalCountFormula` helper threaded through `planLevelUp` via `_classLevelsForLevel`). The `count_by_level` table replaced the old `scales_with` DSL in the 2026-07-28 rule-system removal.
- Pools are keyed by *name*. **This resolver only feeds the level-up dialog's "what changes" preview**; the sheet's live capacity comes from `CharacterResolver.resourcePools`, keyed by entity **id**. (Until 2026-08-31 the level-up apply path also wrote a copy of the maxes to `class_resource_pools` / `class_resource_pools_remaining` on the PC — nothing ever read those fields and the write is gone.) `pool_ref` is accepted in **both** shapes — an unresolved `{_lookup/slug, name}` placeholder *and* a resolved id string, looked up through the entity map by `_poolName`. An id that resolves to nothing is skipped rather than keyed by the raw uuid.
- **Fixed 2026-07-29:** only the placeholder shape was accepted, so against a resolved entity map (`buildBuiltinSrdEntities()` — i.e. every shipped pack) this returned empty and the level-up dialog showed **no resource pools for any class**. [[character_resolver]] never had the bug, which is why the sheet was right and only the preview was wrong. Pinned by `test/domain/services/grant_reader_agreement_test.dart`, which walks all 12 SRD classes at 12 levels and demands the two readers agree.
- `_isAutoGranted` is duplicated across this file, `extra_attack_resolver.dart`, and `weapon_mastery_resolver.dart`.
