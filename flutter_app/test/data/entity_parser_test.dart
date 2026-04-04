import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/data/services/entity_parser.dart';
import 'package:dungeon_master_tool/domain/entities/schema/default_dnd5e_schema.dart';

void main() {
  final schema = generateDefaultDnd5eSchema();

  group('EntityParser', () {
    test('parses basic entity data', () {
      final data = {
        'name': 'Goblin',
        'source': 'MM',
        'description': 'A small green creature',
      };
      final entity = EntityParser.parseFromExternal(data, 'monster', schema);
      expect(entity.name, 'Goblin');
      expect(entity.source, 'MM');
      expect(entity.description, 'A small green creature');
      expect(entity.categorySlug, 'monster');
      expect(entity.id, isNotEmpty);
    });

    test('maps schema fields correctly', () {
      final data = {
        'name': 'Fireball',
        'level': '3',
        'school': 'Evocation',
        'casting_time': '1 action',
        'range': '150 feet',
      };
      final entity = EntityParser.parseFromExternal(data, 'spell', schema);
      expect(entity.fields['level'], '3');
      expect(entity.fields['school'], 'Evocation');
      expect(entity.fields['casting_time'], '1 action');
    });

    test('extracts images from data', () {
      final data = {
        'name': 'Dragon',
        'image': '/img/dragon.png',
        'images': ['/img/dragon2.png'],
      };
      final entity = EntityParser.parseFromExternal(data, 'monster', schema);
      expect(entity.images, ['/img/dragon.png', '/img/dragon2.png']);
    });

    test('extracts tags', () {
      final data = {
        'name': 'Goblin',
        'tags': ['hostile', 'humanoid'],
      };
      final entity = EntityParser.parseFromExternal(data, 'monster', schema);
      expect(entity.tags, ['hostile', 'humanoid']);
    });

    test('includes special fields (stats, combat_stats, etc.)', () {
      final data = {
        'name': 'Guard',
        'stats': {
          'STR': 14,
          'DEX': 12,
          'CON': 12,
          'INT': 10,
          'WIS': 11,
          'CHA': 10,
        },
        'combat_stats': {'hp': '22', 'ac': '16'},
        'traits': [
          {'name': 'Brave'},
        ],
      };
      final entity = EntityParser.parseFromExternal(data, 'npc', schema);
      expect(entity.fields['stat_block'], isA<Map>());
      expect(entity.fields['combat_stats'], isA<Map>());
      expect(entity.fields['traits'], isA<List>());
    });

    test('extracts dm_notes', () {
      final data = {
        'name': 'Secret NPC',
        'dm_notes': 'This NPC is actually a spy',
      };
      final entity = EntityParser.parseFromExternal(data, 'npc', schema);
      expect(entity.dmNotes, 'This NPC is actually a spy');
    });

    test('defaults to Unnamed when no name', () {
      final data = <String, dynamic>{};
      final entity = EntityParser.parseFromExternal(data, 'npc', schema);
      expect(entity.name, 'Unnamed');
    });

    test('generates unique IDs', () {
      final data = {'name': 'Test'};
      final e1 = EntityParser.parseFromExternal(data, 'npc', schema);
      final e2 = EntityParser.parseFromExternal(data, 'npc', schema);
      expect(e1.id, isNot(e2.id));
    });
  });
}
