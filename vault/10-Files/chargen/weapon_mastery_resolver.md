---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/weapon_mastery_resolver.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `weapon_mastery_resolver.dart`

> [!abstract] Primary Purpose
> Pure resolver `resolveWeaponMasteryCountAt(...)` for the `weapon_mastery_count_bonus` effect on auto-granted class feats. Each feat declares an integer cap; the runtime takes the **maximum** across grants at or below a level (SRD §1.7: Fighter 3 at L1, others 2; Fighter bumps at L4/L10/L16).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — single top-level function.
- Reads: `Entity? classEntity`, `Entity? subclassEntity`, `int level`, `Map<String,Entity> entities`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `int resolveWeaponMasteryCountAt({...})`. Returns 0 when no class, `level < 1`, empty entities, or no matching feat.

## Dependencies & Links
- Depends on: `entity.dart`.
- Used by: [[level_up_planner]] (`prevWeaponMasteryCount`/`newWeaponMasteryCount` → `weaponMasteryCountDelta` queues a weapon-mastery pending choice).
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]] §1.7

## Key Logic / Variables
- Identical structure to [[extra_attack_resolver]]: build class+subclass name set, scan `feat` entities, `_isAutoGranted` gates on `auto_granted_by` `source_ref` name + `at_level <= level`, then keep `best = max` of `weapon_mastery_count_bonus` effect `value`s.

## Notes
- Initial creation weapon-mastery picks (CharacterDraft `weaponMasteryChoiceIds`, cap Barb 2 / Fighter 3 / Paladin/Ranger/Rogue 2) are stored on the draft separately; this resolver computes the running cap for level-up deltas.
