import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parse_utils.dart';

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
  final String? appVersion;
  final String? platform;
  final bool onlineRestricted;
  final String? onlineRestrictedReason;

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
    this.appVersion,
    this.platform,
    this.onlineRestricted = false,
    this.onlineRestrictedReason,
  });

  factory AdminUserSummary.fromRow(Map<String, dynamic> row) => AdminUserSummary(
        userId: row['user_id'] as String,
        email: row['email'] as String?,
        username: row['username'] as String?,
        provider: (row['provider'] as String?) ?? 'email',
        createdAt: parseIsoOrNow(row['created_at']),
        isBeta: row['is_beta'] as bool? ?? false,
        isBanned: row['is_banned'] as bool? ?? false,
        storageBytes: (row['storage_bytes'] as num?)?.toInt() ?? 0,
        lastActiveAt: parseIsoOrNull(row['last_active_at']),
        appVersion: row['app_version'] as String?,
        platform: row['platform'] as String?,
        onlineRestricted: row['online_restricted'] as bool? ?? false,
        onlineRestrictedReason: row['online_restricted_reason'] as String?,
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
        bannedAt: parseIsoOrNow(row['banned_at']),
      );
}

class RestrictedUserEntry {
  final String userId;
  final String? email;
  final String? username;
  final String? reason;
  final DateTime? restrictedAt;

  const RestrictedUserEntry({
    required this.userId,
    required this.email,
    required this.username,
    required this.reason,
    required this.restrictedAt,
  });

