import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/conversation.dart';

class MessagesRemoteDataSource {
  static const _conversations = 'conversations';
  static const _messages = 'messages';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Auth kullanıcının üyesi olduğu tüm konuşmalar (en son aktiviteye göre).
  /// Single RPC call — replaces the old N+1 pattern.
  Future<List<Conversation>> fetchMyConversations() async {
    final result = await _client.rpc('get_my_conversations');
    if (result == null) return const [];
    final rows = (result as List).cast<Map<String, dynamic>>();
    return rows.map((c) {
      final members = (c['members'] as List?) ?? [];
      final memberIds = members
          .map((m) => (m as Map<String, dynamic>)['user_id'] as String)
          .toList();
      final memberUsernames = members
          .map((m) => (m as Map<String, dynamic>)['username'] as String)
          .toList();
      final lastMsg = c['last_message'] as Map<String, dynamic>?;
      return Conversation(
        id: c['id'] as String,
        isGroup: (c['is_group'] as bool?) ?? false,
        title: c['title'] as String?,
        createdBy: c['created_by'] as String?,
        memberIds: memberIds,
        memberUsernames: memberUsernames,
        lastMessageBody: lastMsg?['body'] as String?,
        lastMessageAt: lastMsg != null
            ? DateTime.parse(lastMsg['created_at'] as String)
            : null,
        createdAt: DateTime.parse(c['created_at'] as String),
        unreadCount: (c['unread_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
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

  /// Add a member to a group conversation (admin only).
  Future<void> addMember(String conversationId, String targetUserId) async {
    await _client.rpc('add_conversation_member', params: {
      'p_conv_id': conversationId,
      'p_target_user': targetUserId,
    });
  }

  /// Kick a member from a group conversation (admin only).
  Future<void> kickMember(String conversationId, String targetUserId) async {
    await _client.rpc('kick_conversation_member', params: {
      'p_conv_id': conversationId,
      'p_target_user': targetUserId,
    });
  }

  /// Grup ismini değiştir (yalnızca admin).
  Future<void> renameConversation(String conversationId, String title) async {
    await _client.rpc('rename_conversation', params: {
      'p_conv_id': conversationId,
      'p_title': title,
    });
  }

  /// Mark a conversation as read for the current user.
  Future<void> markRead(String conversationId) async {
    await _client.rpc('mark_conversation_read', params: {'p_conv_id': conversationId});
  }

  /// Total unread message count across all conversations (for badge).
  Future<int> fetchTotalUnreadCount() async {
    final result = await _client.rpc('get_total_unread_count');
    return (result as num?)?.toInt() ?? 0;
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
