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
      debugPrint('$label skipped: offline ($e)');
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

  /// charId → expiry timestamp (ms). Make Offline orphan online karakterleri
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

  // ── Granular world state (PR-SYNC-3) ───────────────────────────────
  //
  // worlds.state_json was a monolithic blob; map drag / session note edits
  // re-uploaded the whole world. These three tables carry the same content
  // in separate rows so each mutation only ships the part that changed.
  // Migration 042 created the tables; this PR's outbox handlers route
  // through these methods. DM dual-writes worlds.state_json for now —
  // PR-SYNC-6 retires the legacy path once players are on granular reads.


  // ── Initial fetch on subscribe ─────────────────────────────────────

  /// World'e abone olunduğunda lokal Drift'i seed'lemek için pull.
  /// Granular world tables (map_data/sessions/settings) eklendi (PR-SYNC-3).
  /// `worlds` satırı (state_json) + mindmap node/edge'leri cross-device boş-
  /// snapshot fix'inde eklendi: granular tablolarda yer almayan legacy
  /// alanları (battle_maps, mind_maps, metadata, …) ve dedicated mind_map
  /// tablolarındaki node/edge'leri Device B world open'ında tek seferde
  /// hydrate eder.
  /// Dünya açılışında tek seferlik seed — DM'in paylaşım kanalındaki her şey.
  ///
  /// Tam dünya aynası yok: entity/harita/oturum/ayar/mind-map tabloları
  /// kaldırıldı. Geriye kalan üçü, oyuncunun bağlandığında görmesi gereken
  /// birikmiş durum: paylaşılan kartlar, karakterler ve canlı yayın manifesti.
  /// CDC yalnızca bundan SONRAKİ değişimleri taşır, o yüzden bu seed şart.
  Future<
    ({
      List<Map<String, dynamic>> characters,
      List<Map<String, dynamic>> shares,
      Map<String, dynamic>? projection,
    })
  >
  fetchInitialState(String worldId) async {
    try {
      final charactersRaw = await client
          .from('world_characters')
          .select()
          .eq('world_id', worldId);
      final sharesRaw = await client
          .from('entity_shares')
          .select()
          .eq('world_id', worldId);
      final projectionRaw = await client
          .from('world_projection')
          .select()
          .eq('world_id', worldId)
          .maybeSingle();
      return (
        characters: (charactersRaw as List).cast<Map<String, dynamic>>(),
        shares: (sharesRaw as List).cast<Map<String, dynamic>>(),
        projection: projectionRaw,
      );
    } catch (e) {
      _logMirrorError('fetchInitialState', e);
      return (
        characters: const <Map<String, dynamic>>[],
        shares: const <Map<String, dynamic>>[],
        projection: null,
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

  // ── Personal (per-user) sync — packages ────────────────────────────
  //
  // Package key UUID değil string (paket adı). Entity UUID'leriyle
  // collision olmaması için echo stamp'i `pkg:<name>` prefix'i ile alırız.

  static String _packageEchoKey(String packageName) => 'pkg:$packageName';

  bool isEchoOfPackage(String packageName) =>
      _isEcho(_packageEchoKey(packageName));

  // F5 row-level: each personal-package entity has its own row in
  // `personal_package_entities`. The legacy bulk `publish_personal_package`
  // path still carries schema/metadata in `personal_packages.state_json`,
  // but entity-level mutations route here.

  static String _personalPkgEntityEchoKey(String packageName, String id) =>
      'ppe:$packageName:$id';

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
