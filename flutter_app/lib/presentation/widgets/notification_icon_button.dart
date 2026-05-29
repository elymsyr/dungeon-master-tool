import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/notifications_provider.dart';
import '../dialogs/notification_inbox_dialog.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Bell icon in the Hub AppBar. Shows an unread-count badge and opens the
/// notifications inbox. Keeps the realtime subscription alive while mounted so
/// new broadcasts update the badge live.
class NotificationIconButton extends ConsumerWidget {
  const NotificationIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // Keep the live subscription open; refreshes notificationsProvider on CDC.
    ref.watch(notificationsRealtimeProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return IconButton(
      tooltip: l10n.notificationsButtonTooltip,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: palette.dangerBtnBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: palette.dangerBtnText,
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: () => NotificationInboxDialog.show(context),
    );
  }
}
