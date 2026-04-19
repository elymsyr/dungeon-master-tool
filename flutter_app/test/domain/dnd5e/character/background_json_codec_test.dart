import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/character/background.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/background_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Background codec — round trip', () {
    test('minimal background round-trips', () {
      final b = Background(id: 'srd:acolyte', name: 'Acolyte');
      final back = backgroundFromEntry(backgroundToEntry(b));
      expect(back.id, 'srd:acolyte');
      expect(back.name, 'Acolyte');
      expect(back.effects, isEmpty);
      expect(back.description, '');
    });

    test('full background with effects + description round-trips', () {
      final b = Background(
        id: 'srd:criminal',
        name: 'Criminal',
        description: 'A seasoned lawbreaker.',
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:stealth',
          ),
          GrantProficiency(
            kind: ProficiencyKind.tool,
            targetId: 'srd:thieves_tools',
          ),
        ],
      );
      final back = backgroundFromEntry(backgroundToEntry(b));
      expect(back.description, 'A seasoned lawbreaker.');
      expect(back.effects, hasLength(2));
      expect(back.effects[0], isA<GrantProficiency>());
      final first = back.effects[0] as GrantProficiency;
      expect(first.kind, ProficiencyKind.skill);
      expect(first.targetId, 'srd:stealth');
    });
  });

  group('Background codec — encode shape', () {
    test('empty effects + empty description omitted', () {
      final b = Background(id: 'srd:sage', name: 'Sage');
      final body = backgroundToEntry(b).bodyJson;
      expect(body.contains('effects'), false);
      expect(body.contains('description'), false);
    });

    test('body is valid JSON with expected fields', () {
      final b = Background(
        id: 'srd:soldier',
        name: 'Soldier',
        description: 'A veteran of war.',
      );
      final body = jsonDecode(backgroundToEntry(b).bodyJson) as Map;
      expect(body['description'], 'A veteran of war.');
      expect(body.containsKey('effects'), false);
    });
  });

  group('Background codec — decode errors', () {
    test('non-object body throws with id prefix + type name', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode([1, 2, 3]),
      );
      expect(
        () => backgroundFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:x'))
            .having((e) => e.message, 'message', contains('Background'))),
      );
    });

    test('malformed JSON body throws with type name', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{not json',
      );
      expect(
        () => backgroundFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Background'))),
      );
    });

    test('non-string description throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'description': 42}),
      );
      expect(
        () => backgroundFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('description'))),
      );
    });

    test('non-array effects throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'effects': 'not a list'}),
      );
      expect(
        () => backgroundFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('effects'))),
      );
    });
  });
}
