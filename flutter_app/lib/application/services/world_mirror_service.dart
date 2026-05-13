import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/character.dart';
import 'world_sync_service.dart';

/// Lokal yazıları Supabase mirror tablolarına push eder ve CDC event'lerinden
/// gelen değişimleri local state'e uygulamak için yardımcılar sunar.
///
/// **Önemli kararlar:**
/// - DM client world_entities + world_characters'a yazar. Player kendi
///   karakteri için yazar (RLS izin verir).
/// - Inbound CDC event'i apply etmeden önce "kendi-yazımıydı?" kontrolü
///   yapılır — son N saniyede aynı id'ye push ettiysek skip ederiz; aksi
///   halde write → broadcast → re-apply döngüsü oluşur ve user input'u
///   override edebilir.
/// - Push best-effort; offline veya RLS başarısızlığında sessizce skip.
class WorldMirrorService {
  final SupabaseClient client;
  WorldMirrorService(this.client);

  /// id → son push timestamp. Inbound event suppression için.
  /// TTL: [_pushSuppressionMs].
  final Map<String, int> _lastPushedAt = {};
  static const int _pushSuppressionMs = 3000;

  void _stamp(String id) {
    _lastPushedAt[id] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Inbound event'in kendi push'umuzdan kaynaklanıp kaynaklanmadığını
  /// belirler. true → apply etme (echo).
  bool _isEcho(String id) {
    final at = _lastPushedAt[id];
    if (at == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    if (age > _pushSuppressionMs) {
      _lastPushedAt.remove(id);
      return false;
    }
    return true;
  }

  // ── Entities (DM-only writes) ──────────────────────────────────────

  /// Lokal `data['entities']` blob'undan world_entities'e bulk upsert.
  /// updated_at trigger ile idempotent. Deletion EntityNotifier.delete →
  /// [deleteEntity] üzerinden ayrı path'te yapılır; bu push sadece upsert.
  Future<void> pushEntities({
    required String worldId,
    required Map<String, dynamic> entitiesBlob,
  }) async {
    if (entitiesBlob.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (final entry in entitiesBlob.entries) {
      final m = entry.value;
      if (m is! Map) continue;
      rows.add(_entityRow(worldId, entry.key, Map<String, dynamic>.from(m)));
      _stamp(entry.key);
    }
    if (rows.isEmpty) return;
    try {
      await client.from('world_entities').upsert(rows);
    } catch (e, st) {
      debugPrint('pushEntities upsert error: $e\n$st');
    }
  }

  /// Single-entity upsert (notifier hook için, debouncing dışarıda).
  Future<void> pushEntity({
    required String worldId,
    required String entityId,
    required Map<String, dynamic> entityMap,
  }) async {
    _stamp(entityId);
    try {
      await client
          .from('world_entities')
          .upsert(_entityRow(worldId, entityId, entityMap));
    } catch (e) {
      debugPrint('pushEntity error: $e');
    }
  }

  Future<void> deleteEntity({
    required String worldId,
    required String entityId,
  }) async {
    _stamp(entityId);
    try {
      await client.from('world_entities').delete().eq('id', entityId);
    } catch (e) {
      debugPrint('deleteEntity error: $e');
    }
  }

  Map<String, dynamic> _entityRow(
      String worldId, String entityId, Map<String, dynamic> m) {
    return {
      'id': entityId,
      'world_id': worldId,
      'category_slug': _categoryFor(m),
      'name': (m['name'] as String?) ?? 'Unknown',
      'source': (m['source'] as String?) ?? '',
      'description': (m['description'] as String?) ?? '',
      'image_path': (m['image_path'] as String?) ?? '',
      'images_json': jsonEncode(m['images'] ?? const []),
      'tags_json': jsonEncode(m['tags'] ?? const []),
      'dm_notes': (m['dm_notes'] as String?) ?? '',
      'pdfs_json': jsonEncode(m['pdfs'] ?? const []),
      'location_id': m['location_id'],
      'fields_json': jsonEncode(m['attributes'] ?? m['fields'] ?? const {}),
      'package_id': m['package_id'],
      'package_entity_id': m['package_entity_id'],
      'linked': (m['linked'] as bool?) ?? false,
    };
  }

  String _categoryFor(Map<String, dynamic> m) {
    final t = (m['type'] as String?) ?? (m['categorySlug'] as String?);
    if (t == null) return 'npc';
    return t.toLowerCase().replaceAll(' ', '-');
  }

  // ── Characters (DM full + player own) ──────────────────────────────

  Future<void> pushCharacter({
    required String worldId,
    required Character character,
    required Set<String> referencedEntityIds,
  }) async {
    _stamp(character.id);
    try {
      await client.from('world_characters').upsert({
        'id': character.id,
        'world_id': worldId,
        'owner_id': character.ownerId,
        'template_id': character.templateId,
        'template_name': character.templateName,
        'payload_json': jsonEncode(character.toJson()),
        'referenced_entity_ids': referencedEntityIds.toList(),
      });
    } catch (e) {
      debugPrint('pushCharacter error: $e');
    }
  }

  Future<void> deleteCharacter({required String characterId}) async {
    _stamp(characterId);
    try {
      await client.from('world_characters').delete().eq('id', characterId);
    } catch (e) {
      debugPrint('deleteCharacter error: $e');
    }
  }

  // ── World state (campaign blob) ────────────────────────────────────

  /// state_json yalnızca DM yazar. Player için RLS engeller.
  Future<void> pushWorldState({
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required String stateJson,
  }) async {
    _stamp(worldId);
    // publish_world RPC (SECURITY DEFINER, row_security off) upsert eder ve
    // owner_id'yi auth.uid()'den çeker — UPSERT/RLS gürültüsünü engeller.
    try {
      await client.rpc('publish_world', params: {
        'p_world_id': worldId,
        'p_world_name': worldName,
        'p_template_id': templateId,
        'p_template_hash': templateHash,
        'p_state_json': stateJson,
      });
    } catch (e) {
      debugPrint('pushWorldState error: $e');
    }
  }

  // ── Initial fetch on subscribe ─────────────────────────────────────

  /// World'e abone olunduğunda lokal Drift'i seed'lemek için pull.
  Future<({List<Map<String, dynamic>> entities, List<Map<String, dynamic>> characters})>
      fetchInitialState(String worldId) async {
    try {
      final entitiesRaw = await client
          .from('world_entities')
          .select()
          .eq('world_id', worldId);
      final charactersRaw = await client
          .from('world_characters')
          .select()
          .eq('world_id', worldId);
      final List<Map<String, dynamic>> entities =
          (entitiesRaw as List).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> characters =
          (charactersRaw as List).cast<Map<String, dynamic>>();
      return (entities: entities, characters: characters);
    } catch (e) {
      debugPrint('fetchInitialState error: $e');
      return (
        entities: const <Map<String, dynamic>>[],
        characters: const <Map<String, dynamic>>[],
      );
    }
  }

  // ── Inbound CDC event echo check ───────────────────────────────────

  /// CDC event'i apply etmeden önce kendi push'umuzla çakışıp çakışmadığını
  /// söyler. Yalnızca son N saniye içinde tahmin edilebilir; sonraki event
  /// network jitter ile gecikirse ekstradan bir reapply olabilir — büyük
  /// problem değil çünkü last-writer-wins ile content idempotent.
  bool isEchoOf(WorldSyncEvent event) {
    final id = (event.newRecord['id'] ?? event.oldRecord['id']) as String?;
    if (id == null) return false;
    return _isEcho(id);
  }

  /// Personal sync applier'ından çağrılır. Aynı `_lastPushedAt` map'i
  /// paylaşırız böylece push → CDC → echo döngüsü filtrelenir.
  bool isEchoOfId(String id) => _isEcho(id);

  // ── Personal (per-user) sync — characters ──────────────────────────

  Future<void> pushPersonalCharacter(Character character) async {
    _stamp(character.id);
    try {
      await client.rpc('publish_personal_character', params: {
        'p_id': character.id,
        'p_payload_json': jsonEncode(character.toJson()),
      });
    } catch (e) {
      debugPrint('pushPersonalCharacter error: $e');
    }
  }

  Future<void> unpublishPersonalCharacter(String characterId) async {
    _stamp(characterId);
    try {
      await client.rpc('unpublish_personal_character', params: {
        'p_id': characterId,
      });
    } catch (e) {
      debugPrint('unpublishPersonalCharacter error: $e');
    }
  }

  // ── Personal (per-user) sync — packages ────────────────────────────
  //
  // Package key UUID değil string (paket adı). Entity UUID'leriyle
  // collision olmaması için echo stamp'i `pkg:<name>` prefix'i ile alırız.

  static String _packageEchoKey(String packageName) => 'pkg:$packageName';

  Future<void> pushPersonalPackage({
    required String packageName,
    required Map<String, dynamic> state,
  }) async {
    _stamp(_packageEchoKey(packageName));
    try {
      await client.rpc('publish_personal_package', params: {
        'p_package_name': packageName,
        'p_state_json': jsonEncode(state),
      });
    } catch (e) {
      debugPrint('pushPersonalPackage error: $e');
    }
  }

  Future<void> unpublishPersonalPackage(String packageName) async {
    _stamp(_packageEchoKey(packageName));
    try {
      await client.rpc('unpublish_personal_package', params: {
        'p_package_name': packageName,
      });
    } catch (e) {
      debugPrint('unpublishPersonalPackage error: $e');
    }
  }

  bool isEchoOfPackage(String packageName) =>
      _isEcho(_packageEchoKey(packageName));
}
