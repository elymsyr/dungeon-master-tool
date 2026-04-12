import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/marketplace_listing_provider.dart';
import '../../application/services/marketplace_sync_service.dart';
import '../../core/config/supabase_config.dart';
import '../../domain/entities/marketplace_source.dart';
import '../dialogs/marketplace_update_prompt_dialog.dart';
import '../dialogs/publish_snapshot_dialog.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import 'my_snapshots_panel.dart';

/// Marketplace controls for a single local item:
///
/// - **Owner controls** ("Share to Marketplace" / manage published snapshots)
///   when the user can publish the item.
/// - **Reader badge** ("Imported from @owner") and a **drift banner** when
///   the local copy was downloaded from the marketplace and the publisher
///   has released a newer snapshot.
///
/// Both states are independent and can co-exist (e.g. you imported then
/// republished under a brand-new lineage).
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
  MarketplaceUpdatePrompt? _drift;
  bool _driftChecked = false;
  bool _checkingDrift = false;

  ({String itemType, String localId}) get _key =>
      (itemType: widget.itemType, localId: widget.localId);

  Future<void> _checkDriftIfNeeded(MarketplaceSource? source) async {
    if (source == null || source.muted || source.removed) {
      _driftChecked = true;
      return;
    }
    if (_driftChecked || _checkingDrift) return;
    _checkingDrift = true;
    try {
      final result = await ref
          .read(marketplaceSyncServiceProvider)
          .checkOne(itemType: widget.itemType, localId: widget.localId);
      if (!mounted) return;
      setState(() {
        _drift = result.prompt;
        _driftChecked = true;
        _checkingDrift = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _driftChecked = true;
          _checkingDrift = false;
        });
      }
    }
  }

  Future<void> _publishSnapshot(String? existingLineageId) async {
    final listing = await showPublishSnapshotDialog(
      context: context,
      itemType: widget.itemType,
      localId: widget.localId,
      defaultTitle: widget.title,
      hasExistingLineage: existingLineageId != null,
    );
    if (listing != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.marketplaceSnapshotPublished)),
      );
      ref.invalidate(ownerLineageIdProvider(_key));
    }
  }

  Future<void> _openUpdatePrompt() async {
    if (_drift == null) return;
    final acted = await showMarketplaceUpdatePromptDialog(
      context: context,
      prompt: _drift!,
    );
    if (acted && mounted) {
      setState(() {
        _drift = null;
        _driftChecked = false; // re-check on next build
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) return const SizedBox.shrink();
    if (ref.watch(authProvider) == null) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<DmToolColors>()!;
    final lineageAsync = ref.watch(ownerLineageIdProvider(_key));
    final sourceAsync = ref.watch(marketplaceSourceProvider(_key));

    return lineageAsync.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (e, _) => Text(L10n.of(context)!.marketplaceErrorPrefix('$e'),
          style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
      data: (lineageId) {
        return sourceAsync.when(
          loading: () => const SizedBox(
            height: 36,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (e, _) => Text(L10n.of(context)!.marketplaceErrorPrefix('$e'),
              style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
          data: (source) {
            // Kick off drift check on first build (after both providers
            // resolved). The check is async and only sets state once.
            if (!_driftChecked) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkDriftIfNeeded(source);
              });
            }
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
                    lineageId: lineageId,
                    onPublish: () => _publishSnapshot(lineageId),
                    palette: palette,
                  ),
                  if (lineageId != null) ...[
                    const SizedBox(height: 8),
                    MySnapshotsPanel(lineageId: lineageId),
                  ],
                  if (source != null) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: palette.featureCardBorder),
                    const SizedBox(height: 10),
                    _ReaderSection(
                      source: source,
                      drift: _drift,
                      removed: source.removed,
                      onOpenPrompt: _openUpdatePrompt,
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
  final String? lineageId;
  final VoidCallback onPublish;
  final DmToolColors palette;

  const _OwnerSection({
    required this.lineageId,
    required this.onPublish,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final hasLineage = lineageId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              hasLineage
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined,
              size: 18,
              color: palette.featureCardAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasLineage
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
              hasLineage
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

class _ReaderSection extends StatelessWidget {
  final MarketplaceSource source;
  final MarketplaceUpdatePrompt? drift;
  final bool removed;
  final VoidCallback onOpenPrompt;
  final DmToolColors palette;

  const _ReaderSection({
    required this.source,
    required this.drift,
    required this.removed,
    required this.onOpenPrompt,
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
            Icon(Icons.cloud_download_outlined,
                size: 16, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                source.ownerUsername != null
                    ? l10n.marketplaceImportedFromBy(source.ownerUsername!)
                    : l10n.marketplaceImportedFromGeneric,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
            if (source.muted)
              Tooltip(
                message: l10n.marketplaceUpdatesMutedTooltip,
                child: Icon(Icons.notifications_off_outlined,
                    size: 14, color: palette.sidebarLabelSecondary),
              ),
          ],
        ),
        if (removed) ...[
          const SizedBox(height: 8),
          _Banner(
            icon: Icons.link_off,
            text: l10n.marketplaceItemRemoved,
            palette: palette,
          ),
        ] else if (drift != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: onOpenPrompt,
            child: _Banner(
              icon: Icons.system_update_alt,
              text: l10n.marketplaceUpdateAvailableTap,
              palette: palette,
              accent: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final DmToolColors palette;
  final bool accent;
  const _Banner({
    required this.icon,
    required this.text,
    required this.palette,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? palette.featureCardBg : palette.featureCardBg,
        border: Border.all(
          color: accent ? palette.featureCardAccent : palette.featureCardBorder,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: accent
                  ? palette.featureCardAccent
                  : palette.sidebarLabelSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: palette.tabActiveText),
            ),
          ),
        ],
      ),
    );
  }
}
