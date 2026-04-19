import 'package:dungeon_master_tool/domain/dnd5e/core/exhaustion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Exhaustion', () {
    test('range 0..6', () {
      expect(() => Exhaustion(-1), throwsArgumentError);
      expect(() => Exhaustion(7), throwsArgumentError);
    });

    test('d20Penalty = -2 * level (returned positive)', () {
      expect(Exhaustion(0).d20Penalty, 0);
      expect(Exhaustion(1).d20Penalty, 2);
      expect(Exhaustion(5).d20Penalty, 10);
    });

    test('gain clamps at 6', () {
      expect(Exhaustion(5).gain(5).level, 6);
    });

    test('reduce clamps at 0', () {
      expect(Exhaustion(1).reduce(5).level, 0);
    });

    test('level 6 = dead', () {
      expect(Exhaustion.dead.isDead, isTrue);
    });
  });
}
