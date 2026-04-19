import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/feat.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/feat_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Feat> feats;

  setUpAll(() {
    final file = File('assets/packages/srd_core/feats_fighting_style.json');
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

  test('all 4 Fighting Style feat samples parse', () {
    expect(feats, hasLength(4));
  });

  test('ids namespaced + unique', () {
    for (final f in feats) {
      expect(f.id, startsWith('srd:'));
    }
    expect(feats.map((f) => f.id).toSet().length, feats.length);
  });

  test('every feat is category=fightingStyle', () {
    for (final f in feats) {
      expect(f.category, FeatCategory.fightingStyle);
      expect(f.description, isNotEmpty);
    }
  });

  test('effects-empty placeholder invariant', () {
    for (final f in feats) {
      expect(f.effects, isEmpty);
    }
  });
}
