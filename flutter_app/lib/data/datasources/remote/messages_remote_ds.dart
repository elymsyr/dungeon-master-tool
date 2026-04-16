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
        createdBy: c['created_by'] as String?,
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
  /// SECURITY DEFINER RPC kullanır — RLS sıralaması nedeniyle direkt insert
  /// çalışmıyordu (bkz. migration 010).
  Future<Conversation> openDirect(String otherUserId) async {
    final uid = _userId;
    final convId = await _client.rpc(
      'open_direct_conversation',
      params: {'p_other_user': otherUserId},
    ) as String;
    final row = await _client
        .from(_conversations)
        .select('*')
        .eq('id', convId)
        .single();
    return Conversation(
      id: convId,
      isGroup: (row['is_group'] as bool?) ?? false,
      title: row['title'] as String?,
      createdBy: row['created_by'] as String?,
      memberIds: [uid, otherUserId],
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Grup oluştur.
  Future<Conversation> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final uid = _userId;
    final all = {uid, ...memberIds}.toList();
    final others = memberIds.where((m) => m != uid).toList();
    final convId = await _client.rpc(
      'create_group_conversation',
      params: {'p_title': title, 'p_members': others},
    ) as String;
    final row = await _client
        .from(_conversations)
        .select('*')
        .eq('id', convId)
        .single();
    return Conversation(
      id: convId,
      isGroup: true,
      title: title,
      createdBy: uid,
      memberIds: all,
      createdAt: DateTime.parse(row['created_at'] as String),
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

  /// Mesaj sil (yalnızca kendi mesajları — RLS policy kontrol eder).
  Future<void> deleteMessage(String messageId) async {
    await _client.from(_messages).delete().eq('id', messageId);
  }

  /// Konuşmadan ayrıl. Admin ise yöneticilik transfer edilir; son üyeyse
  /// konuşma silinir.
  Future<void> leaveConversation(String conversationId) async {
    await _client.rpc('leave_conversation', params: {'p_conv_id': conversationId});
  }

  /// Konuşmayı tamamen sil (yalnızca admin). CASCADE ile tüm üyeler ve
  /// mesajlar silinir.
  Future<void> deleteConversation(String conversationId) async {
    await _client.rpc('delete_conversation', params: {'p_conv_id': conversationId});
  }

  /// Grup ismini değiştir (yalnızca admin).
  Future<void> renameConversation(String conversationId, String title) async {
    await _client.rpc('rename_conversation', params: {
      'p_conv_id': conversationId,
      'p_title': title,
    });
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
