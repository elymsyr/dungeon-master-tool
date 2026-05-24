import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/character.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/projection/projection_state.dart';
import '../providers/auth_provider.dart';
import '../providers/online_projection_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/character_provider.dart';
import '../providers/entity_share_provider.dart';
import '../providers/world_characters_provider.dart';
import '../providers/package_provider.dart';
import '../providers/world_membership_provider.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/app_database.dart' hide WorldCharacterRow;
import 'eviction_sweeper.dart';
import 'fetch_queue.dart';
import 'reference_indexer.dart';
import '../../data/database/util/builtin_synth.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package_import_service.dart';
import 'package_sync_service.dart';
import 'pending_write_buffer.dart';
import 'world_mirror_service.dart';
import 'world_sync_service.dart';

dynamic _decodeJsonStatic(String s) => jsonDecode(s);

const int _kDecodeOffloadBytes = 4096;
Future<dynamic> _decodeJsonMaybeOffload(String s) {
  if (s.length < _kDecodeOffloadBytes) {
    return Future.value(jsonDecode(s));
  }
  return compute(_decodeJsonStatic, s);
}

/// CDC event batch penceresi (R1). 1 frame — algılanabilir gecikme yok;
/// profil sonrası 33-50ms'e çıkarılabilir.
const Duration _kBatchWindow = Duration(milliseconds: 16);

/// Bir online world için `applyInitialState` en az bir kez tamamlandı mı —
/// içerik bulundu mu bulunmadı mı ayrı, sadece "cloud snapshot alındı"
/// sinyali. Cross-device open'da auto-create-encounter (session_screen
/// postFrame) ya da mind-map deactivate gibi yollar boş local state'i
/// bulut'a yazıp tüm cihazlara yaymasın diye write-path'leri bu sinyale
/// kadar bekletir.
///
/// İlk world open'da set boştur → combat _loaded false → auto-create bail.
/// applyInitialState bitince set'e worldId eklenir → revision bump'ında
/// combatProvider rebuild → _loaded true. Sticky: aynı session içinde
/// reopen'larda yeniden ödenmeye gerek yok.
final worldInitialSyncSettledProvider =
    StateProvider<Set<String>>((_) => const <String>{});

/// `world_settings.settings_json` decode edilip top-level `data`'ya yayılırken
/// atlanan anahtarlar. Identity / template alanları + granular tablo sahipleri
/// (`entities`, `sessions`, `map_data`): `world_settings` legacy mirror olarak
/// bu alanları taşıyabilir ama dedicated row/table source-of-truth.
/// `_world_schema`: yerelde repo katmanı `world_schema`'ya çeviriyor;
/// snapshot'ı top-level'a koymak yanıltıcı olur.
const Set<String> _settingsApplyBlocklist = {
  'world_id',
  'world_name',
  'created_at',
  'entities',
  'sessions',
  'map_data',
  'world_schema',
  'template_id',
  'template_hash',
  'template_original_hash',
  '_world_schema',
};

/// CDC event'lerini local state'e uygular.
///
/// Sorumluluk:
///   - world_entities event → active campaign data['entities'] patch
///   - world_characters event → characterListProvider invalidate
///   - worlds event → campaign state_json reload
///
/// Self-echo (kendi push'umuzun event'i) `WorldMirrorService.isEchoOf`
/// ile filtrelenir.
class WorldMirrorApplier {
  final Ref ref;
  final WorldMirrorService mirror;
  final WorldSyncService sync;

  StreamSubscription<WorldSyncEvent>? _sub;

  /// Provider rebuild/dispose sonrası `ref` geçersiz — `stop()`'ta set edilir,
  /// in-flight async event'ler stale ref kullanmadan bail eder.
  bool _disposed = false;

  /// CDC event batcher (R1) — gelen event'leri kısa pencerede toplar,
  /// pencere sonunda tek `_bumpRevision()` ile rebuild fırtınasını önler.
  late final _EventBatcher _batcher;

  /// Flush sırasında `true` — `_bumpRevision()` çağrıları bastırılır,
  /// pencere sonunda tek `_doBumpRevision()` atılır.
  bool _suppressRevisionBump = false;

  /// Flush penceresinde gerçek bir bump talebi oldu mu (echo/pending guard
  /// ile atlanan event'lerde boşa bump atılmasın).
  bool _revisionDirty = false;

  /// Captured at construction (host provider building → `ref` clean). The
  /// notifier is owned by the stable `activeCampaignProvider`, so it stays
  /// valid for world-removal work even after this applier's host is torn
  /// down by a role-cache invalidation.
  late final ActiveCampaignNotifier _campaign;

  WorldMirrorApplier({
    required this.ref,
    required this.mirror,
    required this.sync,
  }) {
    _campaign = ref.read(activeCampaignProvider.notifier);
    _batcher = _EventBatcher(window: _kBatchWindow, onFlush: _flushBatch);
  }

  PendingWriteBuffer get _buffer => ref.read(pendingWriteBufferProvider);

  void start() {
    _sub ??= sync.events.listen(_batcher.add);
  }

  Future<void> stop() async {
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    _batcher.dispose();
  }

  /// Batcher penceresi dolunca çağrılır — batch'i SIRALI uygular (paylaşılan
  /// `data` Map; paralel akış bozar), revision bump'larını bastırır, pencere
  /// sonunda tek `_doBumpRevision()` atar.
  Future<void> _flushBatch(List<WorldSyncEvent> batch) async {
    if (_disposed) return;
    _suppressRevisionBump = true;
    _revisionDirty = false;
    try {
      for (final e in batch) {
        if (_disposed) return;
        await _onEvent(e);
      }
    } finally {
      _suppressRevisionBump = false;
    }
    if (_revisionDirty && !_disposed) _doBumpRevision();
  }

