import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_property.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/weapon_property_flag.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<WeaponProperty> props;

  setUpAll(() {
    final file = File('assets/packages/srd_core/weapon_properties.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    props = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return weaponPropertyFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 10 SRD weapon properties parse', () {
    expect(props, hasLength(10));
  });

  test('ids namespaced + unique', () {
    for (final p in props) {
      expect(p.id, startsWith('srd:'));
    }
    final ids = props.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB 10-property set', () {
    final ids = props.map((p) => p.id).toSet();
    expect(ids, {
      'srd:ammunition',
      'srd:finesse',
      'srd:heavy',
      'srd:light',
      'srd:loading',
      'srd:range',
      'srd:reach',
      'srd:thrown',
      'srd:two_handed',
      'srd:versatile',
    });
  });

  test('each property carries its matching PropertyFlag', () {
    final expected = {
      'srd:ammunition': PropertyFlag.ammunition,
      'srd:finesse': PropertyFlag.finesse,
      'srd:heavy': PropertyFlag.heavy,
      'srd:light': PropertyFlag.light,
      'srd:loading': PropertyFlag.loading,
      'srd:range': PropertyFlag.range,
      'srd:reach': PropertyFlag.reach,
      'srd:thrown': PropertyFlag.thrown,
      'srd:two_handed': PropertyFlag.twoHanded,
      'srd:versatile': PropertyFlag.versatile,
    };
    for (final p in props) {
      expect(p.flags, contains(expected[p.id]),
          reason: '${p.id} missing expected flag ${expected[p.id]}');
    }
  });

  test('all have non-empty descriptions', () {
    for (final p in props) {
      expect(p.description, isNotNull, reason: '${p.id} missing description');
      expect(p.description, isNotEmpty, reason: '${p.id} empty description');
    }
  });

  test('reach description mentions 5 feet', () {
    final r = props.firstWhere((p) => p.id == 'srd:reach');
    expect(r.description, contains('5 feet'));
  });

  test('two_handed uses twoHanded camelCase flag', () {
    final th = props.firstWhere((p) => p.id == 'srd:two_handed');
    expect(th.flags, {PropertyFlag.twoHanded});
  });
}
