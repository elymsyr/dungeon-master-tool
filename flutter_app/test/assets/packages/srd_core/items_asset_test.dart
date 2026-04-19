import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/item/item.dart';
import 'package:dungeon_master_tool/domain/dnd5e/item/item_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Item> items;

  setUpAll(() {
    final file = File('assets/packages/srd_core/items.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    items = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return itemFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 8 item samples parse', () {
    expect(items, hasLength(8));
  });

  test('ids namespaced + unique', () {
    for (final i in items) {
      expect(i.id, startsWith('srd:'));
    }
    expect(items.map((i) => i.id).toSet().length, items.length);
  });

  test('every variant present at least once', () {
    final byType = <Type, int>{};
    for (final i in items) {
      byType[i.runtimeType] = (byType[i.runtimeType] ?? 0) + 1;
    }
    expect(byType[Weapon], greaterThanOrEqualTo(1));
    expect(byType[Armor], greaterThanOrEqualTo(1));
    expect(byType[Shield], greaterThanOrEqualTo(1));
    expect(byType[Gear], greaterThanOrEqualTo(1));
    expect(byType[Tool], greaterThanOrEqualTo(1));
    expect(byType[Ammunition], greaterThanOrEqualTo(1));
    expect(byType[MagicItem], greaterThanOrEqualTo(1));
  });

  test('every item references a srd: rarity', () {
    for (final i in items) {
      expect(i.rarityId, startsWith('srd:'));
    }
  });

  test('Longbow has range pair (150/600) and ranged type', () {
    final longbow = items.whereType<Weapon>().firstWhere((w) => w.id == 'srd:longbow');
    expect(longbow.type, WeaponType.ranged);
    expect(longbow.range?.normal, 150);
    expect(longbow.range?.long, 600);
  });

  test('Longsword +1 magic item references base srd:longsword', () {
    final mi = items.whereType<MagicItem>().firstWhere((m) => m.id == 'srd:longsword_plus_1');
    expect(mi.baseItemId, 'srd:longsword');
    expect(mi.requiresAttunement, isFalse);
  });
}
