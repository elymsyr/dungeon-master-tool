import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Spell> cantrips;

  setUpAll(() {
    final file = File('assets/packages/srd_core/spells_cantrips.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    cantrips = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return spellFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 27 SRD cantrips parse', () {
    expect(cantrips, hasLength(27));
  });

  test('ids namespaced + unique', () {
    for (final s in cantrips) {
      expect(s.id, startsWith('srd:'));
    }
    final ids = cantrips.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB SRD cantrip set', () {
    final ids = cantrips.map((s) => s.id).toSet();
    expect(ids, {
      'srd:acid_splash',
      'srd:dancing_lights',
      'srd:druidcraft',
      'srd:eldritch_blast',
      'srd:fire_bolt',
      'srd:guidance',
      'srd:light',
      'srd:mage_hand',
      'srd:mending',
      'srd:message',
      'srd:minor_illusion',
      'srd:poison_spray',
      'srd:prestidigitation',
      'srd:produce_flame',
      'srd:ray_of_frost',
      'srd:resistance',
      'srd:sacred_flame',
      'srd:shillelagh',
      'srd:shocking_grasp',
      'srd:spare_the_dying',
      'srd:starry_wisp',
      'srd:thaumaturgy',
      'srd:thorn_whip',
      'srd:toll_the_dead',
      'srd:true_strike',
      'srd:vicious_mockery',
      'srd:word_of_radiance',
    });
  });

  test('every entry is level 0 (cantrip)', () {
    for (final s in cantrips) {
      expect(s.isCantrip, isTrue, reason: '${s.id} should be a cantrip');
      expect(s.level.value, 0);
    }
  });

  test('every cantrip has a schoolId in the 8 SRD schools', () {
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
    for (final s in cantrips) {
      expect(valid, contains(s.schoolId),
          reason: '${s.id} has unknown schoolId ${s.schoolId}');
    }
  });

  test('every cantrip has non-empty description', () {
    for (final s in cantrips) {
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
    for (final s in cantrips) {
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

  test('every cantrip ships effects-empty (DSL lacks direct spell primitives)',
      () {
    for (final s in cantrips) {
      expect(s.effects, isEmpty, reason: '${s.id} should have no effects yet');
    }
  });

  test('Magic Initiate tradition references (Cleric/Druid/Wizard) each have at least 2 cantrips',
      () {
    final byClass = <String, int>{};
    for (final s in cantrips) {
      for (final c in s.classListIds) {
        byClass[c] = (byClass[c] ?? 0) + 1;
      }
    }
    expect((byClass['srd:cleric'] ?? 0) >= 2, isTrue,
        reason: 'Magic Initiate (Cleric) needs >=2 cleric cantrips');
    expect((byClass['srd:druid'] ?? 0) >= 2, isTrue,
        reason: 'Magic Initiate (Druid) needs >=2 druid cantrips');
    expect((byClass['srd:wizard'] ?? 0) >= 2, isTrue,
        reason: 'Magic Initiate (Wizard) needs >=2 wizard cantrips');
  });

  test('no cantrip is a ritual (per 2024 PHB)', () {
    for (final s in cantrips) {
      expect(s.ritual, isFalse, reason: '${s.id} should not be a ritual');
    }
  });
}
