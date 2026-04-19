import 'package:dungeon_master_tool/application/dnd5e/character_creation/ability_score_method.dart';
import 'package:dungeon_master_tool/application/dnd5e/character_creation/character_creation_step.dart';
import 'package:dungeon_master_tool/application/dnd5e/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/dnd5e/character_creation/step_validator.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:flutter_test/flutter_test.dart';

Map<Ability, int> _std() => const {
      Ability.strength: 15,
      Ability.dexterity: 14,
      Ability.constitution: 13,
      Ability.intelligence: 12,
      Ability.wisdom: 10,
      Ability.charisma: 8,
    };

void main() {
  const validator = CharacterDraftValidator();

  group('Step 0 — start mode', () {
    test('level 1 valid', () {
      expect(
        validator.validate(
          CharacterCreationStep.startMode,
          const CharacterDraft(startingLevel: 1),
          StepValidationContext.empty,
        ),
        isNull,
      );
    });

    test('level 0 invalid', () {
      expect(
        validator.validate(
          CharacterCreationStep.startMode,
          const CharacterDraft(startingLevel: 0),
          StepValidationContext.empty,
        ),
        contains('between 1 and 20'),
      );
    });

    test('level 21 invalid', () {
      expect(
        validator.validate(
          CharacterCreationStep.startMode,
          const CharacterDraft(startingLevel: 21),
          StepValidationContext.empty,
        ),
        contains('between 1 and 20'),
      );
    });
  });

  group('Step 1 — class choice', () {
    test('rejects empty class list', () {
      expect(
        validator.validate(
          CharacterCreationStep.classChoice,
          const CharacterDraft(),
          StepValidationContext.empty,
        ),
        contains('Pick at least one class'),
      );
    });

    test('rejects class levels not matching startingLevel', () {
      expect(
        validator.validate(
          CharacterCreationStep.classChoice,
          const CharacterDraft(
            startingLevel: 3,
            classLevels: [DraftClassLevel(classId: 'srd:fighter', level: 1)],
          ),
          StepValidationContext.empty,
        ),
        contains('total 1'),
      );
    });

    test('requires subclass at/above choice level', () {
      final msg = validator.validate(
        CharacterCreationStep.classChoice,
        const CharacterDraft(
          startingLevel: 3,
          classLevels: [DraftClassLevel(classId: 'srd:fighter', level: 3)],
        ),
        const StepValidationContext(subclassChoiceLevel: 3),
      );
      expect(msg, contains('Subclass'));
    });

    test('accepts when subclass present at choice level', () {
      final msg = validator.validate(
        CharacterCreationStep.classChoice,
        const CharacterDraft(
          startingLevel: 3,
          classLevels: [
            DraftClassLevel(
              classId: 'srd:fighter',
              level: 3,
              subclassId: 'srd:champion',
            ),
          ],
        ),
        const StepValidationContext(subclassChoiceLevel: 3),
      );
      expect(msg, isNull);
    });

    test('skill count mismatch rejected', () {
      expect(
        validator.validate(
          CharacterCreationStep.classChoice,
          const CharacterDraft(
            startingLevel: 1,
            classLevels: [DraftClassLevel(classId: 'srd:fighter', level: 1)],
            chosenSkillIds: ['srd:athletics'],
          ),
          const StepValidationContext(requiredClassSkillCount: 2),
        ),
        contains('exactly 2'),
      );
    });
  });

  group('Step 2 — origin', () {
    test('species required', () {
      expect(
        validator.validate(
          CharacterCreationStep.origin,
          const CharacterDraft(),
          StepValidationContext.empty,
        ),
        contains('Pick a species'),
      );
    });

    test('lineage required when species demands', () {
      expect(
        validator.validate(
          CharacterCreationStep.origin,
          const CharacterDraft(
            speciesId: 'srd:elf',
            backgroundId: 'srd:acolyte',
          ),
          const StepValidationContext(speciesRequiresLineage: true),
        ),
        contains('lineage'),
      );
    });

    test('language count checked', () {
      expect(
        validator.validate(
          CharacterCreationStep.origin,
          const CharacterDraft(
            speciesId: 'srd:human',
            backgroundId: 'srd:acolyte',
            chosenLanguageIds: ['srd:elvish'],
          ),
          const StepValidationContext(requiredLanguageCount: 2),
        ),
        contains('2 languages'),
      );
    });

    test('tool count checked', () {
      expect(
        validator.validate(
          CharacterCreationStep.origin,
          const CharacterDraft(
            speciesId: 'srd:human',
            backgroundId: 'srd:acolyte',
            chosenLanguageIds: ['srd:elvish', 'srd:dwarvish'],
          ),
          const StepValidationContext(
            requiredLanguageCount: 2,
            requiredToolCount: 1,
          ),
        ),
        contains('1 tools'),
      );
    });
  });

  group('Step 3 — abilities', () {
    test('method required', () {
      expect(
        validator.validate(
          CharacterCreationStep.abilities,
          const CharacterDraft(),
          StepValidationContext.empty,
        ),
        contains('ability score method'),
      );
    });

    test('point buy with overspend fails', () {
      expect(
        validator.validate(
          CharacterCreationStep.abilities,
          CharacterDraft(
            scoreMethod: AbilityScoreGenerationMethod.pointBuy,
            baseScores: {
              Ability.strength: 15,
              Ability.dexterity: 15,
              Ability.constitution: 15,
              Ability.intelligence: 15,
              Ability.wisdom: 8,
              Ability.charisma: 8,
            },
          ),
          StepValidationContext.empty,
        ),
        contains('Point Buy spent'),
      );
    });

    test('standard array passes when method matches', () {
      expect(
        validator.validate(
          CharacterCreationStep.abilities,
          CharacterDraft(
            scoreMethod: AbilityScoreGenerationMethod.standardArray,
            baseScores: _std(),
          ),
          StepValidationContext.empty,
        ),
        isNull,
      );
    });
  });

  group('Step 4 — alignment', () {
    test('required', () {
      expect(
        validator.validate(
          CharacterCreationStep.alignment,
          const CharacterDraft(),
          StepValidationContext.empty,
        ),
        contains('Pick an alignment'),
      );
    });

    test('set ok', () {
      expect(
        validator.validate(
          CharacterCreationStep.alignment,
          const CharacterDraft(alignmentId: 'srd:neutral_good'),
          StepValidationContext.empty,
        ),
        isNull,
      );
    });
  });

  group('Step 5 — details', () {
    test('name required', () {
      expect(
        validator.validate(
          CharacterCreationStep.details,
          const CharacterDraft(name: '   '),
          StepValidationContext.empty,
        ),
        contains('Name cannot be empty'),
      );
    });

    test('equipment choice required when count provided', () {
      expect(
        validator.validate(
          CharacterCreationStep.details,
          const CharacterDraft(name: 'Aragorn'),
          const StepValidationContext(equipmentOptionCount: 3),
        ),
        contains('1..3'),
      );
    });

    test('equipment choice out of range rejected', () {
      expect(
        validator.validate(
          CharacterCreationStep.details,
          const CharacterDraft(name: 'Aragorn', equipmentChoice: 5),
          const StepValidationContext(equipmentOptionCount: 3),
        ),
        contains('1..3'),
      );
    });

    test('valid name + equipment ok', () {
      expect(
        validator.validate(
          CharacterCreationStep.details,
          const CharacterDraft(name: 'Aragorn', equipmentChoice: 0),
          const StepValidationContext(equipmentOptionCount: 3),
        ),
        isNull,
      );
    });
  });

  group('Step 6 — review always valid', () {
    test('review passes regardless', () {
      expect(
        validator.validate(
          CharacterCreationStep.review,
          const CharacterDraft(),
          StepValidationContext.empty,
        ),
        isNull,
      );
    });
  });
}
