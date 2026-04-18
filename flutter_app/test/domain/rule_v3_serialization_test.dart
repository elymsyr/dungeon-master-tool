import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/applied_effect.dart';
import 'package:dungeon_master_tool/domain/entities/choice_state.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/resource_state.dart';
import 'package:dungeon_master_tool/domain/entities/turn_state.dart';
import 'package:dungeon_master_tool/domain/entities/schema/event_kind.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_effects_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_expressions_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_predicates_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_triggers.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_v2.dart'
    show ArithOp, CompareOp, FieldRef, RefScope;
import 'package:dungeon_master_tool/domain/entities/schema/rule_v3.dart';

/// Faz 1 acceptance: her V3 tip için JSON round-trip.
void main() {
  group('PredicateV3 round-trip', () {
    final cases = <String, PredicateV3>{
      'always': const PredicateV3.always(),
      'compare': const PredicateV3.compare(
        left: FieldRef(scope: RefScope.self, fieldKey: 'str'),
        op: CompareOp.gte,
        literalValue: 13,
      ),
      'and': const PredicateV3.and([
        PredicateV3.always(),
        PredicateV3.always(),
      ]),
      'or': const PredicateV3.or([PredicateV3.always()]),
      'not': const PredicateV3.not(PredicateV3.always()),
      'listLength': const PredicateV3.listLength(
        list: FieldRef(scope: RefScope.self, fieldKey: 'attunements'),
        op: CompareOp.lt,
        value: 3,
      ),
      'resource': const PredicateV3.resource(
        resourceKey: 'rage_uses',
        field: ResourceField.current,
        op: CompareOp.gt,
        value: 0,
      ),
      'hasChoice': const PredicateV3.hasChoice(
        choiceKey: 'species_lineage',
        expectedValue: 'lineage-high-elf',
      ),
      'hasCondition': const PredicateV3.hasCondition(
        conditionId: 'condition-exhaustion',
        minLevel: 3,
      ),
      'hasFeature': const PredicateV3.hasFeature(featureId: 'feat-alert'),
      'inTurnPhase':
          const PredicateV3.inTurnPhase(phase: TurnPhase.beforeAttack),
      'actionAvailable': const PredicateV3.actionAvailable(
        action: ActionType.bonusAction,
      ),
      'level': const PredicateV3.level(
        op: CompareOp.gte,
        level: 5,
        classFilter: 'fighter',
      ),
      'context': const PredicateV3.context(
        contextKey: 'trigger.damage_type',
        expectedValue: 'fire',
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final restored = PredicateV3.fromJson(entry.value.toJson());
        expect(restored, entry.value);
      });
    }
  });

  group('ValueExpressionV3 round-trip', () {
    final cases = <String, ValueExpressionV3>{
      'literal': const ValueExpressionV3.literal(42),
      'fieldValue': const ValueExpressionV3.fieldValue(
        FieldRef(scope: RefScope.self, fieldKey: 'str'),
      ),
      'modifier': const ValueExpressionV3.modifier(
        FieldRef(scope: RefScope.self, fieldKey: 'str'),
      ),
      'arithmetic': const ValueExpressionV3.arithmetic(
        left: ValueExpressionV3.literal(10),
        op: ArithOp.add,
        right: ValueExpressionV3.literal(2),
      ),
      'ifThenElse': const ValueExpressionV3.ifThenElse(
        condition: PredicateV3.always(),
        then_: ValueExpressionV3.literal(1),
        else_: ValueExpressionV3.literal(0),
      ),
      'listLength': const ValueExpressionV3.listLength(
        FieldRef(scope: RefScope.self, fieldKey: 'attunements'),
      ),
      'min': const ValueExpressionV3.min([
        ValueExpressionV3.literal(1),
        ValueExpressionV3.literal(2),
      ]),
      'max': const ValueExpressionV3.max([
        ValueExpressionV3.literal(1),
        ValueExpressionV3.literal(2),
      ]),
      'clamp': const ValueExpressionV3.clamp(
        value: ValueExpressionV3.literal(5),
        minValue: ValueExpressionV3.literal(0),
        maxValue: ValueExpressionV3.literal(10),
      ),
      'dice': const ValueExpressionV3.dice(notation: '2d6+3', average: true),
      'stringFormat': const ValueExpressionV3.stringFormat(
        template: 'Need STR {0}',
        args: [ValueExpressionV3.literal(13)],
      ),
      'resourceValue': const ValueExpressionV3.resourceValue(
        resourceKey: 'spell_slot_1',
        field: ResourceField.current,
      ),
      'choice': const ValueExpressionV3.choice(choiceKey: 'species'),
      'contextValue': const ValueExpressionV3.contextValue('trigger.spell_level'),
      'levelInClass': const ValueExpressionV3.levelInClass('fighter'),
      'totalLevel': const ValueExpressionV3.totalLevel(),
      'proficiencyBonus': const ValueExpressionV3.proficiencyBonus(),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final restored = ValueExpressionV3.fromJson(entry.value.toJson());
        expect(restored, entry.value);
      });
    }
  });

  group('RuleEffectV3 round-trip', () {
    const someValue = ValueExpressionV3.literal(1);
    final cases = <String, RuleEffectV3>{
      'setValue': const RuleEffectV3.setValue(
        targetFieldKey: 'str_mod',
        value: someValue,
      ),
      'gateEquip': const RuleEffectV3.gateEquip(blockReason: 'need STR 15'),
      'setResourceMax': const RuleEffectV3.setResourceMax(
        resourceKey: 'rage_uses',
        value: someValue,
        refreshRule: RefreshRule.longRest,
      ),
      'consumeResource': const RuleEffectV3.consumeResource(
        resourceKey: 'spell_slot_3',
        amount: someValue,
      ),
      'refreshResource': const RuleEffectV3.refreshResource(
        resourceKey: 'hit_dice_d10',
        fraction: 0.5,
      ),
      'grantFeature':
          const RuleEffectV3.grantFeature(featureId: 'feat-extra-attack'),
      'revokeFeature':
          const RuleEffectV3.revokeFeature(featureId: 'feat-rage'),
      'applyCondition': const RuleEffectV3.applyCondition(
        conditionId: 'condition-poisoned',
      ),
      'removeCondition': const RuleEffectV3.removeCondition(
        conditionId: 'condition-poisoned',
      ),
      'grantAdvantage': const RuleEffectV3.grantAdvantage(
        scope: AdvantageScope.attackRoll,
        filter: 'strength',
      ),
      'grantDisadvantage': const RuleEffectV3.grantDisadvantage(
        scope: AdvantageScope.savingThrow,
      ),
      'modifyCriticalRange':
          const RuleEffectV3.modifyCriticalRange(newMinRange: 19),
      'modifyDamageRoll': const RuleEffectV3.modifyDamageRoll(
        op: DamageModOp.add,
        value: someValue,
      ),
      'modifyAttackRoll':
          const RuleEffectV3.modifyAttackRoll(bonus: someValue),
      'grantTempHp': const RuleEffectV3.grantTempHp(amount: someValue),
      'heal': const RuleEffectV3.heal(amount: someValue),
      'breakConcentration': const RuleEffectV3.breakConcentration(),
      'grantAction': const RuleEffectV3.grantAction(
        actionId: 'action-dash',
        actionType: ActionType.bonusAction,
      ),
      'presentChoice': const RuleEffectV3.presentChoice(
        choiceKey: 'fighting_style',
        options: [
          ChoiceOption(id: 'archery', label: 'Archery'),
          ChoiceOption(id: 'defense', label: 'Defense'),
        ],
      ),
      'composite': const RuleEffectV3.composite([
        RuleEffectV3.breakConcentration(),
        RuleEffectV3.removeCondition(conditionId: 'x'),
      ]),
      'conditional': const RuleEffectV3.conditional(
        condition: PredicateV3.always(),
        then_: RuleEffectV3.breakConcentration(),
      ),
      'applyEffect': const RuleEffectV3.applyEffect(
        effect: AppliedEffect(effectId: 'bless'),
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final restored = RuleEffectV3.fromJson(entry.value.toJson());
        expect(restored, entry.value);
      });
    }
  });

  group('RuleTrigger round-trip', () {
    final cases = <String, RuleTrigger>{
      'always': const RuleTrigger.always(),
      'event': const RuleTrigger.event(event: EventKind.onLongRest),
      'event-with-filter': const RuleTrigger.event(
        event: EventKind.onSpellCast,
        filter: PredicateV3.always(),
      ),
      'd20Test': const RuleTrigger.d20Test(
        testType: D20TestType.attackRoll,
        abilityFilter: 'STR',
      ),
      'damageApply': const RuleTrigger.damageApply(
        damageTypeFilter: 'fire',
      ),
      'turnPhase': const RuleTrigger.turnPhase(phase: TurnPhase.start),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final restored = RuleTrigger.fromJson(entry.value.toJson());
        expect(restored, entry.value);
      });
    }
  });

  group('DurationSpec round-trip', () {
    final cases = <String, DurationSpec>{
      'rounds': const DurationSpec.rounds(3),
      'minutes': const DurationSpec.minutes(10),
      'hours': const DurationSpec.hours(1),
      'concentration': const DurationSpec.concentration(),
      'permanent': const DurationSpec.permanent(),
      'untilLongRest': const DurationSpec.untilLongRest(),
      'untilShortRest': const DurationSpec.untilShortRest(),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final restored = DurationSpec.fromJson(entry.value.toJson());
        expect(restored, entry.value);
      });
    }
  });

  test('RuleV3 top-level round-trip', () {
    const rule = RuleV3(
      ruleId: 'rule_str_mod',
      name: 'STR modifier',
      description: 'Compute STR ability modifier',
      when_: PredicateV3.always(),
      then_: RuleEffectV3.setValue(
        targetFieldKey: 'str_mod',
        value: ValueExpressionV3.modifier(
          FieldRef(scope: RefScope.self, fieldKey: 'stat_block', nestedFieldKey: 'STR'),
        ),
      ),
    );
    expect(RuleV3.fromJson(rule.toJson()), rule);
  });

  test('ResourceState round-trip + derived fields', () {
    const r = ResourceState(
      resourceKey: 'rage_uses',
      current: 2,
      max: 3,
      refreshRule: RefreshRule.longRest,
    );
    expect(ResourceState.fromJson(r.toJson()), r);
    expect(r.expended, 1);
    expect(r.isFull, false);
    expect(r.isEmpty, false);
  });

  test('ChoiceState round-trip', () {
    const c = ChoiceState(
      choiceKey: 'species_lineage',
      chosenValue: 'lineage-high-elf',
      sourceRuleId: 'rule_species',
    );
    expect(ChoiceState.fromJson(c.toJson()), c);
  });

  test('TurnState + AdvantageSource round-trip', () {
    const t = TurnState(
      entityId: 'pc1',
      roundNumber: 3,
      initiativeOrder: 15,
      actionUsed: true,
      advantageSources: [
        AdvantageSource(sourceId: 'rage', reason: 'STR-based roll while raging'),
      ],
      criticalRangeMin: 19,
      attacksThisTurn: 1,
      firstAttackMade: true,
    );
    expect(TurnState.fromJson(t.toJson()), t);
  });

  test('AppliedEffect round-trip', () {
    const e = AppliedEffect(
      effectId: 'bless',
      sourceId: 'spell-bless',
      targetField: 'attack_roll',
      modifier: ValueExpressionV3.dice(notation: '1d4', average: true),
      duration: DurationSpec.rounds(10),
      remainingTurns: 10,
      requiresConcentration: true,
    );
    expect(AppliedEffect.fromJson(e.toJson()), e);
  });

  test('Entity V3 fields round-trip', () {
    const entity = Entity(
      id: 'pc-aragorn',
      categorySlug: 'player',
      name: 'Aragorn',
      fields: {'stat_block': {'STR': 16}},
      resources: {
        'rage_uses': ResourceState(
          resourceKey: 'rage_uses',
          current: 2,
          max: 3,
          refreshRule: RefreshRule.longRest,
        ),
      },
      choices: {
        'fighting_style':
            ChoiceState(choiceKey: 'fighting_style', chosenValue: 'defense'),
      },
      activeEffects: [
        AppliedEffect(effectId: 'bless'),
      ],
    );
    final restored = Entity.fromJson(entity.toJson());
    expect(restored, entity);
  });

  test('Entity V2 backward compat — missing V3 fields deserialize with defaults',
      () {
    final json = {
      'id': 'pc-legacy',
      'categorySlug': 'player',
      'name': 'Legacy',
    };
    final e = Entity.fromJson(json);
    expect(e.resources, isEmpty);
    expect(e.choices, isEmpty);
    expect(e.turnState, isNull);
    expect(e.activeEffects, isEmpty);
  });
}
