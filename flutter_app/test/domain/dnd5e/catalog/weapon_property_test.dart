import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_property.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_property_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeaponProperty', () {
    test('stores flags', () {
      final p = WeaponProperty(
        id: 'srd:finesse',
        name: 'Finesse',
        flags: {PropertyFlag.finesse},
      );
      expect(p.hasFlag(PropertyFlag.finesse), isTrue);
      expect(p.hasFlag(PropertyFlag.heavy), isFalse);
    });

    test('flags default empty', () {
      final p = WeaponProperty(id: 'srd:x', name: 'X');
      expect(p.flags, isEmpty);
    });

    test('flags immutable', () {
      final p = WeaponProperty(
          id: 'srd:x', name: 'X', flags: {PropertyFlag.light});
      expect(() => p.flags.add(PropertyFlag.heavy), throwsA(isA<Error>()));
    });

    test('equality by id', () {
      expect(
        WeaponProperty(id: 'srd:heavy', name: 'A'),
        WeaponProperty(id: 'srd:heavy', name: 'B'),
      );
    });
  });
}
