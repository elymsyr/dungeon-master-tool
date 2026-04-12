import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/marketplace_listing_provider.dart';
import '../../application/services/marketplace_sync_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Reader-side: presents a freshly published snapshot of an item the user
/// previously downloaded. Default action ("Download as new copy") is the
/// safe path — the existing local copy stays untouched, the new snapshot
/// arrives as a separate item. "Replace local copy" overwrites in place
/// after a confirmation step and is destructive.
///
/// Returns true when the user took an action that resolved the prompt
/// (download / replace / dismiss / mute), false on plain cancel.
Future<bool> showMarketplaceUpdatePromptDialog({
  required BuildContext context,
  required MarketplaceUpdatePrompt prompt,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _MarketplaceUpdatePromptDialog(prompt: prompt),
  );
  return result ?? false;
}

class _MarketplaceUpdatePromptDialog extends ConsumerStatefulWidget {
  final MarketplaceUpdatePrompt prompt;
  const _MarketplaceUpdatePromptDialog({required this.prompt});

  @override
  ConsumerState<_MarketplaceUpdatePromptDialog> createState() =>
      _MarketplaceUpdatePromptDialogState();
}

class _MarketplaceUpdatePromptDialogState
    extends ConsumerState<_MarketplaceUpdatePromptDialog> {
  bool _busy = false;

  Future<void> _runAction(Future<void> Function() body) async {
    final l10n = L10n.of(context)!;
    setState(() => _busy = true);
    try {
      await body();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.marketplaceActionFailed('$e'))),
      );
      setState(() => _busy = false);
    }
  }

  Future<void> _downloadAsNewCopy() async {
    final l10n = L10n.of(context)!;
    final notifier = ref.read(marketplaceListingNotifierProvider.notifier);
    return _runAction(() async {
      final newId = await notifier.downloadAsNewCopy(widget.prompt.newListing);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.marketplaceDownloadedAs(newId))),
      );
    });
  }

  Future<void> _replaceLocalCopy() async {
    final l10n = L10n.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.marketplaceReplaceConfirmTitle),
        content: Text(l10n.marketplaceReplaceConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.marketplaceReplaceConfirmAction),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final notifier = ref.read(marketplaceListingNotifierProvider.notifier);
    return _runAction(() async {
      await notifier.replaceLocalCopy(
        itemType: widget.prompt.itemType,
        localId: widget.prompt.localId,
        listing: widget.prompt.newListing,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.marketplaceLocalCopyReplaced)),
      );
    });
  }

  Future<void> _dismiss() async {
    final notifier = ref.read(marketplaceListingNotifierProvider.notifier);
    return _runAction(() async {
      await notifier.dismissListingVersion(
        itemType: widget.prompt.itemType,
        localId: widget.prompt.localId,
        dismissedListingId: widget.prompt.newListing.id,
      );
    });
  }

  Future<void> _mute() async {
    final notifier = ref.read(marketplaceListingNotifierProvider.notifier);
    return _runAction(() async {
      await notifier.setMuted(
        itemType: widget.prompt.itemType,
        localId: widget.prompt.localId,
        muted: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final listing = widget.prompt.newListing;
    final owner = listing.ownerUsername ?? widget.prompt.source.ownerUsername;

    return AlertDialog(
      title: Text(l10n.marketplaceUpdatePromptTitle(listing.title)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_download_outlined,
                      size: 16, color: palette.featureCardAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      owner != null
                          ? l10n.marketplaceUpdatePromptByOwner(owner)
                          : l10n.marketplaceUpdatePromptGeneric,
                      style: TextStyle(
                          fontSize: 13, color: palette.tabActiveText),
                    ),
                  ),
                ],
              ),
              if (listing.changelog != null && listing.changelog!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.marketplaceWhatsNew,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.featureCardBg,
                    border: Border.all(color: palette.featureCardBorder),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    listing.changelog!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _SecondaryAction(
                icon: Icons.notifications_off_outlined,
                label: l10n.marketplaceMuteUpdates,
                onPressed: _busy ? null : _mute,
                palette: palette,
              ),
              _SecondaryAction(
                icon: Icons.visibility_off_outlined,
                label: l10n.marketplaceDismissVersion,
                onPressed: _busy ? null : _dismiss,
                palette: palette,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.btnCancel),
        ),
        TextButton(
          onPressed: _busy ? null : _replaceLocalCopy,
          child: Text(l10n.marketplaceReplaceLocalCopy),
        ),
        FilledButton(
          onPressed: _busy ? null : _downloadAsNewCopy,
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.marketplaceDownloadAsNewCopy),
        ),
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final DmToolColors palette;
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: palette.sidebarLabelSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
