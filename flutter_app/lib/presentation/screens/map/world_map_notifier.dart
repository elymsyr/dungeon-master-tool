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

/// Strategy for merging epochs when a waypoint is deleted.
enum EpochMergeStrategy { merge, keepLeft, keepRight }

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

  // Epoch / date range
  final List<MapEpoch> epochs;
  final List<EpochWaypoint> waypoints;
  final int activeEpochIndex;

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
    this.epochs = const [],
    this.waypoints = const [],
    this.activeEpochIndex = 0,
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
    List<MapEpoch>? epochs,
    List<EpochWaypoint>? waypoints,
    int? activeEpochIndex,
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
      epochs: epochs ?? this.epochs,
      waypoints: waypoints ?? this.waypoints,
      activeEpochIndex: activeEpochIndex ?? this.activeEpochIndex,
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
          pendingParentId == other.pendingParentId &&
          epochs == other.epochs &&
          waypoints == other.waypoints &&
          activeEpochIndex == other.activeEpochIndex;

  @override
  int get hashCode => Object.hash(
        imagePath, pins, timelinePins, hiddenPinTypes,
        showTimeline, showMapPins, showNonPlayerTimeline,
        activeEntityFilters, movingPinId, isLinkMode, pendingParentId,
        epochs, waypoints, activeEpochIndex,
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
    final panX = (data['pan_x'] as num? ?? 0).toDouble();
    final panY = (data['pan_y'] as num? ?? 0).toDouble();
    final scale = (data['scale'] as num? ?? 1.0).toDouble();
    viewTransform.value = WorldMapViewTransform(
      scale: scale,
      panOffset: Offset(panX, panY),
    );

    // --- Epoch support ---
    final rawEpochs = data['epochs'] as List?;
    final rawWaypoints = data['waypoints'] as List?;

    List<MapEpoch> epochs;
    List<EpochWaypoint> waypoints;
    int activeIdx;

    if (rawEpochs != null && rawEpochs.isNotEmpty) {
      epochs = rawEpochs.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        // Parse nested timeline pins with legacy compat
        m['timelinePins'] = _parseRawTimelinePins(
            m['timeline_pins'] as List? ?? m['timelinePins'] as List? ?? [])
            .map((t) => t.toJson())
            .toList();
        // Parse nested pins
        m['pins'] = (m['pins'] as List? ?? [])
            .map((p) => MapPin.fromJson(Map<String, dynamic>.from(p as Map)).toJson())
            .toList();
        m['imagePath'] ??= m['image_path'] ?? '';
        return MapEpoch.fromJson(m);
      }).toList();
      waypoints = (rawWaypoints ?? [])
          .map((w) => EpochWaypoint.fromJson(Map<String, dynamic>.from(w as Map)))
          .toList();
      activeIdx = (data['active_epoch_index'] as int?) ?? 0;
      if (activeIdx >= epochs.length) activeIdx = 0;
    } else {
      // Legacy: wrap existing data into a single epoch
      final pins = _parseRawPins(data['pins'] as List? ?? []);
      final timelinePins =
          _parseRawTimelinePins(data['timeline'] as List? ?? []);
      final imagePath = data['image_path'] as String? ?? '';
      epochs = [
        MapEpoch(
          id: _uuid.v4(),
          imagePath: imagePath,
          pins: pins,
          timelinePins: timelinePins,
        ),
      ];
      waypoints = [];
      activeIdx = 0;
    }

    final active = epochs[activeIdx];
    state = WorldMapState(
      imagePath: active.imagePath,
      pins: active.pins,
      timelinePins: active.timelinePins,
      epochs: epochs,
      waypoints: waypoints,
      activeEpochIndex: activeIdx,
    );
  }

  List<MapPin> _parseRawPins(List<dynamic> raw) {
    return raw
        .map((p) => MapPin.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
  }

  List<TimelinePin> _parseRawTimelinePins(List<dynamic> raw) {
    return raw.map((t) {
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
        final existingParents =
            (map['parent_ids'] as List?)?.cast<String>() ?? [];
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
  }

  Future<void> save() async {
    final campaign = _ref.read(activeCampaignProvider.notifier);
    if (campaign.data == null) return;

    _syncActiveEpoch();

    final vt = viewTransform.value;
    final existing = campaign.data!['map_data'] as Map? ?? {};

    // Legacy compat: root fields from epoch[0]
    final firstEpoch =
        state.epochs.isNotEmpty ? state.epochs[0] : const MapEpoch(id: '');

    campaign.data!['map_data'] = {
      'image_path': firstEpoch.imagePath,
      'pins': firstEpoch.pins.map((p) => p.toJson()).toList(),
      'timeline': firstEpoch.timelinePins.map((t) => t.toJson()).toList(),
      'grid_size': existing['grid_size'] ?? 50,
      'grid_visible': existing['grid_visible'] ?? false,
      'grid_snap': existing['grid_snap'] ?? false,
      'feet_per_cell': existing['feet_per_cell'] ?? 5,
      'fog_state': existing['fog_state'] ?? <String, dynamic>{},
      'drawings': existing['drawings'] ?? <dynamic>[],
      'scale': vt.scale,
      'pan_x': vt.panOffset.dx,
      'pan_y': vt.panOffset.dy,
      // Epoch data
      'epochs': state.epochs
          .map((e) => {
                'id': e.id,
                'image_path': e.imagePath,
                'pins': e.pins.map((p) => p.toJson()).toList(),
                'timeline_pins':
                    e.timelinePins.map((t) => t.toJson()).toList(),
              })
          .toList(),
      'waypoints': state.waypoints
          .map((w) => {'id': w.id, 'label': w.label})
          .toList(),
      'active_epoch_index': state.activeEpochIndex,
    };
    await campaign.save();
  }

  // -------------------------------------------------------------------------
  // Epoch projection helpers
  // -------------------------------------------------------------------------

  /// Syncs projected state back into the epochs list at the active index.
  void _syncActiveEpoch() {
    if (state.epochs.isEmpty) return;
    final idx = state.activeEpochIndex;
    final updated = List<MapEpoch>.from(state.epochs);
    updated[idx] = updated[idx].copyWith(
      imagePath: state.imagePath,
      pins: state.pins,
      timelinePins: state.timelinePins,
    );
    state = state.copyWith(epochs: updated);
  }

  /// Loads an epoch's data into the projected state fields.
  void _loadEpoch(int index) {
    final epoch = state.epochs[index];
    state = state.copyWith(
      imagePath: epoch.imagePath,
      pins: epoch.pins,
      timelinePins: epoch.timelinePins,
      activeEpochIndex: index,
    );
  }

  /// Switches the active epoch: syncs current, loads target.
  void switchEpoch(int index) {
    if (index == state.activeEpochIndex) return;
    if (index < 0 || index >= state.epochs.length) return;
    _syncActiveEpoch();
    _loadEpoch(index);
    _debouncedSave();
  }

  /// Display names for each epoch, derived from adjacent waypoints.
  List<String> get epochNames {
    if (state.epochs.length <= 1) return ['Default'];
    final wps = state.waypoints;
    final names = <String>[];
    for (int i = 0; i < state.epochs.length; i++) {
      final left = i == 0 ? 'Start' : _waypointDisplayLabel(wps[i - 1]);
      final right =
          i >= wps.length ? 'End' : _waypointDisplayLabel(wps[i]);
      names.add('$left \u2013 $right');
    }
    return names;
  }

  /// Short display label for a waypoint.
  static String _waypointDisplayLabel(EpochWaypoint wp) {
    if (wp.label.isEmpty) return '?';
    // If it looks like a number or date, show as-is
    if (RegExp(r'^[\d./-]+$').hasMatch(wp.label)) return wp.label;
    // Otherwise show uppercase initials
    return wp.label
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) save();
    });
  }

  // -------------------------------------------------------------------------
  // Waypoint / Epoch CRUD
  // -------------------------------------------------------------------------

  /// Adds a waypoint at [insertIndex] (0-based within waypoints list).
  /// Splits the epoch that contains this position into two.
  void addWaypoint(
    int insertIndex,
    String label, {
    bool copyPins = false,
    bool copyTimelinePins = false,
  }) {
    _syncActiveEpoch();

    final wp = EpochWaypoint(id: _uuid.v4(), label: label);
    final updatedWps = List<EpochWaypoint>.from(state.waypoints)
      ..insert(insertIndex, wp);

    // The waypoint at insertIndex splits epochIndex = insertIndex into two.
    // Left epoch keeps the original, right epoch is new.
    final epochIdx = insertIndex; // epoch to split
    final original = state.epochs[epochIdx];

    MapEpoch leftEpoch;
    MapEpoch rightEpoch;

    if (copyPins && copyTimelinePins) {
      leftEpoch = original.copyWith(id: _uuid.v4());
      rightEpoch = original.copyWith(
        id: _uuid.v4(),
        pins: _clonePins(original.pins),
        timelinePins: _cloneTimelinePins(original.timelinePins),
      );
    } else if (copyPins) {
      leftEpoch = original.copyWith(id: _uuid.v4());
      rightEpoch = MapEpoch(
        id: _uuid.v4(),
        imagePath: original.imagePath,
        pins: _clonePins(original.pins),
      );
    } else if (copyTimelinePins) {
      leftEpoch = original.copyWith(id: _uuid.v4());
      rightEpoch = MapEpoch(
        id: _uuid.v4(),
        imagePath: original.imagePath,
        timelinePins: _cloneTimelinePins(original.timelinePins),
      );
    } else {
      leftEpoch = original.copyWith(id: _uuid.v4());
      rightEpoch = MapEpoch(id: _uuid.v4(), imagePath: original.imagePath);
    }

    final updatedEpochs = List<MapEpoch>.from(state.epochs)
      ..removeAt(epochIdx)
      ..insert(epochIdx, leftEpoch)
      ..insert(epochIdx + 1, rightEpoch);

    // Adjust activeEpochIndex if needed
    var newActive = state.activeEpochIndex;
    if (newActive > epochIdx) {
      newActive += 1; // shifted right by the split
    }

    state = state.copyWith(
      waypoints: updatedWps,
      epochs: updatedEpochs,
      activeEpochIndex: newActive,
    );
    // Re-project in case active epoch shifted
    _loadEpoch(state.activeEpochIndex);
    _debouncedSave();
  }

  /// Deletes a waypoint and merges its adjacent epochs.
  void deleteWaypoint(int wpIndex, EpochMergeStrategy strategy) {
    if (wpIndex < 0 || wpIndex >= state.waypoints.length) return;
    _syncActiveEpoch();

    final leftIdx = wpIndex;     // epoch to the left of the waypoint
    final rightIdx = wpIndex + 1; // epoch to the right

    final leftEpoch = state.epochs[leftIdx];
    final rightEpoch = state.epochs[rightIdx];

    MapEpoch merged;
    switch (strategy) {
      case EpochMergeStrategy.merge:
        merged = MapEpoch(
          id: _uuid.v4(),
          imagePath: leftEpoch.imagePath.isNotEmpty
              ? leftEpoch.imagePath
              : rightEpoch.imagePath,
          pins: [...leftEpoch.pins, ..._clonePins(rightEpoch.pins)],
          timelinePins: [
            ...leftEpoch.timelinePins,
            ..._cloneTimelinePins(rightEpoch.timelinePins),
          ],
        );
      case EpochMergeStrategy.keepLeft:
        merged = leftEpoch.copyWith(id: _uuid.v4());
      case EpochMergeStrategy.keepRight:
        merged = rightEpoch.copyWith(id: _uuid.v4());
    }

    final updatedEpochs = List<MapEpoch>.from(state.epochs)
      ..removeAt(rightIdx)
      ..removeAt(leftIdx)
      ..insert(leftIdx, merged);

    final updatedWps = List<EpochWaypoint>.from(state.waypoints)
      ..removeAt(wpIndex);

    // Adjust active index
    var newActive = state.activeEpochIndex;
    if (newActive == rightIdx) {
      newActive = leftIdx;
    } else if (newActive > rightIdx) {
      newActive -= 1;
    }
    if (newActive >= updatedEpochs.length) {
      newActive = updatedEpochs.length - 1;
    }

    state = state.copyWith(
      waypoints: updatedWps,
      epochs: updatedEpochs,
      activeEpochIndex: newActive,
    );
    _loadEpoch(newActive);
    _debouncedSave();
  }

  /// Updates a waypoint's label.
  void updateWaypointLabel(int wpIndex, String label) {
    if (wpIndex < 0 || wpIndex >= state.waypoints.length) return;
    final updated = List<EpochWaypoint>.from(state.waypoints);
    updated[wpIndex] = updated[wpIndex].copyWith(label: label);
    state = state.copyWith(waypoints: updated);
    _debouncedSave();
  }

  /// Copies a MapPin from the active epoch to a target epoch (new UUID).
  void copyPinToEpoch(String pinId, int targetEpochIndex) {
    _syncActiveEpoch();
    final pin = state.pins.where((p) => p.id == pinId).firstOrNull;
    if (pin == null) return;
    if (targetEpochIndex < 0 || targetEpochIndex >= state.epochs.length) return;

    final copy = pin.copyWith(id: _uuid.v4());
    final updatedEpochs = List<MapEpoch>.from(state.epochs);
    final target = updatedEpochs[targetEpochIndex];
    updatedEpochs[targetEpochIndex] = target.copyWith(
      pins: [...target.pins, copy],
    );
    state = state.copyWith(epochs: updatedEpochs);
    _debouncedSave();
  }

  /// Copies a TimelinePin from the active epoch to a target epoch (new UUID).
  void copyTimelinePinToEpoch(String tpinId, int targetEpochIndex) {
    _syncActiveEpoch();
    final tpin =
        state.timelinePins.where((t) => t.id == tpinId).firstOrNull;
    if (tpin == null) return;
    if (targetEpochIndex < 0 || targetEpochIndex >= state.epochs.length) return;

    final copy = tpin.copyWith(id: _uuid.v4(), parentIds: []);
    final updatedEpochs = List<MapEpoch>.from(state.epochs);
    final target = updatedEpochs[targetEpochIndex];
    updatedEpochs[targetEpochIndex] = target.copyWith(
      timelinePins: [...target.timelinePins, copy],
    );
    state = state.copyWith(epochs: updatedEpochs);
    _debouncedSave();
  }

  List<MapPin> _clonePins(List<MapPin> pins) =>
      pins.map((p) => p.copyWith(id: _uuid.v4())).toList();

  List<TimelinePin> _cloneTimelinePins(List<TimelinePin> tpins) {
    // Build old→new ID mapping so parentIds can be remapped
    final idMap = <String, String>{};
    for (final tp in tpins) {
      idMap[tp.id] = _uuid.v4();
    }
    return tpins.map((tp) {
      return tp.copyWith(
        id: idMap[tp.id]!,
        parentIds:
            tp.parentIds.map((pid) => idMap[pid] ?? pid).toList(),
      );
    }).toList();
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
      entityIds: List<String>.from(parent?.entityIds ?? []),
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
