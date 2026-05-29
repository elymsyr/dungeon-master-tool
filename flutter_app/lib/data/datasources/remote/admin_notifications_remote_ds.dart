import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/app_notification.dart';

/// Admin-side summary row for the notifications list (title + date + count).
class AdminNotificationSummary {
  final String id;
  final String title;
  final List<NotificationBlock> blocks;
  final DateTime createdAt;
  final int responseCount;

  const AdminNotificationSummary({
    required this.id,
    required this.title,
    required this.blocks,
    required this.createdAt,
    required this.responseCount,
  });

  factory AdminNotificationSummary.fromRow(Map<String, dynamic> row) {
    return AdminNotificationSummary(
      id: row['id'].toString(),
      title: (row['title'] ?? '').toString(),
      blocks: AppNotification.parseBlocks(row['blocks']),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      responseCount: (row['response_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One user's response to a notification, for the admin responses view.
class NotificationResponseRow {
  final String userId;
  final String? username;

  /// block-id → answer map (`{"choice":[0]}` or `{"text":"..."}`).
  final Map<String, dynamic> answers;
  final DateTime submittedAt;

  const NotificationResponseRow({
    required this.userId,
    required this.username,
    required this.answers,
    required this.submittedAt,
  });

  factory NotificationResponseRow.fromRow(Map<String, dynamic> row) {
    final raw = row['answers'];
    return NotificationResponseRow(
      userId: row['user_id'].toString(),
      username: row['username']?.toString(),
      answers: raw is Map ? raw.cast<String, dynamic>() : const {},
      submittedAt:
          DateTime.tryParse(row['submitted_at']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Admin broadcast notifications API. Mirrors migration 069 admin RPCs.
class AdminNotificationsRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AdminNotificationSummary>> list() async {
    final res = await _client.rpc('admin_list_notifications');
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(AdminNotificationSummary.fromRow)
        .toList();
  }

  /// Create + publish a notification. [blocks] is the serialized block array.
  Future<String> create(String title, List<Map<String, dynamic>> blocks) async {
    final res = await _client.rpc('admin_create_notification', params: {
      'p_title': title,
      'p_blocks': blocks,
    });
    return res.toString();
  }

  Future<void> delete(String id) async {
    await _client.rpc('admin_delete_notification', params: {'p_id': id});
  }

  Future<List<NotificationResponseRow>> responses(String id) async {
    final res = await _client.rpc('admin_notification_responses', params: {'p_id': id});
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(NotificationResponseRow.fromRow)
        .toList();
  }
}
