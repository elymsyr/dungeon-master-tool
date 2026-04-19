import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/dnd5e/character/species.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/species_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Species> species;

  setUpAll(() {
    final file = File('assets/packages/srd_core/species.json');
    final raw = jsonDecode(file.readAsStringSync()) as List;
    species = raw.map((e) {
      final m = (e as Map).cast<String, Object?>();
      final body = (m['body'] as Map).cast<String, Object?>();
      return speciesFromEntry(CatalogEntry(
        id: 'srd:${m['id']}',
        name: m['name'] as String,
        bodyJson: jsonEncode(body),
      ));
    }).toList();
  });

  test('all 9 SRD species parse', () {
    expect(species, hasLength(9));
  });

  test('ids namespaced + unique', () {
    for (final s in species) {
      expect(s.id, startsWith('srd:'));
    }
    final ids = species.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('canonical 2024 PHB SRD 9-species set', () {
    final ids = species.map((s) => s.id).toSet();
    expect(ids, {
      'srd:dragonborn',
      'srd:dwarf',
      'srd:elf',
      'srd:gnome',
      'srd:goliath',
      'srd:halfling',
      'srd:human',
      'srd:orc',
      'srd:tiefling',
    });
  });

  test('every species references a valid size id', () {
    const validSizeIds = {
      'srd:tiny',
      'srd:small',
      'srd:medium',
      'srd:large',
      'srd:huge',
      'srd:gargantuan',
    };
    for (final s in species) {
      expect(validSizeIds, contains(s.sizeId),
          reason: '${s.id} references unknown size ${s.sizeId}');
    }
  });

  test('Small species are Halfling + Gnome; rest Medium', () {
    final small = species.where((s) => s.sizeId == 'srd:small').map((s) => s.id).toSet();
    expect(small, {'srd:halfling', 'srd:gnome'});
    final notSmall = species.where((s) => s.sizeId != 'srd:small');
    for (final s in notSmall) {
      expect(s.sizeId, 'srd:medium', reason: '${s.id} expected Medium');
    }
  });

  test('baseSpeedFt is 30 for all except Goliath (35)', () {
    for (final s in species) {
      if (s.id == 'srd:goliath') {
        expect(s.baseSpeedFt, 35);
      } else {
        expect(s.baseSpeedFt, 30, reason: '${s.id} speed mismatch');
      }
    }
  });

  test('all species have non-empty description', () {
    for (final s in species) {
      expect(s.description, isNotEmpty, reason: '${s.id} missing description');
    }
  });

  test('Darkvision species carry a GrantSenseOrSpeed darkvision effect', () {
    const darkvision60 = {'srd:dragonborn', 'srd:elf', 'srd:gnome', 'srd:tiefling'};
    const darkvision120 = {'srd:dwarf', 'srd:orc'};
    for (final s in species) {
      final dv = s.effects.whereType<GrantSenseOrSpeed>().where(
            (e) => e.kind == SenseOrSpeedKind.darkvision,
          );
      if (darkvision60.contains(s.id)) {
        expect(dv, hasLength(1), reason: '${s.id} expected darkvision effect');
        expect(dv.first.value, 60);
      } else if (darkvision120.contains(s.id)) {
        expect(dv, hasLength(1), reason: '${s.id} expected darkvision effect');
        expect(dv.first.value, 120);
      } else {
        expect(dv, isEmpty, reason: '${s.id} should not have darkvision');
      }
    }
  });

  test('Dwarf carries poison resistance', () {
    final dwarf = species.firstWhere((s) => s.id == 'srd:dwarf');
    final resistances = dwarf.effects.whereType<ModifyResistances>();
    expect(resistances, hasLength(1));
    final r = resistances.first;
    expect(r.kind, ResistanceKind.resistance);
    expect(r.add, contains('srd:poison'));
  });

  test('Goliath, Halfling, Human carry no effects (all traits conditional)', () {
    for (final id in ['srd:goliath', 'srd:halfling', 'srd:human']) {
      final s = species.firstWhere((x) => x.id == id);
      expect(s.effects, isEmpty, reason: '$id should have no static effects');
    }
  });
}
