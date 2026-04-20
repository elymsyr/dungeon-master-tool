# 11 — Combat Engine Spec

> **For Claude.** Manual combat tracker (MVP). Auto-resolve = Future Work.
> **Source rules:** [00 §6-§14](./00-dnd5e-mechanics-reference.md#7-combat-flow-pp-13-14)
> **Target:** `flutter_app/lib/application/dnd5e/combat/`, `flutter_app/lib/presentation/screens/dnd5e/combat/`
> **UI migration:** Legacy `SessionScreen` (1851 LOC, reads `EncounterConfig` + `EncounterLayout` from `WorldSchema`) is rewired to read from `EncounterService` + typed `Combatant` rows — see [`50-typed-ui-migration.md`](./50-typed-ui-migration.md) Batch 5. The **initiative column layout / HP bar / condition chip / turn arrow / action-log / AoE overlay** are **preserved verbatim**. Only the data source for each combatant's card content changes (typed `Monster` / `Dnd5eCharacter` row via `TypedCardDispatcher` inspector panel instead of schema-driven `EntityCard`).

## Scope

**MVP (this doc):**
- Turn-based encounter state (initiative, round, turn index).
- Combatant HP / conditions / concentration manual editing by DM.
- Action economy tracking (action used? bonus used? reaction used?).
- Manual damage entry with resistance/vuln auto-application.
- Death save tracker.
- Condition expiration on round/turn boundaries.
- Player view: read-only combat state (with private DM info redacted).

**Future Work (separate doc):**
- Auto-resolve attack rolls and damage.
- Auto-spell-slot decrement.
- Auto-target selection.
- AI for monster tactics.

## Domain Types

```dart
// flutter_app/lib/domain/dnd5e/combat/encounter.dart

class Encounter {
  final String id;
  final String campaignId;
  final String name;
  final List<Combatant> combatants;       // ordered by initiative desc
  final int round;                         // starts at 1
  final int turnIndex;                     // index into combatants
  final EncounterPhase phase;              // setup | active | ended
  final BattleMapState? map;
  ...
}

enum EncounterPhase { setup, active, ended }

sealed class Combatant {
  String get id;
  String get displayName;
  int get currentHp;
  int get maxHp;
  int get tempHp;
  int get armorClass;
  int get initiativeRoll;
  int get initiativeTiebreaker;     // for stable ordering
  Set<ContentReference<Condition>> get conditionIds;                // namespaced: 'srd:stunned'
  Map<ContentReference<Condition>, int> get conditionDurationsRounds;
  Set<ContentReference<DamageType>> get resistances;
  Set<ContentReference<DamageType>> get vulnerabilities;
  Set<ContentReference<DamageType>> get damageImmunities;
  Concentration? get concentration;
  TurnState get turnState;
  TokenPosition? get tokenPosition;
  Visibility get visibility;        // visible | hidden | invisible
}

class TurnState {
  final bool actionUsed;
  final bool bonusActionUsed;
  final bool reactionUsed;
  final bool moveUsedFt;            // movement remaining derived from speed
  final int movementUsedFt;
  final List<EffectApplication> appliedThisTurn;
  TurnState reset() => const TurnState();
}

class Concentration {
  final String spellId;
  final List<String> affectedCombatantIds;
  final int? roundsRemaining;
  final int? saveDcOnDamage;        // computed at last damage event
}
```

## Encounter Service

```dart
// flutter_app/lib/application/dnd5e/combat/encounter_service.dart

class EncounterService {
  final EncounterRepository repo;

  EncounterService(this.repo);

  Future<Encounter> create({required String campaignId, required String name}) async { ... }

  Future<void> addCombatant(String encounterId, Combatant c) async { ... }
  Future<void> removeCombatant(String encounterId, String combatantId) async { ... }

  /// Roll initiative for everyone. Sort desc. Set phase=active, round=1, turnIndex=0.
  Future<Encounter> startCombat(String encounterId, {bool autoRoll = true}) async {
    final e = await repo.load(encounterId);
    final rolled = e.combatants.map((c) {
      final init = autoRoll
        ? Dice.d20() + c.initiativeMod()
        : c.initiativeRoll;
      return c.copyWith(initiativeRoll: init);
    }).toList()..sort(_initiativeOrder);
    final next = e.copyWith(combatants: rolled, round: 1, turnIndex: 0, phase: EncounterPhase.active);
    await repo.save(next);
    return next;
  }

  /// Advance to next turn. Resets reaction/bonus/action of new active combatant.
  /// Triggers turn-end hooks of previous combatant.
  Future<Encounter> nextTurn(String encounterId) async {
    final e = await repo.load(encounterId);
    final prev = e.combatants[e.turnIndex];
    final updatedPrev = prev.copyWith(turnState: prev.turnState);   // expire turn-end effects
    var newIndex = e.turnIndex + 1;
    var newRound = e.round;
    if (newIndex >= e.combatants.length) {
      newIndex = 0;
      newRound++;
    }
    // On the new combatant's turn: reset turnState; refresh reaction; tick condition durations.
    final newActive = e.combatants[newIndex];
    final newActiveReset = newActive.copyWith(
      turnState: const TurnState(),
      conditionDurationsRounds: _tickDurations(newActive.conditionDurationsRounds),
      conditionIds: _expireConditions(newActive.conditionIds, newActive.conditionDurationsRounds),
    );
    final updatedList = [...e.combatants];
    updatedList[e.turnIndex] = updatedPrev;
    updatedList[newIndex] = newActiveReset;
    final next = e.copyWith(combatants: updatedList, turnIndex: newIndex, round: newRound);
    await repo.save(next);
    return next;
  }

  Future<void> applyDamage(String encounterId, String combatantId, DamageInstance dmg) async { ... }
  Future<void> applyHealing(String encounterId, String combatantId, int amount) async { ... }
  Future<void> applyCondition(String encounterId, String combatantId, ContentReference<Condition> conditionId, {int? durationRounds}) async { ... }
  Future<void> removeCondition(String encounterId, String combatantId, ContentReference<Condition> conditionId) async { ... }
  Future<void> setConcentration(String encounterId, String combatantId, Concentration? conc) async { ... }
  Future<void> markActionUsed(String encounterId, String combatantId, ActionType type) async { ... }
  Future<void> rollDeathSave(String encounterId, String combatantId) async { ... }
}
```

## Damage Application Pipeline

```dart
// flutter_app/lib/application/dnd5e/combat/damage_resolver.dart

class DamageInstance {
  final int amount;
  final ContentReference<DamageType> typeId;   // 'srd:fire'
  final bool isCritical;
  final bool fromSavedThrow;       // half-on-success effect
  final bool savedSucceeded;
  final String? sourceSpellId;     // for concentration trigger
}

class DamageResolver {
  /// Pure function. Returns modified damage + side-effect descriptors.
  DamageOutcome resolve(Combatant target, DamageInstance dmg) {
    int amt = dmg.amount;

    // 1. Adjustments (e.g., aura -5). MVP: skip; auras come later.

    // 2. Resistance.
    if (target.resistances.contains(dmg.typeId)) amt = (amt / 2).floor();

    // 3. Vulnerability.
    if (target.vulnerabilities.contains(dmg.typeId)) amt = amt * 2;

    // 4. Immunity (already 0 if).
    if (target.damageImmunities.contains(dmg.typeId)) amt = 0;

    // 5. Savefor-half: apply half if save succeeded.
    // (Already counted in dmg.amount if caller halved; or handle here based on flag.)
    if (dmg.fromSavedThrow && dmg.savedSucceeded) amt = (amt / 2).floor();

    // 6. Temp HP buffer.
    int tempHpAfter = target.tempHp;
    int realDamage = amt;
    if (target.tempHp > 0) {
      final absorbed = math.min(target.tempHp, amt);
      tempHpAfter = target.tempHp - absorbed;
      realDamage = amt - absorbed;
    }

    final hpAfter = math.max(0, target.currentHp - realDamage);

    // 7. Concentration check trigger.
    final concBroken = _checkConcentration(target, amt, dmg);

    // 8. Massive Damage (PCs only): if realDamage ≥ maxHp at 0 HP transition → instant death.
    final instantDeath = (target is PlayerCombatant) && (hpAfter == 0) && (realDamage >= target.maxHp);

    return DamageOutcome(
      newCurrentHp: hpAfter,
      newTempHp: tempHpAfter,
      concentrationBroken: concBroken,
      instantDeath: instantDeath,
      criticalDeathSaveFailures: (hpAfter == 0 && dmg.isCritical) ? 2 : (hpAfter == 0 ? 1 : 0),
    );
  }
}
```

## Death Saving Throw Tracker

```dart
// flutter_app/lib/application/dnd5e/combat/death_save_resolver.dart

class DeathSaveResolver {
  DeathSaveOutcome roll(PlayerCombatant pc) {
    final d = Dice.d20();
    if (d == 20) return DeathSaveOutcome(regainHp: 1);
    if (d == 1) return DeathSaveOutcome(failures: 2);
    if (d >= 10) return DeathSaveOutcome(successes: 1);
    return DeathSaveOutcome(failures: 1);
  }

  /// Apply outcome cumulatively; transition to Stable / Dead at thresholds.
  PlayerCombatant apply(PlayerCombatant pc, DeathSaveOutcome o) {
    if (o.regainHp != null) {
      return pc.copyWith(currentHp: o.regainHp, deathSaves: const DeathSaves.zero(),
                        conditionIds: pc.conditionIds.difference({'srd:unconscious'}));
    }
    var ds = pc.deathSaves.copyWith(
      successes: pc.deathSaves.successes + (o.successes ?? 0),
      failures: pc.deathSaves.failures + (o.failures ?? 0),
    );
    if (ds.successes >= 3) {
      // Stable
      return pc.copyWith(deathSaves: const DeathSaves.zero(), isStable: true);
    }
    if (ds.failures >= 3) {
      return pc.copyWith(isDead: true, deathSaves: const DeathSaves.zero());
    }
    return pc.copyWith(deathSaves: ds);
  }
}
```

## Condition Duration Ticking

Conditions with explicit duration in rounds tick down at the start of the affected combatant's turn (per spec). Conditions without duration (Petrified by spell, etc.) persist until removed. Conditions are referenced by namespaced id (`ContentReference<Condition>`); the resolver never switches on specific ids — it reads the condition's compiled `ConditionInteraction` descriptor.

```dart
Map<String, int> _tickDurations(Map<String, int> in_) {
  return {for (final e in in_.entries) e.key: e.value - 1};
}
Set<String> _expireConditions(Set<String> active, Map<String, int> dur) {
  return active.where((id) {
    if (!dur.containsKey(id)) return true;
    return dur[id]! > 1;
  }).toSet();
}
```

### Compiled-tag lookups

Engine logic that used to switch on the `Condition` enum now consults the compiled `ConditionInteraction` for each active condition id:

```dart
bool isIncapacitated(Combatant c, ContentRegistry reg, EffectCompiler compiler) {
  return c.conditionIds.any((id) {
    final cond = reg.conditions[id];
    if (cond == null) return false;  // dangling — already surfaced by validator
    return compiler.conditionInteraction(cond).incapacitated;
  });
}

Set<Ability> autoFailedSaveAbilities(Combatant c, ContentRegistry reg, EffectCompiler compiler) {
  final result = <Ability>{};
  for (final id in c.conditionIds) {
    final cond = reg.conditions[id];
    if (cond != null) result.addAll(compiler.conditionInteraction(cond).autoFailSavesOf);
  }
  return result;
}
```

The concentration-broken-by-incapacitation check, the "attacks against have advantage" rule, and the auto-fail STR/DEX save on Stunned all read these compiled tags rather than matching condition ids.

## UI: Combat Tracker Screen

`presentation/screens/dnd5e/combat/combat_tracker_screen.dart`

```
Layout (responsive):
  Mobile (<600w):  vertical list of combatants; tap to expand details
  Tablet:          two-pane: list + detail
  Desktop:         three-pane: list + detail + battlemap
```

### Combatant Row

```
[init] [token thumb] [Name              ] [HP bar]   [conditions chip row]   [Active turn ▶]
```

Tap → expand:
- HP +/- input.
- Apply Damage button (modal: amount, type dropdown, crit toggle, save-half toggle).
- Apply Healing.
- Conditions: add/remove with duration.
- Concentration: spellId + rounds remaining.
- Action economy: 3 toggles (Action / Bonus / Reaction) — auto-reset on turn start.
- Death saves (if PC at 0 HP): 3 success / 3 fail boxes + roll button.

### Bottom Bar

`Round: 3   Turn: Bugbear (init 14)   [Prev Turn] [End Turn] [Add Combatant] [End Combat]`

## Player View

When connected as Player role:
- See own combatant fully.
- See other PCs: full HP visible (party transparency).
- See monsters: name, **Bloodied** flag instead of exact HP, conditions, AC hidden.
- See whose turn it is.
- Cannot edit anyone's state directly. Only request actions via [24](./24-player-action-protocol.md).

## Dice Roller

`flutter_app/lib/application/dnd5e/dice/dice.dart`:

```dart
class Dice {
  static int d4() => _rng.nextInt(4) + 1;
  static int d6() => _rng.nextInt(6) + 1;
  static int d8() => _rng.nextInt(8) + 1;
  static int d10() => _rng.nextInt(10) + 1;
  static int d12() => _rng.nextInt(12) + 1;
  static int d20() => _rng.nextInt(20) + 1;
  static int d100() => _rng.nextInt(100) + 1;
  static int roll(DiceExpression e) => e.roll();
}
```

`DiceExpression`: parses `'2d6+3'`, `'1d20'`, `'(1d4+1)d6'` (rare). MVP: simple `XdY[+Z]` parser. Extend later.

## Acceptance

- DM can create encounter, add 5+ combatants, start combat.
- Initiative auto-rolls and orders correctly.
- Next/Prev turn cycles through; round increments correctly.
- Apply damage to combatant: HP decreases, resistance halves, vuln doubles, temp HP absorbs first.
- 0 HP triggers Unconscious + death save prompts (PC) or death (monster).
- Concentration check fires on damage to concentrating caster (DC = max(10, half damage), capped 30).
- Conditions with duration expire on round boundary.
- `flutter test` covers DamageResolver + DeathSaveResolver with 50+ scenarios.

## Open Questions

1. Should encounter state be optimistically updated locally then synced? → Yes (MVP local-only; online sync per [21](./21-realtime-protocol.md)).
2. Initiative tie resolution — auto-randomize or prompt? → **Auto-randomize** with stable tiebreaker stored on combatant; DM can manually swap.
3. Should turn timer (in-game 6 sec) be enforced or shown? → No enforcement; optional display.
