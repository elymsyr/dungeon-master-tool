import 'package:flutter/material.dart';

import '../../../domain/entities/map_data.dart';
import '../../theme/dm_tool_colors.dart';

/// Vertical era bar — opens upward from bottom-left.
/// Start at top, End at bottom. Fixed segment height per era.
class EraScrollBar extends StatefulWidget {
  final List<MapEra> eras;
  final List<EraWaypoint> waypoints;
  final int activeEraIndex;
  final DmToolColors palette;
  final ValueChanged<int> onSwitchEra;
  final void Function(int insertIndex) onAddWaypoint;
  final void Function(int wpIndex) onDeleteWaypoint;
  final void Function(int wpIndex) onRenameWaypoint;
  final String startLabel;
  final String endLabel;
  final void Function(String startLabel, String endLabel)? onRenameBoundary;

  const EraScrollBar({
    super.key,
    required this.eras,
    required this.waypoints,
    required this.activeEraIndex,
    required this.palette,
    required this.onSwitchEra,
    required this.onAddWaypoint,
    required this.onDeleteWaypoint,
    required this.onRenameWaypoint,
    this.startLabel = 'Start',
    this.endLabel = 'End',
    this.onRenameBoundary,
  });

  @override
  State<EraScrollBar> createState() => _EraScrollBarState();
}

class _EraScrollBarState extends State<EraScrollBar> {
  int? _hoveredSegment;
  int? _hoveredWaypoint;

  static const double _barWidth = 200;
  static const double _segmentHeight = 32;
  static const double _wpRadius = 8;
  static const double _trackX = 28;
  static const double _paddingV = 16;

