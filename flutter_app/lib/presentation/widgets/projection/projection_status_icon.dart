import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/projection_output_provider.dart';
import '../../../application/providers/projection_provider.dart';
import '../../../domain/entities/projection/projection_output_mode.dart';
import '../../dialogs/screencast_display_picker.dart';
import '../../theme/dm_tool_colors.dart';

/// AppBar projection toggle button. Adapts to the current platform + role:
///
/// - **Single available mode** (mobile, no online): direct tap toggles it.
/// - **Multiple modes**: popup menu lists each available output with its
///   current on/off state. Tapping an item toggles that specific mode —
///   outputs fan out, so several can be live simultaneously (e.g. second
///   window + online broadcast).
class ProjectionStatusIcon extends ConsumerWidget {
  const ProjectionStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(projectionControllerProvider);
    final available = ref.watch(availableProjectionOutputsProvider);
    final controller = ref.read(projectionControllerProvider.notifier);

    final anyActive = state.outputModes.isNotEmpty;
    final iconColor = anyActive ? palette.tokenBorderActive : null;

    if (available.length <= 1) {
      // Single-mode platforms: direct tap toggles.
      final mode = available.isEmpty
          ? ProjectionOutputMode.screencast
          : available.first;
      final active = state.outputModes.contains(mode);
      return IconButton(
        tooltip: active
            ? 'Close ${_labelForMode(mode)} (Ctrl+Shift+P)'
            : 'Open ${_labelForMode(mode)} (Ctrl+Shift+P)',
        icon: Icon(_iconForMode(mode), size: 20, color: iconColor),
        onPressed: () => _toggle(context, controller, mode, active),
      );
    }

    return PopupMenuButton<ProjectionOutputMode>(
      tooltip: 'Projection outputs',
      icon: Icon(Icons.cast, size: 20, color: iconColor),
      onSelected: (mode) =>
          _toggle(context, controller, mode, state.outputModes.contains(mode)),
      itemBuilder: (_) => [
        for (final mode in available)
          PopupMenuItem(
            value: mode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconForMode(mode),
                  size: 18,
                  color: state.outputModes.contains(mode)
                      ? palette.tokenBorderActive
                      : null,
                ),
                const SizedBox(width: 8),
                Text(_labelForMode(mode)),
                const SizedBox(width: 10),
                if (state.outputModes.contains(mode))
                  Icon(Icons.check, size: 16, color: palette.tokenBorderActive),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    ProjectionController controller,
    ProjectionOutputMode mode,
    bool active,
  ) async {
    if (active) {
      await controller.deactivateOutput(mode);
      return;
    }
    await _activate(context, controller, mode);
  }

  Future<void> _activate(BuildContext context,
      ProjectionController controller, ProjectionOutputMode mode) async {
    if (mode == ProjectionOutputMode.screencast) {
      final display = await ScreencastDisplayPicker.show(context);
      if (display == null) return;
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
      return;
    }
    final ok = await controller.activateOutput(mode);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${_labelForMode(mode)}.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static IconData _iconForMode(ProjectionOutputMode mode) {
    return switch (mode) {
      ProjectionOutputMode.secondWindow => Icons.desktop_windows,
      ProjectionOutputMode.screencast => Icons.cast_connected,
      ProjectionOutputMode.online => Icons.groups,
      ProjectionOutputMode.none => Icons.cast,
    };
  }

  static String _labelForMode(ProjectionOutputMode mode) {
    return switch (mode) {
      ProjectionOutputMode.secondWindow => 'Second Window',
      ProjectionOutputMode.screencast => 'Screen Cast',
      ProjectionOutputMode.online => 'Broadcast to Online Players',
      ProjectionOutputMode.none => '',
    };
  }
}
