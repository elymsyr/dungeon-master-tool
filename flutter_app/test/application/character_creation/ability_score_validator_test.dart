import 'package:dungeon_master_tool/application/character_creation/ability_score_method.dart';
import 'package:dungeon_master_tool/application/character_creation/ability_score_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AbilityScoreValidator.standardArray', () {
    test('accepts canonical 15/14/13/12/10/8 distribution', () {
      final scores = {
        'STR': 15,
        'DEX': 14,
        'CON': 13,
        'INT': 12,
        'WIS': 10,
        'CHA': 8,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.standardArray,
          scores: scores,
        ),
        isNull,
      );
    });

    test('rejects duplicate values', () {
      final scores = {
        'STR': 15,
        'DEX': 15, // duplicate
        'CON': 13,
        'INT': 12,
        'WIS': 10,
        'CHA': 8,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.standardArray,
          scores: scores,
        ),
        isNotNull,
      );
    });

    test('rejects non-array values', () {
      final scores = {
        'STR': 16,
        'DEX': 14,
        'CON': 13,
        'INT': 12,
        'WIS': 10,
        'CHA': 8,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.standardArray,
          scores: scores,
        ),
        isNotNull,
      );
    });

    test('reports missing ability', () {
      final scores = {
        'STR': 15,
        'DEX': 14,
        'CON': 13,
        'INT': 12,
        'WIS': 10,
        // CHA missing
      };
      final err = AbilityScoreValidator.validate(
        method: AbilityScoreMethod.standardArray,
        scores: scores,
      );
      expect(err, contains('CHA'));
    });
  });

  group('AbilityScoreValidator.pointBuy', () {
    test('27-point spread within budget', () {
      final scores = {
        'STR': 15, // 9
        'DEX': 14, // 7
        'CON': 13, // 5
        'INT': 10, // 2
        'WIS': 10, // 2
        'CHA': 10, // 2  total 27
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.pointBuy,
          scores: scores,
        ),
        isNull,
      );
      expect(AbilityScoreValidator.pointBuyCost(scores), 27);
    });

    test('rejects scores outside 8-15', () {
      final scores = {
        'STR': 16, // illegal
        'DEX': 14,
        'CON': 13,
        'INT': 10,
        'WIS': 10,
        'CHA': 8,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.pointBuy,
          scores: scores,
        ),
        contains('8-15'),
      );
    });

    test('rejects overspend', () {
      final scores = {
        'STR': 15, // 9
        'DEX': 15, // 9
        'CON': 15, // 9  total 27
        'INT': 14, // 7  total 34 — over budget
        'WIS': 8,
        'CHA': 8,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.pointBuy,
          scores: scores,
        ),
        contains('exceeds'),
      );
    });
  });

  group('AbilityScoreValidator.random', () {
    test('accepts 4d6-drop-low range (3-18)', () {
      final scores = {
        'STR': 18,
        'DEX': 15,
        'CON': 14,
        'INT': 12,
        'WIS': 10,
        'CHA': 3,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.random,
          scores: scores,
        ),
        isNull,
      );
    });

    test('rejects out-of-range (manual tampering)', () {
      final scores = {
        'STR': 19, // out
        'DEX': 14,
        'CON': 13,
        'INT': 12,
        'WIS': 10,
        'CHA': 8,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.random,
          scores: scores,
        ),
        isNotNull,
      );
    });
  });

  group('AbilityScoreValidator.manual', () {
    test('accepts 3-20 range', () {
      final scores = {
        'STR': 20,
        'DEX': 3,
        'CON': 10,
        'INT': 10,
        'WIS': 10,
        'CHA': 10,
      };
      expect(
        AbilityScoreValidator.validate(
          method: AbilityScoreMethod.manual,
          scores: scores,
        ),
        isNull,
      );
    });
  });

  group('abilityModifier', () {
    test('SRD floor((score-10)/2)', () {
      expect(abilityModifier(8), -1);
      expect(abilityModifier(10), 0);
      expect(abilityModifier(11), 0);
      expect(abilityModifier(15), 2);
      expect(abilityModifier(20), 5);
      expect(abilityModifier(1), -5);
    });
  });
}
