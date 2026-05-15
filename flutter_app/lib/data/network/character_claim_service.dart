import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/providers/world_characters_provider.dart';

/// `world_characters` üzerinde karakter ownership/world membership için thin
/// transport. 039 migration sonrası 5 merkezi RPC + bir direct UPDATE
/// (`attachToWorld`) ile çalışır. Eski `setOwner` direkt update kaldırıldı —
/// constraint by-pass riski.
class CharacterClaimService {
  final SupabaseClient client;
  CharacterClaimService(this.client);

  /// Player: `(NULL, W) → (auth.uid, W)`. RPC atomic, `FOR UPDATE` lock.
  /// Çakışan claim ikinci caller'a `P0003` döner.
  Future<({String characterId, String worldId})> claim(
      String characterId) async {
    final rows = await client.rpc('claim_character', params: {
      'p_character_id': characterId,
    });
    if (rows is! List || rows.isEmpty) {
      throw StateError('claim_character returned empty result');
    }
    final first = rows.first as Map<String, dynamic>;
    return (
      characterId: first['character_id'] as String,
      worldId: first['world_id'] as String,
    );
  }

  /// Ownership drop.
  ///   - `(me, W) → (NULL, W)` UPDATE
  ///   - `(me, NULL) → DELETE` (CHECK violation olurdu, RPC siler)
  /// DM force-release de bu RPC'den geçer; RPC owner-or-DM gate uygular.
  /// Zaten serbestse idempotent — `deleted: false, worldId: prevWorldId`.
  Future<({String characterId, String? worldId, bool deleted})> release(
      String characterId) async {
    final rows = await client.rpc('release_character', params: {
      'p_character_id': characterId,
    });
    if (rows is! List || rows.isEmpty) {
      throw StateError('release_character returned empty result');
    }
    final first = rows.first as Map<String, dynamic>;
    return (
      characterId: first['character_id'] as String,
      worldId: first['world_id'] as String?,
      deleted: (first['deleted'] as bool?) ?? false,
    );
  }

  /// Karakteri dünyadan çıkar.
  ///   - `(owner, W) → (owner, NULL)` UPDATE — orphan'a düşer
  ///   - `(NULL, W) → DELETE` — unclaimed silinir
  /// Yetki: owner = auth.uid OR `is_world_dm(world_id)`.
  Future<({String characterId, bool deleted})> removeFromWorld(
      String characterId) async {
    final rows = await client.rpc('remove_from_world', params: {
      'p_character_id': characterId,
    });
    if (rows is! List || rows.isEmpty) {
      throw StateError('remove_from_world returned empty result');
    }
    final first = rows.first as Map<String, dynamic>;
    return (
      characterId: first['character_id'] as String,
      deleted: (first['deleted'] as bool?) ?? false,
    );
  }

  /// Hard delete — yalnız `(owner, NULL)` orphan'lar için. World-bound
  /// karakterlerde `P0005` exception (yanlış RPC; `removeFromWorld` veya
  /// `release` çağrılmalı).
  Future<void> deleteCharacter(String characterId) async {
    await client.rpc('delete_character', params: {
      'p_character_id': characterId,
    });
  }

  /// DM: karaktere oyuncu ata. `(NULL, W) → (userId, W)` veya `(other, W) →
  /// (userId, W)`. Target user `world_members` üyesi olmak zorunda; aksi
  /// `P0006`. DM olmadan çağrılırsa `42501`.
  Future<void> assignToPlayer({
    required String characterId,
    required String userId,
  }) async {
    await client.rpc('assign_character', params: {
      'p_character_id': characterId,
      'p_user_id': userId,
    });
  }

  /// Orphan karakteri dünyaya bağla: `(me, NULL) → (me, W)`. Direkt UPDATE —
  /// RLS UPDATE policy `owner_id = auth.uid OR is_world_dm` ile gate'lenir.
  /// RPC üretmeye gerek yok: tek satır transition, server-side decision yok.
  Future<void> attachToWorld({
    required String characterId,
    required String worldId,
  }) async {
    await client
        .from('world_characters')
        .update({
          'world_id': worldId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', characterId);
  }

  /// `world_characters` bir world'ün satırlarını listeler. RLS gereği member
  /// olduğun dünyaların tüm karakterlerini görürsün. Bootstrap'te bir kez
  /// çağrılır; sonrası CDC ile granular patch.
  Future<List<WorldCharacterRow>> listWorldCharacters(String worldId) async {
    final rows = await client
        .from('world_characters')
        .select(
            'id, world_id, owner_id, template_id, template_name, payload_json, updated_at')
        .eq('world_id', worldId);
    final out = <WorldCharacterRow>[];
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      out.add(WorldCharacterRow(
        id: m['id'] as String,
        worldId: m['world_id'] as String,
        ownerId: m['owner_id'] as String?,
        templateId: (m['template_id'] as String?) ?? '',
        templateName: (m['template_name'] as String?) ?? '',
        payloadJson: (m['payload_json'] as String?) ?? '{}',
        updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      ));
    }
    return out;
  }
}
