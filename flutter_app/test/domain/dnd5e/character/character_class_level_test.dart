import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterClassLevel', () {
    test('rejects level 0 and >20', () {
      expect(() => CharacterClassLevel(classId: 'srd:wizard', level: 0),
          throwsArgumentError);
      expect(() => CharacterClassLevel(classId: 'srd:wizard', level: 21),
          throwsArgumentError);
    });

    test('rejects malformed classId', () {
      expect(() => CharacterClassLevel(classId: 'wizard', level: 1),
          throwsArgumentError);
    });

    test('rejects malformed subclassId', () {
      expect(
          () => CharacterClassLevel(
              classId: 'srd:wizard', subclassId: 'evocation', level: 5),
          throwsArgumentError);
    });

    test('equality by all fields', () {
      expect(
        CharacterClassLevel(classId: 'srd:wizard', level: 5),
        CharacterClassLevel(classId: 'srd:wizard', level: 5),
      );
      expect(
        CharacterClassLevel(classId: 'srd:wizard', level: 5) ==
            CharacterClassLevel(classId: 'srd:wizard', level: 6),
        isFalse,
      );
    });
  });
}
