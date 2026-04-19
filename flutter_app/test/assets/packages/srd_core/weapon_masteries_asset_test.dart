import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_mastery.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<WeaponMastery> masteries;

  setUpAll(() {
    final file = File('assets/packages/srd_core/weapon_masteries.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    masteries = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return weaponMasteryFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 8 SRD weapon masteries parse', () {
    expect(masteries, hasLength(8));
  });

  test('ids namespaced + unique', () {
    for (final m in masteries) {
      expect(m.id, startsWith('srd:'));
    }
    final ids = masteries.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB 8-mastery set', () {
    final ids = masteries.map((m) => m.id).toSet();
    expect(ids, {
      'srd:cleave',
      'srd:graze',
      'srd:nick',
      'srd:push',
      'srd:sap',
      'srd:slow',
      'srd:topple',
      'srd:vex',
    });
  });

  test('all have non-empty description', () {
    for (final m in masteries) {
      expect(m.description, isNotEmpty, reason: '${m.id} missing description');
    }
  });

  test('Topple references Constitution save', () {
    final t = masteries.firstWhere((m) => m.id == 'srd:topple');
    expect(t.description, contains('Constitution'));
  });

  test('Push distance is 10 feet', () {
    final p = masteries.firstWhere((m) => m.id == 'srd:push');
    expect(p.description, contains('10 feet'));
  });
}
