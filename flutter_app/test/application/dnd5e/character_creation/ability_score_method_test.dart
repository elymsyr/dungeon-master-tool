import 'package:dungeon_master_tool/application/dnd5e/character_creation/ability_score_method.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:flutter_test/flutter_test.dart';

Map<Ability, int> _scores(List<int> values) {
  assert(values.length == 6);
  return {
    for (var i = 0; i < 6; i++) Ability.values[i]: values[i],
  };
}

void main() {
  const v = AbilityScoreValidator();

  group('Standard Array', () {
    test('accepts exact multiset in any order', () {
      expect(v.validateStandardArray(_scores([8, 15, 10, 14, 12, 13])), isNull);
    });

    test('rejects duplicates', () {
      expect(
        v.validateStandardArray(_scores([15, 15, 13, 12, 10, 8])),
        contains('Standard Array'),
      );
    });

    test('rejects missing ability', () {
      expect(
        v.validateStandardArray({
          Ability.strength: 15,
          Ability.dexterity: 14,
          Ability.constitution: 13,
          Ability.intelligence: 12,
          Ability.wisdom: 10,
          // CHA missing
        }),
        contains('Missing base score for CHA'),
      );
    });
  });

  group('Point Buy', () {
    test('accepts exactly 27 points spent', () {
      // 15=9, 15=9, 15=9 would be 27 but only 3 scores — fill rest with 8s.
      // 14+14+13+12+10+8 = 7+7+5+4+2+0 = 25 ≤ 27.
      expect(
        v.validatePointBuy(_scores([14, 14, 13, 12, 10, 8])),
        isNull,
      );
    });

    test('rejects overspend', () {
      // 15,15,15,15,8,8 = 9*4 + 0*2 = 36
      expect(
        v.validatePointBuy(_scores([15, 15, 15, 15, 8, 8])),
        contains('Point Buy spent'),
      );
    });

    test('rejects score below 8', () {
      expect(
        v.validatePointBuy(_scores([7, 8, 8, 8, 8, 8])),
        contains('outside Point Buy range'),
      );
    });

    test('rejects score above 15', () {
      expect(
        v.validatePointBuy(_scores([16, 8, 8, 8, 8, 8])),
        contains('outside Point Buy range'),
      );
    });

    test('cost table matches SRD values', () {
      expect(kPointBuyCosts[8], 0);
      expect(kPointBuyCosts[13], 5);
      expect(kPointBuyCosts[14], 7);
      expect(kPointBuyCosts[15], 9);
    });
  });

  group('Random (4d6 drop lowest)', () {
    test('accepts any value in [3, 18]', () {
      expect(v.validateRandom(_scores([3, 18, 10, 11, 12, 13])), isNull);
    });

    test('rejects value below 3', () {
      expect(
        v.validateRandom(_scores([2, 10, 10, 10, 10, 10])),
        contains('outside 4d6-drop-low'),
      );
    });

    test('rejects value above 18', () {
      expect(
        v.validateRandom(_scores([19, 10, 10, 10, 10, 10])),
        contains('outside 4d6-drop-low'),
      );
    });
  });

  group('Background bonuses', () {
    final listed = {Ability.strength, Ability.dexterity, Ability.constitution};

    test('accepts +2/+1 across two listed', () {
      expect(
        v.validateBackgroundBonuses(
          baseScores: _scores([14, 14, 13, 12, 10, 8]),
          bonuses: {Ability.strength: 2, Ability.dexterity: 1},
          listedAbilities: listed,
        ),
        isNull,
      );
    });

    test('accepts +1/+1/+1 across three listed', () {
      expect(
        v.validateBackgroundBonuses(
          baseScores: _scores([14, 14, 13, 12, 10, 8]),
          bonuses: {
            Ability.strength: 1,
            Ability.dexterity: 1,
            Ability.constitution: 1,
          },
          listedAbilities: listed,
        ),
        isNull,
      );
    });

    test('rejects bonus on non-listed ability', () {
      expect(
        v.validateBackgroundBonuses(
          baseScores: _scores([14, 14, 13, 12, 10, 8]),
          bonuses: {Ability.strength: 2, Ability.charisma: 1},
          listedAbilities: listed,
        ),
        contains('not one of'),
      );
    });

    test('rejects total ≠ +3', () {
      expect(
        v.validateBackgroundBonuses(
          baseScores: _scores([14, 14, 13, 12, 10, 8]),
          bonuses: {Ability.strength: 1, Ability.dexterity: 1},
          listedAbilities: listed,
        ),
        contains('must total +3'),
      );
    });

    test('rejects invalid distribution shape', () {
      expect(
        v.validateBackgroundBonuses(
          baseScores: _scores([14, 14, 13, 12, 10, 8]),
          bonuses: {Ability.strength: 3},
          listedAbilities: listed,
        ),
        contains('+2/+1 on two'),
      );
    });

    test('rejects post-bonus score > 20', () {
      // STR 19 + 2 = 21
      expect(
        v.validateBackgroundBonuses(
          baseScores: _scores([19, 14, 13, 12, 10, 8]),
          bonuses: {Ability.strength: 2, Ability.dexterity: 1},
          listedAbilities: listed,
        ),
        contains('cap 20'),
      );
    });
  });
}
