import 'dart:math' as math;

import 'package:dungeon_master_tool/application/dnd5e/combat/attack_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/attack_roll.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/combatant_effect_source.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/advantage_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
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

MonsterCombatant _mc(String id, {Set<String> conditions = const {}}) =>
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
      id: id,
      instanceMaxHp: 7,
      initiativeRoll: 10,
      conditionIds: conditions,
      turnState: TurnState(speedFt: 30),
    );

AttackPipeline _pipeline({
  required ConditionEffectsLookup lookup,
  required List<int> rolls,
  InherentEffectsLookup inherent = _none,
}) {
  return AttackPipeline(
    effectSource: CombatantEffectSource(
      conditionEffects: lookup,
      inherentEffects: inherent,
    ),
    resolver: AttackResolver(D20Roller(_QueueRng(rolls))),
  );
}

List<EffectDescriptor> _none(Combatant _) => const [];

void main() {
  group('AttackPipeline.run', () {
    test('no effects: bare roll resolves through resolver', () {
      final p = _pipeline(lookup: (_) => const [], rolls: [9]); // d20 = 10
      final r = p.run(AttackPipelineInput(
        attacker: _mc('a'),
        target: _mc('t'),
        abilityMod: 3,
        proficiencyBonus: 2,
        targetArmorClass: 13,
      ));
      expect(r.roll.totalRoll, 10 + 3 + 2); // 15
      expect(r.roll.hit, isTrue);
      expect(r.attackerContribution.flatBonus, 0);
      expect(r.targetContribution.flatBonus, 0);
      expect(r.extraAttackDice, isEmpty);
    });

    test('attacker bless +d4 is folded into flatBonus via accumulator', () {
      // Bless authored as ModifyAttackRoll(flatBonus: 3) here for determinism
      // (real Bless rolls a d4 — accumulator surfaces extraDice; the pipeline
      // does not roll them). Keep the test focused on flatBonus path.
      final p = _pipeline(
        lookup: (id) => id == 'srd:blessed'
            ? const [ModifyAttackRoll(flatBonus: 3)]
            : const [],
        rolls: [9], // d20 = 10
      );
      final r = p.run(AttackPipelineInput(
        attacker: _mc('a', conditions: const {'srd:blessed'}),
        target: _mc('t'),
        abilityMod: 0,
        proficiencyBonus: 0,
        targetArmorClass: 12,
        weaponBonus: 1,
      ));
      expect(r.roll.totalRoll, 10 + 0 + 0 + 3 + 1);
      expect(r.attackerContribution.flatBonus, 3);
      expect(r.targetContribution.flatBonus, 0);
    });

    test('target ModifyAttackRoll(appliesTo: targeted) lands on flatBonus', () {
      // Target is "marked" — every attack against it gets +2.
      final p = _pipeline(
        lookup: (id) => id == 'srd:marked'
            ? const [
                ModifyAttackRoll(flatBonus: 2, appliesTo: EffectTarget.targeted),
              ]
            : const [],
        rolls: [4], // d20 = 5
      );
      final r = p.run(AttackPipelineInput(
        attacker: _mc('a'),
        target: _mc('t', conditions: const {'srd:marked'}),
        abilityMod: 0,
        proficiencyBonus: 0,
        targetArmorClass: 7,
      ));
      expect(r.roll.totalRoll, 5 + 2);
      expect(r.attackerContribution.flatBonus, 0);
      expect(r.targetContribution.flatBonus, 2);
      expect(r.roll.hit, isTrue);
    });

    test('attacker advantage + target disadvantage cancel → normal', () {
      // First two rolls should be ignored when normal — but advantage state
      // is produced before the d20 is rolled. The pipeline combines: atk adv
      // + tgt disadv → normal, so D20Roller takes one face only.
      final p = _pipeline(
        lookup: (id) {
          if (id == 'srd:adv') {
            return const [ModifyAttackRoll(advantage: AdvantageState.advantage)];
          }
          if (id == 'srd:dis') {
            return const [
              ModifyAttackRoll(
                advantage: AdvantageState.disadvantage,
                appliesTo: EffectTarget.targeted,
              ),
            ];
          }
          return const [];
        },
        rolls: [9], // single roll for normal
      );
      final r = p.run(AttackPipelineInput(
        attacker: _mc('a', conditions: const {'srd:adv'}),
        target: _mc('t', conditions: const {'srd:dis'}),
        abilityMod: 0,
        proficiencyBonus: 0,
        targetArmorClass: 1,
      ));
      expect(r.roll.advantage, AdvantageState.normal);
      expect(r.attackerContribution.advantage, AdvantageState.advantage);
      expect(r.targetContribution.advantage, AdvantageState.disadvantage);
    });

    test('extraAttackDice surfaces dice from both sides in order', () {
      final d1 = DiceExpression.single(1, Die.d4);
      final d2 = DiceExpression.single(2, Die.d6);
      final p = _pipeline(
        lookup: (id) {
          if (id == 'srd:atk-side') {
            return [ModifyAttackRoll(extraDice: d1)];
          }
          if (id == 'srd:tgt-side') {
            return [
              ModifyAttackRoll(
                extraDice: d2,
                appliesTo: EffectTarget.targeted,
              ),
            ];
          }
          return const [];
        },
        rolls: [9],
      );
      final r = p.run(AttackPipelineInput(
        attacker: _mc('a', conditions: const {'srd:atk-side'}),
        target: _mc('t', conditions: const {'srd:tgt-side'}),
        abilityMod: 0,
        proficiencyBonus: 0,
        targetArmorClass: 5,
      ));
      expect(r.extraAttackDice, [d1, d2]);
    });

    test('inherent effects fold in alongside conditions', () {
      final p = _pipeline(
        lookup: (_) => const [],
        inherent: (_) => const [ModifyAttackRoll(flatBonus: 5)],
        rolls: [4],
      );
      final r = p.run(AttackPipelineInput(
        attacker: _mc('a'),
        target: _mc('t'),
        abilityMod: 0,
        proficiencyBonus: 0,
        targetArmorClass: 5,
      ));
      expect(r.roll.totalRoll, 5 + 5);
      expect(r.attackerContribution.flatBonus, 5);
    });
  });
}