  /// Subscribe sonrası remote state'i local'a seed eder. Update event'i
  /// gibi davranır — fakat liste olarak gelir, tek transaction'da uygular.
  Future<void> applyInitialState(String worldId) async {
    if (_disposed) return;
    // entity_shares CDC kesinti sırasında replay edilmez; offline/world-closed
    // sırasında yapılan paylaşımlar shares cache'ine düşmez. Catch-up'ta
    // (reconnect / world re-entry / manuel sync) shares'i taze çek — aksi halde
    // visibleEntityProvider stale liste ile filtreler, kart açılmaz.
    ref.invalidate(worldEntitySharesProvider(worldId));
    final snapshot = await mirror.fetchInitialState(worldId);
    if (_disposed) return;
    // Cross-device açılışta entities/characters cloud'da olmayabilir ama
    // mapData/sessions/settings dolu olabilir. Beşi de boşsa bail et,
    // herhangi biri varsa devam — yoksa session/map/mind-map sekmeleri
    // boş kalır. Erken çıkışta da settled marker set edilir ki cloud
    // gerçekten boş olan world'lerde combat/mind-map write path'leri
    // bloklanmasın.
    if (snapshot.entities.isEmpty &&
        snapshot.characters.isEmpty &&
        snapshot.mapData == null &&
        snapshot.sessions.isEmpty &&
        snapshot.settings == null) {
      _markInitialSyncSettled(worldId);
      _bumpRevision();
      return;
    }

    final activeCampaign = ref.read(activeCampaignProvider.notifier);
    final data = activeCampaign.data;
    if (data == null) return;

    if (snapshot.entities.isNotEmpty) {
      final raw = data['entities'];
      final Map<String, dynamic> entities;
      if (raw is Map<String, dynamic>) {
        entities = raw;
      } else {
        entities = <String, dynamic>{};
        data['entities'] = entities;
      }
      for (final row in snapshot.entities) {
        final id = row['id'] as String?;
        if (id == null) continue;
        entities[id] = _entityRowToBlob(row);
      }
    }

    if (snapshot.characters.isNotEmpty) {
      final notifier =
          ref.read(worldCharactersProvider(worldId).notifier);
      for (final row in snapshot.characters) {
        final mapped = _charRowFromCdc(row, fallbackWorldId: worldId);
        if (mapped != null) notifier.applyMirror(mapped);
      }
    }
    // PR-SYNC-3: seed granular world state into the active campaign blob.
    if (snapshot.mapData != null) {
      await _applyMapDataRow(snapshot.mapData!);
    }
    if (snapshot.sessions.isNotEmpty) {
      await _applySessionsList(snapshot.sessions);
    }
    if (snapshot.settings != null) {
      await _applySettingsRow(snapshot.settings!, worldId: worldId);
    }
    // Bütün granular row'lar uygulandı — write path'leri serbest bırak.
    // Settled bayrağı zaten set ise no-op.
    _markInitialSyncSettled(worldId);
    _bumpRevision();
  }

  /// `worldInitialSyncSettledProvider`'a worldId ekler. Sticky — aynı session
  /// içinde tekrar settle gerekli değil. Ref geçersizse sessizce atla
  /// (provider scope tear-down).
  void _markInitialSyncSettled(String worldId) {
    if (_disposed) return;
    try {
      final n = ref.read(worldInitialSyncSettledProvider.notifier);
      if (n.state.contains(worldId)) return;
      n.state = {...n.state, worldId};
    } catch (_) {
      // ref dependency-change penceresinde stale — bir sonraki retry toparlar.
    }
  }

  Future<void> _onEvent(WorldSyncEvent e) async {
    if (_disposed) return;
    if (mirror.isEchoOf(e)) return;
    try {
      switch (e.table) {
        case 'world_entities':
          _applyEntityEvent(e);
        case 'world_characters':
          await _applyCharacterEvent(e);
        case 'worlds':
          await _applyWorldsEvent(e);
        case 'entity_shares':
          await _applyEntityShareEvent(e);
        case 'world_members':
          await _applyMembersEvent(e);
        case 'world_map_data':
          await _applyMapDataEvent(e);
        case 'world_sessions':
          await _applySessionEvent(e);
        case 'world_settings':
          await _applySettingsEvent(e);
        case 'world_packages':
          await _applyWorldPackageEvent(e);
        case 'world_projection':
          _applyProjectionEvent(e);
        // mind_map_*: PR-O8'de dedicated invalidations.
      }
    } catch (err, st) {
      debugPrint('WorldMirrorApplier error: $err\n$st');
    }
  }

