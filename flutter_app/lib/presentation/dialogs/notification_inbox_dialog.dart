import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/notifications_provider.dart';
import '../../core/utils/relative_time.dart';
import '../../domain/entities/app_notification.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/notification_block_view.dart';

/// User-facing notifications inbox. Lists published notifications by title only;
/// tapping a row opens it in a detail dialog (full blocks + poll/input). Header
/// buttons mark all read / remove (dismiss) already-read notifications.
class NotificationInboxDialog extends ConsumerStatefulWidget {
  const NotificationInboxDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const NotificationInboxDialog(),
    );
  }

  @override
  ConsumerState<NotificationInboxDialog> createState() =>
      _NotificationInboxDialogState();
}

class _NotificationInboxDialogState
    extends ConsumerState<NotificationInboxDialog> {
  Future<void> _markAllRead() async {
    final list = ref.read(notificationsProvider).valueOrNull;
    if (list == null) return;
    final unread = list.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final ds = ref.read(notificationsDataSourceProvider);
    for (final n in unread) {
      try {
        await ds.markRead(n.id);
      } catch (_) {/* best-effort */}
    }
    if (mounted) ref.invalidate(notificationsProvider);
  }

  Future<void> _removeRead() async {
    final l10n = L10n.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.notifRemoveReadConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.notifRemoveRead),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ds = ref.read(notificationsDataSourceProvider);
    try {
      await ds.dismissRead();
    } catch (_) {/* best-effort */}
    if (mounted) ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final async = ref.watch(notificationsProvider);
    final list = async.valueOrNull ?? const <AppNotification>[];
    final hasUnread = list.any((n) => !n.read);
    final hasRead = list.any((n) => n.read);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_none, color: palette.featureCardAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.notificationsDialogTitle,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: palette.tabActiveText)),
                  ),
                  IconButton(
                    tooltip: l10n.notifMarkAllRead,
                    icon: const Icon(Icons.done_all, size: 20),
                    onPressed: hasUnread ? _markAllRead : null,
                  ),
                  IconButton(
                    tooltip: l10n.notifRemoveRead,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    onPressed: hasRead ? _removeRead : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $e',
                        style: TextStyle(color: palette.dangerBtnBg)),
                  ),
                  data: (list) => list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.notificationsEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.sidebarLabelSecondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          shrinkWrap: true,
                          itemCount: list.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _NotificationRow(list[i]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inbox row: unread dot + title + relative time. Tapping opens the
/// detail dialog and marks the notification read.
class _NotificationRow extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationRow(this.notification);

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!notification.read) {
      final ds = ref.read(notificationsDataSourceProvider);
      try {
        await ds.markRead(notification.id);
      } catch (_) {/* best-effort */}
      ref.invalidate(notificationsProvider);
    }
    if (context.mounted) {
      await _NotificationDetailDialog.show(context, notification);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final unread = !notification.read;

    return Material(
      color: palette.featureCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: palette.cbr,
        side: BorderSide(color: palette.featureCardBorder),
      ),
      child: InkWell(
        borderRadius: palette.cbr,
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unread
                      ? palette.featureCardAccent
                      : Colors.transparent,
                ),
              ),
              Expanded(
                child: Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(formatRelative(notification.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: palette.sidebarLabelSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full notification view: title + ordered blocks (markdown / poll / input).
class _NotificationDetailDialog extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationDetailDialog(this.notification);

  static Future<void> show(BuildContext context, AppNotification n) {
    return showDialog<void>(
      context: context,
      builder: (_) => _NotificationDetailDialog(n),
    );
  }

  Future<void> _submitBlock(
    BuildContext context,
    WidgetRef ref,
    String blockId,
    Map<String, dynamic> value,
  ) async {
    final ds = ref.read(notificationsDataSourceProvider);
    // Read the freshest answers from the provider, not the captured copy, so
    // accumulated submissions from other blocks are preserved.
    final live = ref.read(notificationsProvider).valueOrNull?.firstWhere(
          (n) => n.id == notification.id,
          orElse: () => notification,
        );
    final answers =
        Map<String, dynamic>.from(live?.myAnswers ?? notification.myAnswers ?? const {});
    answers[blockId] = value;
    try {
      await ds.submit(notification.id, answers);
      ref.invalidate(notificationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.notifSubmitted)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<int> _pollInitial(AppNotification n, String blockId) {
    final raw = n.myAnswers?[blockId];
    final choice = (raw is Map ? raw['choice'] : null);
    if (choice is List) {
      return choice.whereType<num>().map((e) => e.toInt()).toList();
    }
    return const [];
  }

  String _inputInitial(AppNotification n, String blockId) {
    final raw = n.myAnswers?[blockId];
    final text = (raw is Map ? raw['text'] : null);
    return text?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // Watch the live notification so myAnswers reflects prior submissions;
    // the constructor copy is captured once and would otherwise stay stale,
    // causing each block submit to overwrite earlier answers.
    final notification = ref.watch(notificationsProvider).valueOrNull?.firstWhere(
              (n) => n.id == this.notification.id,
              orElse: () => this.notification,
            ) ??
        this.notification;

    final blockWidgets = <Widget>[];
    for (final b in notification.blocks) {
      switch (b) {
        case MarkdownBlock():
          blockWidgets.add(MarkdownBlockView(block: b));
        case PollBlock():
          blockWidgets.add(PollBlockView(
            block: b,
            initial: _pollInitial(notification, b.id),
            onSubmit: (choice) =>
                _submitBlock(context, ref, b.id, {'choice': choice}),
          ));
        case InputBlock():
          blockWidgets.add(InputBlockView(
            block: b,
            initial: _inputInitial(notification, b.id),
            onSubmit: (text) =>
                _submitBlock(context, ref, b.id, {'text': text}),
          ));
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(notification.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: palette.tabActiveText)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0, bottom: 4),
                child: Text(formatRelative(notification.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: palette.sidebarLabelSecondary)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final w in blockWidgets) ...[
                        w,
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
