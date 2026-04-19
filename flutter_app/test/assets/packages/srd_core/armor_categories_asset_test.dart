import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/armor_category.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<ArmorCategory> categories;

  setUpAll(() {
    final file = File('assets/packages/srd_core/armor_categories.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    categories = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return armorCategoryFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 4 SRD armor categories parse', () {
    expect(categories, hasLength(4));
  });

  test('ids namespaced + unique', () {
    for (final c in categories) {
      expect(c.id, startsWith('srd:'));
    }
    final ids = categories.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical SRD set Light/Medium/Heavy/Shield', () {
    final ids = categories.map((c) => c.id).toSet();
    expect(ids, {'srd:light', 'srd:medium', 'srd:heavy', 'srd:shield'});
  });

  test('Light: no Dex cap, no stealth disadvantage', () {
    final l = categories.firstWhere((c) => c.id == 'srd:light');
    expect(l.maxDexCap, isNull);
    expect(l.stealthDisadvantage, isFalse);
  });

  test('Medium: Dex cap +2, no stealth disadvantage at category level', () {
    final m = categories.firstWhere((c) => c.id == 'srd:medium');
    expect(m.maxDexCap, 2);
    expect(m.stealthDisadvantage, isFalse);
  });

  test('Heavy: Dex does not contribute, stealth disadvantage', () {
    final h = categories.firstWhere((c) => c.id == 'srd:heavy');
    expect(h.maxDexCap, 0);
    expect(h.stealthDisadvantage, isTrue);
  });

  test('Shield: no Dex cap, no stealth disadvantage', () {
    final s = categories.firstWhere((c) => c.id == 'srd:shield');
    expect(s.maxDexCap, isNull);
    expect(s.stealthDisadvantage, isFalse);
  });
}
