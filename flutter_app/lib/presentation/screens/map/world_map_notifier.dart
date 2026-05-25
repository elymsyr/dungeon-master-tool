import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/entity_provider.dart';
import '../../../application/services/asset_ref_resolver.dart';
import '../../../application/services/map_image_upload.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../application/services/undo_redo_mixin.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/map_data.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../../domain/value_objects/media_kind.dart';
import '../../widgets/quota_snackbar.dart';

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

/// Strategy for merging eras when a waypoint is deleted.
enum EraMergeStrategy { merge, keepLeft, keepRight }

/// Pin display size preset.
enum PinSize { small, medium, large }

class WorldMapState {
  final String imagePath;
  final List<MapPin> pins;
  final List<TimelinePin> timelinePins;
  final Set<String> hiddenPinTypes;

  // Pin display size
  final PinSize pinSize;

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

  // Era / date range
  final List<MapEra> eras;
  final List<EraWaypoint> waypoints;
  final int activeEraIndex;
  final String eraStartLabel;
  final String eraEndLabel;

  // Drill-in: location IDs deepest-last. Empty = root world map.
  // Drill pins are RAM-only in PR-3; persistence ships in PR-4.
  final List<String> locationStack;

  const WorldMapState({
    this.imagePath = '',
    this.pins = const [],
    this.timelinePins = const [],
    this.hiddenPinTypes = const {},
    this.pinSize = PinSize.medium,
    this.showTimeline = false,
    this.showMapPins = true,
    this.showNonPlayerTimeline = false,
    this.activeEntityFilters = const {},
    this.movingPinId,
    this.movingPinType,
    this.isLinkMode = false,
    this.pendingParentId,
    this.eras = const [],
    this.waypoints = const [],
    this.activeEraIndex = 0,
    this.eraStartLabel = 'Start',
    this.eraEndLabel = 'End',
    this.locationStack = const [],
  });

