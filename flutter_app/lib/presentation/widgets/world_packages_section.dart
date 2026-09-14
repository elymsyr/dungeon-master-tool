import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/package_link_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../theme/dm_tool_colors.dart';
import '../l10n/app_localizations.dart';

/// Lists packages installed into a world, with re-sync + remove actions.
/// Lives in the per-world settings dialog.
class WorldPackagesSection extends ConsumerStatefulWidget {
  final String campaignId;
  const WorldPackagesSection({super.key, required this.campaignId});

  @override
  ConsumerState<WorldPackagesSection> createState() =>
      _WorldPackagesSectionState();
}

class _WorldPackagesSectionState extends ConsumerState<WorldPackagesSection> {
  late Future<List<InstalledPackage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<InstalledPackage>> _load() {
    final db = ref.read(appDatabaseProvider);
    return db.installedPackagesDao.getByWorld(widget.campaignId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _resync(InstalledPackage row) async {
    // Re-syncs the package and everything it links, dependencies first.
    final result = await ref.read(worldPackageInstallerProvider).resync(
          worldId: widget.campaignId,
          packageId: row.packageId,
        );
    // Reload campaign so the entity provider picks up the synced rows.
    if (result.added + result.updated + result.removed > 0) {
      await ref.read(activeCampaignProvider.notifier).reload();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          L10n.of(context)!.pkgSynced(row.packageName, '${result.added}', '${result.updated}', '${result.removed}')),
    ));
    await _refresh();
  }

  Future<void> _remove(InstalledPackage row) async {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.removeNamedTitle(row.packageName)),
        content: Text(
          L10n.of(context)!.removePackageFromWorldBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.of(context)!.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.tabActiveText),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(context)!.btnRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Only this package — packages it links stay installed.
    final result =
        await ref.read(worldPackageInstallerProvider).uninstallFromWorld(
              worldId: widget.campaignId,
              packageId: row.packageId,
            );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        L10n.of(context)!.pkgRemovedSummary('${result.removed}', '${result.detachedSurvived}'),
      ),
    ));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return FutureBuilder<List<InstalledPackage>>(
      future: _future,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              L10n.of(context)!.pkgNoneInstalled,
              style: TextStyle(
                  fontSize: 12, color: palette.sidebarLabelSecondary),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2,
                    size: 16, color: palette.sidebarLabelSecondary),
                const SizedBox(width: 6),
                Text(L10n.of(context)!.pkgInstalledTitle,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText)),
              ],
            ),
            const SizedBox(height: 4),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.packageName,
                              style:
                                  const TextStyle(fontSize: 13)),
                          Text(
                              L10n.of(context)!.pkgSyncedAgo(_relative(row.lastSyncedAt)),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync, size: 18),
                      tooltip: L10n.of(context)!.pkgResync,
                      onPressed: () => _resync(row),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: L10n.of(context)!.removeFromWorld,
                      onPressed: () => _remove(row),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}