  factory RestrictedUserEntry.fromRow(Map<String, dynamic> row) =>
      RestrictedUserEntry(
        userId: row['user_id'] as String,
        email: row['email'] as String?,
        username: row['username'] as String?,
        reason: row['reason'] as String?,
        restrictedAt: parseIsoOrNull(row['restricted_at']),
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

/// Mevcut kullanıcının online restriction durumu. `am_i_online_restricted` RPC
/// sonucundan türetilir.
class OnlineRestriction {
  final bool restricted;
  final String? reason;
  final DateTime? restrictedAt;
  const OnlineRestriction({
    required this.restricted,
    this.reason,
    this.restrictedAt,
  });

  static const none = OnlineRestriction(restricted: false);
}

/// Admin moderation dashboard'u için post/listing satırları.
class AdminPostRow {
  final String id;
  final String authorId;
  final String authorName;
  final String? body;
  final String? imageUrl;
  final int sizeBytes;
  final DateTime createdAt;

  const AdminPostRow({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.imageUrl,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory AdminPostRow.fromRow(Map<String, dynamic> row) => AdminPostRow(
        id: row['id'] as String,
        authorId: row['author_id'] as String,
        authorName: (row['author_name'] as String?) ?? '',
        body: row['body'] as String?,
        imageUrl: row['image_url'] as String?,
        sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: parseIsoOrNow(row['created_at']),
      );
}

class AdminGameListingRow {
  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String? system;
  final bool isOpen;
  final DateTime createdAt;

  const AdminGameListingRow({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.system,
    required this.isOpen,
    required this.createdAt,
  });

  factory AdminGameListingRow.fromRow(Map<String, dynamic> row) =>
      AdminGameListingRow(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        ownerName: (row['owner_name'] as String?) ?? '',
        title: (row['title'] as String?) ?? '',
        system: row['system'] as String?,
        isOpen: row['is_open'] as bool? ?? true,
        createdAt: parseIsoOrNow(row['created_at']),
      );
}

class AdminMarketplaceListingRow {
  final String id;
  final String ownerId;
  final String ownerName;
  final String itemType;
  final String title;
  final String? language;
  final int sizeBytes;
  final bool isBuiltin;
  final DateTime createdAt;

  const AdminMarketplaceListingRow({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.itemType,
    required this.title,
    required this.language,
    required this.sizeBytes,
    required this.isBuiltin,
    required this.createdAt,
  });

  factory AdminMarketplaceListingRow.fromRow(Map<String, dynamic> row) =>
      AdminMarketplaceListingRow(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        ownerName: (row['owner_name'] as String?) ?? '',
        itemType: (row['item_type'] as String?) ?? '',
        title: (row['title'] as String?) ?? '',
        language: row['language'] as String?,
        sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
        isBuiltin: row['is_builtin'] as bool? ?? false,
        createdAt: parseIsoOrNow(row['created_at']),
      );
}

class AdminAuditLogEntry {
  final int id;
  final String? adminId;
  final String? adminName;
  final String action;
  final String? targetUserId;
  final String? targetUserName;
  final String? targetEntityId;
  final String? reason;
  final DateTime createdAt;

  const AdminAuditLogEntry({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetEntityId,
    required this.reason,
    required this.createdAt,
  });

  factory AdminAuditLogEntry.fromRow(Map<String, dynamic> row) =>
      AdminAuditLogEntry(
        id: (row['id'] as num).toInt(),
        adminId: row['admin_id'] as String?,
        adminName: row['admin_name'] as String?,
        action: (row['action'] as String?) ?? '',
        targetUserId: row['target_user_id'] as String?,
        targetUserName: row['target_user_name'] as String?,
        targetEntityId: row['target_entity_id'] as String?,
        reason: row['reason'] as String?,
        createdAt: parseIsoOrNow(row['created_at']),
      );
}

/// Admin paneli için user listesi, ban yönetimi, online restriction ve
/// içerik moderasyonu. Tüm RPC'ler server tarafında `is_admin()` ile korunur.
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
    // 1) RPC: ban kaydı + tüm online veri cleanup (posts/messages/likes/follows/
    //    game listings/marketplace listings/bug reports). Profil kaydı
    //    korunur ama anonimleştirilir. Detay: migration 023.
    await _client.rpc('ban_user', params: {
      'p_target': userId,
      'p_reason': reason ?? '',
    });
    // 2) Storage temizliği — Supabase storage.objects üzerinde doğrudan SQL
    //    DELETE'i engellediği için Storage API üzerinden yapılır.
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

  // ── Online restriction ────────────────────────────────────────────────────

  /// Kullanıcıya online yasağı koy / kaldır.
  Future<void> setOnlineRestriction({
    required String userId,
    required bool restricted,
    String? reason,
  }) async {
    await _client.rpc('set_online_restriction', params: {
      'p_target': userId,
      'p_restricted': restricted,
      'p_reason': reason,
    });
  }

  /// Restricted users listesi.
  Future<List<RestrictedUserEntry>> fetchRestrictedUsers() async {
    final res = await _client.rpc('get_restricted_users');
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(RestrictedUserEntry.fromRow)
        .toList();
  }

  /// Mevcut oturumun restrict durumu (kullanıcı tarafı).
  Future<OnlineRestriction> amIOnlineRestricted() async {
    try {
      final res = await _client.rpc('am_i_online_restricted');
      final rows = (res as List?) ?? const [];
      if (rows.isEmpty) return OnlineRestriction.none;
      final row = rows.first as Map<String, dynamic>;
      final flag = row['is_restricted'] as bool? ?? false;
      if (!flag) return OnlineRestriction.none;
      return OnlineRestriction(
        restricted: true,
        reason: row['reason'] as String?,
        restrictedAt: parseIsoOrNull(row['restricted_at']),
      );
    } catch (_) {
      return OnlineRestriction.none;
    }
  }

  // ── Admin moderation: içerik silme ────────────────────────────────────────

  Future<void> adminDeletePost(String postId) async {
    await _client.rpc('admin_delete_post', params: {'p_post': postId});
  }

  Future<void> adminDeleteMarketplaceListing({
    required String listingId,
    String? payloadPath,
  }) async {
    await _client
        .rpc('admin_delete_marketplace_listing', params: {'p_listing': listingId});
    if (payloadPath != null && payloadPath.isNotEmpty) {
      try {
        await _client.storage.from('shared-payloads').remove([payloadPath]);
      } catch (_) {
        // Best-effort storage cleanup.
      }
    }
  }

  Future<void> adminDeleteGameListing(String listingId) async {
    await _client
        .rpc('admin_delete_game_listing', params: {'p_listing': listingId});
  }

  Future<void> adminDeleteMessage(String messageId) async {
    await _client.rpc('admin_delete_message', params: {'p_message': messageId});
  }

  // ── Built-in toggle ───────────────────────────────────────────────────────

  Future<void> setListingBuiltin(String listingId, bool builtin) async {
    await _client.rpc('set_listing_builtin', params: {
      'p_listing': listingId,
      'p_builtin': builtin,
    });
  }

  // ── Admin listelemeler ────────────────────────────────────────────────────

  Future<List<AdminPostRow>> fetchAllPosts({int limit = 200}) async {
    final res = await _client.rpc('admin_list_posts', params: {'p_limit': limit});
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(AdminPostRow.fromRow)
        .toList();
  }

  Future<List<AdminGameListingRow>> fetchAllGameListings({int limit = 200}) async {
    final res = await _client
        .rpc('admin_list_game_listings', params: {'p_limit': limit});
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(AdminGameListingRow.fromRow)
        .toList();
  }

  Future<List<AdminMarketplaceListingRow>> fetchAllMarketplaceListings({
    bool? builtinOnly,
    int limit = 200,
  }) async {
    final res = await _client.rpc('admin_list_marketplace_listings', params: {
      'p_builtin_only': builtinOnly,
      'p_limit': limit,
    });
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(AdminMarketplaceListingRow.fromRow)
        .toList();
  }

  Future<List<AdminAuditLogEntry>> fetchAuditLog({
    String? action,
    int limit = 200,
  }) async {
    final res = await _client.rpc('admin_list_audit_log', params: {
      'p_limit': limit,
      'p_action': action,
    });
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(AdminAuditLogEntry.fromRow)
        .toList();
  }
}
