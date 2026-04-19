import 'package:dungeon_master_tool/application/dnd5e/effect/effect_context.dart';
import 'package:dungeon_master_tool/application/dnd5e/effect/effect_context_builder.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/combatant.dart';
import 'package:dungeon_master_tool/domain/dnd5e/combat/turn_state.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_score.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/challenge_rating.dart';
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

MonsterCombatant _mc(String id, Set<String> conds) => MonsterCombatant(
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
      conditionIds: conds,
      turnState: TurnState(speedFt: 30),
    );

void main() {
  const builder = EffectContextBuilder();

  group('forAttack', () {
    test('flattens attacker + target conditions into separate slots', () {
      final atk = _mc('a', const {'srd:blessed'});
      final tgt = _mc('t', const {'srd:prone'});
      final ctx = builder.forAttack(
        attacker: atk,
        target: tgt,
        reach: AttackReach.melee,
        attackAbility: Ability.strength,
        weaponProperties: const {'srd:finesse'},
        damageTypeId: 'srd:slashing',
        isCritical: true,
        hasAdvantage: true,
        activeEffectIds: const {'srd:bless#a'},
      );
      expect(ctx.attackerConditions, {'srd:blessed'});
      expect(ctx.targetConditions, {'srd:prone'});
      expect(ctx.attackReach, AttackReach.melee);
      expect(ctx.attackAbility, Ability.strength);
      expect(ctx.weaponProperties, {'srd:finesse'});
      expect(ctx.damageTypeId, 'srd:slashing');
      expect(ctx.isCritical, isTrue);
      expect(ctx.hasAdvantage, isTrue);
      expect(ctx.activeEffectIds, {'srd:bless#a'});
    });

    test('defaults: optional fields blank, reach forwarded', () {
      final atk = _mc('a', const {});
      final tgt = _mc('t', const {});
      final ctx = builder.forAttack(
        attacker: atk,
        target: tgt,
        reach: AttackReach.ranged,
      );
      expect(ctx.attackerConditions, isEmpty);
      expect(ctx.targetConditions, isEmpty);
      expect(ctx.attackReach, AttackReach.ranged);
      expect(ctx.attackAbility, isNull);
      expect(ctx.weaponProperties, isEmpty);
      expect(ctx.damageTypeId, isNull);
      expect(ctx.isCritical, isFalse);
      expect(ctx.hasAdvantage, isFalse);
    });
  });

  group('forDamage', () {
    test('attackReach is none, damageType set, conditions both sides', () {
      final atk = _mc('a', const {'srd:hexblade'});
      final tgt = _mc('t', const {'srd:hexed'});
      final ctx = builder.forDamage(
        attacker: atk,
        target: tgt,
        damageTypeId: 'srd:fire',
        isCritical: true,
      );
      expect(ctx.attackReach, AttackReach.none);
      expect(ctx.damageTypeId, 'srd:fire');
      expect(ctx.attackerConditions, {'srd:hexblade'});
      expect(ctx.targetConditions, {'srd:hexed'});
      expect(ctx.isCritical, isTrue);
    });
  });

  group('forSelfSave', () {
    test('saver conditions go into attackerConditions slot', () {
      final s = _mc('s', const {'srd:poisoned'});
      final ctx = builder.forSelfSave(
        saver: s,
        activeEffectIds: const {'srd:bless#s'},
      );
      expect(ctx.attackerConditions, {'srd:poisoned'});
      expect(ctx.targetConditions, isEmpty);
      expect(ctx.attackReach, AttackReach.none);
      expect(ctx.activeEffectIds, {'srd:bless#s'});
    });
  });
}
