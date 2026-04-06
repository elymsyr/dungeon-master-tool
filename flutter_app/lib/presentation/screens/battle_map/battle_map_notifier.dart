import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/combat_provider.dart';
import '../../../domain/entities/session.dart';

// ---------------------------------------------------------------------------
// Tool enum
// ---------------------------------------------------------------------------

enum BattleMapTool { navigate, ruler, circle, draw, fogAdd, fogErase }

// ---------------------------------------------------------------------------
// Supporting data classes
// ---------------------------------------------------------------------------

class DrawStroke {
  final Path path;
  final Color color;
  final double width;
  final bool isErase;

  DrawStroke({
    required this.path,
    required this.color,
    required this.width,
    this.isErase = false,
  });
}

class MeasurementMark {
  final BattleMapTool type; // ruler or circle
  final Offset start;
  final Offset end;
  final bool isPersistent;

  const MeasurementMark({
    required this.type,
    required this.start,
    required this.end,
    this.isPersistent = false,
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
  final Map<String, int> tokenSizeOverrides;

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
    this.tokenSizeOverrides = const {},
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
    Map<String, int>? tokenSizeOverrides,
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
      tokenSizeOverrides: tokenSizeOverrides ?? this.tokenSizeOverrides,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class BattleMapNotifier extends StateNotifier<BattleMapState> {
  final String encounterId;
  final Ref _ref;

  // Lightweight view transform — updated at 60fps without Riverpod overhead.
  // CustomPainter and tokens listen to this directly via repaint / ValueListenableBuilder.
  final ValueNotifier<ViewTransform> viewTransform =
      ValueNotifier<ViewTransform>(const ViewTransform());

  // Lightweight repaint signal for in-progress annotation strokes.
  final ValueNotifier<int> strokeTick = ValueNotifier<int>(0);

  // In-progress annotation stroke — mutable, NOT in state
  Path? _currentPath;
  Color _currentColor = Colors.red;
  double _currentWidth = 4.0;
  bool _currentIsErase = false;

  // Scale gesture tracking
  double _scaleBase = 1.0;
  Offset _focalBase = Offset.zero;
  Offset _panBase = Offset.zero;

  // Viewport size (updated from LayoutBuilder — not part of state)
  Size _viewportSize = Size.zero;

  // Debounced auto-save
  Timer? _autoSaveTimer;

  BattleMapNotifier(this.encounterId, this._ref) : super(const BattleMapState());

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    viewTransform.dispose();
    strokeTick.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Init
  // -------------------------------------------------------------------------

  Future<void> init(Encounter encounter) async {
    // Grid settings
    var s = state.copyWith(
      gridSize: encounter.gridSize,
      gridVisible: encounter.gridVisible,
      gridSnap: encounter.gridSnap,
      feetPerCell: encounter.feetPerCell,
      tokenSize: encounter.tokenSize,
      tokenSizeOverrides: Map<String, int>.from(encounter.tokenSizeOverrides),
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
    s = s.copyWith(tokenPositions: positions);

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
    );
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
    _viewportSize = size;
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
    state = state.copyWith(activeTool: tool);
  }

  // -------------------------------------------------------------------------
  // Map image
  // -------------------------------------------------------------------------

  Future<void> pickMapImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final img = await _loadImageFromFile(path);
    if (!mounted) return;
    state = state.copyWith(backgroundImage: img, mapPath: path);
    _ref.read(combatProvider.notifier).saveMapData(
      encounterId: encounterId,
      mapPath: path,
    );
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
    _debouncedAutoSave();
  }

  Future<void> fillFog() async {
    final w = _canvasWidth;
    final h = _canvasHeight;
    final fog = await _createBlankFog(w, h, filled: true);
    if (!mounted) return;
    state.fogImage?.dispose();
    state = state.copyWith(fogImage: fog, fogDraftPoints: []);
    _debouncedAutoSave();
  }

  Future<void> clearFog() async {
    final w = _canvasWidth;
    final h = _canvasHeight;
    final fog = await _createBlankFog(w, h, filled: false);
    if (!mounted) return;
    state.fogImage?.dispose();
    state = state.copyWith(fogImage: fog, fogDraftPoints: []);
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
    _currentIsErase = erase;
    _currentColor = erase ? Colors.transparent : Colors.red;
    _currentWidth = erase ? 20.0 : 4.0;
  }

  void continueAnnotationStroke(Offset pt) {
    if (_currentPath == null) return;
    _currentPath!.lineTo(pt.dx, pt.dy);
    strokeTick.value++; // lightweight repaint — no Riverpod rebuild
  }

  void endAnnotationStroke() {
    if (_currentPath == null) return;
    final stroke = DrawStroke(
      path: _currentPath!,
      color: _currentColor,
      width: _currentWidth,
      isErase: _currentIsErase,
    );
    _currentPath = null;
    state = state.copyWith(strokes: [...state.strokes, stroke]);
    _debouncedAutoSave();
  }

  void clearAnnotation() {
    _currentPath = null;
    state = state.copyWith(strokes: [], clearAnnotationImage: true);
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
    state = state.copyWith(
      activeMeasurement: MeasurementMark(
        type: state.activeTool,
        start: pt,
        end: pt,
      ),
    );
  }

  void updateMeasurement(Offset pt) {
    final m = state.activeMeasurement;
    if (m == null) return;
    state = state.copyWith(
      activeMeasurement: MeasurementMark(type: m.type, start: m.start, end: pt),
    );
  }

  void commitMeasurement() {
    final m = state.activeMeasurement;
    if (m == null) return;
    final persistent = MeasurementMark(
      type: m.type,
      start: m.start,
      end: m.end,
      isPersistent: true,
    );
    state = state.copyWith(
      persistentMeasurements: [...state.persistentMeasurements, persistent],
      clearActiveMeasurement: true,
    );
  }

  void clearMeasurements() {
    state = state.copyWith(
      persistentMeasurements: [],
      clearActiveMeasurement: true,
    );
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
    }
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
  }

  void setTokenSizeOverride(String combatantId, int size) {
    final updated = Map<String, int>.from(state.tokenSizeOverrides);
    updated[combatantId] = size.clamp(20, 400);
    state = state.copyWith(tokenSizeOverrides: updated);
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
      tokenSizeOverrides: state.tokenSizeOverrides,
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
  }

  void setGridSnap(bool v) {
    state = state.copyWith(gridSnap: v);
    _persistGridSettings();
  }

  void setGridSize(int size) {
    state = state.copyWith(gridSize: size.clamp(10, 300));
    _persistGridSettings();
  }

  void setFeetPerCell(int feet) {
    state = state.copyWith(feetPerCell: feet.clamp(1, 100));
    _persistGridSettings();
  }

  void _persistGridSettings() {
    if (!mounted) return;
    _ref.read(combatProvider.notifier).updateGridSettings(
      encounterId: encounterId,
      gridSize: state.gridSize,
      gridVisible: state.gridVisible,
      gridSnap: state.gridSnap,
      feetPerCell: state.feetPerCell,
    );
  }

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  void _debouncedAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) save();
    });
  }

  Future<void> save() async {
    final fogB64 = await _fogToBase64();
    final annotB64 = await _annotationToBase64();
    final tokenPosMap = <String, dynamic>{};
    for (final entry in state.tokenPositions.entries) {
      tokenPosMap[entry.key] = {'x': entry.value.dx, 'y': entry.value.dy};
    }

    if (!mounted) return;

    _ref.read(combatProvider.notifier).saveFogAndAnnotation(
      encounterId: encounterId,
      fogData: fogB64,
      annotationData: annotB64,
    );
    _ref.read(combatProvider.notifier).saveMapData(
      encounterId: encounterId,
      tokenPositions: tokenPosMap,
      tokenSizeOverrides: state.tokenSizeOverrides,
      tokenSize: state.tokenSize,
    );
  }

  Future<String?> _fogToBase64() async {
    final img = state.fogImage;
    if (img == null) return null;
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return base64Encode(byteData.buffer.asUint8List());
  }

  Future<String?> _annotationToBase64() async {
    // Flatten strokes to image if any, otherwise use existing annotationImage
    if (state.strokes.isEmpty) {
      final img = state.annotationImage;
      if (img == null) return null;
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    }

    final w = _canvasWidth;
    final h = _canvasHeight;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    // Base annotation image
    if (state.annotationImage != null) {
      canvas.drawImage(state.annotationImage!, Offset.zero, Paint());
    }

    // Committed strokes
    canvas.saveLayer(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint());
    for (final stroke in state.strokes) {
      canvas.drawPath(
        stroke.path,
        Paint()
          ..color = stroke.isErase ? Colors.transparent : stroke.color
          ..blendMode = stroke.isErase ? ui.BlendMode.clear : ui.BlendMode.srcOver
          ..strokeWidth = stroke.width
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();

    final img = await recorder.endRecording().toImage(w, h);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
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

  static Future<ui.Image?> _loadImageFromFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
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
