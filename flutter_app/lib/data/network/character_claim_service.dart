import 'package:supabase_flutter/supabase_flutter.dart';

/// public.character_claim_pool + claim_character RPC için thin transport.
class CharacterClaimService {
  final SupabaseClient client;
  CharacterClaimService(this.client);

  /// DM: karakteri claim havuzuna ekle (available=true).
  Future<void> markAvailable({
    required String characterId,
    required String worldId,
  }) async {
    await client.from('character_claim_pool').upsert({
      'character_id': characterId,
      'world_id': worldId,
      'available': true,
      'claimed_by': null,
      'claimed_at': null,
    });
  }

  /// DM: karakteri claim havuzundan çıkar.
  Future<void> removeFromPool(String characterId) async {
    await client
        .from('character_claim_pool')
        .delete()
        .eq('character_id', characterId);
  }

  /// DM: karakteri direkt bir oyuncuya ata. world_characters.owner_id update.
  Future<void> assignToPlayer({
    required String characterId,
    required String userId,
  }) async {
    await client
        .from('world_characters')
        .update({'owner_id': userId})
        .eq('id', characterId);
    // Bu kullanıcıya atandığı için pool'dan da çıkar (varsa).
    await removeFromPool(characterId);
  }

  /// Player: RPC ile claim et. Atomic — owner_id ve pool.available aynı
  /// transaction'da set edilir.
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

  /// Pool listesi (member görür).
  Future<List<ClaimPoolRow>> listAvailable(String worldId) async {
    final rows = await client
        .from('character_claim_pool')
        .select('character_id, world_id, available, claimed_by, claimed_at, '
            'world_characters:character_id(payload_json, template_name)')
        .eq('world_id', worldId)
        .eq('available', true);
    final out = <ClaimPoolRow>[];
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final wc = m['world_characters'] as Map<String, dynamic>?;
      out.add(ClaimPoolRow(
        characterId: m['character_id'] as String,
        worldId: m['world_id'] as String,
        templateName: wc?['template_name'] as String? ?? '',
        payloadJson: wc?['payload_json'] as String? ?? '{}',
      ));
    }
    return out;
  }
}

/// Pool listesi için lightweight projection.
class ClaimPoolRow {
  final String characterId;
  final String worldId;
  final String templateName;
  final String payloadJson;

  const ClaimPoolRow({
    required this.characterId,
    required this.worldId,
    required this.templateName,
    required this.payloadJson,
  });
}
