import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/online/entity_share.dart';

/// public.entity_shares CRUD. RLS DM yetkisi enforces.
///
/// Bulut sync kaldırıldıktan sonra bu tablo yalnızca bir görünürlük işareti
/// değil, **kartın kendisini taşıyan kanal**. `world_entities` aynası artık
/// yok; oyuncu paylaşılan kartın içeriğini `payload_json`'dan alır. Payload
/// yazmadan paylaşmak, oyuncuda boş kart demektir.
class EntityShareService {
  final SupabaseClient client;
  EntityShareService(this.client);

  Future<List<EntityShare>> listForWorld(String worldId) async {
    final rows = await client
        .from('entity_shares')
        .select()
        .eq('world_id', worldId);
    return (rows as List)
        .map((r) => EntityShare.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// World-wide share (shared_with NULL). Aynı entity için tekrar idempotent.
  ///
  /// [payload] paylaşılan entity'nin tam JSON'u — oyuncu tarafındaki tek
  /// içerik kaynağı. Görselleri `AssetRef`'e çevrilmiş olmalı (bkz.
  /// `entity_share_prepare.dart`), aksi halde oyuncu çözemez.
  Future<void> shareWithAll({
    required String entityId,
    required String worldId,
    Map<String, dynamic>? payload,
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
      'payload_json': payload == null ? null : jsonEncode(payload),
    });
  }

  /// Toplu world-wide paylaşım — publish tohumu için.
  ///
  /// Tek tek [shareWithAll] çağırmak kart başına İKİ round trip demek; birkaç
  /// yüz homebrew kartlı bir dünyada publish dakikalarca sürüyordu. Burada
  /// silme tek sorguya, insert 50'lik parçalara iner.
  ///
  /// Bir parça toptan düşerse (512KB/kart CHECK'i ya da 4000 satır tavanı —
  /// migration 088) o parça satır satır tekrar denenir, böylece tek bozuk
  /// kart geri kalanını götürmez. Dönen değer: yazılamayan kart id'leri.
  Future<List<String>> shareManyWithAll({
    required String worldId,
    required Map<String, Map<String, dynamic>?> payloads,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('auth required');
    if (payloads.isEmpty) return const [];

    final ids = payloads.keys.toList(growable: false);
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
          'payload_json': payloads[id] == null
              ? null
              : jsonEncode(payloads[id]),
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
    Map<String, dynamic>? payload,
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
      'payload_json': payload == null ? null : jsonEncode(payload),
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
