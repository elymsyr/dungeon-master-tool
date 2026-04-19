import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/rarity.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Rarity> rarities;

  setUpAll(() {
    final file = File('assets/packages/srd_core/rarities.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    rarities = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return rarityFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 6 SRD rarities parse', () {
    expect(rarities, hasLength(6));
  });

  test('ids namespaced + unique', () {
    for (final r in rarities) {
      expect(r.id, startsWith('srd:'));
    }
    final ids = rarities.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical SRD 6-rarity set', () {
    final ids = rarities.map((r) => r.id).toSet();
    expect(ids, {
      'srd:common',
      'srd:uncommon',
      'srd:rare',
      'srd:very_rare',
      'srd:legendary',
      'srd:artifact',
    });
  });

  test('sortOrder is 0..5 and monotonic in canonical order', () {
    final order = [
      'srd:common',
      'srd:uncommon',
      'srd:rare',
      'srd:very_rare',
      'srd:legendary',
      'srd:artifact',
    ];
    for (var i = 0; i < order.length; i++) {
      final r = rarities.firstWhere((r) => r.id == order[i]);
      expect(r.sortOrder, i);
    }
  });

  test('attunement tiers ascend: Common/Uncommon=1, Rare=5, VeryRare=11, Legendary=17', () {
    final by = {for (final r in rarities) r.id: r};
    expect(by['srd:common']!.attunementTierReq, 1);
    expect(by['srd:uncommon']!.attunementTierReq, 1);
    expect(by['srd:rare']!.attunementTierReq, 5);
    expect(by['srd:very_rare']!.attunementTierReq, 11);
    expect(by['srd:legendary']!.attunementTierReq, 17);
  });

  test('Artifact has no attunement tier (DM discretion)', () {
    final a = rarities.firstWhere((r) => r.id == 'srd:artifact');
    expect(a.attunementTierReq, isNull);
  });
}
