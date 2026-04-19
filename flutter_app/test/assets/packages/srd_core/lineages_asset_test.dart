import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/lineage.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/lineage_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Lineage> lineages;

  setUpAll(() {
    final file = File('assets/packages/srd_core/lineages.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    lineages = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return lineageFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 5 SRD lineages parse', () {
    expect(lineages, hasLength(5));
  });

  test('ids namespaced + unique', () {
    for (final l in lineages) {
      expect(l.id, startsWith('srd:'));
    }
    final ids = lineages.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB SRD 5-lineage set', () {
    final ids = lineages.map((l) => l.id).toSet();
    expect(ids, {
      'srd:drow',
      'srd:high_elf',
      'srd:wood_elf',
      'srd:forest_gnome',
      'srd:rock_gnome',
    });
  });

  test('every lineage references a valid species id', () {
    const validSpeciesIds = {'srd:elf', 'srd:gnome'};
    for (final l in lineages) {
      expect(validSpeciesIds, contains(l.parentSpeciesId),
          reason: '${l.id} references unknown species ${l.parentSpeciesId}');
    }
  });

  test('three elven lineages parent to srd:elf', () {
    final elven = lineages
        .where((l) => l.parentSpeciesId == 'srd:elf')
        .map((l) => l.id)
        .toSet();
    expect(elven, {'srd:drow', 'srd:high_elf', 'srd:wood_elf'});
  });

  test('two gnomish lineages parent to srd:gnome', () {
    final gnomish = lineages
        .where((l) => l.parentSpeciesId == 'srd:gnome')
        .map((l) => l.id)
        .toSet();
    expect(gnomish, {'srd:forest_gnome', 'srd:rock_gnome'});
  });

  test('all lineages have non-empty description', () {
    for (final l in lineages) {
      expect(l.description, isNotEmpty, reason: '${l.id} missing description');
    }
  });

  test('Drow carries Superior Darkvision 120 (overrides Elf 60)', () {
    final drow = lineages.firstWhere((l) => l.id == 'srd:drow');
    final dv = drow.effects
        .whereType<GrantSenseOrSpeed>()
        .where((e) => e.kind == SenseOrSpeedKind.darkvision);
    expect(dv, hasLength(1));
    expect(dv.first.value, 120);
  });

  test('Non-Drow lineages carry no static effects (cantrips/innate spells are description-only)', () {
    for (final id in [
      'srd:high_elf',
      'srd:wood_elf',
      'srd:forest_gnome',
      'srd:rock_gnome',
    ]) {
      final l = lineages.firstWhere((x) => x.id == id);
      expect(l.effects, isEmpty, reason: '$id should have no static effects');
    }
  });
}
