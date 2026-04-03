import 'package:flutter/material.dart';

import '../../../domain/entities/session.dart';
import '../../theme/dm_tool_colors.dart';

/// Battle map token — local drag tracking for smooth movement.
/// Position is tracked locally during drag (no notifier updates per frame).
/// Only commits final position to parent on pointer-up.
class TokenWidget extends StatefulWidget {
  final Combatant combatant;
  final int tokenSize;
  final bool isActive;
  final Offset canvasPosition; // from notifier state
  final double scale;
  final Offset panOffset;
  final DmToolColors palette;
  final VoidCallback onDragStart;
  final void Function(String id, Offset finalCanvasPos) onDragEnd;
  final void Function(String id) onResizeRequested;

  const TokenWidget({
    super.key,
    required this.combatant,
    required this.tokenSize,
    required this.isActive,
    required this.canvasPosition,
    required this.scale,
    required this.panOffset,
    required this.palette,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onResizeRequested,
  });

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget> {
  // Local drag state — avoids notifier rebuilds during drag
  Offset? _dragCanvasPos;
  Offset? _lastPointerPos;

  Offset get _effectiveCanvasPos => _dragCanvasPos ?? widget.canvasPosition;

  @override
  void didUpdateWidget(TokenWidget old) {
    super.didUpdateWidget(old);
    // If not dragging, sync to external position (e.g. snap or other updates)
    if (_dragCanvasPos == null && old.canvasPosition != widget.canvasPosition) {
      // No local state to clear — widget.canvasPosition is used directly
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = widget.tokenSize * widget.scale;
    final canvasPos = _effectiveCanvasPos;
    final screenPos = canvasPos * widget.scale + widget.panOffset;

    return Positioned(
      left: screenPos.dx - screenSize / 2,
      top: screenPos.dy - screenSize / 2,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          _lastPointerPos = event.position;
          _dragCanvasPos = widget.canvasPosition;
          widget.onDragStart();
        },
        onPointerMove: (event) {
          if (_lastPointerPos == null || _dragCanvasPos == null) return;
          final screenDelta = event.position - _lastPointerPos!;
          _lastPointerPos = event.position;
          final canvasDelta = screenDelta / widget.scale;
          setState(() {
            _dragCanvasPos = _dragCanvasPos! + canvasDelta;
          });
        },
        onPointerUp: (_) {
          final finalPos = _dragCanvasPos;
          _lastPointerPos = null;
          _dragCanvasPos = null;
          if (finalPos != null) {
            widget.onDragEnd(widget.combatant.id, finalPos);
          }
        },
        onPointerCancel: (_) {
          _lastPointerPos = null;
          _dragCanvasPos = null;
        },
        child: GestureDetector(
          onSecondaryTap: () => widget.onResizeRequested(widget.combatant.id),
          child: Container(
            width: screenSize,
            height: screenSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isActive
                    ? widget.palette.tokenBorderActive
                    : widget.palette.tokenBorderNeutral,
                width: widget.isActive ? 3.0 : 2.0,
              ),
              boxShadow: widget.isActive
                  ? [BoxShadow(color: widget.palette.tokenBorderActive.withValues(alpha: 0.4), blurRadius: 8)]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipOval(child: _buildAvatar(screenSize)),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(double size) {
    final name = widget.combatant.name;
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      color: _tokenColor(),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: (size * 0.35).clamp(8.0, 24.0),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
      ),
    );
  }

  Color _tokenColor() {
    final hash = widget.combatant.name.hashCode;
    final hue = (hash.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.4).toColor();
  }
}
