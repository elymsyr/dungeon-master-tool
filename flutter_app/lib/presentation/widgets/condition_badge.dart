import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/entity_provider.dart';
import '../../domain/entities/session.dart';
import '../theme/dm_tool_colors.dart';

class ConditionBadge extends ConsumerWidget {
  final CombatCondition condition;
  final String combatantId;
  final DmToolColors palette;
  final VoidCallback? onRemove;
  final void Function(int? newDuration)? onUpdateDuration;
  /// Condition entity's condition_stats field data (for tooltip).
  final Map<String, dynamic>? conditionStats;
  /// Sub-field definitions from schema (for tooltip labels).
  final List<Map<String, String>>? conditionStatsSubFields;

  const ConditionBadge({
    required this.condition,
    required this.combatantId,
    required this.palette,
    this.onRemove,
    this.onUpdateDuration,
    this.conditionStats,
    this.conditionStatsSubFields,
    super.key,
  });

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

    const size = 28.0;

    return Tooltip(
      message: _buildTooltipMessage(),
      child: GestureDetector(
        onTap: () => _showConditionMenu(context),
        child: SizedBox(
          width: size + 4,
          height: size + 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main circular image or text abbreviation
              if (imagePath != null)
                ClipOval(
                  child: Image.file(
                    File(imagePath),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    cacheWidth: (size * 2).toInt(),
                  ),
                )
              else
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: palette.conditionDefaultBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    condition.name.length > 3
                        ? condition.name.substring(0, 3)
                        : condition.name,
                    style: TextStyle(
                      fontSize: 9,
                      color: palette.conditionText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // Duration badge at bottom-right
              if (condition.duration != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${condition.duration}',
                      style: TextStyle(
                        fontSize: 8,
                        color: palette.conditionText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildTooltipMessage() {
    final parts = <String>[condition.name];
    if (condition.duration != null) {
      final durStr = condition.initialDuration != null && condition.initialDuration! > 0
          ? '${condition.duration}/${condition.initialDuration}'
          : '${condition.duration}';
      parts.add('Duration: $durStr rounds');
    }
    if (conditionStats != null && conditionStatsSubFields != null) {
      for (final sf in conditionStatsSubFields!) {
        final key = sf['key'] ?? '';
        final label = sf['label'] ?? key;
        final value = conditionStats![key];
        if (value != null && value.toString().isNotEmpty && key != 'default_duration') {
          parts.add('$label: $value');
        }
      }
    }
    return parts.join('\n');
  }

  void _showConditionMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'edit_duration',
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: palette.tabText),
              const SizedBox(width: 8),
              Text('Edit Duration', style: TextStyle(fontSize: 12, color: palette.tabText)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red[300]),
              const SizedBox(width: 8),
              Text('Remove', style: TextStyle(fontSize: 12, color: Colors.red[300])),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!context.mounted || value == null) return;
      if (value == 'remove') {
        onRemove?.call();
      } else if (value == 'edit_duration') {
        _showDurationDialog(context);
      }
    });
  }

  void _showDurationDialog(BuildContext context) {
    final controller = TextEditingController(text: '${condition.duration ?? ''}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Duration', style: TextStyle(fontSize: 14)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Duration (rounds)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onUpdateDuration?.call(int.tryParse(controller.text));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
