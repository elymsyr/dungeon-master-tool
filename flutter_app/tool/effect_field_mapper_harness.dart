// Dev harness for the per-kind effect → v3 data-field mapper
// (`lib/domain/services/template_migration/effect_field_mapper.dart`;
// roadmap PR-3.0 slice 4 / content-convert §6).
//
// Run from the Flutter project root (`flutter_app/`):
//
//     dart run tool/effect_field_mapper_harness.dart
//
// It exercises the pure mapper (no dart:io) and asserts:
//   * coverage — every `parametricEffectKinds` entry (the closed set the
//     disposition classifier `mapped`-tags) has a canonical target field and
//     produces ≥1 write; the `effectTargetFields` key set equals that set;
//   * the canonical row/scalar shapes per representative kind;
//   * accumulation — repeated scalar bonuses sum; repeated list grants append;
//   * a non-parametric / null row produces no write.
//
// Verification gate for the slice; NOT part of the app build.
//
// ignore_for_file: avoid_print
library;

import 'package:dungeon_master_tool/domain/services/template_migration/description_generator.dart'
    show parametricEffectKinds;
import 'package:dungeon_master_tool/domain/services/template_migration/effect_field_mapper.dart';

int _checks = 0;
int _failures = 0;

void expect(String name, bool ok) {
  _checks++;
  if (!ok) _failures++;
  print('${ok ? 'PASS' : 'FAIL'}  $name');
}

void main() {
  _coverage();
  _shapes();
  _accumulation();
  _noWrites();

  print('');
  print(_failures == 0
      ? 'Overall: PASS ($_checks checks)'
      : 'Overall: FAIL ($_failures of $_checks checks failed)');
}

// ── 1. Coverage: every parametric kind maps to its canonical field ──────────

void _coverage() {
  print('— Coverage —');
  expect('effectTargetFields keys == parametricEffectKinds',
      effectTargetFields.keys.toSet().difference(parametricEffectKinds).isEmpty &&
          parametricEffectKinds.difference(effectTargetFields.keys.toSet()).isEmpty);

  var allMapped = true;
  var allTargeted = true;
  for (final kind in parametricEffectKinds) {
    final writes = mapEffectToFields(<String, dynamic>{'kind': kind});
    if (writes.isEmpty) {
      allMapped = false;
      print('  (gap) $kind produced no write');
      continue;
    }
    if (writes.first.fieldKey != effectTargetFields[kind]) {
      allTargeted = false;
      print('  (mismatch) $kind → ${writes.first.fieldKey} '
          '(expected ${effectTargetFields[kind]})');
    }
  }
  expect('every parametric kind produces ≥1 write', allMapped);
  expect('every primary write targets the canonical field', allTargeted);
}

// ── 2. Canonical shapes per representative kind ─────────────────────────────

