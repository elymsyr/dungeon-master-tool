import 'package:dungeon_master_tool/application/dnd5e/spell/pact_magic_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PactMagicTable', () {
    test('L1 → 1 slot at level 1', () {
      final e = PactMagicTable.forLevel(1);
      expect(e.slots, 1);
      expect(e.slotLevel, 1);
    });

    test('L5 → 2 slots at slot level 3', () {
      final e = PactMagicTable.forLevel(5);
      expect(e, const PactMagicEntry(slots: 2, slotLevel: 3));
    });

    test('L11 → 3 slots at level 5 (locked at 5 from L11+)', () {
      expect(PactMagicTable.forLevel(11).slotLevel, 5);
      expect(PactMagicTable.forLevel(11).slots, 3);
    });

    test('L17..20 → 4 slots at level 5', () {
      for (final lvl in [17, 18, 19, 20]) {
        final e = PactMagicTable.forLevel(lvl);
        expect(e.slots, 4, reason: 'level $lvl');
        expect(e.slotLevel, 5, reason: 'level $lvl');
      }
    });

    test('rejects out-of-range levels', () {
      expect(() => PactMagicTable.forLevel(0), throwsArgumentError);
      expect(() => PactMagicTable.forLevel(21), throwsArgumentError);
    });
  });
}
