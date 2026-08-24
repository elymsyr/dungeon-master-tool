import 'dart:convert';

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
