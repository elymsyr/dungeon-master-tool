import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeaponMastery', () {
    test('constructs', () {
      final m = WeaponMastery(
          id: 'srd:cleave', name: 'Cleave', description: 'Damage 2nd target.');
      expect(m.description, 'Damage 2nd target.');
    });

    test('description defaults to empty', () {
      final m = WeaponMastery(id: 'srd:graze', name: 'Graze');
      expect(m.description, '');
    });

    test('rejects empty name', () {
      expect(() => WeaponMastery(id: 'srd:x', name: ''), throwsArgumentError);
    });
  });
}
