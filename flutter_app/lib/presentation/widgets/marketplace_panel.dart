import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/marketplace_listing_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../dialogs/publish_snapshot_dialog.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import 'my_snapshots_panel.dart';

/// Marketplace controls for a single local item:
///
/// - **Owner controls** ("Share to Marketplace" / manage published snapshots)
///   when the user can publish the item.
/// - **Reader badge** ("Imported from @owner") when the local copy was
///   downloaded from the marketplace.
class MarketplacePanel extends ConsumerStatefulWidget {
  final String itemType;
  final String localId;
  final String title;

  const MarketplacePanel({
    super.key,
    required this.itemType,
    required this.localId,
    required this.title,
  });

  @override
  ConsumerState<MarketplacePanel> createState() => _MarketplacePanelState();
}

class _MarketplacePanelState extends ConsumerState<MarketplacePanel> {
  ({String itemType, String localId}) get _key =>
      (itemType: widget.itemType, localId: widget.localId);

  Future<void> _publishSnapshot() async {
    final listing = await showPublishSnapshotDialog(
      context: context,
      itemType: widget.itemType,
      localId: widget.localId,
      defaultTitle: widget.title,
    );
    if (listing != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.marketplaceSnapshotPublished)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) return const SizedBox.shrink();
    if (ref.watch(authProvider) == null) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<DmToolColors>()!;
    final ownedAsync = ref.watch(ownedSnapshotsProvider(_key));
    final sourceAsync = ref.watch(marketplaceSourceProvider(_key));

    return ownedAsync.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (e, _) => Text(isOfflineError(e)
              ? "You're offline — check your internet connection."
              : L10n.of(context)!.marketplaceErrorPrefix('$e'),
          style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
      data: (owned) {
        return sourceAsync.when(
          loading: () => const SizedBox(
            height: 36,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (e, _) => Text(isOfflineError(e)
              ? "You're offline — check your internet connection."
              : L10n.of(context)!.marketplaceErrorPrefix('$e'),
              style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
          data: (source) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.featureCardBg,
                border: Border.all(color: palette.featureCardBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OwnerSection(
                    hasPublished: owned.isNotEmpty,
                    onPublish: _publishSnapshot,
                    palette: palette,
                  ),
                  if (owned.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    MySnapshotsPanel(
                      itemType: widget.itemType,
                      localId: widget.localId,
                    ),
                  ],
                  if (source != null) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: palette.featureCardBorder),
                    const SizedBox(height: 10),
                    _ReaderBadge(
                      ownerUsername: source.ownerUsername,
                      palette: palette,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OwnerSection extends StatelessWidget {
  final bool hasPublished;
  final VoidCallback onPublish;
  final DmToolColors palette;

  const _OwnerSection({
    required this.hasPublished,
    required this.onPublish,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              hasPublished
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined,
              size: 18,
              color: palette.featureCardAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasPublished
                    ? l10n.marketplaceOwnerPublished
                    : l10n.marketplaceOwnerNotShared,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.add, size: 14),
            label: Text(
              hasPublished
                  ? l10n.marketplacePublishSnapshotButton
                  : l10n.marketplaceShareButton,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: palette.featureCardAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderBadge extends StatelessWidget {
  final String? ownerUsername;
  final DmToolColors palette;

  const _ReaderBadge({
    required this.ownerUsername,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return Row(
      children: [
        Icon(Icons.cloud_download_outlined,
            size: 16, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ownerUsername != null
                ? l10n.marketplaceImportedFromBy(ownerUsername!)
                : l10n.marketplaceImportedFromGeneric,
            style: TextStyle(
              fontSize: 12,
              color: palette.sidebarLabelSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
