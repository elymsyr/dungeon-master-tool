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
import 'package:dungeon_master_tool/domain/services/template_rules/aspect_context.dart';
import 'package:dungeon_master_tool/domain/services/template_rules/template_rule_resolver.dart';

const _ts = '2026-01-01T00:00:00.000Z';

FieldSchema _field(
  String categoryId,
  String key, {
  required int order,
  FieldType type = FieldType.integer,
  Map<String, dynamic>? typeConfig,
  List<Map<String, dynamic>>? rules,
}) =>
    FieldSchema(
      fieldId: 'fld-$categoryId-$key',
      categoryId: categoryId,
      fieldKey: key,
      label: key,
      fieldType: type,
      orderIndex: order,
      typeConfig: typeConfig,
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

  // A "Belt of Giant Strength": +N to STR where N is the belt's OWN stored
  // field value (the `field` value source, slice 2). `value: {kind: field}`
  // with no explicit "field" defaults to the rule's own field key (`str_bonus`),
  // whose stored value is 4 → +4 str.
  final belt = ResolverAttachment(
    entityId: 'item-belt',
    isEquipped: true,
    values: const {'str_bonus': 4},
    category: _category('item', [
      _field('item', 'str_bonus', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_equipped',
          'target': 'str',
          'value': {'kind': 'field'},
        },
      ]),
    ]),
  );

  // A "Cloak of Protection": +ac equal to a DIFFERENT stored field (explicit
  // "field" key → reads `attachment.values['protection']` = 1).
  final cloak = ResolverAttachment(
    entityId: 'item-cloak',
    isEquipped: true,
    values: const {'protection': 1},
    category: _category('item', [
      _field('item', 'cloak_ac', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_equipped',
          'target': 'ac',
          'value': {'kind': 'field', 'field': 'protection'},
        },
      ]),
    ]),
  );

  // A "Tough"-style feat: a `formula` value source (`2 * level`, slice 3) that
  // now resolves against the aspect context (level 5 → +10 max_hp), plus a
  // not-yet-built `grant_refs` kind that must still land in `deferred`.
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

  // A "Monk" exercising the richer §4.3 formula grammar (slice 3):
  //   * Unarmored Defense — `10 + dex_mod + con_mod` = 10 + 2 + (-1) = 11.
  //   * Proficiency bonus — `table(level, "1:2,5:3,9:4,13:5,17:6")` at level 5
  //     → 3 (the highest threshold <= 5), exercising the step-table function.
  final monk = ResolverAttachment(
    entityId: 'class-monk',
    category: _category('monk', [
      _field('monk', 'unarmored_defense', order: 0, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_granted',
          'target': 'unarmored_ac',
          'value': {'kind': 'formula', 'expr': '10 + dex_mod + con_mod'},
        },
      ]),
      _field('monk', 'prof', order: 1, rules: [
        {
          'kind': 'modify_stat',
          'trigger': 'when_granted',
          'target': 'prof_check',
          'value': {
            'kind': 'formula',
            'expr': 'table(level, "1:2,5:3,9:4,13:5,17:6")',
          },
        },
      ]),
    ]),
  );

  // ── Aspect context (slice 2): built from a synthetic PC card. ────────────
  final pcCategory = _category('player-character', [
    _field('player-character', 'abilities',
        order: 0,
        type: FieldType.abilityScoreTable,
        typeConfig: {
          'publishAspects': true,
          'modifierBase': 10,
          'modifierStep': 2,
          'columns': [
            {'key': 'str', 'label': 'STR'},
            {'key': 'dex', 'label': 'DEX'},
            {'key': 'con', 'label': 'CON'},
          ],
        }),
    _field('player-character', 'combat',
        order: 1, type: FieldType.combatStatsTable),
    _field('player-character', 'prof_bonus',
        order: 2,
        type: FieldType.integer,
        typeConfig: {'publishAspect': 'prof_bonus'}),
  ]);
  final aspects = AspectContext.fromPcCard(
    pcCategory: pcCategory,
    values: const {
      'abilities': {'str': 16, 'dex': 14, 'con': 9},
      'combat': {'level': 5, 'ac': 17, 'max_hp': 42, 'hp': 30},
      'prof_bonus': 3,
    },
    classLevelsBySlug: const {'barbarian': 5},
  );

  print('=== AspectContext (slice 2) ===');
  final aspectKeys = aspects.aspects.keys.toList()..sort();
  for (final k in aspectKeys) {
    print('  $k = ${aspects.value(k)}');
  }
  // con 9 exercises the floor() rule: floor((9-10)/2) = -1 (NOT 0 from `~/`).
  final aspectsOk = aspects.value('str') == 16 &&
      aspects.value('str_mod') == 3 &&
      aspects.value('dex_mod') == 2 &&
      aspects.value('con_mod') == -1 &&
      aspects.value('level') == 5 &&
      aspects.value('ac') == 17 &&
      aspects.value('max_hp') == 42 &&
      aspects.value('prof_bonus') == 3 &&
      aspects.value('class_level(barbarian)') == 5 &&
      !aspects.has('hp'); // combatStatsTable publishes only level/ac/max_hp
  print('Aspect self-check: ${aspectsOk ? 'PASS' : 'FAIL'}\n');

  // ── Stat fold ────────────────────────────────────────────────────────────
  const resolver = TemplateRuleResolver();
  final result = resolver.resolve(
    [species, shield, plate, barbarian, belt, cloak, feat, monk],
    gateLevel: 5,
    aspects: aspects,
  );

  print('=== TemplateRuleResolver shadow harness (gateLevel: 5) ===\n');
  print('Stat overlay (expected: ac +4, speed +10, str +4, max_hp +10, '
      'unarmored_ac +11, prof_check +3):');
  if (result.statDeltas.isEmpty) {
    print('  (none)');
  } else {
    final keys = result.statDeltas.keys.toList()..sort();
    for (final k in keys) {
      final v = result.statDeltas[k]!;
      print('  $k: ${v >= 0 ? '+' : ''}$v');
    }
  }

  print('\nDeferred (not implemented yet) — expected 1 '
      '(grant_refs kind; the formula value source now resolves):');
  if (result.deferred.isEmpty) {
    print('  (none)');
  } else {
    for (final skip in result.deferred) {
      print('  - $skip');
    }
  }

  // Self-checks so the harness fails loudly if a future edit breaks the slice.
  final ac = result.delta('ac'); // species 1 + shield 2 + cloak(field) 1 = 4
  final speed = result.delta('speed'); // barbarian L5 fast movement = 10
  final str = result.delta('str'); // belt own-field value = 4
  final maxHp = result.delta('max_hp'); // feat formula 2 * level(5) = 10
  final unarmoredAc =
      result.delta('unarmored_ac'); // monk 10 + dex_mod(2) + con_mod(-1) = 11
  final profCheck =
      result.delta('prof_check'); // monk table(level=5,…) = 3
  final foldOk = ac == 4 &&
      speed == 10 &&
      str == 4 &&
      maxHp == 10 &&
      unarmoredAc == 11 &&
      profCheck == 3 &&
      result.deferred.length == 1;
  print('\nFold self-check: ${foldOk ? 'PASS' : 'FAIL'} '
      '(ac=$ac/4, speed=$speed/10, str=$str/4, max_hp=$maxHp/10, '
      'unarmored_ac=$unarmoredAc/11, prof_check=$profCheck/3, '
      'deferred=${result.deferred.length}/1)');

  print('\nOverall: ${aspectsOk && foldOk ? 'PASS' : 'FAIL'}');
}
