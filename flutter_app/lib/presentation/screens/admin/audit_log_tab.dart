import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_provider.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/datasources/remote/admin_users_remote_ds.dart';
import '../../theme/dm_tool_colors.dart';

/// Admin audit log — tüm admin aksiyonları (ban/unban, restrict/unrestrict,
/// delete_*) tarih sırasına göre.
class AuditLogTab extends ConsumerWidget {
  const AuditLogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final async = ref.watch(adminAuditLogProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text('No admin actions yet.',
                  style: TextStyle(color: palette.sidebarLabelSecondary)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminAuditLogProvider),
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final e = entries[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.featureCardBg,
                    border: Border.all(color: palette.featureCardBorder),
                    borderRadius: palette.br,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_iconFor(e.action),
                          size: 16, color: _colorFor(e.action, palette)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.adminName ?? "admin"} → ${e.action}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: palette.tabActiveText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _details(e),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(formatRelative(e.createdAt),
                          style: TextStyle(
                              fontSize: 10,
                              color: palette.sidebarLabelSecondary)),
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

  String _details(AdminAuditLogEntry entry) {
    final target = entry.targetUserName ?? entry.targetUserId;
    final ent = entry.targetEntityId;
    final reason = entry.reason;
    final parts = <String>[
      if (target != null && target.isNotEmpty) 'target: $target',
      if (ent != null && ent.isNotEmpty)
        'entity: ${ent.substring(0, ent.length.clamp(0, 8))}',
      if (reason != null && reason.isNotEmpty) 'reason: $reason',
    ];
    return parts.join(' · ');
  }

  IconData _iconFor(String action) {
    if (action.startsWith('delete')) return Icons.delete_outline;
    if (action == 'ban') return Icons.block;
    if (action == 'unban') return Icons.check_circle_outline;
    if (action == 'online_restrict') return Icons.lock_outline;
    if (action == 'online_unrestrict') return Icons.lock_open;
    return Icons.info_outline;
  }

  Color _colorFor(String action, DmToolColors palette) {
    if (action.startsWith('delete') || action == 'ban' ||
        action == 'online_restrict') {
      return palette.dangerBtnBg;
    }
    return palette.sidebarLabelSecondary;
  }
}
