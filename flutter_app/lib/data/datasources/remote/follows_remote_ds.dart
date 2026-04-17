import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parse_utils.dart';
import '../../../domain/entities/user_profile.dart';

/// `follows` tablosu üzerinde takip toggle ve listeleme.
class FollowsRemoteDataSource {
  static const _table = 'follows';
  static const _profilesTable = 'profiles';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Auth user, [targetUserId]'i takip ediyor mu?
  Future<bool> isFollowing(String targetUserId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await _client
        .from(_table)
        .select('follower_id')
        .eq('follower_id', uid)
        .eq('following_id', targetUserId)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// Takip et / takipten çık. Yeni durumu döner.
  Future<bool> toggle(String targetUserId) async {
    final uid = _userId;
    if (uid == targetUserId) return false;

    final following = await isFollowing(targetUserId);
    if (following) {
      await _client
          .from(_table)
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', targetUserId);
      return false;
    } else {
      await _client.from(_table).insert({
        'follower_id': uid,
        'following_id': targetUserId,
      });
      return true;
    }
  }

  /// Bir kullanıcının takipçilerini getir.
  Future<List<UserProfile>> followersOf(String userId) async {
    final rows = await _client
        .from(_table)
        .select('follower_id, $_profilesTable!follows_follower_id_fkey(*)')
        .eq('following_id', userId);
    return _flatten(rows, key: 'follower_id');
  }

  /// Bir kullanıcının takip ettiklerini getir.
  Future<List<UserProfile>> followingOf(String userId) async {
    final rows = await _client
        .from(_table)
        .select('following_id, $_profilesTable!follows_following_id_fkey(*)')
        .eq('follower_id', userId);
    return _flatten(rows, key: 'following_id');
  }

  List<UserProfile> _flatten(List<dynamic> rows, {required String key}) {
    return rows
        .map<UserProfile?>((r) {
          final m = r as Map<String, dynamic>;
          final profile = m[_profilesTable];
          if (profile is! Map<String, dynamic>) return null;
          return UserProfile(
            userId: profile['user_id'] as String,
            username: profile['username'] as String,
            displayName: profile['display_name'] as String?,
            bio: profile['bio'] as String?,
            avatarUrl: profile['avatar_url'] as String?,
            createdAt: parseIsoOrNull(profile['created_at']) ??
                DateTime.now().toUtc(),
          );
        })
        .whereType<UserProfile>()
        .toList();
  }
}
