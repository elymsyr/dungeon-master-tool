import 'dart:math' as math;

import 'package:dungeon_master_tool/presentation/widgets/dice/dice_physics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every die comes to rest flat, showing the face decided up front', () {
    for (var seed = 0; seed < 12; seed++) {
      final roll = throwDice({for (final k in diceKinds) k: 2}, math.Random(seed), trayX: 3.9, trayZ: 2.1);
      for (final d in roll.dice) {
        final (_, q) = d.poseAt(d.steps - 1);
        final m = q.asRotationMatrix();
        double y(DieFace f) => m.transformed(f.normal).y;
        final top = d.shape.faces.reduce((a, b) => y(a) > y(b) ? a : b);
        final bottom = d.shape.faces.reduce((a, b) => y(a) < y(b) ? a : b);
        expect(y(bottom), lessThan(-0.99), reason: '${d.shape.name} seed $seed is not lying flat');
        expect(d.shape.readsBottom ? bottom : top, same(d.face), reason: '${d.shape.name} seed $seed');
      }
    }
  });

  test('results come out per kind, in range, and add up', () {
    final sides = {'d4': 4, 'd6': 6, 'd8': 8, 'd10': 10, 'd12': 12, 'd20': 20, 'd100': 100};
    for (var seed = 0; seed < 20; seed++) {
      final roll = throwDice({'d6': 3, 'd100': 2, 'd20': 1}, math.Random(seed), trayX: 3, trayZ: 5);
      expect(roll.results.keys, ['d6', 'd20', 'd100']);
      expect(roll.dice, hasLength(3 + 1 + 2 * 2));
      for (final MapEntry(key: k, value: vs) in roll.results.entries) {
        expect(vs, everyElement(inInclusiveRange(1, sides[k]!)), reason: k);
      }
      expect(roll.total, roll.results.values.expand((v) => v).reduce((a, b) => a + b));
    }
  });
}