  void _applyEntityEvent(WorldSyncEvent e) {
    final activeCampaign = ref.read(activeCampaignProvider.notifier);
    final data = activeCampaign.data;
    if (data == null) return;

    final raw = data['entities'];
    final Map<String, dynamic> entities;
    if (raw is Map<String, dynamic>) {
      entities = raw;
    } else {
      entities = <String, dynamic>{};
      data['entities'] = entities;
    }

    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        final id = e.oldRecord['id'] as String?;
        if (id == null) return;
        // CDC race guard: local pending edit varken remote DELETE'i de
        // uygulama — kullanıcı yazıyor, trailing fire upsert atacak.
        if (_buffer.isPending('entity:${e.worldId}:$id')) return;
        if (entities.remove(id) != null) {
          _bumpRevision();
        }
        // F3: ref graf temizliği (player tarafı dahil)
        ref
            .read(referenceIndexerProvider)
            .scheduleRemove('world_entities', id);
        // F10: orphan local cache temizliği — debounced 30s. DM cloud silmesini
        // burada DENEMEZ; cloud objesi zaten DM tarafında EntityMediaCleanup
        // ile temizlenmiş (RLS player'da delete'i zaten reddeder).
        ref.read(evictionSweeperProvider).requestSweep();
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final id = e.newRecord['id'] as String?;
        if (id == null) return;
        if (_buffer.isPending('entity:${e.worldId}:$id')) return;
        final blob = _entityRowToBlob(e.newRecord);
        entities[id] = blob;
        _bumpRevision();
        ref.read(referenceIndexerProvider).scheduleReindex(
              table: 'world_entities',
              id: id,
              json: blob,
              worldId: e.worldId,
            );
        // F5: CDC pre-fetcher — UI açılana kadar AssetRef'leri arka planda indir.
        final refs = ReferenceIndexer.extractRefs(blob);
        if (refs.isNotEmpty) {
          ref.read(fetchQueueProvider).scheduleAll(refs);
        }
      default:
        return;
    }
  }

  /// entity_shares CDC event. Shares listesini invalidate eder; INSERT/UPDATE
  /// için yeni paylaşılan entity'nin verisi player'da olmayabilir (RLS önceden
  /// gizliyordu, world_entities satırı değişmediği için CDC çıkmaz) — açıkça
  /// fetch edip local blob'a enjekte eder.
  Future<void> _applyEntityShareEvent(WorldSyncEvent e) async {
    ref.invalidate(worldEntitySharesProvider(e.worldId));
    if (e.eventType != PostgresChangeEvent.insert &&
        e.eventType != PostgresChangeEvent.update) {
      // DELETE: visibleEntityProvider filtresi kartı zaten gizler.
      return;
    }
    final entityId = e.newRecord['entity_id'] as String?;
    if (entityId == null) return;
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final raw = data['entities'];
    final Map<String, dynamic> entities;
    if (raw is Map<String, dynamic>) {
      entities = raw;
    } else {
      entities = <String, dynamic>{};
      data['entities'] = entities;
    }
    if (entities.containsKey(entityId)) return; // veri zaten var (DM dahil)
    final row =
        await mirror.fetchEntity(worldId: e.worldId, entityId: entityId);
    if (_disposed || row == null) return;
    entities[entityId] = _entityRowToBlob(row);
    _bumpRevision();
  }

  Future<void> _applyCharacterEvent(WorldSyncEvent e) => applyCharacterCdc(
        eventType: e.eventType,
        newRecord: e.newRecord,
        oldRecord: e.oldRecord,
        channelWorldId: e.worldId,
      );

  /// Karakter CDC event'ini local state'e uygular. Hem world channel
  /// (`world_sync_service`) hem per-user channel (`personal_sync_service`)
  /// tarafından kullanılır — char tab'dan (aktif dünya yokken) düzenleme de
  /// canlı sync olsun diye. [channelWorldId] world channel'da kanalın dünya
  /// id'si; per-user channel'da `null` geçilir, dünya id'si satırdan okunur.
  Future<void> applyCharacterCdc({
    required PostgresChangeEvent eventType,
    required Map<String, dynamic> newRecord,
    required Map<String, dynamic> oldRecord,
    String? channelWorldId,
  }) async {
    if (_disposed) return;
    switch (eventType) {
      case PostgresChangeEvent.delete:
        final id = oldRecord['id'] as String?;
        if (id == null) return;
        // CDC race guard: local pending edit varken remote uygulanmaz.
        if (_buffer.isPending('character:$id')) return;
        final wid = (oldRecord['world_id'] as String?) ?? channelWorldId;
        // leave_beta / Make Offline: parent world unpublish guard'ında veya
        // orphan char delete guard'ında ise lokal kopyayı koru.
        if ((wid != null && mirror.isExpectedUnpublish(wid)) ||
            mirror.isExpectedCharDelete(id)) {
          return;
        }
        if (wid != null) {
          ref.read(worldCharactersProvider(wid).notifier).removeMirror(id);
        }
        // 039 model: DELETE = canonical row gone. Hub-level local Character
        // da silinmeli (cross-device DELETE echo).
        // ignore: discarded_futures
        ref.read(characterListProvider.notifier).removeMirror(id);
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final id = newRecord['id'] as String?;
        if (id == null) return;
        if (_buffer.isPending('character:$id')) return;
        final newWorldId = newRecord['world_id'] as String?;
        final newOwnerId = newRecord['owner_id'] as String?;
        if (newWorldId == null) {
          // remove_from_world UPDATE: row dünya'dan koptu, orphan'a düştü.
          // Bu world view'dan çıkar; eğer ben owner'ım hub-level char'ı
          // worldId=null patch et.
          if (channelWorldId != null) {
            ref
                .read(worldCharactersProvider(channelWorldId).notifier)
                .removeMirror(id);
          }
          final selfUid = ref.read(authProvider)?.uid;
          if (selfUid != null && newOwnerId == selfUid) {
            final list = ref.read(characterListProvider).valueOrNull ??
                const [];
            final c = list.where((x) => x.id == id).firstOrNull;
            if (c != null) {
              // ignore: discarded_futures
              ref.read(characterListProvider.notifier).applyMirror(
                    c.copyWith(worldId: null),
                  );
            }
          }
          return;
        }
        // Unchanged-TOAST guard: claim/release/assign gibi metadata-only
        // UPDATE'lerde Postgres `payload_json`'u (büyük TOAST kolonu) WAL'a
        // koymaz → CDC newRecord'da null gelir. Mevcut satırın payload'unu
        // fallback al, aksi halde `{}` decode patlar (isim paket adına düşer).
        final fallbackPayload = _resolveFallbackPayload(newWorldId, id);
        final row = _charRowFromCdc(
          newRecord,
          fallbackWorldId: newWorldId,
          fallbackPayloadJson: fallbackPayload,
        );
        if (row != null) {
          ref
              .read(worldCharactersProvider(newWorldId).notifier)
              .applyMirror(row);
        }
        // Hub-level mirror: personal_characters retire edildi (migration
        // 040).
        final selfUid = ref.read(authProvider)?.uid;
        if (selfUid != null && row != null) {
          if (newOwnerId == selfUid) {
            // Bu karakteri ben sahipleniyorum → hub char tab'ında tam
            // payload'la tut (içerik + metadata). Yalnızca metadata
            // patch'lemek DM'in içerik düzenlemesini player editörüne
            // taşımıyordu.
            final fromPayload = await _characterFromPayload(row);
            if (fromPayload != null) {
              // ignore: discarded_futures
              ref
                  .read(characterListProvider.notifier)
                  .applyMirror(fromPayload);
            }
          } else {
            // Ownership benden gitti (unclaim / başka oyuncuya assign) ama
            // karakter dünyada kaldı → hub char tab'ımdan + local Drift'ten
            // çıkar. worldCharactersProvider'da (dünya görünümü) unclaimed
            // olarak kalır; cloud row silinmez.
            // ignore: discarded_futures
            ref.read(characterListProvider.notifier).dropMirror(id);
          }
        }
      default:
        return;
    }
  }

  /// world_characters.payload_json field'ı tüm `Character` JSON'unu taşır.
  /// Yeni cihaza ilk giriş veya owner-eklenmiş cross-device event'inde
  /// hub-level Character'ı sıfırdan kurmak için kullanılır.
  Future<dynamic> _characterFromPayload(WorldCharacterRow row) async {
    try {
      final decoded = await _decodeJsonMaybeOffload(row.payloadJson);
      if (decoded is! Map<String, dynamic>) return null;
      return Character.fromJson(decoded).copyWith(
        worldId: row.worldId,
        ownerId: row.ownerId,
      );
    } catch (e) {
      debugPrint('_characterFromPayload decode error: $e');
      return null;
    }
  }

  WorldCharacterRow? _charRowFromCdc(
    Map<String, dynamic> row, {
    required String fallbackWorldId,
    String? fallbackPayloadJson,
  }) {
    final id = row['id'] as String?;
    if (id == null) return null;
    final updatedRaw = row['updated_at'] as String?;
    // Postgres unchanged-TOAST: metadata-only UPDATE'te payload_json CDC'de
    // null gelir → mevcut payload'u koru, asla `{}`'a düşürme (decode patlar).
    final cdcPayload = row['payload_json'] as String?;
    return WorldCharacterRow(
      id: id,
      worldId: (row['world_id'] as String?) ?? fallbackWorldId,
      ownerId: row['owner_id'] as String?,
      templateId: (row['template_id'] as String?) ?? '',
      templateName: (row['template_name'] as String?) ?? '',
      payloadJson: cdcPayload ?? fallbackPayloadJson ?? '{}',
      updatedAt: updatedRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.tryParse(updatedRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Unchanged-TOAST fallback: CDC `payload_json` null geldiğinde decode
  /// edilebilir bir payload bul — önce world view satırı, sonra hub char
  /// listesi. Hiçbiri yoksa null (genelde INSERT tam payload taşır).
  String? _resolveFallbackPayload(String worldId, String id) {
    final existing = ref
        .read(worldCharactersProvider(worldId))
        .valueOrNull
        ?.where((r) => r.id == id)
        .firstOrNull;
    final fromWorld = existing?.payloadJson;
    if (fromWorld != null && fromWorld != '{}') return fromWorld;
    final hubChar =
        (ref.read(characterListProvider).valueOrNull ?? const <Character>[])
            .where((c) => c.id == id)
            .firstOrNull;
    if (hubChar != null) return jsonEncode(hubChar.toJson());
    return null;
  }

  /// world_members CDC: roster always refreshes. Role + hub world-list
  /// caches only refresh when the event is about *this* user — other-user
  /// joins/leaves don't change my role or my world list, so the previous
  /// unconditional invalidate cascade was wasted work that fanned out into
  /// `visibleEntityProvider` / sidebar rebuilds on every players-tab
  /// activity. Personal channel covers self-on-other-device events.
  Future<void> _applyMembersEvent(WorldSyncEvent e) async {
    // world_members PK is (world_id, user_id) — so DELETE oldRecord carries
    // user_id under default REPLICA IDENTITY.
    final eventUid =
        (e.newRecord['user_id'] ?? e.oldRecord['user_id']) as String?;
    final notifier =
        ref.read(worldMembersProvider(e.worldId).notifier);
    switch (e.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        // Güvenlik ağı: applyJoin başarısızsa (profile fetch hata vs.)
        // roster'ı bütünüyle yeniden çek — yeni member'ı kaybetmeyelim.
        notifier.applyJoin(e.newRecord).catchError((err, st) {
          debugPrint('_applyMembersEvent applyJoin error: $err\n$st');
          return notifier.bootstrap(force: true);
        });
      case PostgresChangeEvent.delete:
        if (eventUid != null) notifier.applyLeave(eventUid);
      default:
        break;
    }
    final selfUid = ref.read(authProvider)?.uid;
    final isSelf = selfUid != null && eventUid == selfUid;
    if (!isSelf) return;
    // Snapshot role BEFORE invalidation — needed to choose trash vs purge
    // when the membership row just vanished (server-side cascade after a
    // DM-driven world delete on another device).
    final priorRole = _campaign.cachedWorldRole(e.worldId);
    // Role + hub caches refresh via the stable notifier ref: invalidating
    // `currentWorldRoleProvider` tears down this applier's host provider,
    // so the applier must not invalidate (or read) via its own `ref` after.
    _campaign.refreshWorldCaches(e.worldId);
    if (e.eventType != PostgresChangeEvent.delete) return;
    // Make Offline echo: kendi membership satırım cascade ile silindi ama
    // DM lokal dünyayı offline olarak tutmak istiyor. Trash/purge'ü atla.
    if (mirror.isExpectedUnpublish(e.worldId)) {
      await _campaign.handleExpectedUnpublish(e.worldId);
      return;
    }
    // DM cross-device: DM on device A deleted the world → server cascade
    // dropped my membership row here on device B. Soft-delete (trash) so
    // the user can still restore. Player path stays as hard purge.
    if (priorRole == WorldRole.dm) {
      await _trashLocalWorld(e.worldId);
      return;
    }
    try {
      final role = await _campaign.recheckWorldRole(e.worldId);
      if (role == WorldRole.none) {
        await purgeLocalWorld(e.worldId);
      }
    } catch (err, st) {
      debugPrint('_applyMembersEvent role re-check error: $err\n$st');
    }
  }

  /// DM cross-device delete echo: move the local mirror to trash without
  /// firing a fresh cloud delete (the originating device already did it).
  /// Routed through the stable [ActiveCampaignNotifier] — see [_campaign].
  Future<void> _trashLocalWorld(String worldId) =>
      _campaign.trashWorldById(worldId);

  /// Public so the per-user sync applier can purge a world when the
  /// `world_members` DELETE event arrives via the personal channel (e.g.
  /// the user is logged in on another device and got kicked there).
  /// Routed through the stable [ActiveCampaignNotifier] — see [_campaign].
  Future<void> purgeLocalWorld(String worldId) =>
      _campaign.purgeWorldById(worldId);

  Future<void> _applyWorldsEvent(WorldSyncEvent e) async {
    if (e.eventType == PostgresChangeEvent.delete) {
      final worldId = (e.oldRecord['id'] ?? e.newRecord['id']) as String?;
      if (worldId == null) return;
      // Make Offline: DM cloud satırını kasıtlı düşürdü ama TÜM lokal Drift
      // verisini tutmak istiyor. Purge'ü atla; yalnızca online-state
      // cleanup yap → dünya normal bir offline dünyaya dönsün.
      if (mirror.isExpectedUnpublish(worldId)) {
        await _campaign.handleExpectedUnpublish(worldId);
        return;
      }
      // Routed through the stable notifier: it purges the local mirror AND
      // refreshes role/hub caches via its own ref. Invalidating
      // `currentWorldRoleProvider` tears down this applier (its host
      // watches that provider), so the applier must not touch `ref` here.
      try {
        await _campaign.purgeWorldById(worldId);
      } catch (err) {
        debugPrint('_applyWorldsEvent purgeWorldById error: $err');
      }
      return;
    }
    if (e.eventType != PostgresChangeEvent.update &&
        e.eventType != PostgresChangeEvent.insert) {
      return;
    }
    final activeCampaign = ref.read(activeCampaignProvider.notifier);
    final data = activeCampaign.data;
    if (data == null) return;
    final newState = e.newRecord['state_json'];
    if (newState is! String) return;
    try {
      final decoded = await _decodeJsonMaybeOffload(newState);
      if (decoded is! Map<String, dynamic>) return;
      // entities alt-map'i normalde world_entities'ten patch'leniyor;
      // worlds.state_json sadece üst-düzey alanları taşır. PR-SYNC-3:
      // map_data + sessions + settings ayrı tablolardan geliyor, bu yüzden
      // worlds event'inden gelen bu alanları da strip ediyoruz — aksi halde
      // race olabilir (granular row henüz gelmemişken state_json daha yeni
      // ama eksik veriyle local'i ezerdi). entities'i de koru.
      final entities = data['entities'];
      final mapData = data['map_data'];
      final sessions = data['sessions'];
      // PRESERVE: settings subkey'leri artık top-level'da yaşıyor
      // (`_applySettingsRow` spread eder). Granular `world_settings`
      // event'i bu anahtarları ayrıca taze tutuyor. Worlds payload'undan
      // gelen stale değerler bunları ezmesin diye `decoded`'dan strip et.
      final preservedSettingsKeys = <String, dynamic>{};
      for (final entry in data.entries) {
        if (_settingsApplyBlocklist.contains(entry.key)) continue;
        preservedSettingsKeys[entry.key] = entry.value;
      }
      // PRESERVE: local-only sibling keys (saveSettingsPatchLocalOnly yazıyor,
      // cloud state_json'a hiç gitmez). clear+addAll'dan sonra geri konmazsa
      // in-memory'den silinir → ekran reload'da viewport defaulta düşer.
      // Yeni motion-class key eklenince buraya da ekle.
      final mapView = data['map_view'];
      final mindMapViews = data['mind_map_views'];
      decoded.remove('map_data');
      decoded.remove('sessions');
      // Worlds payload'undaki settings subkey'leri kullanılmaz — preserve
      // edilmiş top-level değerler `_applySettingsRow` ile yeniden yazılacak.
      for (final key in preservedSettingsKeys.keys) {
        decoded.remove(key);
      }
      decoded.remove('settings'); // legacy nested kopyayı da düşür
      data
        ..clear()
        ..addAll(decoded);
      if (entities is Map<String, dynamic>) {
        data['entities'] = entities;
      }
      if (mapData != null) data['map_data'] = mapData;
      if (sessions != null) data['sessions'] = sessions;
      data.addAll(preservedSettingsKeys);
      if (mapView != null) data['map_view'] = mapView;
      if (mindMapViews != null) data['mind_map_views'] = mindMapViews;
      _bumpRevision();
      // Cover/metadata `worlds.state_json` içinde de taşınır. Granular
      // `world_settings` event'i bu update'e eşlik etmese bile hub liste
      // refresh'inin cover'ı görmesi için metadata alt-kümesini Drift'e yaz.
      final meta = decoded['metadata'];
      if (meta is Map<String, dynamic>) {
        await _persistSettingsToDrift(e.worldId, {'metadata': meta});
      }
    } catch (err) {
      debugPrint('_applyWorldsEvent decode error: $err');
    }
  }

  // ── PR-SYNC-3 granular world state appliers ─────────────────────────

  Future<void> _applyMapDataEvent(WorldSyncEvent e) async {
    if (mirror.isEchoOfMapData(e.worldId)) return;
    // CDC race guard: local pending pin/edit varken remote uygulanmaz.
    if (_buffer.isPending('settings:${e.worldId}:map_data')) return;
    switch (e.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        await _applyMapDataRow(e.newRecord);
      case PostgresChangeEvent.delete:
        final data = ref.read(activeCampaignProvider.notifier).data;
        if (data != null && data.remove('map_data') != null) _bumpRevision();
      default:
        return;
    }
  }

  Future<void> _applyMapDataRow(Map<String, dynamic> row) async {
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final raw = row['data_json'];
    if (raw is! String) return;
    try {
      final decoded = await _decodeJsonMaybeOffload(raw);
      if (decoded is! Map<String, dynamic>) return;
      data['map_data'] = decoded;
      _bumpRevision();
      // F3: map_data içindeki AssetRef'ler (map images, pin icons)
      final worldId = row['world_id'] as String?;
      if (worldId != null) {
        ref.read(referenceIndexerProvider).scheduleReindex(
              table: 'world_map_data',
              id: worldId,
              json: decoded,
              worldId: worldId,
            );
      }
      // F5: pre-fetch map images / pin icons.
      final refs = ReferenceIndexer.extractRefs(decoded);
      if (refs.isNotEmpty) {
        ref.read(fetchQueueProvider).scheduleAll(refs);
      }
    } catch (err) {
      debugPrint('_applyMapDataRow decode error: $err');
    }
  }

  Future<void> _applySessionEvent(WorldSyncEvent e) async {
    final id = (e.newRecord['id'] ?? e.oldRecord['id']) as String?;
    if (id == null) return;
    if (mirror.isEchoOfSession(id)) return;
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final raw = data['sessions'];
    final List sessions = raw is List ? List.from(raw) : <dynamic>[];
    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        sessions.removeWhere((s) => s is Map && s['id'] == id);
        data['sessions'] = sessions;
        _bumpRevision();
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final mapped = await _sessionRowToBlob(e.newRecord);
        if (mapped == null) return;
        final idx = sessions.indexWhere((s) => s is Map && s['id'] == id);
        if (idx >= 0) {
          sessions[idx] = mapped;
        } else {
          sessions.add(mapped);
        }
        data['sessions'] = sessions;
        _bumpRevision();
      default:
        return;
    }
  }

  Future<void> _applySessionsList(List<Map<String, dynamic>> rows) async {
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final mapped = <dynamic>[];
    for (final row in rows) {
      final m = await _sessionRowToBlob(row);
      if (m != null) mapped.add(m);
    }
    data['sessions'] = mapped;
  }

  Future<Map<String, dynamic>?> _sessionRowToBlob(
      Map<String, dynamic> row) async {
    final id = row['id'];
    if (id is! String) return null;
    final raw = row['data_json'];
    Map<String, dynamic>? inner;
    if (raw is String) {
      try {
        final decoded = await _decodeJsonMaybeOffload(raw);
        if (decoded is Map<String, dynamic>) inner = decoded;
      } catch (_) {
        // fall through — produce skeleton with id+name only
      }
    }
    final blob = <String, dynamic>{
      ...?inner,
      'id': id,
      if (row['name'] is String) 'name': row['name'],
      if (row['is_active'] is bool) 'is_active': row['is_active'],
      if (row['sort_order'] is num) 'sort_order': row['sort_order'],
    };
    return blob;
  }

  Future<void> _applySettingsEvent(WorldSyncEvent e) async {
    if (mirror.isEchoOfSettings(e.worldId)) return;
    switch (e.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        await _applySettingsRow(e.newRecord, worldId: e.worldId);
      case PostgresChangeEvent.delete:
        final data = ref.read(activeCampaignProvider.notifier).data;
        if (data != null && data.remove('settings') != null) _bumpRevision();
      default:
        return;
    }
  }

  // ── PR-SYNC-5: DM-shared world_packages mirror ──────────────────────

  Future<void> _applyWorldPackageEvent(WorldSyncEvent e) async {
    final id =
        (e.newRecord['package_id'] ?? e.oldRecord['package_id']) as String?;
    if (id == null) return;
    if (mirror.isEchoOfWorldPackage(id)) return;
    final db = ref.read(appDatabaseProvider);
    final dao = db.worldPackagesDao;
    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        final priorName =
            (e.oldRecord['package_name'] as String?) ?? '';
        final priorWorld =
            (e.oldRecord['world_id'] as String?) ?? e.worldId;
        // leave_beta / Make Offline: parent world korunuyorsa world_packages
        // satırını + materialize edilmiş local package'ı koru.
        if (mirror.isExpectedUnpublish(priorWorld)) break;
        await dao.deleteByPackage(id);
        await _uninstallSharedPackageLocally(db, priorWorld, priorName);
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final row = e.newRecord;
        final worldId = (row['world_id'] as String?) ?? e.worldId;
        final packageName = (row['package_name'] as String?) ?? '';
        final stateJson = (row['state_json'] as String?) ?? '{}';
        await dao.upsert(
          WorldPackagesCompanion(
            worldId: Value(worldId),
            packageId: Value(id),
            packageName: Value(packageName),
            sharedBy: Value(row['shared_by'] as String?),
            stateJson: Value(stateJson),
            updatedAt: Value(
              DateTime.tryParse((row['updated_at'] as String?) ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
        await _materializeSharedPackageLocally(
          db,
          worldId,
          packageName,
          stateJson,
        );
      default:
        return;
    }
  }

  /// Player-side: decode the DM-shared package state_json into a local
  /// `packages` row + install it into the world so `world_entities` get the
  /// pack entities. Idempotent — re-running on an `update` event refreshes
  /// pkg contents and re-syncs.
  Future<void> _materializeSharedPackageLocally(
    AppDatabase db,
    String worldId,
    String packageName,
    String stateJson,
  ) async {
    if (packageName.isEmpty || stateJson.isEmpty || stateJson == '{}') return;
    try {
      final decoded = await _decodeJsonMaybeOffload(stateJson);
      if (decoded is! Map<String, dynamic>) return;
      final repo = ref.read(packageRepositoryProvider);
      await repo.save(packageName, decoded);
      final pkg = await db.packagesDao.getByName(packageName);
      if (pkg == null) return;
      await db.installedPackagesDao.upsert(
        InstalledPackagesCompanion.insert(
          worldId: worldId,
          packageId: pkg.id,
          packageName: Value(pkg.name),
        ),
      );
      final build = generateBuiltinDnd5eV2Schema();
      final tier0Slugs = build.seedRows.keys.toSet();
      final tier0Index =
          await buildTier0LookupIndex(db, worldId, tier0Slugs: tier0Slugs);
      await PackageSyncService(db).sync(
        worldId: worldId,
        packageId: pkg.id,
        resolveAttrs: (attrs) =>
            PackageImportService.resolveLookupPlaceholder(attrs, tier0Index)
                as Map<String, dynamic>,
      );
      ref.invalidate(packageListProvider);
      _bumpRevision();
    } catch (err, st) {
      debugPrint('_materializeSharedPackageLocally error: $err\n$st');
    }
  }

  Future<void> _uninstallSharedPackageLocally(
    AppDatabase db,
    String worldId,
    String packageName,
  ) async {
    if (packageName.isEmpty) return;
    try {
      final pkg = await db.packagesDao.getByName(packageName);
      if (pkg == null) return;
      await PackageSyncService(db).uninstall(
        worldId: worldId,
        packageId: pkg.id,
      );
      _bumpRevision();
    } catch (err, st) {
      debugPrint('_uninstallSharedPackageLocally error: $err\n$st');
    }
  }

  Future<void> _applySettingsRow(
    Map<String, dynamic> row, {
    required String worldId,
  }) async {
    if (_disposed) return;
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data == null) return;
    final raw = row['settings_json'];
    if (raw is! String) return;

    // ref-türevli değerler await'ten ÖNCE alınır — decode sırasında world/role
    // değişirse ref stale olur (`_didChangeDependency`); sonrasında ref'e
    // dokunmuyoruz, yalnızca _bumpRevision (self-guarded) kalıyor.
    final prefix = 'settings:$worldId:';
    final pendingKeys = _buffer.pendingKeysWithPrefix(prefix).toList();

    Map<String, dynamic> decoded;
    try {
      final d = await _decodeJsonMaybeOffload(raw);
      if (d is! Map<String, dynamic>) return;
      decoded = d;
    } catch (err) {
      debugPrint('_applySettingsRow decode error: $err');
      return;
    }

    // `_loadFromDb` settings_json subkey'lerini top-level `data`'ya yayıyor
    // (combat_state, mind_maps, map_view, mind_map_views, metadata, …) ve
    // okurlar (combat_provider, mind_map_screen, …) da top-level'dan okuyor.
    // Cross-device açılışta cloud sync de aynı yere yazmalı — önceden tüm
    // blob `data['settings']` altına gömülüyordu, bu yüzden başka cihazdan
    // açılınca session/mind-map sekmeleri boş kalıyordu.
    //
    // CDC race guard: subkey için lokal pending write varsa, kullanıcının
    // henüz flush edilmemiş edit'i `data[subkey]` içinde duruyor — cloud
    // değerini uygulama ki kullanıcı edit'i ezilmesin.
    final pendingSubkeys = pendingKeys
        .map((k) => k.substring(prefix.length).split(':').first)
        .toSet();

    for (final entry in decoded.entries) {
      final key = entry.key;
      if (_settingsApplyBlocklist.contains(key)) continue;
      if (pendingSubkeys.contains(key)) continue;
      data[key] = entry.value;
    }

    // Önceki versiyonlarda blob'un tamamı `data['settings']` altına
    // yazılıyordu. Top-level spread'e geçişte legacy nested kopyayı temizle —
    // stale değerler taze top-level anahtarları gölgelemesin.
    data.remove('settings');
    // Synced settings blob'unu device-local Drift'e de yaz — `_applySettingsRow`
    // önceden yalnızca in-memory state'e dokunuyordu, bu yüzden hub liste
    // (campaignInfoListProvider) refresh sonrası eski cover'ı okuyordu.
    await _persistSettingsToDrift(worldId, decoded);
    _bumpRevision();
    // F3: settings JSON içindeki AssetRef'ler (cover, mind_map images,
    // battle_map fog/annotation, vb.) için graf güncellemesi.
    ref.read(referenceIndexerProvider).scheduleReindex(
          table: 'world_settings',
          id: worldId,
          json: decoded,
          worldId: worldId,
        );
    // F5: settings içindeki tüm AssetRef'leri arka planda indir.
    final settingsRefs = ReferenceIndexer.extractRefs(decoded);
    if (settingsRefs.isNotEmpty) {
      ref.read(fetchQueueProvider).scheduleAll(settingsRefs);
    }
  }

  /// Synced bir `world_settings` blob'unu device-local Drift'e yazar — hub
  /// liste (campaignInfoListProvider / campaignMetadataProvider) refresh
  /// sonrası güncel cover/metadata'yı görsün. MERGE semantiği:
  /// `repo.saveSettingsPatch` kullanılır → cloud `settings_json`'da olmayan
  /// local-only `_world_schema` snapshot'ı korunur.
  Future<void> _persistSettingsToDrift(
    String worldId,
    Map<String, dynamic> decoded,
  ) async {
    try {
      final repo = ref.read(campaignRepositoryProvider); // await ÖNCESİ
      final name = await _campaign.resolveWorldName(worldId);
      if (name == null) return;
      await repo.saveSettingsPatch(name, decoded);
      _campaign.refreshWorldMetadataCaches(worldId, name);
    } catch (err) {
      debugPrint('_persistSettingsToDrift error: $err');
    }
  }

  // ── Online ikinci ekran — projeksiyon manifesti (Faz A) ─────────────

  /// world_projection CDC event → player-side `onlineProjectionProvider`.
  /// INSERT/UPDATE manifesti decode eder; DELETE (DM projeksiyonu kapattı)
  /// temizler. DM kendi yazımının echo'sunu da alır — zararsız, DM bu
  /// provider'ı render etmez.
  void _applyProjectionEvent(WorldSyncEvent e) {
    final notifier = ref.read(onlineProjectionProvider.notifier);
    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        notifier.state = null;
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final raw = e.newRecord['state_json'];
        if (raw is! String) return;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) return;
          notifier.state = ProjectionState.fromJson(decoded);
        } catch (err) {
          debugPrint('_applyProjectionEvent decode error: $err');
        }
      default:
        return;
    }
  }

  Map<String, dynamic> _entityRowToBlob(Map<String, dynamic> row) {
    Object? decode(dynamic raw, Object? fallback) {
      if (raw is String && raw.isNotEmpty) {
        try {
          return jsonDecode(raw);
        } catch (_) {
          return fallback;
        }
      }
      return fallback ?? raw;
    }

    final blob = <String, dynamic>{
      'name': row['name'],
      'type': row['category_slug'],
      'source': row['source'] ?? '',
      'description': row['description'] ?? '',
      'images': decode(row['images_json'], const []),
      'image_path': row['image_path'] ?? '',
      'tags': decode(row['tags_json'], const []),
      'dm_notes': row['dm_notes'] ?? '',
      'pdfs': decode(row['pdfs_json'], const []),
      'location_id': row['location_id'],
      'attributes': decode(row['fields_json'], const <String, dynamic>{}),
    };
    if (row['package_id'] != null) blob['package_id'] = row['package_id'];
    if (row['package_entity_id'] != null) {
      blob['package_entity_id'] = row['package_entity_id'];
    }
    if (row['linked'] == true) blob['linked'] = true;
    return blob;
  }

  void _bumpRevision() {
    if (_disposed) return;
    // Flush penceresi içinde — bump'ı ertele, pencere sonunda tek atılır.
    if (_suppressRevisionBump) {
      _revisionDirty = true;
      return;
    }
    _doBumpRevision();
  }

  void _doBumpRevision() {
    if (_disposed) return;
    try {
      final n = ref.read(campaignRevisionProvider.notifier);
      n.state = n.state + 1;
    } catch (_) {
      // ref dependency-change penceresinde stale — bir sonraki event toparlar.
    }
  }
}

