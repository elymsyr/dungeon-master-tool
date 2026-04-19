import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/dice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dice', () {
    test('d20 returns 1..20 across samples', () {
      final d = Dice(math.Random(0));
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        final r = d.d20();
        expect(r, inInclusiveRange(1, 20));
        seen.add(r);
      }
      expect(seen.length, greaterThan(10));
    });

    test('all single-die helpers stay in range', () {
      final d = Dice(math.Random(1));
      for (var i = 0; i < 50; i++) {
        expect(d.d4(), inInclusiveRange(1, 4));
        expect(d.d6(), inInclusiveRange(1, 6));
        expect(d.d8(), inInclusiveRange(1, 8));
        expect(d.d10(), inInclusiveRange(1, 10));
        expect(d.d12(), inInclusiveRange(1, 12));
        expect(d.d100(), inInclusiveRange(1, 100));
      }
    });

    test('same seed reproduces the same sequence', () {
      final a = Dice(math.Random(42));
      final b = Dice(math.Random(42));
      final sa = List.generate(20, (_) => a.d20());
      final sb = List.generate(20, (_) => b.d20());
      expect(sa, sb);
    });

    test('roll("2d6+3") stays within [5, 15]', () {
      final d = Dice(math.Random(7));
      for (var i = 0; i < 50; i++) {
        final r = d.roll('2d6+3');
        expect(r, inInclusiveRange(5, 15));
      }
    });
  });
}
