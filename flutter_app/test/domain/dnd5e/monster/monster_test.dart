import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/legendary_action.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster_action.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:flutter_test/flutter_test.dart';

AbilityScores _abs() => AbilityScores(
      str: AbilityScore(14),
      dex: AbilityScore(12),
      con: AbilityScore(12),
      int_: AbilityScore(8),
      wis: AbilityScore(10),
      cha: AbilityScore(8),
    );

StatBlock _stats() => StatBlock(
      sizeId: 'srd:medium',
      typeId: 'srd:humanoid',
      armorClass: 13,
      hitPoints: 11,
      abilities: _abs(),
      cr: ChallengeRating.parse('1/4'),
    );

void main() {
  group('StatBlock', () {
    test('rejects invalid ids', () {
      expect(
          () => StatBlock(
                sizeId: 'medium',
                typeId: 'srd:humanoid',
                armorClass: 10,
                hitPoints: 1,
                abilities: _abs(),
                cr: ChallengeRating.parse('0'),
              ),
          throwsArgumentError);
    });

    test('hitPoints >= 1 and armorClass >= 0', () {
      expect(
          () => StatBlock(
                sizeId: 'srd:medium',
                typeId: 'srd:humanoid',
                armorClass: -1,
                hitPoints: 1,
                abilities: _abs(),
                cr: ChallengeRating.parse('0'),
              ),
          throwsArgumentError);
      expect(
          () => StatBlock(
                sizeId: 'srd:medium',
                typeId: 'srd:humanoid',
                armorClass: 10,
                hitPoints: 0,
                abilities: _abs(),
                cr: ChallengeRating.parse('0'),
              ),
          throwsArgumentError);
    });
  });

  group('Monster', () {
    test('legendaryActions non-empty requires slots > 0', () {
      final leg = LegendaryAction(
        name: 'Bite',
        inner: AttackAction(
          name: 'Bite',
          attackBonus: 5,
          damage: DiceExpression.parse('1d8+2'),
          damageTypeId: 'srd:piercing',
        ),
      );
      expect(
          () => Monster(
                id: 'srd:dragon',
                name: 'Dragon',
                stats: _stats(),
                legendaryActions: [leg],
                legendaryActionSlots: 0,
              ),
          throwsArgumentError);
    });

    test('builds with actions', () {
      final m = Monster(
        id: 'srd:goblin',
        name: 'Goblin',
        stats: _stats(),
        actions: [
          AttackAction(
            name: 'Scimitar',
            attackBonus: 4,
            damage: DiceExpression.parse('1d6+2'),
            damageTypeId: 'srd:slashing',
          ),
        ],
      );
      expect(m.actions.length, 1);
      expect(m.id, 'srd:goblin');
    });
  });

  test('AttackAction range pair symmetry', () {
    expect(
        () => AttackAction(
              name: 'Bow',
              attackBonus: 3,
              damage: DiceExpression.parse('1d6'),
              damageTypeId: 'srd:piercing',
              rangeNormalFt: 80,
            ),
        throwsArgumentError);
  });
}
