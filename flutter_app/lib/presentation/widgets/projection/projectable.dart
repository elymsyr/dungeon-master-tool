import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/projection_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../domain/entities/projection/projection_item.dart';

const _uuid = Uuid();

/// Helper that opens the "Project to player screen" right-click menu.
/// Centralizes all projection trigger sites — every projectable surface
/// (entity portraits, entity card root, battle map, mind-map nodes, PDF
/// pages) wires its `onSecondaryTapDown` to a single call here.
///
/// Phase 1 only enables image projection from this menu; other item types
/// will be enabled as the corresponding views are implemented.
extension ProjectableContextMenu on BuildContext {
  Future<void> showProjectionMenu({
    required WidgetRef ref,
    required Offset globalPosition,
    required ProjectionItem Function() itemBuilder,
    List<ProjectionItem> Function()? alternatives,
  }) async {
    final overlay = Overlay.of(this).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_ProjectAction>(
      context: this,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: _ProjectAction.addAndShow,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cast),
            title: Text('Project & switch to'),
          ),
        ),
        PopupMenuItem(
          value: _ProjectAction.addOnly,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_to_queue),
            title: Text('Project (new tab)'),
          ),
        ),
        PopupMenuItem(
          value: _ProjectAction.replace,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.swap_horiz),
            title: Text('Replace active'),
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;

    final controller = ref.read(projectionControllerProvider.notifier);
    final item = itemBuilder();
    switch (selected) {
      case _ProjectAction.addAndShow:
        controller.addItem(item, setActive: true);
        _showProjectedSnack(ref);
        break;
      case _ProjectAction.addOnly:
        controller.addItem(item, setActive: false);
        _showProjectedSnack(ref);
        break;
      case _ProjectAction.replace:
        controller.replaceActive(item);
        _showProjectedSnack(ref);
        break;
    }
  }

  void _showProjectedSnack(WidgetRef ref) {
    final messenger = ScaffoldMessenger.maybeOf(this);
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
}

enum _ProjectAction { addAndShow, addOnly, replace }

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
