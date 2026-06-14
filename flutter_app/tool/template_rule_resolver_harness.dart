// Dev harness for the SHADOW [TemplateRuleResolver] (roadmap PR-T7 / PR-2.4).
//
// Run from the Flutter project root (`flutter_app/`):
//
//     dart run tool/template_rule_resolver_harness.dart
//
// It builds a synthetic v3 attachment set carrying `modify_stat` rules and
// prints the folded stat overlay plus the list of deferred (not-yet-built)
// rules. This is how each rule-kind slice is verified before any debug panel
// or call-site flip exists — the resolver is inert in the app (the old engine
// stays authoritative until Phase 3.11), so this script is the only thing
// exercising it. NOT part of the app build.
//
// ignore_for_file: avoid_print

import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/services/template_rules/template_rule_resolver.dart';

const _ts = '2026-01-01T00:00:00.000Z';

FieldSchema _field(
  String categoryId,
  String key, {
  required int order,
  List<Map<String, dynamic>>? rules,
}) =>
    FieldSchema(
      fieldId: 'fld-$categoryId-$key',
      categoryId: categoryId,
      fieldKey: key,
      label: key,
      fieldType: FieldType.integer,
      orderIndex: order,
      rules: rules,
      createdAt: _ts,
      updatedAt: _ts,
    );

EntityCategorySchema _category(
  String slug,
  List<FieldSchema> fields,
) =>
    EntityCategorySchema(
      categoryId: 'cat-$slug',
      schemaId: 'schema-test',
      name: slug,
      slug: slug,
      fields: fields,
      createdAt: _ts,
      updatedAt: _ts,
    );

void main() {
  // A "Defender" species: always-on +1 AC.
  final species = ResolverAttachment(
    entityId: 'species-defender',
    category: _category('species', [
      _field('species', 'ac_bonus', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_granted',
          'target': 'ac',
          'value': {'kind': 'fixed', 'value': 1},
        },
      ]),
    ]),
  );

  // A shield: +2 AC only while equipped (bare-number value shorthand).
  final shield = ResolverAttachment(
    entityId: 'item-shield',
    isEquipped: true,
    category: _category('item', [
      _field('item', 'shield_ac', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_equipped',
          'target': 'ac',
          'value': 2,
        },
      ]),
    ]),
  );

  // An UNEQUIPPED plate armor: its +6 AC must NOT apply.
  final plate = ResolverAttachment(
    entityId: 'item-plate',
    isEquipped: false,
    category: _category('item', [
      _field('item', 'plate_ac', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_equipped',
          'target': 'ac',
          'value': 6,
        },
      ]),
    ]),
  );

  // A barbarian: +10 speed at level 5 (level_up gate), and a fast-movement
  // feature gated at level 11 that must NOT apply at gateLevel 5.
  final barbarian = ResolverAttachment(
    entityId: 'class-barbarian',
    category: _category('class', [
      _field('class', 'fast_movement', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'level_up',
          'trigger_args': {'at_level': 5},
          'target': 'speed',
          'value': {'kind': 'fixed', 'value': 10},
        },
      ]),
      _field('class', 'swift_movement', order: 1, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'level_up',
          'trigger_args': {'at_level': 11},
          'target': 'speed',
          'value': {'kind': 'fixed', 'value': 5},
        },
      ]),
    ]),
  );

  // A feat carrying a not-yet-built kind + a formula value source — both must
  // land in `deferred`, never silently change a stat.
  final feat = ResolverAttachment(
    entityId: 'feat-tough',
    category: _category('feat', [
      _field('feat', 'hp_per_level', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_granted',
          'target': 'max_hp',
          'value': {'kind': 'formula', 'expr': '2 * level'},
        },
      ]),
      _field('feat', 'grant_resistance', order: 1, rules: [
        {
          'kind': 'grant_refs',
          'trigger': 'when_granted',
          'target': 'resistances',
        },
      ]),
    ]),
  );

  const resolver = TemplateRuleResolver();
  final result = resolver.resolve(
    [species, shield, plate, barbarian, feat],
    gateLevel: 5,
  );

  print('=== TemplateRuleResolver shadow harness (gateLevel: 5) ===\n');
  print('Stat overlay (expected: ac +3, speed +10):');
  if (result.statDeltas.isEmpty) {
    print('  (none)');
  } else {
    final keys = result.statDeltas.keys.toList()..sort();
    for (final k in keys) {
      final v = result.statDeltas[k]!;
      print('  $k: ${v >= 0 ? '+' : ''}$v');
    }
  }

  print('\nDeferred (not implemented this slice) — expected 2 '
      '(formula value source, grant_refs kind):');
  if (result.deferred.isEmpty) {
    print('  (none)');
  } else {
    for (final skip in result.deferred) {
      print('  - $skip');
    }
  }

  // Self-checks so the harness fails loudly if a future edit breaks the slice.
  final ac = result.delta('ac');
  final speed = result.delta('speed');
  final ok = ac == 3 && speed == 10 && result.deferred.length == 2;
  print('\nResult: ${ok ? 'PASS' : 'FAIL'} '
      '(ac=$ac expected 3, speed=$speed expected 10, '
      'deferred=${result.deferred.length} expected 2)');
}
