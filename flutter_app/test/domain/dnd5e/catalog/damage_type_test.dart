import 'package:dungeon_master_tool/domain/dnd5e/catalog/damage_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DamageType', () {
    test('physical defaults false', () {
      final dt = DamageType(id: 'srd:fire', name: 'Fire');
      expect(dt.physical, isFalse);
    });

    test('physical true for bludgeoning', () {
      final dt = DamageType(
          id: 'srd:bludgeoning', name: 'Bludgeoning', physical: true);
      expect(dt.physical, isTrue);
    });

    test('rejects malformed id', () {
      expect(
          () => DamageType(id: 'fire', name: 'Fire'), throwsArgumentError);
    });

    test('equality by id', () {
      expect(DamageType(id: 'srd:fire', name: 'A'),
          DamageType(id: 'srd:fire', name: 'B'));
    });
  });
}
