import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../domain/entities/mind_map.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// View transform (lightweight — not in Riverpod state)
// ---------------------------------------------------------------------------

class MindMapViewTransform {
  final double scale;
  final Offset panOffset;
  const MindMapViewTransform({this.scale = 1.0, this.panOffset = Offset.zero});
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MindMapState {
  final List<MindMapNode> nodes;
  final List<MindMapEdge> edges;
  final String? selectedNodeId;
  final String? selectedEdgeId;
  final String? connectingFromId;
  final String? moveModeNodeId;
  final String? resizeModeNodeId;

  const MindMapState({
    this.nodes = const [],
    this.edges = const [],
    this.selectedNodeId,
    this.selectedEdgeId,
    this.connectingFromId,
    this.moveModeNodeId,
    this.resizeModeNodeId,
  });

  MindMapState copyWith({
    List<MindMapNode>? nodes,
    List<MindMapEdge>? edges,
    String? selectedNodeId,
    String? selectedEdgeId,
    String? connectingFromId,
    String? moveModeNodeId,
    String? resizeModeNodeId,
    bool clearSelectedNode = false,
    bool clearSelectedEdge = false,
    bool clearConnectingFrom = false,
    bool clearMoveMode = false,
    bool clearResizeMode = false,
  }) {
    return MindMapState(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      selectedNodeId: clearSelectedNode ? null : (selectedNodeId ?? this.selectedNodeId),
      selectedEdgeId: clearSelectedEdge ? null : (selectedEdgeId ?? this.selectedEdgeId),
      connectingFromId: clearConnectingFrom ? null : (connectingFromId ?? this.connectingFromId),
      moveModeNodeId: clearMoveMode ? null : (moveModeNodeId ?? this.moveModeNodeId),
      resizeModeNodeId: clearResizeMode ? null : (resizeModeNodeId ?? this.resizeModeNodeId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindMapState &&
          nodes == other.nodes &&
          edges == other.edges &&
          selectedNodeId == other.selectedNodeId &&
          selectedEdgeId == other.selectedEdgeId &&
          connectingFromId == other.connectingFromId &&
          moveModeNodeId == other.moveModeNodeId &&
          resizeModeNodeId == other.resizeModeNodeId;

  @override
  int get hashCode => Object.hash(nodes, edges, selectedNodeId, selectedEdgeId, connectingFromId, moveModeNodeId, resizeModeNodeId);
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class MindMapNotifier extends StateNotifier<MindMapState> {
  final Ref _ref;

  /// Lightweight view transform — updated at 60fps, not via Riverpod.
  final ValueNotifier<MindMapViewTransform> viewTransform =
      ValueNotifier<MindMapViewTransform>(const MindMapViewTransform());

  /// Triggers edge repaint without full widget rebuild.
  final ValueNotifier<int> edgeTick = ValueNotifier<int>(0);

  final List<MindMapState> _undoStack = [];
  final List<MindMapState> _redoStack = [];
  static const int _maxUndo = 50;

  Timer? _saveTimer;

  // Gesture tracking
  double _scaleBase = 1.0;
  Offset _focalBase = Offset.zero;
  Offset _panBase = Offset.zero;
  Size _viewportSize = Size.zero;

  MindMapNotifier(this._ref) : super(const MindMapState());

  @override
  void dispose() {
    _saveTimer?.cancel();
    viewTransform.dispose();
    edgeTick.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Init / Save
  // -------------------------------------------------------------------------

  void init(Map<String, dynamic> data) {
    final nodesList = (data['nodes'] as List? ?? [])
        .map((n) => MindMapNode.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();
    final edgesList = (data['edges'] as List? ?? [])
        .map((e) => MindMapEdge.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final panX = (data['pan_x'] as num? ?? 0).toDouble();
    final panY = (data['pan_y'] as num? ?? 0).toDouble();
    final scale = (data['scale'] as num? ?? 1.0).toDouble();
    viewTransform.value = MindMapViewTransform(
      scale: scale,
      panOffset: Offset(panX, panY),
    );

    state = MindMapState(nodes: nodesList, edges: edgesList);
    _undoStack.clear();
    _redoStack.clear();
  }

  Future<void> save() async {
    final campaign = _ref.read(activeCampaignProvider.notifier);
    if (campaign.data == null) return;

    final vt = viewTransform.value;
    final mindMapData = {
      'nodes': state.nodes.map((n) => n.toJson()).toList(),
      'edges': state.edges.map((e) => e.toJson()).toList(),
      'scale': vt.scale,
      'pan_x': vt.panOffset.dx,
      'pan_y': vt.panOffset.dy,
    };

    final mindMaps =
        Map<String, dynamic>.from(campaign.data!['mind_maps'] as Map? ?? {});
    mindMaps['default'] = mindMapData;
    campaign.data!['mind_maps'] = mindMaps;
    await campaign.save();
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) save();
    });
  }

  // -------------------------------------------------------------------------
  // Undo / Redo
  // -------------------------------------------------------------------------

  void _pushUndo() {
    _undoStack.add(state);
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(state);
    state = _undoStack.removeLast();
    edgeTick.value++;
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(state);
    state = _redoStack.removeLast();
    edgeTick.value++;
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // -------------------------------------------------------------------------
  // Pan / Zoom (custom gesture handling — BattleMap/WorldMap pattern)
  // -------------------------------------------------------------------------

  void onScaleStart(ScaleStartDetails d) {
    _scaleBase = viewTransform.value.scale;
    _focalBase = d.focalPoint;
    _panBase = viewTransform.value.panOffset;
  }

  void onScaleUpdate(ScaleUpdateDetails d) {
    final newScale = (_scaleBase * d.scale).clamp(0.05, 10.0);
    final focalDelta = d.focalPoint - _focalBase;
    final scaleRatio = newScale / _scaleBase;
    final newPan = _focalBase - (_focalBase - _panBase) * scaleRatio + focalDelta;
    viewTransform.value = MindMapViewTransform(scale: newScale, panOffset: newPan);
  }

  void onScaleEnd() {
    _debouncedSave();
  }

  /// Mouse-wheel zoom centered on [localPos].
  void zoomAtPoint(Offset localPos, double scrollDelta) {
    const factor = 1.12;
    final vt = viewTransform.value;
    final scaleFactor = scrollDelta < 0 ? factor : 1.0 / factor;
    final newScale = (vt.scale * scaleFactor).clamp(0.05, 10.0);
    final scaleRatio = newScale / vt.scale;
    final newPan = localPos - (localPos - vt.panOffset) * scaleRatio;
    viewTransform.value = MindMapViewTransform(scale: newScale, panOffset: newPan);
  }

  void updateViewportSize(Size size) {
    _viewportSize = size;
  }

  Offset screenToCanvas(Offset screenPt) {
    final vt = viewTransform.value;
    return (screenPt - vt.panOffset) / vt.scale;
  }

  Offset canvasToScreen(Offset canvasPt) {
    final vt = viewTransform.value;
    return canvasPt * vt.scale + vt.panOffset;
  }

  // -------------------------------------------------------------------------
  // Zoom controls (for floating buttons)
  // -------------------------------------------------------------------------

  void zoomIn() {
    final vt = viewTransform.value;
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final newScale = (vt.scale * 1.2).clamp(0.05, 10.0);
    final scaleRatio = newScale / vt.scale;
    final newPan = center - (center - vt.panOffset) * scaleRatio;
    viewTransform.value = MindMapViewTransform(scale: newScale, panOffset: newPan);
  }

  void zoomOut() {
    final vt = viewTransform.value;
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final newScale = (vt.scale / 1.2).clamp(0.05, 10.0);
    final scaleRatio = newScale / vt.scale;
    final newPan = center - (center - vt.panOffset) * scaleRatio;
    viewTransform.value = MindMapViewTransform(scale: newScale, panOffset: newPan);
  }

  /// Fit all nodes into the viewport.
  void centerView() {
    if (state.nodes.isEmpty || _viewportSize == Size.zero) {
      viewTransform.value = const MindMapViewTransform();
      return;
    }
    _fitBounds(_allNodesBounds());
  }

  /// Zoom to a specific workspace.
  void zoomToWorkspace(String id) {
    final ws = state.nodes.where((n) => n.id == id).firstOrNull;
    if (ws == null || _viewportSize == Size.zero) return;
    final bounds = Rect.fromCenter(
      center: Offset(ws.x, ws.y),
      width: ws.width,
      height: ws.height,
    );
    _fitBounds(bounds);
  }

  void _fitBounds(Rect bounds) {
    if (bounds.isEmpty || _viewportSize == Size.zero) return;
    final padded = bounds.inflate(50);
    final scaleX = _viewportSize.width / padded.width;
    final scaleY = _viewportSize.height / padded.height;
    final newScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.05, 10.0);
    final canvasCenter = padded.center;
    final screenCenter = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final newPan = screenCenter - canvasCenter * newScale;
    viewTransform.value = MindMapViewTransform(scale: newScale, panOffset: newPan);
  }

  Rect _allNodesBounds() {
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final n in state.nodes) {
      final left = n.x - n.width / 2;
      final top = n.y - n.height / 2;
      final right = n.x + n.width / 2;
      final bottom = n.y + n.height / 2;
      if (left < minX) minX = left;
      if (top < minY) minY = top;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  // -------------------------------------------------------------------------
  // LOD
  // -------------------------------------------------------------------------

  int get lodZone {
    final s = viewTransform.value.scale;
    if (s >= 0.4) return 0;
    if (s >= 0.1) return 1;
    return 2;
  }

  // -------------------------------------------------------------------------
  // Sorted nodes (workspaces behind others)
  // -------------------------------------------------------------------------

  List<MindMapNode> get sortedNodes {
    final ws = state.nodes.where((n) => n.nodeType == 'workspace').toList();
    final other = state.nodes.where((n) => n.nodeType != 'workspace').toList();
    return [...ws, ...other];
  }

  List<MindMapNode> get workspaces =>
      state.nodes.where((n) => n.nodeType == 'workspace').toList();

  // -------------------------------------------------------------------------
  // Node CRUD
  // -------------------------------------------------------------------------

  String addNode(Offset canvasPos, String nodeType) {
    _pushUndo();
    final id = _uuid.v4();
    final (label, w, h) = switch (nodeType) {
      'note' => ('New Note', 250.0, 200.0),
      'entity' => ('Entity', 300.0, 200.0),
      'image' => ('Image', 300.0, 300.0),
      'workspace' => ('New Workspace', 800.0, 600.0),
      _ => ('Node', 200.0, 150.0),
    };
    final node = MindMapNode(
      id: id,
      label: label,
      nodeType: nodeType,
      x: canvasPos.dx,
      y: canvasPos.dy,
      width: w,
      height: h,
    );
    state = state.copyWith(nodes: [...state.nodes, node]);
    _debouncedSave();
    return id;
  }

  /// Add workspace with optional custom color.
  String addWorkspace(Offset canvasPos, {String color = '#42a5f5'}) {
    _pushUndo();
    final id = _uuid.v4();
    final node = MindMapNode(
      id: id,
      label: 'New Workspace',
      nodeType: 'workspace',
      x: canvasPos.dx,
      y: canvasPos.dy,
      width: 800,
      height: 600,
      color: color,
    );
    state = state.copyWith(nodes: [...state.nodes, node]);
    _debouncedSave();
    return id;
  }

  /// Add entity node from sidebar drag-drop.
  String addEntityNode(Offset canvasPos, String entityId, String entityName) {
    _pushUndo();
    final id = _uuid.v4();
    final node = MindMapNode(
      id: id,
      label: entityName,
      nodeType: 'entity',
      x: canvasPos.dx,
      y: canvasPos.dy,
      width: 300,
      height: 200,
      entityId: entityId,
    );
    state = state.copyWith(nodes: [...state.nodes, node]);
    _debouncedSave();
    return id;
  }

  void deleteNode(String id) {
    _pushUndo();
    final updatedNodes = state.nodes.where((n) => n.id != id).toList();
    final updatedEdges = state.edges
        .where((e) => e.sourceId != id && e.targetId != id)
        .toList();
    state = state.copyWith(
      nodes: updatedNodes,
      edges: updatedEdges,
      clearSelectedNode: state.selectedNodeId == id,
      clearConnectingFrom: state.connectingFromId == id,
    );
    edgeTick.value++;
    _debouncedSave();
  }

  void duplicateNode(String id) {
    final original = state.nodes.firstWhere((n) => n.id == id);
    _pushUndo();
    final newNode = original.copyWith(
      id: _uuid.v4(),
      x: original.x + 30,
      y: original.y + 30,
    );
    state = state.copyWith(nodes: [...state.nodes, newNode]);
    _debouncedSave();
  }

  void updateNodePosition(String id, Offset pos) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = List<MindMapNode>.from(state.nodes);
    updated[idx] = updated[idx].copyWith(x: pos.dx, y: pos.dy);
    state = state.copyWith(nodes: updated);
    edgeTick.value++;
    _debouncedSave();
  }

  void updateNodeSize(String id, Size size) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = List<MindMapNode>.from(state.nodes);
    updated[idx] = updated[idx].copyWith(
      width: size.width.clamp(150, 2000),
      height: size.height.clamp(80, 2000),
    );
    state = state.copyWith(nodes: updated);
    edgeTick.value++;
    _debouncedSave();
  }

  void updateNodeContent(String id, String content) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = List<MindMapNode>.from(state.nodes);
    updated[idx] = updated[idx].copyWith(content: content);
    state = state.copyWith(nodes: updated);
    _debouncedSave();
  }

  void updateNodeLabel(String id, String label) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = List<MindMapNode>.from(state.nodes);
    updated[idx] = updated[idx].copyWith(label: label);
    state = state.copyWith(nodes: updated);
    _debouncedSave();
  }

  void updateNodeEntityId(String id, String? entityId) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _pushUndo();
    final updated = List<MindMapNode>.from(state.nodes);
    updated[idx] = updated[idx].copyWith(entityId: entityId);
    state = state.copyWith(nodes: updated);
    _debouncedSave();
  }

  void updateNodeImageUrl(String id, String imageUrl) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final updated = List<MindMapNode>.from(state.nodes);
    updated[idx] = updated[idx].copyWith(imageUrl: imageUrl);
    state = state.copyWith(nodes: updated);
    _debouncedSave();
  }

