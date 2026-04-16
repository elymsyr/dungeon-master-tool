import 'dart:math' show pow;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/post.dart';

/// `posts` tablosu + `post-images` Storage bucket. Image upload size_bytes
/// olarak `posts.size_bytes` ve dolaylı olarak `get_user_total_storage_used`
/// quota'sına yansır.
enum FeedScope { all, following, gameLists }

class PostsRemoteDataSource {
  static const _table = 'posts';
  static const _bucket = 'post-images';
  static const _likesTable = 'post_likes';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Feed sorgusu. [scope] = all → tüm kullanıcılar, following → takip
  /// edilenler + kendisi. Sonuçların yaklaşık üçte biri "hot" sırasıyla
  /// (post_scores view) en başa konur, geri kalan sade tarih sırasıyla.
  Future<List<Post>> fetchFeed({
    FeedScope scope = FeedScope.all,
    int limit = 50,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    if (scope == FeedScope.gameLists) return const [];

    List<String>? authorIds;
    if (scope == FeedScope.following) {
      final followsRows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid);
      final ids = <String>{
        uid,
        for (final r in followsRows) r['following_id'] as String,
      };
      authorIds = ids.toList();
      if (authorIds.isEmpty) return const [];
    }

    var query = _client
        .from(_table)
        .select('*, profiles!posts_author_id_fkey(username, avatar_url), marketplace_listings!posts_marketplace_item_id_fkey(id, title, item_type), game_listings!posts_game_listing_id_fkey(id, title, system)');
    if (authorIds != null) {
      query = query.inFilter('author_id', authorIds);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);
    final posts = rows.map(_rowToPost).toList();
    return _hydrateLikesAndRank(posts, uid);
  }

  /// Belirli bir kullanıcının postları — profile screen.
  Future<List<Post>> fetchByAuthor(String userId, {int limit = 50}) async {
    final rows = await _client
        .from(_table)
        .select('*, profiles!posts_author_id_fkey(username, avatar_url), marketplace_listings!posts_marketplace_item_id_fkey(id, title, item_type), game_listings!posts_game_listing_id_fkey(id, title, system)')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    final posts = rows.map(_rowToPost).toList();
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return posts;
    return _hydrateLikes(posts, uid);
  }

  /// Bir post'u beğen / beğeniyi geri al. Yeni durumu döner (true = liked).
  Future<bool> toggleLike(String postId) async {
    final uid = _userId;
    final existing = await _client
        .from(_likesTable)
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .limit(1);
    if (existing.isNotEmpty) {
      await _client
          .from(_likesTable)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
      return false;
    } else {
      await _client.from(_likesTable).insert({
        'post_id': postId,
        'user_id': uid,
      });
      return true;
    }
  }

  Future<List<Post>> _hydrateLikes(List<Post> posts, String uid) async {
    if (posts.isEmpty) return posts;
    final ids = posts.map((p) => p.id).toList();
    final likeRows = await _client
        .from(_likesTable)
        .select('post_id, user_id')
        .inFilter('post_id', ids);
    final counts = <String, int>{};
    final liked = <String>{};
    for (final r in likeRows) {
      final pid = r['post_id'] as String;
      counts[pid] = (counts[pid] ?? 0) + 1;
      if (r['user_id'] == uid) liked.add(pid);
    }
    return posts
        .map((p) => p.copyWith(
              likeCount: counts[p.id] ?? 0,
              likedByMe: liked.contains(p.id),
            ))
        .toList();
  }

  /// _hydrateLikes + ara ara çok beğenilen postları yukarı taşır.
  /// Strateji: postları HN-style hot_score ile sırala, en üst 5'in 3'ünü
  /// kronolojik listenin önüne enjekte et. Bu sayede feed kronolojik akışı
  /// büyük ölçüde korunur ama trend olan postlar da öne çıkar.
  Future<List<Post>> _hydrateLikesAndRank(List<Post> posts, String uid) async {
    final hydrated = await _hydrateLikes(posts, uid);
    if (hydrated.length < 4) return hydrated;
    final now = DateTime.now().toUtc();
    double score(Post p) {
      final hours = now.difference(p.createdAt.toUtc()).inMinutes / 60.0;
      return (p.likeCount + 1) / pow(hours + 2, 1.5);
    }
    final ranked = [...hydrated]..sort((a, b) => score(b).compareTo(score(a)));
    final top = ranked.take(3).where((p) => p.likeCount > 0).toList();
    if (top.isEmpty) return hydrated;
    final topIds = top.map((p) => p.id).toSet();
    final rest = hydrated.where((p) => !topIds.contains(p.id)).toList();
    return [...top, ...rest];
  }

  /// Yeni post oluştur. [imageBytes] verilirse Storage'a yüklenir, kota
  /// `get_user_total_storage_used` ile birlikte UI tarafından kontrol edilir.
  Future<Post> create({
    String? body,
    Uint8List? imageBytes,
    String contentType = 'image/jpeg',
    String? marketplaceItemId,
    String? gameListingId,
  }) async {
    final uid = _userId;
    String? imageUrl;
    String? imagePath;
    int sizeBytes = 0;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final ext = contentType.contains('png') ? 'png' : 'jpg';
      final ts = DateTime.now().millisecondsSinceEpoch;
      imagePath = '$uid/$ts.$ext';
      await _client.storage.from(_bucket).uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      imageUrl = _client.storage.from(_bucket).getPublicUrl(imagePath);
      sizeBytes = imageBytes.length;
    }

    final inserted = await _client.from(_table).insert({
      'author_id': uid,
      'body': body,
      'image_url': imageUrl,
      'image_path': imagePath,
      'size_bytes': sizeBytes,
      'marketplace_item_id': marketplaceItemId,
      'game_listing_id': gameListingId,
    }).select('*, profiles!posts_author_id_fkey(username, avatar_url), marketplace_listings!posts_marketplace_item_id_fkey(id, title, item_type), game_listings!posts_game_listing_id_fkey(id, title, system)').single();
    return _rowToPost(inserted);
  }

  Future<void> delete(String postId) async {
    final row = await _client
        .from(_table)
        .select('image_path')
        .eq('id', postId)
        .eq('author_id', _userId)
        .maybeSingle();
    if (row != null && row['image_path'] != null) {
      try {
        await _client.storage.from(_bucket).remove([row['image_path'] as String]);
      } catch (e) {
        debugPrint('Post image delete failed: $e');
      }
    }
    await _client.from(_table).delete().eq('id', postId);
  }

  Post _rowToPost(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final marketplace = row['marketplace_listings'] as Map<String, dynamic>?;
    final gameListing = row['game_listings'] as Map<String, dynamic>?;
    return Post(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorUsername: profile?['username'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      body: row['body'] as String?,
      imageUrl: row['image_url'] as String?,
      sizeBytes: (row['size_bytes'] as int?) ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      marketplaceItemId: marketplace?['id'] as String?,
      marketplaceItemTitle: marketplace?['title'] as String?,
      marketplaceItemType: marketplace?['item_type'] as String?,
      gameListingId: gameListing?['id'] as String?,
      gameListingTitle: gameListing?['title'] as String?,
      gameListingSystem: gameListing?['system'] as String?,
    );
  }
}
