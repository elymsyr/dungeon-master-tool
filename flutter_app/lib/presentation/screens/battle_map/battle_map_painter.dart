import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
class BattleMapPainter extends CustomPainter {
  final BattleMapState mapState;
  final ValueNotifier<ViewTransform> viewTransform;
  final DmToolColors palette;
  final bool isDmView;

  // In-progress annotation stroke (from notifier, not in state to avoid rebuilds per point)
  final Path? currentPath;
  final Color currentColor;
  final double currentWidth;
  final bool currentIsErase;

  BattleMapPainter({
    required this.mapState,
    required this.viewTransform,
    required this.palette,
    required this.isDmView,
    required ValueNotifier<int> strokeTick,
    this.currentPath,
    this.currentColor = Colors.red,
    this.currentWidth = 4.0,
    this.currentIsErase = false,
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

    // Only need saveLayer when erase strokes are present (BlendMode.clear
    // requires compositing within an offscreen layer).
    final hasErase = mapState.strokes.any((s) => s.isErase) || currentIsErase;

    if (hasErase) {
      canvas.saveLayer(bounds, Paint());
    }

    // Committed annotation image (flattened on save)
    if (mapState.annotationImage != null) {
      canvas.drawImage(mapState.annotationImage!, Offset.zero, Paint());
    }

    // Committed strokes (since last save)
    for (final stroke in mapState.strokes) {
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

    // In-progress stroke
    if (currentPath != null) {
      canvas.drawPath(
        currentPath!,
        Paint()
          ..color = currentIsErase ? Colors.transparent : currentColor
          ..blendMode = currentIsErase ? ui.BlendMode.clear : ui.BlendMode.srcOver
          ..strokeWidth = currentWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
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
    final all = [
      ...mapState.persistentMeasurements,
      if (mapState.activeMeasurement != null) mapState.activeMeasurement!,
    ];

    for (final m in all) {
      final sStart = _toScreen(m.start, vt);
      final sEnd = _toScreen(m.end, vt);
      if (m.type == BattleMapTool.ruler) {
        _drawRuler(canvas, sStart, sEnd, vt);
      } else {
        _drawCircle(canvas, sStart, sEnd, vt);
      }
    }
  }

  Offset _toScreen(Offset canvasPt, ViewTransform vt) =>
      canvasPt * vt.scale + vt.panOffset;

  void _drawRuler(Canvas canvas, Offset s, Offset e, ViewTransform vt) {
    final linePaint = Paint()
      ..color = const Color(0xFFFFDC32)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(s, e, linePaint);
    canvas.drawCircle(s, 4, Paint()..color = const Color(0xFFFFDC32));
    canvas.drawCircle(e, 4, Paint()..color = const Color(0xFFFFDC32));

    final dist = (e - s).distance / vt.scale;
    final squares = dist / mapState.gridSize;
    final feet = squares * mapState.feetPerCell;
    final label = '${feet.toStringAsFixed(0)} ft (${squares.toStringAsFixed(1)} sq)';
    _drawLabel(canvas, (s + e) / 2 - const Offset(0, 14), label);
  }

  void _drawCircle(Canvas canvas, Offset center, Offset edge, ViewTransform vt) {
    final r = (edge - center).distance;
    final paint = Paint()
      ..color = const Color(0xFF50C8FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF50C8FF));

    final rCanvas = r / vt.scale;
    final feet = (rCanvas / mapState.gridSize) * mapState.feetPerCell;
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
    return old.mapState != mapState ||
        old.isDmView != isDmView ||
        old.currentColor != currentColor;
  }
}
