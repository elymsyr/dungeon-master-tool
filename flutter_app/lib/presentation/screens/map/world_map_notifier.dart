import 'dart:async';
import 'dart:collection';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../domain/entities/map_data.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// View transform (lightweight)
// ---------------------------------------------------------------------------

class WorldMapViewTransform {
  final double scale;
  final Offset panOffset;
  const WorldMapViewTransform({this.scale = 1.0, this.panOffset = Offset.zero});
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class WorldMapState {
  final String imagePath;
  final List<MapPin> pins;
  final List<TimelinePin> timelinePins;
  final Set<String> hiddenPinTypes;

  // Timeline / visibility
  final bool showTimeline;
  final bool showMapPins;
  final bool showNonPlayerTimeline;

  // Entity filter
  final Set<String> activeEntityFilters;

  // Interaction modes
  final String? movingPinId;
  final String? movingPinType; // 'pin' | 'timeline'
  final bool isLinkMode;
  final String? pendingParentId;

  const WorldMapState({
    this.imagePath = '',
    this.pins = const [],
    this.timelinePins = const [],
    this.hiddenPinTypes = const {},
    this.showTimeline = false,
    this.showMapPins = true,
    this.showNonPlayerTimeline = false,
    this.activeEntityFilters = const {},
    this.movingPinId,
    this.movingPinType,
    this.isLinkMode = false,
    this.pendingParentId,
  });

  WorldMapState copyWith({
    String? imagePath,
    List<MapPin>? pins,
    List<TimelinePin>? timelinePins,
    Set<String>? hiddenPinTypes,
    bool? showTimeline,
    bool? showMapPins,
    bool? showNonPlayerTimeline,
    Set<String>? activeEntityFilters,
    String? movingPinId,
    String? movingPinType,
    bool? isLinkMode,
    String? pendingParentId,
    bool clearMovingPin = false,
    bool clearPendingParent = false,
  }) {
    return WorldMapState(
      imagePath: imagePath ?? this.imagePath,
      pins: pins ?? this.pins,
      timelinePins: timelinePins ?? this.timelinePins,
      hiddenPinTypes: hiddenPinTypes ?? this.hiddenPinTypes,
      showTimeline: showTimeline ?? this.showTimeline,
      showMapPins: showMapPins ?? this.showMapPins,
      showNonPlayerTimeline: showNonPlayerTimeline ?? this.showNonPlayerTimeline,
      activeEntityFilters: activeEntityFilters ?? this.activeEntityFilters,
      movingPinId: clearMovingPin ? null : (movingPinId ?? this.movingPinId),
      movingPinType: clearMovingPin ? null : (movingPinType ?? this.movingPinType),
      isLinkMode: isLinkMode ?? this.isLinkMode,
      pendingParentId: clearPendingParent ? null : (pendingParentId ?? this.pendingParentId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldMapState &&
          imagePath == other.imagePath &&
          pins == other.pins &&
          timelinePins == other.timelinePins &&
          hiddenPinTypes == other.hiddenPinTypes &&
          showTimeline == other.showTimeline &&
          showMapPins == other.showMapPins &&
          showNonPlayerTimeline == other.showNonPlayerTimeline &&
          activeEntityFilters == other.activeEntityFilters &&
          movingPinId == other.movingPinId &&
          isLinkMode == other.isLinkMode &&
          pendingParentId == other.pendingParentId;

  @override
  int get hashCode => Object.hash(
        imagePath, pins, timelinePins, hiddenPinTypes,
        showTimeline, showMapPins, showNonPlayerTimeline,
        activeEntityFilters, movingPinId, isLinkMode, pendingParentId,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class WorldMapNotifier extends StateNotifier<WorldMapState> {
  final Ref _ref;

  final ValueNotifier<WorldMapViewTransform> viewTransform =
      ValueNotifier<WorldMapViewTransform>(const WorldMapViewTransform());

  // Scale gesture tracking
  double _scaleBase = 1.0;
  Offset _focalBase = Offset.zero;
  Offset _panBase = Offset.zero;

  Timer? _saveTimer;

  WorldMapNotifier(this._ref) : super(const WorldMapState());

  @override
  void dispose() {
    _saveTimer?.cancel();
    viewTransform.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Init / Save
  // -------------------------------------------------------------------------

  void init(Map<String, dynamic> data) {
    final rawPins = (data['pins'] as List? ?? []);
    final pins = rawPins
        .map((p) => MapPin.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    // Parse timeline pins (legacy-compatible)
    final rawTimeline = (data['timeline'] as List? ?? []);
    final timelinePins = rawTimeline.map((t) {
      final map = Map<String, dynamic>.from(t as Map);
      // Handle legacy 'entity_id' → 'entityIds'
      if (map.containsKey('entity_id') && !map.containsKey('entityIds')) {
        final eid = map['entity_id'] as String?;
        if (eid != null && eid.isNotEmpty) {
          map['entityIds'] = [eid];
        }
      }
      // Handle legacy 'parent_id' → 'parentIds'
      if (map.containsKey('parent_id') && !map.containsKey('parentIds')) {
        final pid = map['parent_id'] as String?;
        final existingParents = (map['parent_ids'] as List?)?.cast<String>() ?? [];
        if (pid != null && pid.isNotEmpty && !existingParents.contains(pid)) {
          map['parentIds'] = [...existingParents, pid];
        }
      }
      // Snake_case → camelCase aliases
      map['entityIds'] ??= map['entity_ids'];
      map['sessionId'] ??= map['session_id'];
      map['parentIds'] ??= map['parent_ids'];
      return TimelinePin.fromJson(map);
    }).toList();

    final panX = (data['pan_x'] as num? ?? 0).toDouble();
    final panY = (data['pan_y'] as num? ?? 0).toDouble();
    final scale = (data['scale'] as num? ?? 1.0).toDouble();
    viewTransform.value = WorldMapViewTransform(
      scale: scale,
      panOffset: Offset(panX, panY),
    );

    state = WorldMapState(
      imagePath: data['image_path'] as String? ?? '',
      pins: pins,
      timelinePins: timelinePins,
    );
  }

  Future<void> save() async {
    final campaign = _ref.read(activeCampaignProvider.notifier);
    if (campaign.data == null) return;

    final vt = viewTransform.value;
    final existing = campaign.data!['map_data'] as Map? ?? {};
    campaign.data!['map_data'] = {
      'image_path': state.imagePath,
      'pins': state.pins.map((p) => p.toJson()).toList(),
      'timeline': state.timelinePins.map((t) => t.toJson()).toList(),
      'grid_size': existing['grid_size'] ?? 50,
      'grid_visible': existing['grid_visible'] ?? false,
      'grid_snap': existing['grid_snap'] ?? false,
      'feet_per_cell': existing['feet_per_cell'] ?? 5,
      'fog_state': existing['fog_state'] ?? <String, dynamic>{},
      'drawings': existing['drawings'] ?? <dynamic>[],
      'scale': vt.scale,
      'pan_x': vt.panOffset.dx,
      'pan_y': vt.panOffset.dy,
    };
    await campaign.save();
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) save();
    });
  }

  // -------------------------------------------------------------------------
  // Map image
  // -------------------------------------------------------------------------

  Future<void> pickMapImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    state = state.copyWith(imagePath: path);
    viewTransform.value = const WorldMapViewTransform();
    _debouncedSave();
  }

  // -------------------------------------------------------------------------
  // Pan / Zoom (manual GestureDetector — same pattern as BattleMap)
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
    viewTransform.value = WorldMapViewTransform(scale: newScale, panOffset: newPan);
  }

  void onScaleEnd() {
    _debouncedSave();
  }

  void zoomAtPoint(Offset localPos, double scrollDelta) {
    const zoomFactor = 0.1;
    final vt = viewTransform.value;
    final factor = scrollDelta > 0 ? 1 - zoomFactor : 1 + zoomFactor;
    final newScale = (vt.scale * factor).clamp(0.05, 10.0);
    final scaleRatio = newScale / vt.scale;
    final newPan = localPos - (localPos - vt.panOffset) * scaleRatio;
    viewTransform.value = WorldMapViewTransform(scale: newScale, panOffset: newPan);
  }

  void resetView() {
    viewTransform.value = const WorldMapViewTransform();
    _debouncedSave();
  }

  // -------------------------------------------------------------------------
  // Pin CRUD
  // -------------------------------------------------------------------------

  String addPin(
    Offset canvasPos, {
    String pinType = 'default',
    String? entityId,
    String label = '',
    String color = '',
  }) {
    final id = _uuid.v4();
    final pin = MapPin(
      id: id,
      x: canvasPos.dx,
      y: canvasPos.dy,
      label: label,
      pinType: pinType,
      entityId: entityId,
      color: color,
    );
    state = state.copyWith(pins: [...state.pins, pin]);
    _debouncedSave();
    return id;
  }

  void updatePin(
    String id, {
    Offset? pos,
    String? label,
    String? pinType,
  }) {
    final idx = state.pins.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final updated = List<MapPin>.from(state.pins);
    final p = updated[idx];
    updated[idx] = p.copyWith(
      x: pos?.dx ?? p.x,
      y: pos?.dy ?? p.y,
      label: label ?? p.label,
      pinType: pinType ?? p.pinType,
    );
    state = state.copyWith(pins: updated);
    _debouncedSave();
  }

  void updatePinNote(String id, String note) {
    final idx = state.pins.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final updated = List<MapPin>.from(state.pins);
    updated[idx] = updated[idx].copyWith(note: note);
    state = state.copyWith(pins: updated);
    _debouncedSave();
  }

  void updatePinColor(String id, String color) {
    final idx = state.pins.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final updated = List<MapPin>.from(state.pins);
    updated[idx] = updated[idx].copyWith(color: color);
    state = state.copyWith(pins: updated);
    _debouncedSave();
  }

  void deletePin(String id) {
    state = state.copyWith(
      pins: state.pins.where((p) => p.id != id).toList(),
    );
    _debouncedSave();
  }

  void togglePinTypeVisibility(String pinType) {
    final hidden = Set<String>.from(state.hiddenPinTypes);
    if (hidden.contains(pinType)) {
      hidden.remove(pinType);
    } else {
      hidden.add(pinType);
    }
    state = state.copyWith(hiddenPinTypes: hidden);
  }

  // -------------------------------------------------------------------------
  // Timeline CRUD
  // -------------------------------------------------------------------------

  String addTimelinePin(
    Offset canvasPos, {
    int day = 1,
    String note = '',
    String color = '#42a5f5',
    List<String> entityIds = const [],
    String? sessionId,
    String? parentId,
  }) {
    final id = _uuid.v4();
    final pin = TimelinePin(
      id: id,
      x: canvasPos.dx,
      y: canvasPos.dy,
      day: day,
      note: note,
      color: color,
      entityIds: entityIds,
      sessionId: sessionId,
      parentIds: parentId != null ? [parentId] : [],
    );
    state = state.copyWith(timelinePins: [...state.timelinePins, pin]);
    _debouncedSave();
    return id;
  }

  void updateTimelinePin(
    String id, {
    Offset? pos,
    int? day,
    String? note,
    String? color,
    List<String>? entityIds,
    String? sessionId,
  }) {
    final idx = state.timelinePins.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final updated = List<TimelinePin>.from(state.timelinePins);
    final t = updated[idx];
    updated[idx] = t.copyWith(
      x: pos?.dx ?? t.x,
      y: pos?.dy ?? t.y,
      day: day ?? t.day,
      note: note ?? t.note,
      color: color ?? t.color,
      entityIds: entityIds ?? t.entityIds,
      sessionId: sessionId ?? t.sessionId,
    );
    state = state.copyWith(timelinePins: updated);
    _debouncedSave();
  }

  void deleteTimelinePin(String id) {
    // Remove from children's parentIds
    final updated = state.timelinePins
        .where((t) => t.id != id)
        .map((t) {
          if (t.parentIds.contains(id)) {
            return t.copyWith(
              parentIds: t.parentIds.where((p) => p != id).toList(),
            );
          }
          return t;
        })
        .toList();
    state = state.copyWith(timelinePins: updated);
    _debouncedSave();
  }

  void linkTimelinePins(String parentId, String childId) {
    if (parentId == childId) return;
    final idx = state.timelinePins.indexWhere((t) => t.id == childId);
    if (idx < 0) return;
    final child = state.timelinePins[idx];
    if (child.parentIds.contains(parentId)) return;
    final updated = List<TimelinePin>.from(state.timelinePins);
    updated[idx] = child.copyWith(
      parentIds: [...child.parentIds, parentId],
    );
    state = state.copyWith(timelinePins: updated);
    _debouncedSave();
  }

  /// Propagate color through the timeline chain (BFS).
  void updateTimelineChainColor(String startId, String color) {
    final pinMap = {for (final t in state.timelinePins) t.id: t};
    final visited = <String>{};
    final queue = Queue<String>()..add(startId);

    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      if (visited.contains(id)) continue;
      visited.add(id);

      // Find children (pins where parentIds contains id)
      for (final t in state.timelinePins) {
        if (t.parentIds.contains(id) && !visited.contains(t.id)) {
          queue.add(t.id);
        }
      }
      // Find parents
      final pin = pinMap[id];
      if (pin != null) {
        for (final pid in pin.parentIds) {
          if (!visited.contains(pid)) queue.add(pid);
        }
      }
    }

    final updated = state.timelinePins.map((t) {
      if (visited.contains(t.id)) {
        return t.copyWith(color: color);
      }
      return t;
    }).toList();
    state = state.copyWith(timelinePins: updated);
    _debouncedSave();
  }

  // -------------------------------------------------------------------------
  // Move mode (pin repositioning)
  // -------------------------------------------------------------------------

  void startPinMoveMode(String pinId, String pinType) {
    state = state.copyWith(
      movingPinId: pinId,
      movingPinType: pinType,
      isLinkMode: false,
      clearPendingParent: true,
    );
  }

  void completePinMove(Offset canvasPos) {
    final id = state.movingPinId;
    final type = state.movingPinType;
    if (id == null || type == null) return;

    if (type == 'timeline') {
      updateTimelinePin(id, pos: canvasPos);
    } else {
      updatePin(id, pos: canvasPos);
    }
    state = state.copyWith(clearMovingPin: true);
  }

  void cancelMoveMode() {
    state = state.copyWith(clearMovingPin: true);
  }

  // -------------------------------------------------------------------------
  // Link mode (timeline pin linking)
  // -------------------------------------------------------------------------

  void startLinkMode(String parentTimelinePinId) {
    state = state.copyWith(
      isLinkMode: true,
      pendingParentId: parentTimelinePinId,
      clearMovingPin: true,
    );
  }

  void handleLinkToExisting(String targetPinId) {
    final parentId = state.pendingParentId;
    if (parentId == null) return;
    linkTimelinePins(parentId, targetPinId);
    state = state.copyWith(
      isLinkMode: false,
      clearPendingParent: true,
    );
  }

  void handleLinkToNew(Offset canvasPos) {
    final parentId = state.pendingParentId;
    if (parentId == null) return;
    final parent = state.timelinePins.where((t) => t.id == parentId).firstOrNull;
    addTimelinePin(
      canvasPos,
      day: parent?.day ?? 1,
      note: 'New Event',
      color: parent?.color ?? '#42a5f5',
      parentId: parentId,
    );
    state = state.copyWith(
      isLinkMode: false,
      clearPendingParent: true,
    );
  }

  void cancelLinkMode() {
    state = state.copyWith(
      isLinkMode: false,
      clearPendingParent: true,
    );
  }

  // -------------------------------------------------------------------------
  // Visibility / Filter toggles
  // -------------------------------------------------------------------------

  void toggleTimelineVisibility() {
    state = state.copyWith(showTimeline: !state.showTimeline);
  }

  void toggleMapPinsVisibility() {
    state = state.copyWith(showMapPins: !state.showMapPins);
  }

  void toggleNonPlayerTimeline() {
    state = state.copyWith(
        showNonPlayerTimeline: !state.showNonPlayerTimeline);
  }

  void setEntityFilter(Set<String> entityIds) {
    state = state.copyWith(activeEntityFilters: entityIds);
  }

  void clearEntityFilter() {
    state = state.copyWith(activeEntityFilters: const {});
  }

  /// Visible map pins (filtered by type + entity filter).
  List<MapPin> get visiblePins {
    if (!state.showMapPins) return [];
    var pins = state.pins.where(
        (p) => !state.hiddenPinTypes.contains(p.pinType));
    if (state.activeEntityFilters.isNotEmpty) {
      pins = pins.where((p) =>
          p.entityId != null &&
          state.activeEntityFilters.contains(p.entityId));
    }
    return pins.toList();
  }

  /// Visible timeline pins (filtered by entity filter).
  List<TimelinePin> get visibleTimelinePins {
    if (!state.showTimeline) return [];
    var pins = state.timelinePins;
    if (state.activeEntityFilters.isNotEmpty) {
      pins = pins
          .where((t) =>
              t.entityIds.isEmpty ||
              t.entityIds.any(
                  (e) => state.activeEntityFilters.contains(e)))
          .toList();
    }
    return pins;
  }

  // -------------------------------------------------------------------------
  // Coordinate conversion
  // -------------------------------------------------------------------------

  Offset screenToCanvas(Offset screenPt) {
    final vt = viewTransform.value;
    return (screenPt - vt.panOffset) / vt.scale;
  }

  Offset canvasToScreen(Offset canvasPt) {
    final vt = viewTransform.value;
    return canvasPt * vt.scale + vt.panOffset;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final worldMapProvider = StateNotifierProvider.autoDispose<WorldMapNotifier, WorldMapState>(
  (ref) => WorldMapNotifier(ref),
);
