import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/projection_provider.dart';
import '../../theme/dm_tool_colors.dart';

/// AppBar player-window toggle button. Always visible regardless of which
/// tab is active. Click → opens or closes the player sub-window directly.
/// Color tracks open state (accent when open, default when closed).
class PlayerWindowStatusIcon extends ConsumerWidget {
  const PlayerWindowStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(projectionControllerProvider);
    final controller = ref.read(projectionControllerProvider.notifier);
    return IconButton(
      tooltip: state.windowOpen
          ? 'Close player window (Ctrl+Shift+P)'
          : 'Open player window (Ctrl+Shift+P)',
      icon: Icon(
        state.windowOpen ? Icons.cast_connected : Icons.cast,
        size: 20,
        color: state.windowOpen ? palette.tokenBorderActive : null,
      ),
      onPressed: () {
        if (state.windowOpen) {
          controller.closeWindow();
        } else {
          controller.openWindow();
        }
      },
    );
  }
}
