import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/session.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../screens/battle_map/battle_map_notifier.dart';
import '../../theme/dm_tool_colors.dart';
import '../asset_ref_image.dart';

/// Battle map token — canvas-space positioning.
///
/// The parent wraps all tokens in a [Transform] that applies scale + panOffset,
/// so this widget only deals with canvas-space coordinates and sizes.
/// During drag, position is tracked locally (no notifier updates per frame).
/// Only commits final position to parent on pointer-up.
///
/// Beyond the avatar circle the token draws a combat HUD in canvas-space:
/// a name label + HP bar below, and a condition chip strip above. The HUD is
/// rendered via a [Stack] with `clipBehavior: Clip.none` so it overflows the
/// token's square box without changing the drag hit area (the circle).
class TokenWidget extends StatefulWidget {
  final Combatant combatant;
  final int tokenSize;
  final bool isActive;
  final bool isSelected;
  final Offset canvasPosition; // from notifier state
  final ValueListenable<ViewTransform> viewTransform; // for drag scale
  final Color borderColor; // category color
  final String? imagePath; // entity's first image

  /// When false the token is hidden from players (DM-only). On the DM map it
  /// renders ghosted so the DM can still see + move it.
  final bool hidden;
  final DmToolColors palette;
  final VoidCallback onDragStart;
  final void Function(String id, Offset finalCanvasPos) onDragEnd;

  /// Right-click / long-press → opens the token context menu (damage, heal,
  /// hide, resize).
  final void Function(String id) onContextMenu;

  const TokenWidget({
    super.key,
    required this.combatant,
    required this.tokenSize,
    required this.isActive,
    this.isSelected = false,
    required this.canvasPosition,
    required this.viewTransform,
    required this.borderColor,
    this.imagePath,
    this.hidden = false,
    required this.palette,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onContextMenu,
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

    final borderWidth = widget.isActive ? 7.0 : 3.2;
    final hudGap = (size * 0.06).clamp(2.0, 10.0);

    // Canvas-space positioning — Transform wrapper handles screen projection.
    // The Positioned box is exactly the circle's bounding square; the HUD
    // (name/HP/conditions) overflows it via a non-clipping Stack.
    return Positioned(
      left: canvasPos.dx - size / 2,
      top: canvasPos.dy - size / 2,
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Condition chips — above the token.
          if (widget.combatant.conditions.isNotEmpty)
            Positioned(
              left: -size * 0.5,
              right: -size * 0.5,
              bottom: size + hudGap,
              child: _ConditionStrip(
                conditions: widget.combatant.conditions,
                tokenSize: size,
                palette: widget.palette,
              ),
            ),
          // The avatar circle + drag listener fills the box.
          Positioned.fill(
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
                onSecondaryTap: () =>
                    widget.onContextMenu(widget.combatant.id),
                onLongPress: () =>
                    widget.onContextMenu(widget.combatant.id),
                child: Opacity(
                  opacity: widget.hidden ? 0.45 : 1.0,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isSelected
                            ? widget.palette.featureCardAccent
                            : widget.borderColor,
                        width: widget.isSelected
                            ? borderWidth + 2.0
                            : borderWidth,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(child: _buildAvatar(size)),
                  ),
                ),
              ),
            ),
          ),
          // Name + HP bar — below the token.
          Positioned(
            left: -size * 0.5,
            right: -size * 0.5,
            top: size + hudGap,
            child: _TokenLabel(
              name: widget.combatant.name,
              hp: widget.combatant.hp,
              maxHp: widget.combatant.maxHp,
              tokenSize: size,
              hidden: widget.hidden,
              palette: widget.palette,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) {
    final path = widget.imagePath;
    if (path == null || path.isEmpty) return _buildInitials(size);
    final cacheDim = (size * 2).toInt();
    // AssetRefImage handles raw paths, local `asset://` refs, and cloud
    // `dmt-asset://` refs (downloads + caches). Falls back to initials when
    // the ref can't be resolved.
    return AssetRefImage(
      ref: AssetRef(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: cacheDim,
      cacheHeight: cacheDim,
      placeholder: _buildInitials(size),
      errorWidget: _buildInitials(size),
    );
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

/// Name label + slim HP bar drawn beneath a token, in canvas-space.
class _TokenLabel extends StatelessWidget {
  final String name;
  final int hp;
  final int maxHp;
  final double tokenSize;
  final bool hidden;
  final DmToolColors palette;

  const _TokenLabel({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.tokenSize,
    required this.hidden,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = (tokenSize * 0.2).clamp(7.0, 18.0);
    final ratio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final barHeight = (tokenSize * 0.09).clamp(2.0, 7.0);
    final barWidth = tokenSize * 0.9;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // HP bar
        ClipRRect(
          borderRadius: BorderRadius.circular(barHeight),
          child: SizedBox(
            width: barWidth,
            height: barHeight,
            child: Stack(
              children: [
                Container(color: Colors.black.withValues(alpha: 0.6)),
                FractionallySizedBox(
                  widthFactor: ratio.toDouble(),
                  child: Container(color: _hpColor(ratio.toDouble())),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: (tokenSize * 0.03).clamp(1.0, 4.0)),
        // Name + HP text
        Text(
          hidden ? '$name  (hidden)' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: hidden ? Colors.white60 : Colors.white,
            shadows: const [
              Shadow(blurRadius: 3, color: Colors.black),
              Shadow(blurRadius: 1, color: Colors.black),
            ],
          ),
        ),
      ],
    );
  }

  Color _hpColor(double ratio) {
    if (ratio > 0.66) return palette.hpBarHigh;
    if (ratio > 0.33) return palette.hpBarMed;
    return palette.hpBarLow;
  }
}

/// Compact horizontal strip of condition chips above a token, in canvas-space.
/// Shows up to 5 chips with the condition's 3-letter abbreviation + remaining
/// duration; collapses the overflow into a "+N" chip.
class _ConditionStrip extends StatelessWidget {
  final List<CombatCondition> conditions;
  final double tokenSize;
  final DmToolColors palette;

  const _ConditionStrip({
    required this.conditions,
    required this.tokenSize,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    const maxChips = 5;
    final shown = conditions.take(maxChips).toList();
    final overflow = conditions.length - shown.length;
    final fontSize = (tokenSize * 0.16).clamp(6.0, 14.0);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: (tokenSize * 0.04).clamp(1.0, 4.0),
      runSpacing: (tokenSize * 0.04).clamp(1.0, 4.0),
      children: [
        for (final c in shown) _chip(_abbrev(c.name), c.duration, fontSize),
        if (overflow > 0) _chip('+$overflow', null, fontSize),
      ],
    );
  }

  Widget _chip(String label, int? duration, double fontSize) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.35,
        vertical: fontSize * 0.15,
      ),
      decoration: BoxDecoration(
        color: palette.conditionDefaultBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(fontSize * 0.5),
        border: Border.all(color: Colors.black54, width: 0.8),
      ),
      child: Text(
        duration != null ? '$label·$duration' : label,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: palette.conditionText,
        ),
      ),
    );
  }

  static String _abbrev(String name) {
    if (name.isEmpty) return '?';
    return name.length <= 3 ? name.toUpperCase() : name.substring(0, 3).toUpperCase();
  }
}
