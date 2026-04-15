import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserSummary {
  final String userId;
  final String? email;
  final String? username;
  final String provider;
  final DateTime createdAt;
  final bool isBeta;
  final bool isBanned;
  final int storageBytes;
  final DateTime? lastActiveAt;

  const AdminUserSummary({
    required this.userId,
    required this.email,
    required this.username,
    required this.provider,
    required this.createdAt,
    required this.isBeta,
    required this.isBanned,
    required this.storageBytes,
    required this.lastActiveAt,
  });

  factory AdminUserSummary.fromRow(Map<String, dynamic> row) => AdminUserSummary(
        userId: row['user_id'] as String,
        email: row['email'] as String?,
        username: row['username'] as String?,
        provider: (row['provider'] as String?) ?? 'email',
        createdAt: DateTime.parse(row['created_at'] as String),
        isBeta: row['is_beta'] as bool? ?? false,
        isBanned: row['is_banned'] as bool? ?? false,
        storageBytes: (row['storage_bytes'] as num?)?.toInt() ?? 0,
        lastActiveAt: row['last_active_at'] != null
            ? DateTime.parse(row['last_active_at'] as String)
            : null,
      );
}

class BannedUserEntry {
  final String userId;
  final String? email;
  final String? username;
  final String? reason;
  final DateTime bannedAt;

  const BannedUserEntry({
    required this.userId,
    required this.email,
    required this.username,
    required this.reason,
    required this.bannedAt,
  });

  factory BannedUserEntry.fromRow(Map<String, dynamic> row) => BannedUserEntry(
        userId: row['user_id'] as String,
        email: row['email'] as String?,
        username: row['username'] as String?,
        reason: row['reason'] as String?,
        bannedAt: DateTime.parse(row['banned_at'] as String),
      );
}

class StorageBucketStat {
  final String bucketId;
  final int objectCount;
  final int usedBytes;

  const StorageBucketStat({
    required this.bucketId,
    required this.objectCount,
    required this.usedBytes,
  });

  factory StorageBucketStat.fromRow(Map<String, dynamic> row) => StorageBucketStat(
        bucketId: row['bucket_id'] as String,
        objectCount: (row['object_count'] as num).toInt(),
        usedBytes: (row['used_bytes'] as num).toInt(),
      );
}

/// Admin paneli için user listesi, ban yönetimi ve storage istatistiği.
/// Tüm RPC'ler server tarafında `is_admin()` ile korunur.
class AdminUsersRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AdminUserSummary>> fetchAllUsers() async {
    final res = await _client.rpc('get_all_users_summary');
    return (res as List).cast<Map<String, dynamic>>().map(AdminUserSummary.fromRow).toList();
  }

  Future<List<AdminUserSummary>> searchUsers(String query) async {
    final res = await _client.rpc('search_users', params: {'p_query': query});
    return (res as List).cast<Map<String, dynamic>>().map(AdminUserSummary.fromRow).toList();
  }

  Future<void> banUser(String userId, String? reason) async {
    // 1) RPC: ban kaydı + cloud_backups/community_assets/beta_participants cleanup.
    await _client.rpc('ban_user', params: {
      'p_target': userId,
      'p_reason': reason ?? '',
    });
    // 2) Storage temizliği — Supabase artık storage.objects üzerinde doğrudan
    //    SQL DELETE'i engelliyor, bu yüzden Storage API üzerinden yapılıyor.
    //    Migration 008 admin kullanıcılara campaign-backups için DELETE izni verir.
    try {
      final storage = _client.storage.from('campaign-backups');
      final objects = await storage.list(path: userId);
      if (objects.isNotEmpty) {
        final paths = objects.map((o) => '$userId/${o.name}').toList();
        await storage.remove(paths);
      }
    } catch (e) {
      // Storage cleanup best-effort; ban kaydı yine de açılmış olacak.
      // ignore: avoid_print
      print('Ban storage cleanup warning for $userId: $e');
    }
  }

  Future<void> unbanUser(String userId) async {
    await _client.rpc('unban_user', params: {'p_target': userId});
  }

  Future<List<BannedUserEntry>> fetchBannedUsers() async {
    final res = await _client.rpc('get_banned_users');
    return (res as List).cast<Map<String, dynamic>>().map(BannedUserEntry.fromRow).toList();
  }

  Future<List<StorageBucketStat>> fetchStorageStats() async {
    final res = await _client.rpc('get_system_storage_stats');
    return (res as List).cast<Map<String, dynamic>>().map(StorageBucketStat.fromRow).toList();
  }
}
