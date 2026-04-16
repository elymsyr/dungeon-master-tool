import 'package:dungeon_master_tool/application/services/rule_engine_v2.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rule_v2.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Test Helpers ────────────────────────────────────────────────────────────

Entity _entity(String id, String slug, {Map<String, dynamic> fields = const {}}) {
  return Entity(id: id, name: id, categorySlug: slug, fields: fields);
}

EntityCategorySchema _cat(String slug, {List<RuleV2> rules = const []}) {
  return EntityCategorySchema(
    categoryId: slug,
    schemaId: 'test',
    name: slug,
    slug: slug,
    rules: rules,
    createdAt: '',
    updatedAt: '',
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('Predicate evaluation', () {
    test('always predicate returns true', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'speed',
            value: ValueExpression.literal(30),
          ),
        ),
      ]);
      final entity = _entity('e1', 'npc');
      final result = RuleEngineV2.evaluate(entity: entity, category: cat, allEntities: {'e1': entity});
      expect(result.computedValues['speed'], 30);
    });

    test('compare predicate - gte with literal', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.compare(
            left: FieldRef(scope: RefScope.self, fieldKey: 'level'),
            op: CompareOp.gte,
            literalValue: 5,
          ),
          then_: RuleEffect.setValue(
            targetFieldKey: 'bonus',
            value: ValueExpression.literal(10),
          ),
        ),
      ]);

      // Level 3 — should NOT fire
      final low = _entity('e1', 'npc', fields: {'level': 3});
      final r1 = RuleEngineV2.evaluate(entity: low, category: cat, allEntities: {'e1': low});
      expect(r1.computedValues.containsKey('bonus'), false);

      // Level 7 — should fire
      final high = _entity('e2', 'npc', fields: {'level': 7});
      final r2 = RuleEngineV2.evaluate(entity: high, category: cat, allEntities: {'e2': high});
      expect(r2.computedValues['bonus'], 10);
    });

    test('compare predicate - eq', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.compare(
            left: FieldRef(scope: RefScope.self, fieldKey: 'class'),
            op: CompareOp.eq,
            literalValue: 'wizard',
          ),
          then_: RuleEffect.setValue(
            targetFieldKey: 'spellcaster',
            value: ValueExpression.literal(true),
          ),
        ),
      ]);

      final wizard = _entity('e1', 'npc', fields: {'class': 'wizard'});
      final r1 = RuleEngineV2.evaluate(entity: wizard, category: cat, allEntities: {'e1': wizard});
      expect(r1.computedValues['spellcaster'], true);

      final fighter = _entity('e2', 'npc', fields: {'class': 'fighter'});
      final r2 = RuleEngineV2.evaluate(entity: fighter, category: cat, allEntities: {'e2': fighter});
      expect(r2.computedValues.containsKey('spellcaster'), false);
    });

    test('and predicate', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.and([
            Predicate.compare(left: FieldRef(scope: RefScope.self, fieldKey: 'str'), op: CompareOp.gte, literalValue: 10),
            Predicate.compare(left: FieldRef(scope: RefScope.self, fieldKey: 'dex'), op: CompareOp.gte, literalValue: 10),
          ]),
          then_: RuleEffect.setValue(targetFieldKey: 'fit', value: ValueExpression.literal(true)),
        ),
      ]);

      final both = _entity('e1', 'npc', fields: {'str': 12, 'dex': 14});
      expect(RuleEngineV2.evaluate(entity: both, category: cat, allEntities: {'e1': both}).computedValues['fit'], true);

      final onlyStr = _entity('e2', 'npc', fields: {'str': 12, 'dex': 5});
      expect(RuleEngineV2.evaluate(entity: onlyStr, category: cat, allEntities: {'e2': onlyStr}).computedValues.containsKey('fit'), false);
    });

    test('or predicate', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.or([
            Predicate.compare(left: FieldRef(scope: RefScope.self, fieldKey: 'class'), op: CompareOp.eq, literalValue: 'wizard'),
            Predicate.compare(left: FieldRef(scope: RefScope.self, fieldKey: 'class'), op: CompareOp.eq, literalValue: 'sorcerer'),
          ]),
          then_: RuleEffect.setValue(targetFieldKey: 'caster', value: ValueExpression.literal(true)),
        ),
      ]);

      final wizard = _entity('e1', 'npc', fields: {'class': 'wizard'});
      expect(RuleEngineV2.evaluate(entity: wizard, category: cat, allEntities: {'e1': wizard}).computedValues['caster'], true);

      final sorcerer = _entity('e2', 'npc', fields: {'class': 'sorcerer'});
      expect(RuleEngineV2.evaluate(entity: sorcerer, category: cat, allEntities: {'e2': sorcerer}).computedValues['caster'], true);

      final fighter = _entity('e3', 'npc', fields: {'class': 'fighter'});
      expect(RuleEngineV2.evaluate(entity: fighter, category: cat, allEntities: {'e3': fighter}).computedValues.containsKey('caster'), false);
    });

    test('not predicate', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.not(Predicate.compare(
            left: FieldRef(scope: RefScope.self, fieldKey: 'level'),
            op: CompareOp.isEmpty,
          )),
          then_: RuleEffect.setValue(targetFieldKey: 'has_level', value: ValueExpression.literal(true)),
        ),
      ]);

      final withLevel = _entity('e1', 'npc', fields: {'level': 5});
      expect(RuleEngineV2.evaluate(entity: withLevel, category: cat, allEntities: {'e1': withLevel}).computedValues['has_level'], true);

      final without = _entity('e2', 'npc', fields: {});
      expect(RuleEngineV2.evaluate(entity: without, category: cat, allEntities: {'e2': without}).computedValues.containsKey('has_level'), false);
    });

    test('isEmpty and isNotEmpty', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.compare(left: FieldRef(scope: RefScope.self, fieldKey: 'items'), op: CompareOp.isNotEmpty),
          then_: RuleEffect.setValue(targetFieldKey: 'has_items', value: ValueExpression.literal(true)),
        ),
      ]);

      final withItems = _entity('e1', 'npc', fields: {'items': ['sword']});
      expect(RuleEngineV2.evaluate(entity: withItems, category: cat, allEntities: {'e1': withItems}).computedValues['has_items'], true);

      final empty = _entity('e2', 'npc', fields: {'items': []});
      expect(RuleEngineV2.evaluate(entity: empty, category: cat, allEntities: {'e2': empty}).computedValues.containsKey('has_items'), false);
    });

    test('isSubsetOf for cross-field comparison', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.compare(
            left: FieldRef(scope: RefScope.self, fieldKey: 'required'),
            op: CompareOp.isSubsetOf,
            right: FieldRef(scope: RefScope.self, fieldKey: 'inventory'),
          ),
          then_: RuleEffect.setValue(targetFieldKey: 'ready', value: ValueExpression.literal(true)),
        ),
      ]);

      final ready = _entity('e1', 'npc', fields: {'required': ['sword', 'shield'], 'inventory': ['sword', 'shield', 'potion']});
      expect(RuleEngineV2.evaluate(entity: ready, category: cat, allEntities: {'e1': ready}).computedValues['ready'], true);

      final notReady = _entity('e2', 'npc', fields: {'required': ['sword', 'shield'], 'inventory': ['sword', 'potion']});
      expect(RuleEngineV2.evaluate(entity: notReady, category: cat, allEntities: {'e2': notReady}).computedValues.containsKey('ready'), false);
    });
  });

  group('Value expressions', () {
    test('fieldValue from related entity', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'pull speed',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'speed',
            value: ValueExpression.fieldValue(FieldRef(
              scope: RefScope.related,
              fieldKey: 'base_speed',
              relationFieldKey: 'race_ref',
            )),
          ),
        ),
      ]);

      final race = _entity('race1', 'race', fields: {'base_speed': 30});
      final npc = _entity('npc1', 'npc', fields: {'race_ref': 'race1'});
      final all = {'npc1': npc, 'race1': race};

      final result = RuleEngineV2.evaluate(entity: npc, category: cat, allEntities: all);
      expect(result.computedValues['speed'], 30);
    });

    test('aggregate sum', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'total bonus',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'total_bonus',
            value: ValueExpression.aggregate(
              relationFieldKey: 'equipment',
              sourceFieldKey: 'bonus',
              op: AggregateOp.sum,
            ),
          ),
        ),
      ]);

      final sword = _entity('sw1', 'equipment', fields: {'bonus': 3});
      final shield = _entity('sh1', 'equipment', fields: {'bonus': 2});
      final npc = _entity('npc1', 'npc', fields: {
        'equipment': [
          {'id': 'sw1', 'equipped': true},
          {'id': 'sh1', 'equipped': true},
        ],
      });

      final result = RuleEngineV2.evaluate(
        entity: npc,
        category: cat,
        allEntities: {'npc1': npc, 'sw1': sword, 'sh1': shield},
      );
      expect(result.computedValues['total_bonus'], 5);
    });

    test('aggregate sum with onlyEquipped', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'equipped bonus',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'equipped_bonus',
            value: ValueExpression.aggregate(
              relationFieldKey: 'equipment',
              sourceFieldKey: 'bonus',
              op: AggregateOp.sum,
              onlyEquipped: true,
            ),
          ),
        ),
      ]);

      final sword = _entity('sw1', 'equipment', fields: {'bonus': 3});
      final shield = _entity('sh1', 'equipment', fields: {'bonus': 2});
      final npc = _entity('npc1', 'npc', fields: {
        'equipment': [
          {'id': 'sw1', 'equipped': true},
          {'id': 'sh1', 'equipped': false}, // not equipped
        ],
      });

      final result = RuleEngineV2.evaluate(
        entity: npc,
        category: cat,
        allEntities: {'npc1': npc, 'sw1': sword, 'sh1': shield},
      );
      expect(result.computedValues['equipped_bonus'], 3);
    });

    test('aggregate append (conditionalList replacement)', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'collect spells',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'all_spells',
            value: ValueExpression.aggregate(
              relationFieldKey: 'equipment',
              sourceFieldKey: 'spells',
              op: AggregateOp.append,
              onlyEquipped: true,
            ),
          ),
        ),
      ]);

      final wand = _entity('wand1', 'equipment', fields: {'spells': ['fireball', 'ice_bolt']});
      final ring = _entity('ring1', 'equipment', fields: {'spells': ['heal']});
      final npc = _entity('npc1', 'npc', fields: {
        'equipment': [
          {'id': 'wand1', 'equipped': true},
          {'id': 'ring1', 'equipped': true},
        ],
      });

      final result = RuleEngineV2.evaluate(
        entity: npc,
        category: cat,
        allEntities: {'npc1': npc, 'wand1': wand, 'ring1': ring},
      );
      final spells = result.computedValues['all_spells'] as List;
      expect(spells.length, 3);
      expect(spells.any((s) => s['id'] == 'fireball'), true);
      expect(spells.any((s) => s['id'] == 'heal'), true);
    });

    test('arithmetic expression', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'calculated AC',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'ac',
            value: ValueExpression.arithmetic(
              left: ValueExpression.literal(10),
              op: ArithOp.add,
              right: ValueExpression.fieldValue(FieldRef(scope: RefScope.self, fieldKey: 'dex_mod')),
            ),
          ),
        ),
      ]);

      final npc = _entity('npc1', 'npc', fields: {'dex_mod': 3});
      final result = RuleEngineV2.evaluate(entity: npc, category: cat, allEntities: {'npc1': npc});
      expect(result.computedValues['ac'], 13);
    });

    test('nested field value (statBlock)', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'str check',
          when_: Predicate.compare(
            left: FieldRef(scope: RefScope.self, fieldKey: 'stats', nestedFieldKey: 'STR'),
            op: CompareOp.gte,
            literalValue: 15,
          ),
          then_: RuleEffect.setValue(targetFieldKey: 'strong', value: ValueExpression.literal(true)),
        ),
      ]);

      final strong = _entity('e1', 'npc', fields: {'stats': {'STR': 18, 'DEX': 12}});
      expect(RuleEngineV2.evaluate(entity: strong, category: cat, allEntities: {'e1': strong}).computedValues['strong'], true);

      final weak = _entity('e2', 'npc', fields: {'stats': {'STR': 8, 'DEX': 12}});
      expect(RuleEngineV2.evaluate(entity: weak, category: cat, allEntities: {'e2': weak}).computedValues.containsKey('strong'), false);
    });
  });

  group('Effect types', () {
    test('gateEquip blocks items that fail predicate', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'str gate',
          when_: Predicate.compare(
            left: FieldRef(scope: RefScope.self, fieldKey: 'str'),
            op: CompareOp.gte,
            right: FieldRef(scope: RefScope.related, fieldKey: 'required_str'),
          ),
          then_: RuleEffect.gateEquip(blockReason: 'Strength too low'),
        ),
      ]);

      final heavySword = _entity('sw1', 'equipment', fields: {'required_str': 15});
      final lightDagger = _entity('dg1', 'equipment', fields: {'required_str': 5});
      final npc = _entity('npc1', 'npc', fields: {
        'str': 10,
        'equipment': [
          {'id': 'sw1', 'equipped': false},
          {'id': 'dg1', 'equipped': false},
        ],
      });

      final result = RuleEngineV2.evaluate(
        entity: npc,
        category: cat,
        allEntities: {'npc1': npc, 'sw1': heavySword, 'dg1': lightDagger},
      );

      // Heavy sword should be gated (STR 10 < required 15)
      expect(result.equipGates['sw1'], 'Strength too low');
      // Light dagger should NOT be gated (STR 10 >= required 5)
      expect(result.equipGates.containsKey('dg1'), false);
    });

    test('styleItems fades items when condition not met', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'fade missing items',
          when_: Predicate.compare(
            left: FieldRef(scope: RefScope.related, fieldKey: 'required_items'),
            op: CompareOp.isSubsetOf,
            right: FieldRef(scope: RefScope.self, fieldKey: 'inventory'),
          ),
          then_: RuleEffect.styleItems(
            listFieldKey: 'spells',
            style: ItemStyle(faded: true, tooltip: 'Missing required items'),
          ),
        ),
      ]);

      final fireball = _entity('spell1', 'spell', fields: {'required_items': ['ruby']});
      final heal = _entity('spell2', 'spell', fields: {'required_items': ['herb']});
      final npc = _entity('npc1', 'npc', fields: {
        'inventory': ['herb', 'potion'],
        'spells': [
          {'id': 'spell1', 'equipped': true},
          {'id': 'spell2', 'equipped': true},
        ],
      });

      final result = RuleEngineV2.evaluate(
        entity: npc,
        category: cat,
        allEntities: {'npc1': npc, 'spell1': fireball, 'spell2': heal},
      );

      // Fireball: needs ruby, inventory has no ruby → faded
      expect(result.itemStyles['spell1']?.faded, true);
      expect(result.itemStyles['spell1']?.tooltip, 'Missing required items');

      // Heal: needs herb, inventory has herb → NOT faded
      expect(result.itemStyles.containsKey('spell2'), false);
    });

    test('modifyWhileEquipped applies effect from equipped items', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'cursed penalty',
          when_: Predicate.always(),
          then_: RuleEffect.modifyWhileEquipped(
            targetFieldKey: 'ac_penalty',
            value: ValueExpression.fieldValue(FieldRef(scope: RefScope.related, fieldKey: 'penalty')),
          ),
        ),
      ]);

      final cursedRing = _entity('ring1', 'equipment', fields: {'penalty': -2});
      final normalSword = _entity('sw1', 'equipment', fields: {'penalty': 0});
      final npc = _entity('npc1', 'npc', fields: {
        'equipment': [
          {'id': 'ring1', 'equipped': true},
          {'id': 'sw1', 'equipped': false}, // not equipped, should not apply
        ],
      });

      final result = RuleEngineV2.evaluate(
        entity: npc,
        category: cat,
        allEntities: {'npc1': npc, 'ring1': cursedRing, 'sw1': normalSword},
      );

      expect(result.equippedModifiers['ac_penalty'], -2);
    });
  });

  group('Dependency collection', () {
    test('collects IDs from relation fields referenced by rules', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'speed',
            value: ValueExpression.fieldValue(FieldRef(
              scope: RefScope.related,
              fieldKey: 'base_speed',
              relationFieldKey: 'race_ref',
            )),
          ),
        ),
      ]);

      final npc = _entity('npc1', 'npc', fields: {'race_ref': 'race1'});
      final deps = RuleEngineV2.collectDependencyIds(npc, cat);
      expect(deps, {'race1'});
    });

    test('collects IDs from list relation fields', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'total',
            value: ValueExpression.aggregate(
              relationFieldKey: 'equipment',
              sourceFieldKey: 'bonus',
              op: AggregateOp.sum,
            ),
          ),
        ),
      ]);

      final npc = _entity('npc1', 'npc', fields: {
        'equipment': [
          {'id': 'sw1', 'equipped': true},
          {'id': 'sh1', 'equipped': true},
        ],
      });
      final deps = RuleEngineV2.collectDependencyIds(npc, cat);
      expect(deps, {'sw1', 'sh1'});
    });
  });

  group('Priority ordering', () {
    test('rules execute in priority order', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r2',
          name: 'second',
          priority: 1,
          when_: Predicate.always(),
          then_: RuleEffect.setValue(targetFieldKey: 'val', value: ValueExpression.literal('second')),
        ),
        const RuleV2(
          ruleId: 'r1',
          name: 'first',
          priority: 0,
          when_: Predicate.always(),
          then_: RuleEffect.setValue(targetFieldKey: 'val', value: ValueExpression.literal('first')),
        ),
      ]);

      final npc = _entity('npc1', 'npc');
      final result = RuleEngineV2.evaluate(entity: npc, category: cat, allEntities: {'npc1': npc});
      // Priority 1 runs after priority 0, so 'second' overwrites 'first'
      expect(result.computedValues['val'], 'second');
    });
  });

  group('Edge cases', () {
    test('disabled rules are skipped', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'disabled',
          enabled: false,
          when_: Predicate.always(),
          then_: RuleEffect.setValue(targetFieldKey: 'val', value: ValueExpression.literal(42)),
        ),
      ]);

      final npc = _entity('npc1', 'npc');
      final result = RuleEngineV2.evaluate(entity: npc, category: cat, allEntities: {'npc1': npc});
      expect(result.computedValues.containsKey('val'), false);
    });

    test('empty rules list returns empty result', () {
      final cat = _cat('npc');
      final npc = _entity('npc1', 'npc');
      final result = RuleEngineV2.evaluate(entity: npc, category: cat, allEntities: {'npc1': npc});
      expect(result.isEmpty, true);
    });

    test('missing related entity returns null for field value', () {
      final cat = _cat('npc', rules: [
        const RuleV2(
          ruleId: 'r1',
          name: 'test',
          when_: Predicate.always(),
          then_: RuleEffect.setValue(
            targetFieldKey: 'speed',
            value: ValueExpression.fieldValue(FieldRef(
              scope: RefScope.related,
              fieldKey: 'base_speed',
              relationFieldKey: 'race_ref',
            )),
          ),
        ),
      ]);

      final npc = _entity('npc1', 'npc', fields: {'race_ref': 'nonexistent'});
      final result = RuleEngineV2.evaluate(entity: npc, category: cat, allEntities: {'npc1': npc});
      expect(result.computedValues.containsKey('speed'), false);
    });
  });
}
