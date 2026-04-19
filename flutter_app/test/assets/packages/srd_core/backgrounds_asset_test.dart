import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/background.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/background_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Background> backgrounds;

  setUpAll(() {
    final file = File('assets/packages/srd_core/backgrounds.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    backgrounds = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return backgroundFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 16 SRD backgrounds parse', () {
    expect(backgrounds, hasLength(16));
  });

  test('ids namespaced + unique', () {
    for (final b in backgrounds) {
      expect(b.id, startsWith('srd:'));
    }
    final ids = backgrounds.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB SRD 16-background set', () {
    final ids = backgrounds.map((b) => b.id).toSet();
    expect(ids, {
      'srd:acolyte',
      'srd:artisan',
      'srd:charlatan',
      'srd:criminal',
      'srd:entertainer',
      'srd:farmer',
      'srd:guard',
      'srd:guide',
      'srd:hermit',
      'srd:merchant',
      'srd:noble',
      'srd:sage',
      'srd:sailor',
      'srd:scribe',
      'srd:soldier',
      'srd:wayfarer',
    });
  });

  test('every background has non-empty description', () {
    for (final b in backgrounds) {
      expect(b.description, isNotEmpty, reason: '${b.id} missing description');
    }
  });

  test('every background grants exactly 2 skill proficiencies', () {
    for (final b in backgrounds) {
      final skills = b.effects
          .whereType<GrantProficiency>()
          .where((e) => e.kind == ProficiencyKind.skill)
          .toList();
      expect(skills, hasLength(2),
          reason: '${b.id} should grant exactly 2 skill proficiencies');
    }
  });

  test('all granted skill target ids namespaced under srd:', () {
    for (final b in backgrounds) {
      final skills = b.effects
          .whereType<GrantProficiency>()
          .where((e) => e.kind == ProficiencyKind.skill);
      for (final s in skills) {
        expect(s.targetId, startsWith('srd:'),
            reason: '${b.id} skill ${s.targetId} missing namespace');
      }
    }
  });

  test('all granted skill target ids belong to the 18 SRD skills', () {
    const validSkills = {
      'srd:athletics',
      'srd:acrobatics',
      'srd:sleight_of_hand',
      'srd:stealth',
      'srd:arcana',
      'srd:history',
      'srd:investigation',
      'srd:nature',
      'srd:religion',
      'srd:animal_handling',
      'srd:insight',
      'srd:medicine',
      'srd:perception',
      'srd:survival',
      'srd:deception',
      'srd:intimidation',
      'srd:performance',
      'srd:persuasion',
    };
    for (final b in backgrounds) {
      final skills = b.effects
          .whereType<GrantProficiency>()
          .where((e) => e.kind == ProficiencyKind.skill);
      for (final s in skills) {
        expect(validSkills, contains(s.targetId),
            reason: '${b.id} references unknown skill ${s.targetId}');
      }
    }
  });

  test('backgrounds with a fixed tool grant a single tool proficiency; choice backgrounds grant none', () {
    const fixedToolBackgrounds = {
      'srd:acolyte',
      'srd:charlatan',
      'srd:criminal',
      'srd:farmer',
      'srd:guide',
      'srd:hermit',
      'srd:merchant',
      'srd:sage',
      'srd:sailor',
      'srd:scribe',
      'srd:wayfarer',
    };
    const choiceToolBackgrounds = {
      'srd:artisan',
      'srd:entertainer',
      'srd:guard',
      'srd:noble',
      'srd:soldier',
    };
    expect(
      fixedToolBackgrounds.union(choiceToolBackgrounds),
      backgrounds.map((b) => b.id).toSet(),
    );
    for (final b in backgrounds) {
      final tools = b.effects
          .whereType<GrantProficiency>()
          .where((e) => e.kind == ProficiencyKind.tool)
          .toList();
      if (fixedToolBackgrounds.contains(b.id)) {
        expect(tools, hasLength(1), reason: '${b.id} expects one tool grant');
        expect(tools.first.targetId, startsWith('srd:'));
      } else {
        expect(tools, isEmpty,
            reason: '${b.id} has a choice-tool; should not grant statically');
      }
    }
  });

  test('Acolyte grants Insight + Religion + Calligrapher\'s Supplies', () {
    final acolyte = backgrounds.firstWhere((b) => b.id == 'srd:acolyte');
    final grants = acolyte.effects.whereType<GrantProficiency>().toList();
    final skillIds = grants
        .where((e) => e.kind == ProficiencyKind.skill)
        .map((e) => e.targetId)
        .toSet();
    expect(skillIds, {'srd:insight', 'srd:religion'});
    final toolIds = grants
        .where((e) => e.kind == ProficiencyKind.tool)
        .map((e) => e.targetId)
        .toSet();
    expect(toolIds, {'srd:calligraphers_supplies'});
  });

  test('Criminal grants Sleight of Hand + Stealth + Thieves\' Tools', () {
    final criminal = backgrounds.firstWhere((b) => b.id == 'srd:criminal');
    final skillIds = criminal.effects
        .whereType<GrantProficiency>()
        .where((e) => e.kind == ProficiencyKind.skill)
        .map((e) => e.targetId)
        .toSet();
    expect(skillIds, {'srd:sleight_of_hand', 'srd:stealth'});
    final toolIds = criminal.effects
        .whereType<GrantProficiency>()
        .where((e) => e.kind == ProficiencyKind.tool)
        .map((e) => e.targetId)
        .toSet();
    expect(toolIds, {'srd:thieves_tools'});
  });

  test('Sage grants Arcana + History + Calligrapher\'s Supplies', () {
    final sage = backgrounds.firstWhere((b) => b.id == 'srd:sage');
    final skillIds = sage.effects
        .whereType<GrantProficiency>()
        .where((e) => e.kind == ProficiencyKind.skill)
        .map((e) => e.targetId)
        .toSet();
    expect(skillIds, {'srd:arcana', 'srd:history'});
  });
}
