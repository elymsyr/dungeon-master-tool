import 'package:dungeon_master_tool/domain/dnd5e/catalog/language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Language', () {
    test('script optional', () {
      final l = Language(id: 'srd:druidic', name: 'Druidic');
      expect(l.script, isNull);
    });

    test('script stored when given', () {
      final l = Language(
          id: 'srd:dwarvish', name: 'Dwarvish', script: 'Dethek');
      expect(l.script, 'Dethek');
    });

    test('rejects empty script string', () {
      expect(
          () => Language(id: 'srd:x', name: 'X', script: ''),
          throwsArgumentError);
    });
  });
}
