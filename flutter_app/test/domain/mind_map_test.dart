import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/mind_map.dart';

void main() {
  group('MindMapNode', () {
    test('creates with defaults', () {
      const node = MindMapNode(id: 'n-1');
      expect(node.id, 'n-1');
      expect(node.label, '');
      expect(node.nodeType, 'note');
      expect(node.x, 0);
      expect(node.y, 0);
      expect(node.width, 200);
      expect(node.height, 100);
      expect(node.entityId, isNull);
      expect(node.imageUrl, isNull);
      expect(node.content, '');
      expect(node.style, isEmpty);
    });

    test('note nodeType', () {
      const node = MindMapNode(
        id: 'n-1',
        label: 'Session Notes',
        nodeType: 'note',
        content: 'The party rested at the inn.',
      );
      expect(node.nodeType, 'note');
      expect(node.label, 'Session Notes');
      expect(node.content, 'The party rested at the inn.');
      expect(node.entityId, isNull);
      expect(node.imageUrl, isNull);
    });

    test('entity nodeType with entityId', () {
      const node = MindMapNode(
        id: 'n-2',
        label: 'Elminster',
        nodeType: 'entity',
        entityId: 'npc-42',
      );
      expect(node.nodeType, 'entity');
      expect(node.entityId, 'npc-42');
      expect(node.imageUrl, isNull);
    });

    test('image nodeType with imageUrl', () {
      const node = MindMapNode(
        id: 'n-3',
        label: 'World Map',
        nodeType: 'image',
        imageUrl: 'https://example.com/map.png',
      );
      expect(node.nodeType, 'image');
      expect(node.imageUrl, 'https://example.com/map.png');
      expect(node.entityId, isNull);
    });

    test('workspace nodeType', () {
      const node = MindMapNode(
        id: 'n-4',
        label: 'Planning Area',
        nodeType: 'workspace',
        width: 600,
        height: 400,
      );
      expect(node.nodeType, 'workspace');
      expect(node.width, 600);
      expect(node.height, 400);
    });

    test('copyWith preserves unchanged fields', () {
      const node = MindMapNode(
        id: 'n-1',
        label: 'Original',
        nodeType: 'note',
        x: 100,
        y: 200,
        width: 300,
        height: 150,
        content: 'Some content',
        style: {'color': 'red'},
      );

      final updated = node.copyWith(label: 'Updated', x: 500);
      expect(updated.id, 'n-1');
      expect(updated.label, 'Updated');
      expect(updated.x, 500);
      expect(updated.y, 200);
      expect(updated.width, 300);
      expect(updated.height, 150);
      expect(updated.content, 'Some content');
      expect(updated.style['color'], 'red');
    });

    test('toJson / fromJson roundtrip', () {
      const node = MindMapNode(
        id: 'n-1',
        label: 'Test Node',
        nodeType: 'note',
        x: 150.5,
        y: 250.75,
        width: 300,
        height: 180,
        content: 'Detailed note about the campaign.',
        style: {'color': '#FF5733', 'fontSize': 14, 'bold': true},
      );

      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(node.toJson())) as Map,
      );
      final restored = MindMapNode.fromJson(json);

      expect(restored.id, node.id);
      expect(restored.label, node.label);
      expect(restored.nodeType, 'note');
      expect(restored.x, 150.5);
      expect(restored.y, 250.75);
      expect(restored.width, 300);
      expect(restored.height, 180);
      expect(restored.content, 'Detailed note about the campaign.');
      expect(restored.style['color'], '#FF5733');
      expect(restored.style['fontSize'], 14);
      expect(restored.style['bold'], true);
    });

    test('toJson / fromJson roundtrip with entityId', () {
      const node = MindMapNode(
        id: 'n-2',
        label: 'Linked Entity',
        nodeType: 'entity',
        entityId: 'npc-99',
        x: 50,
        y: 75,
      );

      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(node.toJson())) as Map,
      );
      final restored = MindMapNode.fromJson(json);

      expect(restored.id, 'n-2');
      expect(restored.nodeType, 'entity');
      expect(restored.entityId, 'npc-99');
      expect(restored.imageUrl, isNull);
    });

    test('toJson / fromJson roundtrip with imageUrl', () {
      const node = MindMapNode(
        id: 'n-3',
        label: 'Map Image',
        nodeType: 'image',
        imageUrl: 'https://example.com/dungeon.jpg',
        x: 400,
        y: 300,
      );

      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(node.toJson())) as Map,
      );
      final restored = MindMapNode.fromJson(json);

      expect(restored.id, 'n-3');
      expect(restored.nodeType, 'image');
      expect(restored.imageUrl, 'https://example.com/dungeon.jpg');
      expect(restored.entityId, isNull);
    });
  });

  group('MindMapEdge', () {
    test('creates with defaults', () {
      const edge = MindMapEdge(
        id: 'e-1',
        sourceId: 'n-1',
        targetId: 'n-2',
      );
      expect(edge.id, 'e-1');
      expect(edge.sourceId, 'n-1');
      expect(edge.targetId, 'n-2');
      expect(edge.label, '');
      expect(edge.style, isEmpty);
    });

    test('copyWith preserves unchanged fields', () {
      const edge = MindMapEdge(
        id: 'e-1',
        sourceId: 'n-1',
        targetId: 'n-2',
        label: 'allies',
        style: {'strokeWidth': 2, 'dashed': false},
      );

      final updated = edge.copyWith(label: 'enemies');
      expect(updated.id, 'e-1');
      expect(updated.sourceId, 'n-1');
      expect(updated.targetId, 'n-2');
      expect(updated.label, 'enemies');
      expect(updated.style['strokeWidth'], 2);
      expect(updated.style['dashed'], false);
    });

    test('toJson / fromJson roundtrip', () {
      const edge = MindMapEdge(
        id: 'e-1',
        sourceId: 'n-10',
        targetId: 'n-20',
        label: 'trade route',
        style: {'color': '#00FF00', 'strokeWidth': 3, 'dashed': true},
      );

      final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(edge.toJson())) as Map,
      );
      final restored = MindMapEdge.fromJson(json);

      expect(restored.id, 'e-1');
      expect(restored.sourceId, 'n-10');
      expect(restored.targetId, 'n-20');
      expect(restored.label, 'trade route');
      expect(restored.style['color'], '#00FF00');
      expect(restored.style['strokeWidth'], 3);
      expect(restored.style['dashed'], true);
    });
  });
}
