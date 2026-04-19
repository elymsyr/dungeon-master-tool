import 'package:dungeon_master_tool/domain/dnd5e/catalog/armor_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArmorCategory', () {
    test('null maxDexCap = no cap (Light)', () {
      final c = ArmorCategory(id: 'srd:light', name: 'Light');
      expect(c.maxDexCap, isNull);
    });

    test('0 maxDexCap = Dex does not contribute (Heavy)', () {
      final c = ArmorCategory(
          id: 'srd:heavy', name: 'Heavy', maxDexCap: 0, stealthDisadvantage: true);
      expect(c.maxDexCap, 0);
      expect(c.stealthDisadvantage, isTrue);
    });

    test('positive maxDexCap (Medium = 2)', () {
      final c = ArmorCategory(id: 'srd:medium', name: 'Medium', maxDexCap: 2);
      expect(c.maxDexCap, 2);
    });

    test('rejects negative maxDexCap', () {
      expect(
          () => ArmorCategory(id: 'srd:x', name: 'X', maxDexCap: -1),
          throwsArgumentError);
    });
  });
}
