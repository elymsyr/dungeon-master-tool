import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/user_profile.dart';

/// Supabase `profiles` tablosu + `profile_counts` view + `search_profiles` RPC
/// üzerinde CRUD ve query işlemleri.
class ProfilesRemoteDataSource {
  static const _table = 'profiles';
  static const _countsView = 'profile_counts';
  static const _avatarBucket = 'avatars';

  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Mevcut auth user için profil getir; profil henüz oluşturulmamışsa null.
  Future<UserProfile?> fetchCurrent() async {
    final uid = _currentUserId;
    if (uid == null) return null;
    return fetchById(uid);
  }

  /// Belirli kullanıcının profili — yoksa null.
  Future<UserProfile?> fetchById(String userId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;

    final counts = await _client
        .from(_countsView)
        .select('followers, following')
        .eq('user_id', userId)
        .limit(1);
    final followers = counts.isNotEmpty ? (counts.first['followers'] as int? ?? 0) : 0;
    final following = counts.isNotEmpty ? (counts.first['following'] as int? ?? 0) : 0;

    return _rowToProfile(rows.first, followers: followers, following: following);
  }

  /// Username'in serbest olup olmadığını kontrol et.
  Future<bool> isUsernameAvailable(String username) async {
    final rows = await _client
        .from(_table)
        .select('user_id')
        .eq('username', username.toLowerCase())
        .limit(1);
    return rows.isEmpty;
  }

  /// Profil oluştur (ilk sign-in akışı). user_id çakışırsa mevcut satırı
  /// günceller — yani idempotent. Username çakışması (başka kullanıcı aynı
  /// username'i almışsa) ayrı unique constraint ile reddedilir.
  Future<UserProfile> create({
    required String username,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('Not authenticated');

    final row = {
      'user_id': uid,
      'username': username.toLowerCase(),
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final inserted = await _client
        .from(_table)
        .upsert(row, onConflict: 'user_id')
        .select()
        .single();
    return _rowToProfile(inserted);
  }

  /// Mevcut profili güncelle. Yalnızca verilen alanlar dokunulur.
  Future<UserProfile> update({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? hiddenFromDiscover,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('Not authenticated');

    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (username != null) patch['username'] = username.toLowerCase();
    if (displayName != null) patch['display_name'] = displayName;
    if (bio != null) patch['bio'] = bio;
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (hiddenFromDiscover != null) patch['hidden_from_discover'] = hiddenFromDiscover;

    final updated = await _client
        .from(_table)
        .update(patch)
        .eq('user_id', uid)
        .select()
        .single();
    return _rowToProfile(updated);
  }

  /// Avatar görselini Supabase Storage `avatars` bucket'ına yükler ve public
  /// URL döner. Aynı kullanıcının önceki avatarı üzerine yazılır.
  Future<String> uploadAvatar(Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final path = '$uid/avatar.$ext';
    await _client.storage.from(_avatarBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from(_avatarBucket).getPublicUrl(path);
  }

  /// Username prefix araması (Players tab discover).
  Future<List<UserProfile>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _client.rpc('search_profiles', params: {
      'p_query': query.trim().toLowerCase(),
      'p_limit': limit,
    });
    if (rows is! List) return const [];
    return rows.map((r) => _rowToProfile(r as Map<String, dynamic>)).toList();
  }

  /// Auth user'a önerilen kullanıcılar (henüz takip edilmeyen, en çok
  /// takipçiye sahip olanlar). Marketplace sağ panelinde kullanılır.
  Future<List<UserProfile>> suggested({int limit = 10}) async {
    final rows = await _client.rpc('suggested_profiles', params: {'p_limit': limit});
    if (rows is! List) return const [];
    return rows
        .map((r) => _rowToProfile(
              r as Map<String, dynamic>,
              followers: (r['followers'] as int?) ?? 0,
            ))
        .toList();
  }

  UserProfile _rowToProfile(
    Map<String, dynamic> row, {
    int followers = 0,
    int following = 0,
  }) {
    return UserProfile(
      userId: row['user_id'] as String,
      username: row['username'] as String,
      displayName: row['display_name'] as String?,
      bio: row['bio'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      followers: followers,
      following: following,
      hiddenFromDiscover: row['hidden_from_discover'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now().toUtc(),
    );
  }
}
