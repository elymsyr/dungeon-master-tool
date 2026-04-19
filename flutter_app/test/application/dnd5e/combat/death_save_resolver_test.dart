import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/death_save_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/death_saves.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic RNG that yields a fixed `nextInt(20)` each call so the
/// resolver's branch logic is easy to test without mocking the dart random.
class _FixedRng implements math.Random {
  final int value;
  _FixedRng(this.value);

  @override
  int nextInt(int max) => value;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('DeathSaveResolver.rollOnce', () {
    test('natural 20 returns regainHp=1', () {
      final r = DeathSaveResolver(_FixedRng(19)); // nextInt(20) = 19 → 20
      final roll = r.rollOnce();
      expect(roll.roll, 20);
      expect(roll.regainHp, 1);
    });

    test('natural 1 returns 2 failures', () {
      final r = DeathSaveResolver(_FixedRng(0)); // → 1
      final roll = r.rollOnce();
      expect(roll.roll, 1);
      expect(roll.failuresToAdd, 2);
    });

    test('10..19 is a success', () {
      for (final n in [9, 15, 18]) {
        final roll = DeathSaveResolver(_FixedRng(n)).rollOnce();
        expect(roll.successesToAdd, 1, reason: 'nextInt=$n → roll=${n + 1}');
      }
    });

    test('2..9 is a failure', () {
      for (final n in [1, 5, 8]) {
        final roll = DeathSaveResolver(_FixedRng(n)).rollOnce();
        expect(roll.failuresToAdd, 1, reason: 'nextInt=$n → roll=${n + 1}');
      }
    });
  });

  group('DeathSaveResolver.apply', () {
    final r = DeathSaveResolver(_FixedRng(0));

    test('success tally accumulates', () {
      var s = DeathSaves.zero;
      s = r.apply(s, const DeathSaveRoll(roll: 12, successesToAdd: 1));
      s = r.apply(s, const DeathSaveRoll(roll: 15, successesToAdd: 1));
      expect(s.successes, 2);
      expect(s.isStable, false);
      s = r.apply(s, const DeathSaveRoll(roll: 11, successesToAdd: 1));
      expect(s.isStable, true);
    });

    test('critical failure adds two failures at once', () {
      final s = r.apply(
          DeathSaves.zero, const DeathSaveRoll(roll: 1, failuresToAdd: 2));
      expect(s.failures, 2);
      expect(s.isDead, false);
    });

    test('three failures → dead', () {
      var s = DeathSaves.zero;
      s = r.apply(s, const DeathSaveRoll(roll: 5, failuresToAdd: 1));
      s = r.apply(s, const DeathSaveRoll(roll: 1, failuresToAdd: 2));
      expect(s.isDead, true);
    });

    test('regainHp resets state entirely', () {
      var s = DeathSaves(successes: 2, failures: 2);
      s = r.apply(s, const DeathSaveRoll(roll: 20, regainHp: 1));
      expect(s, DeathSaves.zero);
    });
  });
}
