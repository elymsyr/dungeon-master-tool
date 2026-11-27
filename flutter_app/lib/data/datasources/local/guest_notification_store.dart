import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/app_notification.dart';

/// A guest has no `auth.uid()`, so the server can't hold their read /
/// dismissed state (migration 111). It lives on the device instead.
///
/// shortcut: ids are never pruned and do not carry over on sign-in; prune
/// against the fetched list if the sets ever get large.
class GuestNotificationStore {
  static const readKey = 'guest_notif_read';
  static const dismissedKey = 'guest_notif_dismissed';

  /// Drops dismissed notifications and sets `read` from the local set.
  Future<List<AppNotification>> apply(List<AppNotification> list) async {
    final prefs = await SharedPreferences.getInstance();
    final read = (prefs.getStringList(readKey) ?? const []).toSet();
    final dismissed = (prefs.getStringList(dismissedKey) ?? const []).toSet();
    return [
      for (final n in list)
        if (!dismissed.contains(n.id))
          AppNotification(
            id: n.id,
            title: n.title,
            blocks: n.blocks,
            createdAt: n.createdAt,
            myAnswers: n.myAnswers,
            read: read.contains(n.id),
          ),
    ];
  }

  Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final read = (prefs.getStringList(readKey) ?? const []).toSet()..add(id);
    await prefs.setStringList(readKey, read.toList());
  }

  /// Every read notification becomes dismissed.
  Future<void> dismissRead() async {
    final prefs = await SharedPreferences.getInstance();
    final read = prefs.getStringList(readKey) ?? const [];
    final dismissed =
        (prefs.getStringList(dismissedKey) ?? const []).toSet()..addAll(read);
    await prefs.setStringList(dismissedKey, dismissed.toList());
    await prefs.remove(readKey);
  }
}
