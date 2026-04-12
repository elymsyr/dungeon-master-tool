import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/post.dart';

/// `posts` tablosu + `post-images` Storage bucket. Image upload size_bytes
/// olarak `posts.size_bytes` ve dolaylı olarak `get_user_total_storage_used`
/// quota'sına yansır.
class PostsRemoteDataSource {
  static const _table = 'posts';
  static const _bucket = 'post-images';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Takip edilenlerin postları (kendi postları dahil) — feed.
  Future<List<Post>> fetchFeed({int limit = 50}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    // Following uid'leri çek, sonra posts tablosundan author_id IN (...) sorgula.
    final followsRows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', uid);
    final ids = <String>{
      uid,
      for (final r in followsRows) r['following_id'] as String,
    };

    final rows = await _client
        .from(_table)
        .select('*, profiles!posts_author_id_fkey(username, avatar_url)')
        .inFilter('author_id', ids.toList())
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(_rowToPost).toList();
  }

  /// Belirli bir kullanıcının postları — profile screen.
  Future<List<Post>> fetchByAuthor(String userId, {int limit = 50}) async {
    final rows = await _client
        .from(_table)
        .select('*, profiles!posts_author_id_fkey(username, avatar_url)')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(_rowToPost).toList();
  }

  /// Yeni post oluştur. [imageBytes] verilirse Storage'a yüklenir, kota
  /// `get_user_total_storage_used` ile birlikte UI tarafından kontrol edilir.
  Future<Post> create({
    String? body,
    Uint8List? imageBytes,
    String contentType = 'image/jpeg',
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
    }).select('*, profiles!posts_author_id_fkey(username, avatar_url)').single();
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
    return Post(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorUsername: profile?['username'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      body: row['body'] as String?,
      imageUrl: row['image_url'] as String?,
      sizeBytes: (row['size_bytes'] as int?) ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
