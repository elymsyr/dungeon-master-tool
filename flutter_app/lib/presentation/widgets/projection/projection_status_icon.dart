import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/projection_output_provider.dart';
import '../../../application/providers/projection_provider.dart';
import '../../../domain/entities/projection/projection_output_mode.dart';
import '../../dialogs/screencast_display_picker.dart';
import '../../theme/dm_tool_colors.dart';

/// AppBar projection toggle button. Adapts to the current platform:
///
/// - **Mobile** (only screencast available): single tap opens display picker.
/// - **Desktop** (both modes available): tap opens a popup menu to choose
///   between "Second Window" and "Screencast". When active, tap deactivates.
class ProjectionStatusIcon extends ConsumerWidget {
  const ProjectionStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(projectionControllerProvider);
    final available = ref.watch(availableProjectionOutputsProvider);
    final controller = ref.read(projectionControllerProvider.notifier);

    if (state.isActive) {
      // Active — tap to deactivate.
      return IconButton(
        tooltip: _tooltipForMode(state.outputMode, active: true),
        icon: Icon(
          _iconForMode(state.outputMode),
          size: 20,
          color: palette.tokenBorderActive,
        ),
        onPressed: () => controller.deactivateOutput(),
      );
    }

    if (available.length == 1) {
      // Only one option (mobile) — direct tap opens display picker.
      return IconButton(
        tooltip: _tooltipForMode(available.first, active: false),
        icon: const Icon(Icons.cast, size: 20),
        onPressed: () => _activate(context, controller, available.first),
      );
    }

    // Multiple options (desktop) — popup menu.
    return PopupMenuButton<ProjectionOutputMode>(
      tooltip: 'Open projection output',
      icon: const Icon(Icons.cast, size: 20),
      onSelected: (mode) => _activate(context, controller, mode),
      itemBuilder: (_) => [
        for (final mode in available)
          PopupMenuItem(
            value: mode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconForMode(mode), size: 18),
                const SizedBox(width: 8),
                Text(_labelForMode(mode)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _activate(BuildContext context,
      ProjectionController controller, ProjectionOutputMode mode) async {
    if (mode == ProjectionOutputMode.screencast) {
      // Show display picker dialog — user selects target display.
      final display = await ScreencastDisplayPicker.show(context);
      if (display == null) return; // cancelled
      if (!context.mounted) return;
      final ok = await controller.activateOutput(mode, displayId: display.id);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start screen cast on this display.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Second window — activate directly.
      final ok = await controller.activateOutput(mode);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open second window.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  static IconData _iconForMode(ProjectionOutputMode mode) {
    return switch (mode) {
      ProjectionOutputMode.secondWindow => Icons.desktop_windows,
      ProjectionOutputMode.screencast => Icons.cast_connected,
      ProjectionOutputMode.none => Icons.cast,
    };
  }

  static String _labelForMode(ProjectionOutputMode mode) {
    return switch (mode) {
      ProjectionOutputMode.secondWindow => 'Second Window',
      ProjectionOutputMode.screencast => 'Screen Cast',
      ProjectionOutputMode.none => '',
    };
  }

  static String _tooltipForMode(ProjectionOutputMode mode,
      {required bool active}) {
    final label = _labelForMode(mode);
    if (active) return 'Close $label (Ctrl+Shift+P)';
    return 'Open $label (Ctrl+Shift+P)';
  }
}
