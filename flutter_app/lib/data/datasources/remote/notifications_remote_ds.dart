import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/app_notification.dart';
import '../local/guest_notification_store.dart';

/// End-user notifications API (online-only). Mirrors migration 069 RPCs.
/// Without a session (guest, migration 111) the list still comes from the
/// server, but read / dismiss state is kept on the device.
class NotificationsRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;
  final _guest = GuestNotificationStore();

  bool get _isGuest => _client.auth.currentSession == null;

  /// Published notifications + the caller's own answers + read flag.
  Future<List<AppNotification>> list() async {
    final res = await _client.rpc('list_notifications');
    final list = (res as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromRow)
        .toList();
    return _isGuest ? _guest.apply(list) : list;
  }

  /// Upsert the caller's answers for a notification (block-id → answer map).
  Future<void> submit(String notificationId, Map<String, dynamic> answers) async {
    await _client.rpc('submit_notification_response', params: {
      'p_id': notificationId,
      'p_answers': answers,
    });
  }

  Future<void> markRead(String notificationId) async {
    if (_isGuest) return _guest.markRead(notificationId);
    await _client.rpc('mark_notification_read', params: {'p_id': notificationId});
  }

  /// Permanently dismiss all of the caller's read notifications from their inbox.
  Future<void> dismissRead() async {
    if (_isGuest) return _guest.dismissRead();
    await _client.rpc('dismiss_read_notifications');
  }
}
