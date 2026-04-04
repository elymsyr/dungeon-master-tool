import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/campaign.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';

void main() {
  group('MapData', () {
    test('creates with defaults', () {
      const mapData = MapData();
      expect(mapData.imagePath, '');
      expect(mapData.pins, isEmpty);
      expect(mapData.timeline, isEmpty);
    });

    test('copyWith preserves unchanged fields', () {
      final mapData = MapData(
        imagePath: '/maps/world.png',
        pins: [
          {'name': 'Tavern', 'x': 10.0, 'y': 20.0},
        ],
        timeline: [
          {'event': 'Dragon attack', 'day': 1},
        ],
      );

      final updated = mapData.copyWith(imagePath: '/maps/dungeon.png');
      expect(updated.imagePath, '/maps/dungeon.png');
      expect(updated.pins.length, 1);
      expect(updated.pins.first['name'], 'Tavern');
      expect(updated.timeline.length, 1);
      expect(updated.timeline.first['event'], 'Dragon attack');
    });

    test('toJson / fromJson roundtrip', () {
      final mapData = MapData(
        imagePath: '/maps/forest.png',
        pins: [
          {'name': 'Cave Entrance', 'x': 100.0, 'y': 200.0},
          {'name': 'River Crossing', 'x': 300.0, 'y': 150.0},
        ],
        timeline: [
          {'event': 'Flood', 'day': 5, 'severity': 'high'},
        ],
      );

      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(mapData.toJson())) as Map,
      );
      final restored = MapData.fromJson(json);

      expect(restored.imagePath, mapData.imagePath);
      expect(restored.pins.length, 2);
      expect(restored.pins.first['name'], 'Cave Entrance');
      expect(restored.pins.last['x'], 300.0);
      expect(restored.timeline.length, 1);
      expect(restored.timeline.first['severity'], 'high');
    });
  });

  group('Campaign', () {
    test('creates with defaults', () {
      const campaign = Campaign();
      expect(campaign.worldName, '');
      expect(campaign.entities, isEmpty);
      expect(campaign.mapData, const MapData());
      expect(campaign.sessions, isEmpty);
      expect(campaign.lastActiveSessionId, isNull);
      expect(campaign.mindMaps, isEmpty);
      expect(campaign.worldSchema, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final campaign = Campaign(
        worldName: 'Forgotten Realms',
        entities: {
          'npc-1': {'name': 'Elminster', 'type': 'npc'},
        },
        sessions: [
          {'id': 's-1', 'name': 'Session 1'},
        ],
        lastActiveSessionId: 's-1',
      );

      final updated = campaign.copyWith(worldName: 'Eberron');
      expect(updated.worldName, 'Eberron');
      expect(updated.entities['npc-1'], isNotNull);
      expect(updated.sessions.length, 1);
      expect(updated.lastActiveSessionId, 's-1');
    });

    test('toJson / fromJson roundtrip', () {
      final campaign = Campaign(
        worldName: 'Greyhawk',
        entities: {
          'npc-1': {'name': 'Mordenkainen', 'level': 20},
          'loc-1': {'name': 'Castle Greyhawk', 'type': 'location'},
        },
        mapData: MapData(
          imagePath: '/maps/greyhawk.png',
          pins: [
            {'name': 'Castle', 'x': 50.0, 'y': 75.0},
          ],
          timeline: [
            {'event': 'Founding', 'year': 0},
          ],
        ),
        sessions: [
          {'id': 's-1', 'name': 'Arrival', 'notes': 'The party arrives'},
          {'id': 's-2', 'name': 'Exploration'},
        ],
        lastActiveSessionId: 's-2',
        mindMaps: {
          'mm-1': {'title': 'NPC Relations'},
        },
      );

      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(campaign.toJson())) as Map,
      );
      final restored = Campaign.fromJson(json);

      expect(restored.worldName, 'Greyhawk');
      expect(restored.entities.length, 2);
      expect(restored.entities['npc-1']!['name'], 'Mordenkainen');
      expect(restored.entities['loc-1']!['type'], 'location');
      expect(restored.mapData.imagePath, '/maps/greyhawk.png');
      expect(restored.mapData.pins.length, 1);
      expect(restored.mapData.timeline.first['event'], 'Founding');
      expect(restored.sessions.length, 2);
      expect(restored.sessions.last['name'], 'Exploration');
      expect(restored.lastActiveSessionId, 's-2');
      expect(restored.mindMaps['mm-1'], isNotNull);
    });

    test('worldSchema null vs present', () {
      const campaignNoSchema = Campaign(worldName: 'No Schema World');
      expect(campaignNoSchema.worldSchema, isNull);

      final campaignWithSchema = Campaign(
        worldName: 'Schema World',
        worldSchema: WorldSchema(
          schemaId: 'ws-1',
          name: 'Custom Schema',
          createdAt: '2026-01-01T00:00:00Z',
          updatedAt: '2026-04-01T00:00:00Z',
        ),
      );
      expect(campaignWithSchema.worldSchema, isNotNull);
      expect(campaignWithSchema.worldSchema!.schemaId, 'ws-1');
      expect(campaignWithSchema.worldSchema!.name, 'Custom Schema');
    });

    test('toJson / fromJson roundtrip with worldSchema', () {
      final campaign = Campaign(
        worldName: 'Schema World',
        worldSchema: WorldSchema(
          schemaId: 'ws-1',
          name: 'D&D 5e Homebrew',
          version: '2.0.0',
          baseSystem: 'dnd5e',
          description: 'Custom rules',
          createdAt: '2026-01-01T00:00:00Z',
          updatedAt: '2026-04-01T00:00:00Z',
        ),
      );

      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(campaign.toJson())) as Map,
      );
      final restored = Campaign.fromJson(json);

      expect(restored.worldSchema, isNotNull);
      expect(restored.worldSchema!.schemaId, 'ws-1');
      expect(restored.worldSchema!.name, 'D&D 5e Homebrew');
      expect(restored.worldSchema!.version, '2.0.0');
      expect(restored.worldSchema!.baseSystem, 'dnd5e');
      expect(restored.worldSchema!.description, 'Custom rules');
    });

    test('populated entities and sessions', () {
      final campaign = Campaign(
        worldName: 'Dark Sun',
        entities: {
          'npc-1': {'name': 'Rikus', 'class': 'gladiator', 'level': 15},
          'npc-2': {'name': 'Sadira', 'class': 'defiler', 'level': 12},
          'item-1': {'name': 'Heartwood Spear', 'rarity': 'legendary'},
        },
        sessions: [
          {'id': 's-1', 'name': 'Escape from Tyr', 'xp': 500},
          {'id': 's-2', 'name': 'Desert Trek', 'xp': 750},
          {'id': 's-3', 'name': 'Dragon Encounter', 'xp': 2000},
        ],
      );

      expect(campaign.entities.length, 3);
      expect(campaign.entities['npc-1']!['class'], 'gladiator');
      expect(campaign.entities['item-1']!['rarity'], 'legendary');
      expect(campaign.sessions.length, 3);
      expect(campaign.sessions[1]['name'], 'Desert Trek');
      expect(campaign.sessions[2]['xp'], 2000);
    });
  });
}
