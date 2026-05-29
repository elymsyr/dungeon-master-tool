import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/admin_notifications_provider.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/datasources/remote/admin_notifications_remote_ds.dart';
import '../../dialogs/notification_composer_dialog.dart';
import '../../dialogs/notification_responses_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

/// Admin tab: list broadcast notifications, compose new ones, view responses.
class NotificationsAdminTab extends ConsumerWidget {
  const NotificationsAdminTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final async = ref.watch(adminNotificationsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminNotificationsProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.notifAdminTab,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText)),
              ),
              FilledButton.icon(
                onPressed: () => NotificationComposerDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.notifNewButton),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e',
                style: TextStyle(color: palette.dangerBtnBg)),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.notificationsEmpty,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: palette.sidebarLabelSecondary)),
                  )
                : Column(
                    children: [
                      for (final n in items) ...[
                        _NotificationRow(summary: n),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  final AdminNotificationSummary summary;
  const _NotificationRow({required this.summary});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.notifDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btnClose),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.notifDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminNotificationsDataSourceProvider).delete(summary.id);
      ref.invalidate(adminNotificationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText)),
                const SizedBox(height: 2),
                Text(
                  '${formatRelative(summary.createdAt)} · ${l10n.notifResponseCount(summary.responseCount)}',
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.notifViewResponses,
            icon: const Icon(Icons.insights_outlined, size: 20),
            onPressed: () =>
                NotificationResponsesDialog.show(context, summary),
          ),
          IconButton(
            tooltip: l10n.notifDelete,
            icon: Icon(Icons.delete_outline, size: 20, color: palette.dangerBtnBg),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}
