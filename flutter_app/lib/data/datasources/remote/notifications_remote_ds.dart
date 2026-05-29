import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/app_notification.dart';

/// End-user notifications API (online-only). Mirrors migration 069 RPCs.
class NotificationsRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  /// Published notifications + the caller's own answers + read flag.
  Future<List<AppNotification>> list() async {
    final res = await _client.rpc('list_notifications');
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromRow)
        .toList();
  }

  /// Upsert the caller's answers for a notification (block-id → answer map).
  Future<void> submit(String notificationId, Map<String, dynamic> answers) async {
    await _client.rpc('submit_notification_response', params: {
      'p_id': notificationId,
      'p_answers': answers,
    });
  }

  Future<void> markRead(String notificationId) async {
    await _client.rpc('mark_notification_read', params: {'p_id': notificationId});
  }

  /// Permanently dismiss all of the caller's read notifications from their inbox.
  Future<void> dismissRead() async {
    await _client.rpc('dismiss_read_notifications');
  }
}
