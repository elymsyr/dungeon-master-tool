import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/conversation.dart';

class MessagesRemoteDataSource {
  static const _conversations = 'conversations';
  static const _members = 'conversation_members';
  static const _messages = 'messages';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Auth kullanıcının üyesi olduğu tüm konuşmalar (en son aktiviteye göre).
  Future<List<Conversation>> fetchMyConversations() async {
    final uid = _userId;
    final memberRows = await _client
        .from(_members)
        .select('conversation_id')
        .eq('user_id', uid);
    final ids = memberRows.map((r) => r['conversation_id'] as String).toList();
    if (ids.isEmpty) return const [];

    final convRows = await _client
        .from(_conversations)
        .select('*')
        .inFilter('id', ids)
        .order('created_at', ascending: false);

    // Her konuşmanın üyelerini topla (basit fetch — N+1 ama küçük listeler için yeterli).
    final result = <Conversation>[];
    for (final c in convRows) {
      final convId = c['id'] as String;
      final memberRows = await _client
          .from(_members)
          .select('user_id, profiles!conversation_members_user_id_fkey(username)')
          .eq('conversation_id', convId);
      final memberIds = <String>[];
      final memberUsernames = <String>[];
      for (final m in memberRows) {
        memberIds.add(m['user_id'] as String);
        final p = m['profiles'] as Map<String, dynamic>?;
        if (p != null) memberUsernames.add(p['username'] as String);
      }

      final lastMsg = await _client
          .from(_messages)
          .select('body, created_at')
          .eq('conversation_id', convId)
          .order('created_at', ascending: false)
          .limit(1);

      result.add(Conversation(
        id: convId,
        isGroup: (c['is_group'] as bool?) ?? false,
        title: c['title'] as String?,
        memberIds: memberIds,
        memberUsernames: memberUsernames,
        lastMessageBody: lastMsg.isNotEmpty ? lastMsg.first['body'] as String? : null,
        lastMessageAt: lastMsg.isNotEmpty
            ? DateTime.parse(lastMsg.first['created_at'] as String)
            : null,
        createdAt: DateTime.parse(c['created_at'] as String),
      ));
    }
    return result;
  }

  /// Bir kullanıcı ile DM aç (varsa mevcudunu döner, yoksa oluşturur).
  Future<Conversation> openDirect(String otherUserId) async {
    final uid = _userId;
    // Kendi membership'lerini al, sonra her birinin diğer üyesini kontrol et.
    final myConvs = await _client
        .from(_members)
        .select('conversation_id')
        .eq('user_id', uid);
    for (final r in myConvs) {
      final convId = r['conversation_id'] as String;
      final conv = await _client
          .from(_conversations)
          .select('is_group')
          .eq('id', convId)
          .maybeSingle();
      if (conv == null || conv['is_group'] == true) continue;

      final members = await _client
          .from(_members)
          .select('user_id')
          .eq('conversation_id', convId);
      final ids = members.map((m) => m['user_id'] as String).toSet();
      if (ids.length == 2 && ids.contains(otherUserId)) {
        // Mevcut DM bulundu
        return (await fetchMyConversations()).firstWhere((c) => c.id == convId);
      }
    }

    // Yoksa yeni oluştur.
    final created = await _client
        .from(_conversations)
        .insert({'is_group': false, 'created_by': uid})
        .select()
        .single();
    final convId = created['id'] as String;
    await _client.from(_members).insert([
      {'conversation_id': convId, 'user_id': uid},
      {'conversation_id': convId, 'user_id': otherUserId},
    ]);
    return Conversation(
      id: convId,
      isGroup: false,
      memberIds: [uid, otherUserId],
      createdAt: DateTime.parse(created['created_at'] as String),
    );
  }

  /// Grup oluştur.
  Future<Conversation> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final uid = _userId;
    final all = {uid, ...memberIds}.toList();
    final created = await _client
        .from(_conversations)
        .insert({'is_group': true, 'title': title, 'created_by': uid})
        .select()
        .single();
    final convId = created['id'] as String;
    await _client.from(_members).insert([
      for (final m in all) {'conversation_id': convId, 'user_id': m},
    ]);
    return Conversation(
      id: convId,
      isGroup: true,
      title: title,
      memberIds: all,
      createdAt: DateTime.parse(created['created_at'] as String),
    );
  }

  /// Bir konuşmanın mesajlarını getir (en eskiden yeniye).
  Future<List<ChatMessage>> fetchMessages(String conversationId, {int limit = 200}) async {
    final rows = await _client
        .from(_messages)
        .select('*, profiles!messages_author_id_fkey(username)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);
    return rows.map(_rowToMessage).toList();
  }

  Future<ChatMessage> send(String conversationId, String body) async {
    final inserted = await _client.from(_messages).insert({
      'conversation_id': conversationId,
      'author_id': _userId,
      'body': body,
    }).select('*, profiles!messages_author_id_fkey(username)').single();
    return _rowToMessage(inserted);
  }

  /// Realtime stream — sadece bu konuşmaya ait yeni mesajlar.
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _client
        .from(_messages)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map(_rowToMessage).toList());
  }

  ChatMessage _rowToMessage(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return ChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      authorId: row['author_id'] as String?,
      authorUsername: profile?['username'] as String?,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
