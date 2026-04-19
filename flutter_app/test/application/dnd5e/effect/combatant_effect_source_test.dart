import 'package:dungeon_master_tool/application/dnd5e/effect/combatant_effect_source.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:flutter_test/flutter_test.dart';

AbilityScores _abs() => AbilityScores(
      str: AbilityScore(10),
      dex: AbilityScore(10),
      con: AbilityScore(10),
      int_: AbilityScore(10),
      wis: AbilityScore(10),
      cha: AbilityScore(10),
    );

MonsterCombatant _mc({Set<String> conditions = const {}}) => MonsterCombatant(
      definition: Monster(
        id: 'srd:goblin',
        name: 'Goblin',
        stats: StatBlock(
          sizeId: 'srd:small',
          typeId: 'srd:humanoid',
          armorClass: 13,
          hitPoints: 7,
          abilities: _abs(),
          cr: ChallengeRating.parse('1/4'),
        ),
      ),
      id: 'g1',
      instanceMaxHp: 7,
      initiativeRoll: 10,
      conditionIds: conditions,
      turnState: TurnState(speedFt: 30),
    );

void main() {
  group('CombatantEffectSource.collect', () {
    test('empty combatant + empty lookup → empty', () {
      final src = CombatantEffectSource(conditionEffects: (_) => const []);
      expect(src.collect(_mc()), isEmpty);
    });

    test('inherent effects appear first', () {
      final inherent = const ModifyAttackRoll(flatBonus: 1);
      final fromCond = const ModifyAttackRoll(flatBonus: 2);
      final src = CombatantEffectSource(
        conditionEffects: (id) => id == 'srd:blessed' ? [fromCond] : const [],
        inherentEffects: (_) => [inherent],
      );
      final c = _mc(conditions: const {'srd:blessed'});
      expect(src.collect(c), [inherent, fromCond]);
    });

    test('multiple conditions concatenate in insertion order', () {
      final a = const ModifyAttackRoll(flatBonus: 1);
      final b = const ModifyAttackRoll(flatBonus: 2);
      final src = CombatantEffectSource(
        conditionEffects: (id) {
          if (id == 'srd:blessed') return [a];
          if (id == 'srd:guided') return [b];
          return const [];
        },
      );
      final c = _mc(conditions: const {'srd:blessed', 'srd:guided'});
      expect(src.collect(c), [a, b]);
    });

    test('unknown condition id contributes nothing', () {
      final src = CombatantEffectSource(conditionEffects: (_) => const []);
      final c = _mc(conditions: const {'srd:unknown'});
      expect(src.collect(c), isEmpty);
    });

    test('result is unmodifiable', () {
      final src = CombatantEffectSource(conditionEffects: (_) => const []);
      final out = src.collect(_mc());
      expect(() => out.add(const ModifyAttackRoll()), throwsUnsupportedError);
    });

    test('inherent-only combatant works without conditionEffects calls', () {
      var calls = 0;
      final src = CombatantEffectSource(
        conditionEffects: (_) {
          calls++;
          return const [];
        },
        inherentEffects: (_) => [
          ModifySave(ability: Ability.wisdom, flatBonus: 5),
        ],
      );
      final out = src.collect(_mc());
      expect(out, hasLength(1));
      expect(calls, 0);
    });
  });
}
