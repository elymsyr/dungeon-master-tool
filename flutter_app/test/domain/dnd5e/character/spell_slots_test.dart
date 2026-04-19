import 'package:dungeon_master_tool/domain/dnd5e/character/spell_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpellSlots', () {
    test('rejects level 0 or >9', () {
      expect(() => SpellSlots({0: (current: 1, max: 1)}),
          throwsArgumentError);
      expect(() => SpellSlots({10: (current: 1, max: 1)}),
          throwsArgumentError);
    });

    test('current in [0, max]', () {
      expect(() => SpellSlots({3: (current: 5, max: 4)}),
          throwsArgumentError);
    });

    test('spend throws when empty', () {
      final s = SpellSlots({1: (current: 0, max: 2)});
      expect(() => s.spend(1), throwsStateError);
    });

    test('spend decrements', () {
      final s = SpellSlots({2: (current: 2, max: 3)});
      final after = s.spend(2);
      expect(after.currentOf(2), 1);
      expect(after.maxOf(2), 3);
    });

    test('restoreAll sets current = max per level', () {
      final s = SpellSlots({
        1: (current: 0, max: 4),
        3: (current: 1, max: 2),
      });
      final r = s.restoreAll();
      expect(r.currentOf(1), 4);
      expect(r.currentOf(3), 2);
    });

    test('hasAvailable reflects current', () {
      final s = SpellSlots({4: (current: 1, max: 1)});
      expect(s.hasAvailable(4), isTrue);
      expect(s.hasAvailable(5), isFalse);
    });
  });
}
