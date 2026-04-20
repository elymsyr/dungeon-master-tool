import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_summary_provider.dart';
import '../../theme/dm_tool_colors.dart';
import 'card_panel_scope.dart';
import 'card_shell.dart' show CardTag;

/// Tappable, hover-preview chip for cross-entity references (e.g. a
/// spell's schoolId pointing at `srd:evocation`, a monster action's
/// damage-type id, etc.). Tap opens the referenced entity in the opposite
/// database panel via [CardPanelScope]; hover surfaces the entity's name
/// + category via a built-in [Tooltip].
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
    final label = displayLabel ?? summary?.name ?? _localSlug(entityId);
    final tooltipLines = <String>[
      summary?.name ?? _localSlug(entityId),
      if (summary != null) summary.categorySlug.toUpperCase(),
      entityId,
    ];
    final scope = CardPanelScope.maybeOf(context);

    final chip = MouseRegion(
      cursor: scope == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color ?? palette.tabBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scope == null
                ? palette.sidebarDivider
                : palette.sidebarDivider.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Tooltip(
      message: tooltipLines.join('\n'),
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: scope == null ? null : () => scope.openInOtherPanel(entityId),
        child: chip,
      ),
    );
  }
}

/// Non-interactive fallback used inside tag-row of cards when the id is
/// not resolvable (e.g. raw slug without a matching entity). Kept for
/// layout parity with [EntityLinkChip] so switching between tappable and
/// non-tappable never changes sizing.
class EntityStaticChip extends StatelessWidget {
  final String label;
  const EntityStaticChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) => CardTag(label);
}

String _localSlug(String id) {
  final idx = id.indexOf(':');
  return idx < 0 ? id : id.substring(idx + 1);
}
