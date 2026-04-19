import 'package:dungeon_master_tool/domain/dnd5e/character/pact_magic_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PactMagicSlots', () {
    test('slotLevel in [1, 5]', () {
      expect(() => PactMagicSlots(slotLevel: 0, current: 0, max: 1),
          throwsArgumentError);
      expect(() => PactMagicSlots(slotLevel: 6, current: 0, max: 1),
          throwsArgumentError);
    });

    test('current in [0, max]', () {
      expect(() => PactMagicSlots(slotLevel: 3, current: 5, max: 3),
          throwsArgumentError);
    });

    test('spend then restore', () {
      final p = PactMagicSlots(slotLevel: 3, current: 2, max: 2);
      expect(p.spend().current, 1);
      expect(p.spend().spend().current, 0);
      expect(() => p.spend().spend().spend(), throwsStateError);
      expect(p.spend().spend().restore().current, 2);
    });
  });
}
