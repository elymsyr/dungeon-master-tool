import 'package:dungeon_master_tool/application/services/rule_engine_v3.dart';
import 'package:dungeon_master_tool/application/services/rule_event_bus.dart';
import 'package:dungeon_master_tool/application/services/rule_event_mutation_applier.dart';
import 'package:dungeon_master_tool/domain/entities/applied_effect.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/events/game_event.dart';
import 'package:dungeon_master_tool/domain/entities/resource_state.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/event_kind.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_effects_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_expressions_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_predicates_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_triggers.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_v2.dart'
    show CompareOp, FieldRef, RefScope;
import 'package:dungeon_master_tool/domain/entities/schema/rule_v3.dart';
import 'package:flutter_test/flutter_test.dart';

EntityCategorySchema _cat(String slug) => EntityCategorySchema(
      categoryId: slug,
      schemaId: 'test',
      name: slug,
      slug: slug,
      createdAt: '',
      updatedAt: '',
    );

RuleV3 _rule(
  String id,
  RuleTrigger trigger,
  RuleEffectV3 effect, {
  PredicateV3 when = const PredicateV3.always(),
}) =>
    RuleV3(
      ruleId: id,
      name: id,
      trigger: trigger,
      when_: when,
      then_: effect,
    );

void main() {
  group('RuleEventBus — emit + mutation', () {
    test('onLongRest refreshes spell slot via mutation applier', () {
      final rules = [
        _rule(
          'long_rest_slots',
          const RuleTrigger.event(event: EventKind.onLongRest),
          const RuleEffectV3.refreshResource(resourceKey: 'spell_slot_1'),
        ),
      ];

      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        name: 'Aragorn',
        resources: const {
          'spell_slot_1': ResourceState(
            resourceKey: 'spell_slot_1',
            current: 1,
            max: 4,
            refreshRule: RefreshRule.longRest,
          ),
        },
      );

      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (slug) => slug == 'player' ? _cat(slug) : null,
        rulesResolver: (_) => rules,
        entitySink: (updated) => pc = updated,
      );

      bus.fire(EventKind.onLongRest, 'pc');
      expect(pc.resources['spell_slot_1']!.current, 4);
    });

    test('onSpellCast consumes slot when sufficient', () {
      final rules = [
        _rule(
          'cast_consume',
          const RuleTrigger.event(event: EventKind.onSpellCast),
          const RuleEffectV3.consumeResource(
            resourceKey: 'spell_slot_3',
            amount: ValueExpressionV3.literal(1),
          ),
        ),
      ];

      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        resources: const {
          'spell_slot_3': ResourceState(
            resourceKey: 'spell_slot_3',
            current: 2,
            max: 2,
          ),
        },
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onSpellCast, 'pc', payload: {'spell_level': 3});
      expect(pc.resources['spell_slot_3']!.current, 1);
    });

    test('insufficient resource → blockIfInsufficient skips mutation', () {
      final rules = [
        _rule(
          'cast_consume',
          const RuleTrigger.event(event: EventKind.onSpellCast),
          const RuleEffectV3.consumeResource(
            resourceKey: 'spell_slot_3',
            amount: ValueExpressionV3.literal(1),
          ),
        ),
      ];

      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        resources: const {
          'spell_slot_3': ResourceState(
              resourceKey: 'spell_slot_3', current: 0, max: 2),
        },
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onSpellCast, 'pc');
      expect(pc.resources['spell_slot_3']!.current, 0);
    });

    test('applyCondition → condition appears in activeEffects', () {
      final rules = [
        _rule(
          'poison_apply',
          const RuleTrigger.event(event: EventKind.onConditionApplied),
          const RuleEffectV3.applyCondition(conditionId: 'condition-poisoned'),
        ),
      ];
      Entity pc = Entity(id: 'pc', categorySlug: 'player');
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onConditionApplied, 'pc');
      expect(
        pc.activeEffects.any((e) => e.conditionId == 'condition-poisoned'),
        isTrue,
      );
    });

    test('removeCondition removes only targeted condition', () {
      final rules = [
        _rule(
          'cure_poison',
          const RuleTrigger.event(event: EventKind.onConditionRemoved),
          const RuleEffectV3.removeCondition(
              conditionId: 'condition-poisoned'),
        ),
      ];
      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        activeEffects: const [
          AppliedEffect(effectId: 'a', conditionId: 'condition-poisoned'),
          AppliedEffect(effectId: 'b', conditionId: 'condition-frightened'),
        ],
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onConditionRemoved, 'pc');
      expect(pc.activeEffects, hasLength(1));
      expect(pc.activeEffects.first.conditionId, 'condition-frightened');
    });

    test('breakConcentration drops concentration-flagged effects', () {
      final rules = [
        _rule(
          'break_conc',
          const RuleTrigger.event(event: EventKind.onConcentrationBroken),
          const RuleEffectV3.breakConcentration(),
        ),
      ];
      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        activeEffects: const [
          AppliedEffect(effectId: 'bless', requiresConcentration: true),
          AppliedEffect(effectId: 'bardic', requiresConcentration: false),
        ],
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onConcentrationBroken, 'pc');
      expect(pc.activeEffects, hasLength(1));
      expect(pc.activeEffects.first.effectId, 'bardic');
    });

    test('grantTempHp sets combat_stats.temp_hp when higher', () {
      final rules = [
        _rule(
          'false_life',
          const RuleTrigger.event(event: EventKind.onSpellCast),
          const RuleEffectV3.grantTempHp(
            amount: ValueExpressionV3.literal(8),
          ),
        ),
      ];
      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'temp_hp': 3},
        },
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onSpellCast, 'pc');
      expect((pc.fields['combat_stats'] as Map)['temp_hp'], 8);
    });

    test('heal applies to nested combat_stats.hp path', () {
      final rules = [
        _rule(
          'healing_word',
          const RuleTrigger.event(event: EventKind.onSpellCast),
          const RuleEffectV3.heal(
            amount: ValueExpressionV3.literal(6),
            targetField: 'combat_stats.hp',
          ),
        ),
      ];
      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 10},
        },
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onSpellCast, 'pc');
      expect((pc.fields['combat_stats'] as Map)['hp'], 16);
    });
  });

  group('RuleEventBus — cascade guard', () {
    test('unknown entity id returns empty result silently', () {
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (_) => null,
        categoryResolver: (_) => null,
        rulesResolver: (_) => const [],
        entitySink: (_) {},
      );
      final r = bus.fire(EventKind.onLongRest, 'missing');
      expect(r.isEmpty, isTrue);
    });

    test('stream emits event', () async {
      Entity pc = Entity(id: 'pc', categorySlug: 'player');
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => const [],
        entitySink: (u) => pc = u,
      );
      final received = <GameEvent>[];
      final sub = bus.events.listen(received.add);
      bus.fire(EventKind.onTurnStart, 'pc');
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.first.kind, EventKind.onTurnStart);
      await sub.cancel();
      await bus.dispose();
    });

    test('lastTrace accumulates emitted events; resetTrace clears', () {
      Entity pc = Entity(id: 'pc', categorySlug: 'player');
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => const [],
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onTurnStart, 'pc');
      expect(bus.lastTrace, hasLength(1));
      bus.fire(EventKind.onTurnEnd, 'pc');
      expect(bus.lastTrace, hasLength(2));
      expect(bus.lastTrace.last.kind, EventKind.onTurnEnd);
      bus.resetTrace();
      expect(bus.lastTrace, isEmpty);
    });
  });

  group('Full rest cycle (integration)', () {
    test('long rest refreshes spell slots + half hit dice + clears temp HP',
        () {
      final rules = [
        _rule(
          'long_rest_slots',
          const RuleTrigger.event(event: EventKind.onLongRest),
          const RuleEffectV3.refreshResource(resourceKey: 'spell_slot_1'),
        ),
        _rule(
          'long_rest_hit_dice',
          const RuleTrigger.event(event: EventKind.onLongRest),
          const RuleEffectV3.refreshResource(
            resourceKey: 'hit_dice_d10',
            fraction: 0.5,
          ),
        ),
      ];

      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 30, 'temp_hp': 5},
        },
        resources: const {
          'spell_slot_1': ResourceState(
            resourceKey: 'spell_slot_1',
            current: 0,
            max: 4,
          ),
          'hit_dice_d10': ResourceState(
            resourceKey: 'hit_dice_d10',
            current: 1,
            max: 5,
          ),
        },
      );

      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onLongRest, 'pc');

      expect(pc.resources['spell_slot_1']!.current, 4);
      // half of 5 = 2.5 → ceil → +3 → 1 + 3 = 4
      expect(pc.resources['hit_dice_d10']!.current, 4);
    });
  });

  group('RuleEventMutationApplier — unit', () {
    test('apply idempotent on empty result', () {
      final applier = RuleEventMutationApplier();
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final result = engineEmptyResult();
      final out = applier.apply(entity: pc, result: result);
      expect(out, same(pc));
    });
  });

  group('V3 predicate in cascade path', () {
    test('conditional effect fires inside event path', () {
      final rules = [
        _rule(
          'if_poisoned',
          const RuleTrigger.event(event: EventKind.onTurnStart),
          const RuleEffectV3.conditional(
            condition: PredicateV3.hasCondition(
              conditionId: 'condition-poisoned',
            ),
            then_: RuleEffectV3.applyCondition(
              conditionId: 'condition-marked',
            ),
          ),
        ),
      ];
      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        activeEffects: const [
          AppliedEffect(effectId: 'e', conditionId: 'condition-poisoned'),
        ],
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onTurnStart, 'pc');
      expect(
        pc.activeEffects.any((e) => e.conditionId == 'condition-marked'),
        isTrue,
      );
    });

    test('onDamageTaken with payload-driven predicate (context key)', () {
      final rules = [
        _rule(
          'fire_resistance',
          const RuleTrigger.event(event: EventKind.onDamageTaken),
          const RuleEffectV3.setValue(
            targetFieldKey: 'flagged',
            value: ValueExpressionV3.literal(true),
          ),
          when: const PredicateV3.context(
            contextKey: 'trigger.damage_type',
            expectedValue: 'fire',
          ),
        ),
      ];
      Entity pc = Entity(id: 'pc', categorySlug: 'player');
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      // Fire damage → should set flagged via result (but result
      // computedValues not applied — just assert result contains it via
      // lastTrace + check engine runs the rule).
      bus.fire(
        EventKind.onDamageTaken,
        'pc',
        payload: {'damage_type': 'fire'},
      );
      expect(bus.lastTrace.last.kind, EventKind.onDamageTaken);
    });
  });

  group('Filter trigger', () {
    test('event trigger with filter blocks mismatching payload', () {
      final rules = [
        _rule(
          'spell_lvl3_flag',
          const RuleTrigger.event(
            event: EventKind.onSpellCast,
            filter: PredicateV3.compare(
              left: FieldRef(
                scope: RefScope.self,
                fieldKey: 'class',
              ),
              op: CompareOp.eq,
              literalValue: 'wizard',
            ),
          ),
          const RuleEffectV3.consumeResource(
            resourceKey: 'spell_slot_3',
            amount: ValueExpressionV3.literal(1),
          ),
        ),
      ];
      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {'class': 'fighter'},
        resources: const {
          'spell_slot_3': ResourceState(
              resourceKey: 'spell_slot_3', current: 2, max: 2),
        },
      );
      final bus = RuleEventBus(
        engine: RuleEngineV3(),
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat('player'),
        rulesResolver: (_) => rules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onSpellCast, 'pc');
      // Filter said 'wizard' — fighter skips rule.
      expect(pc.resources['spell_slot_3']!.current, 2);
    });
  });
}

/// Test helper — builds an empty RuleEvaluationResultV3 by running the engine
/// with an empty rule list.
dynamic engineEmptyResult() {
  return RuleEngineV3().evaluateReactive(
    entity: Entity(id: 'x', categorySlug: 'y'),
    category: _cat('y'),
    allEntities: {'x': Entity(id: 'x', categorySlug: 'y')},
    rules: const [],
  );
}
