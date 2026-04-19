import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the next value from a fixed queue each time nextInt is called.
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

void main() {
  group('D20Roller', () {
    test('normal: single roll used', () {
      final r = D20Roller(_QueueRng([14]));
      final o = r.roll(AdvantageState.normal);
      expect(o.chosen, 15);
      expect(o.other, 15);
      expect(o.state, AdvantageState.normal);
    });

    test('advantage: picks higher of two', () {
      final r = D20Roller(_QueueRng([4, 19]));
      final o = r.roll(AdvantageState.advantage);
      expect(o.chosen, 20);
      expect(o.other, 5);
    });

    test('disadvantage: picks lower of two', () {
      final r = D20Roller(_QueueRng([17, 2]));
      final o = r.roll(AdvantageState.disadvantage);
      expect(o.chosen, 3);
      expect(o.other, 18);
    });

    test('nat-20 + nat-1 helpers', () {
      final twenty = D20Roller(_QueueRng([19])).roll(AdvantageState.normal);
      expect(twenty.isNaturalTwenty, true);
      final one = D20Roller(_QueueRng([0])).roll(AdvantageState.normal);
      expect(one.isNaturalOne, true);
    });
  });
}
