import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/spell_school.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<SpellSchool> schools;

  setUpAll(() {
    final file = File('assets/packages/srd_core/spell_schools.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    schools = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return spellSchoolFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 8 SRD spell schools parse', () {
    expect(schools, hasLength(8));
  });

  test('ids namespaced + unique', () {
    for (final s in schools) {
      expect(s.id, startsWith('srd:'));
    }
    final ids = schools.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical SRD 8-school set', () {
    final ids = schools.map((s) => s.id).toSet();
    expect(ids, {
      'srd:abjuration',
      'srd:conjuration',
      'srd:divination',
      'srd:enchantment',
      'srd:evocation',
      'srd:illusion',
      'srd:necromancy',
      'srd:transmutation',
    });
  });

  test('all have valid #RRGGBB color', () {
    final hex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    for (final s in schools) {
      expect(s.color, isNotNull, reason: '${s.id} missing color');
      expect(hex.hasMatch(s.color!), isTrue,
          reason: '${s.id} color ${s.color} not #RRGGBB');
    }
  });

  test('colors are distinct per school', () {
    final colors = schools.map((s) => s.color).toList();
    expect(colors.toSet().length, colors.length);
  });
}