  @override
  Widget build(BuildContext context) {
    final eraCount = widget.eras.length;
    final wpCount = widget.waypoints.length;
    final barHeight =
        _paddingV * 2 + eraCount * _segmentHeight + wpCount * _segmentHeight;

    const trackTop = _paddingV; // small y → top of canvas (Start)
    final trackBottom = barHeight - _paddingV; // large y → bottom (End)

    return SizedBox(
      width: _barWidth,
      height: barHeight.toDouble(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _handleTap(d.localPosition, trackTop, trackBottom),
        onSecondaryTapUp: (d) => _handleSecondaryTap(
            d.localPosition, d.globalPosition, trackTop, trackBottom),
        onLongPressStart: (d) => _handleSecondaryTap(
            d.localPosition, d.globalPosition, trackTop, trackBottom),
        child: MouseRegion(
          onHover: (e) => _updateHover(
              e.localPosition, trackTop, trackBottom, eraCount),
          onExit: (_) => setState(() {
            _hoveredSegment = null;
            _hoveredWaypoint = null;
          }),
          child: CustomPaint(
            size: Size(_barWidth, barHeight.toDouble()),
            painter: _EraScrollPainter(
              eras: widget.eras,
              waypoints: widget.waypoints,
              activeIndex: widget.activeEraIndex,
              palette: widget.palette,
              hoveredSegment: _hoveredSegment,
              hoveredWaypoint: _hoveredWaypoint,
              trackTop: trackTop,
              trackBottom: trackBottom,
              trackX: _trackX,
              wpRadius: _wpRadius,
              barWidth: _barWidth,
              startLabel: widget.startLabel,
              endLabel: widget.endLabel,
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the y positions of each waypoint along the track.
  /// Waypoints sit between segments, fixed spacing. Start at top (small y),
  /// going down (increasing y) toward End at bottom.
  List<double> _waypointYPositions(double trackTop, double trackBottom) {
    final count = widget.waypoints.length;
    if (count == 0) return [];
    final trackLen = trackBottom - trackTop; // positive (bottom > top)
    final step = trackLen / (count + 1);
    return List.generate(count, (i) => trackTop + step * (i + 1));
  }

  /// Returns the era segment index for a given y position.
  /// Segments are between waypoints. Top-most segment = index 0.
  int? _segmentAtY(double y, double trackTop, double trackBottom) {
    if (y < trackTop || y > trackBottom) return null;
    final wpYs = _waypointYPositions(trackTop, trackBottom);
    // wpYs is ascending (top → bottom). Walk from top (low y) downward.
    for (int i = 0; i < wpYs.length; i++) {
      if (y < wpYs[i]) return i;
    }
    return widget.eras.length - 1;
  }

  /// Returns the waypoint index if y is close to a waypoint marker.
  int? _waypointAtY(double y, double trackTop, double trackBottom) {
    final wpYs = _waypointYPositions(trackTop, trackBottom);
    for (int i = 0; i < wpYs.length; i++) {
      if ((y - wpYs[i]).abs() <= _wpRadius + 6) return i;
    }
    return null;
  }

  void _updateHover(
      Offset pos, double trackTop, double trackBottom, int eraCount) {
    final wpIdx = _waypointAtY(pos.dy, trackTop, trackBottom);
    final segIdx =
        wpIdx == null ? _segmentAtY(pos.dy, trackTop, trackBottom) : null;
    if (wpIdx != _hoveredWaypoint || segIdx != _hoveredSegment) {
      setState(() {
        _hoveredWaypoint = wpIdx;
        _hoveredSegment = segIdx;
      });
    }
  }

  void _handleTap(Offset pos, double trackTop, double trackBottom) {
    final wpIdx = _waypointAtY(pos.dy, trackTop, trackBottom);
    if (wpIdx != null) return;

    final segIdx = _segmentAtY(pos.dy, trackTop, trackBottom);
    if (segIdx == null) return;

    widget.onSwitchEra(segIdx);
  }

  String? _endpointAtY(double y, double trackTop, double trackBottom) {
    if ((y - trackTop).abs() <= 12) return 'start'; // top = Start
    if ((y - trackBottom).abs() <= 12) return 'end'; // bottom = End
    return null;
  }

  void _handleSecondaryTap(
      Offset localPos, Offset globalPos, double trackTop, double trackBottom) {
    final ep = _endpointAtY(localPos.dy, trackTop, trackBottom);
    if (ep != null && widget.onRenameBoundary != null) {
      _showEndpointRenameMenu(globalPos, ep);
      return;
    }

    final wpIdx = _waypointAtY(localPos.dy, trackTop, trackBottom);
    if (wpIdx != null) {
      _showWaypointContextMenu(globalPos, wpIdx);
      return;
    }

    final segIdx = _segmentAtY(localPos.dy, trackTop, trackBottom);
    if (segIdx != null) {
      widget.onAddWaypoint(segIdx);
    }
  }

  void _showEndpointRenameMenu(Offset globalPos, String which) {
    final p = widget.palette;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      color: p.uiFloatingBg,
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(children: [
            Icon(Icons.edit, size: 14, color: p.uiFloatingText),
            const SizedBox(width: 8),
            Text('Rename',
                style: TextStyle(fontSize: 12, color: p.uiFloatingText)),
          ]),
        ),
      ],
    ).then((value) {
      if (value != 'rename') return;
      final current =
          which == 'start' ? widget.startLabel : widget.endLabel;
      _showRenameBoundaryDialog(current, which);
    });
  }

  void _showRenameBoundaryDialog(String current, String which) {
    final p = widget.palette;
    final ctrl = TextEditingController(text: current);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.uiFloatingBg,
        title: Text('Rename ${which == 'start' ? 'Start' : 'End'}',
            style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 12, color: p.uiFloatingText),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: p.uiFloatingText)),
          ),
          ElevatedButton(
            onPressed: () {
              final label = ctrl.text.trim();
              if (label.isNotEmpty) Navigator.pop(ctx, label);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((newLabel) {
      if (newLabel == null) return;
      if (which == 'start') {
        widget.onRenameBoundary?.call(newLabel, widget.endLabel);
      } else {
        widget.onRenameBoundary?.call(widget.startLabel, newLabel);
      }
    }).whenComplete(ctrl.dispose);
  }

  void _showWaypointContextMenu(Offset globalPos, int wpIndex) {
    final p = widget.palette;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      color: p.uiFloatingBg,
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(children: [
            Icon(Icons.edit, size: 14, color: p.uiFloatingText),
            const SizedBox(width: 8),
            Text('Rename',
                style: TextStyle(fontSize: 12, color: p.uiFloatingText)),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 14, color: Colors.red[300]),
            const SizedBox(width: 8),
            Text('Delete',
                style: TextStyle(fontSize: 12, color: Colors.red[300])),
          ]),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'rename':
          widget.onRenameWaypoint(wpIndex);
        case 'delete':
          widget.onDeleteWaypoint(wpIndex);
        default:
          break;
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Vertical Painter — Start at top, End at bottom
// ---------------------------------------------------------------------------

class _EraScrollPainter extends CustomPainter {
  final List<MapEra> eras;
  final List<EraWaypoint> waypoints;
  final int activeIndex;
  final DmToolColors palette;
  final int? hoveredSegment;
  final int? hoveredWaypoint;
  final double trackTop;
  final double trackBottom;
  final double trackX;
  final double wpRadius;
  final double barWidth;
  final String startLabel;
  final String endLabel;

  _EraScrollPainter({
    required this.eras,
    required this.waypoints,
    required this.activeIndex,
    required this.palette,
    required this.hoveredSegment,
    required this.hoveredWaypoint,
    required this.trackTop,
    required this.trackBottom,
    required this.trackX,
    required this.wpRadius,
    required this.barWidth,
    required this.startLabel,
    required this.endLabel,
  });

  late final Paint _activeSegPaint = Paint()
    ..color = palette.tabIndicator.withValues(alpha: 0.2);
  late final Paint _hoverSegPaint = Paint()
    ..color = palette.uiFloatingText.withValues(alpha: 0.05);
  late final Paint _trackPaint = Paint()
    ..color = palette.uiFloatingBorder
    ..strokeWidth = 2;
  late final Paint _endpointPaint = Paint()..color = palette.uiFloatingBorder;
  late final Paint _waypointPaint = Paint()
    ..color = palette.uiFloatingText.withValues(alpha: 0.7);
  late final Paint _waypointHoverPaint = Paint()..color = palette.tabIndicator;

  @override
  void paint(Canvas canvas, Size size) {
    final segCount = eras.length;
    final wpCount = waypoints.length;

    // Waypoint y positions (fixed spacing).
    // trackBottom is high y (bottom of canvas), trackTop is low y (top).
    final wpYs = <double>[];
    if (wpCount > 0) {
      final trackLen = trackBottom - trackTop; // positive (bottom > top)
      final step = trackLen / (wpCount + 1);
      for (int i = 0; i < wpCount; i++) {
        wpYs.add(trackTop + step * (i + 1)); // from top, going down
      }
    }

    // Segment boundaries (y ranges).
    // Segment 0 is top-most (near Start), segment N-1 is bottom-most (near End).
    final segBounds = <(double, double)>[]; // (top, bottom) in canvas coords
    for (int i = 0; i < segCount; i++) {
      final top = i == 0 ? trackTop : wpYs[i - 1];
      final bottom = i >= wpYs.length ? trackBottom : wpYs[i];
      segBounds.add((top, bottom));
    }

    // Draw active segment highlight
    if (activeIndex >= 0 && activeIndex < segBounds.length) {
      final (t, b) = segBounds[activeIndex];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(trackX - 12, t, trackX + 12, b),
            palette.br.topLeft),
        _activeSegPaint,
      );
    }

    // Draw hovered segment highlight
    if (hoveredSegment != null &&
        hoveredSegment != activeIndex &&
        hoveredSegment! < segBounds.length) {
      final (t, b) = segBounds[hoveredSegment!];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(trackX - 12, t, trackX + 12, b),
            palette.br.topLeft),
        _hoverSegPaint,
      );
    }

