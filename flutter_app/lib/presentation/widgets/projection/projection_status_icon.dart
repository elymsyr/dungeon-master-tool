import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/projection_output_provider.dart';
import '../../../application/providers/projection_provider.dart';
import '../../../domain/entities/projection/projection_output_mode.dart';
import '../../dialogs/screencast_display_picker.dart';
import '../../theme/dm_tool_colors.dart';
import '../../l10n/app_localizations.dart';
import 'projection_panel.dart';

/// AppBar projection button: a menu listing each available output with its
/// on/off state — tapping one toggles it; outputs fan out, so several can be
/// live at once (e.g. second window + online broadcast) — and, under them,
/// the player view window.
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

    // `none` is never an output; here it stands for the player view item.
    return PopupMenuButton<ProjectionOutputMode>(
      tooltip: L10n.of(context)!.projOutputs,
      icon: Icon(Icons.cast, size: 20, color: iconColor),
      onSelected: (mode) => mode == ProjectionOutputMode.none
          ? showPlayerViewWindow(context)
          : _toggle(context, controller, mode, state.outputModes.contains(mode)),
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
        if (available.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem(
          value: ProjectionOutputMode.none,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tv, size: 18),
              const SizedBox(width: 8),
              Text(L10n.of(context)!.sessionPlayerScreen),
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
          SnackBar(
            content: Text(L10n.of(context)!.projScreencastFailed),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    final ok = await controller.activateOutput(mode);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context)!.couldNotOpen(_labelForMode(mode))),
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
