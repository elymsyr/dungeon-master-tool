import 'package:dungeon_master_tool/application/services/d20_test_service.dart';
import 'package:dungeon_master_tool/application/services/damage_pipeline.dart';
import 'package:dungeon_master_tool/application/services/dice_roller.dart';
import 'package:dungeon_master_tool/application/services/rule_engine_v3.dart';
import 'package:dungeon_master_tool/application/services/rule_event_bus.dart';
import 'package:dungeon_master_tool/domain/entities/applied_effect.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/event_kind.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_effects_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_expressions_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_predicates_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_triggers.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_v3.dart';
import 'package:flutter_test/flutter_test.dart';

EntityCategorySchema _cat() => EntityCategorySchema(
      categoryId: 'player',
      schemaId: 'test',
      name: 'player',
      slug: 'player',
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

/// Test için 2 zar döndüren roller — ilk çağrı r1, ikinci r2.
class _SequenceRoller implements DiceRoller {
  _SequenceRoller(this._rolls);
  final List<int> _rolls;
  int _i = 0;
  @override
  int roll(String notation) {
    final v = _rolls[_i % _rolls.length];
    _i++;
    return v;
  }

  @override
  double average(String notation) => 10.5;
}

void main() {
  group('D20TestService — roll resolution', () {
    test('straight roll no adv/disadv → single die', () {
      final engine = RuleEngineV3();
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(15),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final result = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.abilityCheck,
        baseModifier: 3,
      );
      expect(result.rawRolls, [15]);
      expect(result.d20Roll, 15);
      expect(result.total, 18);
      expect(result.advantage, isFalse);
      expect(result.disadvantage, isFalse);
    });

    test('advantage takes max of two rolls', () {
      final engine = RuleEngineV3();
      final rules = [
        _rule(
          'adv',
          const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          const RuleEffectV3.grantAdvantage(
            scope: AdvantageScope.attackRoll,
          ),
        ),
      ];
      final service = D20TestService(
        engine: engine,
        diceRoller: _SequenceRoller([5, 17]),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final result = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: rules,
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
      );
      expect(result.advantage, isTrue);
      expect(result.d20Roll, 17);
      expect(result.rawRolls, [5, 17]);
    });

    test('disadvantage takes min of two rolls', () {
      final engine = RuleEngineV3();
      final rules = [
        _rule(
          'dis',
          const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          const RuleEffectV3.grantDisadvantage(
            scope: AdvantageScope.attackRoll,
          ),
        ),
      ];
      final service = D20TestService(
        engine: engine,
        diceRoller: _SequenceRoller([15, 3]),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final result = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: rules,
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
      );
      expect(result.disadvantage, isTrue);
      expect(result.d20Roll, 3);
    });

    test('advantage + disadvantage cancel each other', () {
      final engine = RuleEngineV3();
      final rules = [
        _rule(
          'adv',
          const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          const RuleEffectV3.grantAdvantage(
            scope: AdvantageScope.attackRoll,
          ),
        ),
        _rule(
          'dis',
          const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          const RuleEffectV3.grantDisadvantage(
            scope: AdvantageScope.attackRoll,
          ),
        ),
      ];
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(10),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final result = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: rules,
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
      );
      expect(result.advantage, isFalse);
      expect(result.disadvantage, isFalse);
      expect(result.rawRolls, [10]);
    });
  });

  group('D20TestService — critical + proficiency + DC', () {
    test('nat 20 is critical on attack', () {
      final engine = RuleEngineV3();
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(20),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final r = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
        dc: 25,
      );
      expect(r.critical, isTrue);
      expect(r.success, isTrue); // crit → hit regardless of DC
    });

    test('nat 1 on attack auto-misses', () {
      final engine = RuleEngineV3();
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(1),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final r = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
        dc: 5,
        baseModifier: 10,
      );
      expect(r.criticalMissRange, isTrue);
      expect(r.success, isFalse); // nat 1 auto-fail despite total 11 > DC 5
    });

    test('Champion L3 → crit range 19', () {
      final engine = RuleEngineV3();
      final rules = [
        _rule(
          'champion',
          const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          const RuleEffectV3.modifyCriticalRange(newMinRange: 19),
        ),
      ];
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(19),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final r = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: rules,
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
      );
      expect(r.critical, isTrue);
    });

    test('proficient adds PB from level 5 → +3', () {
      final engine = RuleEngineV3();
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(10),
      );
      final pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {'total_level': 5},
      );
      final r = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.savingThrow,
        baseModifier: 2,
        proficient: true,
      );
      // 10 + 2 (mod) + 3 (PB@L5) = 15
      expect(r.total, 15);
    });

    test('non-proficient on skill check no PB', () {
      final engine = RuleEngineV3();
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(10),
      );
      final pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {'total_level': 5},
      );
      final r = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.abilityCheck,
        baseModifier: 2,
        proficient: false,
      );
      expect(r.total, 12); // 10 + 2, no PB
    });

    test('attack bonus rule adds to total', () {
      final engine = RuleEngineV3();
      final rules = [
        _rule(
          'archery',
          const RuleTrigger.d20Test(testType: D20TestType.attackRoll),
          const RuleEffectV3.modifyAttackRoll(
            bonus: ValueExpressionV3.literal(2),
          ),
        ),
      ];
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(10),
      );
      final pc = Entity(id: 'pc', categorySlug: 'player');
      final r = service.rollTest(
        entity: pc,
        category: _cat(),
        rules: rules,
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
        baseModifier: 3,
      );
      expect(r.total, 15); // 10 + 3 + 2
    });
  });

  group('D20TestService — event emission', () {
    test('attackRoll fires onAttackMade + onAttackHit on success', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(id: 'pc', categorySlug: 'player');
      final bus = RuleEventBus(
        engine: engine,
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat(),
        rulesResolver: (_) => const [],
        entitySink: (u) => pc = u,
      );
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(15),
        eventBus: bus,
      );
      final fired = <EventKind>[];
      bus.events.listen((e) => fired.add(e.kind));
      service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
        dc: 12,
        targetEntityId: 'enemy',
      );
      // Sync test via lastTrace.
      expect(
        bus.lastTrace.map((e) => e.kind).toList(),
        containsAll([EventKind.onAttackMade, EventKind.onAttackHit]),
      );
    });

    test('attackRoll miss fires onAttackMiss', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(id: 'pc', categorySlug: 'player');
      final bus = RuleEventBus(
        engine: engine,
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat(),
        rulesResolver: (_) => const [],
        entitySink: (u) => pc = u,
      );
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(5),
        eventBus: bus,
      );
      service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
        dc: 15,
      );
      expect(
        bus.lastTrace.any((e) => e.kind == EventKind.onAttackMiss),
        isTrue,
      );
    });

    test('nat 20 fires onCriticalHit + onAttackHit', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(id: 'pc', categorySlug: 'player');
      final bus = RuleEventBus(
        engine: engine,
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat(),
        rulesResolver: (_) => const [],
        entitySink: (u) => pc = u,
      );
      final service = D20TestService(
        engine: engine,
        diceRoller: FixedDiceRoller(20),
        eventBus: bus,
      );
      service.rollTest(
        entity: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        testType: D20TestType.attackRoll,
        dc: 50,
      );
      final kinds = bus.lastTrace.map((e) => e.kind).toList();
      expect(kinds.contains(EventKind.onCriticalHit), isTrue);
      expect(kinds.contains(EventKind.onAttackHit), isTrue);
    });
  });

  group('DamagePipeline — base + resistance + immunity + vulnerability', () {
    test('straight damage reduces hp', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'goblin',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 10},
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'goblin': target},
        amount: 7,
        damageType: 'slashing',
      );
      expect(result.appliedAmount, 7);
      expect(result.newHp, 3);
    });

    test('resistance halves (floor)', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 20},
          'damage_resistances': ['fire'],
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 9,
        damageType: 'fire',
      );
      expect(result.wasResistant, isTrue);
      expect(result.appliedAmount, 4); // 9 ~/ 2
    });

    test('immunity → 0', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 20},
          'damage_immunities': ['poison'],
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 30,
        damageType: 'poison',
      );
      expect(result.wasImmune, isTrue);
      expect(result.appliedAmount, 0);
      expect(result.newHp, 20);
    });

    test('vulnerability doubles', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'ice',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 30},
          'damage_vulnerabilities': ['fire'],
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'ice': target},
        amount: 10,
        damageType: 'fire',
      );
      expect(result.wasVulnerable, isTrue);
      expect(result.appliedAmount, 20); // 10 * 2
      expect(result.newHp, 10);
    });

    test('vulnerability + resistance apply in order → 10 * 2 / 2 = 10', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'weird',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 30},
          'damage_vulnerabilities': ['fire'],
          'damage_resistances': ['fire'],
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'weird': target},
        amount: 10,
        damageType: 'fire',
      );
      expect(result.appliedAmount, 10);
    });

    test('critical doubles damage', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 30},
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 8,
        damageType: 'slashing',
        isCritical: true,
      );
      expect(result.wasCritical, isTrue);
      expect(result.appliedAmount, 16);
      expect(result.newHp, 14);
    });
  });

  group('DamagePipeline — temp HP + hp zero + concentration', () {
    test('temp HP absorbs first', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 20, 'temp_hp': 5},
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 8,
        damageType: 'slashing',
      );
      expect(result.absorbedByTempHp, 5);
      expect(result.newTempHp, 0);
      expect(result.newHp, 17); // 20 - 3
    });

    test('HP zero sets hpZero flag', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 5},
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 100,
        damageType: 'slashing',
      );
      expect(result.hpZero, isTrue);
      expect(result.newHp, 0);
    });

    test('concentration save DC = max(10, damage/2)', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 50},
        },
        activeEffects: const [
          AppliedEffect(effectId: 'bless', requiresConcentration: true),
        ],
      );
      final low = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 8,
        damageType: 'slashing',
      );
      expect(low.concentrationSaveDc, 10); // min 10

      final high = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 30,
        damageType: 'slashing',
      );
      expect(high.concentrationSaveDc, 15); // 30 / 2
    });

    test('no concentration → concSaveDc null', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 50},
        },
      );
      final r = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 10,
        damageType: 'slashing',
      );
      expect(r.concentrationSaveDc, isNull);
    });
  });

  group('DamagePipeline — events + mutation', () {
    test('emits onDamageTaken + onHpZero', () {
      final engine = RuleEngineV3();
      Entity pc = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 3},
        },
      );
      final bus = RuleEventBus(
        engine: engine,
        entityResolver: (id) => pc.id == id ? pc : null,
        categoryResolver: (_) => _cat(),
        rulesResolver: (_) => const [],
        entitySink: (u) => pc = u,
      );
      final pipe = DamagePipeline(engine: engine, eventBus: bus);
      pipe.apply(
        target: pc,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': pc},
        amount: 10,
        damageType: 'slashing',
      );
      final kinds = bus.lastTrace.map((e) => e.kind).toList();
      expect(kinds.contains(EventKind.onDamageTaken), isTrue);
      expect(kinds.contains(EventKind.onHpZero), isTrue);
    });

    test('applyMutation updates combat_stats.hp + temp_hp', () {
      final engine = RuleEngineV3();
      final pipe = DamagePipeline(engine: engine);
      final target = Entity(
        id: 'pc',
        categorySlug: 'player',
        fields: const {
          'combat_stats': {'hp': 10, 'temp_hp': 5},
        },
      );
      final result = pipe.apply(
        target: target,
        category: _cat(),
        rules: const [],
        allEntities: {'pc': target},
        amount: 8,
        damageType: 'slashing',
      );
      final mutated = pipe.applyMutation(target: target, result: result);
      final combat = mutated.fields['combat_stats'] as Map;
      expect(combat['hp'], 7);
      expect(combat['temp_hp'], 0);
    });
  });
}
