import 'package:dungeon_master_tool/application/dnd5e/combat/apply_damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_instance.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_pipeline.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/damage_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/d20_roller.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/save_resolver.dart';
import 'package:dungeon_master_tool/application/dnd5e/combat/target_defenses.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/combatant_effect_source.dart';
import 'package:dungeon_master_tool/application/dnd5e/spell/concentration_check_resolver.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/dice_expression.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
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

MonsterCombatant _mc(String id, {Set<String> conditions = const {}}) =>
    MonsterCombatant(
      definition: Monster(
        id: 'srd:goblin',
        name: 'Goblin',
        stats: StatBlock(
          sizeId: 'srd:small',
          typeId: 'srd:humanoid',
          armorClass: 13,
          hitPoints: 10,
          abilities: _abs(),
          cr: ChallengeRating.parse('1/4'),
        ),
      ),
      id: id,
      instanceMaxHp: 10,
      initiativeRoll: 10,
      conditionIds: conditions,
      turnState: TurnState(speedFt: 30),
    );

DamagePipeline _build(ConditionEffectsLookup lookup) {
  return DamagePipeline(
    effectSource: CombatantEffectSource(conditionEffects: lookup),
    applyPipeline: ApplyDamagePipeline(
      damageResolver: const DamageResolver(),
      concentrationResolver:
          ConcentrationCheckResolver(SaveResolver(D20Roller())),
    ),
  );
}

TargetDefenses _defenses({
  Set<String> resist = const {},
  int currentHp = 10,
}) =>
    TargetDefenses(
      currentHp: currentHp,
      maxHp: 10,
      resistances: resist,
    );

void main() {
  group('DamagePipeline.run', () {
    test('no effects: base damage flows through unchanged', () {
      final p = _build((_) => const []);
      final r = p.run(DamagePipelineInput(
        attacker: _mc('a'),
        target: _mc('t'),
        defenses: _defenses(),
        baseDamage:
            DamageInstance(amount: 4, typeId: 'srd:slashing'),
      ));
      expect(r.modifiedDamage.amount, 4);
      expect(r.modifiedDamage.typeId, 'srd:slashing');
      expect(r.outcome.damage.amountAfterMitigation, 4);
      expect(r.outcome.damage.newCurrentHp, 6);
      expect(r.contribution.flatBonus, 0);
    });

    test('attacker ModifyDamageRoll(+2) folds into pre-mitigation damage', () {
      final p = _build((id) => id == 'srd:rage'
          ? [ModifyDamageRoll(flatBonus: 2)]
          : const []);
      final r = p.run(DamagePipelineInput(
        attacker: _mc('a', conditions: const {'srd:rage'}),
        target: _mc('t'),
        defenses: _defenses(),
        baseDamage: DamageInstance(amount: 5, typeId: 'srd:slashing'),
      ));
      expect(r.modifiedDamage.amount, 7);
      expect(r.outcome.damage.amountAfterMitigation, 7);
      expect(r.outcome.damage.newCurrentHp, 3);
      expect(r.contribution.flatBonus, 2);
    });

    test('damageTypeOverride routes through resistance check on new type', () {
      // Target resists fire but not slashing. With override → resistance hits.
      final p = _build((id) => id == 'srd:flameblade'
          ? [ModifyDamageRoll(damageTypeOverride: 'srd:fire')]
          : const []);
      final r = p.run(DamagePipelineInput(
        attacker: _mc('a', conditions: const {'srd:flameblade'}),
        target: _mc('t'),
        defenses: _defenses(resist: const {'srd:fire'}),
        baseDamage: DamageInstance(amount: 8, typeId: 'srd:slashing'),
      ));
      expect(r.modifiedDamage.typeId, 'srd:fire');
      expect(r.outcome.damage.amountAfterMitigation, 4); // halved
      expect(r.outcome.damage.newCurrentHp, 6);
    });

    test('crit flag carried through to modifiedDamage', () {
      final p = _build((_) => const []);
      final r = p.run(DamagePipelineInput(
        attacker: _mc('a'),
        target: _mc('t'),
        defenses: _defenses(),
        baseDamage: DamageInstance(
          amount: 6,
          typeId: 'srd:slashing',
          isCritical: true,
        ),
      ));
      expect(r.modifiedDamage.isCritical, isTrue);
    });

    test('extra dice + extra typed dice surfaced but not rolled', () {
      final extra = DiceExpression.single(1, Die.d6);
      final p = _build((id) => id == 'srd:hex'
          ? [
              ModifyDamageRoll(
                extraTypedDice: [
                  TypedDice(dice: extra, damageTypeId: 'srd:necrotic'),
                ],
              ),
            ]
          : const []);
      final r = p.run(DamagePipelineInput(
        attacker: _mc('a', conditions: const {'srd:hex'}),
        target: _mc('t'),
        defenses: _defenses(),
        baseDamage: DamageInstance(amount: 3, typeId: 'srd:slashing'),
      ));
      expect(r.modifiedDamage.amount, 3); // unchanged: extra dice not rolled
      expect(r.contribution.extraTypedDice, hasLength(1));
      expect(r.contribution.extraTypedDice.first.damageTypeId, 'srd:necrotic');
      expect(r.contribution.extraTypedDice.first.dice, extra);
    });
  });
}
