import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/providers/world_characters_provider.dart';

/// `world_characters` + `claim_character` RPC için thin transport.
///
/// Pool tablosu (`character_claim_pool`) modeli 034 migration ile bırakıldı:
/// `owner_id IS NULL` = claim edilebilir. UI bu yüzden artık world satırına
/// bakar, ayrı pool tablosuna değil. Eski `markAvailable` / `removeFromPool`
/// API'leri kaldırıldı.
class CharacterClaimService {
  final SupabaseClient client;
  CharacterClaimService(this.client);

  /// DM: karakteri direkt bir oyuncuya ata. world_characters.owner_id update.
  Future<void> assignToPlayer({
    required String characterId,
    required String userId,
  }) async {
    await client
        .from('world_characters')
        .update({'owner_id': userId})
        .eq('id', characterId);
  }

  /// Player: RPC ile claim et. Atomic — RPC `owner_id IS NULL` kilitler ve
  /// `auth.uid()`'a set eder.
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

  /// `world_characters` tüm satırlarını listeler (RLS gereği member olduğun
  /// world'leri görürsün). Bootstrap'te bir kez çağrılır; sonrasında CDC
  /// granular patch.
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
