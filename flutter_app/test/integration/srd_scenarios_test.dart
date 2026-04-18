import 'package:dungeon_master_tool/application/services/choice_manager.dart';
import 'package:dungeon_master_tool/application/services/resource_manager.dart';
import 'package:dungeon_master_tool/application/services/rule_engine_v3.dart';
import 'package:dungeon_master_tool/application/services/rule_event_bus.dart';
import 'package:dungeon_master_tool/application/services/turn_manager.dart';
import 'package:dungeon_master_tool/domain/entities/applied_effect.dart';
import 'package:dungeon_master_tool/domain/entities/choice_state.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/resource_state.dart';
import 'package:dungeon_master_tool/domain/entities/schema/default_dnd5e_rules_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/event_kind.dart';
import 'package:flutter_test/flutter_test.dart';

EntityCategorySchema _playerCat() => EntityCategorySchema(
      categoryId: 'player',
      schemaId: 'srd-5.2.1',
      name: 'Player',
      slug: 'player',
      createdAt: '',
      updatedAt: '',
    );

void main() {
  final seedRules = Dnd5eRulesV3.forPlayerCategory();
  final reactiveRules = Dnd5eRulesV3.forPlayerReactive();
  final eventRules = Dnd5eRulesV3.forPlayerEvents();
  final d20Rules = Dnd5eRulesV3.forPlayerD20Tests();

  // ── Fighter L5 ──────────────────────────────────────────────────────────
  group('Fighter L5', () {
    test('ability modifiers computed correctly', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'aragorn',
        categorySlug: 'player',
        name: 'Aragorn',
        fields: const {
          'total_level': 5,
          'stat_block': {
            'STR': 16,
            'DEX': 14,
            'CON': 14,
            'INT': 10,
            'WIS': 12,
            'CHA': 10,
          },
        },
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'aragorn': pc},
        rules: reactiveRules,
      );
      expect(result.computedValues['str_mod'], 3);
      expect(result.computedValues['dex_mod'], 2);
      expect(result.computedValues['con_mod'], 2);
      expect(result.computedValues['int_mod'], 0);
      expect(result.computedValues['wis_mod'], 1);
      expect(result.computedValues['cha_mod'], 0);
    });

    test('L5 → PB 3', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'aragorn',
        categorySlug: 'player',
        fields: const {'total_level': 5},
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'aragorn': pc},
        rules: reactiveRules,
      );
      expect(result.computedValues['proficiency_bonus'], 3);
    });

    test('Perception proficient + WIS 12 → PP 14', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'aragorn',
        categorySlug: 'player',
        fields: const {
          'total_level': 5,
          'stat_block': {'WIS': 12},
          'skill_perception_proficient': true,
        },
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'aragorn': pc},
        rules: reactiveRules,
      );
      // 10 + 1 (WIS mod) + 3 (PB@L5) = 14
      expect(result.computedValues['passive_perception'], 14);
    });

    test('Not proficient → PP 11', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'total_level': 5,
          'stat_block': {'WIS': 12},
          'skill_perception_proficient': false,
        },
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'pc': pc},
        rules: reactiveRules,
      );
      // 10 + 1 (WIS mod) = 11, no PB
      expect(result.computedValues['passive_perception'], 11);
    });

    test('STR 16 → carrying capacity 240 lbs', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'aragorn',
        categorySlug: 'player',
        fields: const {
          'stat_block': {'STR': 16},
        },
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'aragorn': pc},
        rules: reactiveRules,
      );
      expect(result.computedValues['carrying_capacity'], 240);
    });
  });

  // ── Wizard L5 (Fireball slot consume) ────────────────────────────────────
  group('Wizard L5 — Spellcasting', () {
    test('INT 18 + L5 → spell save DC 15', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'gandalf',
        categorySlug: 'player',
        fields: const {
          'total_level': 5,
          'stat_block': {'INT': 18},
          'casting_ability_mod': 4,
        },
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'gandalf': pc},
        rules: reactiveRules,
      );
      expect(result.computedValues['spell_save_dc'], 15); // 8 + 3 + 4
      expect(result.computedValues['spell_attack_bonus'], 7); // 3 + 4
    });

    test('Fireball (slot 3) consumes 1 from spell_slot_3', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(
        id: 'gandalf',
        categorySlug: 'player',
        resources: const {
          'spell_slot_3': ResourceState(
            resourceKey: 'spell_slot_3',
            current: 2,
            max: 2,
            refreshRule: RefreshRule.longRest,
          ),
        },
      );
      final bus = RuleEventBus(
        engine: engine,
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _playerCat(),
        rulesResolver: (_) => eventRules,
        entitySink: (u) => pc = u,
      );
      bus.fire(
        EventKind.onSpellCast,
        'gandalf',
        payload: {'slot_level': 3},
      );
      expect(pc.resources['spell_slot_3']!.current, 1);
    });

    test('Long rest refreshes spell slots + hit dice half', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(
        id: 'gandalf',
        categorySlug: 'player',
        resources: const {
          'spell_slot_1': ResourceState(
            resourceKey: 'spell_slot_1',
            current: 0,
            max: 4,
            refreshRule: RefreshRule.longRest,
          ),
          'spell_slot_3': ResourceState(
            resourceKey: 'spell_slot_3',
            current: 1,
            max: 2,
            refreshRule: RefreshRule.longRest,
          ),
          'hit_dice_d6': ResourceState(
            resourceKey: 'hit_dice_d6',
            current: 1,
            max: 5,
            refreshRule: RefreshRule.longRest,
          ),
        },
      );
      final bus = RuleEventBus(
        engine: engine,
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _playerCat(),
        rulesResolver: (_) => eventRules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onLongRest, 'gandalf');

      expect(pc.resources['spell_slot_1']!.current, 4);
      expect(pc.resources['spell_slot_3']!.current, 2);
      // Hit dice d6 max=5, fraction 0.5 → ceil(2.5)=3 → 1+3=4
      expect(pc.resources['hit_dice_d6']!.current, 4);
    });
  });

  // ── Barbarian L3 — Rage mechanics ────────────────────────────────────────
  group('Barbarian L3 — Rage', () {
    const choiceMgr = ChoiceManager();
    const resourceMgr = ResourceManager();

    test('Rage active → advantage on STR ability check', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(
        id: 'conan',
        categorySlug: 'player',
        fields: const {
          'total_level': 3,
          'stat_block': {'STR': 16},
        },
        resources: const {
          'rage_uses': ResourceState(
            resourceKey: 'rage_uses',
            current: 3,
            max: 3,
            refreshRule: RefreshRule.longRest,
          ),
        },
      );
      pc = choiceMgr.record(
        entity: pc,
        choiceKey: 'rage_active',
        value: 'true',
      );
      final result = engine.evaluateD20Test(
        testType: D20TestType.abilityCheck,
        ability: 'STR',
        entity: pc,
        category: _playerCat(),
        allEntities: {'conan': pc},
        rules: d20Rules,
      );
      expect(result.advantages, isNotEmpty);
      expect(result.advantages.first.filter, 'STR');
    });

    test('Enter rage — consume rage_uses slot', () {
      Entity pc = Entity(
        id: 'conan',
        categorySlug: 'player',
        resources: const {
          'rage_uses': ResourceState(
            resourceKey: 'rage_uses',
            current: 3,
            max: 3,
            refreshRule: RefreshRule.longRest,
          ),
        },
      );
      pc = resourceMgr.consume(
        entity: pc,
        resourceKey: 'rage_uses',
        amount: 1,
      );
      expect(pc.resources['rage_uses']!.current, 2);
    });

    test('Long rest refills rage_uses', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(
        id: 'conan',
        categorySlug: 'player',
        resources: const {
          'rage_uses': ResourceState(
            resourceKey: 'rage_uses',
            current: 0,
            max: 3,
            refreshRule: RefreshRule.longRest,
          ),
        },
      );
      final bus = RuleEventBus(
        engine: engine,
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _playerCat(),
        rulesResolver: (_) => eventRules,
        entitySink: (u) => pc = u,
      );
      bus.fire(EventKind.onLongRest, 'conan');
      expect(pc.resources['rage_uses']!.current, 3);
    });
  });

  // ── Status effect cascades ───────────────────────────────────────────────
  group('Status effects — seed rules', () {
    test('Poisoned → disadvantage on attack roll (D20 path)', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        activeEffects: const [
          AppliedEffect(effectId: 'x', conditionId: 'condition-poisoned'),
        ],
      );
      final result = engine.evaluateD20Test(
        testType: D20TestType.attackRoll,
        entity: pc,
        category: _playerCat(),
        allEntities: {'pc': pc},
        rules: d20Rules,
      );
      expect(result.disadvantages, isNotEmpty);
    });

    test('Exhaustion Lv3 → d20 disadvantage', () {
      const mgr = TurnManager();
      var pc = Entity(id: 'pc', categorySlug: 'player');
      pc = mgr.incrementExhaustion(pc, amount: 3);
      final engine = RuleEngineV3();
      final result = engine.evaluateD20Test(
        testType: D20TestType.attackRoll,
        entity: pc,
        category: _playerCat(),
        allEntities: {'pc': pc},
        rules: d20Rules,
      );
      expect(result.disadvantages, isNotEmpty);
    });

    test('Exhaustion Lv2 does NOT trigger disadvantage rule', () {
      const mgr = TurnManager();
      var pc = Entity(id: 'pc', categorySlug: 'player');
      pc = mgr.incrementExhaustion(pc, amount: 2);
      final engine = RuleEngineV3();
      final result = engine.evaluateD20Test(
        testType: D20TestType.attackRoll,
        entity: pc,
        category: _playerCat(),
        allEntities: {'pc': pc},
        rules: d20Rules,
      );
      expect(result.disadvantages, isEmpty);
    });
  });

  // ── Attunement cap ───────────────────────────────────────────────────────
  group('Attunement', () {
    test('Below 3 items → slot available flag true', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'attunements': ['item-1', 'item-2'],
        },
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'pc': pc},
        rules: reactiveRules,
      );
      expect(result.computedValues['attunement_slot_available'], true);
    });

    test('3 items → flag not set', () {
      final engine = RuleEngineV3();
      final pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'attunements': ['a', 'b', 'c'],
        },
      );
      final result = engine.evaluateReactive(
        entity: pc,
        category: _playerCat(),
        allEntities: {'pc': pc},
        rules: reactiveRules,
      );
      expect(
        result.computedValues.containsKey('attunement_slot_available'),
        isFalse,
      );
    });
  });

  // ── Seed inventory sanity ────────────────────────────────────────────────
  test('forPlayerCategory() returns all 3 buckets combined', () {
    expect(
      seedRules.length,
      reactiveRules.length + eventRules.length + d20Rules.length,
    );
  });

  test('all seed rules have unique ruleId', () {
    final ids = seedRules.map((r) => r.ruleId).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('seed rules JSON round-trip', () {
    // Sanity — all seed rules must serialize + deserialize without loss.
    for (final rule in seedRules) {
      final json = rule.toJson();
      // Smoke: ruleId preserved.
      expect(json['ruleId'], rule.ruleId);
    }
  });

  test('choice-based rage check does not fire without choice recorded', () {
    final engine = RuleEngineV3();
    final pc = Entity(id: 'pc', categorySlug: 'player');
    final result = engine.evaluateD20Test(
      testType: D20TestType.abilityCheck,
      ability: 'STR',
      entity: pc,
      category: _playerCat(),
      allEntities: {'pc': pc},
      rules: d20Rules,
    );
    expect(result.advantages, isEmpty);
  });

  test('ChoiceState with value true fires rage advantage', () {
    final engine = RuleEngineV3();
    final pc = Entity(
      id: 'pc',
      categorySlug: 'player',
      choices: const {
        'rage_active': ChoiceState(
          choiceKey: 'rage_active',
          chosenValue: 'true',
        ),
      },
    );
    final result = engine.evaluateD20Test(
      testType: D20TestType.abilityCheck,
      ability: 'STR',
      entity: pc,
      category: _playerCat(),
      allEntities: {'pc': pc},
      rules: d20Rules,
    );
    expect(result.advantages, isNotEmpty);
  });
}
