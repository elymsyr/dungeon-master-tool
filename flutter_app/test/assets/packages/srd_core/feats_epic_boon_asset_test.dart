import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/feat.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/feat_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Feat> feats;

  setUpAll(() {
    final file = File('assets/packages/srd_core/feats_epic_boon.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    feats = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return featFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 3 Epic Boon feat samples parse', () {
    expect(feats, hasLength(3));
  });

  test('ids namespaced + unique', () {
    for (final f in feats) {
      expect(f.id, startsWith('srd:'));
    }
    expect(feats.map((f) => f.id).toSet().length, feats.length);
  });

  test('every feat is category=epicBoon with Level 19+ prereq', () {
    for (final f in feats) {
      expect(f.category, FeatCategory.epicBoon);
      expect(f.prerequisite, contains('Level 19'));
      expect(f.description, isNotEmpty);
    }
  });

  test('effects-empty placeholder invariant', () {
    for (final f in feats) {
      expect(f.effects, isEmpty);
    }
  });
}
