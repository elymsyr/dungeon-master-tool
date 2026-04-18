import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_provider.dart';
import '../../application/providers/auth_provider.dart';
import '../../application/providers/marketplace_listing_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/marketplace_listing.dart';
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

  Future<MarketplaceListing?> _openPublishDialog({required bool asBuiltin}) {
    return showPublishSnapshotDialog(
      context: context,
      itemType: widget.itemType,
      localId: widget.localId,
      defaultTitle: widget.title,
      publishAsBuiltin: asBuiltin,
    );
  }

  Future<void> _publishSnapshot() async {
    final listing = await _openPublishDialog(asBuiltin: false);
    if (listing != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.marketplaceSnapshotPublished)),
      );
    }
  }

  Future<void> _publishAsBuiltin() async {
    final l10n = L10n.of(context)!;
    final listing = await _openPublishDialog(asBuiltin: true);
    if (listing == null || !mounted) return;
    try {
      await ref
          .read(adminUsersDataSourceProvider)
          .setListingBuiltin(listing.id, true);
      ref.invalidate(adminAllMarketplaceListingsProvider);
      ref.invalidate(ownedSnapshotsProvider(_key));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publishAsBuiltinSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publishAsBuiltinFlagFailed)),
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
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

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
                    onPublishAsBuiltin:
                        isAdmin ? _publishAsBuiltin : null,
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
  final VoidCallback? onPublishAsBuiltin;
  final DmToolColors palette;

  const _OwnerSection({
    required this.hasPublished,
    required this.onPublish,
    required this.onPublishAsBuiltin,
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
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              if (onPublishAsBuiltin != null)
                FilledButton.icon(
                  onPressed: onPublishAsBuiltin,
                  icon: const Icon(Icons.star, size: 14),
                  label: Text(
                    l10n.publishAsBuiltinButton,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC8A24B),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              FilledButton.icon(
                onPressed: onPublish,
                icon: const Icon(Icons.add, size: 14),
                label: Text(
                  hasPublished
                      ? l10n.marketplacePublishSnapshotButton
                      : l10n.marketplaceShareButton,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.featureCardAccent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
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