  WorldMapState copyWith({
    String? imagePath,
    List<MapPin>? pins,
    List<TimelinePin>? timelinePins,
    Set<String>? hiddenPinTypes,
    PinSize? pinSize,
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
    List<MapEra>? eras,
    List<EraWaypoint>? waypoints,
    int? activeEraIndex,
    String? eraStartLabel,
    String? eraEndLabel,
    List<String>? locationStack,
  }) {
    return WorldMapState(
      imagePath: imagePath ?? this.imagePath,
      pins: pins ?? this.pins,
      timelinePins: timelinePins ?? this.timelinePins,
      hiddenPinTypes: hiddenPinTypes ?? this.hiddenPinTypes,
      pinSize: pinSize ?? this.pinSize,
      showTimeline: showTimeline ?? this.showTimeline,
      showMapPins: showMapPins ?? this.showMapPins,
      showNonPlayerTimeline: showNonPlayerTimeline ?? this.showNonPlayerTimeline,
      activeEntityFilters: activeEntityFilters ?? this.activeEntityFilters,
      movingPinId: clearMovingPin ? null : (movingPinId ?? this.movingPinId),
      movingPinType: clearMovingPin ? null : (movingPinType ?? this.movingPinType),
      isLinkMode: isLinkMode ?? this.isLinkMode,
      pendingParentId: clearPendingParent ? null : (pendingParentId ?? this.pendingParentId),
      eras: eras ?? this.eras,
      waypoints: waypoints ?? this.waypoints,
      activeEraIndex: activeEraIndex ?? this.activeEraIndex,
      eraStartLabel: eraStartLabel ?? this.eraStartLabel,
      eraEndLabel: eraEndLabel ?? this.eraEndLabel,
      locationStack: locationStack ?? this.locationStack,
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
          pinSize == other.pinSize &&
          showTimeline == other.showTimeline &&
          showMapPins == other.showMapPins &&
          showNonPlayerTimeline == other.showNonPlayerTimeline &&
          activeEntityFilters == other.activeEntityFilters &&
          movingPinId == other.movingPinId &&
          isLinkMode == other.isLinkMode &&
          pendingParentId == other.pendingParentId &&
          eras == other.eras &&
          waypoints == other.waypoints &&
          activeEraIndex == other.activeEraIndex &&
          eraStartLabel == other.eraStartLabel &&
          eraEndLabel == other.eraEndLabel &&
          _listEquals(locationStack, other.locationStack);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        imagePath, pins, timelinePins, hiddenPinTypes, pinSize,
        showTimeline, showMapPins, showNonPlayerTimeline,
        activeEntityFilters, movingPinId, isLinkMode, pendingParentId,
        eras, waypoints, activeEraIndex, eraStartLabel, eraEndLabel,
        Object.hashAll(locationStack),
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class WorldMapNotifier extends StateNotifier<WorldMapState>
    with UndoRedoMixin<WorldMapState> {
  final Ref _ref;

  final ValueNotifier<WorldMapViewTransform> viewTransform =
      ValueNotifier<WorldMapViewTransform>(const WorldMapViewTransform());

  // F2: Viewport-cull recomputation tick. Bumped at gesture-END / discrete
  // zoom events; the pin layer rebuilds its filtered list against the
  // current viewTransform.value. During active scale/pan ticks viewTransform
  // updates without bumping cullTick, so the pin Widget tree is not
  // reinstantiated 60fps — Transform handles smooth visual update via the
  // matrix alone (F1 child-slot pattern).
  final ValueNotifier<int> cullTick = ValueNotifier<int>(0);

  // F4: Single source of truth for the timeline pin under cursor. Per-pin
  // MouseRegion writes here; one canvas-level ValueListenableBuilder renders
  // the hover card. Drops 100x setState fanout vs per-pin local state.
  final ValueNotifier<String?> hoveredTimelinePinId =
      ValueNotifier<String?>(null);

  /// Pin ID under the mouse cursor (desktop) or last tapped (mobile) for a
  /// location-linked pin → drives [LocationPinPreviewCard] overlay.
  final ValueNotifier<String?> hoveredLocationPinId =
      ValueNotifier<String?>(null);

  // Viewport size for fit-to-image calculations
  Size _viewportSize = Size.zero;

  // Scale gesture tracking
  double _scaleBase = 1.0;
  Offset _focalBase = Offset.zero;
  Offset _panBase = Offset.zero;

  // Image dimension cache keyed by file path. Decode is GPU-bound and cannot
  // run on a worker isolate (ui.Image is not transferable), so the win is
  // skipping the redundant decode on resetView / repeat _fitImageInViewport.
  final Map<String, Size> _imageSizeCache = <String, Size>{};

  // Guard: until [init] runs, `state` is the empty default. Syncing that
  // back into campaign data would wipe the real saved map (deactivate then
  // persists it). [syncToCampaignData] early-returns while this is false.
  bool _initialized = false;
  String? _initializedWorldId;
  /// İlk [init] çağrısı gerçek (non-empty) `map_data` ile mi yapıldı?
  /// Cross-device açılışta yerel boş + cloud pending durumunda false kalır
  /// ve [syncToCampaignData] kullanıcı içerik eklemediği sürece sessiz
  /// döner — aksi halde deactivate boş map'i bulut'a yazıp tüm cihazlara
  /// "kayıp harita" olarak yayılırdı. Kullanıcı pin/görsel/era eklerse
  /// `hasContent` true olur → save serbest.
  bool _initializedWithContent = false;

  WorldMapNotifier(this._ref) : super(const WorldMapState());

  @override
  void dispose() {
    viewTransform.dispose();
    cullTick.dispose();
    hoveredTimelinePinId.dispose();
    hoveredLocationPinId.dispose();
    disposeUndoRedo();
    super.dispose();
  }

  /// Bumps [cullTick] to trigger viewport-culling recomputation on the pin
  /// layer. Fired at gesture-END / discrete zoom / view-fit transitions.
  void _bumpCullTick() {
    cullTick.value++;
  }

  // -------------------------------------------------------------------------
  // Init / Save
  // -------------------------------------------------------------------------

  /// Whether [init] has already populated this notifier for [worldId].
  /// The screen checks this before re-initialising so a `campaignRevision`
  /// bump (unrelated entity edit, etc.) doesn't clobber live map state.
  bool isInitializedFor(String? worldId) =>
      _initialized && _initializedWorldId == worldId;

  /// True when the notifier carries actual map content (image, pins or
  /// multi-era data). Used by the screen to allow a re-init when the
  /// first init ran with empty data (cross-device open before cloud sync
  /// arrived) and the underlying `data['map_data']` has since been filled.
  /// Single default era with no pins/image counts as empty.
  bool get hasContent {
    if (state.imagePath.isNotEmpty) return true;
    if (state.pins.isNotEmpty) return true;
    if (state.timelinePins.isNotEmpty) return true;
    if (state.eras.length > 1) return true;
    if (state.eras.length == 1) {
      final ep = state.eras.first;
      if (ep.imagePath.isNotEmpty) return true;
      if (ep.pins.isNotEmpty) return true;
      if (ep.timelinePins.isNotEmpty) return true;
    }
    return false;
  }

  void init(Map<String, dynamic> data, {String? worldId}) {
    final panX = (data['pan_x'] as num? ?? 0).toDouble();
    final panY = (data['pan_y'] as num? ?? 0).toDouble();
    final scale = (data['scale'] as num? ?? 1.0).toDouble();
    viewTransform.value = WorldMapViewTransform(
      scale: scale,
      panOffset: Offset(panX, panY),
    );
    _bumpCullTick();

    // --- Era support (legacy key `epochs` still read for backwards-compat) ---
    final rawEras = (data['eras'] ?? data['epochs']) as List?;
    final rawWaypoints = data['waypoints'] as List?;

    List<MapEra> eras;
    List<EraWaypoint> waypoints;
    int activeIdx;

    if (rawEras != null && rawEras.isNotEmpty) {
      eras = rawEras.map((e) {
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
        // Per-location nested maps (PR-4). Snake-case alias `location_maps`.
        final rawLocMaps =
            (m['location_maps'] ?? m['locationMaps']) as Map?;
        if (rawLocMaps != null) {
          final parsed = <String, dynamic>{};
          for (final entry in rawLocMaps.entries) {
            final inner = Map<String, dynamic>.from(entry.value as Map);
            inner['pins'] = _parseRawPins(inner['pins'] as List? ?? [])
                .map((p) => p.toJson())
                .toList();
            inner['timelinePins'] = _parseRawTimelinePins(
                    inner['timeline_pins'] as List? ??
                        inner['timelinePins'] as List? ??
                        [])
                .map((t) => t.toJson())
                .toList();
            parsed[entry.key.toString()] = inner;
          }
          m['locationMaps'] = parsed;
          m.remove('location_maps');
        }
        return MapEra.fromJson(m);
      }).toList();
      waypoints = (rawWaypoints ?? [])
          .map((w) => EraWaypoint.fromJson(Map<String, dynamic>.from(w as Map)))
          .toList();
      activeIdx = (data['active_era_index'] ?? data['active_epoch_index']) as int? ?? 0;
      if (activeIdx >= eras.length) activeIdx = 0;
    } else {
      // Legacy: wrap existing data into a single era
      final pins = _parseRawPins(data['pins'] as List? ?? []);
      final timelinePins =
          _parseRawTimelinePins(data['timeline'] as List? ?? []);
      final imagePath = data['image_path'] as String? ?? '';
      eras = [
        MapEra(
          id: _uuid.v4(),
          imagePath: imagePath,
          pins: pins,
          timelinePins: timelinePins,
        ),
      ];
      waypoints = [];
      activeIdx = 0;
    }

    final pinSizeStr = data['pin_size'] as String?;
    final pinSize = PinSize.values.where((e) => e.name == pinSizeStr).firstOrNull
        ?? PinSize.medium;
    final eraStartLabel =
        (data['era_start_label'] ?? data['epoch_start_label']) as String? ??
            'Start';
    final eraEndLabel =
        (data['era_end_label'] ?? data['epoch_end_label']) as String? ?? 'End';

    final active = eras[activeIdx];
    state = WorldMapState(
      imagePath: active.imagePath,
      pins: active.pins,
      timelinePins: active.timelinePins,
      eras: eras,
      waypoints: waypoints,
      activeEraIndex: activeIdx,
      pinSize: pinSize,
      eraStartLabel: eraStartLabel,
      eraEndLabel: eraEndLabel,
    );
    clearUndoRedo();
    _initialized = true;
    _initializedWorldId = worldId;
    // Init'in gerçek veriyle yapılıp yapılmadığını şimdi tespit et — kullanıcı
    // sonradan içerik eklerse `hasContent` true olur, ama "init geldi mi"
    // sinyalini bağımsız tut.
    _initializedWithContent = hasContent;
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

  void syncToCampaignData() {
    // Not initialised → `state` is the empty default. Writing it into
    // campaign data would wipe the saved map (deactivate then persists it).
    if (!_initialized) return;
    // Cross-device clobber guard: init boş veriyle yapıldı VE kullanıcı
    // bir şey eklemedi → bu state'in canonicalliği belirsiz; cloud sync
    // henüz arrive etmemiş olabilir. Yazma, sessiz dön.
    if (!_initializedWithContent && !hasContent) return;
    final campaign = _ref.read(activeCampaignProvider.notifier);
    if (campaign.data == null) return;

    _syncProjection();

    final vt = viewTransform.value;
    final existing = campaign.data!['map_data'] as Map? ?? {};

    // Legacy compat: root fields from eras[0]
    final firstEra =
        state.eras.isNotEmpty ? state.eras[0] : const MapEra(id: '');

    // Viewport (pan/zoom) — DM-local motion class. Sibling key `map_view`
    // out of `map_data` so content sync (pins/waypoints) and viewport
    // local-save use different buffer keys + different cloud semantics.
    campaign.data!['map_view'] = <String, dynamic>{
      'scale': vt.scale,
      'pan_x': vt.panOffset.dx,
      'pan_y': vt.panOffset.dy,
    };

    campaign.data!['map_data'] = {
      'image_path': firstEra.imagePath,
      'pins': firstEra.pins.map((p) => p.toJson()).toList(),
      'timeline': firstEra.timelinePins.map((t) => t.toJson()).toList(),
      'grid_size': existing['grid_size'] ?? 50,
      'grid_visible': existing['grid_visible'] ?? false,
      'grid_snap': existing['grid_snap'] ?? false,
      'feet_per_cell': existing['feet_per_cell'] ?? 5,
      'fog_state': existing['fog_state'] ?? <String, dynamic>{},
      'drawings': existing['drawings'] ?? <dynamic>[],
      // Era data
      'eras': state.eras
          .map((e) => {
                'id': e.id,
                'image_path': e.imagePath,
                'pins': e.pins.map((p) => p.toJson()).toList(),
                'timeline_pins':
                    e.timelinePins.map((t) => t.toJson()).toList(),
                if (e.locationMaps.isNotEmpty)
                  'location_maps': {
                    for (final entry in e.locationMaps.entries)
                      entry.key: {
                        'pins':
                            entry.value.pins.map((p) => p.toJson()).toList(),
                        'timeline_pins': entry.value.timelinePins
                            .map((t) => t.toJson())
                            .toList(),
                      },
                  },
              })
          .toList(),
      'waypoints': state.waypoints
          .map((w) => {'id': w.id, 'label': w.label})
          .toList(),
      'active_era_index': state.activeEraIndex,
      'era_start_label': state.eraStartLabel,
      'era_end_label': state.eraEndLabel,
      'pin_size': state.pinSize.name,
    };
  }

  // -------------------------------------------------------------------------
  // Era projection helpers
  // -------------------------------------------------------------------------

  /// Syncs the projected `state.pins`/`state.timelinePins`/`state.imagePath`
  /// back into the eras list. At root → writes the active era directly. While
  /// drilled → writes into `era.locationMaps[currentLocationId]` (image is
  /// sourced from the location entity, not stored here).
  void _syncProjection() {
    if (state.eras.isEmpty) return;
    final idx = state.activeEraIndex;
    final updated = List<MapEra>.from(state.eras);
    if (state.locationStack.isEmpty) {
      updated[idx] = updated[idx].copyWith(
        imagePath: state.imagePath,
        pins: state.pins,
        timelinePins: state.timelinePins,
      );
    } else {
      final locId = state.locationStack.last;
      final maps = Map<String, LocationMapData>.from(updated[idx].locationMaps);
      if (state.pins.isEmpty && state.timelinePins.isEmpty) {
        maps.remove(locId);
      } else {
        maps[locId] = LocationMapData(
          pins: state.pins,
          timelinePins: state.timelinePins,
        );
      }
      updated[idx] = updated[idx].copyWith(locationMaps: maps);
    }
    state = state.copyWith(eras: updated);
  }

  /// Legacy alias — call sites updated to [_syncProjection].
  void _syncActiveEra() => _syncProjection();

  /// Loads an era's data into the projected state fields.
  void _loadEra(int index) {
    final era = state.eras[index];
    state = state.copyWith(
      imagePath: era.imagePath,
      pins: era.pins,
      timelinePins: era.timelinePins,
      activeEraIndex: index,
    );
  }

  /// Switches the active era: syncs current, loads target. While drilled into
  /// a location, both the image and the drilled pin set swap to the new era's
  /// `locationMaps[locId]` (era is global).
  void switchEra(int index) {
    if (index == state.activeEraIndex) return;
    if (index < 0 || index >= state.eras.length) return;
    pushUndo(state);
    _syncProjection();
    if (state.locationStack.isEmpty) {
      _loadEra(index);
    } else {
      final locId = state.locationStack.last;
      final loc = _resolveLocation(locId);
      final existing = state.eras[index].locationMaps[locId];
      state = state.copyWith(
        activeEraIndex: index,
        imagePath: _resolveLocationMapImage(loc),
        pins: existing?.pins ?? const [],
        timelinePins: existing?.timelinePins ?? const [],
      );
    }
    _debouncedSave();
  }

  // -------------------------------------------------------------------------
  // Drill-in (PR-3: UI-only; pins/timelinePins reset in-place, persistence
  // ships in PR-4 via per-location nested maps inside MapEra)
  // -------------------------------------------------------------------------

  Entity? _resolveLocation(String? id) {
    if (id == null) return null;
    return _ref.read(entityProvider)[id];
  }

  String _resolveLocationMapImage(Entity? loc) {
    if (loc == null) return '';
    final perEra = loc.fields['map_per_era'];
    final activeEra = state.eras.isNotEmpty &&
            state.activeEraIndex < state.eras.length
        ? state.eras[state.activeEraIndex]
        : null;
    if (perEra is Map && activeEra != null) {
      final v = perEra[activeEra.id];
      if (v is String && v.isNotEmpty) return v;
    }
    final fallback = loc.fields['map'];
    if (fallback is String && fallback.isNotEmpty) return fallback;
    return '';
  }

  /// Drills the map view into [locationId]. Active era preserved; projected
  /// image swaps to the location's `map_per_era[currentEra]` (falls back to
  /// `map`). Pins for the (era, location) tuple are persisted in
  /// `MapEra.locationMaps`.
  void drillIntoLocation(String locationId) {
    _syncProjection();
    final loc = _resolveLocation(locationId);
    if (loc == null) return;
    final newStack = [...state.locationStack, locationId];
    final existing = state.eras.isNotEmpty
        ? state.eras[state.activeEraIndex].locationMaps[locationId]
        : null;
    state = state.copyWith(
      locationStack: newStack,
      imagePath: _resolveLocationMapImage(loc),
      pins: existing?.pins ?? const [],
      timelinePins: existing?.timelinePins ?? const [],
    );
  }

  /// Pops to a given depth (0 = root, 1 = first child, …).
  void popToLocationDepth(int depth) {
    if (depth < 0 || depth > state.locationStack.length) return;
    if (depth == state.locationStack.length) return;
    _syncProjection();
    if (depth == 0) {
      state = state.copyWith(locationStack: const []);
      if (state.eras.isNotEmpty) _loadEra(state.activeEraIndex);
      _debouncedSave();
      return;
    }
    final newStack = state.locationStack.sublist(0, depth);
    final loc = _resolveLocation(newStack.last);
    final existing = state.eras.isNotEmpty
        ? state.eras[state.activeEraIndex].locationMaps[newStack.last]
        : null;
    state = state.copyWith(
      locationStack: newStack,
      imagePath: _resolveLocationMapImage(loc),
      pins: existing?.pins ?? const [],
      timelinePins: existing?.timelinePins ?? const [],
    );
    _debouncedSave();
  }

  /// Display names for each era, derived from adjacent waypoints.
  List<String> get eraNames {
    if (state.eras.length <= 1) return ['Default'];
    final wps = state.waypoints;
    final names = <String>[];
    for (int i = 0; i < state.eras.length; i++) {
      final left = i == 0
          ? state.eraStartLabel
          : _waypointDisplayLabel(wps[i - 1]);
      final right = i >= wps.length
          ? state.eraEndLabel
          : _waypointDisplayLabel(wps[i]);
      names.add('$left \u2013 $right');
    }
    return names;
  }

  static final RegExp _digitsLikeRe = RegExp(r'^[\d./-]+$');
  static final RegExp _wsRe = RegExp(r'\s+');

  /// Short display label for a waypoint.
  static String _waypointDisplayLabel(EraWaypoint wp) {
    if (wp.label.isEmpty) return '?';
    // If it looks like a number or date, show as-is
    if (_digitsLikeRe.hasMatch(wp.label)) return wp.label;
    // Otherwise show uppercase initials
    return wp.label
        .split(_wsRe)
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
  }

  /// In-memory campaign data güncelle + diske debounced yaz.
  /// `pendingWriteBufferProvider` 1000ms spatial debounce yapar — pin drag
  /// burst'lerinde tek I/O. Viewport (pan/zoom) bu path'ten geçmez;
  /// [_debouncedViewportSave] kullanır (local-only, 2000ms).
  void _debouncedSave() {
    if (!mounted) return;
    syncToCampaignData();
    final campaign = _ref.read(activeCampaignProvider.notifier);
    final data = campaign.data;
    if (data == null) return;
    final mapMap = Map<String, dynamic>.from(data['map_data'] as Map? ?? {});
    final worldId = (data['world_id'] as String?) ?? 'local';
    final campaignName = _ref.read(activeCampaignProvider);
    final repo = _ref.read(campaignRepositoryProvider);
    _ref.read(pendingWriteBufferProvider).schedule(
          key: 'settings:$worldId:map_data',
          kind: WriteKind.spatial,
          action: () async {
            final snapshot = Map<String, dynamic>.from(mapMap);
            // Dual write: settings_json merge (legacy compat + cloud push)
            // + granular world_map_data Drift row (reopen kalıcılığı).
            await campaign.saveSettingsPatch({'map_data': snapshot});
            if (campaignName != null) {
              await repo.saveMapData(campaignName, snapshot);
            }
          },
        );
  }

  /// Pan/zoom save — local-only, 2000ms reset-on-edit. Viewport DM-local
  /// motion class; cloud'a gitmez (oyuncuya yansımaz, başka cihazda ekran
  /// sıçramaz). PendingWriteBuffer aynı key için yeni schedule'da timer'ı
  /// cancel + reset eder — kullanıcı pan'a devam ederken save tetiklenmez.
  void _debouncedViewportSave() {
    if (!mounted) return;
    syncToCampaignData();
    final campaign = _ref.read(activeCampaignProvider.notifier);
    final data = campaign.data;
    if (data == null) return;
    final view = Map<String, dynamic>.from(data['map_view'] as Map? ?? {});
    final worldId = (data['world_id'] as String?) ?? 'local';
    _ref.read(pendingWriteBufferProvider).schedule(
          key: 'settings:$worldId:map_view',
          kind: WriteKind.viewport,
          action: () => campaign.saveSettingsPatchLocalOnly(
            {'map_view': Map<String, dynamic>.from(view)},
          ),
        );
  }

  void undo() {
    final restored = popUndo(state);
    if (restored != null) {
      state = restored;
    }
  }

  void redo() {
    final restored = popRedo(state);
    if (restored != null) {
      state = restored;
    }
  }

  // -------------------------------------------------------------------------
  // Waypoint / Era CRUD
  // -------------------------------------------------------------------------

  /// Adds a waypoint at [insertIndex] (0-based within waypoints list).
  /// Splits the era that contains this position into two.
  void addWaypoint(
    int insertIndex,
    String label, {
    bool copyPins = false,
    bool copyTimelinePins = false,
  }) {
    pushUndo(state);
    _syncActiveEra();

    final wp = EraWaypoint(id: _uuid.v4(), label: label);
    final updatedWps = List<EraWaypoint>.from(state.waypoints)
      ..insert(insertIndex, wp);

    // The waypoint at insertIndex splits eraIndex = insertIndex into two.
    // Left era keeps the original, right era is new.
    final eraIdx = insertIndex; // era to split
    final original = state.eras[eraIdx];

    MapEra leftEra;
    MapEra rightEra;

    if (copyPins && copyTimelinePins) {
      leftEra = original.copyWith(id: _uuid.v4());
      rightEra = original.copyWith(
        id: _uuid.v4(),
        pins: _clonePins(original.pins),
        timelinePins: _cloneTimelinePins(original.timelinePins),
      );
    } else if (copyPins) {
      leftEra = original.copyWith(id: _uuid.v4());
      rightEra = MapEra(
        id: _uuid.v4(),
        imagePath: original.imagePath,
        pins: _clonePins(original.pins),
      );
    } else if (copyTimelinePins) {
      leftEra = original.copyWith(id: _uuid.v4());
      rightEra = MapEra(
        id: _uuid.v4(),
        imagePath: original.imagePath,
        timelinePins: _cloneTimelinePins(original.timelinePins),
      );
    } else {
      leftEra = original.copyWith(id: _uuid.v4());
      rightEra = MapEra(id: _uuid.v4(), imagePath: original.imagePath);
    }

    final updatedEras = List<MapEra>.from(state.eras)
      ..removeAt(eraIdx)
      ..insert(eraIdx, leftEra)
      ..insert(eraIdx + 1, rightEra);

    // Adjust activeEraIndex if needed
    var newActive = state.activeEraIndex;
    if (newActive > eraIdx) {
      newActive += 1; // shifted right by the split
    }

    state = state.copyWith(
      waypoints: updatedWps,
      eras: updatedEras,
      activeEraIndex: newActive,
    );
    // Re-project in case active era shifted
    _loadEra(state.activeEraIndex);
    _debouncedSave();
  }

  /// Deletes a waypoint and merges its adjacent eras.
  void deleteWaypoint(int wpIndex, EraMergeStrategy strategy) {
    if (wpIndex < 0 || wpIndex >= state.waypoints.length) return;
    pushUndo(state);
    _syncActiveEra();

    final leftIdx = wpIndex;     // era to the left of the waypoint
    final rightIdx = wpIndex + 1; // era to the right

    final leftEra = state.eras[leftIdx];
    final rightEra = state.eras[rightIdx];

    MapEra merged;
    switch (strategy) {
      case EraMergeStrategy.merge:
        merged = MapEra(
          id: _uuid.v4(),
          imagePath: leftEra.imagePath.isNotEmpty
              ? leftEra.imagePath
              : rightEra.imagePath,
          pins: [...leftEra.pins, ..._clonePins(rightEra.pins)],
          timelinePins: [
            ...leftEra.timelinePins,
            ..._cloneTimelinePins(rightEra.timelinePins),
          ],
        );
      case EraMergeStrategy.keepLeft:
        merged = leftEra.copyWith(id: _uuid.v4());
      case EraMergeStrategy.keepRight:
        merged = rightEra.copyWith(id: _uuid.v4());
    }

    final updatedEras = List<MapEra>.from(state.eras)
      ..removeAt(rightIdx)
      ..removeAt(leftIdx)
      ..insert(leftIdx, merged);

    final updatedWps = List<EraWaypoint>.from(state.waypoints)
      ..removeAt(wpIndex);

    // Adjust active index
    var newActive = state.activeEraIndex;
    if (newActive == rightIdx) {
      newActive = leftIdx;
    } else if (newActive > rightIdx) {
      newActive -= 1;
    }
    if (newActive >= updatedEras.length) {
      newActive = updatedEras.length - 1;
    }

    state = state.copyWith(
      waypoints: updatedWps,
      eras: updatedEras,
      activeEraIndex: newActive,
    );
    _loadEra(newActive);
    _debouncedSave();
  }

  /// Updates a waypoint's label.
  void updateWaypointLabel(int wpIndex, String label) {
    if (wpIndex < 0 || wpIndex >= state.waypoints.length) return;
    pushUndo(state);
    final updated = List<EraWaypoint>.from(state.waypoints);
    updated[wpIndex] = updated[wpIndex].copyWith(label: label);
    state = state.copyWith(waypoints: updated);
    _debouncedSave();
  }

  /// Updates the Start / End boundary labels.
  void updateEraBoundaryLabels({String? startLabel, String? endLabel}) {
    pushUndo(state);
    state = state.copyWith(
      eraStartLabel: startLabel,
      eraEndLabel: endLabel,
    );
    _debouncedSave();
  }

  /// Copies a MapPin from the active era to a target era (new UUID).
  void copyPinToEra(String pinId, int targetEraIndex) {
    _syncActiveEra();
    final pin = state.pins.where((p) => p.id == pinId).firstOrNull;
    if (pin == null) return;
    if (targetEraIndex < 0 || targetEraIndex >= state.eras.length) return;
    pushUndo(state);

    final copy = pin.copyWith(id: _uuid.v4());
    final updatedEras = List<MapEra>.from(state.eras);
    final target = updatedEras[targetEraIndex];
    updatedEras[targetEraIndex] = target.copyWith(
      pins: [...target.pins, copy],
    );
    state = state.copyWith(eras: updatedEras);
    _debouncedSave();
  }

  /// Copies a TimelinePin from the active era to a target era (new UUID).
  void copyTimelinePinToEra(String tpinId, int targetEraIndex) {
    _syncActiveEra();
    final tpin =
        state.timelinePins.where((t) => t.id == tpinId).firstOrNull;
    if (tpin == null) return;
    if (targetEraIndex < 0 || targetEraIndex >= state.eras.length) return;
    pushUndo(state);

    final copy = tpin.copyWith(id: _uuid.v4(), parentIds: []);
    final updatedEras = List<MapEra>.from(state.eras);
    final target = updatedEras[targetEraIndex];
    updatedEras[targetEraIndex] = target.copyWith(
      timelinePins: [...target.timelinePins, copy],
    );
    state = state.copyWith(eras: updatedEras);
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

  Future<void> pickMapImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final localPath = result.files.first.path;
    if (localPath == null) return;

    final oldRef = state.imagePath;
    // Eager cloud upload — online world → push to R2; offline / quota-full
    // → keep the local path.
    final (ref: stored, :quotaExceeded, :tooLarge, :actualBytes) =
        await uploadMapImage(
      _ref.read,
      path: localPath,
      kind: MediaKind.battleMap,
    );
    pushUndo(state);
    state = state.copyWith(imagePath: stored);
    await _fitImageInViewport();
    _debouncedSave();
    _debouncedViewportSave();
    if (quotaExceeded && context.mounted) showQuotaFullSnackbar(context);
    if (tooLarge && context.mounted) {
      showImageTooLargeSnackbar(
        context,
        maxBytes: MediaKind.battleMap.maxBytes,
        actualBytes: actualBytes,
      );
    }
    // Replaced an earlier cloud image → best-effort orphan cleanup.
    unawaited(cleanupMapImageRef(
      _ref.read,
      removedRef: oldRef,
      flushPrefix: 'settings:',
    ));
  }

  /// Ensures the active map image is cloud-hosted so remote players can
  /// resolve it: a still-local path is eager-uploaded, the rewritten ref is
  /// persisted, and the resolved ref is returned (empty when no image).
  Future<String> ensureMapImageUploaded() async {
    final current = state.imagePath;
    if (current.isEmpty || !AssetRef(current).isLocal) return current;
    final (ref: stored, quotaExceeded: _, tooLarge: _, actualBytes: _) =
        await uploadMapImage(
      _ref.read,
      path: current,
      kind: MediaKind.battleMap,
      transientFallback: true,
    );
    // Counted ref → persist (permanent). Transient ref (quota full) → use for
    // this projection only; persisting it would orphan the row at R2 TTL.
    if (stored != current && !AssetRef(stored).isTransient) {
      state = state.copyWith(imagePath: stored);
      _debouncedSave();
    }
    return stored;
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
    // Viewport-only save: local Drift, no cloud push, 2s reset-on-edit.
    // Pan/zoom undo stack'i kirletmesin → pushUndo yok.
    _debouncedViewportSave();
    _bumpCullTick();
  }

  void zoomAtPoint(Offset localPos, double scrollDelta) {
    const zoomFactor = 0.1;
    final vt = viewTransform.value;
    final factor = scrollDelta > 0 ? 1 - zoomFactor : 1 + zoomFactor;
    final newScale = (vt.scale * factor).clamp(0.05, 10.0);
    final scaleRatio = newScale / vt.scale;
    final newPan = localPos - (localPos - vt.panOffset) * scaleRatio;
    viewTransform.value = WorldMapViewTransform(scale: newScale, panOffset: newPan);
    _bumpCullTick();
    _debouncedViewportSave();
  }

  void updateViewportSize(Size size) {
    if (size == _viewportSize) return;
    _viewportSize = size;
    _bumpCullTick();
  }

  void resetView() {
    pushUndo(state);
    _fitImageInViewport();
    _debouncedViewportSave();
  }

  /// Fit the current map image within the viewport (contain).
  /// Falls back to default transform if image can't be resolved.
  Future<void> _fitImageInViewport() async {
    final path = state.imagePath;
    if (path.isEmpty || _viewportSize == Size.zero) {
      viewTransform.value = const WorldMapViewTransform();
      _bumpCullTick();
      return;
    }
    // imagePath may be a local path or a `dmt-asset://` cloud ref — resolve
    // through AssetRefResolver (cloud refs download + cache on first use).
    final file =
        await _ref.read(assetRefResolverProvider).resolve(AssetRef(path));
    if (file == null) {
      viewTransform.value = const WorldMapViewTransform();
      _bumpCullTick();
      return;
    }
    try {
      final size = _imageSizeCache[path] ?? await _decodeImageSize(file);
      _imageSizeCache[path] = size;
      final imgW = size.width;
      final imgH = size.height;

      final scaleX = _viewportSize.width / imgW;
      final scaleY = _viewportSize.height / imgH;
      final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.05, 10.0);
      final panX = (_viewportSize.width - imgW * scale) / 2;
      final panY = (_viewportSize.height - imgH * scale) / 2;
      viewTransform.value =
          WorldMapViewTransform(scale: scale, panOffset: Offset(panX, panY));
      _bumpCullTick();
    } catch (_) {
      viewTransform.value = const WorldMapViewTransform();
      _bumpCullTick();
    }
  }

  Future<Size> _decodeImageSize(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    return size;
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
    pushUndo(state);
    state = state.copyWith(pins: [...state.pins, pin]);
    _debouncedSave();
    return id;
  }

  void updatePin(
    String id, {
    Offset? pos,
    String? label,
    String? pinType,
    String? note,
    String? color,
    Map<String, dynamic>? style,
  }) {
    final idx = state.pins.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    pushUndo(state);
    final updated = List<MapPin>.from(state.pins);
    final p = updated[idx];
    updated[idx] = p.copyWith(
      x: pos?.dx ?? p.x,
      y: pos?.dy ?? p.y,
      label: label ?? p.label,
      pinType: pinType ?? p.pinType,
      note: note ?? p.note,
      color: color ?? p.color,
      style: style ?? p.style,
    );
    state = state.copyWith(pins: updated);
    _debouncedSave();
  }

  void updatePinNote(String id, String note) {
    final idx = state.pins.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    pushUndo(state);
    final updated = List<MapPin>.from(state.pins);
    updated[idx] = updated[idx].copyWith(note: note);
    state = state.copyWith(pins: updated);
    _debouncedSave();
  }

  void updatePinColor(String id, String color) {
    final idx = state.pins.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    pushUndo(state);
    final updated = List<MapPin>.from(state.pins);
    updated[idx] = updated[idx].copyWith(color: color);
    state = state.copyWith(pins: updated);
    _debouncedSave();
  }

  void deletePin(String id) {
    pushUndo(state);
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
    pushUndo(state);
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
    Map<String, dynamic>? style,
  }) {
    final idx = state.timelinePins.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    pushUndo(state);
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
      style: style ?? t.style,
    );
    state = state.copyWith(timelinePins: updated);
    _debouncedSave();
  }

  void deleteTimelinePin(String id) {
    pushUndo(state);
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
    pushUndo(state);
    final updated = List<TimelinePin>.from(state.timelinePins);
    updated[idx] = child.copyWith(
      parentIds: [...child.parentIds, parentId],
    );
    state = state.copyWith(timelinePins: updated);
    _debouncedSave();
  }

  /// Propagate color through the timeline chain (BFS).
  void updateTimelineChainColor(String startId, String color) {
    pushUndo(state);
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

  void cyclePinSize() {
    final next = switch (state.pinSize) {
      PinSize.small => PinSize.medium,
      PinSize.medium => PinSize.large,
      PinSize.large => PinSize.small,
    };
    state = state.copyWith(pinSize: next);
  }

  // Memoized visible-pin slices. Identity-keyed on the immutable inputs the
  // filter reads — pin list, hiddenPinTypes set, activeEntityFilters set, and
  // the two visibility flags. Avoids re-filtering on every consumer rebuild.
  List<MapPin>? _cachedVisiblePins;
  List<MapPin>? _cachedVisiblePinsKeyPins;
  Set<String>? _cachedVisiblePinsKeyHidden;
  Set<String>? _cachedVisiblePinsKeyFilters;
  bool? _cachedVisiblePinsKeyShow;

  List<TimelinePin>? _cachedVisibleTimelinePins;
  List<TimelinePin>? _cachedVisibleTimelinePinsKeyPins;
  Set<String>? _cachedVisibleTimelinePinsKeyFilters;
  bool? _cachedVisibleTimelinePinsKeyShow;

  /// Visible map pins (filtered by type + entity filter).
  List<MapPin> get visiblePins {
    if (identical(_cachedVisiblePinsKeyPins, state.pins) &&
        identical(_cachedVisiblePinsKeyHidden, state.hiddenPinTypes) &&
        identical(_cachedVisiblePinsKeyFilters, state.activeEntityFilters) &&
        _cachedVisiblePinsKeyShow == state.showMapPins &&
        _cachedVisiblePins != null) {
      return _cachedVisiblePins!;
    }
    final List<MapPin> result;
    if (!state.showMapPins) {
      result = const [];
    } else {
      var pins = state.pins.where(
          (p) => !state.hiddenPinTypes.contains(p.pinType));
      if (state.activeEntityFilters.isNotEmpty) {
        pins = pins.where((p) =>
            p.entityId != null &&
            state.activeEntityFilters.contains(p.entityId));
      }
      result = pins.toList(growable: false);
    }
    _cachedVisiblePins = result;
    _cachedVisiblePinsKeyPins = state.pins;
    _cachedVisiblePinsKeyHidden = state.hiddenPinTypes;
    _cachedVisiblePinsKeyFilters = state.activeEntityFilters;
    _cachedVisiblePinsKeyShow = state.showMapPins;
    return result;
  }

  /// Visible timeline pins (filtered by entity filter).
  List<TimelinePin> get visibleTimelinePins {
    if (identical(_cachedVisibleTimelinePinsKeyPins, state.timelinePins) &&
        identical(_cachedVisibleTimelinePinsKeyFilters,
            state.activeEntityFilters) &&
        _cachedVisibleTimelinePinsKeyShow == state.showTimeline &&
        _cachedVisibleTimelinePins != null) {
      return _cachedVisibleTimelinePins!;
    }
    final List<TimelinePin> result;
    if (!state.showTimeline) {
      result = const [];
    } else {
      var pins = state.timelinePins;
      if (state.activeEntityFilters.isNotEmpty) {
        pins = pins
            .where((t) =>
                t.entityIds.isEmpty ||
                t.entityIds.any(
                    (e) => state.activeEntityFilters.contains(e)))
            .toList(growable: false);
      }
      result = pins;
    }
    _cachedVisibleTimelinePins = result;
    _cachedVisibleTimelinePinsKeyPins = state.timelinePins;
    _cachedVisibleTimelinePinsKeyFilters = state.activeEntityFilters;
    _cachedVisibleTimelinePinsKeyShow = state.showTimeline;
    return result;
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

  /// Center of current viewport in canvas space. Falls back to (0,0) when
  /// viewport hasn't been laid out yet.
  Offset get viewportCenterCanvas {
    if (_viewportSize == Size.zero) return Offset.zero;
    return screenToCanvas(
      Offset(_viewportSize.width / 2, _viewportSize.height / 2),
    );
  }

  /// F2: Current viewport in canvas-space (inverse of the Transform matrix).
  /// Used by the pin layer to viewport-cull at [cullTick] events.
  /// Inflated by ~1 viewport-worth so a pan-drag stays inside the culled set
  /// until the next gesture-END bumps cullTick.
  Rect computeCullViewport() {
    if (_viewportSize == Size.zero) {
      return const Rect.fromLTWH(-1e6, -1e6, 2e6, 2e6);
    }
    final vt = viewTransform.value;
    final visible = Rect.fromLTWH(
      -vt.panOffset.dx / vt.scale,
      -vt.panOffset.dy / vt.scale,
      _viewportSize.width / vt.scale,
      _viewportSize.height / vt.scale,
    );
    // One-viewport buffer so a pan within the current gesture doesn't blank
    // edge pins before onScaleEnd refreshes the cull.
    return visible.inflate(
        math.max(visible.width, visible.height));
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final worldMapProvider = StateNotifierProvider.autoDispose<WorldMapNotifier, WorldMapState>(
  (ref) => WorldMapNotifier(ref),
);