  /// Merge new entries into a node's style map.
  void updateNodeStyle(String id, Map<String, dynamic> styleUpdate) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _pushUndo();
    final updated = List<MindMapNode>.from(state.nodes);
    final current = Map<String, dynamic>.from(updated[idx].style);
    current.addAll(styleUpdate);
    updated[idx] = updated[idx].copyWith(style: current);
    state = state.copyWith(nodes: updated);
    _debouncedSave();
  }

  /// Update workspace border color.
  void updateWorkspaceColor(String id, String hexColor) {
    final idx = state.nodes.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _pushUndo();
    final updated = List<MindMapNode>.from(state.nodes);
    updated[idx] = updated[idx].copyWith(color: hexColor);
    state = state.copyWith(nodes: updated);
    _debouncedSave();
  }

  // -------------------------------------------------------------------------
  // Move / Resize mode (context menu actions)
  // -------------------------------------------------------------------------

  void enterMoveMode(String nodeId) {
    state = state.copyWith(
      moveModeNodeId: nodeId,
      clearResizeMode: true,
    );
  }

  void exitMoveMode() {
    state = state.copyWith(clearMoveMode: true);
  }

  /// Place the move-mode node at [canvasPos] and exit move mode.
  void placeNodeAtPosition(Offset canvasPos) {
    final id = state.moveModeNodeId;
    if (id == null) return;
    _pushUndo();
    updateNodePosition(id, canvasPos);
    state = state.copyWith(clearMoveMode: true);
  }

  void enterResizeMode(String nodeId) {
    state = state.copyWith(
      resizeModeNodeId: nodeId,
      selectedNodeId: nodeId,
      clearMoveMode: true,
      clearSelectedEdge: true,
    );
  }

  void exitResizeMode() {
    state = state.copyWith(clearResizeMode: true);
  }

  // -------------------------------------------------------------------------
  // Edge CRUD
  // -------------------------------------------------------------------------

  void addEdge(String sourceId, String targetId) {
    if (sourceId == targetId) return;
    if (state.edges.any((e) => e.sourceId == sourceId && e.targetId == targetId)) return;
    _pushUndo();
    final edge = MindMapEdge(
      id: _uuid.v4(),
      sourceId: sourceId,
      targetId: targetId,
    );
    state = state.copyWith(
      edges: [...state.edges, edge],
      clearConnectingFrom: true,
    );
    edgeTick.value++;
    _debouncedSave();
  }

  void deleteEdge(String id) {
    _pushUndo();
    final updated = state.edges.where((e) => e.id != id).toList();
    state = state.copyWith(
      edges: updated,
      clearSelectedEdge: state.selectedEdgeId == id,
    );
    edgeTick.value++;
    _debouncedSave();
  }

  // -------------------------------------------------------------------------
  // Selection
  // -------------------------------------------------------------------------

  void setSelectedNode(String? id) {
    state = state.copyWith(
      selectedNodeId: id,
      clearSelectedNode: id == null,
      clearSelectedEdge: true,
    );
  }

  void setSelectedEdge(String? id) {
    state = state.copyWith(
      selectedEdgeId: id,
      clearSelectedEdge: id == null,
      clearSelectedNode: true,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedNode: true,
      clearSelectedEdge: true,
    );
  }

  /// Hit-test [point] (in canvas coords) against all edges.
  /// Returns the edge id if within [threshold] px, or null.
  String? hitTestEdge(Offset point, {double threshold = 10.0}) {
    final nodeMap = <String, Offset>{};
    for (final n in state.nodes) {
      nodeMap[n.id] = Offset(n.x, n.y);
    }
    String? bestId;
    double bestDist = threshold;
    for (final edge in state.edges) {
      final src = nodeMap[edge.sourceId];
      final tgt = nodeMap[edge.targetId];
      if (src == null || tgt == null) continue;
      final d = _distToCubicBezier(point, src, tgt);
      if (d < bestDist) {
        bestDist = d;
        bestId = edge.id;
      }
    }
    return bestId;
  }

  /// Approximate distance from [p] to a cubic bezier S-curve from [a] to [b]
  /// matching the painter's `_bezierPath` logic.
  static double _distToCubicBezier(Offset p, Offset a, Offset b) {
    final dx = (b.dx - a.dx).abs();
    final dy = (b.dy - a.dy).abs();
    final spread = (math.max(dx, dy) * 0.4).clamp(30.0, 200.0);
    final horizontal = dx >= dy;

    final c1 = Offset(
      horizontal ? a.dx + spread : a.dx,
      horizontal ? a.dy : a.dy + spread,
    );
    final c2 = Offset(
      horizontal ? b.dx - spread : b.dx,
      horizontal ? b.dy : b.dy - spread,
    );

    // Sample 16 points along the cubic curve
    double minDist = double.infinity;
    for (int i = 0; i <= 16; i++) {
      final t = i / 16.0;
      final u = 1 - t;
      final x = u * u * u * a.dx +
          3 * u * u * t * c1.dx +
          3 * u * t * t * c2.dx +
          t * t * t * b.dx;
      final y = u * u * u * a.dy +
          3 * u * u * t * c1.dy +
          3 * u * t * t * c2.dy +
          t * t * t * b.dy;
      final d = math.sqrt((p.dx - x) * (p.dx - x) + (p.dy - y) * (p.dy - y));
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  // -------------------------------------------------------------------------
  // Connection mode (edge creation)
  // -------------------------------------------------------------------------

  void startConnecting(String fromNodeId) {
    state = state.copyWith(
      connectingFromId: fromNodeId,
      clearSelectedNode: true,
      clearSelectedEdge: true,
    );
  }

  void cancelConnecting() {
    state = state.copyWith(clearConnectingFrom: true);
  }

  void connectTo(String targetNodeId) {
    final from = state.connectingFromId;
    if (from == null) return;
    addEdge(from, targetNodeId);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final mindMapProvider = StateNotifierProvider.autoDispose<MindMapNotifier, MindMapState>(
  (ref) => MindMapNotifier(ref),
);
