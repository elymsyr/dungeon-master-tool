import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/value_objects/grid_distance.dart';
import '../../theme/dm_tool_colors.dart';
import 'battle_map_notifier.dart';

/// CustomPainter rendering all battle map layers:
/// 1. Background (map image or dark fill)
/// 2. Grid
/// 3. Annotation (committed image + in-progress strokes)
/// 4. Fog (pre-rendered ui.Image with BlendMode.clear for revealed areas)
/// 5. Fog draft (polygon outline preview)
/// 6. Measurements (ruler/circle — drawn in screen-space after canvas.restore)
///
/// Repaint is driven by [viewTransform] and [strokeTick] Listenables
/// so that pan/zoom and in-progress strokes bypass widget rebuilds entirely.
///
/// **In-progress strokes are read from [notifier] at paint-time** (not
/// captured at construction). The painter is built once per Consumer
/// rebuild — if we captured the path at construction, the very first
/// stroke after the painter was built would be invisible (because the
/// notifier creates the Path from a mouseDown that doesn't trigger a
/// state change). Reading dynamically guarantees the live stroke shows
/// up the moment `strokeTick` ticks.
class BattleMapPainter extends CustomPainter {
  final BattleMapState mapState;
  final ValueNotifier<ViewTransform> viewTransform;
  final DmToolColors palette;
  final bool isDmView;
  final BattleMapNotifier notifier;

  BattleMapPainter({
    required this.mapState,
    required this.viewTransform,
    required this.palette,
    required this.isDmView,
    required this.notifier,
    required ValueNotifier<int> strokeTick,
  }) : super(repaint: Listenable.merge([viewTransform, strokeTick]));

  @override
  void paint(Canvas canvas, Size size) {
    final vt = viewTransform.value;

    // ---- Apply view transform ----
    canvas.save();
    canvas.translate(vt.panOffset.dx, vt.panOffset.dy);
    canvas.scale(vt.scale);

    // Layer 1: Background
    _paintBackground(canvas, size, vt);

    // Layer 2: Grid (viewport-clipped)
    if (mapState.gridVisible) _paintGrid(canvas, size, vt);

    // Layer 3: Annotation
    _paintAnnotation(canvas, size, vt);

    // Layer 4: Fog
    _paintFog(canvas);

    // Layer 5: Fog draft
    if (mapState.fogDraftPoints.length > 1) _paintFogDraft(canvas, vt);

    canvas.restore();

    // Layer 6: Measurements (screen-space — not affected by pan/zoom)
    _paintMeasurements(canvas, vt);
  }

  // ---------------------------------------------------------------------------
  // Layer 1 — Background
  // ---------------------------------------------------------------------------

