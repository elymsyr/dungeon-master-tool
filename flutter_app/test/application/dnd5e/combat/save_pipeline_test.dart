import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/combatant_effect_source.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/stat_block.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueRng implements math.Random {
  final List<int> q;
  int i = 0;
  _QueueRng(this.q);
  @override
  int nextInt(int max) => q[i++];
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

AbilityScores _abs() => AbilityScores(
      str: AbilityScore(10),
      dex: AbilityScore(10),
      con: AbilityScore(10),
      int_: AbilityScore(10),
      wis: AbilityScore(10),
      cha: AbilityScore(10),
    );

MonsterCombatant _saver({Set<String> conditions = const {}}) =>
    MonsterCombatant(
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
      id: 's',
      instanceMaxHp: 7,
      initiativeRoll: 10,
      conditionIds: conditions,
      turnState: TurnState(speedFt: 30),
    );

SavePipeline _build(ConditionEffectsLookup lookup, List<int> rolls) {
  return SavePipeline(
    effectSource: CombatantEffectSource(conditionEffects: lookup),
    resolver: SaveResolver(D20Roller(_QueueRng(rolls))),
  );
}

void main() {
  group('SavePipeline.run', () {
    test('no effects: bare save resolves through resolver', () {
      final p = _build((_) => const [], [9]); // d20 = 10
      final r = p.run(SavePipelineInput(
        saver: _saver(),
        ability: Ability.dexterity,
        abilityMod: 2,
        proficiencyContribution: 2,
        dc: 14,
      ));
      expect(r.save.totalRoll, 10 + 2 + 2);
      expect(r.save.succeeded, isTrue);
      expect(r.contribution.flatBonus, 0);
    });

    test('matching ModifySave folds flatBonus into roll', () {
      final p = _build(
        (id) => id == 'srd:bless'
            ? [ModifySave(ability: Ability.dexterity, flatBonus: 3)]
            : const [],
        [4], // d20 = 5
      );
      final r = p.run(SavePipelineInput(
        saver: _saver(conditions: const {'srd:bless'}),
        ability: Ability.dexterity,
        abilityMod: 0,
        dc: 8,
      ));
      expect(r.save.totalRoll, 5 + 0 + 3);
      expect(r.save.succeeded, isTrue);
      expect(r.contribution.flatBonus, 3);
    });

    test('non-matching ability is filtered out', () {
      final p = _build(
        (id) => id == 'srd:bless'
            ? [ModifySave(ability: Ability.strength, flatBonus: 99)]
            : const [],
        [9],
      );
      final r = p.run(SavePipelineInput(
        saver: _saver(conditions: const {'srd:bless'}),
        ability: Ability.dexterity,
        abilityMod: 0,
        dc: 5,
      ));
      expect(r.contribution.flatBonus, 0);
      expect(r.save.totalRoll, 10);
    });

    test('autoSucceed surfaces (no d20 rolled)', () {
      final p = _build(
        (id) => id == 'srd:guided-divinely'
            ? [ModifySave(ability: Ability.wisdom, autoSucceed: true)]
            : const [],
        const [],
      );
      final r = p.run(SavePipelineInput(
        saver: _saver(conditions: const {'srd:guided-divinely'}),
        ability: Ability.wisdom,
        abilityMod: 0,
        dc: 30,
      ));
      expect(r.save.succeeded, isTrue);
      expect(r.save.resolution, SaveResolution.autoSucceed);
    });

    test('autoFail beats autoSucceed when both surface from different effects',
        () {
      final p = _build(
        (id) {
          if (id == 'srd:luck') {
            return [ModifySave(ability: Ability.charisma, autoSucceed: true)];
          }
          if (id == 'srd:doom') {
            return [ModifySave(ability: Ability.charisma, autoFail: true)];
          }
          return const [];
        },
        const [],
      );
      final r = p.run(SavePipelineInput(
        saver: _saver(conditions: const {'srd:luck', 'srd:doom'}),
        ability: Ability.charisma,
        abilityMod: 5,
        dc: 5,
      ));
      expect(r.save.succeeded, isFalse);
      expect(r.save.resolution, SaveResolution.autoFail);
    });

    test('descriptor advantage combines with baseAdvantage', () {
      // baseDisadvantage + descriptor advantage → normal (one d20).
      final p = _build(
        (id) => id == 'srd:emboldened'
            ? [
                ModifySave(
                  ability: Ability.constitution,
                  advantage: AdvantageState.advantage,
                ),
              ]
            : const [],
        [9], // single d20
      );
      final r = p.run(SavePipelineInput(
        saver: _saver(conditions: const {'srd:emboldened'}),
        ability: Ability.constitution,
        abilityMod: 0,
        dc: 5,
        baseAdvantage: AdvantageState.disadvantage,
      ));
      expect(r.save.advantage, AdvantageState.normal);
    });
  });
}
