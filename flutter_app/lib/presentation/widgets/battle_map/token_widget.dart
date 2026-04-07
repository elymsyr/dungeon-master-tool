import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/session.dart';
import '../../screens/battle_map/battle_map_notifier.dart';
import '../../theme/dm_tool_colors.dart';

/// Battle map token — canvas-space positioning.
///
/// The parent wraps all tokens in a [Transform] that applies scale + panOffset,
/// so this widget only deals with canvas-space coordinates and sizes.
/// During drag, position is tracked locally (no notifier updates per frame).
/// Only commits final position to parent on pointer-up.
class TokenWidget extends StatefulWidget {
  final Combatant combatant;
  final int tokenSize;
  final bool isActive;
  final Offset canvasPosition; // from notifier state
  final ValueListenable<ViewTransform> viewTransform; // for drag scale
  final Color borderColor; // category color
  final String? imagePath; // entity's first image
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
    required this.viewTransform,
    required this.borderColor,
    this.imagePath,
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
  Widget build(BuildContext context) {
    final size = widget.tokenSize.toDouble();
    final canvasPos = _effectiveCanvasPos;

    final borderWidth = widget.isActive ? 5.0 : 3.2;

    // Canvas-space positioning — Transform wrapper handles screen projection
    return Positioned(
      left: canvasPos.dx - size / 2,
      top: canvasPos.dy - size / 2,
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
          // Read scale imperatively — no rebuild triggered
          final scale = widget.viewTransform.value.scale;
          final canvasDelta = screenDelta / scale;
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
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.borderColor, width: borderWidth),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: widget.borderColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipOval(child: _buildAvatar(size)),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(double size) {
    final path = widget.imagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildInitials(size),
        );
      }
    }
    return _buildInitials(size);
  }

  Widget _buildInitials(double size) {
    final name = widget.combatant.name;
    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
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
