import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../../core/utils/relative_time.dart';
import '../../theme/dm_tool_colors.dart';

/// Online yasaklı kullanıcılar listesi + "Remove restriction" aksiyonu.
class RestrictedUsersTab extends ConsumerWidget {
  const RestrictedUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final async = ref.watch(adminRestrictedUsersProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: palette.sidebarLabelSecondary),
                  const SizedBox(height: 8),
                  Text('No online-restricted users.',
                      style: TextStyle(color: palette.sidebarLabelSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminRestrictedUsersProvider),
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = entries[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.featureCardBg,
                    border: Border.all(color: palette.featureCardBorder),
                    borderRadius: palette.cbr,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            palette.dangerBtnBg.withValues(alpha: 0.15),
                        child: Icon(Icons.lock_outline,
                            color: palette.dangerBtnBg, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.username ?? e.email ?? e.userId,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: palette.tabActiveText)),
                            const SizedBox(height: 2),
                            if (e.email != null)
                              Text(e.email!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: palette.sidebarLabelSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${e.reason ?? "No reason"} · ${formatRelative(e.restrictedAt)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: palette.tabText,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('Unrestrict'),
                        onPressed: () async {
                          try {
                            await ref
                                .read(adminUsersDataSourceProvider)
                                .setOnlineRestriction(
                                  userId: e.userId,
                                  restricted: false,
                                );
                            ref.invalidate(adminRestrictedUsersProvider);
                            ref.invalidate(adminUserListProvider);
                            ref.invalidate(adminAuditLogProvider);
                          } catch (err) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Unrestrict failed: $err')));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
