import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/condition.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the authoring-format SRD conditions asset parses through the
/// Tier 1 catalog codec after bodies are stringified (the build step's
/// transformation). Once `tool:build_srd_pkg` exists this test will load the
/// built monolith directly; until then it simulates the transform.
void main() {
  late List<Condition> conditions;

  setUpAll(() {
    final file = File('assets/packages/srd_core/conditions.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    conditions = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      final entry = CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      );
      return conditionFromEntry(entry);
    }).toList();
  });

  test('all 15 SRD conditions parse without error', () {
    expect(conditions, hasLength(15));
  });

  test('ids are namespaced under srd:', () {
    for (final c in conditions) {
      expect(c.id, startsWith('srd:'));
    }
  });

  test('ids unique', () {
    final ids = conditions.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every condition has non-empty description', () {
    for (final c in conditions) {
      expect(c.description.isNotEmpty, true, reason: '${c.id} missing description');
    }
  });

  test('Blinded: attacks-vs adv + own disadv', () {
    final c = conditions.firstWhere((c) => c.id == 'srd:blinded');
    final ci = c.effects.whereType<ConditionInteraction>().single;
    expect(ci.imposedAdvantageOnAttacksAgainst, true);
    expect(ci.attacksHaveDisadvantage, true);
  });

  test('Paralyzed: incapacitated + speed 0 + STR/DEX auto-fail + crit setup', () {
    final c = conditions.firstWhere((c) => c.id == 'srd:paralyzed');
    final ci = c.effects.whereType<ConditionInteraction>().single;
    expect(ci.incapacitated, true);
    expect(ci.speedZero, true);
    expect(ci.cannotTakeActions, true);
    expect(ci.cannotTakeReactions, true);
    expect(ci.imposedAdvantageOnAttacksAgainst, true);
    expect(ci.autoFailSavesOf, {Ability.strength, Ability.dexterity});
  });

  test('Restrained: composite ConditionInteraction + ModifySave DEX disadv', () {
    final c = conditions.firstWhere((c) => c.id == 'srd:restrained');
    expect(c.effects, hasLength(2));
    final ci = c.effects.whereType<ConditionInteraction>().single;
    expect(ci.speedZero, true);
    expect(ci.imposedAdvantageOnAttacksAgainst, true);
    expect(ci.attacksHaveDisadvantage, true);
    final ms = c.effects.whereType<ModifySave>().single;
    expect(ms.ability, Ability.dexterity);
  });

  test('Charmed / Deafened / Exhaustion: description-only, no effects', () {
    for (final id in ['srd:charmed', 'srd:deafened', 'srd:exhaustion']) {
      final c = conditions.firstWhere((cc) => cc.id == id);
      expect(c.effects, isEmpty, reason: id);
    }
  });

  test('Incapacitated: cannotTakeActions + cannotTakeReactions', () {
    final c = conditions.firstWhere((c) => c.id == 'srd:incapacitated');
    final ci = c.effects.whereType<ConditionInteraction>().single;
    expect(ci.incapacitated, true);
    expect(ci.cannotTakeActions, true);
    expect(ci.cannotTakeReactions, true);
  });

  test('Invisible: invisibleToSight', () {
    final c = conditions.firstWhere((c) => c.id == 'srd:invisible');
    final ci = c.effects.whereType<ConditionInteraction>().single;
    expect(ci.invisibleToSight, true);
  });

  test('Grappled: speed 0 + grappled flag', () {
    final c = conditions.firstWhere((c) => c.id == 'srd:grappled');
    final ci = c.effects.whereType<ConditionInteraction>().single;
    expect(ci.speedZero, true);
    expect(ci.grappled, true);
  });

  test('Stunned + Unconscious: STR+DEX auto-fail + incapacitated', () {
    for (final id in ['srd:stunned', 'srd:unconscious']) {
      final c = conditions.firstWhere((cc) => cc.id == id);
      final ci = c.effects.whereType<ConditionInteraction>().single;
      expect(ci.autoFailSavesOf, {Ability.strength, Ability.dexterity},
          reason: id);
      expect(ci.incapacitated, true, reason: id);
      expect(ci.speedZero, true, reason: id);
    }
  });

  test('Poisoned + Prone + Frightened: attacksHaveDisadvantage', () {
    for (final id in ['srd:poisoned', 'srd:prone', 'srd:frightened']) {
      final c = conditions.firstWhere((cc) => cc.id == id);
      final ci = c.effects.whereType<ConditionInteraction>().single;
      expect(ci.attacksHaveDisadvantage, true, reason: id);
    }
  });
}
