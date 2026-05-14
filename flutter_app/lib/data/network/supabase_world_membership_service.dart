import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/online/world_invite.dart';
import '../../domain/entities/online/world_member.dart';
import '../../domain/entities/online/world_role.dart';
import 'world_membership_service.dart';

/// Supabase-backed implementation. Tüm yetki RLS politikaları + RPC'lerde
/// (026_online_worlds.sql) kontrol edilir; bu sınıf transport katmanıdır.
class SupabaseWorldMembershipService implements WorldMembershipService {
  final SupabaseClient client;

  SupabaseWorldMembershipService(this.client);

  String get _uid {
    final id = client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('SupabaseWorldMembershipService requires auth session');
    }
    return id;
  }

  @override
  Future<void> publishWorld({
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required String stateJson,
  }) async {
    // RLS gürültüsünden kaçınmak için tüm publish akışı `publish_world`
    // RPC'sine taşındı (migration 029). RPC SECURITY DEFINER + row_security
    // off ile worlds + world_members'ı atomik günceller, orphan satırları
    // tolere eder ve farklı hesap sahibiyse net hata fırlatır.
    try {
      await client.rpc('publish_world', params: {
        'p_world_id': worldId,
        'p_world_name': worldName,
        'p_template_id': templateId,
        'p_template_hash': templateHash,
        'p_state_json': stateJson,
      });
    } on PostgrestException catch (e) {
      debugPrint(
          'publish_world RPC FAILED: code=${e.code} msg=${e.message} details=${e.details} hint=${e.hint}');
      rethrow;
    }
  }

  @override
  Future<void> unpublishWorld(String worldId) async {
    // ON DELETE CASCADE tüm mirror data'yı siler.
    await client.from('worlds').delete().eq('id', worldId);
  }

  @override
  Future<String> createInvite({
    required String worldId,
    int? expiresSeconds,
    int uses = 1,
  }) async {
    final result = await client.rpc('create_world_invite', params: {
      'p_world_id': worldId,
      'p_expires_secs': ?expiresSeconds,
      'p_uses': uses,
    });
    if (result is String) return result;
    throw StateError('create_world_invite returned unexpected: $result');
  }

  @override
  Future<String> ensureInvite(String worldId) async {
    final result = await client
        .rpc('ensure_world_invite', params: {'p_world_id': worldId});
    if (result is String) return result;
    throw StateError('ensure_world_invite returned unexpected: $result');
  }

  @override
  Future<String> regenerateInvite(String worldId) async {
    final result = await client
        .rpc('regenerate_world_invite', params: {'p_world_id': worldId});
    if (result is String) return result;
    throw StateError('regenerate_world_invite returned unexpected: $result');
  }

  @override
  Future<({String worldId, String worldName})> redeemInvite(String code) async {
    final rows = await client.rpc('redeem_world_invite', params: {
      'p_code': code.toUpperCase().trim(),
    });
    if (rows is! List || rows.isEmpty) {
      throw StateError('redeem_world_invite returned empty result');
    }
    final first = rows.first as Map<String, dynamic>;
    return (
      worldId: first['world_id'] as String,
      worldName: first['world_name'] as String,
    );
  }

  @override
  Future<List<WorldMember>> listMembers(String worldId) async {
    // world_members ile profiles arasında direct FK yok (her ikisi de
    // auth.users referans veriyor). PostgREST embedded select bu yüzden
    // çalışmıyor — iki ayrı sorgu çekip client-side merge.
    final memberRows = await client
        .from('world_members')
        .select('world_id, user_id, role, joined_at')
        .eq('world_id', worldId);
    final members = (memberRows as List)
        .map((r) => r as Map<String, dynamic>)
        .toList();
    if (members.isEmpty) return const [];
    final userIds = members
        .map((m) => m['user_id'] as String)
        .toSet()
        .toList(growable: false);
    final profileRows = await client
        .from('profiles')
        .select('user_id, username, display_name, avatar_url')
        .inFilter('user_id', userIds);
    final profilesById = <String, Map<String, dynamic>>{
      for (final p in (profileRows as List))
        ((p as Map)['user_id'] as String): Map<String, dynamic>.from(p),
    };
    return members.map((m) {
      final profile = profilesById[m['user_id'] as String];
      return WorldMember(
        worldId: m['world_id'] as String,
        userId: m['user_id'] as String,
        role: _parseRole(m['role'] as String),
        joinedAt: DateTime.parse(m['joined_at'] as String),
        username: profile?['username'] as String?,
        displayName: profile?['display_name'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
      );
    }).toList(growable: false);
  }

  @override
  Future<List<WorldInvite>> listInvites(String worldId) async {
    final rows = await client
        .from('world_invites')
        .select()
        .eq('world_id', worldId)
        .order('created_at', ascending: false);
    return (rows as List).map((row) {
      final m = row as Map<String, dynamic>;
      return WorldInvite(
        code: m['code'] as String,
        worldId: m['world_id'] as String,
        createdBy: m['created_by'] as String,
        usesLeft: m['uses_left'] as int,
        createdAt: DateTime.parse(m['created_at'] as String),
        expiresAt: m['expires_at'] == null
            ? null
            : DateTime.parse(m['expires_at'] as String),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> removeMember(
      {required String worldId, required String userId}) async {
    await client
        .from('world_members')
        .delete()
        .eq('world_id', worldId)
        .eq('user_id', userId);
  }

  @override
  Future<void> leaveWorld(String worldId) async {
    await client
        .from('world_members')
        .delete()
        .eq('world_id', worldId)
        .eq('user_id', _uid);
  }

  @override
  Future<void> revokeInvite(String code) async {
    await client.from('world_invites').delete().eq('code', code.toUpperCase());
  }

  WorldRole _parseRole(String s) => switch (s) {
        'dm' => WorldRole.dm,
        'player' => WorldRole.player,
        _ => WorldRole.none,
      };
}
