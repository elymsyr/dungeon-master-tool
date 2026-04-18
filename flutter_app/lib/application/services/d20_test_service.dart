import 'dart:math' as math;

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/event_kind.dart';
import '../../domain/entities/schema/rule_v3.dart';
import '../../domain/entities/turn_state.dart';
import 'd20_test_result.dart';
import 'dice_roller.dart';
import 'rule_engine_v3.dart';
import 'rule_event_bus.dart';

/// D&D 5e d20 test pipeline — attack/save/check.
///
/// Flow:
/// 1. Engine evaluate d20 rules (adv/disadv/crit range)
/// 2. Net advantage/disadvantage resolution (iki varsa iptal)
/// 3. d20 roll (adv/disadv → 2 zar)
/// 4. Critical check (d20 >= criticalRangeMin, default 20)
/// 5. Total = d20 + modifier + proficiency + rule bonuses
/// 6. Success = DC ? total >= DC : null (crit → true for attack rolls)
/// 7. Emit events: onAttackMade + onCriticalHit/onAttackHit/onAttackMiss
class D20TestService {
  D20TestService({
    required RuleEngineV3 engine,
    required DiceRoller diceRoller,
    RuleEventBus? eventBus,
  })  : _engine = engine,
        _dice = diceRoller,
        _bus = eventBus;

  final RuleEngineV3 _engine;
  final DiceRoller _dice;
  final RuleEventBus? _bus;

  D20TestResult rollTest({
    required Entity entity,
    required EntityCategorySchema category,
    required List<RuleV3> rules,
    required Map<String, Entity> allEntities,
    required D20TestType testType,
    String? ability,
    String? skill,
    String? saveAgainst,
    int? dc,
    int baseModifier = 0,
    bool proficient = false,
    int? proficiencyBonusOverride,
    TurnState? turnState,
    String? targetEntityId,
  }) {
    // 1. Engine evaluate.
    final ruleResult = _engine.evaluateD20Test(
      testType: testType,
      entity: entity,
      category: category,
      allEntities: allEntities,
      rules: rules,
      ability: ability,
      skill: skill,
      saveAgainst: saveAgainst,
      turnState: turnState,
    );

    // 2. Advantage / disadvantage resolution (iki varsa iptal).
    final hasAdv = ruleResult.advantages.isNotEmpty;
    final hasDisadv = ruleResult.disadvantages.isNotEmpty;
    final netAdv = hasAdv && !hasDisadv;
    final netDisadv = hasDisadv && !hasAdv;

    // 3. Roll.
    final roll1 = _dice.roll('1d20');
    final roll2 = (netAdv || netDisadv) ? _dice.roll('1d20') : null;
    final d20 = roll2 == null
        ? roll1
        : netAdv
            ? math.max(roll1, roll2)
            : math.min(roll1, roll2);

    // 4. Critical range.
    final critMin = ruleResult.criticalRangeMin ?? 20;
    final isCrit = d20 >= critMin;
    final isNaturalOne = d20 == 1;

    // 5. Total.
    final pb = proficient ? (proficiencyBonusOverride ?? _inferPB(entity)) : 0;
    final ruleBonus = ruleResult.attackRollBonus;
    final total = d20 + baseModifier + pb + ruleBonus.toInt();

    final appliedBonuses = <AppliedBonus>[
      AppliedBonus(source: 'd20', amount: d20),
      if (baseModifier != 0)
        AppliedBonus(source: 'ability_mod', amount: baseModifier),
      if (pb != 0) AppliedBonus(source: 'proficiency_bonus', amount: pb),
      if (ruleBonus != 0)
        AppliedBonus(source: 'rules', amount: ruleBonus),
    ];

    // 6. Success.
    final bool? success;
    if (dc != null) {
      if (testType == D20TestType.attackRoll) {
        if (isCrit) {
          success = true;
        } else if (isNaturalOne) {
          success = false;
        } else {
          success = total >= dc;
        }
      } else {
        success = total >= dc;
      }
    } else {
      success = null;
    }

    // 7. Events.
    if (_bus != null) {
      if (testType == D20TestType.attackRoll) {
        _bus.fire(
          EventKind.onAttackMade,
          entity.id,
          targetEntityId: targetEntityId,
          payload: {
            'd20': d20,
            'total': total,
            'dc': ?dc,
            'ability': ?ability,
          },
        );
        if (isCrit) {
          _bus.fire(
            EventKind.onCriticalHit,
            entity.id,
            targetEntityId: targetEntityId,
            payload: {'d20': d20, 'total': total},
          );
        }
        if (success == true) {
          _bus.fire(
            EventKind.onAttackHit,
            entity.id,
            targetEntityId: targetEntityId,
            payload: {'d20': d20, 'total': total},
          );
        } else if (success == false) {
          _bus.fire(
            EventKind.onAttackMiss,
            entity.id,
            targetEntityId: targetEntityId,
            payload: {'d20': d20, 'total': total},
          );
        }
      }
    }

    return D20TestResult(
      testType: testType,
      d20Roll: d20,
      rawRolls: roll2 == null ? [roll1] : [roll1, roll2],
      total: total,
      advantage: netAdv,
      disadvantage: netDisadv,
      critical: isCrit,
      criticalMissRange: testType == D20TestType.attackRoll && isNaturalOne,
      totalBonus: total - d20,
      success: success,
      dc: dc,
      appliedBonuses: appliedBonuses,
    );
  }

  /// Default PB inference — entity.fields['proficiency_bonus'] varsa onu,
  /// yoksa total_level bazlı SRD kuralı.
  int _inferPB(Entity entity) {
    final raw = entity.fields['proficiency_bonus'];
    if (raw is num) return raw.toInt();

    final total = entity.fields['total_level'];
    int level;
    if (total is num) {
      level = total.toInt();
    } else {
      final classes = entity.fields['classes'];
      if (classes is List) {
        level = 0;
        for (final c in classes) {
          if (c is Map && c['level'] is num) {
            level += (c['level'] as num).toInt();
          }
        }
      } else {
        level = 1;
      }
    }
    return ((level - 1) ~/ 4) + 2;
  }
}
