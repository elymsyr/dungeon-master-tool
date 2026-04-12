import 'package:flutter/material.dart';

import '../../../domain/entities/map_data.dart';
import '../../theme/dm_tool_colors.dart';

/// Horizontal scroll bar showing epoch segments separated by waypoints.
class EpochScrollBar extends StatefulWidget {
  final List<MapEpoch> epochs;
  final List<EpochWaypoint> waypoints;
  final int activeEpochIndex;
  final List<String> epochNames;
  final DmToolColors palette;
  final ValueChanged<int> onSwitchEpoch;
  final void Function(int insertIndex) onAddWaypoint;
  final void Function(int wpIndex) onDeleteWaypoint;
  final void Function(int wpIndex) onRenameWaypoint;
  final String startLabel;
  final String endLabel;
  final void Function(String startLabel, String endLabel)? onRenameBoundary;

  const EpochScrollBar({
    super.key,
    required this.epochs,
    required this.waypoints,
    required this.activeEpochIndex,
    required this.epochNames,
    required this.palette,
    required this.onSwitchEpoch,
    required this.onAddWaypoint,
    required this.onDeleteWaypoint,
    required this.onRenameWaypoint,
    this.startLabel = 'Start',
    this.endLabel = 'End',
    this.onRenameBoundary,
  });

  @override
  State<EpochScrollBar> createState() => _EpochScrollBarState();
}

class _EpochScrollBarState extends State<EpochScrollBar> {
  int? _hoveredSegment;
  int? _hoveredWaypoint;

  static const double _barWidth = 400;
  static const double _barHeight = 36;
  static const double _trackY = 22;
  static const double _trackPadding = 40; // space for Start/End labels
  static const double _wpRadius = 7;

