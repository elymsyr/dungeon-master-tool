import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/concentration_check_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/concentration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/spell_level.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueRng implements math.Random {
  final List<int> queue;
  int i = 0;
  _QueueRng(this.queue);
  @override
  int nextInt(int max) => queue[i++];
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

ConcentrationCheckResolver _resolver(List<int> rolls) =>
    ConcentrationCheckResolver(SaveResolver(D20Roller(_QueueRng(rolls))));

Concentration _bless() => Concentration(
      spellId: 'srd:bless',
      castAtLevel: SpellLevel(1),
    );

void main() {
  group('DC formula', () {
    test('low damage floors at 10', () {
      final out = _resolver([19]).check(
        current: _bless(),
        damage: 4,
        conMod: 0,
      );
      expect(out.dc, 10);
    });

    test('moderate damage uses floor(damage/2)', () {
      final out = _resolver([19]).check(
        current: _bless(),
        damage: 25,
        conMod: 0,
      );
      expect(out.dc, 12);
    });

    test('massive damage caps at 30', () {
      final out = _resolver([19]).check(
        current: _bless(),
        damage: 200,
        conMod: 0,
      );
      expect(out.dc, 30);
    });

    test('negative damage rejected', () {
      expect(
        () => _resolver([19]).check(
          current: _bless(),
          damage: -1,
          conMod: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('save outcomes', () {
    test('pass keeps concentration', () {
      // dc 10, roll 12 + mod 3 = 15
      final out = _resolver([11]).check(
        current: _bless(),
        damage: 8,
        conMod: 3,
      );
      expect(out.maintained, isTrue);
      expect(out.broken, isFalse);
      expect(out.concentrationAfter, _bless());
      expect(out.save.succeeded, isTrue);
    });

    test('fail breaks concentration', () {
      // dc 12, roll 2 + mod 0 = 2
      final out = _resolver([1]).check(
        current: _bless(),
        damage: 24,
        conMod: 0,
      );
      expect(out.broken, isTrue);
      expect(out.concentrationAfter, isNull);
    });

    test('proficiency bonus added to roll', () {
      // dc 14, roll 7 + mod 2 + prof 5 = 14, just makes it
      final out = _resolver([6]).check(
        current: _bless(),
        damage: 28,
        conMod: 2,
        saveProfBonus: 5,
      );
      expect(out.maintained, isTrue);
    });

    test('advantage picks higher d20', () {
      // dc 10, advantage [3, 18] → 18 + mod 0 = 18
      final out = _resolver([2, 17]).check(
        current: _bless(),
        damage: 5,
        conMod: 0,
        advantage: AdvantageState.advantage,
      );
      expect(out.maintained, isTrue);
      expect(out.save.d20Chosen, 18);
    });

    test('autoFail breaks regardless of roll', () {
      final out = _resolver([]).check(
        current: _bless(),
        damage: 5,
        conMod: 99,
        autoFail: true,
      );
      expect(out.broken, isTrue);
      expect(out.save.resolution, SaveResolution.autoFail);
    });

    test('autoSucceed keeps concentration regardless of damage', () {
      final out = _resolver([]).check(
        current: _bless(),
        damage: 200,
        conMod: -5,
        autoSucceed: true,
      );
      expect(out.maintained, isTrue);
      expect(out.dc, 30);
      expect(out.save.resolution, SaveResolution.autoSucceed);
    });
  });
}
