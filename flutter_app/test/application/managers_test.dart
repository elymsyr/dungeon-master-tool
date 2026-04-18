import 'package:dungeon_master_tool/application/services/choice_manager.dart';
import 'package:dungeon_master_tool/application/services/resource_manager.dart';
import 'package:dungeon_master_tool/application/services/turn_manager.dart';
import 'package:dungeon_master_tool/domain/entities/applied_effect.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/resource_state.dart';
import 'package:dungeon_master_tool/domain/entities/schema/event_kind.dart';
import 'package:dungeon_master_tool/domain/entities/turn_state.dart';
import 'package:flutter_test/flutter_test.dart';

Entity _pc({
  Map<String, ResourceState> resources = const {},
  List<AppliedEffect> effects = const [],
  TurnState? turnState,
  Map<String, dynamic> fields = const {},
}) =>
    Entity(
      id: 'pc',
      categorySlug: 'player',
      name: 'Aragorn',
      resources: resources,
      activeEffects: effects,
      turnState: turnState,
      fields: fields,
    );

void main() {
  // ─── ResourceManager ──────────────────────────────────────────────────────
  group('ResourceManager.consume', () {
    const mgr = ResourceManager();

    test('decrements current by amount', () {
      final pc = _pc(resources: {
        'rage_uses': const ResourceState(
          resourceKey: 'rage_uses',
          current: 3,
          max: 3,
        ),
      });
      final after = mgr.consume(entity: pc, resourceKey: 'rage_uses', amount: 1);
      expect(after.resources['rage_uses']!.current, 2);
    });

    test('throws InsufficientResourceException when short', () {
      final pc = _pc(resources: {
        'spell_slot_3': const ResourceState(
          resourceKey: 'spell_slot_3',
          current: 0,
          max: 2,
        ),
      });
      expect(
        () => mgr.consume(
          entity: pc,
          resourceKey: 'spell_slot_3',
          amount: 1,
        ),
        throwsA(isA<InsufficientResourceException>()),
      );
    });

    test('throws ResourceNotInitializedException when missing', () {
      final pc = _pc();
      expect(
        () => mgr.consume(
          entity: pc,
          resourceKey: 'missing',
          amount: 1,
        ),
        throwsA(isA<ResourceNotInitializedException>()),
      );
    });

    test('tryConsume returns null when insufficient', () {
      final pc = _pc(resources: {
        'x': const ResourceState(resourceKey: 'x', current: 0, max: 1),
      });
      expect(mgr.tryConsume(entity: pc, resourceKey: 'x', amount: 1), isNull);
    });
  });

  group('ResourceManager.refresh', () {
    const mgr = ResourceManager();

    test('full refill when no amount/fraction', () {
      final pc = _pc(resources: {
        'spell_slot_1': const ResourceState(
          resourceKey: 'spell_slot_1',
          current: 1,
          max: 4,
        ),
      });
      final after = mgr.refresh(entity: pc, resourceKey: 'spell_slot_1');
      expect(after.resources['spell_slot_1']!.current, 4);
    });

    test('fraction adds ceil(max * fraction)', () {
      // max=5, fraction=0.5 → ceil(2.5) = 3 → 2 + 3 = 5 (clamped)
      final pc = _pc(resources: {
        'hit_dice_d10': const ResourceState(
          resourceKey: 'hit_dice_d10',
          current: 2,
          max: 5,
        ),
      });
      final after = mgr.refresh(
        entity: pc,
        resourceKey: 'hit_dice_d10',
        fraction: 0.5,
      );
      expect(after.resources['hit_dice_d10']!.current, 5);
    });

    test('fraction with low current → partial recover', () {
      // max=5, cur=0, fraction=0.5 → ceil(2.5) = 3 → 0 + 3 = 3
      final pc = _pc(resources: {
        'hit_dice_d10': const ResourceState(
          resourceKey: 'hit_dice_d10',
          current: 0,
          max: 5,
        ),
      });
      final after = mgr.refresh(
        entity: pc,
        resourceKey: 'hit_dice_d10',
        fraction: 0.5,
      );
      expect(after.resources['hit_dice_d10']!.current, 3);
    });

    test('explicit amount adds clamped to max', () {
      final pc = _pc(resources: {
        'x': const ResourceState(resourceKey: 'x', current: 0, max: 5),
      });
      final after = mgr.refresh(entity: pc, resourceKey: 'x', amount: 100);
      expect(after.resources['x']!.current, 5);
    });

    test('missing resource → entity unchanged', () {
      final pc = _pc();
      final after = mgr.refresh(entity: pc, resourceKey: 'missing');
      expect(after, pc);
    });
  });

  group('ResourceManager.setMax + refreshAllByRule', () {
    const mgr = ResourceManager();

    test('setMax creates new resource at full', () {
      final pc = _pc();
      final after = mgr.setMax(
        entity: pc,
        resourceKey: 'rage_uses',
        newMax: 3,
        refreshRule: RefreshRule.longRest,
      );
      expect(after.resources['rage_uses']!.max, 3);
      expect(after.resources['rage_uses']!.current, 3);
      expect(
        after.resources['rage_uses']!.refreshRule,
        RefreshRule.longRest,
      );
    });

    test('setMax clamps current when reducing max', () {
      final pc = _pc(resources: {
        'x': const ResourceState(resourceKey: 'x', current: 5, max: 5),
      });
      final after = mgr.setMax(entity: pc, resourceKey: 'x', newMax: 2);
      expect(after.resources['x']!.max, 2);
      expect(after.resources['x']!.current, 2);
    });

    test('refreshAllByRule — longRest full refills; hit dice half', () {
      final pc = _pc(resources: {
        'spell_slot_1': const ResourceState(
          resourceKey: 'spell_slot_1',
          current: 0,
          max: 4,
          refreshRule: RefreshRule.longRest,
        ),
        'hit_dice_d10': const ResourceState(
          resourceKey: 'hit_dice_d10',
          current: 0,
          max: 5,
          refreshRule: RefreshRule.longRest,
        ),
        'rage_uses': const ResourceState(
          resourceKey: 'rage_uses',
          current: 0,
          max: 3,
          refreshRule: RefreshRule.longRest,
        ),
        'short_only': const ResourceState(
          resourceKey: 'short_only',
          current: 0,
          max: 1,
          refreshRule: RefreshRule.shortRest,
        ),
      });
      final after = mgr.refreshAllByRule(
        entity: pc,
        rule: RefreshRule.longRest,
      );
      expect(after.resources['spell_slot_1']!.current, 4);
      // hit dice half of 5 → ceil(2.5)=3 → 0+3=3
      expect(after.resources['hit_dice_d10']!.current, 3);
      expect(after.resources['rage_uses']!.current, 3);
      // shortRest-only untouched
      expect(after.resources['short_only']!.current, 0);
    });
  });

  group('ResourceManager — concentration', () {
    const mgr = ResourceManager();

    test('startConcentration ensures resource + sets current=1', () {
      final pc = _pc();
      final after = mgr.startConcentration(entity: pc, effectId: 'bless');
      expect(after.resources['concentration']!.current, 1);
      expect(after.resources['concentration']!.max, 1);
    });

    test('startConcentration drops prior concentration effects', () {
      final pc = _pc(effects: [
        const AppliedEffect(effectId: 'bless', requiresConcentration: true),
        const AppliedEffect(effectId: 'bardic', requiresConcentration: false),
      ]);
      final after = mgr.startConcentration(entity: pc, effectId: 'haste');
      expect(after.activeEffects, hasLength(1));
      expect(after.activeEffects.first.effectId, 'bardic');
    });

    test('isConcentrating reflects active state', () {
      final none = _pc();
      expect(mgr.isConcentrating(none), isFalse);
      final yes = _pc(effects: const [
        AppliedEffect(effectId: 'b', requiresConcentration: true),
      ]);
      expect(mgr.isConcentrating(yes), isTrue);
    });

    test('breakConcentration drops concentration effects + resets resource',
        () {
      final pc = _pc(
        resources: {
          'concentration': const ResourceState(
            resourceKey: 'concentration',
            current: 1,
            max: 1,
          ),
        },
        effects: [
          const AppliedEffect(
            effectId: 'bless',
            requiresConcentration: true,
          ),
        ],
      );
      final after = mgr.breakConcentration(pc);
      expect(after.activeEffects, isEmpty);
      expect(after.resources['concentration']!.current, 0);
    });
  });

  // ─── ChoiceManager ────────────────────────────────────────────────────────
  group('ChoiceManager', () {
    const mgr = ChoiceManager();

    test('record + read + has + value', () {
      final pc = _pc();
      final after = mgr.record(
        entity: pc,
        choiceKey: 'fighting_style',
        value: 'archery',
        sourceRuleId: 'rule_x',
      );
      expect(mgr.has(entity: after, choiceKey: 'fighting_style'), isTrue);
      expect(mgr.value(entity: after, choiceKey: 'fighting_style'), 'archery');
      final state = mgr.read(entity: after, choiceKey: 'fighting_style');
      expect(state?.sourceRuleId, 'rule_x');
      expect(state?.chosenAt, isNotNull);
    });

    test('record overwrites existing choice', () {
      final pc = _pc();
      final a = mgr.record(entity: pc, choiceKey: 'k', value: 'v1');
      final b = mgr.record(entity: a, choiceKey: 'k', value: 'v2');
      expect(mgr.value(entity: b, choiceKey: 'k'), 'v2');
    });

    test('clear removes entry', () {
      final pc = _pc();
      final a = mgr.record(entity: pc, choiceKey: 'k', value: 'v');
      final b = mgr.clear(entity: a, choiceKey: 'k');
      expect(mgr.has(entity: b, choiceKey: 'k'), isFalse);
    });
  });

  // ─── TurnManager ──────────────────────────────────────────────────────────
  group('TurnManager', () {
    const mgr = TurnManager();

    test('startEncounter initializes fresh turnState', () {
      final pc = _pc();
      final after = mgr.startEncounter(entity: pc, initiativeOrder: 17);
      expect(after.turnState, isNotNull);
      expect(after.turnState!.roundNumber, 1);
      expect(after.turnState!.initiativeOrder, 17);
    });

    test('advanceRound increments round + resets action economy', () {
      final pc = _pc(
        turnState: const TurnState(
          entityId: 'pc',
          roundNumber: 2,
          actionUsed: true,
          bonusActionUsed: true,
          movementUsed: 20,
          attacksThisTurn: 1,
          firstAttackMade: true,
        ),
      );
      final after = mgr.advanceRound(pc);
      expect(after.turnState!.roundNumber, 3);
      expect(after.turnState!.actionUsed, isFalse);
      expect(after.turnState!.bonusActionUsed, isFalse);
      expect(after.turnState!.movementUsed, 0);
      expect(after.turnState!.attacksThisTurn, 0);
      expect(after.turnState!.firstAttackMade, isFalse);
    });

    test('markAction flips correct flag', () {
      final pc = _pc(
        turnState: const TurnState(entityId: 'pc'),
      );
      final afterAction = mgr.markAction(entity: pc, type: ActionType.action);
      expect(afterAction.turnState!.actionUsed, isTrue);

      final afterBonus = mgr.markAction(
        entity: pc,
        type: ActionType.bonusAction,
      );
      expect(afterBonus.turnState!.bonusActionUsed, isTrue);

      final afterReaction = mgr.markAction(
        entity: pc,
        type: ActionType.reaction,
      );
      expect(afterReaction.turnState!.reactionUsed, isTrue);
    });

    test('registerAttack increments counter + sets firstAttackMade', () {
      final pc = _pc(turnState: const TurnState(entityId: 'pc'));
      final a = mgr.registerAttack(pc);
      expect(a.turnState!.attacksThisTurn, 1);
      expect(a.turnState!.firstAttackMade, isTrue);
      final b = mgr.registerAttack(a);
      expect(b.turnState!.attacksThisTurn, 2);
    });

    test('spendMovement accumulates', () {
      final pc = _pc(turnState: const TurnState(entityId: 'pc'));
      final a = mgr.spendMovement(entity: pc, feet: 15);
      final b = mgr.spendMovement(entity: a, feet: 10);
      expect(b.turnState!.movementUsed, 25);
    });
  });

  // ─── Exhaustion stacking ─────────────────────────────────────────────────
  group('TurnManager — exhaustion', () {
    const mgr = TurnManager();

    test('increment from 0 → 1', () {
      final pc = _pc();
      final a = mgr.incrementExhaustion(pc);
      expect(mgr.exhaustionLevel(a), 1);
      expect(a.activeEffects, hasLength(1));
      expect(
        a.activeEffects.first.conditionId,
        'condition-exhaustion',
      );
    });

    test('increment stacks up to cap 6', () {
      var pc = _pc();
      for (var i = 0; i < 10; i++) {
        pc = mgr.incrementExhaustion(pc);
      }
      expect(mgr.exhaustionLevel(pc), 6);
    });

    test('decrement goes back to 0 and removes effect', () {
      var pc = _pc();
      pc = mgr.incrementExhaustion(pc, amount: 3);
      expect(mgr.exhaustionLevel(pc), 3);
      pc = mgr.decrementExhaustion(pc, amount: 3);
      expect(mgr.exhaustionLevel(pc), 0);
      expect(
        pc.activeEffects.any((e) => e.conditionId == 'condition-exhaustion'),
        isFalse,
      );
    });

    test('decrement below 0 clamps', () {
      final pc = _pc();
      final a = mgr.decrementExhaustion(pc);
      expect(mgr.exhaustionLevel(a), 0);
    });

    test('exhaustion preserves unrelated conditions', () {
      var pc = _pc(effects: const [
        AppliedEffect(effectId: 'p', conditionId: 'condition-poisoned'),
      ]);
      pc = mgr.incrementExhaustion(pc, amount: 2);
      expect(
        pc.activeEffects.any((e) => e.conditionId == 'condition-poisoned'),
        isTrue,
      );
      expect(mgr.exhaustionLevel(pc), 2);
    });
  });
}
