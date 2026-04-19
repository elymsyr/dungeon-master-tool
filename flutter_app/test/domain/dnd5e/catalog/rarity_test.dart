import 'package:dungeon_master_tool/domain/dnd5e/catalog/rarity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rarity', () {
    test('constructs', () {
      final r = Rarity(
          id: 'srd:uncommon', name: 'Uncommon', sortOrder: 1);
      expect(r.sortOrder, 1);
      expect(r.attunementTierReq, isNull);
    });

    test('attunementTierReq validated', () {
      expect(
          () => Rarity(
              id: 'srd:x', name: 'X', sortOrder: 0, attunementTierReq: 0),
          throwsArgumentError);
      expect(
          () => Rarity(
              id: 'srd:x', name: 'X', sortOrder: 0, attunementTierReq: 21),
          throwsArgumentError);
    });

    test('accepts tier 1..20', () {
      final r = Rarity(
          id: 'srd:legendary',
          name: 'Legendary',
          sortOrder: 4,
          attunementTierReq: 11);
      expect(r.attunementTierReq, 11);
    });
  });
}
