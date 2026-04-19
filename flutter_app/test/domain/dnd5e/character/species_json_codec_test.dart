import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/character/species.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/species_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Species codec — round trip', () {
    test('minimal species round-trips', () {
      final s = Species(
        id: 'srd:human',
        name: 'Human',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
      );
      final back = speciesFromEntry(speciesToEntry(s));
      expect(back.id, 'srd:human');
      expect(back.name, 'Human');
      expect(back.sizeId, 'srd:medium');
      expect(back.baseSpeedFt, 30);
      expect(back.effects, isEmpty);
      expect(back.description, '');
    });

    test('full species with effects + description round-trips', () {
      final s = Species(
        id: 'srd:elf',
        name: 'Elf',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
        description: 'Graceful, long-lived wanderers.',
        effects: [
          GrantSenseOrSpeed(kind: SenseOrSpeedKind.darkvision, value: 60),
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:perception',
          ),
        ],
      );
      final back = speciesFromEntry(speciesToEntry(s));
      expect(back.description, 'Graceful, long-lived wanderers.');
      expect(back.effects, hasLength(2));
      expect(back.effects[0], isA<GrantSenseOrSpeed>());
      final darkvision = back.effects[0] as GrantSenseOrSpeed;
      expect(darkvision.kind, SenseOrSpeedKind.darkvision);
      expect(darkvision.value, 60);
      expect(back.effects[1], isA<GrantProficiency>());
    });
  });

  group('Species codec — encode shape', () {
    test('empty effects + empty description omitted', () {
      final s = Species(
        id: 'srd:halfling',
        name: 'Halfling',
        sizeId: 'srd:small',
        baseSpeedFt: 30,
      );
      final body = speciesToEntry(s).bodyJson;
      expect(body.contains('effects'), false);
      expect(body.contains('description'), false);
      expect(body.contains('sizeId'), true);
      expect(body.contains('baseSpeedFt'), true);
    });

    test('body is valid JSON with expected fields', () {
      final s = Species(
        id: 'srd:dwarf',
        name: 'Dwarf',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
        description: 'Stout folk.',
      );
      final body = jsonDecode(speciesToEntry(s).bodyJson) as Map;
      expect(body['sizeId'], 'srd:medium');
      expect(body['baseSpeedFt'], 30);
      expect(body['description'], 'Stout folk.');
    });
  });

  group('Species codec — decode errors', () {
    test('missing sizeId throws with id prefix', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'baseSpeedFt': 30}),
      );
      expect(
        () => speciesFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:x'))
            .having((e) => e.message, 'message', contains('sizeId'))),
      );
    });

    test('non-int baseSpeedFt throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'sizeId': 'srd:medium', 'baseSpeedFt': 'fast'}),
      );
      expect(
        () => speciesFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('baseSpeedFt'))),
      );
    });

    test('malformed JSON body throws with type name', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{not json',
      );
      expect(
        () => speciesFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Species'))),
      );
    });
  });
}
