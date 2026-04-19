import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/catalog/catalog_json_codecs.dart';
import 'package:dungeon_master_tool/domain/dnd5e/catalog/damage_type.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<DamageType> damageTypes;

  setUpAll(() {
    final file = File('assets/packages/srd_core/damage_types.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    damageTypes = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return damageTypeFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 13 SRD damage types parse', () {
    expect(damageTypes, hasLength(13));
  });

  test('ids namespaced + unique', () {
    for (final d in damageTypes) {
      expect(d.id, startsWith('srd:'));
    }
    final ids = damageTypes.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('physical types flagged (bludgeoning, piercing, slashing)', () {
    final physical = damageTypes.where((d) => d.physical).map((d) => d.id).toSet();
    expect(physical, {'srd:bludgeoning', 'srd:piercing', 'srd:slashing'});
  });

  test('non-physical types default to physical=false', () {
    for (final id in [
      'srd:acid',
      'srd:cold',
      'srd:fire',
      'srd:force',
      'srd:lightning',
      'srd:necrotic',
      'srd:poison',
      'srd:psychic',
      'srd:radiant',
      'srd:thunder',
    ]) {
      final d = damageTypes.firstWhere((dd) => dd.id == id);
      expect(d.physical, false, reason: id);
    }
  });

  test('contains canonical SRD set exactly', () {
    final ids = damageTypes.map((d) => d.id).toSet();
    expect(ids, {
      'srd:acid',
      'srd:bludgeoning',
      'srd:cold',
      'srd:fire',
      'srd:force',
      'srd:lightning',
      'srd:necrotic',
      'srd:piercing',
      'srd:poison',
      'srd:psychic',
      'srd:radiant',
      'srd:slashing',
      'srd:thunder',
    });
  });
}
