import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../domain/entities/session.dart';
import '../theme/dm_tool_colors.dart';

class ConditionBadge extends ConsumerWidget {
  final CombatCondition condition;
  final DmToolColors palette;
  final VoidCallback? onRemove;

  const ConditionBadge({required this.condition, required this.palette, this.onRemove, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Look up entity image if entityId is set
    String? imagePath;
    if (condition.entityId != null) {
      final entity = ref.watch(entityProvider.select((m) => m[condition.entityId]));
      if (entity != null) {
        if (entity.imagePath.isNotEmpty) {
          imagePath = entity.imagePath;
        } else if (entity.images.isNotEmpty) {
          imagePath = entity.images.first;
        }
      }
    }

    final hasDuration = condition.duration != null;
    final hasInitial = condition.initialDuration != null && condition.initialDuration! > 0;
    final durationText = hasDuration && hasInitial
        ? '${condition.duration}/${condition.initialDuration}'
        : hasDuration
            ? '${condition.duration}'
            : null;

    return Tooltip(
      message: '${condition.name}${hasDuration ? ' ($durationText rounds)' : ''}',
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: palette.conditionDefaultBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imagePath != null)
                ClipOval(
                  child: Image.file(
                    File(imagePath),
                    width: 16,
                    height: 16,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Text(
                  condition.name.length > 3 ? condition.name.substring(0, 3) : condition.name,
                  style: TextStyle(fontSize: 9, color: palette.conditionText, fontWeight: FontWeight.w600),
                ),
              if (durationText != null) ...[
                const SizedBox(width: 2),
                Text(durationText, style: TextStyle(fontSize: 8, color: palette.conditionText)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