  void _paintBackground(Canvas canvas, Size screenSize, ViewTransform vt) {
    final img = mapState.backgroundImage;
    if (img != null) {
      canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    } else {
      // Dark fallback covering the visible viewport
      final viewW = screenSize.width / vt.scale;
      final viewH = screenSize.height / vt.scale;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, viewW, viewH),
        Paint()..color = const Color(0xFF111111),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Layer 2 — Grid (viewport-clipped for performance)
  // ---------------------------------------------------------------------------

  void _paintGrid(Canvas canvas, Size screenSize, ViewTransform vt) {
    final gs = mapState.gridSize.toDouble();
    // Cosmetic pen: 1px regardless of zoom level
    final paint = Paint()
      ..color = const Color(0x37FFFFFF) // 55/255 alpha — matches Python
      ..strokeWidth = 1.0 / vt.scale
      ..style = PaintingStyle.stroke;

    final img = mapState.backgroundImage;
    final canvasW = img != null ? img.width.toDouble() : screenSize.width / vt.scale;
    final canvasH = img != null ? img.height.toDouble() : screenSize.height / vt.scale;

    // Visible viewport in canvas-space
    final visibleLeft = -vt.panOffset.dx / vt.scale;
    final visibleTop = -vt.panOffset.dy / vt.scale;
    final visibleRight = visibleLeft + screenSize.width / vt.scale;
    final visibleBottom = visibleTop + screenSize.height / vt.scale;

    // Clamp to canvas bounds with one cell margin
    final startX = math.max(0.0, (visibleLeft / gs).floor() * gs);
    final endX = math.min(canvasW + gs, (visibleRight / gs).ceil() * gs + gs);
    final startY = math.max(0.0, (visibleTop / gs).floor() * gs);
    final endY = math.min(canvasH + gs, (visibleBottom / gs).ceil() * gs + gs);

    final yTop = math.max(0.0, startY);
    final yBot = math.min(canvasH, endY);
    final xLeft = math.max(0.0, startX);
    final xRight = math.min(canvasW, endX);

    for (double x = startX; x <= endX && x <= canvasW; x += gs) {
      canvas.drawLine(Offset(x, yTop), Offset(x, yBot), paint);
    }
    for (double y = startY; y <= endY && y <= canvasH; y += gs) {
      canvas.drawLine(Offset(xLeft, y), Offset(xRight, y), paint);
    }
  }

  // ---------------------------------------------------------------------------
  // Layer 3 — Annotation
  // ---------------------------------------------------------------------------

  void _paintAnnotation(Canvas canvas, Size screenSize, ViewTransform vt) {
    final img = mapState.backgroundImage;
    final w = img != null ? img.width.toDouble() : screenSize.width / vt.scale;
    final h = img != null ? img.height.toDouble() : screenSize.height / vt.scale;
    final bounds = Rect.fromLTWH(0, 0, w, h);

    // Read in-progress stroke state from the notifier at paint-time so a
    // mouseDown that doesn't trigger a Riverpod rebuild still becomes
    // visible the moment `strokeTick` ticks.
    final liveCurrentPath = notifier.currentPath;
    final liveCurrentColor = notifier.currentColor;
    final liveCurrentWidth = notifier.currentWidth;
    final liveCurrentIsErase = notifier.currentIsErase;

    // Only need saveLayer when erase strokes are present (BlendMode.clear
    // requires compositing within an offscreen layer).
    final hasErase =
        mapState.strokes.any((s) => s.isErase) || liveCurrentIsErase;

    if (hasErase) {
      canvas.saveLayer(bounds, Paint());
    }

    // Committed annotation image (flattened on save)
    if (mapState.annotationImage != null) {
      canvas.drawImage(mapState.annotationImage!, Offset.zero, Paint());
    }

    // Reuse a single mutable Paint across all strokes to avoid per-stroke
    // allocation (can be 100+ strokes on a busy map).
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Committed strokes (since last save)
    for (final stroke in mapState.strokes) {
      strokePaint
        ..color = stroke.isErase ? Colors.transparent : stroke.color
        ..blendMode = stroke.isErase ? ui.BlendMode.clear : ui.BlendMode.srcOver
        ..strokeWidth = stroke.width;
      canvas.drawPath(stroke.path, strokePaint);
    }

    // In-progress stroke
    if (liveCurrentPath != null) {
      strokePaint
        ..color = liveCurrentIsErase ? Colors.transparent : liveCurrentColor
        ..blendMode =
            liveCurrentIsErase ? ui.BlendMode.clear : ui.BlendMode.srcOver
        ..strokeWidth = liveCurrentWidth;
      canvas.drawPath(liveCurrentPath, strokePaint);
    }

    if (hasErase) {
      canvas.restore();
    }
  }

  // ---------------------------------------------------------------------------
  // Layer 4 — Fog
  // ---------------------------------------------------------------------------

  void _paintFog(Canvas canvas) {
    final fogImg = mapState.fogImage;
    if (fogImg == null) return;

    final opacity = isDmView ? 0.5 : 1.0;
    // Draw fog directly with opacity paint — no need for saveLayer
    canvas.drawImage(
      fogImg,
      Offset.zero,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  // ---------------------------------------------------------------------------
  // Layer 5 — Fog draft preview
  // ---------------------------------------------------------------------------

  void _paintFogDraft(Canvas canvas, ViewTransform vt) {
    final pts = mapState.fogDraftPoints;
    if (pts.length < 2) return;

    final isErase = mapState.activeTool == BattleMapTool.fogErase;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = isErase
            ? const Color(0xFF00FF88).withValues(alpha: 0.7)
            : const Color(0xFFFF3333).withValues(alpha: 0.7)
        ..strokeWidth = 2.0 / vt.scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // ---------------------------------------------------------------------------
  // Layer 6 — Measurements (screen-space)
  // ---------------------------------------------------------------------------

  void _paintMeasurements(Canvas canvas, ViewTransform vt) {
    final rule = diagonalRuleFromInt(mapState.diagonalRule);
    final all = [
      ...mapState.persistentMeasurements,
      if (mapState.activeMeasurement != null) mapState.activeMeasurement!,
    ];

    for (final m in all) {
      final sStart = _toScreen(m.start, vt);
      final sEnd = _toScreen(m.end, vt);
      switch (m.type) {
        case BattleMapTool.ruler:
          _drawRuler(canvas, sStart, sEnd, m, rule);
        case BattleMapTool.circle:
          _drawCircle(canvas, sStart, sEnd, m, rule);
        case BattleMapTool.aoeCone:
          _drawAoeShape(canvas, aoeConePath(sStart, sEnd), m,
              labelAt: sEnd, feet: _geoFeet(m.start, m.end));
        case BattleMapTool.aoeLine:
          _drawAoeShape(
              canvas, aoeLinePath(sStart, sEnd, mapState.gridSize * vt.scale), m,
              labelAt: sEnd, feet: _geoFeet(m.start, m.end));
        case BattleMapTool.aoeCircle:
          final r = (sEnd - sStart).distance;
          _drawAoeShape(canvas, Path()..addOval(Rect.fromCircle(center: sStart, radius: r)), m,
              labelAt: Offset(sStart.dx, sStart.dy - r - 12),
              feet: _geoFeet(m.start, m.end),
              radiusLabel: true);
        case BattleMapTool.aoeSquare:
          final rect = aoeSquareRect(sStart, sEnd);
          _drawAoeShape(canvas, Path()..addRect(rect), m,
              labelAt: rect.topCenter, feet: _geoSideFeet(m.start, m.end));
        case BattleMapTool.aoeSector:
          final rFeet = _geoFeet(m.start, m.end);
          if (m.sweepDeg == null) {
            // Stage 1 preview — radius guide line + full-circle outline.
            final color = _aoeColor(m);
            final r = (sEnd - sStart).distance;
            canvas.drawCircle(
                sStart,
                r,
                Paint()
                  ..color = color.withValues(alpha: 0.5)
                  ..strokeWidth = 1.5
                  ..style = PaintingStyle.stroke);
            canvas.drawLine(sStart, sEnd,
                Paint()..color = color..strokeWidth = 2);
            _drawLabel(canvas, sEnd - const Offset(0, 12),
                'r = ${rFeet.toStringAsFixed(0)} ft');
          } else {
            _drawAoeShape(canvas, aoeSectorPath(sStart, sEnd, m.sweepDeg!), m,
                labelAt: sEnd,
                feet: rFeet,
                labelOverride:
                    'r = ${rFeet.toStringAsFixed(0)} ft, ${m.sweepDeg!.toStringAsFixed(0)}°');
          }
        default:
          break;
      }
    }
  }

  Offset _toScreen(Offset canvasPt, ViewTransform vt) =>
      canvasPt * vt.scale + vt.panOffset;

  /// Euclidean size of a canvas-space segment in feet — used for AoE template
  /// labels (5e measures templates by geometry, not grid movement).
  double _geoFeet(Offset a, Offset b) {
    if (mapState.gridSize <= 0) return 0;
    return (b - a).distance / mapState.gridSize * mapState.feetPerCell;
  }

  /// Axis-aligned side length of a canvas-space drag in feet (cube/square).
  double _geoSideFeet(Offset a, Offset b) {
    if (mapState.gridSize <= 0) return 0;
    final side = math.max((b.dx - a.dx).abs(), (b.dy - a.dy).abs());
    return side / mapState.gridSize * mapState.feetPerCell;
  }

  Color _aoeColor(MeasurementMark m) {
    final hex = m.colorHex ?? defaultAoeColorHex(m.type) ?? '#ff9800';
    var clean = hex.replaceFirst('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.parse(clean, radix: 16));
  }

  void _drawAoeShape(
    Canvas canvas,
    Path path,
    MeasurementMark m, {
    required Offset labelAt,
    required double feet,
    bool radiusLabel = false,
    String? labelOverride,
  }) {
    final color = _aoeColor(m);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    final label = labelOverride ??
        (radiusLabel
            ? 'r = ${feet.toStringAsFixed(0)} ft'
            : '${feet.toStringAsFixed(0)} ft');
    _drawLabel(canvas, labelAt - const Offset(0, 8), label);
  }

  void _drawRuler(
      Canvas canvas, Offset s, Offset e, MeasurementMark m, DiagonalRule rule) {
    final linePaint = Paint()
      ..color = const Color(0xFFFFDC32)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(s, e, linePaint);
    canvas.drawCircle(s, 4, Paint()..color = const Color(0xFFFFDC32));
    canvas.drawCircle(e, 4, Paint()..color = const Color(0xFFFFDC32));

    final feet = gridDistanceFeet(m.start, m.end,
        gridSize: mapState.gridSize.toDouble(),
        feetPerCell: mapState.feetPerCell.toDouble(),
        rule: rule);
    final squares =
        mapState.feetPerCell > 0 ? feet / mapState.feetPerCell : 0.0;
    final label = '${feet.toStringAsFixed(0)} ft (${squares.toStringAsFixed(1)} sq)';
    _drawLabel(canvas, (s + e) / 2 - const Offset(0, 14), label);
  }

  void _drawCircle(
      Canvas canvas, Offset center, Offset edge, MeasurementMark m, DiagonalRule rule) {
    final r = (edge - center).distance;
    final paint = Paint()
      ..color = const Color(0xFF50C8FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF50C8FF));

    final feet = gridDistanceFeet(m.start, m.end,
        gridSize: mapState.gridSize.toDouble(),
        feetPerCell: mapState.feetPerCell.toDouble(),
        rule: rule);
    _drawLabel(canvas, center - Offset(0, r + 16), 'r = ${feet.toStringAsFixed(0)} ft');
  }

  void _drawLabel(Canvas canvas, Offset pos, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(BattleMapPainter old) {
    // View transform and stroke tick are handled by the repaint Listenable,
    // so we only check state changes that require a full repaint.
    return old.mapState != mapState || old.isDmView != isDmView;
  }
}
