import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/dm_tool_colors.dart';
import 'mind_map_notifier.dart';

/// Paints the mind map background grid, workspaces, connection edges,
/// and LOD template rectangles at extreme zoom-out.
///
/// Repaint is triggered by [edgeTick] ValueNotifier — avoids Riverpod rebuilds
/// during node drag or edge creation.
class MindMapPainter extends CustomPainter {
  final MindMapState mapState;
  final double scale;
  final Rect viewportRect;
  final DmToolColors palette;
  final String? connectingFromId;
  final Offset? connectingToCanvas;
  final int lodZone;

  MindMapPainter({
    required this.mapState,
    required this.scale,
    required this.viewportRect,
    required this.palette,
    this.connectingFromId,
    this.connectingToCanvas,
    this.lodZone = 0,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas);
    _paintWorkspaces(canvas);
    _paintEdges(canvas);
    _paintConnectingDraft(canvas);
    if (lodZone == 2) _paintLodTemplates(canvas);
  }

  // -------------------------------------------------------------------------
  // Grid
  // -------------------------------------------------------------------------

  void _paintGrid(Canvas canvas) {
    if (scale < 0.12) return;

    final useMajorOnly = scale < 0.5;
    final cellSize = useMajorOnly ? 200.0 : 50.0;
    final alpha = (useMajorOnly ? 0.25 : 0.15) * math.min(1.0, (scale - 0.12) / 0.2);

    final paint = Paint()
      ..color = palette.sidebarDivider.withValues(alpha: alpha)
      ..strokeWidth = 0.5;

    final startX = (viewportRect.left / cellSize).floor() * cellSize;
    final startY = (viewportRect.top / cellSize).floor() * cellSize;
    final endX = (viewportRect.right / cellSize).ceil() * cellSize;
    final endY = (viewportRect.bottom / cellSize).ceil() * cellSize;

    for (var x = startX; x <= endX; x += cellSize) {
      canvas.drawLine(
        Offset(x, viewportRect.top),
        Offset(x, viewportRect.bottom),
        paint,
      );
    }
    for (var y = startY; y <= endY; y += cellSize) {
      canvas.drawLine(
        Offset(viewportRect.left, y),
        Offset(viewportRect.right, y),
        paint,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Workspaces (dashed border + semi-transparent fill + label)
  // -------------------------------------------------------------------------

  void _paintWorkspaces(Canvas canvas) {
    for (final node in mapState.nodes.where((n) => n.nodeType == 'workspace')) {
      final rect = Rect.fromCenter(
        center: Offset(node.x, node.y),
        width: node.width,
        height: node.height,
      );

      // Viewport culling
      if (!viewportRect.overlaps(rect.inflate(10))) continue;

      final color = _parseHexColor(node.color);
      final isSelected = node.id == mapState.selectedNodeId;

      // Semi-transparent fill
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: 0.12),
      );

      // Dashed border
      final strokeWidth = isSelected ? 4.0 : 3.0;
      final borderColor = isSelected ? palette.lineSelected : color;
      _drawDashedRect(canvas, rect, borderColor, strokeWidth);

      // Label at top-left
      final fontSize = (14 / scale).clamp(10.0, 60.0);
      final tp = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width - 16 / scale);
      tp.paint(canvas, rect.topLeft + Offset(8 / scale, 6 / scale));
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    const dashLen = 10.0;
    const gapLen = 6.0;

    // Draw dashed line along a path
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();

    final dashedPath = _createDashedPath(path, dashLen, gapLen);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, double dashLen, double gapLen) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final segLen = math.min(draw ? dashLen : gapLen, metric.length - distance);
        if (draw) {
          result.addPath(
            metric.extractPath(distance, distance + segLen),
            Offset.zero,
          );
        }
        distance += segLen;
        draw = !draw;
      }
    }
    return result;
  }

  Color _parseHexColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  // -------------------------------------------------------------------------
  // Edges
  // -------------------------------------------------------------------------

  void _paintEdges(Canvas canvas) {
    if (mapState.edges.isEmpty) return;

    final nodeMap = <String, (double, double, double, double)>{};
    for (final n in mapState.nodes) {
      nodeMap[n.id] = (n.x, n.y, n.width, n.height);
    }

    for (final edge in mapState.edges) {
      final src = nodeMap[edge.sourceId];
      final tgt = nodeMap[edge.targetId];
      if (src == null || tgt == null) continue;

      final srcCenter = Offset(src.$1, src.$2);
      final tgtCenter = Offset(tgt.$1, tgt.$2);

      // Skip edges fully outside viewport
      final edgeBounds = Rect.fromPoints(srcCenter, tgtCenter).inflate(20);
      if (!viewportRect.overlaps(edgeBounds)) continue;

      final isSelected = edge.id == mapState.selectedEdgeId;
      final paint = Paint()
        ..color = isSelected
            ? palette.tabIndicator
            : palette.tabText.withValues(alpha: 0.45)
        ..strokeWidth = isSelected ? 2.0 : 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = _bezierPath(srcCenter, tgtCenter);
      canvas.drawPath(path, paint);
      _drawArrow(canvas, path, tgtCenter, paint.color);
    }
  }

  Path _bezierPath(Offset src, Offset tgt) {
    final dx = ((tgt.dx - src.dx).abs() * 0.5).clamp(40.0, 250.0);
    return Path()
      ..moveTo(src.dx, src.dy)
      ..cubicTo(
        src.dx + dx,
        src.dy,
        tgt.dx - dx,
        tgt.dy,
        tgt.dx,
        tgt.dy,
      );
  }

  void _drawArrow(Canvas canvas, Path path, Offset tip, Color color) {
    final metrics = path.computeMetrics().firstOrNull;
    if (metrics == null || metrics.length < 12) return;

    final tangent = metrics.getTangentForOffset(metrics.length - 10);
    if (tangent == null) return;

    final angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
    const arrowLen = 9.0;
    const spread = math.pi / 6;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      tip,
      Offset(
        tip.dx - arrowLen * math.cos(angle - spread),
        tip.dy - arrowLen * math.sin(angle - spread),
      ),
      paint,
    );
    canvas.drawLine(
      tip,
      Offset(
        tip.dx - arrowLen * math.cos(angle + spread),
        tip.dy - arrowLen * math.sin(angle + spread),
      ),
      paint,
    );
  }

  // -------------------------------------------------------------------------
  // Connecting draft (dashed line from source to cursor)
  // -------------------------------------------------------------------------

  void _paintConnectingDraft(Canvas canvas) {
    final fromId = connectingFromId;
    final toPos = connectingToCanvas;
    if (fromId == null || toPos == null) return;

    final src = mapState.nodes.where((n) => n.id == fromId).firstOrNull;
    if (src == null) return;

    final srcCenter = Offset(src.x, src.y);
    final paint = Paint()
      ..color = palette.tabIndicator.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final total = (toPos - srcCenter).distance;
    if (total < 1) return;

    final linePath = Path()
      ..moveTo(srcCenter.dx, srcCenter.dy)
      ..lineTo(toPos.dx, toPos.dy);
    final dashedPath = _createDashedPath(linePath, 8.0, 4.0);
    canvas.drawPath(dashedPath, paint);
  }

  // -------------------------------------------------------------------------
  // LOD zone 2 — simplified template rectangles (no widgets)
  // -------------------------------------------------------------------------

  void _paintLodTemplates(Canvas canvas) {
    for (final node in mapState.nodes.where((n) => n.nodeType != 'workspace')) {
      final rect = Rect.fromCenter(
        center: Offset(node.x, node.y),
        width: node.width,
        height: node.height,
      );

      // Viewport culling
      if (!viewportRect.overlaps(rect.inflate(10))) continue;

      // Background
      final bgColor = switch (node.nodeType) {
        'note' => palette.nodeBgNote,
        'entity' => palette.nodeBgEntity,
        'image' => palette.canvasBg.withValues(alpha: 0.5),
        _ => palette.tabBg,
      };
      canvas.drawRect(rect, Paint()..color = bgColor);

      // Border
      final isSelected = node.id == mapState.selectedNodeId;
      if (isSelected) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = palette.lineSelected
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke,
        );
      }

      // Label — auto-scaled to be readable regardless of zoom
      final fontSize = (13 / scale).clamp(8.0, 60.0);
      final tp = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: palette.nodeText,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: rect.width - 8 / scale);
      tp.paint(
        canvas,
        rect.topLeft + Offset(4 / scale, 4 / scale),
      );
    }
  }

  // -------------------------------------------------------------------------
  // shouldRepaint
  // -------------------------------------------------------------------------

  @override
  bool shouldRepaint(covariant MindMapPainter old) {
    return old.mapState != mapState ||
        old.scale != scale ||
        old.viewportRect != viewportRect ||
        old.connectingFromId != connectingFromId ||
        old.connectingToCanvas != connectingToCanvas ||
        old.lodZone != lodZone;
  }
}