void _shapes() {
  print('');
  print('— Shapes —');

  final asi = mapEffectToFields(
      <String, dynamic>{'kind': 'ability_score_bonus', 'ability': 'STR', 'value': 2});
  expect('ability_score_bonus → ability_bonuses appendRow',
      asi.single.fieldKey == 'ability_bonuses' && asi.single.mode == FieldWriteMode.appendRow);
  expect('ability_score_bonus row {ability:str, amount:2}',
      _eq(asi.single.value, {'ability': 'str', 'amount': 2}));

  final ac = mapEffectToFields(<String, dynamic>{'kind': 'ac_bonus', 'value': 1});
  expect('ac_bonus → ac_bonus addScalar 1',
      ac.single.fieldKey == 'ac_bonus' &&
          ac.single.mode == FieldWriteMode.addScalar &&
          ac.single.value == 1);

  final res = mapEffectToFields(
      <String, dynamic>{'kind': 'damage_resistance', 'value': 'fire'});
  expect('damage_resistance → damage_resistances {damage_type:fire}',
      res.single.fieldKey == 'damage_resistances' &&
          _eq(res.single.value, {'damage_type': 'fire'}));

  final sense = mapEffectToFields(<String, dynamic>{
    'kind': 'sense_grant',
    'sense': 'darkvision',
    'range_ft': 60,
  });
  expect('sense_grant → granted_senses {sense:darkvision, range_ft:60}',
      _eq(sense.single.value, {'sense': 'darkvision', 'range_ft': 60}));

  final truesight =
      mapEffectToFields(<String, dynamic>{'kind': 'truesight_grant', 'range': 120});
  expect('truesight_grant → granted_senses sense:truesight',
      sense.single.fieldKey == 'granted_senses' &&
          _eq(truesight.single.value, {'sense': 'truesight', 'range_ft': 120}));

  final bonusAction = mapEffectToFields(
      <String, dynamic>{'kind': 'granted_bonus_action_grant', 'name': 'Cunning Action'});
  expect('granted_bonus_action_grant → granted_actions action_type:bonus_action',
      bonusAction.single.fieldKey == 'granted_actions' &&
          _eq(bonusAction.single.value,
              {'action_type': 'bonus_action', 'action': 'Cunning Action'}));

  final formula = mapEffectToFields(<String, dynamic>{
    'kind': 'unarmored_ac_formula',
    'value': '10 + dex_mod + con_mod',
  });
  expect('unarmored_ac_formula → setScalar formula',
      formula.single.fieldKey == 'unarmored_ac_formula' &&
          formula.single.mode == FieldWriteMode.setScalar &&
          formula.single.value == '10 + dex_mod + con_mod');

  final classLevel = mapEffectToFields(<String, dynamic>{
    'kind': 'class_level_grant',
    'target_ref': {'name': 'Fighter'},
    'value': 1,
  });
  expect('class_level_grant → granted_class_levels {class, levels:1}',
      classLevel.single.fieldKey == 'granted_class_levels' &&
          _eq(classLevel.single.value, {
            'class': {'name': 'Fighter'},
            'levels': 1,
          }));
}

// ── 3. Accumulation via applyEffectWrites ───────────────────────────────────

void _accumulation() {
  print('');
  print('— Accumulation —');
  final attrs = <String, dynamic>{};

  // Two +1 AC features sum to ac_bonus 2.
  applyEffectWrites(attrs, mapEffectToFields(<String, dynamic>{'kind': 'ac_bonus', 'value': 1}));
  applyEffectWrites(attrs, mapEffectToFields(<String, dynamic>{'kind': 'ac_bonus', 'value': 1}));
  expect('ac_bonus sums to 2', attrs['ac_bonus'] == 2);

  // Two ability grants append two rows.
  applyEffectWrites(attrs,
      mapEffectToFields(<String, dynamic>{'kind': 'ability_score_bonus', 'ability': 'str', 'value': 1}));
  applyEffectWrites(attrs,
      mapEffectToFields(<String, dynamic>{'kind': 'ability_score_bonus', 'ability': 'dex', 'value': 1}));
  final bonuses = attrs['ability_bonuses'];
  expect('ability_bonuses appended two rows',
      bonuses is List && bonuses.length == 2);
  expect('ability_bonuses rows correct',
      bonuses is List &&
          _eq(bonuses[0], {'ability': 'str', 'amount': 1}) &&
          _eq(bonuses[1], {'ability': 'dex', 'amount': 1}));

  // Pre-existing scalar value is added onto, not clobbered.
  final seeded = <String, dynamic>{'speed_bonus': 5};
  applyEffectWrites(seeded, mapEffectToFields(<String, dynamic>{'kind': 'speed_bonus', 'value': 10}));
  expect('speed_bonus adds onto existing (5 + 10 = 15)', seeded['speed_bonus'] == 15);
}

// ── 4. Non-parametric / null rows write nothing ─────────────────────────────

void _noWrites() {
  print('');
  print('— No-write rows —');
  expect('null row → no writes', mapEffectToFields(null).isEmpty);
  expect('empty row → no writes', mapEffectToFields(<String, dynamic>{}).isEmpty);
  expect('out-of-scope combat kind → no writes',
      mapEffectToFields(<String, dynamic>{'kind': 'reroll_on_falling'}).isEmpty);
  expect('unknown kind → no writes',
      mapEffectToFields(<String, dynamic>{'kind': 'phase_of_moon'}).isEmpty);
}

// ── helpers ─────────────────────────────────────────────────────────────────

bool _eq(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_eq(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_eq(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
