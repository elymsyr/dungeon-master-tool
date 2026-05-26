import 'package:flutter/material.dart';

import '../../../../domain/entities/entity.dart';
import '../../../theme/dm_tool_colors.dart';

/// Drill-in navigation bar above the world map canvas. Shows
/// `Home > Castle > Crypt > …`. Each segment is tappable and pops the stack
/// to that depth. Hidden when the user is at root.
class MapBreadcrumbBar extends StatelessWidget {
  final List<String> locationStack;
  final Map<String, Entity> entities;
  final DmToolColors palette;
  final ValueChanged<int> onJumpToDepth;

  const MapBreadcrumbBar({
    super.key,
    required this.locationStack,
    required this.entities,
    required this.palette,
    required this.onJumpToDepth,
  });

  @override
  Widget build(BuildContext context) {
    if (locationStack.isEmpty) return const SizedBox.shrink();
    final segments = <Widget>[
      _segment(context, label: 'Home', onTap: () => onJumpToDepth(0)),
    ];
    for (var i = 0; i < locationStack.length; i++) {
      segments.add(_chevron());
      final name = entities[locationStack[i]]?.name ?? '?';
      final isLast = i == locationStack.length - 1;
      segments.add(_segment(
        context,
        label: name,
        onTap: isLast ? null : () => onJumpToDepth(i + 1),
        bold: isLast,
      ));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.uiFloatingBg,
        border: Border.all(color: palette.uiFloatingBorder),
        borderRadius: palette.cbr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments,
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    VoidCallback? onTap,
    bool bold = false,
  }) {
    final text = Text(
      label,
      style: TextStyle(
        color: palette.uiFloatingText,
        fontSize: 12,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      ),
    );
    if (onTap == null) return text;
    return InkWell(
      onTap: onTap,
      borderRadius: palette.cbr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: text,
      ),
    );
  }

  Widget _chevron() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          Icons.chevron_right,
          size: 14,
          color: palette.uiFloatingText.withValues(alpha: 0.6),
        ),
      );
}