/// CDC event'lerini kısa pencerede toplayıp tek geçişte uygular (R1).
///
/// Çok-kişili realtime'da event seli her event için ayrı `_bumpRevision()`
/// tetikliyordu → rebuild fırtınası. Batcher [window] boyunca event biriktirir,
/// idempotent satır event'lerini PK bazlı coalesce eder (son event kazanır),
/// sonra hepsini tek seferde flush eder.
class _EventBatcher {
  _EventBatcher({required this.window, required this.onFlush});

  final Duration window;
  final Future<void> Function(List<WorldSyncEvent> batch) onFlush;

  /// PK bazlı coalesce edilen event'ler — recency order korunur (aynı key
  /// tekrar gelince pozisyon sona taşınır, son event hem içerik hem sıra).
  final LinkedHashMap<String, WorldSyncEvent> _coalesced =
      LinkedHashMap<String, WorldSyncEvent>();

  /// Coalesce edilemeyen event'ler (member join/leave sırası önemli).
  final List<WorldSyncEvent> _ordered = <WorldSyncEvent>[];

  Timer? _timer;
  bool _flushing = false;
  bool _disposed = false;

  void add(WorldSyncEvent e) {
    if (_disposed) return;
    final key = _coalesceKey(e);
    if (key != null) {
      _coalesced.remove(key); // recency: pozisyonu sona taşı
      _coalesced[key] = e;
    } else {
      _ordered.add(e);
    }
    _timer ??= Timer(window, _fire);
  }

