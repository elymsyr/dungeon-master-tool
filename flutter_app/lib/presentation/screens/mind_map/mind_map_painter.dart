import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/mind_map.dart';
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
  final Map<String, Offset> dragOverrides;

  // -----------------------------------------------------------------------
  // Static caches — survive painter reconstruction across frames
  // -----------------------------------------------------------------------
  static final _colorCache = <String, Color>{};
  static final _wsLabelCache = <String, TextPainter>{};
  static final _dashedRectCache = <int, Path>{};
  static final _arrowCache = <int, double>{};
  static final _nodeLabelCache = <String, TextPainter>{};
  static List<MindMapNode>? _lastNodes;

  MindMapPainter({
    required this.mapState,
    required this.scale,
    required this.viewportRect,
    required this.palette,
    this.connectingFromId,
    this.connectingToCanvas,
    this.lodZone = 0,
    this.dragOverrides = const {},
    super.repaint,
  });

  /// Clear label and path caches when the node list changes structurally.
  void _checkCacheValidity() {
    if (!identical(_lastNodes, mapState.nodes)) {
      _lastNodes = mapState.nodes;
      _wsLabelCache.clear();
      _dashedRectCache.clear();
      _nodeLabelCache.clear();
      _arrowCache.clear();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _checkCacheValidity();
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
      if (!viewportRect.overlaps(rect.inflate(50))) continue;

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

      // Label at top-left (cached TextPainter)
      final fontSize = (14 / scale).clamp(10.0, 60.0);
      final maxW = rect.width - 16 / scale;
      final cacheKey = '${node.label}_${fontSize.toStringAsFixed(1)}_${maxW.toStringAsFixed(0)}';
      final tp = _wsLabelCache.putIfAbsent(cacheKey, () => TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxW));
      tp.paint(canvas, rect.topLeft + Offset(8 / scale, 6 / scale));
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final key = Object.hash(rect.left, rect.top, rect.right, rect.bottom);
    final dashedPath = _dashedRectCache.putIfAbsent(key, () {
      final path = Path()
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      return _createDashedPath(path, 10.0, 6.0);
    });
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
    return _colorCache.putIfAbsent(hex, () {
      var h = hex.replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    });
  }

  // -------------------------------------------------------------------------
  // Edges
  // -------------------------------------------------------------------------

  void _paintEdges(Canvas canvas) {
    if (mapState.edges.isEmpty) return;

    final nodeMap = <String, (double, double, double, double)>{};
    for (final n in mapState.nodes) {
      // Use drag override position if available (during active drag)
      final override = dragOverrides[n.id];
      final x = override?.dx ?? n.x;
      final y = override?.dy ?? n.y;
      nodeMap[n.id] = (x, y, n.width, n.height);
    }

    for (final edge in mapState.edges) {
      final src = nodeMap[edge.sourceId];
      final tgt = nodeMap[edge.targetId];
      if (src == null || tgt == null) continue;

      final srcCenter = Offset(src.$1, src.$2);
      final tgtCenter = Offset(tgt.$1, tgt.$2);

      // Skip edges fully outside viewport (inflate accounts for curve bulge)
      final edgeBounds = Rect.fromPoints(srcCenter, tgtCenter).inflate(60);
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
      _drawArrow(canvas, path, tgtCenter, paint.color, srcCenter);
    }
  }

  Path _bezierPath(Offset src, Offset tgt) {
    // Smooth S-curve: control points offset along the dominant axis
    final dx = (tgt.dx - src.dx).abs();
    final dy = (tgt.dy - src.dy).abs();
    final spread = (math.max(dx, dy) * 0.4).clamp(30.0, 200.0);

    // Horizontal-dominant: offset control points horizontally
    // Vertical-dominant: offset control points vertically
    final horizontal = dx >= dy;

    return Path()
      ..moveTo(src.dx, src.dy)
      ..cubicTo(
        horizontal ? src.dx + spread : src.dx,
        horizontal ? src.dy : src.dy + spread,
        horizontal ? tgt.dx - spread : tgt.dx,
        horizontal ? tgt.dy : tgt.dy - spread,
        tgt.dx,
        tgt.dy,
      );
  }

  void _drawArrow(Canvas canvas, Path path, Offset tip, Color color,
      Offset srcCenter) {
    final key = Object.hash(
      srcCenter.dx.toInt(), srcCenter.dy.toInt(),
      tip.dx.toInt(), tip.dy.toInt(),
    );

    final angle = _arrowCache.putIfAbsent(key, () {
      final metrics = path.computeMetrics().firstOrNull;
      if (metrics == null || metrics.length < 12) return double.nan;
      final tangent = metrics.getTangentForOffset(metrics.length - 10);
      if (tangent == null) return double.nan;
      return math.atan2(tangent.vector.dy, tangent.vector.dx);
    });

    if (angle.isNaN) return;

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

    final override = dragOverrides[fromId];
    final srcCenter = override ?? Offset(src.x, src.y);
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
      if (!viewportRect.overlaps(rect.inflate(50))) continue;

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

      // Label — cached TextPainter
      final fontSize = (13 / scale).clamp(8.0, 60.0);
      final maxW = rect.width - 8 / scale;
      final cacheKey = '${node.label}_${fontSize.toStringAsFixed(1)}_${maxW.toStringAsFixed(0)}';
      final tp = _nodeLabelCache.putIfAbsent(cacheKey, () => TextPainter(
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
      )..layout(maxWidth: maxW));
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
        old.lodZone != lodZone ||
        old.dragOverrides != dragOverrides;
  }
}
