import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/role_provider.dart';
import '../theme/dm_tool_colors.dart';
import 'world_characters_view.dart';

/// "+" entry point shared by the DM character sidebar and the player tab.
/// Two actions: Create new character (always available with an active world)
/// and Import existing — opens [ImportOrphanDialog] against the active world.
///
/// 039 model: import sadece orphan (worldless + self-owned) karakterleri
/// aktif dünyaya bağlar. Cross-world re-link özelliği yok; bir karakter aynı
/// anda en fazla bir dünyaya bağlıdır.
class CharacterAddButton extends ConsumerWidget {
  final DmToolColors palette;
  final bool dense;

  /// When the host already shows the active world (sidebar / player tab),
  /// the create option is gated on a world being open. Pass null to
  /// disable; pass the active world name to enable.
  final String? activeWorld;

  const CharacterAddButton({
    super.key,
    required this.palette,
    required this.activeWorld,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasWorld = activeWorld != null && activeWorld!.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Add character',
      enabled: hasWorld,
      icon: dense
          ? Icon(Icons.add, color: palette.tabActiveText)
          : null,
      iconSize: dense ? 18 : 24,
      padding: dense ? EdgeInsets.zero : const EdgeInsets.all(8),
      child: dense
          ? null
          : Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: hasWorld
                    ? palette.featureCardAccent
                    : palette.featureCardAccent.withValues(alpha: 0.4),
                borderRadius: palette.br,
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Add',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
      onSelected: (v) async {
        switch (v) {
          case 'create':
            context.push('/character/new');
          case 'import':
            final worldId =
                ref.read(activeCampaignIdProvider).valueOrNull;
            if (worldId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Open a world first to import.')),
              );
              return;
            }
            await showDialog<void>(
              context: context,
              builder: (_) => ImportOrphanDialog(
                worldId: worldId,
                palette: palette,
              ),
            );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'create',
          child: Row(children: [
            Icon(Icons.add_circle_outline, size: 16),
            SizedBox(width: 8),
            Text('Create new character'),
          ]),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(children: [
            Icon(Icons.input, size: 16),
            SizedBox(width: 8),
            Text('Import existing character...'),
          ]),
        ),
      ],
    );
  }
}
