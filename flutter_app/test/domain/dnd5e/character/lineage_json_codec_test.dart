import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/character/lineage.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/lineage_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lineage codec — round trip', () {
    test('minimal lineage round-trips', () {
      final l = Lineage(
        id: 'srd:high_elf',
        name: 'High Elf',
        parentSpeciesId: 'srd:elf',
      );
      final back = lineageFromEntry(lineageToEntry(l));
      expect(back.id, 'srd:high_elf');
      expect(back.name, 'High Elf');
      expect(back.parentSpeciesId, 'srd:elf');
      expect(back.effects, isEmpty);
      expect(back.description, '');
    });

    test('full lineage with effects + description round-trips', () {
      final l = Lineage(
        id: 'srd:hill_dwarf',
        name: 'Hill Dwarf',
        parentSpeciesId: 'srd:dwarf',
        description: 'Sturdy and wise.',
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:insight',
          ),
        ],
      );
      final back = lineageFromEntry(lineageToEntry(l));
      expect(back.parentSpeciesId, 'srd:dwarf');
      expect(back.description, 'Sturdy and wise.');
      expect(back.effects, hasLength(1));
      expect(back.effects[0], isA<GrantProficiency>());
    });
  });

  group('Lineage codec — encode shape', () {
    test('empty effects + empty description omitted', () {
      final l = Lineage(
        id: 'srd:forest_gnome',
        name: 'Forest Gnome',
        parentSpeciesId: 'srd:gnome',
      );
      final body = lineageToEntry(l).bodyJson;
      expect(body.contains('effects'), false);
      expect(body.contains('description'), false);
      expect(body.contains('parentSpeciesId'), true);
    });

    test('body is valid JSON with expected fields', () {
      final l = Lineage(
        id: 'srd:wood_elf',
        name: 'Wood Elf',
        parentSpeciesId: 'srd:elf',
        description: 'Swift and stealthy.',
      );
      final body = jsonDecode(lineageToEntry(l).bodyJson) as Map;
      expect(body['parentSpeciesId'], 'srd:elf');
      expect(body['description'], 'Swift and stealthy.');
    });
  });

  group('Lineage codec — decode errors', () {
    test('missing parentSpeciesId throws with id prefix', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({}),
      );
      expect(
        () => lineageFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:x'))
            .having((e) => e.message, 'message', contains('parentSpeciesId'))),
      );
    });

    test('non-array effects throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({
          'parentSpeciesId': 'srd:elf',
          'effects': 'oops',
        }),
      );
      expect(
        () => lineageFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('effects'))),
      );
    });

    test('malformed JSON body throws with type name', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{not json',
      );
      expect(
        () => lineageFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Lineage'))),
      );
    });
  });
}
