import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/marketplace_listing_provider.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Owner-side: list of every snapshot in a single lineage. The current
/// (live) snapshot is highlighted; everything else is a historical row
/// the owner can delete. There is no "edit" — snapshots are immutable.
class MySnapshotsPanel extends ConsumerWidget {
  final String lineageId;
  const MySnapshotsPanel({super.key, required this.lineageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final historyAsync = ref.watch(lineageHistoryProvider(lineageId));

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text(
          isOfflineError(e)
              ? "You're offline — snapshots unavailable."
              : l10n.mySnapshotsLoadError('$e'),
          style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
      data: (snapshots) {
        if (snapshots.isEmpty) {
          return Text(
            l10n.mySnapshotsEmpty,
            style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                l10n.mySnapshotsHeading(snapshots.length),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
            for (var i = 0; i < snapshots.length; i++)
              _SnapshotRow(
                listing: snapshots[i],
                versionIndex: snapshots.length - i,
                palette: palette,
              ),
          ],
        );
      },
    );
  }
}

class _SnapshotRow extends ConsumerStatefulWidget {
  final MarketplaceListing listing;
  final int versionIndex;
  final DmToolColors palette;
  const _SnapshotRow({
    required this.listing,
    required this.versionIndex,
    required this.palette,
  });

  @override
  ConsumerState<_SnapshotRow> createState() => _SnapshotRowState();
}

class _SnapshotRowState extends ConsumerState<_SnapshotRow> {
  bool _busy = false;

  Future<void> _delete() async {
    final l10n = L10n.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mySnapshotsDeleteTitle),
        content: Text(
          widget.listing.isCurrent
              ? l10n.mySnapshotsDeleteCurrentBody
              : l10n.mySnapshotsDeleteHistoricalBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: widget.palette.dangerBtnBg,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.btnDelete),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceListingNotifierProvider.notifier)
          .deleteListing(widget.listing);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mySnapshotsDeleted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mySnapshotsDeleteFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final l = widget.listing;
    final palette = widget.palette;
    final created = '${l.createdAt.toLocal().year}-'
        '${l.createdAt.toLocal().month.toString().padLeft(2, '0')}-'
        '${l.createdAt.toLocal().day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: l.isCurrent
            ? palette.featureCardAccent.withValues(alpha: 0.08)
            : null,
        border: Border.all(
          color: l.isCurrent
              ? palette.featureCardAccent
              : palette.featureCardBorder,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: l.isCurrent
                  ? palette.featureCardAccent
                  : palette.sidebarLabelSecondary,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'v${widget.versionIndex}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l.changelog?.isNotEmpty == true
                      ? l.changelog!
                      : '$created · ${l10n.mySnapshotsDownloadCount(l.downloadCount)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: palette.sidebarLabelSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (l.isCurrent)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                l10n.mySnapshotsCurrentBadge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.featureCardAccent,
                ),
              ),
            ),
          IconButton(
            onPressed: _busy ? null : _delete,
            tooltip: l10n.mySnapshotsDeleteTooltip,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.delete_outline,
                    size: 16, color: palette.dangerBtnBg),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
        ],
      ),
    );
  }
}
