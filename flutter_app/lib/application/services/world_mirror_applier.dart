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
import '../providers/package_link_provider.dart';
import '../providers/package_provider.dart';
import '../providers/world_membership_provider.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/app_database.dart' hide WorldCharacterRow;
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

  /// Subscribe sonrası DM'in paylaşım kanalındaki birikmiş durumu local'a
  /// seed eder: paylaşılan kartlar, karakterler, canlı yayın manifesti.
  ///
  /// CDC yalnızca abonelikten SONRAKİ değişimleri taşır — dünya kapalıyken
  /// yapılan paylaşımlar bu seed olmadan hiç görünmezdi.
  Future<void> applyInitialState(String worldId) async {
    if (_disposed) return;
    ref.invalidate(worldEntitySharesProvider(worldId));
    final snapshot = await mirror.fetchInitialState(worldId);
    if (_disposed) return;
    if (snapshot.characters.isEmpty &&
        snapshot.shares.isEmpty &&
        snapshot.projection == null) {
      _markInitialSyncSettled(worldId);
      _bumpRevision();
      return;
    }

    // Paylaşılan kartların gövdeleri — payload'ı olmayan satırlar linked
    // kartlar; onların içeriği oyuncunun kurulu paketinden gelir.
    final data = ref.read(activeCampaignProvider.notifier).data;
    if (data != null && snapshot.shares.isNotEmpty) {
      final raw = data['entities'];
      final Map<String, dynamic> entities;
      if (raw is Map<String, dynamic>) {
        entities = raw;
      } else {
        entities = <String, dynamic>{};
        data['entities'] = entities;
      }
      for (final row in snapshot.shares) {
        final id = row['entity_id'] as String?;
        if (id == null) continue;
        if (_buffer.isPending('entity:$worldId:$id')) continue;
        final payload = _decodeSharePayload(row['payload_json']);
        if (payload != null) entities[id] = payload;
      }
    }

    if (snapshot.characters.isNotEmpty) {
      final notifier = ref.read(worldCharactersProvider(worldId).notifier);
      for (final row in snapshot.characters) {
        final mapped = _charRowFromCdc(row, fallbackWorldId: worldId);
        if (mapped != null) notifier.applyMirror(mapped);
      }
    }

    if (snapshot.projection != null) {
      _applyProjectionRow(snapshot.projection!);
    }

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
        case 'world_projection':
          _applyProjectionEvent(e);
        case 'entity_shares':
          await _applyEntityShareEvent(e);
        case 'world_characters':
          await _applyCharacterEvent(e);
        case 'world_packages':
          await _applyWorldPackageEvent(e);
        case 'world_members':
          await _applyMembersEvent(e);
        case 'worlds':
          await _applyWorldsEvent(e);
      }
    } catch (err, st) {
      debugPrint('WorldMirrorApplier error: $err\n$st');
    }
  }

  /// entity_shares CDC event. Shares listesini invalidate eder; INSERT/UPDATE
  /// için yeni paylaşılan entity'nin verisi player'da olmayabilir (RLS önceden
  /// gizliyordu, world_entities satırı değişmediği için CDC çıkmaz) — açıkça
  /// fetch edip local blob'a enjekte eder.
  /// `entity_shares` CDC — DM'in paylaştığı kartın hem görünürlüğü hem
  /// **içeriği** buradan gelir. `world_entities` aynası kaldırıldığı için
  /// satırın `payload_json`'ı oyuncunun tek içerik kaynağı.
  Future<void> _applyEntityShareEvent(WorldSyncEvent e) async {
    ref.invalidate(worldEntitySharesProvider(e.worldId));
    if (e.eventType == PostgresChangeEvent.delete) {
      // Paylaşım geri alındı: kartın gövdesini de düşür, yoksa oyuncunun
      // cihazında erişilemez ama duran bir kopya kalırdı.
      final removedId = e.oldRecord['entity_id'] as String?;
      if (removedId != null) _removeSharedEntity(removedId);
      return;
    }
    final entityId = e.newRecord['entity_id'] as String?;
    if (entityId == null) return;
    final payload = _decodeSharePayload(e.newRecord['payload_json']);
    if (payload == null) return; // linked kart — gövdesi kurulu paketten gelir
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
    // DM kendi kartını zaten yerelde tutuyor; yeniden yazmak, henüz
    // gönderilmemiş yerel düzenlemesini eski payload'la ezerdi.
    if (_buffer.isPending('entity:${e.worldId}:$entityId')) return;
    entities[entityId] = payload;
    _bumpRevision();
  }

  void _removeSharedEntity(String entityId) {
    final data = ref.read(activeCampaignProvider.notifier).data;
    final raw = data?['entities'];
    if (raw is! Map<String, dynamic>) return;
    if (raw.remove(entityId) != null) _bumpRevision();
  }

  static Map<String, dynamic>? _decodeSharePayload(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
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
        // Make Offline: parent world unpublish guard'ında veya orphan char
        // delete guard'ında ise lokal kopyayı koru.
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
        // Make Offline: parent world korunuyorsa world_packages
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
    Future<void> attempt() async {
      final decoded = await _decodeJsonMaybeOffload(stateJson);
      if (decoded is! Map<String, dynamic>) return;
      final repo = ref.read(packageRepositoryProvider);
      await repo.save(packageName, decoded);
      final pkg = await db.packagesDao.getByName(packageName);
      if (pkg == null) return;
      // Installs the shared package plus everything it links. A link whose
      // target the player doesn't have is dangling and simply skipped — the
      // DM shares each package separately.
      await ref
          .read(worldPackageInstallerProvider)
          .installIntoWorld(worldId: worldId, packageId: pkg.id);
      ref.invalidate(packageListProvider);
      _bumpRevision();
    }

    // Retry once: a transient decode/DB error otherwise leaves the player
    // without the package until the next `update` CDC.
    for (var i = 0; i < 2; i++) {
      try {
        await attempt();
        return;
      } catch (err, st) {
        if (i == 0 && !_disposed) {
          debugPrint('_materializeSharedPackageLocally retry after: $err');
          await Future<void>.delayed(const Duration(milliseconds: 150));
          if (!_disposed) continue;
        }
        debugPrint('_materializeSharedPackageLocally error: $err\n$st');
        return;
      }
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
    switch (e.eventType) {
      case PostgresChangeEvent.delete:
        ref.read(onlineProjectionProvider.notifier).state = null;
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        _applyProjectionRow(e.newRecord);
      default:
        return;
    }
  }

  /// `world_projection` satırını oyuncunun ikinci ekranına bağlar. Hem CDC
  /// event'i hem dünya açılışındaki seed buradan geçer.
  void _applyProjectionRow(Map<String, dynamic> row) {
    final raw = row['state_json'];
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      ref.read(onlineProjectionProvider.notifier).state =
          ProjectionState.fromJson(decoded);
    } catch (err) {
      debugPrint('_applyProjectionRow decode error: $err');
    }
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
  /// `world_members` / `worlds` / `entity_shares` → null (coalesce yok —
  /// paylaş/paylaşımı-kaldır sırası anlamlı).
  String? _coalesceKey(WorldSyncEvent e) {
    switch (e.table) {
      case 'world_characters':
        final id = (e.newRecord['id'] ?? e.oldRecord['id']) as String?;
        return id == null ? null : '${e.table}:$id';
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
