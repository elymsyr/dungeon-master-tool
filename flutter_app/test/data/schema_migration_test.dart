import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/data/schema/legacy_maps.dart';
import 'package:dungeon_master_tool/data/schema/schema_migration.dart';

void main() {
  group('Legacy Maps', () {
    test('schemaMap maps Turkish names to slugs', () {
      expect(schemaMap['Canavar'], 'monster');
      expect(schemaMap['Büyü (Spell)'], 'spell');
      expect(schemaMap['Mekan'], 'location');
      expect(schemaMap['Oyuncu'], 'player');
      expect(schemaMap['Durum Etkisi'], 'status-effect');
    });

    test('schemaMap maps English names to slugs', () {
      expect(schemaMap['NPC'], 'npc');
      expect(schemaMap['Monster'], 'monster');
      expect(schemaMap['Status Effect'], 'status-effect');
      expect(schemaMap['Legendary Action'], 'legendary-action');
    });

    test('propertyMap maps Turkish labels to fieldKeys', () {
      expect(propertyMap['Irk'], 'race');
      expect(propertyMap['Sınıf'], 'class_');
      expect(propertyMap['Seviye'], 'level');
      expect(propertyMap['Tavır'], 'attitude');
      expect(propertyMap['Hasar Zarı'], 'damage_dice');
    });

    test('defaultEntityFields has required keys', () {
      expect(defaultEntityFields.containsKey('stats'), true);
      expect(defaultEntityFields.containsKey('combat_stats'), true);
      expect(defaultEntityFields.containsKey('traits'), true);
      expect(defaultEntityFields.containsKey('actions'), true);
      expect(defaultEntityFields.containsKey('dm_notes'), true);
      expect(defaultEntityFields['stats'], isA<Map>());
    });
  });

  group('SchemaMigration', () {
    test('does nothing when world_schema and world_id exist', () {
      // migrate() also backfills world_id; supply both so no mutation occurs.
      final data = <String, dynamic>{
        'world_schema': {'some': 'data'},
        'world_id': 'existing-id',
      };
      final result = SchemaMigration.migrate(data);
      expect(result, false);
    });

    test('generates world_schema when missing', () {
      final data = <String, dynamic>{};
      final result = SchemaMigration.migrate(data);
      expect(result, true);
      expect(data.containsKey('world_schema'), true);
      expect(data['world_schema'], isA<Map>());
    });

    test('translates Turkish entity types to slugs', () {
      final data = <String, dynamic>{
        'entities': {
          'e1': {'name': 'Goblin', 'type': 'Canavar', 'attributes': {}},
          'e2': {
            'name': 'Fireball',
            'type': 'Büyü (Spell)',
            'attributes': {},
          },
        },
      };
      SchemaMigration.migrate(data);
      final entities = data['entities'] as Map;
      expect((entities['e1'] as Map)['type'], 'monster');
      expect((entities['e2'] as Map)['type'], 'spell');
    });

    test('translates English entity types to slugs', () {
      final data = <String, dynamic>{
        'entities': {
          'e1': {'name': 'Guard', 'type': 'NPC', 'attributes': {}},
          'e2': {'name': 'Helm', 'type': 'Equipment', 'attributes': {}},
        },
      };
      SchemaMigration.migrate(data);
      final entities = data['entities'] as Map;
      expect((entities['e1'] as Map)['type'], 'npc');
      expect((entities['e2'] as Map)['type'], 'equipment');
    });

    test('translates Turkish attribute keys', () {
      final data = <String, dynamic>{
        'entities': {
          'e1': {
            'name': 'Test NPC',
            'type': 'NPC',
            'attributes': {
              'Irk': 'Human',
              'Sınıf': 'Fighter',
              'Seviye': '5',
            },
          },
        },
      };
      SchemaMigration.migrate(data);
      final entity = (data['entities'] as Map)['e1'] as Map;
      final attrs = entity['attributes'] as Map;
      expect(attrs.containsKey('race'), true);
      expect(attrs.containsKey('class_'), true);
      expect(attrs.containsKey('level'), true);
      expect(attrs['race'], 'Human');
    });

    test('backfills missing default fields', () {
      final data = <String, dynamic>{
        'entities': {
          'e1': {
            'name': 'Minimal',
            'type': 'NPC',
          },
        },
      };
      SchemaMigration.migrate(data);
      final entity = (data['entities'] as Map)['e1'] as Map;
      expect(entity.containsKey('stats'), true);
      expect(entity.containsKey('combat_stats'), true);
      expect(entity.containsKey('traits'), true);
      expect(entity.containsKey('dm_notes'), true);
    });

    test('migrates image_path to images list', () {
      final data = <String, dynamic>{
        'entities': {
          'e1': {
            'name': 'With Image',
            'type': 'NPC',
            'image_path': '/path/to/image.png',
            'images': [],
          },
        },
      };
      SchemaMigration.migrate(data);
      final entity = (data['entities'] as Map)['e1'] as Map;
      expect(entity['images'], ['/path/to/image.png']);
    });

    test('preserves existing images when image_path also present', () {
      final data = <String, dynamic>{
        'entities': {
          'e1': {
            'name': 'With Images',
            'type': 'NPC',
            'image_path': '/old.png',
            'images': ['/new.png'],
          },
        },
      };
      SchemaMigration.migrate(data);
      final entity = (data['entities'] as Map)['e1'] as Map;
      expect(entity['images'], ['/new.png']); // existing images preserved
    });

    test('handles entity list format', () {
      final data = <String, dynamic>{
        'entities': [
          {'name': 'Entity1', 'type': 'Monster', 'attributes': {}},
        ],
      };
      SchemaMigration.migrate(data);
      final entities = data['entities'] as List;
      expect((entities[0] as Map)['type'], 'monster');
    });
  });
}
