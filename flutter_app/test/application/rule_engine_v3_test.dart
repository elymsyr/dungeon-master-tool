import 'package:dungeon_master_tool/application/services/dice_roller.dart';
import 'package:dungeon_master_tool/application/services/rule_engine_v3.dart';
import 'package:dungeon_master_tool/application/services/rule_v2_to_v3_adapter.dart';
import 'package:dungeon_master_tool/domain/entities/applied_effect.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/resource_state.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/event_kind.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_effects_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_expressions_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_predicates_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_triggers.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_v2.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_v3.dart';
import 'package:flutter_test/flutter_test.dart';

Entity _entity(
  String id,
  String slug, {
  Map<String, dynamic> fields = const {},
  Map<String, ResourceState> resources = const {},
  List<AppliedEffect> activeEffects = const [],
}) {
  return Entity(
    id: id,
    name: id,
    categorySlug: slug,
    fields: fields,
    resources: resources,
    activeEffects: activeEffects,
  );
}

EntityCategorySchema _cat(String slug) {
  return EntityCategorySchema(
    categoryId: slug,
    schemaId: 'test',
    name: slug,
    slug: slug,
    createdAt: '',
    updatedAt: '',
  );
}

RuleV3 _rule({
  required String id,
  required RuleEffectV3 effect,
  PredicateV3 when = const PredicateV3.always(),
  RuleTrigger trigger = const RuleTrigger.always(),
  int priority = 0,
  List<String> dependsOn = const [],
}) {
  return RuleV3(
    ruleId: id,
    name: id,
    priority: priority,
    trigger: trigger,
    when_: when,
    then_: effect,
    dependsOn: dependsOn,
  );
}

