import 'dart:math' as math;

import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiceExpression.parse', () {
    test('simple NdS', () {
      final e = DiceExpression.parse('2d6');
      expect(e.terms.length, 1);
      expect(e.terms.first.count, 2);
      expect(e.terms.first.die, Die.d6);
      expect(e.flatBonus, 0);
    });

    test('bare dN defaults count to 1', () {
      final e = DiceExpression.parse('d20');
      expect(e.terms.first.count, 1);
      expect(e.terms.first.die, Die.d20);
    });

    test('NdS+K flat bonus', () {
      final e = DiceExpression.parse('1d8+3');
      expect(e.terms.first.count, 1);
      expect(e.terms.first.die, Die.d8);
      expect(e.flatBonus, 3);
    });

    test('negative bonus', () {
      final e = DiceExpression.parse('2d6-1');
      expect(e.flatBonus, -1);
    });

    test('multiple dice groups', () {
      final e = DiceExpression.parse('1d8+2d6+4');
      expect(e.terms.length, 2);
      expect(e.terms[0].die, Die.d8);
      expect(e.terms[1].die, Die.d6);
      expect(e.flatBonus, 4);
    });

    test('whitespace tolerant', () {
      final e = DiceExpression.parse(' 1d8 + 3 ');
      expect(e.terms.first.die, Die.d8);
      expect(e.flatBonus, 3);
    });

    test('rejects empty', () {
      expect(() => DiceExpression.parse(''), throwsFormatException);
    });

    test('rejects garbage', () {
      expect(() => DiceExpression.parse('banana'), throwsFormatException);
      expect(() => DiceExpression.parse('1d7'), throwsArgumentError);
    });
  });

  group('DiceExpression maxTotal/minTotal/averageFloor', () {
    test('2d6+3', () {
      final e = DiceExpression.parse('2d6+3');
      expect(e.maxTotal, 15);
      expect(e.averageFloor, 2 * 3 + 3);
    });

    test('flat only', () {
      final e = DiceExpression.flat(5);
      expect(e.maxTotal, 5);
      expect(e.averageFloor, 5);
    });
  });

  group('DiceExpression.roll', () {
    test('flat only returns flat', () {
      final rng = math.Random(42);
      expect(DiceExpression.flat(7).roll(rng), 7);
    });

    test('range within [min, max] across many rolls', () {
      final e = DiceExpression.parse('3d6+2');
      final rng = math.Random(1);
      for (var i = 0; i < 100; i++) {
        final r = e.roll(rng);
        expect(r, inInclusiveRange(5, 20));
      }
    });
  });

  group('DiceExpression.toString', () {
    test('canonical render', () {
      expect(DiceExpression.parse('2d6+3').toString(), '2d6+3');
      expect(DiceExpression.parse('d20').toString(), 'd20');
      expect(DiceExpression.parse('1d8-1').toString(), 'd8-1');
      expect(DiceExpression.flat(0).toString(), '0');
    });
  });

  group('DiceExpression equality', () {
    test('structural', () {
      expect(
        DiceExpression.parse('2d6+3') == DiceExpression.parse('2d6+3'),
        isTrue,
      );
      expect(
        DiceExpression.parse('2d6+3') == DiceExpression.parse('2d6+4'),
        isFalse,
      );
    });
  });
}
