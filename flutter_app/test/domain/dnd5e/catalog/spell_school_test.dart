import 'package:dungeon_master_tool/domain/dnd5e/catalog/spell_school.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpellSchool', () {
    test('accepts valid hex color', () {
      final s = SpellSchool(
          id: 'srd:evocation', name: 'Evocation', color: '#FF5533');
      expect(s.color, '#FF5533');
    });

    test('accepts null color', () {
      final s = SpellSchool(id: 'srd:abjuration', name: 'Abjuration');
      expect(s.color, isNull);
    });

    test('rejects malformed color', () {
      expect(
          () => SpellSchool(
              id: 'srd:x', name: 'X', color: 'red'),
          throwsArgumentError);
      expect(
          () => SpellSchool(
              id: 'srd:x', name: 'X', color: '#FFF'),
          throwsArgumentError);
    });
  });
}
