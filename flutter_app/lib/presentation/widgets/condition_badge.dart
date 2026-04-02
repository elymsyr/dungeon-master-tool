import 'package:flutter/material.dart';

import '../../domain/entities/session.dart';
import '../theme/dm_tool_colors.dart';

class ConditionBadge extends StatelessWidget {
  final CombatCondition condition;
  final DmToolColors palette;
  final VoidCallback? onRemove;

  const ConditionBadge({required this.condition, required this.palette, this.onRemove, super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${condition.name}${condition.duration != null ? ' (${condition.duration} rounds)' : ''}',
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: palette.conditionDefaultBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                condition.name.length > 3 ? condition.name.substring(0, 3) : condition.name,
                style: TextStyle(fontSize: 9, color: palette.conditionText, fontWeight: FontWeight.w600),
              ),
              if (condition.duration != null) ...[
                const SizedBox(width: 2),
                Text('${condition.duration}', style: TextStyle(fontSize: 8, color: palette.conditionText)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
