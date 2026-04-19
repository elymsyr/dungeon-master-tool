import 'package:dungeon_master_tool/application/dnd5e/spell/spell_slot_progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpellSlotProgression', () {
    test('level 0 → all zeros', () {
      expect(SpellSlotProgression.slotsForCasterLevel(0),
          [0, 0, 0, 0, 0, 0, 0, 0, 0]);
    });

    test('level 1 full caster → 2 level-1 slots', () {
      expect(SpellSlotProgression.slotsForCasterLevel(1),
          [2, 0, 0, 0, 0, 0, 0, 0, 0]);
    });

    test('level 5 → [4,3,2,0...]', () {
      expect(SpellSlotProgression.slotsForCasterLevel(5),
          [4, 3, 2, 0, 0, 0, 0, 0, 0]);
    });

    test('level 20 → full endgame slot spread', () {
      expect(SpellSlotProgression.slotsForCasterLevel(20),
          [4, 3, 3, 3, 3, 2, 2, 1, 1]);
    });

    test('returned list is unmodifiable', () {
      final slots = SpellSlotProgression.slotsForCasterLevel(5);
      expect(() => slots[0] = 99, throwsUnsupportedError);
    });

    test('rejects out-of-range levels', () {
      expect(() => SpellSlotProgression.slotsForCasterLevel(-1),
          throwsArgumentError);
      expect(() => SpellSlotProgression.slotsForCasterLevel(21),
          throwsArgumentError);
    });
  });
}
