import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_format.dart';
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

  /// Offline hatasını tek satır breadcrumb'a indirger; offline değilse mevcut
  /// tam hata logu basılır. Çağıran taraf `rethrow`'u kendi yapar (SyncEngine
  /// outbox retry'ı için hata yukarı çıkmalı).
  void _logMirrorError(String label, Object e) {
    if (isOfflineError(e)) {
      debugPrint('$label skipped: offline');
    } else {
      debugPrint('$label error: $e');
    }
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

  /// worldId → expiry timestamp (ms). "Make Offline" UI aksiyonu
  /// `unpublishWorld` çağrısından hemen önce buraya kaydeder. Bir worldId
  /// bu set'teyken CDC applier'ları o dünyanın `worlds`/`world_members`
  /// DELETE event'inde lokal purge/trash'i ATLAR — Make Offline tüm lokal
  /// Drift verisini korumalı. [_unpublishGuardMs] sonra kendiliğinden expire.
  final Map<String, int> _expectedUnpublish = {};
  static const int _unpublishGuardMs = 60000;

  /// DM-initiated unpublish'i [worldId] için kaydet.
  void registerExpectedUnpublish(String worldId) {
    _expectedUnpublish[worldId] =
        DateTime.now().millisecondsSinceEpoch + _unpublishGuardMs;
  }

  /// [worldId] için canlı bir "Make Offline" guard'ı var mı? Self-expiring.
  bool isExpectedUnpublish(String worldId) {
    final until = _expectedUnpublish[worldId];
    if (until == null) return false;
    if (DateTime.now().millisecondsSinceEpoch > until) {
      _expectedUnpublish.remove(worldId);
      return false;
    }
    return true;
  }

  /// Guard'ı erken temizle — unpublish CDC cleanup'ı çalıştıktan sonra
  /// ya da unpublish başarısız olduğunda çağrılır.
  void clearExpectedUnpublish(String worldId) =>
      _expectedUnpublish.remove(worldId);

  /// charId → expiry timestamp (ms). `leave_beta` orphan online karakterleri
  /// sunucudan silerken DM lokal kopyayı tutmak ister; bu set'teyken
  /// `applyCharacterCdc` DELETE event'inde lokal removeMirror/dropMirror
  /// çağrısı ATLANIR. [_unpublishGuardMs] sonra kendiliğinden expire.
  final Map<String, int> _expectedCharDelete = {};

  void registerExpectedCharDelete(String characterId) {
    _expectedCharDelete[characterId] =
        DateTime.now().millisecondsSinceEpoch + _unpublishGuardMs;
  }

  bool isExpectedCharDelete(String characterId) {
    final until = _expectedCharDelete[characterId];
    if (until == null) return false;
    if (DateTime.now().millisecondsSinceEpoch > until) {
      _expectedCharDelete.remove(characterId);
      return false;
    }
    return true;
  }

  void clearExpectedCharDelete(String characterId) =>
      _expectedCharDelete.remove(characterId);

  // ── Entities (DM-only writes) ──────────────────────────────────────

  /// Single-entity upsert. F4 retired the bulk `pushEntities` path —
  /// every entity edit flows through the outbox per-row.
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
      _logMirrorError('pushEntity', e);
      rethrow;
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
      _logMirrorError('deleteEntity', e);
      rethrow;
    }
  }

  Map<String, dynamic> _entityRow(
    String worldId,
    String entityId,
    Map<String, dynamic> m,
  ) {
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
      'package_id': m['package_id'] as String?,
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
      _logMirrorError('pushCharacter', e);
      rethrow;
    }
  }

  Future<void> deleteCharacter({required String characterId}) async {
    _stamp(characterId);
    try {
      await client.from('world_characters').delete().eq('id', characterId);
    } catch (e) {
      _logMirrorError('deleteCharacter', e);
      rethrow;
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
      await client.rpc(
        'publish_world',
        params: {
          'p_world_id': worldId,
          'p_world_name': worldName,
          'p_template_id': templateId,
          'p_template_hash': templateHash,
          'p_state_json': stateJson,
        },
      );
    } catch (e) {
      _logMirrorError('pushWorldState', e);
      rethrow;
    }
  }

  // ── Granular world state (PR-SYNC-3) ───────────────────────────────
  //
  // worlds.state_json was a monolithic blob; map drag / session note edits
  // re-uploaded the whole world. These three tables carry the same content
  // in separate rows so each mutation only ships the part that changed.
  // Migration 042 created the tables; this PR's outbox handlers route
  // through these methods. DM dual-writes worlds.state_json for now —
  // PR-SYNC-6 retires the legacy path once players are on granular reads.

  Future<void> pushMapData({
    required String worldId,
    required Map<String, dynamic> data,
  }) async {
    _stamp('mapdata:$worldId');
    try {
      await client.from('world_map_data').upsert({
        'world_id': worldId,
        'data_json': jsonEncode(data),
      });
    } catch (e) {
      _logMirrorError('pushMapData', e);
      rethrow;
    }
  }

  Future<void> pushSession({
    required String worldId,
    required String sessionId,
    required String name,
    required Map<String, dynamic> data,
    bool isActive = false,
    int sortOrder = 0,
  }) async {
    _stamp('session:$sessionId');
    try {
      await client.from('world_sessions').upsert({
        'id': sessionId,
        'world_id': worldId,
        'name': name,
        'data_json': jsonEncode(data),
        'is_active': isActive,
        'sort_order': sortOrder,
      });
    } catch (e) {
      _logMirrorError('pushSession', e);
      rethrow;
    }
  }

  Future<void> deleteSession({required String sessionId}) async {
    _stamp('session:$sessionId');
    try {
      await client.from('world_sessions').delete().eq('id', sessionId);
    } catch (e) {
      _logMirrorError('deleteSession', e);
      rethrow;
    }
  }

  Future<void> pushSettings({
    required String worldId,
    required Map<String, dynamic> settings,
  }) async {
    _stamp('settings:$worldId');
    try {
      await client.from('world_settings').upsert({
        'world_id': worldId,
        'settings_json': jsonEncode(settings),
      });
    } catch (e) {
      _logMirrorError('pushSettings', e);
      rethrow;
    }
  }

  bool isEchoOfMapData(String worldId) => _isEcho('mapdata:$worldId');
  bool isEchoOfSession(String sessionId) => _isEcho('session:$sessionId');
  bool isEchoOfSettings(String worldId) => _isEcho('settings:$worldId');

  // ── Initial fetch on subscribe ─────────────────────────────────────

  /// World'e abone olunduğunda lokal Drift'i seed'lemek için pull.
  /// Granular world tables (map_data/sessions/settings) eklendi (PR-SYNC-3).
  /// `worlds` satırı (state_json) + mindmap node/edge'leri cross-device boş-
  /// snapshot fix'inde eklendi: granular tablolarda yer almayan legacy
  /// alanları (battle_maps, mind_maps, metadata, …) ve dedicated mind_map
  /// tablolarındaki node/edge'leri Device B world open'ında tek seferde
  /// hydrate eder.
  Future<
    ({
      List<Map<String, dynamic>> entities,
      List<Map<String, dynamic>> characters,
      Map<String, dynamic>? mapData,
      List<Map<String, dynamic>> sessions,
      Map<String, dynamic>? settings,
      Map<String, dynamic>? worldRow,
      List<Map<String, dynamic>> mindMapNodes,
      List<Map<String, dynamic>> mindMapEdges,
    })
  >
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
      final mapDataRaw = await client
          .from('world_map_data')
          .select()
          .eq('world_id', worldId)
          .maybeSingle();
      final sessionsRaw = await client
          .from('world_sessions')
          .select()
          .eq('world_id', worldId);
      final settingsRaw = await client
          .from('world_settings')
          .select()
          .eq('world_id', worldId)
          .maybeSingle();
      final worldRowRaw = await client
          .from('worlds')
          .select('id, world_name, updated_at, state_json')
          .eq('id', worldId)
          .maybeSingle();
      final mindNodesRaw = await client
          .from('world_mind_map_nodes')
          .select()
          .eq('world_id', worldId);
      final mindEdgesRaw = await client
          .from('world_mind_map_edges')
          .select()
          .eq('world_id', worldId);
      final List<Map<String, dynamic>> entities = (entitiesRaw as List)
          .cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> characters = (charactersRaw as List)
          .cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> sessions = (sessionsRaw as List)
          .cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> mindNodes = (mindNodesRaw as List)
          .cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> mindEdges = (mindEdgesRaw as List)
          .cast<Map<String, dynamic>>();
      return (
        entities: entities,
        characters: characters,
        mapData: mapDataRaw,
        sessions: sessions,
        settings: settingsRaw,
        worldRow: worldRowRaw,
        mindMapNodes: mindNodes,
        mindMapEdges: mindEdges,
      );
    } catch (e) {
      _logMirrorError('fetchInitialState', e);
      return (
        entities: const <Map<String, dynamic>>[],
        characters: const <Map<String, dynamic>>[],
        mapData: null,
        sessions: const <Map<String, dynamic>>[],
        settings: null,
        worldRow: null,
        mindMapNodes: const <Map<String, dynamic>>[],
        mindMapEdges: const <Map<String, dynamic>>[],
      );
    }
  }

  /// Tek bir world_entities satırını çeker. entity_shares INSERT CDC'sinden
  /// sonra applier yeni paylaşılan entity'nin verisini buradan alır — paylaşım
  /// world_entities satırını değiştirmediği için o satır için CDC event'i
  /// çıkmaz. RLS: player bu satırı ancak paylaşım sonrası görebilir.
  Future<Map<String, dynamic>?> fetchEntity({
    required String worldId,
    required String entityId,
  }) async {
    try {
      return await client
          .from('world_entities')
          .select()
          .eq('id', entityId)
          .eq('world_id', worldId)
          .maybeSingle();
    } catch (e) {
      _logMirrorError('fetchEntity', e);
      return null;
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
      await client.rpc(
        'publish_personal_character',
        params: {
          'p_id': character.id,
          'p_payload_json': jsonEncode(character.toJson()),
        },
      );
    } catch (e) {
      _logMirrorError('pushPersonalCharacter', e);
    }
  }

  Future<void> unpublishPersonalCharacter(String characterId) async {
    _stamp(characterId);
    try {
      await client.rpc(
        'unpublish_personal_character',
        params: {'p_id': characterId},
      );
    } catch (e) {
      _logMirrorError('unpublishPersonalCharacter', e);
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
      await client.rpc(
        'publish_personal_package',
        params: {
          'p_package_name': packageName,
          'p_state_json': jsonEncode(state),
        },
      );
    } catch (e) {
      _logMirrorError('pushPersonalPackage', e);
      rethrow;
    }
  }

  Future<void> unpublishPersonalPackage(String packageName) async {
    _stamp(_packageEchoKey(packageName));
    try {
      await client.rpc(
        'unpublish_personal_package',
        params: {'p_package_name': packageName},
      );
    } catch (e) {
      _logMirrorError('unpublishPersonalPackage', e);
      rethrow;
    }
  }

  bool isEchoOfPackage(String packageName) =>
      _isEcho(_packageEchoKey(packageName));

  // F5 row-level: each personal-package entity has its own row in
  // `personal_package_entities`. The legacy bulk `publish_personal_package`
  // path still carries schema/metadata in `personal_packages.state_json`,
  // but entity-level mutations route here.

  static String _personalPkgEntityEchoKey(String packageName, String id) =>
      'ppe:$packageName:$id';

  Future<void> pushPersonalPackageEntity({
    required String packageName,
    required String entityId,
    required Map<String, dynamic> entityMap,
  }) async {
    _stamp(_personalPkgEntityEchoKey(packageName, entityId));
    try {
      await client.rpc(
        'publish_personal_package_entity',
        params: {
          'p_package_name': packageName,
          'p_entity_id': entityId,
          'p_payload_json': jsonEncode(entityMap),
        },
      );
    } catch (e) {
      _logMirrorError('pushPersonalPackageEntity', e);
      rethrow;
    }
  }

  Future<void> deletePersonalPackageEntity({
    required String packageName,
    required String entityId,
  }) async {
    _stamp(_personalPkgEntityEchoKey(packageName, entityId));
    try {
      await client.rpc(
        'delete_personal_package_entity',
        params: {
          'p_package_name': packageName,
          'p_entity_id': entityId,
        },
      );
    } catch (e) {
      _logMirrorError('deletePersonalPackageEntity', e);
      rethrow;
    }
  }

  bool isEchoOfPersonalPackageEntity(String packageName, String entityId) =>
      _isEcho(_personalPkgEntityEchoKey(packageName, entityId));

  // ── World packages (DM-shared per world) — PR-SYNC-5 ───────────────
  //
  // `share_package_to_world` RPC upserts by (world_id, package_name) and
  // returns the canonical package_id. Echo keyed by `wpkg:<id>` once the
  // RPC resolves so the inbound CDC for our own push gets suppressed.

  static String _worldPackageEchoKey(String packageId) => 'wpkg:$packageId';

  /// Returns the world-package id (server-assigned on first share).
  Future<String?> shareWorldPackage({
    required String worldId,
    required String packageName,
    required Map<String, dynamic> state,
  }) async {
    try {
      final id = await client.rpc(
        'share_package_to_world',
        params: {
          'p_world_id': worldId,
          'p_package_name': packageName,
          'p_state_json': jsonEncode(state),
        },
      ) as String?;
      if (id != null) _stamp(_worldPackageEchoKey(id));
      return id;
    } catch (e) {
      _logMirrorError('shareWorldPackage', e);
      rethrow;
    }
  }

  Future<void> unshareWorldPackage({required String packageId}) async {
    _stamp(_worldPackageEchoKey(packageId));
    try {
      await client.rpc(
        'unshare_world_package',
        params: {'p_package_id': packageId},
      );
    } catch (e) {
      _logMirrorError('unshareWorldPackage', e);
      rethrow;
    }
  }

  bool isEchoOfWorldPackage(String packageId) =>
      _isEcho(_worldPackageEchoKey(packageId));
}
