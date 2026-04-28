import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/services/package_import_service.dart';
import '../../application/services/package_sync_service.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../theme/dm_tool_colors.dart';

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
    return db.installedPackageDao.listForCampaign(widget.campaignId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _resync(InstalledPackage row) async {
    final db = ref.read(appDatabaseProvider);
    // Build Tier-0 (slug,name) → uuid index from this campaign's seeded
    // entities so pack-side `_lookup` placeholders resolve correctly.
    final build = generateBuiltinDnd5eV2Schema();
    final tier0Slugs = build.seedRows.keys.toSet();
    final tier0Rows = await (db.select(db.entities)
          ..where((t) =>
              t.campaignId.equals(widget.campaignId) &
              t.categorySlug.isIn(tier0Slugs)))
        .get();
    final tier0Index = <String, Map<String, String>>{};
    for (final r in tier0Rows) {
      tier0Index
          .putIfAbsent(r.categorySlug, () => <String, String>{})[r.name] = r.id;
    }
    final result = await PackageSyncService(db).sync(
      campaignId: widget.campaignId,
      packageId: row.packageId,
      resolveAttrs: (attrs) =>
          PackageImportService.resolveLookupPlaceholder(attrs, tier0Index)
              as Map<String, dynamic>,
    );
    // Reload campaign so the entity provider picks up the synced rows.
    if (result.total > 0) {
      await ref.read(activeCampaignProvider.notifier).reload();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Synced "${row.packageName}": +${result.added}, ~${result.updated}, -${result.removed}.'),
    ));
    await _refresh();
  }

  Future<void> _remove(InstalledPackage row) async {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${row.packageName}"?'),
        content: const Text(
          'Linked entities from this package will be deleted. '
          'User-edited copies are kept as homebrew.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.tabActiveText),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(appDatabaseProvider);
    final result = await PackageSyncService(db).uninstall(
      campaignId: widget.campaignId,
      packageId: row.packageId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Removed ${result.removed} entities; ${result.detachedSurvived} kept as homebrew.',
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
              'No packages installed.',
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
                Text('Installed Packages',
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
                              'Synced ${_relative(row.lastSyncedAt)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync, size: 18),
                      tooltip: 'Re-sync from package',
                      onPressed: () => _resync(row),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Remove from world',
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