    // Draw vertical track line
    canvas.drawLine(
      Offset(trackX, trackTop),
      Offset(trackX, trackBottom),
      _trackPaint,
    );

    // Draw endpoint: Start at top, End at bottom
    _drawEndpoint(canvas, trackX, trackTop, startLabel);
    _drawEndpoint(canvas, trackX, trackBottom, endLabel);

    // Draw waypoint markers
    for (int i = 0; i < wpYs.length; i++) {
      final isHovered = hoveredWaypoint == i;
      _drawWaypoint(canvas, trackX, wpYs[i], waypoints[i], isHovered);
    }
  }

  void _drawEndpoint(Canvas canvas, double x, double y, String label) {
    canvas.drawCircle(Offset(x, y), 5, _endpointPaint);
    final display = label.isEmpty ? '?' : label;
    final tp = TextPainter(
      text: TextSpan(
        text: display,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: palette.uiFloatingText.withValues(alpha: 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 100);
    tp.paint(canvas, Offset(x + 12, y - tp.height / 2));
  }

  void _drawWaypoint(
      Canvas canvas, double x, double y, EraWaypoint wp, bool isHovered) {
    canvas.drawCircle(
      Offset(x, y),
      wpRadius,
      isHovered ? _waypointHoverPaint : _waypointPaint,
    );

    // Full label, to the right of the circle
    final displayLabel = wp.label.isEmpty ? '?' : wp.label;
    final tp = TextPainter(
      text: TextSpan(
        text: displayLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isHovered
              ? palette.tabIndicator
              : palette.uiFloatingText.withValues(alpha: 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: barWidth - trackX - wpRadius - 20);
    tp.paint(canvas, Offset(x + wpRadius + 10, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EraScrollPainter old) =>
      old.activeIndex != activeIndex ||
      old.hoveredSegment != hoveredSegment ||
      old.hoveredWaypoint != hoveredWaypoint ||
      old.eras != eras ||
      old.waypoints != waypoints ||
      old.startLabel != startLabel ||
      old.endLabel != endLabel;
}
