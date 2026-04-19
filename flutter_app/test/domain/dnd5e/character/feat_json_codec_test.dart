import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/character/feat.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/feat_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feat codec — round trip', () {
    test('minimal feat round-trips (origin category, defaults)', () {
      final f = Feat(
        id: 'srd:tough',
        name: 'Tough',
        category: FeatCategory.origin,
      );
      final back = featFromEntry(featToEntry(f));
      expect(back.id, 'srd:tough');
      expect(back.name, 'Tough');
      expect(back.category, FeatCategory.origin);
      expect(back.repeatable, false);
      expect(back.prerequisite, isNull);
      expect(back.effects, isEmpty);
      expect(back.description, '');
    });

    test('full feat with all fields round-trips', () {
      final f = Feat(
        id: 'srd:ability_score_improvement',
        name: 'Ability Score Improvement',
        category: FeatCategory.general,
        repeatable: true,
        prerequisite: 'Level 4+',
        description: 'Increase one score by 2, or two by 1.',
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:athletics',
          ),
        ],
      );
      final back = featFromEntry(featToEntry(f));
      expect(back.category, FeatCategory.general);
      expect(back.repeatable, true);
      expect(back.prerequisite, 'Level 4+');
      expect(back.description, 'Increase one score by 2, or two by 1.');
      expect(back.effects, hasLength(1));
      expect(back.effects[0], isA<GrantProficiency>());
    });

    test('each FeatCategory value round-trips', () {
      for (final c in FeatCategory.values) {
        final f = Feat(id: 'srd:x_${c.name}', name: 'X', category: c);
        expect(featFromEntry(featToEntry(f)).category, c);
      }
    });
  });

  group('Feat codec — encode shape', () {
    test('defaults omit repeatable / prerequisite / effects / description', () {
      final f = Feat(
        id: 'srd:alert',
        name: 'Alert',
        category: FeatCategory.origin,
      );
      final body = featToEntry(f).bodyJson;
      expect(body.contains('repeatable'), false);
      expect(body.contains('prerequisite'), false);
      expect(body.contains('effects'), false);
      expect(body.contains('description'), false);
      expect(body.contains('category'), true);
    });

    test('category encoded as enum .name', () {
      final f = Feat(
        id: 'srd:great_weapon_master',
        name: 'Great Weapon Master',
        category: FeatCategory.fightingStyle,
      );
      final body = jsonDecode(featToEntry(f).bodyJson) as Map;
      expect(body['category'], 'fightingStyle');
    });

    test('repeatable=true is emitted', () {
      final f = Feat(
        id: 'srd:asi',
        name: 'ASI',
        category: FeatCategory.general,
        repeatable: true,
      );
      final body = jsonDecode(featToEntry(f).bodyJson) as Map;
      expect(body['repeatable'], true);
    });
  });

  group('Feat codec — decode errors', () {
    test('missing category throws with id prefix', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({}),
      );
      expect(
        () => featFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:x'))
            .having((e) => e.message, 'message', contains('category'))),
      );
    });

    test('unknown category value throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'category': 'nonsense'}),
      );
      expect(
        () => featFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('nonsense'))),
      );
    });

    test('non-bool repeatable throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'category': 'origin', 'repeatable': 'yes'}),
      );
      expect(
        () => featFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('repeatable'))),
      );
    });

    test('malformed JSON body throws with type name', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{not json',
      );
      expect(
        () => featFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Feat'))),
      );
    });
  });
}
