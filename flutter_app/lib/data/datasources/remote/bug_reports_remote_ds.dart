import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parse_utils.dart';

class BugReport {
  final String id;
  final String userId;
  final String? email;
  final String? username;
  final String message;
  final String? logs;
  final String? appVersion;
  final String? platform;
  final String status; // open / read / resolved
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BugReport({
    required this.id,
    required this.userId,
    required this.email,
    required this.username,
    required this.message,
    required this.logs,
    required this.appVersion,
    required this.platform,
    required this.status,
    required this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BugReport.fromRow(Map<String, dynamic> row) => BugReport(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        email: row['email'] as String?,
        username: row['username'] as String?,
        message: row['message'] as String,
        logs: row['logs'] as String?,
        appVersion: row['app_version'] as String?,
        platform: row['platform'] as String?,
        status: (row['status'] as String?) ?? 'open',
        adminNote: row['admin_note'] as String?,
        createdAt: parseIsoOrNow(row['created_at']),
        updatedAt: parseIsoOrNow(row['updated_at']),
      );
}

/// Exception: kullanıcı son 1 dk içinde 1 veya son 1 saat içinde 5 rapor gönderdi.
class BugReportRateLimitException implements Exception {
  final String message;
  const BugReportRateLimitException(this.message);
  @override
  String toString() => 'BugReportRateLimitException: $message';
}

/// Bug report gönderimi (self) ve admin listeleme/status update.
class BugReportsRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Kullanıcı yeni bug raporu gönderir. Rate limit trigger'ı aşılırsa
  /// `BugReportRateLimitException` fırlatılır.
  Future<void> submit({
    required String message,
    String? logs,
    String? appVersion,
    String? platform,
  }) async {
    try {
      await _client.from('bug_reports').insert({
        'user_id': _userId,
        'message': message,
        if (logs != null && logs.isNotEmpty) 'logs': logs,
        'app_version': appVersion,
        'platform': platform,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('bug_report_rate_limit_exceeded')) {
        throw BugReportRateLimitException(e.message);
      }
      rethrow;
    }
  }

  /// Admin: bug raporlarını status filtresiyle getirir.
  /// `status` null veya 'all' → tüm raporlar.
  Future<List<BugReport>> fetchForAdmin({String? status}) async {
    final res = await _client.rpc(
      'get_bug_reports',
      params: {'p_status': status},
    );
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(BugReport.fromRow)
        .toList();
  }

  /// Admin: rapor status'ünü günceller (open/read/resolved).
  Future<void> updateStatus(String id, String status, {String? note}) async {
    await _client.rpc(
      'update_bug_report_status',
      params: {
        'p_id': id,
        'p_status': status,
        'p_note': note,
      },
    );
  }
}
