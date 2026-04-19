import 'package:dungeon_master_tool/application/dnd5e/character_creation/character_creation_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterCreationStep', () {
    test('ordered 0..6', () {
      expect(CharacterCreationStep.values.length, 7);
      expect(CharacterCreationStep.startMode.index, 0);
      expect(CharacterCreationStep.review.index, 6);
    });

    test('isFirst / isLast', () {
      expect(CharacterCreationStep.startMode.isFirst, true);
      expect(CharacterCreationStep.review.isLast, true);
      expect(CharacterCreationStep.origin.isFirst, false);
      expect(CharacterCreationStep.origin.isLast, false);
    });

    test('next / previous chain', () {
      expect(CharacterCreationStep.startMode.previous, isNull);
      expect(CharacterCreationStep.review.next, isNull);
      expect(
        CharacterCreationStep.startMode.next,
        CharacterCreationStep.classChoice,
      );
      expect(
        CharacterCreationStep.review.previous,
        CharacterCreationStep.details,
      );
    });
  });
}
