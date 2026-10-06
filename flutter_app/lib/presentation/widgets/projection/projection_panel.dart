import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/projection_provider.dart';
import '../../theme/dm_tool_colors.dart';
import 'projection_thumb_chip.dart';
import '../../l10n/app_localizations.dart';

/// Opens [ProjectionPanel] in a window — from the projection outputs menu
/// and the "View" action of the projected snackbar.
Future<void> showPlayerViewWindow(BuildContext context) {
  final palette = Theme.of(context).extension<DmToolColors>()!;
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: palette.uiPopupBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: palette.br,
        side: BorderSide(color: palette.featureCardBorder),
      ),
      child: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      L10n.of(ctx)!.sessionPlayerScreen,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: L10n.of(ctx)!.btnClose,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Expanded(child: ProjectionPanel()),
          ],
        ),
      ),
    ),
  );
}

/// DM-side control surface for the player screen, shown in the player view
/// window ([showPlayerViewWindow]). Shows the blackout button and a list of
/// projection item thumbnails.
///
/// Mirrors the Python `ui/widgets/player_screen_widget.py` placement.
class ProjectionPanel extends ConsumerWidget {
  const ProjectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(projectionControllerProvider);
    final controller = ref.read(projectionControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top control row — Open/Close player window butonu burada YOK,
        // AppBar'daki cast ikonu o görevi görüyor.
        Container(
          color: palette.tabBg,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: state.blackoutOverride ? L10n.of(context)!.projBlackoutOn : L10n.of(context)!.projBlackout,
                isSelected: state.blackoutOverride,
                selectedIcon: Icon(
                  Icons.visibility_off,
                  size: 18,
                  color: palette.dangerBtnBg,
                ),
                icon: const Icon(Icons.tonality, size: 18),
                onPressed: controller.toggleBlackout,
              ),
              const Spacer(),
              if (state.items.isNotEmpty)
                IconButton(
                  tooltip: L10n.of(context)!.projClearAll,
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  onPressed: controller.clearAll,
                ),
            ],
          ),
        ),

        // Thumbnail grid — wraps onto multiple rows, items at natural height
        Expanded(
          child: state.items.isEmpty
              ? Center(
                  child: Text(
                    L10n.of(context)!.projEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in state.items)
                        ProjectionThumbChip(
                          item: item,
                          isActive: item.id == state.activeItemId,
                          onTap: () => controller.setActive(item.id),
                          onClose: () => controller.removeItem(item.id),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
