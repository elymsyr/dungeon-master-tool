import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/combat_provider.dart';
import '../../../application/providers/projection_provider.dart';
import '../../../application/services/asset_ref_resolver.dart';
import '../../../application/services/map_image_upload.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../domain/entities/projection/battle_map_snapshot.dart';
import '../../../domain/entities/projection/projection_item.dart';
import '../../../domain/entities/session.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../../domain/value_objects/grid_distance.dart';
import '../../../domain/value_objects/media_kind.dart';
import '../../widgets/quota_snackbar.dart';

// ---------------------------------------------------------------------------
// Tool enum
// ---------------------------------------------------------------------------

enum BattleMapTool {
  navigate,
  ruler,
  circle,
  draw,
  fogAdd,
  fogErase,
  // AoE templates — share the measurement lifecycle (origin→far point).
  aoeCone,
  aoeLine,
  aoeCircle,
  aoeSquare,
  // Sector ("kesik daire") — two-stage: drag radius, then drag angle.
  aoeSector,
  // Drag-eraser for measurements/AoE — delete marks the pointer crosses.
  eraseMark,
}

/// True for the AoE template tools (filled shapes that ride the measurement
/// pipeline). Used to branch origin-snap + fill-color stamping.
bool isAoeTool(BattleMapTool t) =>
    t == BattleMapTool.aoeCone ||
    t == BattleMapTool.aoeLine ||
    t == BattleMapTool.aoeCircle ||
    t == BattleMapTool.aoeSquare ||
    t == BattleMapTool.aoeSector;

/// Default sector sweep (degrees) shown after the radius is set, before the
/// DM adjusts the angle in stage 2.
const double kDefaultSectorSweepDeg = 90;

/// Default fill/stroke color (hex) for each AoE shape. Returns null for the
/// plain ruler/circle measurement tools, which keep their hardcoded colors.
String? defaultAoeColorHex(BattleMapTool t) {
  switch (t) {
    case BattleMapTool.aoeCone:
      return '#ff7043'; // deep orange
    case BattleMapTool.aoeLine:
      return '#ffca28'; // amber
    case BattleMapTool.aoeCircle:
      return '#42a5f5'; // blue
    case BattleMapTool.aoeSquare:
      return '#ab47bc'; // purple
    case BattleMapTool.aoeSector:
      return '#26c6da'; // teal
    default:
      return null;
  }
}

/// Total, lossless mapping `BattleMapTool → persisted type string`. Replaces
/// the old binary `circle?'circle':'ruler'` ternary so AoE subtypes survive
/// the JSON / snapshot round-trip instead of degrading to ruler.
String battleMapToolToTypeString(BattleMapTool t) {
  switch (t) {
    case BattleMapTool.circle:
      return 'circle';
    case BattleMapTool.aoeCone:
      return 'cone';
    case BattleMapTool.aoeLine:
      return 'line';
    case BattleMapTool.aoeCircle:
      return 'aoeCircle';
    case BattleMapTool.aoeSquare:
      return 'square';
    case BattleMapTool.aoeSector:
      return 'sector';
    default:
      return 'ruler';
  }
}

/// Inverse of [battleMapToolToTypeString]. Unknown strings → ruler.
BattleMapTool battleMapToolFromTypeString(String? s) {
  switch (s) {
    case 'circle':
      return BattleMapTool.circle;
    case 'cone':
      return BattleMapTool.aoeCone;
    case 'line':
      return BattleMapTool.aoeLine;
    case 'aoeCircle':
      return BattleMapTool.aoeCircle;
    case 'square':
      return BattleMapTool.aoeSquare;
    case 'sector':
      return BattleMapTool.aoeSector;
    default:
      return BattleMapTool.ruler;
  }
}

// ---------------------------------------------------------------------------
// Supporting data classes
// ---------------------------------------------------------------------------

class DrawStroke {
  final Path path;
  final Color color;
  final double width;
  final bool isErase;

  /// Raw point list captured alongside `path` so the stroke can be serialized
  /// for cross-isolate projection (Path is not JSON-serializable).
  final List<Offset> rawPoints;

  DrawStroke({
    required this.path,
    required this.color,
    required this.width,
    this.rawPoints = const [],
    this.isErase = false,
  });
}

class MeasurementMark {
  final BattleMapTool type; // ruler, circle, or an AoE template tool
  final Offset start;
  final Offset end;
  final bool isPersistent;

  /// Fill/stroke color (hex) for AoE templates. Null for plain ruler/circle
  /// measurements, which paint with their fixed yellow/cyan.
  final String? colorHex;

  /// Sector sweep angle in degrees (aoeSector only). Null while the radius is
  /// still being set in stage 1, or for non-sector marks.
  final double? sweepDeg;

  const MeasurementMark({
    required this.type,
    required this.start,
    required this.end,
    this.isPersistent = false,
    this.colorHex,
    this.sweepDeg,
  });
}

// ---------------------------------------------------------------------------
// View transform (lightweight — bypasses Riverpod for 60fps updates)
// ---------------------------------------------------------------------------

