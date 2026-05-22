import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/online_worlds_provider.dart';
import '../../../application/providers/projection_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../domain/entities/online/world_role.dart';
import '../../../domain/entities/projection/projection_output_mode.dart';
import '../../theme/dm_tool_colors.dart';
import 'projection_thumb_chip.dart';

/// DM-side control surface for the player screen — lives inside the
/// Session tab's "Player Screen" bottom tab. Shows the open/close window
/// toggle, the blackout button, and a horizontal scrolling list of
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

    // DM-only online broadcast toggle — visible only when the active world is
    // online and the current user is its DM. Fan-out lets it run alongside
    // the offline second window.
    final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
    final isOnlineWorld =
        worldId != null && ref.watch(onlineWorldIdsProvider).contains(worldId);
    final isDm =
        ref.watch(currentWorldRoleProvider).valueOrNull == WorldRole.dm;
    final showOnlineToggle = isOnlineWorld && isDm;
    final onlineActive =
        state.outputModes.contains(ProjectionOutputMode.online);

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
                tooltip: state.blackoutOverride ? 'Blackout ON' : 'Blackout',
                isSelected: state.blackoutOverride,
                selectedIcon: Icon(
                  Icons.visibility_off,
                  size: 18,
                  color: palette.dangerBtnBg,
                ),
                icon: const Icon(Icons.tonality, size: 18),
                onPressed: controller.toggleBlackout,
              ),
              if (showOnlineToggle)
                IconButton(
                  tooltip: onlineActive
                      ? 'Broadcasting to online players (tap to stop)'
                      : 'Broadcast to online players',
                  isSelected: onlineActive,
                  selectedIcon: Icon(
                    Icons.groups,
                    size: 18,
                    color: palette.tokenBorderActive,
                  ),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  onPressed: () => onlineActive
                      ? controller
                          .deactivateOutput(ProjectionOutputMode.online)
                      : controller
                          .activateOutput(ProjectionOutputMode.online),
                ),
              const Spacer(),
              if (state.items.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all projections',
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
                    'No projections yet.\nRight-click an image and choose "Project" to send it to the player screen.',
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
