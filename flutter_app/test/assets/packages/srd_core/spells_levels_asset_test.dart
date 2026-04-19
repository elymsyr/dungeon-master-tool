import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell.dart';
import 'package:dungeon_master_tool/domain/dnd5e/spell/spell_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';

const _validSchools = {
  'srd:abjuration',
  'srd:conjuration',
  'srd:divination',
  'srd:enchantment',
  'srd:evocation',
  'srd:illusion',
  'srd:necromancy',
  'srd:transmutation',
};

const _validClasses = {
  'srd:bard',
  'srd:cleric',
  'srd:druid',
  'srd:paladin',
  'srd:ranger',
  'srd:sorcerer',
  'srd:warlock',
  'srd:wizard',
};

List<Spell> _load(int level) {
  final file = File('assets/packages/srd_core/spells_$level.json');
  final raw = jsonDecode(file.readAsStringSync()) as List;
  return raw.map((e) {
    final m = (e as Map).cast<String, Object?>();
    final body = (m['body'] as Map).cast<String, Object?>();
    return spellFromEntry(CatalogEntry(
      id: 'srd:${m['id']}',
      name: m['name'] as String,
      bodyJson: jsonEncode(body),
    ));
  }).toList();
}

void main() {
  for (final level in [2, 3, 4, 5, 6, 7, 8, 9]) {
    group('spells_$level.json placeholder tranche', () {
      late List<Spell> spells;

      setUpAll(() {
        spells = _load(level);
      });

      test('parses non-empty', () {
        expect(spells, isNotEmpty);
      });

      test('every entry has level=$level', () {
        for (final s in spells) {
          expect(s.level.value, level, reason: '${s.id} wrong level');
          expect(s.isCantrip, isFalse);
        }
      });

      test('ids namespaced + unique', () {
        for (final s in spells) {
          expect(s.id, startsWith('srd:'));
        }
        expect(spells.map((s) => s.id).toSet().length, spells.length);
      });

      test('schoolId in 8 SRD schools', () {
        for (final s in spells) {
          expect(_validSchools, contains(s.schoolId),
              reason: '${s.id} unknown schoolId ${s.schoolId}');
        }
      });

      test('classListIds non-empty + all in valid class set', () {
        for (final s in spells) {
          expect(s.classListIds, isNotEmpty, reason: '${s.id} no classes');
          for (final c in s.classListIds) {
            expect(_validClasses, contains(c),
                reason: '${s.id} references unknown class $c');
          }
        }
      });

      test('every spell has non-empty description + components', () {
        for (final s in spells) {
          expect(s.description, isNotEmpty, reason: '${s.id} no description');
          expect(s.components, isNotEmpty, reason: '${s.id} no components');
        }
      });

      test('effects-empty placeholder invariant (DSL gaps)', () {
        for (final s in spells) {
          expect(s.effects, isEmpty,
              reason: '${s.id} should ship with empty effects');
        }
      });
    });
  }
}
