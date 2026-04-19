import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/subclass.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/subclass_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Subclass> subclasses;

  setUpAll(() {
    final file = File('assets/packages/srd_core/subclasses.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    subclasses = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return subclassFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 5 subclass samples parse', () {
    expect(subclasses, hasLength(5));
  });

  test('ids namespaced + unique', () {
    for (final s in subclasses) {
      expect(s.id, startsWith('srd:'));
    }
    expect(subclasses.map((s) => s.id).toSet().length, subclasses.length);
  });

  test('every subclass parents a srd: class id with non-empty description', () {
    for (final s in subclasses) {
      expect(s.parentClassId, startsWith('srd:'));
      expect(s.description, isNotEmpty);
    }
  });

  test('feature rows sorted by level + at least one row each', () {
    for (final s in subclasses) {
      expect(s.featureTable, isNotEmpty);
      final levels = s.featureTable.map((r) => r.level).toList();
      final sorted = [...levels]..sort();
      expect(levels, sorted, reason: '${s.id} rows out of order');
    }
  });

  test('parent class ids reference shipped sample classes', () {
    const validParents = {
      'srd:barbarian',
      'srd:cleric',
      'srd:fighter',
      'srd:rogue',
      'srd:wizard',
    };
    for (final s in subclasses) {
      expect(validParents, contains(s.parentClassId),
          reason: '${s.id} parent ${s.parentClassId} not in sample classes');
    }
  });
}
