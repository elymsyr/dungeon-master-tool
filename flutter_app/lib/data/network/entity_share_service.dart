import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/online/entity_share.dart';

/// public.entity_shares CRUD. RLS DM yetkisi enforces.
///
/// Tablo yalnız izin: "bu dünyanın üyeleri bu kartı okuyabilir" (§2.5).
/// Gövde DM'in bulut aynasında; oyuncu onu `get_shared_entities`'ten alır
/// (Faz 5.5b). Kart kopyası taşıyan `payload_json` 103'te düştü.
class EntityShareService {
  final SupabaseClient client;
  EntityShareService(this.client);

  Future<List<EntityShare>> listForWorld(String worldId) async {
    final rows = await client
        .from('entity_shares')
        .select('entity_id, world_id, shared_with, shared_by, shared_at')
        .eq('world_id', worldId);
    return (rows as List)
        .map((r) => EntityShare.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// World-wide share (shared_with NULL). Aynı entity için tekrar idempotent.
  Future<void> shareWithAll({
    required String entityId,
    required String worldId,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('auth required');
    // Önce mevcut world-wide kaydı temizle (re-share idempotent).
    await client
        .from('entity_shares')
        .delete()
        .eq('entity_id', entityId)
        .eq('world_id', worldId)
        .filter('shared_with', 'is', null);
    await client.from('entity_shares').insert({
      'entity_id': entityId,
      'world_id': worldId,
      'shared_with': null,
      'shared_by': uid,
    });
  }

  /// Toplu world-wide paylaşım — publish tohumu için.
  ///
  /// Tek tek [shareWithAll] çağırmak kart başına İKİ round trip demek; birkaç
  /// yüz homebrew kartlı bir dünyada publish dakikalarca sürüyordu. Burada
  /// silme tek sorguya, insert 50'lik parçalara iner.
  ///
  /// Bir parça toptan düşerse (4000 satır tavanı — migration 088) o parça
  /// satır satır tekrar denenir, böylece tek bozuk satır geri kalanını
  /// götürmez. Dönen değer: yazılamayan kart id'leri.
  Future<List<String>> shareManyWithAll({
    required String worldId,
    required Iterable<String> entityIds,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('auth required');
    final ids = entityIds.toList(growable: false);
    if (ids.isEmpty) return const [];

    for (var i = 0; i < ids.length; i += 200) {
      await client
          .from('entity_shares')
          .delete()
          .eq('world_id', worldId)
          .inFilter('entity_id', ids.sublist(i, min(i + 200, ids.length)))
          .filter('shared_with', 'is', null);
    }

    Map<String, dynamic> row(String id) => {
          'entity_id': id,
          'world_id': worldId,
          'shared_with': null,
          'shared_by': uid,
        };

    final failed = <String>[];
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, min(i + 50, ids.length));
      try {
        await client.from('entity_shares').insert(chunk.map(row).toList());
      } catch (_) {
        for (final id in chunk) {
          try {
            await client.from('entity_shares').insert(row(id));
          } catch (_) {
            failed.add(id);
          }
        }
      }
    }
    return failed;
  }

  Future<void> shareWithUser({
    required String entityId,
    required String worldId,
    required String userId,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('auth required');
    // Mevcut kaydı temizle, sonra ekle (atomic re-insert).
    await client
        .from('entity_shares')
        .delete()
        .eq('entity_id', entityId)
        .eq('world_id', worldId)
        .eq('shared_with', userId);
    await client.from('entity_shares').insert({
      'entity_id': entityId,
      'world_id': worldId,
      'shared_with': userId,
      'shared_by': uid,
    });
  }

  /// World-wide unshare.
  Future<void> unshareAll({
    required String entityId,
    required String worldId,
  }) async {
    await client
        .from('entity_shares')
        .delete()
        .eq('entity_id', entityId)
        .eq('world_id', worldId)
        .filter('shared_with', 'is', null);
  }

  Future<void> unshareUser({
    required String entityId,
    required String worldId,
    required String userId,
  }) async {
    await client
        .from('entity_shares')
        .delete()
        .eq('entity_id', entityId)
        .eq('world_id', worldId)
        .eq('shared_with', userId);
  }
}
