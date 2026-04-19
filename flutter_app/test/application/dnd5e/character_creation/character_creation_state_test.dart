import 'package:dungeon_master_tool/application/dnd5e/character_creation/character_creation_state.dart';
import 'package:dungeon_master_tool/application/dnd5e/character_creation/character_creation_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterCreationState', () {
    test('initial starts at startMode with empty draft + no errors', () {
      const s = CharacterCreationState.initial;
      expect(s.currentStep, CharacterCreationStep.startMode);
      expect(s.completedSteps, isEmpty);
      expect(s.validationMessages, isEmpty);
      expect(s.canAdvance, true);
      expect(s.canGoBack, false);
    });

    test('canAdvance false when current step has a message', () {
      const s = CharacterCreationState.initial;
      final bad = s.copyWith(
        validationMessages: const {
          CharacterCreationStep.startMode: 'bad level',
        },
      );
      expect(bad.canAdvance, false);
    });

    test('canGoBack true once past first step', () {
      const s = CharacterCreationState.initial;
      final next = s.copyWith(currentStep: CharacterCreationStep.classChoice);
      expect(next.canGoBack, true);
    });

    test('canAdvance true when message slot present but null', () {
      const s = CharacterCreationState.initial;
      final clean = s.copyWith(
        validationMessages: const {CharacterCreationStep.startMode: null},
      );
      expect(clean.canAdvance, true);
    });
  });
}