class ViewTransform {
  final double scale;
  final Offset panOffset;
  const ViewTransform({this.scale = 1.0, this.panOffset = Offset.zero});
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class BattleMapState {
  // Tool
  final BattleMapTool activeTool;

  // Background
  final ui.Image? backgroundImage;
  final String? mapPath;

  // Fog (pre-rendered bitmap)
  final ui.Image? fogImage;

  // Annotation
  final List<DrawStroke> strokes; // committed strokes (displayed via painter)
  final ui.Image? annotationImage; // flattened on save

  // Fog draft (polygon being drawn, in canvas-space)
  final List<Offset> fogDraftPoints;

  // Measurements
  final MeasurementMark? activeMeasurement;
  final List<MeasurementMark> persistentMeasurements;

  // Token positions (combatantId → canvas-space Offset)
  final Map<String, Offset> tokenPositions;

  // Grid & sizing
  final int gridSize;
  final bool gridVisible;
  final bool gridSnap;
  final int feetPerCell;
  final int tokenSize;
  final Map<String, double> tokenSizeMultipliers;

  /// 5e diagonal counting rule for distance labels. Index into
  /// `DiagonalRule.values` (0 = euclidean, the default).
  final int diagonalRule;

  // Canvas dimensions (from background image or default)
  final int canvasWidth;
  final int canvasHeight;

  const BattleMapState({
    this.activeTool = BattleMapTool.navigate,
    this.backgroundImage,
    this.mapPath,
    this.fogImage,
    this.strokes = const [],
    this.annotationImage,
    this.fogDraftPoints = const [],
    this.activeMeasurement,
    this.persistentMeasurements = const [],
    this.tokenPositions = const {},
    this.gridSize = 50,
    this.gridVisible = false,
    this.gridSnap = false,
    this.feetPerCell = 5,
    this.tokenSize = 50,
    this.tokenSizeMultipliers = const {},
    this.diagonalRule = 0,
    this.canvasWidth = 2048,
    this.canvasHeight = 2048,
  });

  BattleMapState copyWith({
    BattleMapTool? activeTool,
    ui.Image? backgroundImage,
    String? mapPath,
    ui.Image? fogImage,
    List<DrawStroke>? strokes,
    ui.Image? annotationImage,
    List<Offset>? fogDraftPoints,
    MeasurementMark? activeMeasurement,
    List<MeasurementMark>? persistentMeasurements,
    Map<String, Offset>? tokenPositions,
    int? gridSize,
    bool? gridVisible,
    bool? gridSnap,
    int? feetPerCell,
    int? tokenSize,
    Map<String, double>? tokenSizeMultipliers,
    int? diagonalRule,
    int? canvasWidth,
    int? canvasHeight,
    // Sentinel for nullable clears
    bool clearFogImage = false,
    bool clearAnnotationImage = false,
    bool clearActiveMeasurement = false,
    bool clearMapPath = false,
    bool clearBackgroundImage = false,
  }) {
    return BattleMapState(
      activeTool: activeTool ?? this.activeTool,
      backgroundImage: clearBackgroundImage ? null : (backgroundImage ?? this.backgroundImage),
      mapPath: clearMapPath ? null : (mapPath ?? this.mapPath),
      fogImage: clearFogImage ? null : (fogImage ?? this.fogImage),
      strokes: strokes ?? this.strokes,
      annotationImage: clearAnnotationImage ? null : (annotationImage ?? this.annotationImage),
      fogDraftPoints: fogDraftPoints ?? this.fogDraftPoints,
      activeMeasurement: clearActiveMeasurement ? null : (activeMeasurement ?? this.activeMeasurement),
      persistentMeasurements: persistentMeasurements ?? this.persistentMeasurements,
      tokenPositions: tokenPositions ?? this.tokenPositions,
      gridSize: gridSize ?? this.gridSize,
      gridVisible: gridVisible ?? this.gridVisible,
      gridSnap: gridSnap ?? this.gridSnap,
      feetPerCell: feetPerCell ?? this.feetPerCell,
      tokenSize: tokenSize ?? this.tokenSize,
      tokenSizeMultipliers: tokenSizeMultipliers ?? this.tokenSizeMultipliers,
      diagonalRule: diagonalRule ?? this.diagonalRule,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class BattleMapNotifier extends StateNotifier<BattleMapState> {
  final String encounterId;
  final Ref _ref;

  /// Per-encounter cache of the last `ViewTransform` (scale + pan), so that
  /// switching tabs / closing the battle map and reopening it lands on the
  /// same view instead of resetting to the top-left identity transform.
  /// The notifier itself is `autoDispose.family`, so this static map is the
  /// only thing that survives across recreations.
  static final Map<String, ViewTransform> _viewMemory = {};

  // Lightweight view transform — updated at 60fps without Riverpod overhead.
  // CustomPainter and tokens listen to this directly via repaint / ValueListenableBuilder.
  final ValueNotifier<ViewTransform> viewTransform =
      ValueNotifier<ViewTransform>(const ViewTransform());

  // Lightweight repaint signal for in-progress annotation strokes.
  final ValueNotifier<int> strokeTick = ValueNotifier<int>(0);

  // In-progress annotation stroke — mutable, NOT in state
  Path? _currentPath;
  final List<Offset> _currentRawPoints = [];
  Color _currentColor = Colors.red;
  double _currentWidth = 4.0;
  bool _currentIsErase = false;
  // Set by eraseMarksAt on every pan sample that deletes a mark/stroke; flushed
  // once (sync + autosave) at pan-end in commitEraseStroke instead of per sample.
  bool _eraseDirty = false;

  // Scale gesture tracking
  double _scaleBase = 1.0;
  Offset _focalBase = Offset.zero;
  Offset _panBase = Offset.zero;

  // Viewport size (updated from LayoutBuilder — not part of state)
  Size _viewportSize = Size.zero;

  // Projection viewport sync — leading-edge throttle so high-frequency
  // pan/zoom updates land on the player window at ~30Hz max.
  Timer? _projectionSyncThrottle;

  // Projection drawings sync — leading-edge throttle for stroke/measurement
  // /token-size/grid/fog updates. Slower than viewport (80ms) since they're
  // not driven by 60fps gestures.
  Timer? _projectionDrawingsThrottle;

  // Cached fog→base64 encoding so we don't re-encode the PNG on every
  // throttled push when the underlying image hasn't changed.
  ui.Image? _lastFogImage;
  String? _lastFogB64;
  // True when the fog has changed since the last drawings push reached
  // the player. Until this flips, the patch payload won't include
  // `fogDataBase64` at all — saving 100s of KB of JSON serialization on
  // every stroke / measurement edit.
  bool _fogDirtyForProjection = false;

  /// True between a sector's stage-1 (radius) commit and its stage-2 (angle)
  /// commit, so the lifecycle methods adjust the sweep instead of the radius.
  bool _awaitingSectorAngle = false;

  BattleMapNotifier(this.encounterId, this._ref)
      : super(const BattleMapState()) {
    // Restore the cached view (scale + pan) for this encounter, if any —
    // so reopening the battle map tab lands on the last position the DM
    // was looking at instead of resetting to the top-left.
    final remembered = _viewMemory[encounterId];
    if (remembered != null) {
      viewTransform.value = remembered;
    }
    viewTransform.addListener(_scheduleProjectionSync);
    viewTransform.addListener(_persistView);
  }

  void _persistView() {
    _viewMemory[encounterId] = viewTransform.value;
  }

  @override
  void dispose() {
    // Final view snapshot before the notifier goes away — guarantees the
    // memory is always up to date even if the last update was during a
    // gesture that hadn't finished firing listeners.
    _viewMemory[encounterId] = viewTransform.value;
    _projectionSyncThrottle?.cancel();
    _projectionDrawingsThrottle?.cancel();
    viewTransform.removeListener(_scheduleProjectionSync);
    viewTransform.removeListener(_persistView);
    viewTransform.dispose();
    strokeTick.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Projection viewport sync
  // -------------------------------------------------------------------------

  /// Called whenever `viewTransform` changes. Throttles the actual push to
  /// ~30Hz to avoid spamming IPC during a pinch-zoom gesture.
  void _scheduleProjectionSync() {
    if (_projectionSyncThrottle != null) return;
    _projectionSyncThrottle = Timer(const Duration(milliseconds: 33), () {
      _projectionSyncThrottle = null;
      _pushViewportToProjection();
    });
  }

  /// Computes the visible canvas rect in **normalized** coordinates and
  /// pushes it to any unlocked `BattleMapProjection` for this encounter.
  ///
  /// Clips the rect to actual canvas bounds before normalizing — DM's
  /// letterbox padding is NOT content the player should see. When the DM
  /// is fit-to-screen (or wider) the rect collapses to "full canvas" via
  /// a null override, so the player paints fit-to-its-own-viewport for an
  /// edge-to-edge full-screen result.
  void _pushViewportToProjection() {
    final vp = _viewportSize;
    if (vp == Size.zero) return;
    final canvasW = state.canvasWidth.toDouble();
    final canvasH = state.canvasHeight.toDouble();
    if (canvasW <= 0 || canvasH <= 0) return;
    final vt = viewTransform.value;
    if (vt.scale <= 0) return;

    // Find the matching projection — bail if none or locked.
    final pState = _ref.read(projectionControllerProvider);
    final proj = pState.items
        .whereType<BattleMapProjection>()
        .where((p) => p.encounterId == encounterId && !p.viewportLocked)
        .firstOrNull;
    if (proj == null) return;

    // visibleRect (canvas-space) = (-pan/scale, vp/scale)
    final left = -vt.panOffset.dx / vt.scale;
    final top = -vt.panOffset.dy / vt.scale;
    final right = left + vp.width / vt.scale;
    final bottom = top + vp.height / vt.scale;

    // Clip to actual canvas bounds.
    final clipL = left.clamp(0.0, canvasW);
    final clipT = top.clamp(0.0, canvasH);
    final clipR = right.clamp(0.0, canvasW);
    final clipB = bottom.clamp(0.0, canvasH);
    final clipW = clipR - clipL;
    final clipH = clipB - clipT;
    if (clipW <= 0 || clipH <= 0) return;

    // If the DM is essentially viewing the entire canvas, push null so the
    // player just fits-to-its-own-viewport (no aspect-ratio letterbox issues).
    final isFullView = clipL <= 1 &&
        clipT <= 1 &&
        clipR >= canvasW - 1 &&
        clipB >= canvasH - 1;

    final norm = isFullView
        ? null
        : NormalizedRect(
            left: clipL / canvasW,
            top: clipT / canvasH,
            width: clipW / canvasW,
            height: clipH / canvasH,
          );

    _ref
        .read(projectionControllerProvider.notifier)
        .updateBattleMapViewport(proj.id, norm);
  }

  // -------------------------------------------------------------------------
  // Projection drawings sync (strokes, measurements, fog, token size, grid)
  // -------------------------------------------------------------------------

  /// Schedule a leading-edge throttled push of all "static" battle map state
  /// (everything except viewport + tokens, which have their own paths).
  void _scheduleDrawingsSync() {
    if (_projectionDrawingsThrottle != null) return;
    _projectionDrawingsThrottle = Timer(const Duration(milliseconds: 80), () {
      _projectionDrawingsThrottle = null;
      _pushDrawingsToProjection();
    });
  }

  Future<void> _pushDrawingsToProjection() async {
    final pState = _ref.read(projectionControllerProvider);
    final proj = pState.items
        .whereType<BattleMapProjection>()
        .where((p) => p.encounterId == encounterId)
        .firstOrNull;
    if (proj == null) return;

    // Re-encode + ship fog only when it's actually dirty since the last
    // push. The fog PNG is by far the heaviest field in the patch — most
    // pushes (drawing a stroke, moving a ruler) don't touch it, so we
    // skip it entirely most of the time.
    final fog = state.fogImage;
    String? fogB64;
    var includeFog = false;
    if (_fogDirtyForProjection) {
      _fogDirtyForProjection = false;
      includeFog = true;
      if (fog == null) {
        fogB64 = null;
        _lastFogImage = null;
        _lastFogB64 = null;
      } else if (identical(fog, _lastFogImage)) {
        fogB64 = _lastFogB64;
      } else {
        fogB64 = await _fogToBase64();
        _lastFogImage = fog;
        _lastFogB64 = fogB64;
      }
    }

    // Map DrawStrokes to JSON-clean snapshots — skip erase strokes (DM-only).
    final strokeSnaps = <StrokeSnapshot>[];
    for (final s in state.strokes) {
      if (s.isErase) continue;
      if (s.rawPoints.length < 2) continue;
      final flat = <double>[];
      for (final p in s.rawPoints) {
        flat
          ..add(p.dx)
          ..add(p.dy);
      }
      strokeSnaps.add(StrokeSnapshot(
        points: flat,
        colorHex: _colorToHex(s.color),
        width: s.width,
      ));
    }

    final measurementSnaps = state.persistentMeasurements
        .map((m) => MeasurementSnapshot(
              type: battleMapToolToTypeString(m.type),
              x1: m.start.dx,
              y1: m.start.dy,
              x2: m.end.dx,
              y2: m.end.dy,
              colorHex: m.colorHex,
              sweepDeg: m.sweepDeg,
            ))
        .toList();

    _ref.read(projectionControllerProvider.notifier).updateBattleMapDrawings(
          itemId: proj.id,
          strokes: strokeSnaps,
          measurements: measurementSnaps,
          tokenSize: state.tokenSize,
          tokenSizeMultipliers: state.tokenSizeMultipliers,
          gridVisible: state.gridVisible,
          gridSize: state.gridSize,
          feetPerCell: state.feetPerCell,
          diagonalRule: state.diagonalRule,
          fogDataBase64: fogB64,
          includeFog: includeFog,
        );
  }

  static String _colorToHex(Color c) {
    final r = (c.r * 255).round() & 0xff;
    final g = (c.g * 255).round() & 0xff;
    final b = (c.b * 255).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  static Color _colorFromHex(String hex) {
    var clean = hex.replaceFirst('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.parse(clean, radix: 16));
  }

  // -------------------------------------------------------------------------
  // Init
  // -------------------------------------------------------------------------

  /// Last applied cloud-side encounter fingerprint. Compared in
  /// [syncFromEncounter] to decide whether incoming activeEncounter update is
  /// a fresh cloud snapshot worth re-hydrating from. Local saves bump it via
  /// [_stampFingerprint] so the notifier's own writes don't trigger a
  /// re-init loop.
  String? _appliedFingerprint;

  static String _fingerprintOf(Encounter e) {
    return jsonEncode({
      'm': e.mapPath ?? '',
      'ts': e.tokenSize,
      'tm': e.tokenSizeMultipliers,
      'tp': e.tokenPositions,
      'f': e.fogData?.length ?? 0,
      'a': e.annotationData?.length ?? 0,
      'ms': e.measurementsData ?? '',
      'st': e.strokesData ?? '',
      'g': '${e.gridSize}/${e.gridVisible}/${e.gridSnap}/${e.feetPerCell}/${e.diagonalRule}',
    });
  }

  void _stampFingerprint(Encounter e) {
    _appliedFingerprint = _fingerprintOf(e);
  }

  /// Re-hydrate notifier from a fresh [encounter] snapshot (CDC catch-up,
  /// cross-device open). Idempotent — bails when the fingerprint matches the
  /// last applied snapshot, or when a local battlemap write is still pending
  /// (about to overwrite cloud anyway).
  Future<void> syncFromEncounter(Encounter encounter) async {
    if (encounter.id != encounterId) return;
    final fp = _fingerprintOf(encounter);
    if (fp == _appliedFingerprint) return;
    if (_ref
        .read(pendingWriteBufferProvider)
        .isPending('battlemap:$encounterId:save')) {
      return;
    }
    await init(encounter);
  }

  Future<void> init(Encounter encounter) async {
    // Grid settings
    var s = state.copyWith(
      gridSize: encounter.gridSize,
      gridVisible: encounter.gridVisible,
      gridSnap: encounter.gridSnap,
      feetPerCell: encounter.feetPerCell,
      tokenSize: encounter.tokenSize,
      tokenSizeMultipliers: Map<String, double>.from(encounter.tokenSizeMultipliers),
      diagonalRule: encounter.diagonalRule,
      mapPath: encounter.mapPath,
    );

    // Token positions
    final positions = <String, Offset>{};
    for (final entry in encounter.tokenPositions.entries) {
      final v = entry.value;
      if (v is Map) {
        positions[entry.key] = Offset(
          (v['x'] as num?)?.toDouble() ?? 0,
          (v['y'] as num?)?.toDouble() ?? 0,
        );
      }
    }

    // Persistent measurements (circles + rulers). Vector JSON — not flattened
    // into annotationData PNG so individual marks remain deletable.
    final measurements = <MeasurementMark>[];
    final rawMeasurements = encounter.measurementsData;
    if (rawMeasurements != null && rawMeasurements.isNotEmpty) {
      try {
        final list = jsonDecode(rawMeasurements);
        if (list is List) {
          for (final m in list) {
            if (m is! Map) continue;
            measurements.add(MeasurementMark(
              type: battleMapToolFromTypeString(m['type'] as String?),
              start: Offset(
                (m['x1'] as num?)?.toDouble() ?? 0,
                (m['y1'] as num?)?.toDouble() ?? 0,
              ),
              end: Offset(
                (m['x2'] as num?)?.toDouble() ?? 0,
                (m['y2'] as num?)?.toDouble() ?? 0,
              ),
              isPersistent: true,
              colorHex: m['c'] as String?,
              sweepDeg: (m['s'] as num?)?.toDouble(),
            ));
          }
        }
      } catch (_) {}
    }
    // Pen strokes — vector JSON (array of StrokeSnapshot). Reload as individual
    // DrawStrokes so each stays deletable; NOT baked into annotationData.
    final strokes = <DrawStroke>[];
    final rawStrokes = encounter.strokesData;
    if (rawStrokes != null && rawStrokes.isNotEmpty) {
      try {
        final list = jsonDecode(rawStrokes);
        if (list is List) {
          for (final e in list) {
            if (e is! Map) continue;
            final snap = StrokeSnapshot.fromJson(e.cast<String, dynamic>());
            if (snap.points.length < 4) continue;
            final pts = <Offset>[];
            for (var i = 0; i + 1 < snap.points.length; i += 2) {
              pts.add(Offset(snap.points[i], snap.points[i + 1]));
            }
            final path = Path()..moveTo(pts.first.dx, pts.first.dy);
            for (final p in pts.skip(1)) {
              path.lineTo(p.dx, p.dy);
            }
            strokes.add(DrawStroke(
              path: path,
              color: _colorFromHex(snap.colorHex),
              width: snap.width,
              rawPoints: pts,
            ));
          }
        }
      } catch (_) {}
    }
    // Assign default positions for combatants without saved positions
    var col = 0;
    var row = 0;
    for (final c in encounter.combatants) {
      if (!positions.containsKey(c.id)) {
        final gs = encounter.gridSize.toDouble();
        positions[c.id] = Offset((col + 1.5) * gs, (row + 1.5) * gs);
        col++;
        if (col > 4) { col = 0; row++; }
      }
    }
    s = s.copyWith(
      tokenPositions: positions,
      persistentMeasurements: measurements,
      strokes: strokes,
    );

    if (!mounted) return;
    state = s;

    // Load assets asynchronously
    final bgFuture = encounter.mapPath != null ? _loadImageFromFile(encounter.mapPath!) : Future<ui.Image?>.value(null);
    final fogFuture = _base64ToImage(encounter.fogData);
    final annotFuture = _base64ToImage(encounter.annotationData);

    final results = await Future.wait([bgFuture, fogFuture, annotFuture]);
    final bg = results[0];
    final fog = results[1];
    final annot = results[2];

    if (!mounted) return;

    state = state.copyWith(
      backgroundImage: bg,
      fogImage: fog,
      annotationImage: annot,
      canvasWidth: bg?.width ?? 2048,
      canvasHeight: bg?.height ?? 2048,
    );
    _stampFingerprint(encounter);

    // Push rehydrated drawings (strokes/measurements/fog) to any live
    // projection so a reopen mirrors them to players even without a fresh edit.
    _fogDirtyForProjection = true;
    _scheduleDrawingsSync();

    // First time we open this encounter's battle map — auto-fit the
    // background to the viewport so the user doesn't see the top-left
    // letterbox. Subsequent reopens use the remembered view (handled in
    // the constructor).
    if (!_viewMemory.containsKey(encounterId) && bg != null) {
      // The viewport may not be measured yet (LayoutBuilder hasn't run);
      // schedule for after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_viewportSize == Size.zero) return;
        resetView();
      });
    }
  }

  // -------------------------------------------------------------------------
  // View transform (updates viewTransform ValueNotifier — no Riverpod state)
  // -------------------------------------------------------------------------

  void onScaleStart(ScaleStartDetails details) {
    final vt = viewTransform.value;
    _scaleBase = vt.scale;
    _focalBase = details.focalPoint;
    _panBase = vt.panOffset;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final scaleFactor = (details.scale * _scaleBase).clamp(0.08, 10.0);
    // Pan delta from focal point movement
    // Zoom around focal point
    final focalCanvas = (_focalBase - _panBase) / _scaleBase;
    final newPan = details.focalPoint - focalCanvas * scaleFactor;
    final panDelta = details.focalPoint - _focalBase;

    viewTransform.value = ViewTransform(
      scale: scaleFactor,
      panOffset: details.pointerCount >= 2 ? newPan : _panBase + panDelta,
    );
  }

  /// Call at gesture end to sync viewTransform back to a debounced auto-save.
  void onScaleEnd() {
    _debouncedAutoSave();
  }

  void updateViewportSize(Size size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
    // First time we know our viewport — push initial projection sync.
    _scheduleProjectionSync();
  }

  /// Zoom in/out centred on [focalPoint] (screen coords). [scrollDelta] > 0 = zoom out.
  void zoomAtPoint(Offset focalPoint, double scrollDelta) {
    const factor = 1.12;
    final scaleFactor = scrollDelta < 0 ? factor : 1.0 / factor;
    final vt = viewTransform.value;
    final newScale = (vt.scale * scaleFactor).clamp(0.08, 10.0);
    final focalCanvas = (focalPoint - vt.panOffset) / vt.scale;
    final newPan = focalPoint - focalCanvas * newScale;
    viewTransform.value = ViewTransform(scale: newScale, panOffset: newPan);
    _debouncedAutoSave();
  }

  /// Fit the background image (or reset to 1× if none) inside the viewport.
  void resetView() {
    final img = state.backgroundImage;
    if (img == null || _viewportSize == Size.zero) {
      viewTransform.value = const ViewTransform();
      return;
    }
    final scale = ((_viewportSize.width / img.width) < (_viewportSize.height / img.height)
            ? _viewportSize.width / img.width
            : _viewportSize.height / img.height)
        .clamp(0.08, 10.0);
    final panX = (_viewportSize.width - img.width * scale) / 2;
    final panY = (_viewportSize.height - img.height * scale) / 2;
    viewTransform.value = ViewTransform(scale: scale, panOffset: Offset(panX, panY));
  }

  // -------------------------------------------------------------------------
  // Tool
  // -------------------------------------------------------------------------

  void setTool(BattleMapTool tool) {
    // Abandon a half-placed sector (radius set, angle pending) when switching
    // tools so it doesn't linger as a ghost wedge.
    if (_awaitingSectorAngle) {
      _awaitingSectorAngle = false;
      state = state.copyWith(activeTool: tool, clearActiveMeasurement: true);
      return;
    }
    state = state.copyWith(activeTool: tool);
  }

  // -------------------------------------------------------------------------
  // Map image
  // -------------------------------------------------------------------------

  Future<void> pickMapImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;
    await applyMapImage(context, result.files.single.path!);
  }

  /// Applies a map image from any source — a freshly picked local path or an
  /// already-uploaded `dmt-asset://` ref (e.g. a location's `battlemaps`
  /// entry). `uploadMapImage` is a no-op for non-local refs, so reused refs
  /// skip R2 traffic but still flow through the same decode/state pipeline.
  Future<void> applyMapImage(BuildContext context, String pathOrRef) async {
    final oldRef = state.mapPath;
    final (ref: stored, :quotaExceeded, :tooLarge, :actualBytes) =
        await uploadMapImage(
      _ref.read,
      path: pathOrRef,
      kind: MediaKind.battleMap,
    );
    final img = await _loadImageFromFile(stored);
    if (!mounted) return;
    state = state.copyWith(
      backgroundImage: img,
      mapPath: stored,
      canvasWidth: img?.width ?? 2048,
      canvasHeight: img?.height ?? 2048,
    );
    _ref.read(combatProvider.notifier).saveMapData(
      encounterId: encounterId,
      mapPath: stored,
    );
    if (quotaExceeded && context.mounted) showQuotaFullSnackbar(context);
    if (tooLarge && context.mounted) {
      showImageTooLargeSnackbar(
        context,
        maxBytes: MediaKind.battleMap.maxBytes,
        actualBytes: actualBytes,
      );
    }
    unawaited(cleanupMapImageRef(
      _ref.read,
      removedRef: oldRef,
      flushPrefix: 'settings:',
    ));
  }

  // -------------------------------------------------------------------------
  // Fog
  // -------------------------------------------------------------------------

  void startFogDraft(Offset canvasPoint) {
    state = state.copyWith(fogDraftPoints: [canvasPoint]);
  }

  void continueFogDraft(Offset canvasPoint) {
    final pts = state.fogDraftPoints;
    if (pts.isEmpty) return;
    final last = pts.last;
    // Skip tiny movements (< 3px) to keep polygon clean
    if ((canvasPoint - last).distanceSquared < 9) return;
    state = state.copyWith(fogDraftPoints: [...pts, canvasPoint]);
  }

  Future<void> commitFogDraft() async {
    final pts = state.fogDraftPoints;
    if (pts.length < 3) {
      state = state.copyWith(fogDraftPoints: []);
      return;
    }

    final isAdding = state.activeTool == BattleMapTool.fogAdd;
    final w = _canvasWidth;
    final h = _canvasHeight;

    final existing = state.fogImage ?? await _createBlankFog(w, h, filled: false);
    final newFog = await _paintFogPolygon(existing, pts, isAdding, w, h);

    if (!mounted) return;
    state = state.copyWith(fogImage: newFog, fogDraftPoints: []);
    _fogDirtyForProjection = true;
    _scheduleDrawingsSync();
    _debouncedAutoSave();
  }

  Future<void> fillFog() async {
    final w = _canvasWidth;
    final h = _canvasHeight;
    final fog = await _createBlankFog(w, h, filled: true);
    if (!mounted) return;
    state.fogImage?.dispose();
    state = state.copyWith(fogImage: fog, fogDraftPoints: []);
    _fogDirtyForProjection = true;
    _scheduleDrawingsSync();
    _debouncedAutoSave();
  }

  Future<void> clearFog() async {
    final w = _canvasWidth;
    final h = _canvasHeight;
    final fog = await _createBlankFog(w, h, filled: false);
    if (!mounted) return;
    state.fogImage?.dispose();
    state = state.copyWith(fogImage: fog, fogDraftPoints: []);
    _fogDirtyForProjection = true;
    _scheduleDrawingsSync();
    _debouncedAutoSave();
  }

  int get _canvasWidth {
    final img = state.backgroundImage;
    return img != null ? img.width : 2048;
  }

  int get _canvasHeight {
    final img = state.backgroundImage;
    return img != null ? img.height : 2048;
  }

  Future<ui.Image> _createBlankFog(int w, int h, {required bool filled}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (filled) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = Colors.black,
      );
    }
    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  Future<ui.Image> _paintFogPolygon(
    ui.Image existing,
    List<Offset> points,
    bool isAdding,
    int w,
    int h,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    canvas.saveLayer(bounds, Paint());
    canvas.drawImage(existing, Offset.zero, Paint());

    final path = Path()..addPolygon(points, true);

    if (isAdding) {
      canvas.drawPath(path, Paint()..color = Colors.black);
    } else {
      canvas.drawPath(path, Paint()..blendMode = ui.BlendMode.clear);
    }

    canvas.restore();
    final newImg = await recorder.endRecording().toImage(w, h);
    existing.dispose();
    return newImg;
  }

  // -------------------------------------------------------------------------
  // Annotation
  // -------------------------------------------------------------------------

  void startAnnotationStroke(Offset pt, {bool erase = false}) {
    _currentPath = Path()..moveTo(pt.dx, pt.dy);
    _currentRawPoints
      ..clear()
      ..add(pt);
    _currentIsErase = erase;
    _currentColor = erase ? Colors.transparent : Colors.red;
    _currentWidth = erase ? 20.0 : 4.0;
    // Force the painter to repaint immediately. Without this the live
    // stroke wouldn't appear until the first `continueAnnotationStroke`
    // call ticks the notifier — leaving a tiny but visible "dead zone"
    // where the user can see no feedback after pressing down.
    strokeTick.value++;
  }

  void continueAnnotationStroke(Offset pt) {
    if (_currentPath == null) return;
    _currentPath!.lineTo(pt.dx, pt.dy);
    _currentRawPoints.add(pt);
    strokeTick.value++; // lightweight repaint — no Riverpod rebuild
  }

  void endAnnotationStroke() {
    if (_currentPath == null) return;
    final stroke = DrawStroke(
      path: _currentPath!,
      color: _currentColor,
      width: _currentWidth,
      rawPoints: List<Offset>.from(_currentRawPoints),
      isErase: _currentIsErase,
    );
    _currentPath = null;
    _currentRawPoints.clear();
    state = state.copyWith(strokes: [...state.strokes, stroke]);
    _scheduleDrawingsSync();
    _debouncedAutoSave();
  }

  /// Commits an in-progress ERASE drag (the mark-eraser tool). Vector strokes
  /// crossed during the drag are already whole-deleted live via [eraseMarksAt],
  /// and THOSE deletes propagate to players (the projection ships vector
  /// strokes). This additionally bakes the erase path into the legacy
  /// annotation BITMAP, which clears pre-vector-migration flattened art on the
  /// DM canvas only — that bitmap is never sent to the player projection (the
  /// snapshot ships strokes/measurements/fog, not annotationImage), so this
  /// step is DM-cosmetic. The transient stroke is discarded, not kept.
  Future<void> commitEraseStroke() async {
    // Flush the coalesced eraseMarksAt dirty state exactly once. Runs in BOTH
    // exit paths so a vector-only erase (no annotation bitmap to bake) still
    // syncs + persists its deletions.
    void flush() {
      if (_eraseDirty) {
        _eraseDirty = false;
        _scheduleDrawingsSync();
        _debouncedAutoSave();
      }
    }

    final pts = List<Offset>.from(_currentRawPoints);
    _currentPath = null;
    _currentRawPoints.clear();
    if (pts.isEmpty || state.annotationImage == null) {
      // Nothing baked to clear — vector deletes already happened live.
      strokeTick.value++;
      flush();
      return;
    }
    final w = _canvasWidth;
    final h = _canvasHeight;
    final old = state.annotationImage!;
    final recorder = ui.PictureRecorder();
    final bounds = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    final canvas = Canvas(recorder, bounds);
    // saveLayer wraps BOTH the base image and the clear path, so the clear
    // actually subtracts from the baked pixels (the old flatten drew the image
    // OUTSIDE the layer — that was the bug that made erases reappear).
    canvas.saveLayer(bounds, Paint());
    canvas.drawImage(old, Offset.zero, Paint());
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = ui.BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = _currentWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    final pic = recorder.endRecording();
    final newImg = await pic.toImage(w, h);
    pic.dispose();
    if (!mounted) {
      newImg.dispose();
      return;
    }
    // Bail if the annotation image was replaced during the await (e.g. a CDC
    // catch-up ran init()/syncFromEncounter and set a fresh annotationImage).
    // Disposing/clobbering it now would leak the new image and revert the erase
    // to stale baked content ("erase comes back").
    if (!identical(state.annotationImage, old)) {
      newImg.dispose();
      return;
    }
    old.dispose();
    state = state.copyWith(annotationImage: newImg);
    flush();
  }

  void clearAnnotation() {
    _currentPath = null;
    _currentRawPoints.clear();
    state = state.copyWith(strokes: [], clearAnnotationImage: true);
    _scheduleDrawingsSync();
    _debouncedAutoSave(); // persist the cleared state (else it survives reload)
  }

  /// Expose in-progress path for painter
  Path? get currentPath => _currentPath;
  Color get currentColor => _currentColor;
  double get currentWidth => _currentWidth;
  bool get currentIsErase => _currentIsErase;

  // -------------------------------------------------------------------------
  // Measurements
  // -------------------------------------------------------------------------

  void startMeasurement(Offset pt) {
    final tool = state.activeTool;
    // Stage 2 of a sector: the radius is locked; the second drag only sets the
    // angle, so keep the pending mark and let updateMeasurement adjust sweep.
    if (tool == BattleMapTool.aoeSector && _awaitingSectorAngle) return;
    // AoE origins snap to the nearest grid intersection (when Snap is on) so
    // templates sit cleanly on the grid; rulers stay freeform.
    final origin = (isAoeTool(tool) && state.gridSnap) ? _snapToGrid(pt) : pt;
    state = state.copyWith(
      activeMeasurement: MeasurementMark(
        type: tool,
        start: origin,
        end: origin,
        colorHex: defaultAoeColorHex(tool),
      ),
    );
  }

  void updateMeasurement(Offset pt) {
    final m = state.activeMeasurement;
    if (m == null) return;
    // Sector stage 2: center + radius fixed; the cursor's angular offset from
    // the radius direction sets the (symmetric) sweep.
    if (m.type == BattleMapTool.aoeSector && _awaitingSectorAngle) {
      final base = m.end - m.start;
      final cur = pt - m.start;
      if (base.distance < 0.01 || cur.distance < 0.01) return;
      final baseAng = math.atan2(base.dy, base.dx);
      final curAng = math.atan2(cur.dy, cur.dx);
      var diff = (curAng - baseAng).abs() % (2 * math.pi);
      if (diff > math.pi) diff = 2 * math.pi - diff;
      final sweep = (diff * 180 / math.pi * 2).clamp(1.0, 360.0);
      state = state.copyWith(
        activeMeasurement: MeasurementMark(
          type: m.type,
          start: m.start,
          end: m.end,
          colorHex: m.colorHex,
          sweepDeg: sweep,
        ),
      );
      return;
    }
    state = state.copyWith(
      activeMeasurement: MeasurementMark(
        type: m.type,
        start: m.start,
        end: pt,
        colorHex: m.colorHex,
        sweepDeg: m.sweepDeg,
      ),
    );
  }

  void commitMeasurement() {
    final m = state.activeMeasurement;
    if (m == null) return;
    // Sector stage 1 → don't persist yet; lock the radius, show a default
    // wedge, and wait for the angle drag (stage 2).
    if (m.type == BattleMapTool.aoeSector && !_awaitingSectorAngle) {
      // Ignore a zero-radius tap (no drag happened).
      if ((m.end - m.start).distance < 1) {
        state = state.copyWith(clearActiveMeasurement: true);
        return;
      }
      _awaitingSectorAngle = true;
      state = state.copyWith(
        activeMeasurement: MeasurementMark(
          type: m.type,
          start: m.start,
          end: m.end,
          colorHex: m.colorHex,
          sweepDeg: kDefaultSectorSweepDeg,
        ),
      );
      return;
    }
    if (m.type == BattleMapTool.aoeSector) {
      _awaitingSectorAngle = false;
    }
    final persistent = MeasurementMark(
      type: m.type,
      start: m.start,
      end: m.end,
      isPersistent: true,
      colorHex: m.colorHex,
      sweepDeg: m.sweepDeg,
    );
    state = state.copyWith(
      persistentMeasurements: [...state.persistentMeasurements, persistent],
      clearActiveMeasurement: true,
    );
    _scheduleDrawingsSync();
    _debouncedAutoSave();
  }

  void clearMeasurements() {
    state = state.copyWith(
      persistentMeasurements: [],
      clearActiveMeasurement: true,
    );
    _scheduleDrawingsSync();
    _debouncedAutoSave();
  }

  /// Delete measurement closest to the tap in canvas-space (within 30px)
  void deleteMeasurementAt(Offset canvasPoint) {
    const threshold = 30.0;
    final marks = state.persistentMeasurements;
    int? closest;
    double closestDist = double.infinity;

    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      final mid = (m.start + m.end) / 2;
      final dist = (mid - canvasPoint).distance;
      if (dist < closestDist) {
        closestDist = dist;
        closest = i;
      }
    }

    if (closest != null && closestDist < threshold) {
      final updated = List<MeasurementMark>.from(marks)..removeAt(closest);
      state = state.copyWith(persistentMeasurements: updated);
      _scheduleDrawingsSync();
      _debouncedAutoSave();
    }
  }

  /// Drag-eraser: removes every persistent measurement / AoE template whose
  /// geometry the pointer [canvasPoint] crosses. Called continuously while the
  /// erase tool is dragged, so passing over a shape deletes it on contact.
  void eraseMarksAt(Offset canvasPoint) {
    final marks = state.persistentMeasurements;
    final strokes = state.strokes;
    if (marks.isEmpty && strokes.isEmpty) return;
    final keptMarks = [
      for (final m in marks)
        if (!_markHit(m, canvasPoint)) m,
    ];
    // Also drop any committed pen stroke the pointer crosses. Whole-stroke
    // delete (not pixel erase) so the change propagates to players via the
    // shrunken `strokes` list. (Strokes already flattened into the annotation
    // bitmap on a prior reload aren't vector anymore — can't be removed here.)
    final keptStrokes = [
      for (final s in strokes)
        if (!_strokeHit(s, canvasPoint)) s,
    ];
    final changed = keptMarks.length != marks.length ||
        keptStrokes.length != strokes.length;
    if (!changed) return;
    state = state.copyWith(
      persistentMeasurements: keptMarks,
      strokes: keptStrokes,
    );
    // Coalesce: mark dirty and flush sync+autosave once at pan-end
    // (commitEraseStroke) rather than re-arming the timers on every pan sample.
    _eraseDirty = true;
  }

  /// True when [p] (canvas-space) is within the stroke's polyline (proximity
  /// band scaled by the pen width).
  bool _strokeHit(DrawStroke s, Offset p) {
    final pts = s.rawPoints;
    if (pts.isEmpty) return false;
    final th = 12.0 + s.width / 2;
    if (pts.length == 1) return (p - pts.first).distance <= th;
    for (var i = 0; i + 1 < pts.length; i++) {
      if (_distToSegment(p, pts[i], pts[i + 1]) <= th) return true;
    }
    return false;
  }

  /// True when [p] (canvas-space) touches mark [m]'s geometry. Lines use a
  /// proximity band; filled AoE shapes use path containment; the circle ruler
  /// uses its ring, the filled sphere its interior.
  bool _markHit(MeasurementMark m, Offset p) {
    const th = 12.0;
    switch (m.type) {
      case BattleMapTool.ruler:
        return _distToSegment(p, m.start, m.end) <= th;
      case BattleMapTool.circle:
        final r = (m.end - m.start).distance;
        return ((p - m.start).distance - r).abs() <= th;
      case BattleMapTool.aoeCircle:
        return (p - m.start).distance <= (m.end - m.start).distance;
      case BattleMapTool.aoeCone:
        return aoeConePath(m.start, m.end).contains(p);
      case BattleMapTool.aoeLine:
        return aoeLinePath(m.start, m.end, state.gridSize.toDouble()).contains(p);
      case BattleMapTool.aoeSquare:
        return aoeSquareRect(m.start, m.end).contains(p);
      case BattleMapTool.aoeSector:
        return aoeSectorPath(m.start, m.end, m.sweepDeg ?? kDefaultSectorSweepDeg)
            .contains(p);
      default:
        return false;
    }
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  // -------------------------------------------------------------------------
  // Tokens
  // -------------------------------------------------------------------------

  /// Assign default positions to combatants that don't have one yet.
  void ensureTokenPositions(List<Combatant> combatants) {
    if (!mounted) return;
    final positions = Map<String, Offset>.from(state.tokenPositions);
    var changed = false;
    var idx = 0;
    for (final c in combatants) {
      if (!positions.containsKey(c.id)) {
        final gs = state.gridSize.toDouble();
        positions[c.id] = Offset((idx % 5 + 1.5) * gs, (idx ~/ 5 + 1.5) * gs);
        changed = true;
      }
      idx++;
    }
    if (changed) {
      state = state.copyWith(tokenPositions: positions);
      persistTokenPositions();
    }
  }

  void moveToken(String combatantId, Offset canvasPos) {
    final updated = Map<String, Offset>.from(state.tokenPositions);
    updated[combatantId] = canvasPos;
    state = state.copyWith(tokenPositions: updated);
  }

  void snapTokenToGrid(String combatantId) {
    final pos = state.tokenPositions[combatantId];
    if (pos == null) return;
    final snapped = _snapToGrid(pos);
    moveToken(combatantId, snapped);
  }

  void setGlobalTokenSize(int size) {
    state = state.copyWith(tokenSize: size.clamp(20, 300));
    _scheduleDrawingsSync();
  }

  void setTokenSizeMultiplier(String combatantId, double multiplier) {
    final updated = Map<String, double>.from(state.tokenSizeMultipliers);
    updated[combatantId] = multiplier.clamp(0.25, 8.0);
    state = state.copyWith(tokenSizeMultipliers: updated);
    _scheduleDrawingsSync();
  }

  /// Persist current token positions to campaign data.
  void persistTokenPositions() {
    if (!mounted) return;
    final tokenPosMap = <String, dynamic>{};
    for (final entry in state.tokenPositions.entries) {
      tokenPosMap[entry.key] = {'x': entry.value.dx, 'y': entry.value.dy};
    }
    _ref.read(combatProvider.notifier).saveMapData(
      encounterId: encounterId,
      tokenPositions: tokenPosMap,
      tokenSizeMultipliers: state.tokenSizeMultipliers,
      tokenSize: state.tokenSize,
    );
  }

  Offset _snapToGrid(Offset pt) {
    final gs = state.gridSize.toDouble();
    return Offset(
      (pt.dx / gs).round() * gs,
      (pt.dy / gs).round() * gs,
    );
  }

  // -------------------------------------------------------------------------
  // Grid
  // -------------------------------------------------------------------------

  void setGridVisible(bool v) {
    state = state.copyWith(gridVisible: v);
    _persistGridSettings();
    _scheduleDrawingsSync();
  }

  void setGridSnap(bool v) {
    state = state.copyWith(gridSnap: v);
    _persistGridSettings();
  }

  void setGridSize(int size) {
    state = state.copyWith(gridSize: size.clamp(10, 300));
    _persistGridSettings();
    _scheduleDrawingsSync();
  }

  void setGridColumns(double columns) {
    final cellSize = (state.canvasWidth / columns).round().clamp(10, 300);
    state = state.copyWith(gridSize: cellSize);
    _persistGridSettings();
    _scheduleDrawingsSync();
  }

  void setFeetPerCell(int feet) {
    state = state.copyWith(feetPerCell: feet.clamp(1, 100));
    _persistGridSettings();
    _scheduleDrawingsSync();
  }

  /// 5e diagonal counting rule (index into `DiagonalRule.values`). Drives the
  /// distance labels on rulers/circles DM-side and projects to players.
  void setDiagonalRule(int rule) {
    state = state.copyWith(diagonalRule: rule);
    _persistGridSettings();
    _scheduleDrawingsSync();
  }

  void _persistGridSettings() {
    if (!mounted) return;
    _ref.read(combatProvider.notifier).updateGridSettings(
      encounterId: encounterId,
      gridSize: state.gridSize,
      gridVisible: state.gridVisible,
      gridSnap: state.gridSnap,
      feetPerCell: state.feetPerCell,
      diagonalRule: state.diagonalRule,
    );
    // updateGridSettings republishes activeEncounter synchronously. Restamp the
    // fingerprint from it so the listener-driven syncFromEncounter does NOT
    // re-run init() for our own grid write — re-init re-decodes bg/fog/annot and
    // re-encodes+pushes the full fog PNG over IPC on every spinbox step. A
    // genuinely different remote encounter still differs in fingerprint and
    // re-inits normally. The setters' own _scheduleDrawingsSync() already
    // pushes grid/diagonal to the projection without touching fog.
    final enc = _ref.read(combatProvider).activeEncounter;
    if (enc != null && enc.id == encounterId) {
      _stampFingerprint(enc);
    }
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  /// Edit burst'lerini PendingWriteBuffer ile coalesce et. Fog paint
  /// stroke'ları, token drag, grid setting tek tek instant fire ederse
  /// her biri combat_state outbox push'una çıkıyor → mobilde "ard arda
  /// save" görüntüsü. combatTick (500ms) tier'ı multiplayer fog güncellemesi
  /// için snappy kalır.
  void _debouncedAutoSave() {
    if (!mounted) return;
    _ref.read(pendingWriteBufferProvider).schedule(
          key: 'battlemap:$encounterId:save',
          kind: WriteKind.combatTick,
          action: () async {
            if (!mounted) return;
            await save();
          },
        );
  }

  Future<void> save() async {
    final fogB64 = await _fogToBase64();
    final annotB64 = await _annotationToBase64();
    final measurementsJson = state.persistentMeasurements.isEmpty
        ? null
        : jsonEncode(state.persistentMeasurements
            .map((m) => {
                  'type': battleMapToolToTypeString(m.type),
                  'x1': m.start.dx,
                  'y1': m.start.dy,
                  'x2': m.end.dx,
                  'y2': m.end.dy,
                  if (m.colorHex != null) 'c': m.colorHex,
                  if (m.sweepDeg != null) 's': m.sweepDeg,
                })
            .toList());
    // Pen strokes as vector JSON (reuse StrokeSnapshot's p/c/w encoding — the
    // same shape the projection sends). Skip erase + degenerate strokes.
    final keepStrokes =
        state.strokes.where((s) => !s.isErase && s.rawPoints.length >= 2);
    final strokesJson = keepStrokes.isEmpty
        ? null
        : jsonEncode([
            for (final s in keepStrokes)
              StrokeSnapshot(
                points: [for (final p in s.rawPoints) ...[p.dx, p.dy]],
                colorHex: _colorToHex(s.color),
                width: s.width,
              ).toJson(),
          ]);
    final tokenPosMap = <String, dynamic>{};
    for (final entry in state.tokenPositions.entries) {
      tokenPosMap[entry.key] = {'x': entry.value.dx, 'y': entry.value.dy};
    }

    if (!mounted) return;

    _ref.read(combatProvider.notifier).saveFogAndAnnotation(
      encounterId: encounterId,
      fogData: fogB64,
      annotationData: annotB64,
      measurementsData: measurementsJson,
      strokesData: strokesJson,
    );
    _ref.read(combatProvider.notifier).saveMapData(
      encounterId: encounterId,
      tokenPositions: tokenPosMap,
      tokenSizeMultipliers: state.tokenSizeMultipliers,
      tokenSize: state.tokenSize,
    );
    // Stamp fingerprint from the just-pushed encounter so the CDC echo or
    // own-write activeEncounter update doesn't trigger syncFromEncounter.
    final enc = _ref.read(combatProvider).activeEncounter;
    if (enc != null && enc.id == encounterId) {
      _stampFingerprint(enc);
    }
  }

  Future<String?> _fogToBase64() async {
    final img = state.fogImage;
    if (img == null) return null;
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(byteData.buffer.asUint8List());
  }

  /// Encodes ONLY the legacy/imported annotation bitmap. Pen strokes are no
  /// longer baked here — they persist as vector JSON via `strokesData` so each
  /// stays individually deletable across reload. (Baking strokes broke
  /// whole-stroke erase: once flattened they lost identity and reappeared.)
  Future<String?> _annotationToBase64() async {
    final img = state.annotationImage;
    if (img == null) return null;
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(byteData.buffer.asUint8List());
  }

  // -------------------------------------------------------------------------
  // Coordinate conversion (reads viewTransform directly)
  // -------------------------------------------------------------------------

  Offset screenToCanvas(Offset screenPt) {
    final vt = viewTransform.value;
    return (screenPt - vt.panOffset) / vt.scale;
  }

  Offset canvasToScreen(Offset canvasPt) {
    final vt = viewTransform.value;
    return canvasPt * vt.scale + vt.panOffset;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static Future<ui.Image?> _base64ToImage(String? b64) async {
    if (b64 == null || b64.isEmpty) return null;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(
      Uint8List.fromList(base64Decode(b64)),
      completer.complete,
    );
    return completer.future;
  }

  /// Decodes the background map image. [pathOrRef] may be a local path or a
  /// `dmt-asset://` cloud ref — resolved through [AssetRefResolver] (cloud
  /// refs download + cache on first use) before decoding.
  Future<ui.Image?> _loadImageFromFile(String pathOrRef) async {
    try {
      final file = await _ref
          .read(assetRefResolverProvider)
          .resolve(AssetRef(pathOrRef));
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      return completer.future;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final battleMapProvider = StateNotifierProvider.autoDispose
    .family<BattleMapNotifier, BattleMapState, String>((ref, encounterId) {
  return BattleMapNotifier(encounterId, ref);
});
