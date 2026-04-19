import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/character/caster_kind.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterClass codec — round trip', () {
    test('minimal non-caster class round-trips (fighter-like)', () {
      final c = CharacterClass(
        id: 'srd:fighter',
        name: 'Fighter',
        hitDie: Die.d10,
      );
      final back = characterClassFromEntry(characterClassToEntry(c));
      expect(back.id, 'srd:fighter');
      expect(back.name, 'Fighter');
      expect(back.hitDie, Die.d10);
      expect(back.casterKind, CasterKind.none);
      expect(back.casterFraction, 0);
      expect(back.spellcastingAbility, isNull);
      expect(back.savingThrows, isEmpty);
      expect(back.featureTable, isEmpty);
      expect(back.description, '');
    });

    test('full caster with saves + feature table + spellcasting ability', () {
      final c = CharacterClass(
        id: 'srd:wizard',
        name: 'Wizard',
        hitDie: Die.d6,
        casterKind: CasterKind.full,
        spellcastingAbility: Ability.intelligence,
        savingThrows: [Ability.intelligence, Ability.wisdom],
        description: 'Scholar of arcane lore.',
        featureTable: [
          ClassFeatureRow(
            level: 1,
            featureIds: ['srd:arcane_recovery', 'srd:spellcasting'],
          ),
          ClassFeatureRow(
            level: 2,
            effects: [
              GrantProficiency(
                kind: ProficiencyKind.skill,
                targetId: 'srd:arcana',
              ),
            ],
          ),
        ],
      );
      final back = characterClassFromEntry(characterClassToEntry(c));
      expect(back.hitDie, Die.d6);
      expect(back.casterKind, CasterKind.full);
      expect(back.casterFraction, 1.0);
      expect(back.spellcastingAbility, Ability.intelligence);
      expect(back.savingThrows, [Ability.intelligence, Ability.wisdom]);
      expect(back.featureTable, hasLength(2));
      expect(back.featureTable[0].level, 1);
      expect(back.featureTable[0].featureIds, [
        'srd:arcane_recovery',
        'srd:spellcasting',
      ]);
      expect(back.featureTable[1].effects, hasLength(1));
      expect(back.description, 'Scholar of arcane lore.');
    });

    test('each CasterKind value round-trips with default fraction', () {
      for (final k in CasterKind.values) {
        final c = CharacterClass(
          id: 'srd:x_${k.name}',
          name: 'X',
          hitDie: Die.d8,
          casterKind: k,
        );
        final back = characterClassFromEntry(characterClassToEntry(c));
        expect(back.casterKind, k);
        expect(back.casterFraction, c.casterFraction);
      }
    });

    test('each hit Die value round-trips', () {
      for (final d in Die.values) {
        final c = CharacterClass(
          id: 'srd:x_${d.name}',
          name: 'X',
          hitDie: d,
        );
        expect(characterClassFromEntry(characterClassToEntry(c)).hitDie, d);
      }
    });

    test('feature table sorted by level on encode', () {
      final c = CharacterClass(
        id: 'srd:bard',
        name: 'Bard',
        hitDie: Die.d8,
        featureTable: [
          ClassFeatureRow(level: 5, featureIds: ['srd:b']),
          ClassFeatureRow(level: 1, featureIds: ['srd:a']),
          ClassFeatureRow(level: 3, featureIds: ['srd:c']),
        ],
      );
      final body = jsonDecode(characterClassToEntry(c).bodyJson) as Map;
      final rows = body['featureTable'] as List;
      expect((rows[0] as Map)['level'], 1);
      expect((rows[1] as Map)['level'], 3);
      expect((rows[2] as Map)['level'], 5);
    });
  });

  group('CharacterClass codec — encode shape', () {
    test('defaults omit optional fields', () {
      final c = CharacterClass(
        id: 'srd:barbarian',
        name: 'Barbarian',
        hitDie: Die.d12,
      );
      final body = characterClassToEntry(c).bodyJson;
      expect(body.contains('spellcastingAbility'), false);
      expect(body.contains('savingThrows'), false);
      expect(body.contains('featureTable'), false);
      expect(body.contains('casterFraction'), false);
      expect(body.contains('description'), false);
      expect(body.contains('hitDie'), true);
      expect(body.contains('casterKind'), true);
    });

    test('enums encoded as .name', () {
      final c = CharacterClass(
        id: 'srd:paladin',
        name: 'Paladin',
        hitDie: Die.d10,
        casterKind: CasterKind.half,
        spellcastingAbility: Ability.charisma,
        savingThrows: [Ability.wisdom, Ability.charisma],
      );
      final body = jsonDecode(characterClassToEntry(c).bodyJson) as Map;
      expect(body['hitDie'], 'd10');
      expect(body['casterKind'], 'half');
      expect(body['spellcastingAbility'], 'charisma');
      expect(body['savingThrows'], ['wisdom', 'charisma']);
    });

    test('casterFraction emitted only when non-default', () {
      final c = CharacterClass(
        id: 'srd:custom',
        name: 'Custom',
        hitDie: Die.d8,
        casterKind: CasterKind.full,
        casterFraction: 0.75,
      );
      final body = jsonDecode(characterClassToEntry(c).bodyJson) as Map;
      expect(body['casterFraction'], 0.75);
    });
  });

  group('CharacterClass codec — decode errors', () {
    test('missing hitDie throws with id prefix', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'casterKind': 'none'}),
      );
      expect(
        () => characterClassFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:x'))
            .having((e) => e.message, 'message', contains('hitDie'))),
      );
    });

    test('unknown Die throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'hitDie': 'd7', 'casterKind': 'none'}),
      );
      expect(
        () => characterClassFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('d7'))),
      );
    });

    test('unknown CasterKind throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({'hitDie': 'd8', 'casterKind': 'quarter'}),
      );
      expect(
        () => characterClassFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('quarter'))),
      );
    });

    test('unknown Ability in savingThrows throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({
          'hitDie': 'd8',
          'casterKind': 'none',
          'savingThrows': ['strength', 'luck'],
        }),
      );
      expect(
        () => characterClassFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('luck'))),
      );
    });

    test('featureTable row missing level throws', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: jsonEncode({
          'hitDie': 'd8',
          'casterKind': 'none',
          'featureTable': [
            {'featureIds': ['srd:a']},
          ],
        }),
      );
      expect(
        () => characterClassFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('level'))),
      );
    });

    test('malformed JSON body throws with type name', () {
      final bad = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{not json',
      );
      expect(
        () => characterClassFromEntry(bad),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('CharacterClass'))),
      );
    });
  });
}
