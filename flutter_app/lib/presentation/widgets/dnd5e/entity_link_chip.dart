import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_summary_provider.dart';
import '../../theme/dm_tool_colors.dart';
import 'card_panel_scope.dart';

/// Inline cross-entity reference. Renders as plain text in the surrounding
/// style — no chip shell, no icon, no border — just slightly muted color so
/// it reads as "linked but quiet". Pointer cursor on hover. Tap opens the
/// referenced entity in the opposite database panel via [CardPanelScope].
class EntityLinkChip extends ConsumerWidget {
  final String entityId;
  final String? displayLabel;
  final Color? color;

  const EntityLinkChip({
    required this.entityId,
    this.displayLabel,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final summary = ref.watch(entitySummaryByIdProvider)[entityId];
    final label = displayLabel ?? summary?.name ?? _titleCaseSlug(entityId);
    final scope = CardPanelScope.maybeOf(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final effectiveColor = color ?? palette.linkMuted;

    final text = Text(
      label,
      style: baseStyle.copyWith(color: effectiveColor),
    );

    if (scope == null) return text;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => scope.openInOtherPanel(entityId),
        behavior: HitTestBehavior.opaque,
        child: text,
      ),
    );
  }
}

String _titleCaseSlug(String id) {
  final idx = id.indexOf(':');
  final local = idx < 0 ? id : id.substring(idx + 1);
  if (local.isEmpty) return id;
  return local
      .split(RegExp(r'[-_]'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