  /// İdempotent, son-yazan-kazanır tablolar için coalesce anahtarı.
  /// `world_members` / `worlds` / `entity_shares` → null (coalesce yok).
  String? _coalesceKey(WorldSyncEvent e) {
    switch (e.table) {
      case 'world_entities':
      case 'world_sessions':
      case 'world_characters':
        final id = (e.newRecord['id'] ?? e.oldRecord['id']) as String?;
        return id == null ? null : '${e.table}:$id';
      case 'world_map_data':
      case 'world_settings':
        return '${e.table}:${e.worldId}';
      case 'world_packages':
        final id =
            (e.newRecord['package_id'] ?? e.oldRecord['package_id'])
                as String?;
        return id == null ? null : '${e.table}:$id';
      default:
        return null;
    }
  }

  Future<void> _fire() async {
    _timer = null;
    if (_disposed || _flushing) return;
    _flushing = true;
    try {
      final batch = _drain();
      if (batch.isNotEmpty) await onFlush(batch);
    } finally {
      _flushing = false;
      // Flush sırasında biriken event varsa yeni pencere aç — ilerleme garanti.
      if (!_disposed && (_coalesced.isNotEmpty || _ordered.isNotEmpty)) {
        _timer ??= Timer(window, _fire);
      }
    }
  }

  List<WorldSyncEvent> _drain() {
    final out = <WorldSyncEvent>[..._coalesced.values, ..._ordered];
    _coalesced.clear();
    _ordered.clear();
    return out;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _coalesced.clear();
    _ordered.clear();
  }
}
