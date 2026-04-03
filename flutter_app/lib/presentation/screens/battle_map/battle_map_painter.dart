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
class BattleMapPainter extends CustomPainter {
  final BattleMapState mapState;
  final DmToolColors palette;
  final bool isDmView;

  // In-progress annotation stroke (from notifier, not in state to avoid rebuilds per point)
  final Path? currentPath;
  final Color currentColor;
  final double currentWidth;
  final bool currentIsErase;

  const BattleMapPainter({
    required this.mapState,
    required this.palette,
    required this.isDmView,
    this.currentPath,
    this.currentColor = Colors.red,
    this.currentWidth = 4.0,
    this.currentIsErase = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ---- Apply view transform ----
    canvas.save();
    canvas.translate(mapState.panOffset.dx, mapState.panOffset.dy);
    canvas.scale(mapState.scale);

    // Layer 1: Background
    _paintBackground(canvas, size);

    // Layer 2: Grid
    if (mapState.gridVisible) _paintGrid(canvas, size);

    // Layer 3: Annotation
    _paintAnnotation(canvas, size);

    // Layer 4: Fog
    _paintFog(canvas);

    // Layer 5: Fog draft
    if (mapState.fogDraftPoints.length > 1) _paintFogDraft(canvas);

    canvas.restore();

    // Layer 6: Measurements (screen-space — not affected by pan/zoom)
    _paintMeasurements(canvas);
  }

  // ---------------------------------------------------------------------------
  // Layer 1 — Background
  // ---------------------------------------------------------------------------

  void _paintBackground(Canvas canvas, Size screenSize) {
    final img = mapState.backgroundImage;
    if (img != null) {
      canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    } else {
      // Dark fallback covering the visible viewport
      final viewW = screenSize.width / mapState.scale;
      final viewH = screenSize.height / mapState.scale;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, viewW, viewH),
        Paint()..color = const Color(0xFF111111),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Layer 2 — Grid
  // ---------------------------------------------------------------------------

  void _paintGrid(Canvas canvas, Size screenSize) {
    final gs = mapState.gridSize.toDouble();
    // Cosmetic pen: 1px regardless of zoom level
    final paint = Paint()
      ..color = const Color(0x37FFFFFF) // 55/255 alpha — matches Python
      ..strokeWidth = 1.0 / mapState.scale
      ..style = PaintingStyle.stroke;

    final img = mapState.backgroundImage;
    final w = img != null ? img.width.toDouble() : screenSize.width / mapState.scale;
    final h = img != null ? img.height.toDouble() : screenSize.height / mapState.scale;

    for (double x = 0; x <= w + gs; x += gs) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    }
    for (double y = 0; y <= h + gs; y += gs) {
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
  }

  // ---------------------------------------------------------------------------
  // Layer 3 — Annotation
  // ---------------------------------------------------------------------------

  void _paintAnnotation(Canvas canvas, Size screenSize) {
    final img = mapState.backgroundImage;
    final w = img != null ? img.width.toDouble() : screenSize.width / mapState.scale;
    final h = img != null ? img.height.toDouble() : screenSize.height / mapState.scale;
    final bounds = Rect.fromLTWH(0, 0, w, h);

    canvas.saveLayer(bounds, Paint());

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

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Layer 4 — Fog
  // ---------------------------------------------------------------------------

  void _paintFog(Canvas canvas) {
    final fogImg = mapState.fogImage;
    if (fogImg == null) return;

    final opacity = isDmView ? 0.5 : 1.0;
    final bounds = Rect.fromLTWH(
      0, 0,
      fogImg.width.toDouble(),
      fogImg.height.toDouble(),
    );

    canvas.saveLayer(bounds, Paint());
    canvas.drawImage(
      fogImg,
      Offset.zero,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Layer 5 — Fog draft preview
  // ---------------------------------------------------------------------------

  void _paintFogDraft(Canvas canvas) {
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
        ..strokeWidth = 2.0 / mapState.scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // ---------------------------------------------------------------------------
  // Layer 6 — Measurements (screen-space)
  // ---------------------------------------------------------------------------

  void _paintMeasurements(Canvas canvas) {
    final all = [
      ...mapState.persistentMeasurements,
      if (mapState.activeMeasurement != null) mapState.activeMeasurement!,
    ];

    for (final m in all) {
      final sStart = _toScreen(m.start);
      final sEnd = _toScreen(m.end);
      if (m.type == BattleMapTool.ruler) {
        _drawRuler(canvas, sStart, sEnd);
      } else {
        _drawCircle(canvas, sStart, sEnd);
      }
    }
  }

  Offset _toScreen(Offset canvasPt) =>
      canvasPt * mapState.scale + mapState.panOffset;

  void _drawRuler(Canvas canvas, Offset s, Offset e) {
    final linePaint = Paint()
      ..color = const Color(0xFFFFDC32)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(s, e, linePaint);
    canvas.drawCircle(s, 4, Paint()..color = const Color(0xFFFFDC32));
    canvas.drawCircle(e, 4, Paint()..color = const Color(0xFFFFDC32));

    final dist = (e - s).distance / mapState.scale;
    final squares = dist / mapState.gridSize;
    final feet = squares * mapState.feetPerCell;
    final label = '${feet.toStringAsFixed(0)} ft (${squares.toStringAsFixed(1)} sq)';
    _drawLabel(canvas, (s + e) / 2 - const Offset(0, 14), label);
  }

  void _drawCircle(Canvas canvas, Offset center, Offset edge) {
    final r = (edge - center).distance;
    final paint = Paint()
      ..color = const Color(0xFF50C8FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF50C8FF));

    final rCanvas = r / mapState.scale;
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
    return old.mapState != mapState ||
        old.isDmView != isDmView ||
        old.currentPath != currentPath ||
        old.currentColor != currentColor;
  }
}
