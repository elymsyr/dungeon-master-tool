import 'dart:math' as math;

import '../../../domain/dnd5e/core/death_saves.dart';

/// Result of one death-save roll.
///
/// - `regainHp = 1` on natural 20 — caller clears `DeathSaves`, wakes the
///   combatant, and removes the Unconscious condition.
/// - `failuresToAdd = 2` on natural 1 (critical).
/// - `successesToAdd = 1` on 10..19.
/// - `failuresToAdd = 1` on 2..9.
class DeathSaveRoll {
  final int roll;
  final int successesToAdd;
  final int failuresToAdd;
  final int regainHp;

  const DeathSaveRoll({
    required this.roll,
    this.successesToAdd = 0,
    this.failuresToAdd = 0,
    this.regainHp = 0,
  });
}

/// Pure resolver for the death-save subsystem. Takes a [math.Random] so tests
/// can inject a seed; the [apply] method folds a roll into an existing
/// [DeathSaves] tally and reports whether the PC became stable, dead, or
/// conscious.
class DeathSaveResolver {
  final math.Random _rng;
  const DeathSaveResolver._(this._rng);

  factory DeathSaveResolver([math.Random? rng]) =>
      DeathSaveResolver._(rng ?? math.Random());

  DeathSaveRoll rollOnce() {
    final d = _rng.nextInt(20) + 1;
    if (d == 20) return DeathSaveRoll(roll: d, regainHp: 1);
    if (d == 1) return const DeathSaveRoll(roll: 1, failuresToAdd: 2);
    if (d >= 10) return DeathSaveRoll(roll: d, successesToAdd: 1);
    return DeathSaveRoll(roll: d, failuresToAdd: 1);
  }

  /// Returns next DeathSaves state; if `regainHp > 0`, resets to zero so the
  /// caller can lift Unconscious. Stable/dead transitions live in DeathSaves.
  DeathSaves apply(DeathSaves current, DeathSaveRoll roll) {
    if (roll.regainHp > 0) return DeathSaves.zero;
    var next = current;
    for (var i = 0; i < roll.successesToAdd; i++) {
      next = next.addSuccess();
    }
    if (roll.failuresToAdd == 2) {
      next = next.addCriticalFailure();
    } else {
      for (var i = 0; i < roll.failuresToAdd; i++) {
        next = next.addFailure();
      }
    }
    return next;
  }
}
