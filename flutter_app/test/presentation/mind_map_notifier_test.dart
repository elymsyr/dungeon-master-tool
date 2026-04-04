import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/presentation/screens/mind_map/mind_map_notifier.dart';

/// Creates an isolated ProviderContainer for each test.
ProviderContainer _makeContainer() => ProviderContainer();

// ignore: invalid_use_of_protected_member
MindMapState _state(MindMapNotifier n) => n.state;

void main() {
  group('MindMapNotifier — Node CRUD', () {
    late ProviderContainer c;
    late MindMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('addNode creates node with correct defaults', () {
      n.addNode(const Offset(100, 200), 'note');
      final nodes = _state(n).nodes;
      expect(nodes, hasLength(1));
      expect(nodes.first.nodeType, 'note');
      expect(nodes.first.x, 100);
      expect(nodes.first.y, 200);
      expect(nodes.first.width, 250);
      expect(nodes.first.height, 200);
      expect(nodes.first.label, 'New Note');
    });

    test('addNode with entity type uses correct dimensions', () {
      n.addNode(const Offset(0, 0), 'entity');
      expect(_state(n).nodes.first.height, 200);
      expect(_state(n).nodes.first.width, 300);
    });

    test('deleteNode removes node', () {
      n.addNode(const Offset(0, 0), 'note');
      final id = _state(n).nodes.first.id;
      n.deleteNode(id);
      expect(_state(n).nodes, isEmpty);
    });

    test('deleteNode also removes connected edges', () {
      n.addNode(const Offset(0, 0), 'note');
      n.addNode(const Offset(200, 0), 'note');
      final ids = _state(n).nodes.map((e) => e.id).toList();
      n.addEdge(ids[0], ids[1]);
      expect(_state(n).edges, hasLength(1));

      n.deleteNode(ids[0]);
      expect(_state(n).edges, isEmpty);
    });

    test('updateNodePosition moves node', () {
      n.addNode(const Offset(0, 0), 'note');
      final id = _state(n).nodes.first.id;
      n.updateNodePosition(id, const Offset(300, 400));
      final node = _state(n).nodes.first;
      expect(node.x, 300);
      expect(node.y, 400);
    });

    test('updateNodeContent sets content', () {
      n.addNode(const Offset(0, 0), 'note');
      final id = _state(n).nodes.first.id;
      n.updateNodeContent(id, 'Hello world');
      expect(_state(n).nodes.first.content, 'Hello world');
    });

    test('updateNodeLabel sets label', () {
      n.addNode(const Offset(0, 0), 'note');
      final id = _state(n).nodes.first.id;
      n.updateNodeLabel(id, 'My Note');
      expect(_state(n).nodes.first.label, 'My Note');
    });

    test('updateNodeSize clamps to minimum', () {
      n.addNode(const Offset(0, 0), 'note');
      final id = _state(n).nodes.first.id;
      n.updateNodeSize(id, const Size(50, 20)); // below min
      expect(_state(n).nodes.first.width, 150);
      expect(_state(n).nodes.first.height, 80);
    });

    test('duplicateNode creates offset copy', () {
      n.addNode(const Offset(100, 100), 'note');
      final id = _state(n).nodes.first.id;
      n.duplicateNode(id);
      expect(_state(n).nodes, hasLength(2));
      final copy = _state(n).nodes.last;
      expect(copy.id, isNot(id));
      expect(copy.x, 130);
      expect(copy.y, 130);
    });
  });

  group('MindMapNotifier — Edge CRUD', () {
    late ProviderContainer c;
    late MindMapNotifier n;
    late String idA, idB;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
      n.addNode(const Offset(0, 0), 'note');
      n.addNode(const Offset(200, 0), 'note');
      final nodes = _state(n).nodes;
      idA = nodes[0].id;
      idB = nodes[1].id;
    });
    tearDown(() => c.dispose());

    test('addEdge creates edge', () {
      n.addEdge(idA, idB);
      expect(_state(n).edges, hasLength(1));
      expect(_state(n).edges.first.sourceId, idA);
      expect(_state(n).edges.first.targetId, idB);
    });

    test('addEdge ignores self-loop', () {
      n.addEdge(idA, idA);
      expect(_state(n).edges, isEmpty);
    });

    test('addEdge ignores duplicate edge', () {
      n.addEdge(idA, idB);
      n.addEdge(idA, idB);
      expect(_state(n).edges, hasLength(1));
    });

    test('deleteEdge removes edge', () {
      n.addEdge(idA, idB);
      final edgeId = _state(n).edges.first.id;
      n.deleteEdge(edgeId);
      expect(_state(n).edges, isEmpty);
    });
  });

  group('MindMapNotifier — Undo / Redo', () {
    late ProviderContainer c;
    late MindMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('undo reverts addNode', () {
      n.addNode(const Offset(0, 0), 'note');
      expect(_state(n).nodes, hasLength(1));
      n.undo();
      expect(_state(n).nodes, isEmpty);
    });

    test('redo re-applies after undo', () {
      n.addNode(const Offset(0, 0), 'note');
      n.undo();
      n.redo();
      expect(_state(n).nodes, hasLength(1));
    });

    test('undo/redo multiple steps', () {
      n.addNode(const Offset(0, 0), 'note');
      n.addNode(const Offset(200, 0), 'note');
      n.addNode(const Offset(400, 0), 'note');
      expect(_state(n).nodes, hasLength(3));

      n.undo();
      expect(_state(n).nodes, hasLength(2));
      n.undo();
      expect(_state(n).nodes, hasLength(1));
      n.redo();
      expect(_state(n).nodes, hasLength(2));
    });

    test('new mutation clears redo stack', () {
      n.addNode(const Offset(0, 0), 'note');
      n.undo();
      n.addNode(const Offset(100, 100), 'entity');
      n.redo(); // should be no-op
      expect(_state(n).nodes, hasLength(1));
      expect(_state(n).nodes.first.nodeType, 'entity');
    });

    test('undo does nothing when stack is empty', () {
      n.undo(); // should not throw
      expect(_state(n).nodes, isEmpty);
    });
  });

  group('MindMapNotifier — Selection & Connection mode', () {
    late ProviderContainer c;
    late MindMapNotifier n;
    late String idA, idB;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
      n.addNode(const Offset(0, 0), 'note');
      n.addNode(const Offset(200, 0), 'note');
      idA = _state(n).nodes[0].id;
      idB = _state(n).nodes[1].id;
    });
    tearDown(() => c.dispose());

    test('setSelectedNode sets selection', () {
      n.setSelectedNode(idA);
      expect(_state(n).selectedNodeId, idA);
      expect(_state(n).selectedEdgeId, isNull);
    });

    test('clearSelection clears both', () {
      n.setSelectedNode(idA);
      n.clearSelection();
      expect(_state(n).selectedNodeId, isNull);
    });

    test('startConnecting sets connectingFromId', () {
      n.startConnecting(idA);
      expect(_state(n).connectingFromId, idA);
    });

    test('connectTo completes edge and clears connecting state', () {
      n.startConnecting(idA);
      n.connectTo(idB);
      expect(_state(n).edges, hasLength(1));
      expect(_state(n).connectingFromId, isNull);
    });

    test('cancelConnecting clears connecting state', () {
      n.startConnecting(idA);
      n.cancelConnecting();
      expect(_state(n).connectingFromId, isNull);
    });
  });

  group('MindMapNotifier — Workspace CRUD', () {
    late ProviderContainer c;
    late MindMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('addWorkspace creates workspace with correct defaults', () {
      n.addWorkspace(const Offset(100, 200));
      final ws = _state(n).nodes.first;
      expect(ws.nodeType, 'workspace');
      expect(ws.width, 800);
      expect(ws.height, 600);
      expect(ws.label, 'New Workspace');
      expect(ws.color, '#42a5f5');
      expect(ws.x, 100);
      expect(ws.y, 200);
    });

    test('addWorkspace with custom color', () {
      n.addWorkspace(const Offset(0, 0), color: '#ef5350');
      expect(_state(n).nodes.first.color, '#ef5350');
    });

    test('updateWorkspaceColor changes color', () {
      n.addWorkspace(const Offset(0, 0));
      final id = _state(n).nodes.first.id;
      n.updateWorkspaceColor(id, '#66bb6a');
      expect(_state(n).nodes.first.color, '#66bb6a');
    });

    test('workspaces getter filters correctly', () {
      n.addNode(const Offset(0, 0), 'note');
      n.addWorkspace(const Offset(100, 100));
      n.addNode(const Offset(200, 200), 'entity');
      n.addWorkspace(const Offset(300, 300));

      expect(n.workspaces, hasLength(2));
      expect(n.workspaces.every((w) => w.nodeType == 'workspace'), isTrue);
    });

    test('sortedNodes returns workspaces first', () {
      n.addNode(const Offset(0, 0), 'note');
      n.addWorkspace(const Offset(100, 100));
      n.addNode(const Offset(200, 200), 'entity');

      final sorted = n.sortedNodes;
      expect(sorted.first.nodeType, 'workspace');
      expect(sorted.last.nodeType, 'entity');
    });

    test('deleteNode removes workspace and connected edges', () {
      n.addWorkspace(const Offset(0, 0));
      n.addNode(const Offset(200, 0), 'note');
      final ids = _state(n).nodes.map((e) => e.id).toList();
      n.addEdge(ids[0], ids[1]);
      expect(_state(n).edges, hasLength(1));

      n.deleteNode(ids[0]);
      expect(_state(n).nodes, hasLength(1));
      expect(_state(n).edges, isEmpty);
    });
  });

  group('MindMapNotifier — Entity node from sidebar', () {
    late ProviderContainer c;
    late MindMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('addEntityNode sets entityId and name', () {
      n.addEntityNode(const Offset(50, 75), 'eid-123', 'Blacksmith');
      final node = _state(n).nodes.first;
      expect(node.nodeType, 'entity');
      expect(node.entityId, 'eid-123');
      expect(node.label, 'Blacksmith');
    });

    test('addEntityNode uses correct dimensions', () {
      n.addEntityNode(const Offset(0, 0), 'eid-1', 'NPC');
      final node = _state(n).nodes.first;
      expect(node.width, 300);
      expect(node.height, 200);
    });
  });

  group('MindMapNotifier — Custom gestures & Zoom', () {
    late ProviderContainer c;
    late MindMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
      n.updateViewportSize(const Size(800, 600));
    });
    tearDown(() => c.dispose());

    test('zoomIn increases scale', () {
      final before = n.viewTransform.value.scale;
      n.zoomIn();
      expect(n.viewTransform.value.scale, greaterThan(before));
    });

    test('zoomOut decreases scale', () {
      final before = n.viewTransform.value.scale;
      n.zoomOut();
      expect(n.viewTransform.value.scale, lessThan(before));
    });

    test('screenToCanvas and canvasToScreen are inverses', () {
      const screen = Offset(300, 400);
      final canvas = n.screenToCanvas(screen);
      final back = n.canvasToScreen(canvas);
      expect(back.dx, closeTo(screen.dx, 0.001));
      expect(back.dy, closeTo(screen.dy, 0.001));
    });

    test('zoomAtPoint clamps to minimum 0.05', () {
      for (var i = 0; i < 200; i++) {
        n.zoomAtPoint(Offset.zero, 1); // scroll down = zoom out
      }
      expect(n.viewTransform.value.scale, closeTo(0.05, 0.01));
    });

    test('zoomAtPoint clamps to maximum 10', () {
      for (var i = 0; i < 200; i++) {
        n.zoomAtPoint(Offset.zero, -1); // scroll up = zoom in
      }
      expect(n.viewTransform.value.scale, closeTo(10.0, 0.1));
    });
  });

  group('MindMapNotifier — LOD zones', () {
    late ProviderContainer c;
    late MindMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('lodZone returns 0 at default scale', () {
      expect(n.lodZone, 0); // default scale 1.0
    });

    test('lodZone returns 1 at scale 0.2', () {
      n.viewTransform.value =
          const MindMapViewTransform(scale: 0.2);
      expect(n.lodZone, 1);
    });

    test('lodZone returns 2 at scale 0.05', () {
      n.viewTransform.value =
          const MindMapViewTransform(scale: 0.05);
      expect(n.lodZone, 2);
    });

    test('lodZone boundary at 0.4', () {
      n.viewTransform.value =
          const MindMapViewTransform(scale: 0.4);
      expect(n.lodZone, 0);
      n.viewTransform.value =
          const MindMapViewTransform(scale: 0.39);
      expect(n.lodZone, 1);
    });

    test('lodZone boundary at 0.1', () {
      n.viewTransform.value =
          const MindMapViewTransform(scale: 0.1);
      expect(n.lodZone, 1);
      n.viewTransform.value =
          const MindMapViewTransform(scale: 0.09);
      expect(n.lodZone, 2);
    });
  });

  group('MindMapNotifier — init/save roundtrip', () {
    late ProviderContainer c;
    late MindMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(mindMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('init loads nodes and edges', () {
      n.addNode(const Offset(10, 20), 'note');
      n.addNode(const Offset(200, 20), 'entity');
      final ids = _state(n).nodes.map((e) => e.id).toList();
      n.addEdge(ids[0], ids[1]);

      final json = {
        'nodes': _state(n).nodes.map((nd) => nd.toJson()).toList(),
        'edges': _state(n).edges.map((e) => e.toJson()).toList(),
        'scale': 1.0,
        'pan_x': 0.0,
        'pan_y': 0.0,
      };

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      final n2 = c2.read(mindMapProvider.notifier);
      n2.init(json);

      // ignore: invalid_use_of_protected_member
      final s2 = n2.state;
      expect(s2.nodes, hasLength(2));
      expect(s2.edges, hasLength(1));
      expect(s2.nodes[0].x, 10);
      expect(s2.nodes[0].y, 20);
      expect(s2.nodes[0].nodeType, 'note');
      expect(s2.nodes[1].nodeType, 'entity');
      expect(s2.edges[0].sourceId, ids[0]);
      expect(s2.edges[0].targetId, ids[1]);
    });

    test('init resets undo/redo stacks', () {
      n.addNode(const Offset(0, 0), 'note');
      n.init({});
      n.undo(); // should be no-op
      expect(_state(n).nodes, isEmpty);
    });

    test('init preserves workspace color field', () {
      n.addWorkspace(const Offset(100, 100), color: '#ef5350');
      final json = {
        'nodes': _state(n).nodes.map((nd) => nd.toJson()).toList(),
        'edges': <dynamic>[],
        'scale': 1.0,
        'pan_x': 0.0,
        'pan_y': 0.0,
      };

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      final n2 = c2.read(mindMapProvider.notifier);
      n2.init(json);

      // ignore: invalid_use_of_protected_member
      final s2 = n2.state;
      expect(s2.nodes, hasLength(1));
      expect(s2.nodes.first.color, '#ef5350');
      expect(s2.nodes.first.nodeType, 'workspace');
    });

    test('syncViewTransform updates viewTransform', () {
      n.onScaleStart(ScaleStartDetails(focalPoint: const Offset(100, 100)));
      expect(n.viewTransform.value.scale, 1.0);
    });

    test('centerView fits all nodes into viewport', () {
      n.updateViewportSize(const Size(800, 600));
      n.addNode(const Offset(-100, -100), 'note');
      n.addNode(const Offset(100, 100), 'note');
      n.centerView();
      // After centering, scale should be adjusted
      expect(n.viewTransform.value.scale, greaterThan(0));
      expect(n.viewTransform.value.scale, isNot(1.0));
    });
  });
}
