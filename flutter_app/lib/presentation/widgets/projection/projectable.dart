import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/ui_state_provider.dart';
import '../../../domain/entities/projection/projection_item.dart';

const _uuid = Uuid();

/// Shows the "Projected to player screen" confirmation snackbar with a
/// "View" action that jumps to the Player Screen panel. Shared by every
/// projection trigger site (entity card menu, world map, mind-map nodes).
void showProjectedSnack(BuildContext context, WidgetRef ref) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        width: 320,
        content: const Text('Projected to player screen'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Trigger main_screen to switch to Session tab + focus the
            // projection (Player Screen) bottom tab.
            ref.read(projectionPanelNavigationProvider.notifier).state = true;
          },
        ),
      ),
    );
}

/// Convenience helpers for the most common item construction. Generates a
/// fresh uuid each time so multiple "Project" actions on the same source
/// produce distinct tabs.
class ProjectionItemBuilders {
  static ImageProjection image({
    required String label,
    required List<String> filePaths,
  }) {
    return ImageProjection(
      id: _uuid.v4(),
      label: label,
      filePaths: filePaths,
    );
  }
}
