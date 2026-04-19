import 'dart:convert';

import 'package:dungeon_master_tool/domain/dnd5e/character/character_class.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/subclass.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/subclass_json_codec.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:dungeon_master_tool/domain/dnd5e/package/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Subclass codec — round trip', () {
    test('minimal subclass round-trips', () {
      final s = Subclass(
        id: 'srd:champion',
        name: 'Champion',
        parentClassId: 'srd:fighter',
      );
      final back = subclassFromEntry(subclassToEntry(s));
      expect(back.id, 'srd:champion');
      expect(back.name, 'Champion');
      expect(back.parentClassId, 'srd:fighter');
      expect(back.featureTable, isEmpty);
      expect(back.description, '');
    });

    test('full subclass with features + effects round-trips', () {
      final s = Subclass(
        id: 'srd:evocation',
        name: 'School of Evocation',
        parentClassId: 'srd:wizard',
        description: 'Shape spells to spare allies.',
        featureTable: [
          ClassFeatureRow(
            level: 3,
            featureIds: ['srd:evocation-savant', 'srd:sculpt-spells'],
          ),
          ClassFeatureRow(
            level: 6,
            featureIds: ['srd:potent-cantrip'],
            effects: [
              ModifySave(ability: Ability.dexterity, flatBonus: 1),
            ],
          ),
          ClassFeatureRow(level: 10, featureIds: ['srd:empowered-evocation']),
          ClassFeatureRow(level: 14, featureIds: ['srd:overchannel']),
        ],
      );
      final back = subclassFromEntry(subclassToEntry(s));
      expect(back.description, 'Shape spells to spare allies.');
      expect(back.featureTable, hasLength(4));
      expect(back.featureTable[0].level, 3);
      expect(back.featureTable[0].featureIds,
          ['srd:evocation-savant', 'srd:sculpt-spells']);
      expect(back.featureTable[1].effects, hasLength(1));
      expect(back.featureTable[1].effects[0], isA<ModifySave>());
      expect(back.featureTable[3].level, 14);
    });
  });

  group('Subclass codec — encode shape', () {
    test('empty featureTable + empty description omitted', () {
      final s = Subclass(
        id: 'srd:s',
        name: 'S',
        parentClassId: 'srd:c',
      );
      final body = subclassToEntry(s).bodyJson;
      expect(body.contains('featureTable'), false);
      expect(body.contains('description'), false);
      expect(body.contains('parentClassId'), true);
    });

    test('rows emitted sorted by level regardless of input order', () {
      final s = Subclass(
        id: 'srd:s',
        name: 'S',
        parentClassId: 'srd:c',
        featureTable: [
          ClassFeatureRow(level: 14, featureIds: ['srd:f14']),
          ClassFeatureRow(level: 3, featureIds: ['srd:f3']),
          ClassFeatureRow(level: 10, featureIds: ['srd:f10']),
          ClassFeatureRow(level: 6, featureIds: ['srd:f6']),
        ],
      );
      final body = jsonDecode(subclassToEntry(s).bodyJson)
          as Map<String, Object?>;
      final rows = (body['featureTable'] as List)
          .cast<Map<String, Object?>>();
      expect(rows.map((r) => r['level']).toList(), [3, 6, 10, 14]);
    });

    test('empty featureIds + empty effects elided from row', () {
      final s = Subclass(
        id: 'srd:s',
        name: 'S',
        parentClassId: 'srd:c',
        featureTable: [ClassFeatureRow(level: 3)],
      );
      final body = subclassToEntry(s).bodyJson;
      expect(body.contains('featureIds'), false);
      expect(body.contains('effects'), false);
      expect(body.contains('"level":3'), true);
    });
  });

  group('Subclass codec — errors', () {
    test('rejects non-object body', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '[]');
      expect(() => subclassFromEntry(e), throwsFormatException);
    });

    test('rejects missing parentClassId', () {
      final e = CatalogEntry(id: 'srd:x', name: 'X', bodyJson: '{}');
      expect(() => subclassFromEntry(e), throwsFormatException);
    });

    test('rejects non-array featureTable', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{"parentClassId":"srd:c","featureTable":{}}',
      );
      expect(() => subclassFromEntry(e), throwsFormatException);
    });

    test('rejects row missing level', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson:
            '{"parentClassId":"srd:c","featureTable":[{"featureIds":["srd:a"]}]}',
      );
      expect(() => subclassFromEntry(e), throwsFormatException);
    });

    test('rejects row with non-string featureIds entry', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson:
            '{"parentClassId":"srd:c","featureTable":[{"level":3,"featureIds":[1]}]}',
      );
      expect(() => subclassFromEntry(e), throwsFormatException);
    });

    test('rejects non-object row', () {
      final e = CatalogEntry(
        id: 'srd:x',
        name: 'X',
        bodyJson: '{"parentClassId":"srd:c","featureTable":[1]}',
      );
      expect(() => subclassFromEntry(e), throwsFormatException);
    });

    test('error messages carry entry id prefix', () {
      final e = CatalogEntry(
        id: 'srd:broken',
        name: 'X',
        bodyJson: '{}',
      );
      expect(
        () => subclassFromEntry(e),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('srd:broken'))),
      );
    });
  });
}
