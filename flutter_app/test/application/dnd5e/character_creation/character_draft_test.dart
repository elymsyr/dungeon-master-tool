import 'package:dungeon_master_tool/application/dnd5e/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/dnd5e/character_creation/hp_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterDraft', () {
    test('empty has defaults', () {
      const d = CharacterDraft.empty;
      expect(d.startingLevel, 1);
      expect(d.classLevels, isEmpty);
      expect(d.hpMethod, HpMethod.fixed);
      expect(d.totalLevel, 0);
    });

    test('copyWith clears nullable via explicit null', () {
      const d = CharacterDraft(
        name: 'Aragorn',
        speciesId: 'srd:human',
      );
      final cleared = d.copyWith(name: null, speciesId: null);
      expect(cleared.name, isNull);
      expect(cleared.speciesId, isNull);
    });

    test('copyWith preserves fields when sentinel used', () {
      const d = CharacterDraft(name: 'Aragorn', speciesId: 'srd:human');
      final updated = d.copyWith(startingLevel: 5);
      expect(updated.name, 'Aragorn');
      expect(updated.speciesId, 'srd:human');
      expect(updated.startingLevel, 5);
    });

    test('totalLevel sums class levels', () {
      const d = CharacterDraft(classLevels: [
        DraftClassLevel(classId: 'srd:fighter', level: 3),
        DraftClassLevel(classId: 'srd:wizard', level: 2),
      ]);
      expect(d.totalLevel, 5);
    });
  });

  group('DraftClassLevel', () {
    test('equality by all fields', () {
      const a =
          DraftClassLevel(classId: 'srd:fighter', level: 3, subclassId: 'srd:champion');
      const b =
          DraftClassLevel(classId: 'srd:fighter', level: 3, subclassId: 'srd:champion');
      expect(a, b);
    });

    test('copyWith clears subclassId with explicit null', () {
      const a =
          DraftClassLevel(classId: 'srd:fighter', level: 3, subclassId: 'srd:champion');
      expect(a.copyWith(subclassId: null).subclassId, isNull);
    });
  });
}
