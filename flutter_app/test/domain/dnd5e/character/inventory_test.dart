import 'package:dungeon_master_tool/domain/dnd5e/character/inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryEntry', () {
    test('quantity > 0', () {
      expect(() => InventoryEntry(itemId: 'srd:rope', quantity: 0),
          throwsArgumentError);
    });

    test('validates itemId', () {
      expect(() => InventoryEntry(itemId: 'rope'), throwsArgumentError);
    });
  });

  group('Inventory', () {
    test('copper >= 0', () {
      expect(() => Inventory(copper: -1), throwsArgumentError);
    });

    test('rejects >3 attuned items', () {
      final entries = [
        for (var i = 0; i < 4; i++)
          InventoryEntry(itemId: 'srd:item_$i', attuned: true),
      ];
      expect(() => Inventory(entries: entries), throwsArgumentError);
    });

    test('accepts exactly 3 attuned', () {
      final entries = [
        for (var i = 0; i < 3; i++)
          InventoryEntry(itemId: 'srd:item_$i', attuned: true),
      ];
      final inv = Inventory(entries: entries);
      expect(inv.attunedCount, 3);
    });

    test('empty factory yields no entries', () {
      expect(Inventory.empty().entries, isEmpty);
      expect(Inventory.empty().copper, 0);
    });
  });
}