  double get _trackStart => _trackPadding;
  double get _trackEnd => _barWidth - _trackPadding;
  double get _trackLength => _trackEnd - _trackStart;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Container(
      width: _barWidth,
      height: _barHeight,
      decoration: BoxDecoration(
        color: p.uiFloatingBg,
        border: Border.all(color: p.uiFloatingBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _handleTap(d.localPosition),
        onSecondaryTapUp: (d) => _handleSecondaryTap(d.localPosition, d.globalPosition),
        onLongPressStart: (d) => _handleSecondaryTap(d.localPosition, d.globalPosition),
        child: MouseRegion(
          onHover: (e) => _updateHover(e.localPosition),
          onExit: (_) => setState(() {
            _hoveredSegment = null;
            _hoveredWaypoint = null;
          }),
          child: CustomPaint(
            size: const Size(_barWidth, _barHeight),
            painter: _EpochScrollPainter(
              epochs: widget.epochs,
              waypoints: widget.waypoints,
              activeIndex: widget.activeEpochIndex,
              epochNames: widget.epochNames,
              palette: widget.palette,
              hoveredSegment: _hoveredSegment,
              hoveredWaypoint: _hoveredWaypoint,
              trackStart: _trackStart,
              trackEnd: _trackEnd,
              trackY: _trackY,
              wpRadius: _wpRadius,
              startLabel: widget.startLabel,
              endLabel: widget.endLabel,
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the x positions of each waypoint along the track.
  List<double> _waypointXPositions() {
    final count = widget.waypoints.length;
    if (count == 0) return [];
    final segmentWidth = _trackLength / (count + 1);
    return List.generate(count, (i) => _trackStart + segmentWidth * (i + 1));
  }

  /// Returns the epoch segment index for a given x position.
  int? _segmentAtX(double x) {
    if (x < _trackStart || x > _trackEnd) return null;
    final wpXs = _waypointXPositions();
    for (int i = 0; i < wpXs.length; i++) {
      if (x < wpXs[i]) return i;
    }
    return widget.epochs.length - 1;
  }

  /// Returns the waypoint index if x is close to a waypoint marker.
  int? _waypointAtX(double x) {
    final wpXs = _waypointXPositions();
    for (int i = 0; i < wpXs.length; i++) {
      if ((x - wpXs[i]).abs() <= _wpRadius + 4) return i;
    }
    return null;
  }

  void _updateHover(Offset pos) {
    final wpIdx = _waypointAtX(pos.dx);
    final segIdx = wpIdx == null ? _segmentAtX(pos.dx) : null;
    if (wpIdx != _hoveredWaypoint || segIdx != _hoveredSegment) {
      setState(() {
        _hoveredWaypoint = wpIdx;
        _hoveredSegment = segIdx;
      });
    }
  }

  void _handleTap(Offset pos) {
    // Check waypoint hit first
    final wpIdx = _waypointAtX(pos.dx);
    if (wpIdx != null) return; // waypoints use right-click

    // Check segment hit
    final segIdx = _segmentAtX(pos.dx);
    if (segIdx == null) return;

    widget.onSwitchEpoch(segIdx);
  }

  /// Returns 'start' or 'end' if x is near an endpoint marker.
  String? _endpointAtX(double x) {
    if ((x - _trackStart).abs() <= 10) return 'start';
    if ((x - _trackEnd).abs() <= 10) return 'end';
    return null;
  }

  void _handleSecondaryTap(Offset localPos, Offset globalPos) {
    // Check endpoint hit (Start / End labels)
    final ep = _endpointAtX(localPos.dx);
    if (ep != null && widget.onRenameBoundary != null) {
      _showEndpointRenameMenu(globalPos, ep);
      return;
    }

    final wpIdx = _waypointAtX(localPos.dx);
    if (wpIdx != null) {
      _showWaypointContextMenu(globalPos, wpIdx);
      return;
    }

    // Right-click on segment → add waypoint
    final segIdx = _segmentAtX(localPos.dx);
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
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: p.uiFloatingText)),
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
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _EpochScrollPainter extends CustomPainter {
  final List<MapEpoch> epochs;
  final List<EpochWaypoint> waypoints;
  final int activeIndex;
  final List<String> epochNames;
  final DmToolColors palette;
  final int? hoveredSegment;
  final int? hoveredWaypoint;
  final double trackStart;
  final double trackEnd;
  final double trackY;
  final double wpRadius;
  final String startLabel;
  final String endLabel;

  _EpochScrollPainter({
    required this.epochs,
    required this.waypoints,
    required this.activeIndex,
    required this.epochNames,
    required this.palette,
    required this.hoveredSegment,
    required this.hoveredWaypoint,
    required this.trackStart,
    required this.trackEnd,
    required this.trackY,
    required this.wpRadius,
    required this.startLabel,
    required this.endLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackLength = trackEnd - trackStart;
    final segCount = epochs.length;
    final wpCount = waypoints.length;

    // Waypoint x positions (evenly spaced)
    final wpXs = <double>[];
    if (wpCount > 0) {
      final segW = trackLength / (wpCount + 1);
      for (int i = 0; i < wpCount; i++) {
        wpXs.add(trackStart + segW * (i + 1));
      }
    }

    // Segment boundaries
    final segBounds = <(double, double)>[];
    for (int i = 0; i < segCount; i++) {
      final left = i == 0 ? trackStart : wpXs[i - 1];
      final right = i >= wpXs.length ? trackEnd : wpXs[i];
      segBounds.add((left, right));
    }

    // Draw active segment highlight
    if (activeIndex >= 0 && activeIndex < segBounds.length) {
      final (l, r) = segBounds[activeIndex];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(l, trackY - 8, r, trackY + 8),
            const Radius.circular(3)),
        Paint()..color = palette.tabIndicator.withValues(alpha: 0.2),
      );
    }

    // Draw hovered segment highlight
    if (hoveredSegment != null &&
        hoveredSegment != activeIndex &&
        hoveredSegment! < segBounds.length) {
      final (l, r) = segBounds[hoveredSegment!];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(l, trackY - 8, r, trackY + 8),
            const Radius.circular(3)),
        Paint()..color = palette.uiFloatingText.withValues(alpha: 0.05),
      );
    }

    // Draw track line
    canvas.drawLine(
      Offset(trackStart, trackY),
      Offset(trackEnd, trackY),
      Paint()
        ..color = palette.uiFloatingBorder
        ..strokeWidth = 2,
    );

    // Draw endpoint markers
    _drawEndpoint(canvas, trackStart, trackY, startLabel);
    _drawEndpoint(canvas, trackEnd, trackY, endLabel);

    // Draw waypoint markers
    for (int i = 0; i < wpXs.length; i++) {
      final isHovered = hoveredWaypoint == i;
      _drawWaypoint(canvas, wpXs[i], trackY, waypoints[i], isHovered);
    }

    // Draw epoch name for active segment
    if (activeIndex >= 0 && activeIndex < epochNames.length) {
      final name = epochNames[activeIndex];
      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontSize: 9,
            color: palette.uiFloatingText.withValues(alpha: 0.6),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final (sl, sr) = segBounds[activeIndex];
      final cx = (sl + sr) / 2 - tp.width / 2;
      tp.paint(canvas, Offset(cx.clamp(2, size.width - tp.width - 2), 2));
    }
  }

  void _drawEndpoint(Canvas canvas, double x, double y, String label) {
    canvas.drawCircle(
      Offset(x, y),
      4,
      Paint()..color = palette.uiFloatingBorder,
    );
    final display = _shortLabel(label);
    final tp = TextPainter(
      text: TextSpan(
        text: display,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: palette.uiFloatingText.withValues(alpha: 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 36);
    tp.paint(canvas, Offset(x - tp.width / 2, y - 16));
  }

  void _drawWaypoint(
      Canvas canvas, double x, double y, EpochWaypoint wp, bool isHovered) {
    // Circle
    canvas.drawCircle(
      Offset(x, y),
      wpRadius,
      Paint()
        ..color = isHovered
            ? palette.tabIndicator
            : palette.uiFloatingText.withValues(alpha: 0.7),
    );

    // Label
    final displayLabel = _shortLabel(wp.label);
    final tp = TextPainter(
      text: TextSpan(
        text: displayLabel,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isHovered
              ? palette.tabIndicator
              : palette.uiFloatingText.withValues(alpha: 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - wpRadius - 12));
  }

  String _shortLabel(String label) {
    if (label.isEmpty) return '?';
    if (RegExp(r'^[\d./-]+$').hasMatch(label)) return label;
    return label
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
  }

  @override
  bool shouldRepaint(covariant _EpochScrollPainter old) =>
      old.activeIndex != activeIndex ||
      old.hoveredSegment != hoveredSegment ||
      old.hoveredWaypoint != hoveredWaypoint ||
      old.epochs != epochs ||
      old.waypoints != waypoints;
}
