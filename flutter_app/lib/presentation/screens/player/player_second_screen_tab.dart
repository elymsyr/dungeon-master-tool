import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/online_projection_provider.dart';
import '../player_window/player_window_root.dart';
import '../../theme/dm_tool_colors.dart';

/// Player's "Second Screen" tab — renders whatever the DM is currently
/// projecting to online players.
///
/// `onlineProjectionProvider` is fed by `WorldMirrorApplier` from the
/// `world_projection` CDC channel: `null` when the DM is not projecting,
/// a [ProjectionState] otherwise. When projecting, the manifest is rendered
/// by [PlayerWindowRoot] — the exact widget tree used by the local
/// second-window — fed by [onlineProjectionStateProvider].
class PlayerSecondScreenTab extends ConsumerWidget {
  const PlayerSecondScreenTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref.watch(onlineProjectionProvider);
    if (projection == null) {
      return const _WaitingPlaceholder();
    }
    return PlayerWindowRoot(stateProvider: onlineProjectionStateProvider);
  }
}

class _WaitingPlaceholder extends StatelessWidget {
  const _WaitingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      color: palette.tabBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cast,
                  size: 56, color: palette.sidebarLabelSecondary),
              const SizedBox(height: 12),
              Text(
                'Waiting for DM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your DM has not started a live session yet. When they do,'
                ' anything they project to the player screen will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
