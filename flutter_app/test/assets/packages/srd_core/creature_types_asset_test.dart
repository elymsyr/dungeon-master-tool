import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/creature_type.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<CreatureType> types;

  setUpAll(() {
    final file = File('assets/packages/srd_core/creature_types.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    types = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return creatureTypeFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 14 SRD creature types parse', () {
    expect(types, hasLength(14));
  });

  test('ids namespaced + unique', () {
    for (final t in types) {
      expect(t.id, startsWith('srd:'));
    }
    final ids = types.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical SRD 14-type set', () {
    final ids = types.map((t) => t.id).toSet();
    expect(ids, {
      'srd:aberration',
      'srd:beast',
      'srd:celestial',
      'srd:construct',
      'srd:dragon',
      'srd:elemental',
      'srd:fey',
      'srd:fiend',
      'srd:giant',
      'srd:humanoid',
      'srd:monstrosity',
      'srd:ooze',
      'srd:plant',
      'srd:undead',
    });
  });

  test('names are Title Case', () {
    for (final t in types) {
      expect(t.name[0], t.name[0].toUpperCase(), reason: t.id);
    }
  });
}
