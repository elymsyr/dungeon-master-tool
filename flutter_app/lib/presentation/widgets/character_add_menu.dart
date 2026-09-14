import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/role_provider.dart';
import '../theme/dm_tool_colors.dart';
import 'world_characters_view.dart';
import '../l10n/app_localizations.dart';

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
      tooltip: L10n.of(context)!.charAddTooltip,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(L10n.of(context)!.btnAdd,
                      style: const TextStyle(
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
            // activeCampaignIdProvider is async (name → UUID lookup via
            // campaignInfoListProvider). On a fresh world open, `.valueOrNull`
            // can return null while the future is still resolving — await it
            // so the "Open a world first" snackbar only fires when there's
            // genuinely no active world.
            final worldId =
                await ref.read(activeCampaignIdProvider.future);
            if (!context.mounted) return;
            if (worldId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(L10n.of(context)!.charImportNeedsWorld)),
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
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'create',
          child: Row(children: [
            const Icon(Icons.add_circle_outline, size: 16),
            const SizedBox(width: 8),
            Text(L10n.of(context)!.charCreateNew),
          ]),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(children: [
            const Icon(Icons.input, size: 16),
            const SizedBox(width: 8),
            Text(L10n.of(context)!.charImportExisting),
          ]),
        ),
      ],
    );
  }
}
