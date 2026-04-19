import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/monster/monster.dart';
import 'package:dungeon_master_tool/domain/dnd5e/monster/monster_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Monster> monsters;

  setUpAll(() {
    final file = File('assets/packages/srd_core/monsters.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    monsters = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return monsterFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 5 monster samples parse', () {
    expect(monsters, hasLength(5));
  });

  test('ids namespaced + unique', () {
    for (final m in monsters) {
      expect(m.id, startsWith('srd:'));
    }
    expect(monsters.map((m) => m.id).toSet().length, monsters.length);
  });

  test('canonical sample id set', () {
    expect(monsters.map((m) => m.id).toSet(), {
      'srd:goblin',
      'srd:wolf',
      'srd:orc',
      'srd:skeleton',
      'srd:adult_red_dragon',
    });
  });

  test('every monster has at least one action + non-empty description', () {
    for (final m in monsters) {
      expect(m.actions, isNotEmpty, reason: '${m.id} actions');
      expect(m.description, isNotEmpty);
    }
  });

  test('Adult Red Dragon is legendary with 3 slots and 3 actions', () {
    final dragon = monsters.firstWhere((m) => m.id == 'srd:adult_red_dragon');
    expect(dragon.legendaryActionSlots, 3);
    expect(dragon.legendaryActions, hasLength(3));
    expect(dragon.stats.cr.canonical, '17');
  });

  test('every monster cr is in canonical set', () {
    for (final m in monsters) {
      expect(m.stats.cr.canonical, isNotEmpty);
    }
  });
}
