import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_format.dart';
import '../../data/database/app_database.dart';
import '../../data/network/network_providers.dart';
import '../../domain/entities/character.dart';
import '../../domain/value_objects/media_kind.dart';
import '../providers/auth_provider.dart';
import '../providers/beta_provider.dart';
import '../providers/cloud_backup_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/world_mirror_provider.dart';
import 'image_upload_helper.dart';
import 'media_bundler.dart';
import 'pending_write_buffer.dart';
import 'srd_core_package_bootstrap.dart';
import 'sync_tier.dart';

/// Persistent outbox drain worker (PR-D5 v12 rewrite).
///
/// The engine is a singleton owned by [syncEngineProvider]. Mutations elsewhere
/// in the app call [SyncEngine.enqueue*] which routes through the v12
/// `SyncOutboxDao.enqueueCoalesced` API: rows with matching
/// `(target_table, target_pk, op_type)` overwrite each other so rapid edits
/// don't bloat the outbox.
///
/// Tier-aware enqueue: fast tier (world entities, world-bound characters, world
/// settings/map/sessions, world_packages) drain immediately on the next tick;
/// slow tier (personal packages + entities, worldless char snapshots) carry a
/// 30s `nextAttemptAt` offset so coalescing batches rapid edits before hitting
/// the network.
///
/// Auto drain triggers (set up in [start]):
///   - `PendingWriteBuffer.tick` bump → 150ms micro-debounce → `_tick()`.
///   - `connectivityStreamProvider` false→true transition → `_tick()`.
///   - 15s periodic safety timer → `_tick()` (slow tier eligibility + retry).
///
/// Ordering: rows drain in `(nextAttemptAt ASC, createdAt ASC)` per the DAO's
/// `readyBatch`, so dependencies (e.g. world create before world_entity insert)
/// are preserved per-actor.
///
/// Retry: exponential backoff capped at 5 minutes; rows past 50 attempts are
/// considered dead-lettered (left in the table for inspection).
class SyncEngine {
  SyncEngine(this._db, this._ref);

  final AppDatabase _db;
  final Ref _ref;

  bool _running = false;
  bool _paused = false;
  bool _started = false;

  Timer? _drainDebounce;
  Timer? _retryTimer;
  ProviderSubscription<AsyncValue<bool>>? _connSub;
  VoidCallback? _bufferListener;

  static const int _batchSize = 20;
  static const int _dlqAttempts = 50;
  static const Duration _maxBackoff = Duration(minutes: 5);
  static const Duration _drainMicroDebounce = Duration(milliseconds: 150);
  static const Duration _retryInterval = Duration(seconds: 15);

  // ── v12 outbox target tables (mirror Postgres table names). ────────────
  static const _tWorldEntities = 'world_entities';
  static const _tWorldCharacters = 'world_characters';
  static const _tWorldMapData = 'world_map_data';
  static const _tWorldSessions = 'world_sessions';
  static const _tWorldSettings = 'world_settings';
  static const _tWorlds = 'worlds';
  static const _tWorldPackages = 'world_packages';
  static const _tPersonalPackages = 'personal_packages';
  static const _tPersonalPackageEntities = 'personal_package_entities';
  static const _tCloudBackups = 'cloud_backups';

  static const _opUpsert = 'upsert';
  static const _opDelete = 'delete';

