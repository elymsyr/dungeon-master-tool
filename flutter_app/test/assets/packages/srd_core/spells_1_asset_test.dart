import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_duration.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Spell> spells;

  setUpAll(() {
    final file = File('assets/packages/srd_core/spells_1.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    spells = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return spellFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 50 level-1 SRD spells parse', () {
    expect(spells, hasLength(50));
  });

  test('ids namespaced + unique', () {
    for (final s in spells) {
      expect(s.id, startsWith('srd:'));
    }
    final ids = spells.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB SRD level-1 set', () {
    final ids = spells.map((s) => s.id).toSet();
    expect(ids, {
      'srd:alarm',
      'srd:animal_friendship',
      'srd:bane',
      'srd:bless',
      'srd:burning_hands',
      'srd:charm_person',
      'srd:color_spray',
      'srd:command',
      'srd:comprehend_languages',
      'srd:create_or_destroy_water',
      'srd:cure_wounds',
      'srd:detect_evil_and_good',
      'srd:detect_magic',
      'srd:detect_poison_and_disease',
      'srd:disguise_self',
      'srd:divine_favor',
      'srd:entangle',
      'srd:expeditious_retreat',
      'srd:faerie_fire',
      'srd:false_life',
      'srd:feather_fall',
      'srd:find_familiar',
      'srd:fog_cloud',
      'srd:goodberry',
      'srd:grease',
      'srd:guiding_bolt',
      'srd:healing_word',
      'srd:hellish_rebuke',
      'srd:heroism',
      'srd:hunters_mark',
      'srd:identify',
      'srd:inflict_wounds',
      'srd:jump',
      'srd:longstrider',
      'srd:mage_armor',
      'srd:magic_missile',
      'srd:protection_from_evil_and_good',
      'srd:purify_food_and_drink',
      'srd:ray_of_sickness',
      'srd:sanctuary',
      'srd:shield',
      'srd:shield_of_faith',
      'srd:silent_image',
      'srd:sleep',
      'srd:speak_with_animals',
      'srd:hideous_laughter',
      'srd:thunderwave',
      'srd:unseen_servant',
      'srd:witch_bolt',
      'srd:chromatic_orb',
    });
  });

  test('every entry is level 1', () {
    for (final s in spells) {
      expect(s.level.value, 1, reason: '${s.id} should be level 1');
      expect(s.isCantrip, isFalse);
    }
  });

  test('every spell has a schoolId in the 8 SRD schools', () {
    const valid = {
      'srd:abjuration',
      'srd:conjuration',
      'srd:divination',
      'srd:enchantment',
      'srd:evocation',
      'srd:illusion',
      'srd:necromancy',
      'srd:transmutation',
    };
    for (final s in spells) {
      expect(valid, contains(s.schoolId),
          reason: '${s.id} has unknown schoolId ${s.schoolId}');
    }
  });

  test('every spell has non-empty description', () {
    for (final s in spells) {
      expect(s.description, isNotEmpty, reason: '${s.id} missing description');
    }
  });

  test('every classListIds target is namespaced + in valid class set', () {
    const validClasses = {
      'srd:bard',
      'srd:cleric',
      'srd:druid',
      'srd:paladin',
      'srd:ranger',
      'srd:sorcerer',
      'srd:warlock',
      'srd:wizard',
    };
    for (final s in spells) {
      expect(s.classListIds, isNotEmpty,
          reason: '${s.id} should name at least one class list');
      for (final c in s.classListIds) {
        expect(c, startsWith('srd:'),
            reason: '${s.id} class ref $c missing namespace');
        expect(validClasses, contains(c),
            reason: '${s.id} references unknown class $c');
      }
    }
  });

  test('every spell ships effects-empty (DSL lacks direct spell primitives)',
      () {
    for (final s in spells) {
      expect(s.effects, isEmpty, reason: '${s.id} should have no effects yet');
    }
  });

  test('ritual spells match canonical SRD ritual subset', () {
    const expectedRituals = {
      'srd:alarm',
      'srd:comprehend_languages',
      'srd:detect_magic',
      'srd:detect_poison_and_disease',
      'srd:find_familiar',
      'srd:identify',
      'srd:purify_food_and_drink',
      'srd:speak_with_animals',
      'srd:unseen_servant',
    };
    final actualRituals =
        spells.where((s) => s.ritual).map((s) => s.id).toSet();
    expect(actualRituals, expectedRituals);
  });

  test('concentration-flagged durations match canonical SRD concentration subset',
      () {
    final concentrationIds = <String>{};
    for (final s in spells) {
      final d = s.duration;
      final isConc = switch (d) {
        SpellRounds(:final concentration) => concentration,
        SpellMinutes(:final concentration) => concentration,
        SpellHours(:final concentration) => concentration,
        _ => false,
      };
      if (isConc) concentrationIds.add(s.id);
    }
    expect(concentrationIds, {
      'srd:bane',
      'srd:bless',
      'srd:detect_evil_and_good',
      'srd:detect_magic',
      'srd:detect_poison_and_disease',
      'srd:divine_favor',
      'srd:entangle',
      'srd:expeditious_retreat',
      'srd:faerie_fire',
      'srd:fog_cloud',
      'srd:heroism',
      'srd:hideous_laughter',
      'srd:hunters_mark',
      'srd:protection_from_evil_and_good',
      'srd:shield_of_faith',
      'srd:silent_image',
      'srd:sleep',
      'srd:witch_bolt',
    });
  });

  test('every spell has at least one component', () {
    for (final s in spells) {
      expect(s.components, isNotEmpty, reason: '${s.id} missing components');
    }
  });
}
