import 'package:dungeon_master_tool/domain/dnd5e/character/hit_dice_pool.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HitDicePool', () {
    test('empty returns 0 for unknown die', () {
      final p = HitDicePool.empty();
      expect(p.remainingOf(Die.d8), 0);
      expect(p.maxOf(Die.d8), 0);
    });

    test('invariant: remaining in [0, max]', () {
      expect(
          () => HitDicePool({Die.d8: (remaining: 5, max: 4)}),
          throwsArgumentError);
      expect(() => HitDicePool({Die.d8: (remaining: -1, max: 4)}),
          throwsArgumentError);
    });

    test('spend decrements remaining', () {
      final p = HitDicePool({Die.d8: (remaining: 3, max: 3)});
      final after = p.spend(Die.d8);
      expect(after.remainingOf(Die.d8), 2);
      expect(after.maxOf(Die.d8), 3);
    });

    test('spend throws when empty', () {
      final p = HitDicePool({Die.d8: (remaining: 0, max: 3)});
      expect(() => p.spend(Die.d8), throwsStateError);
    });

    test('long rest recovers half total', () {
      final p = HitDicePool({
        Die.d8: (remaining: 0, max: 4),
        Die.d10: (remaining: 0, max: 4),
      });
      final after = p.recoverLongRest();
      final total = after.remainingOf(Die.d8) + after.remainingOf(Die.d10);
      expect(total, 4); // 8 total / 2
    });
  });
}
