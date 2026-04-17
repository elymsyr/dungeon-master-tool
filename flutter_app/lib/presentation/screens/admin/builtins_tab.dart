import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../../core/utils/format_bytes.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/datasources/remote/admin_users_remote_ds.dart';
import '../../theme/dm_tool_colors.dart';

/// Yalnız built-in işaretli marketplace listing'leri gösterir.
/// Admin istediği listing'in işaretini kaldırabilir (sonra sahibi silebilir).
class BuiltinsTab extends ConsumerStatefulWidget {
  const BuiltinsTab({super.key});

  @override
  ConsumerState<BuiltinsTab> createState() => _BuiltinsTabState();
}

class _BuiltinsTabState extends ConsumerState<BuiltinsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminMarketplaceFilterProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final async = ref.watch(adminAllMarketplaceListingsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          final builtins = rows.where((r) => r.isBuiltin).toList();
          if (builtins.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border,
                      size: 48, color: palette.sidebarLabelSecondary),
                  const SizedBox(height: 8),
                  Text('No built-in items yet.',
                      style: TextStyle(color: palette.sidebarLabelSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    'Go to the Content tab and star a marketplace listing.',
                    style: TextStyle(
                        fontSize: 11,
                        color: palette.sidebarLabelSecondary,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminAllMarketplaceListingsProvider),
            child: ListView.separated(
              itemCount: builtins.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _BuiltinCard(row: builtins[i]),
            ),
          );
        },
      ),
    );
  }
}

class _BuiltinCard extends ConsumerWidget {
  const _BuiltinCard({required this.row});
  final AdminMarketplaceListingRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardAccent.withValues(alpha: 0.6)),
        borderRadius: palette.cbr,
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: 20, color: palette.featureCardAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText)),
                const SizedBox(height: 2),
                Text(
                  '${row.itemType} · ${row.ownerName} · ${formatBytes(row.sizeBytes)} · ${formatRelative(row.createdAt)}',
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.star_border, size: 16),
            label: const Text('Unmark'),
            onPressed: () => _unmark(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _unmark(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(adminUsersDataSourceProvider)
          .setListingBuiltin(row.id, false);
      ref.invalidate(adminAllMarketplaceListingsProvider);
      ref.invalidate(adminAuditLogProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Unmark failed: $e')));
      }
    }
  }
}