  /// Starts the worker. Wires three auto-drain triggers:
  ///   - PendingWriteBuffer.tick → 150ms micro-debounce → `_tick()`.
  ///   - Connectivity false→true → `_tick()`.
  ///   - 15s periodic timer → `_tick()` (slow tier eligibility + retries).
  void start() {
    if (_started) return;
    _started = true;

    final buffer = _ref.read(pendingWriteBufferProvider);
    void onBufferTick() => _scheduleDrain();
    buffer.tick.addListener(onBufferTick);
    _bufferListener = onBufferTick;

    _connSub = _ref.listen<AsyncValue<bool>>(
      connectivityStreamProvider,
      (prev, next) {
        final wasOnline = prev?.valueOrNull ?? false;
        final isOnline = next.valueOrNull ?? false;
        if (!wasOnline && isOnline) {
          // ignore: discarded_futures
          _tick();
        }
      },
    );

    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (!_started) return;
      // ignore: discarded_futures
      _tick();
    });

    // Catch up on any rows enqueued before start() (cold-start residue).
    // ignore: discarded_futures
    _tick();
  }

  Future<void> stop() async {
    _started = false;
    _drainDebounce?.cancel();
    _drainDebounce = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _connSub?.close();
    _connSub = null;
    final listener = _bufferListener;
    if (listener != null) {
      _ref.read(pendingWriteBufferProvider).tick.removeListener(listener);
      _bufferListener = null;
    }
  }

  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
    // ignore: discarded_futures
    _tick();
  }

  void _scheduleDrain() {
    if (!_started || _paused) return;
    _drainDebounce?.cancel();
    _drainDebounce = Timer(_drainMicroDebounce, () {
      if (!_started || _paused) return;
      // ignore: discarded_futures
      _tick();
    });
  }

  /// UI affordance — "Retry now" button on the sync indicator. Resets every
  /// pending row's backoff so the next drain processes them immediately.
  Future<int> forceTick() async {
    final n = await (_db.update(_db.syncOutbox)).write(
      SyncOutboxCompanion(
        attempts: const Value(0),
        nextAttemptAt: Value(DateTime.now()),
        lastError: const Value(null),
      ),
    );
    await _tick();
    return n;
  }

  // ────────────────────────────────────────────────────────────────────
  // Enqueue helpers — call from notifiers' Drift transactions.
  //
  // Fast tier (world_*) → default `nextAttemptAt = now`, drains on the next
  // tick. Slow tier (personal_*, cloud_backups) → `now + cloudDelay` so the
  // row coalesces edits before becoming drain-eligible.
  // ────────────────────────────────────────────────────────────────────

  DateTime _slowAttemptAt() => DateTime.now().add(SyncTier.slow.cloudDelay);

  /// Built-in (SRD core) package satırları cloud'a yazılmaz — pakage'ın
  /// kendisi tüm cihazlarda yerel olarak seed edilir. World/character içine
  /// linked row referans olarak girer; bu satırlar `world_entities` üzerinden
  /// normal yoldan CDC ile dağılır. Built-in package row'u outbox'a girmez.
  bool _isBuiltinPackage(String packageName) =>
      packageName == srdCorePackageName;

  Future<void> enqueueWorldEntityUpsert({
    required String worldId,
    required String entityId,
    required Map<String, dynamic> entityMap,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldEntities,
      targetPk: entityId,
      opType: _opUpsert,
      scopeId: worldId,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'entity': entityMap,
      }),
    );
  }

  Future<void> enqueueWorldEntityDelete({
    required String worldId,
    required String entityId,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldEntities,
      targetPk: entityId,
      opType: _opDelete,
      scopeId: worldId,
      payloadJson: jsonEncode({'world_id': worldId}),
    );
  }

  Future<void> enqueueWorldCharacterUpsert({
    required String worldId,
    required Character character,
    Set<String> referencedEntityIds = const {},
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldCharacters,
      targetPk: character.id,
      opType: _opUpsert,
      scopeId: worldId,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'character': character.toJson(),
        'referenced_entity_ids': referencedEntityIds.toList(),
      }),
    );
  }

  Future<void> enqueueWorldCharacterDelete({
    required String characterId,
    String? worldId,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldCharacters,
      targetPk: characterId,
      opType: _opDelete,
      scopeId: worldId,
      payloadJson: jsonEncode({
        // ignore: use_null_aware_elements
        if (worldId != null) 'world_id': worldId,
      }),
    );
  }

  /// Granular world map state. PK = worldId; rapid map edits coalesce.
  Future<void> enqueueWorldMapData({
    required String worldId,
    required Map<String, dynamic> data,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldMapData,
      targetPk: worldId,
      opType: _opUpsert,
      scopeId: worldId,
      payloadJson: jsonEncode({'world_id': worldId, 'data': data}),
    );
  }

  Future<void> enqueueWorldSessionUpsert({
    required String worldId,
    required String sessionId,
    required String name,
    required Map<String, dynamic> data,
    bool isActive = false,
    int sortOrder = 0,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldSessions,
      targetPk: sessionId,
      opType: _opUpsert,
      scopeId: worldId,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'name': name,
        'data': data,
        'is_active': isActive,
        'sort_order': sortOrder,
      }),
    );
  }

  Future<void> enqueueWorldSessionDelete({
    required String worldId,
    required String sessionId,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldSessions,
      targetPk: sessionId,
      opType: _opDelete,
      scopeId: worldId,
      payloadJson: jsonEncode({'world_id': worldId}),
    );
  }

  Future<void> enqueueWorldSettings({
    required String worldId,
    required Map<String, dynamic> settings,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldSettings,
      targetPk: worldId,
      opType: _opUpsert,
      scopeId: worldId,
      payloadJson: jsonEncode({'world_id': worldId, 'settings': settings}),
    );
  }

  /// Full worlds row push (name/template/state). PK = worldId.
  Future<void> enqueueWorldState({
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required Map<String, dynamic> state,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorlds,
      targetPk: worldId,
      opType: _opUpsert,
      scopeId: worldId,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'world_name': worldName,
        'template_id': ?templateId,
        'template_hash': ?templateHash,
        'state': state,
      }),
    );
  }

  /// DM shares personal package into world. PK = "worldId:packageName".
  Future<void> enqueueWorldPackageShare({
    required String worldId,
    required String packageName,
    required Map<String, dynamic> state,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldPackages,
      targetPk: '$worldId:$packageName',
      opType: _opUpsert,
      scopeId: worldId,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'package_name': packageName,
        'state': state,
      }),
    );
  }

  Future<void> enqueueWorldPackageUnshare({
    required String worldId,
    required String packageName,
    required String packageId,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tWorldPackages,
      targetPk: '$worldId:$packageName',
      opType: _opDelete,
      scopeId: worldId,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'package_name': packageName,
        'package_id': packageId,
      }),
    );
  }

  Future<void> enqueuePersonalPackageUpsert({
    required String packageName,
    required Map<String, dynamic> state,
  }) async {
    if (_isBuiltinPackage(packageName)) {
      debugPrint('[SyncEngine] skip builtin package $packageName');
      return;
    }
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tPersonalPackages,
      targetPk: packageName,
      opType: _opUpsert,
      payloadJson: jsonEncode({'state': state}),
      nextAttemptAt: _slowAttemptAt(),
    );
  }

  Future<void> enqueuePersonalPackageDelete({required String packageName}) async {
    if (_isBuiltinPackage(packageName)) {
      debugPrint('[SyncEngine] skip builtin package $packageName');
      return;
    }
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tPersonalPackages,
      targetPk: packageName,
      opType: _opDelete,
      payloadJson: '{}',
      nextAttemptAt: _slowAttemptAt(),
    );
  }

  /// F5 row-level. PK = "$packageName:$entityId" so distinct packages
  /// don't collide on shared entity ids. Coalesced upsert means rapid
  /// edits to the same entity collapse to one cloud push.
  Future<void> enqueuePersonalPackageEntityUpsert({
    required String packageName,
    required String entityId,
    required Map<String, dynamic> entityMap,
  }) async {
    if (_isBuiltinPackage(packageName)) {
      debugPrint('[SyncEngine] skip builtin package $packageName/$entityId');
      return;
    }
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tPersonalPackageEntities,
      targetPk: '$packageName:$entityId',
      opType: _opUpsert,
      payloadJson: jsonEncode({
        'package_name': packageName,
        'entity_id': entityId,
        'entity': entityMap,
      }),
      nextAttemptAt: _slowAttemptAt(),
    );
  }

  Future<void> enqueuePersonalPackageEntityDelete({
    required String packageName,
    required String entityId,
  }) async {
    if (_isBuiltinPackage(packageName)) {
      debugPrint('[SyncEngine] skip builtin package $packageName/$entityId');
      return;
    }
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tPersonalPackageEntities,
      targetPk: '$packageName:$entityId',
      opType: _opDelete,
      payloadJson: jsonEncode({
        'package_name': packageName,
        'entity_id': entityId,
      }),
      nextAttemptAt: _slowAttemptAt(),
    );
  }

  /// Cloud backup snapshot for a worldless / world-offline item. [type] is
  /// `world`, `template`, `package`, or `character`. PK = "$type:$itemId" so
  /// distinct types of the same id don't collide.
  Future<void> enqueueCloudBackupUpsert({
    required String itemId,
    required String itemName,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tCloudBackups,
      targetPk: '$type:$itemId',
      opType: _opUpsert,
      payloadJson: jsonEncode({
        'item_id': itemId,
        'item_name': itemName,
        'type': type,
        'data': data,
      }),
      nextAttemptAt: _slowAttemptAt(),
    );
  }

  Future<void> enqueueCloudBackupDelete({
    required String itemId,
    required String type,
  }) async {
    await _db.syncOutboxDao.enqueueCoalesced(
      opId: _newOpId(),
      targetTable: _tCloudBackups,
      targetPk: '$type:$itemId',
      opType: _opDelete,
      payloadJson: jsonEncode({'item_id': itemId, 'type': type}),
      nextAttemptAt: _slowAttemptAt(),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Drain loop
  // ────────────────────────────────────────────────────────────────────

  Future<void> _tick() async {
    if (_running || _paused) return;
    if (_ref.read(authProvider) == null) return;
    // Offline → drain'i atla. Satırlar outbox'ta (SQLite) kalır; start()'taki
    // offline→online listener bağlantı dönünce _tick()'i yeniden tetikler.
    if (!(_ref.read(connectivityStreamProvider).valueOrNull ?? true)) return;
    _running = true;
    try {
      var drained = 0;
      while (true) {
        final batch = await _db.syncOutboxDao
            .readyBatch(now: DateTime.now(), limit: _batchSize);
        if (batch.isEmpty) break;
        for (final row in batch) {
          if (_paused) break;
          await _handle(row);
          drained++;
        }
        if (batch.length < _batchSize) break;
      }
      if (drained > 0) {
        debugPrint('SyncEngine drained $drained outbox row(s)');
      }
    } catch (e, st) {
      if (isOfflineError(e)) {
        debugPrint('SyncEngine tick skipped: offline');
      } else {
        debugPrint('SyncEngine tick error: $e\n$st');
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _handle(SyncOutboxRow row) async {
    if (row.attempts >= _dlqAttempts) {
      debugPrint(
        '[SyncEngine] DLQ ${row.targetTable}/${row.targetPk} '
        '${row.opType} attempts=${row.attempts}',
      );
      return;
    }
    final sw = Stopwatch()..start();
    debugPrint(
      '[SyncEngine] → ${row.targetTable}/${row.targetPk} ${row.opType} '
      'attempt=${row.attempts + 1} payloadBytes=${row.payloadJson.length}',
    );
    try {
      switch (row.targetTable) {
        case _tWorldEntities:
          await _handleWorldEntity(row);
        case _tWorldCharacters:
          await _handleWorldCharacter(row);
        case _tWorldMapData:
          await _handleWorldMapData(row);
        case _tWorldSessions:
          await _handleWorldSession(row);
        case _tWorldSettings:
          await _handleWorldSettings(row);
        case _tWorlds:
          await _handleWorldState(row);
        case _tWorldPackages:
          await _handleWorldPackage(row);
        case _tPersonalPackages:
          await _handlePersonalPackage(row);
        case _tPersonalPackageEntities:
          await _handlePersonalPackageEntity(row);
        case _tCloudBackups:
          await _handleCloudBackup(row);
        default:
          debugPrint(
            '[SyncEngine] ✗ unknown table ${row.targetTable}, dropping',
          );
          await _db.syncOutboxDao.deleteById(row.opId);
          return;
      }
      await _db.syncOutboxDao.deleteById(row.opId);
      debugPrint(
        '[SyncEngine] ✓ ${row.targetTable}/${row.targetPk} ${row.opType} '
        '${sw.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      if (_isPermanentRejection(e)) {
        debugPrint(
          '[SyncEngine] ✗ drop ${row.targetTable}/${row.targetPk} '
          '${row.opType} ${sw.elapsedMilliseconds}ms: $e',
        );
        await _db.syncOutboxDao.deleteById(row.opId);
        return;
      }
      if (isOfflineError(e)) {
        debugPrint(
          '[SyncEngine] ↻ ${row.targetTable}/${row.targetPk} '
          'offline, retry queued',
        );
      } else {
        debugPrint(
          '[SyncEngine] ✗ retry ${row.targetTable}/${row.targetPk} '
          '${row.opType} ${sw.elapsedMilliseconds}ms: $e\n$st',
        );
      }
      await _markRetry(row, e.toString());
    }
  }

  /// Outbox row hatası geçici mi yoksa kalıcı RLS reddi mi? RLS reddi (PG
  /// `42501`) ve "row not found" gibi durumlar retry'a değmez — orphan
  /// outbox satırı dakikada bir 42501 spam'i üretir, drop temizler.
  bool _isPermanentRejection(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501') return true;
      // PostgREST "no rows" / PK miss — referenced parent likely deleted.
      if (e.code == 'PGRST116') return true;
    }
    return false;
  }

  Future<void> _markRetry(SyncOutboxRow row, String error) async {
    final attempts = row.attempts + 1;
    final seconds = math
        .min(_maxBackoff.inSeconds, math.pow(2, attempts).toInt())
        .clamp(1, _maxBackoff.inSeconds);
    final nextAt = DateTime.now().add(Duration(seconds: seconds));
    await _db.syncOutboxDao.incrementAttempts(row.opId);
    await _db.syncOutboxDao.markFailed(
      row.opId,
      error: error,
      nextAttemptAt: nextAt,
    );
  }

  // ── Handlers ───────────────────────────────────────────────────────

  Future<void> _handleWorldEntity(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final worldId = p['world_id'] as String;
    if (row.opType == _opDelete) {
      await mirror.deleteEntity(worldId: worldId, entityId: row.targetPk);
      return;
    }
    var entityMap = (p['entity'] as Map).cast<String, dynamic>();
    // F4: per-row media bundle. Replaces the previous world-wide
    // MediaBundler pass on the bulk pushEntities path — each outbox row
    // re-uploads local-path images (AssetService SHA-dedupes the repeat
    // case) and rewrites refs to `dmt-asset://` before the cloud push.
    final assetSvc = _ref.read(assetServiceProvider);
    if (assetSvc != null) {
      try {
        entityMap = await MediaBundler(assetSvc).bundleEntityMedia(
          scopeId: worldId,
          entityId: row.targetPk,
          entityMap: entityMap,
          kind: MediaKind.worldEntityImage,
        );
      } catch (e, st) {
        debugPrint('per-entity media bundle error: $e\n$st');
      }
    }
    await mirror.pushEntity(
      worldId: worldId,
      entityId: row.targetPk,
      entityMap: entityMap,
    );
  }

  Future<void> _handleWorldCharacter(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    if (row.opType == _opDelete) {
      await mirror.deleteCharacter(characterId: row.targetPk);
      return;
    }
    final worldId = p['world_id'] as String;
    var characterMap = (p['character'] as Map).cast<String, dynamic>();
    // Faz 3: karakter medyası — portre ücretsiz Supabase'e (dmt-public://),
    // ek resimler R2'ya (characterExtraImage). Bundle hatası sync'i bozmaz.
    final assetSvc = _ref.read(assetServiceProvider);
    if (assetSvc != null) {
      try {
        characterMap = await MediaBundler(
          assetSvc,
          freeMediaService: _ref.read(freeMediaServiceProvider),
        ).bundleCharacterMedia(
          scopeId: worldId.isEmpty ? 'personal' : worldId,
          characterMap: characterMap,
        );
      } catch (e, st) {
        debugPrint('character media bundle error: $e\n$st');
      }
    }
    final char = Character.fromJson(characterMap);
    final refs = ((p['referenced_entity_ids'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    await mirror.pushCharacter(
      worldId: worldId,
      character: char,
      referencedEntityIds: refs,
    );
  }

  Future<void> _handleWorldMapData(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final worldId = p['world_id'] as String;
    // Delete op: clear the row by upserting empty. Granular delete semantics
    // not exposed — the table is 1:1 with the world.
    var data = row.opType == _opDelete
        ? const <String, dynamic>{}
        : (p['data'] as Map).cast<String, dynamic>();
    // Faz 3: battle map arkaplan resmi R2'ya bundle (battleMap, 5MB).
    if (row.opType != _opDelete) {
      final assetSvc = _ref.read(assetServiceProvider);
      if (assetSvc != null) {
        try {
          data = await MediaBundler(assetSvc)
              .bundleMapMedia(worldId: worldId, mapData: data);
        } catch (e, st) {
          debugPrint('map media bundle error: $e\n$st');
        }
      }
    }
    await mirror.pushMapData(worldId: worldId, data: data);
  }

  Future<void> _handleWorldSession(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    if (row.opType == _opDelete) {
      await mirror.deleteSession(sessionId: row.targetPk);
      return;
    }
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    await mirror.pushSession(
      worldId: p['world_id'] as String,
      sessionId: row.targetPk,
      name: (p['name'] as String?) ?? '',
      data: (p['data'] as Map).cast<String, dynamic>(),
      isActive: (p['is_active'] as bool?) ?? false,
      sortOrder: (p['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _handleWorldSettings(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final worldId = p['world_id'] as String;
    final settings = row.opType == _opDelete
        ? const <String, dynamic>{}
        : (p['settings'] as Map).cast<String, dynamic>();
    await mirror.pushSettings(worldId: worldId, settings: settings);
  }

  Future<void> _handleWorldState(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    if (row.opType == _opDelete) {
      // worlds row delete goes through a separate "unpublish" flow elsewhere.
      return;
    }
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final state = (p['state'] as Map).cast<String, dynamic>();
    await mirror.pushWorldState(
      worldId: p['world_id'] as String,
      worldName: (p['world_name'] as String?) ?? '',
      templateId: p['template_id'] as String?,
      templateHash: p['template_hash'] as String?,
      stateJson: jsonEncode(state),
    );
  }

  Future<void> _handleWorldPackage(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final worldId = p['world_id'] as String;
    final packageName = p['package_name'] as String;
    if (row.opType == _opDelete) {
      final packageId = p['package_id'] as String?;
      if (packageId == null || packageId.isEmpty) return;
      await mirror.unshareWorldPackage(packageId: packageId);
      return;
    }
    final state = (p['state'] as Map).cast<String, dynamic>();
    await mirror.shareWorldPackage(
      worldId: worldId,
      packageName: packageName,
      state: state,
    );
  }

  Future<void> _handlePersonalPackage(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    if (!_ref.read(isBetaActiveProvider)) {
      return;
    }
    if (row.opType == _opDelete) {
      await mirror.unpublishPersonalPackage(row.targetPk);
      return;
    }
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    var state = (p['state'] as Map).cast<String, dynamic>();
    // Faz 3: paket kapak resmi (`metadata.cover_image_path`) hâlâ local path
    // ise free-media bucket'a yükle → portable `dmt-public://` ref. Bundle
    // hatası push'u bozmaz (best-effort).
    final meta = state['metadata'];
    if (meta is Map<String, dynamic>) {
      try {
        state = {
          ...state,
          'metadata': await uploadCoverImageInMetadata(
            _ref.read(freeMediaServiceProvider),
            metadata: meta,
            coverKind: MediaKind.packageCover,
            scopeId: row.targetPk,
          ),
        };
      } catch (e, st) {
        debugPrint('personal package cover bundle error: $e\n$st');
      }
    }
    await mirror.pushPersonalPackage(
      packageName: row.targetPk,
      state: state,
    );
  }

  Future<void> _handlePersonalPackageEntity(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    if (!_ref.read(isBetaActiveProvider)) return;
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final packageName = p['package_name'] as String;
    final entityId = p['entity_id'] as String;
    if (row.opType == _opDelete) {
      await mirror.deletePersonalPackageEntity(
        packageName: packageName,
        entityId: entityId,
      );
      return;
    }
    var entityMap = (p['entity'] as Map).cast<String, dynamic>();
    // Faz 3: package entity kart resimleri R2'ya bundle (packageEntityImage).
    final assetSvc = _ref.read(assetServiceProvider);
    if (assetSvc != null) {
      try {
        entityMap = await MediaBundler(assetSvc).bundleEntityMedia(
          scopeId: packageName,
          entityId: entityId,
          entityMap: entityMap,
          kind: MediaKind.packageEntityImage,
        );
      } catch (e, st) {
        debugPrint('package entity media bundle error: $e\n$st');
      }
    }
    await mirror.pushPersonalPackageEntity(
      packageName: packageName,
      entityId: entityId,
      entityMap: entityMap,
    );
  }

  Future<void> _handleCloudBackup(SyncOutboxRow row) async {
    if (!_ref.read(isBetaActiveProvider)) {
      debugPrint('[SyncEngine]   cloud_backup: beta inactive, skip');
      return;
    }
    final repo = _ref.read(cloudBackupRepositoryProvider);
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final itemId = p['item_id'] as String;
    final type = p['type'] as String;
    if (row.opType == _opDelete) {
      await repo.deleteBackupByItem(itemId, type);
      debugPrint('[SyncEngine]   cloud_backup deleted item=$itemId type=$type');
      return;
    }
    final itemName = p['item_name'] as String;
    var data = (p['data'] as Map).cast<String, dynamic>();
    // Faz 3: cloud_backup ile senkronlanan karakter (worldless / dünya
    // offline) medyası da bundle edilmeli. `_handleWorldCharacter` world
    // mirror yolunu bundle eder ama cloud_backup yolu etmiyordu — portre/ek
    // resim local dosya yolu olarak cloud'a gidip ikinci cihazda çözülemez
    // kalıyordu. Portre → ücretsiz Supabase (dmt-public://), ek resimler →
    // R2 (dmt-asset://). Bundle hatası backup'ı bozmaz (best-effort).
    if (type == 'character') {
      final assetSvc = _ref.read(assetServiceProvider);
      final charRaw = data['character'];
      if (assetSvc != null && charRaw is Map) {
        try {
          final bundled = await MediaBundler(
            assetSvc,
            freeMediaService: _ref.read(freeMediaServiceProvider),
          ).bundleCharacterMedia(
            scopeId: 'personal',
            characterMap: charRaw.cast<String, dynamic>(),
          );
          data = {...data, 'character': bundled};
        } catch (e, st) {
          debugPrint('cloud_backup character media bundle error: $e\n$st');
        }
      }
    }
    final hash = _hashPayload(type, itemId, data);
    try {
      final remoteHash = await repo.fetchPayloadHashByItem(itemId, type);
      if (remoteHash == hash) {
        debugPrint(
          '[SyncEngine]   cloud_backup hash match — skip upload '
          'item=$itemId type=$type hash=${hash.substring(0, 8)}',
        );
        return;
      }
      debugPrint(
        '[SyncEngine]   cloud_backup remoteHash=${remoteHash?.substring(0, 8) ?? "null"} '
        'localHash=${hash.substring(0, 8)} → upload',
      );
    } catch (e) {
      debugPrint('[SyncEngine]   cloud_backup hash fetch failed: $e');
    }
    final meta = await repo.uploadBackup(
      itemName,
      itemId,
      type,
      data,
      payloadHash: hash,
    );
    debugPrint(
      '[SyncEngine]   cloud_backup uploaded id=${meta.id} item=$itemId '
      'type=$type createdAt=${meta.createdAt.toIso8601String()} '
      'sizeBytes=${meta.sizeBytes}',
    );
  }

  String _hashPayload(String type, String itemId, Map<String, dynamic> data) {
    final canonical = jsonEncode({
      'type': type,
      'item_id': itemId,
      'data': data,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static int _opSeq = 0;
  String _newOpId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    _opSeq = (_opSeq + 1) & 0x7fffffff;
    return 'op_${t}_$_opSeq';
  }
}