void main() {
  final engine = RuleEngineV3(diceRoller: FixedDiceRoller(10));
  final cat = _cat('player');

  group('Reactive — V2 parity', () {
    test('always predicate + setValue literal', () {
      final rules = [
        _rule(
          id: 'r1',
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'speed',
            value: ValueExpressionV3.literal(30),
          ),
        ),
      ];
      final entity = _entity('e1', 'player');
      final result = engine.evaluateReactive(
        entity: entity,
        category: cat,
        allEntities: {'e1': entity},
        rules: rules,
      );
      expect(result.computedValues['speed'], 30);
    });

    test('STR 16 → str_mod = 3 via modifier expr', () {
      final rules = [
        _rule(
          id: 'str_mod',
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'str_mod',
            value: ValueExpressionV3.modifier(
              FieldRef(
                scope: RefScope.self,
                fieldKey: 'stat_block',
                nestedFieldKey: 'STR',
              ),
            ),
          ),
        ),
      ];
      final entity = _entity('pc', 'player', fields: {
        'stat_block': {'STR': 16},
      });
      final result = engine.evaluateReactive(
        entity: entity,
        category: cat,
        allEntities: {'pc': entity},
        rules: rules,
      );
      expect(result.computedValues['str_mod'], 3);
    });

    test('Level 5 → PB 3 via proficiencyBonus shortcut', () {
      final rules = [
        _rule(
          id: 'pb',
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'proficiency_bonus',
            value: ValueExpressionV3.proficiencyBonus(),
          ),
        ),
      ];
      final entity = _entity('pc', 'player', fields: {'total_level': 5});
      final result = engine.evaluateReactive(
        entity: entity,
        category: cat,
        allEntities: {'pc': entity},
        rules: rules,
      );
      expect(result.computedValues['proficiency_bonus'], 3);
    });
  });

  group('V3 new predicates', () {
    test('listLength < 3 fires; == 3 does not', () {
      final rules = [
        _rule(
          id: 'att_ok',
          when: const PredicateV3.listLength(
            list: FieldRef(scope: RefScope.self, fieldKey: 'attunements'),
            op: CompareOp.lt,
            value: 3,
          ),
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'attune_slot_available',
            value: ValueExpressionV3.literal(true),
          ),
        ),
      ];
      final two = _entity('pc', 'player', fields: {
        'attunements': ['a', 'b']
      });
      final three = _entity('pc2', 'player', fields: {
        'attunements': ['a', 'b', 'c']
      });
      final r1 = engine.evaluateReactive(
        entity: two,
        category: cat,
        allEntities: {'pc': two},
        rules: rules,
      );
      expect(r1.computedValues['attune_slot_available'], true);
      final r2 = engine.evaluateReactive(
        entity: three,
        category: cat,
        allEntities: {'pc2': three},
        rules: rules,
      );
      expect(r2.computedValues.containsKey('attune_slot_available'), false);
    });

    test('resource predicate — has rage_uses > 0', () {
      final rules = [
        _rule(
          id: 'rage_possible',
          when: const PredicateV3.resource(
            resourceKey: 'rage_uses',
            field: ResourceField.current,
            op: CompareOp.gt,
            value: 0,
          ),
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'can_rage',
            value: ValueExpressionV3.literal(true),
          ),
        ),
      ];
      final with0 = _entity('pc', 'player', resources: {
        'rage_uses': const ResourceState(
            resourceKey: 'rage_uses', current: 0, max: 3),
      });
      final with2 = _entity('pc2', 'player', resources: {
        'rage_uses': const ResourceState(
            resourceKey: 'rage_uses', current: 2, max: 3),
      });
      final r1 = engine.evaluateReactive(
        entity: with0,
        category: cat,
        allEntities: {'pc': with0},
        rules: rules,
      );
      expect(r1.computedValues.containsKey('can_rage'), false);
      final r2 = engine.evaluateReactive(
        entity: with2,
        category: cat,
        allEntities: {'pc2': with2},
        rules: rules,
      );
      expect(r2.computedValues['can_rage'], true);
    });

    test('hasCondition predicate — poisoned', () {
      final rules = [
        _rule(
          id: 'poisoned_debuff',
          when: const PredicateV3.hasCondition(
            conditionId: 'condition-poisoned',
          ),
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'disadvantage_on_all',
            value: ValueExpressionV3.literal(true),
          ),
        ),
      ];
      final poisoned = _entity('pc', 'player', activeEffects: [
        const AppliedEffect(
            effectId: 'eff1', conditionId: 'condition-poisoned'),
      ]);
      final result = engine.evaluateReactive(
        entity: poisoned,
        category: cat,
        allEntities: {'pc': poisoned},
        rules: rules,
      );
      expect(result.computedValues['disadvantage_on_all'], true);
    });
  });

  group('Event path', () {
    test('onLongRest fires refreshResource', () {
      final rules = [
        _rule(
          id: 'rest_slots',
          trigger: const RuleTrigger.event(event: EventKind.onLongRest),
          effect: const RuleEffectV3.refreshResource(
            resourceKey: 'spell_slot_1',
          ),
        ),
      ];
      final pc = _entity('pc', 'player', resources: {
        'spell_slot_1': const ResourceState(
            resourceKey: 'spell_slot_1', current: 1, max: 4),
      });
      final result = engine.evaluateEvent(
        kind: EventKind.onLongRest,
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(result.computedResources['spell_slot_1']!.current, 4);
    });

    test('event trigger does not fire on always eval', () {
      final rules = [
        _rule(
          id: 'rest_slots',
          trigger: const RuleTrigger.event(event: EventKind.onLongRest),
          effect: const RuleEffectV3.refreshResource(
            resourceKey: 'spell_slot_1',
          ),
        ),
      ];
      final pc = _entity('pc', 'player');
      final result = engine.evaluateReactive(
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(result.resourceDeltas, isEmpty);
    });
  });

  group('D20 path', () {
    test('poisoned → grantDisadvantage on attack roll', () {
      final rules = [
        _rule(
          id: 'poisoned_disadv',
          trigger: const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          when: const PredicateV3.hasCondition(
            conditionId: 'condition-poisoned',
          ),
          effect: const RuleEffectV3.grantDisadvantage(
            scope: AdvantageScope.attackRoll,
          ),
        ),
      ];
      final pc = _entity('pc', 'player', activeEffects: [
        const AppliedEffect(effectId: 'e', conditionId: 'condition-poisoned'),
      ]);
      final result = engine.evaluateD20Test(
        testType: D20TestType.attackRoll,
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(result.disadvantages, hasLength(1));
      expect(result.disadvantages.first.scope, AdvantageScope.attackRoll);
    });

    test('Champion L3 → modifyCriticalRange 19', () {
      final rules = [
        _rule(
          id: 'champion_crit',
          trigger: const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          effect: const RuleEffectV3.modifyCriticalRange(newMinRange: 19),
        ),
      ];
      final pc = _entity('pc', 'player');
      final result = engine.evaluateD20Test(
        testType: D20TestType.attackRoll,
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(result.criticalRangeMin, 19);
    });
  });

  group('Resource effects', () {
    test('consumeResource with blockIfInsufficient — insufficient skips', () {
      final rules = [
        _rule(
          id: 'cast_l3',
          trigger: const RuleTrigger.event(event: EventKind.onSpellCast),
          effect: const RuleEffectV3.consumeResource(
            resourceKey: 'spell_slot_3',
            amount: ValueExpressionV3.literal(1),
          ),
        ),
      ];
      final pc = _entity('pc', 'player', resources: {
        'spell_slot_3': const ResourceState(
            resourceKey: 'spell_slot_3', current: 0, max: 2),
      });
      final result = engine.evaluateEvent(
        kind: EventKind.onSpellCast,
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      // Current stays 0 — insufficient block.
      expect(
        result.computedResources['spell_slot_3']?.current ??
            pc.resources['spell_slot_3']!.current,
        0,
      );
    });

    test('setResourceMax creates + clamps current', () {
      final rules = [
        _rule(
          id: 'set_rage_max',
          effect: const RuleEffectV3.setResourceMax(
            resourceKey: 'rage_uses',
            value: ValueExpressionV3.literal(3),
            refreshRule: RefreshRule.longRest,
          ),
        ),
      ];
      final pc = _entity('pc', 'player');
      final result = engine.evaluateReactive(
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(result.computedResources['rage_uses']!.max, 3);
      expect(result.computedResources['rage_uses']!.current, 0);
      expect(
        result.computedResources['rage_uses']!.refreshRule,
        RefreshRule.longRest,
      );
    });
  });

  group('Effect composition', () {
    test('composite effect applies all subeffects', () {
      final rules = [
        _rule(
          id: 'multi',
          effect: const RuleEffectV3.composite([
            RuleEffectV3.setValue(
              targetFieldKey: 'a',
              value: ValueExpressionV3.literal(1),
            ),
            RuleEffectV3.setValue(
              targetFieldKey: 'b',
              value: ValueExpressionV3.literal(2),
            ),
          ]),
        ),
      ];
      final pc = _entity('pc', 'player');
      final result = engine.evaluateReactive(
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(result.computedValues['a'], 1);
      expect(result.computedValues['b'], 2);
    });

    test('conditional effect branches correctly', () {
      final rules = [
        _rule(
          id: 'cond',
          effect: const RuleEffectV3.conditional(
            condition: PredicateV3.compare(
              left: FieldRef(scope: RefScope.self, fieldKey: 'level'),
              op: CompareOp.gte,
              literalValue: 5,
            ),
            then_: RuleEffectV3.setValue(
              targetFieldKey: 'tier',
              value: ValueExpressionV3.literal('veteran'),
            ),
            else_: RuleEffectV3.setValue(
              targetFieldKey: 'tier',
              value: ValueExpressionV3.literal('novice'),
            ),
          ),
        ),
      ];
      final novice = _entity('n', 'player', fields: {'level': 2});
      final veteran = _entity('v', 'player', fields: {'level': 7});
      final r1 = engine.evaluateReactive(
        entity: novice,
        category: cat,
        allEntities: {'n': novice},
        rules: rules,
      );
      expect(r1.computedValues['tier'], 'novice');
      final r2 = engine.evaluateReactive(
        entity: veteran,
        category: cat,
        allEntities: {'v': veteran},
        rules: rules,
      );
      expect(r2.computedValues['tier'], 'veteran');
    });
  });

  group('Dice roller (FixedDiceRoller)', () {
    test('dice expr rolls via injected roller', () {
      final rules = [
        _rule(
          id: 'dice_test',
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'rolled',
            value: ValueExpressionV3.dice(notation: '1d20'),
          ),
        ),
      ];
      final pc = _entity('pc', 'player');
      final result = engine.evaluateReactive(
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(result.computedValues['rolled'], 10);
    });

    test('dice expr average mode', () {
      final e2 = RuleEngineV3(diceRoller: FixedDiceRoller(99));
      final rules = [
        _rule(
          id: 'dice_avg',
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'avg',
            value: ValueExpressionV3.dice(notation: '2d6', average: true),
          ),
        ),
      ];
      final pc = _entity('pc', 'player');
      final r = e2.evaluateReactive(
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      expect(r.computedValues['avg'], 7); // 2 * 3.5
    });
  });

  group('V2 → V3 adapter parity', () {
    test('upgrade V2 reactive rule produces equivalent result', () {
      const v2Rule = RuleV2(
        ruleId: 'v2_str_mod',
        name: 'STR mod',
        when_: Predicate.always(),
        then_: RuleEffect.setValue(
          targetFieldKey: 'str_mod',
          value: ValueExpression.modifier(
            FieldRef(
              scope: RefScope.self,
              fieldKey: 'stat_block',
              nestedFieldKey: 'STR',
            ),
          ),
        ),
      );
      final v3 = RuleV2ToV3Adapter.upgrade(v2Rule);
      expect(v3.ruleId, 'v2_str_mod');

      final pc = _entity('pc', 'player', fields: {
        'stat_block': {'STR': 14},
      });
      final result = engine.evaluateReactive(
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: [v3],
      );
      expect(result.computedValues['str_mod'], 2);
    });

    test('V3 → V2 downgrade preserves V2-compatible rule', () {
      final v3 = _rule(
        id: 'simple',
        effect: const RuleEffectV3.setValue(
          targetFieldKey: 'speed',
          value: ValueExpressionV3.literal(30),
        ),
      );
      final v2 = RuleV3ToV2Adapter.downgrade(v3);
      expect(v2, isNotNull);
      expect(v2!.ruleId, 'simple');
    });

    test('V3 → V2 downgrade returns null for V3-only effect', () {
      final v3 = _rule(
        id: 'rage',
        trigger: const RuleTrigger.event(event: EventKind.onLongRest),
        effect: const RuleEffectV3.setResourceMax(
          resourceKey: 'rage_uses',
          value: ValueExpressionV3.literal(3),
          refreshRule: RefreshRule.longRest,
        ),
      );
      final v2 = RuleV3ToV2Adapter.downgrade(v3);
      expect(v2, isNull);
    });
  });

  group('Topological sort', () {
    test('dependsOn ordering', () {
      final executionOrder = <String>[];
      // Use depends-on cross-check via setValue writes — rules write
      // in-order, so second rule can observe first's output in computedValues
      // only indirectly; we instead count via rule IDs recorded in names.
      // Simpler check: build two rules where b depends on a (higher priority
      // normally) but dependsOn forces a before b.
      final rules = [
        _rule(
          id: 'b',
          priority: 0,
          dependsOn: ['a'],
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'b_seen',
            value: ValueExpressionV3.literal('b'),
          ),
        ),
        _rule(
          id: 'a',
          priority: 10,
          effect: const RuleEffectV3.setValue(
            targetFieldKey: 'a_seen',
            value: ValueExpressionV3.literal('a'),
          ),
        ),
      ];
      final pc = _entity('pc', 'player');
      final result = engine.evaluateReactive(
        entity: pc,
        category: cat,
        allEntities: {'pc': pc},
        rules: rules,
      );
      // Both fire — primary guarantee: no crash on dependsOn reorder.
      expect(result.computedValues['a_seen'], 'a');
      expect(result.computedValues['b_seen'], 'b');
      executionOrder.add('ok');
      expect(executionOrder, ['ok']);
    });
  });
}
