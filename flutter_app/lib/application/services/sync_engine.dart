import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/sync_outbox_dao.dart';
import '../../domain/entities/character.dart';
import '../providers/auth_provider.dart';
import '../providers/beta_provider.dart';
import '../providers/cloud_backup_provider.dart';
import '../providers/world_mirror_provider.dart';

/// Persistent outbox drain worker (PR-SYNC-1).
///
/// The engine is a singleton owned by [syncEngineProvider]. Mutations elsewhere
/// in the app call [SyncEngine.enqueue*] **inside the same Drift transaction**
/// as the local write; the engine wakes up via the DAO's change stream and
/// drains rows in serial.
///
/// Ordering: rows are drained in `created_at` ASC order so dependencies
/// (e.g. world create before world_entity insert) are preserved per-actor.
///
/// Retry: exponential backoff capped at 5 minutes; rows past 50 attempts are
/// considered dead-lettered (left in the table for inspection; status surfaced
/// to UI via the sync indicator).
class SyncEngine {
  SyncEngine(this._db, this._ref);

  final AppDatabase _db;
  final Ref _ref;

  StreamSubscription<void>? _outboxSub;
  Timer? _retryTimer;
  bool _running = false;
  bool _paused = false;
  bool _started = false;

  static const int _batchSize = 20;
  static const int _dlqAttempts = 50;
  static const Duration _maxBackoff = Duration(minutes: 5);

  /// Starts the worker. Idempotent — safe to call from `eagerLoad`.
  void start() {
    if (_started) return;
    _started = true;
    _outboxSub = _db.syncOutboxDao.watchAnyChange().listen((_) {
      // ignore: discarded_futures
      _tick();
    });
    // Initial drain on cold start (rows from a prior session that never got
    // pushed).
    // ignore: discarded_futures
    _tick();
  }

  /// Stops draining and tears down the stream. Used by app dispose paths.
  Future<void> stop() async {
    _started = false;
    await _outboxSub?.cancel();
    _outboxSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Lifecycle hooks for AppLifecycleState.paused / resumed.
  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
    // ignore: discarded_futures
    _tick();
  }

  /// UI affordance — "Retry now" button on the sync indicator.
  Future<int> forceTick() async {
    final n = await _db.syncOutboxDao.rescheduleAllNow();
    await _tick();
    return n;
  }

  // ────────────────────────────────────────────────────────────────────
  // Enqueue helpers — call from notifiers' Drift transactions.
  // ────────────────────────────────────────────────────────────────────

  /// Enqueue a world_entity upsert. `entityMap` is the serialised entity
  /// payload (id/name/fields/...). [builtinPackageId] is optional — used by
  /// `WorldMirrorService.pushEntity` to mark linked SRD-Core entities so they
  /// fan out via `is_builtin`.
  Future<void> enqueueWorldEntityUpsert({
    required String worldId,
    required String entityId,
    required Map<String, dynamic> entityMap,
    String? builtinPackageId,
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldEntity,
      entityId: entityId,
      scopeId: worldId,
      opType: OutboxOp.upsert,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'entity': entityMap,
        // ignore: use_null_aware_elements
        if (builtinPackageId != null) 'builtin_package_id': builtinPackageId,
      }),
    );
  }

  Future<void> enqueueWorldEntityDelete({
    required String worldId,
    required String entityId,
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldEntity,
      entityId: entityId,
      scopeId: worldId,
      opType: OutboxOp.delete,
      payloadJson: jsonEncode({'world_id': worldId}),
    );
  }

  Future<void> enqueueWorldCharacterUpsert({
    required String worldId,
    required Character character,
    Set<String> referencedEntityIds = const {},
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldCharacter,
      entityId: character.id,
      scopeId: worldId,
      opType: OutboxOp.upsert,
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
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldCharacter,
      entityId: characterId,
      scopeId: worldId,
      opType: OutboxOp.delete,
      payloadJson: jsonEncode({
        // ignore: use_null_aware_elements
        if (worldId != null) 'world_id': worldId,
      }),
    );
  }

  /// PR-SYNC-3: granular world state replaces the worlds.state_json blob.
  /// One row per world; coalesces against the same scopeId.
  Future<void> enqueueWorldMapData({
    required String worldId,
    required Map<String, dynamic> data,
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldMapData,
      entityId: worldId,
      scopeId: worldId,
      opType: OutboxOp.upsert,
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
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldSession,
      entityId: sessionId,
      scopeId: worldId,
      opType: OutboxOp.upsert,
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
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldSession,
      entityId: sessionId,
      scopeId: worldId,
      opType: OutboxOp.delete,
      payloadJson: jsonEncode({'world_id': worldId}),
    );
  }

  Future<void> enqueueWorldSettings({
    required String worldId,
    required Map<String, dynamic> settings,
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldSettings,
      entityId: worldId,
      scopeId: worldId,
      opType: OutboxOp.upsert,
      payloadJson: jsonEncode({'world_id': worldId, 'settings': settings}),
    );
  }

  /// PR-SYNC-3 transitional: full worlds.state_json push routed through
  /// the outbox. Coalesces per-world. Retired in PR-SYNC-6 once the
  /// granular tables are the only readers.
  Future<void> enqueueWorldState({
    required String worldId,
    required String worldName,
    String? templateId,
    String? templateHash,
    required Map<String, dynamic> state,
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldState,
      entityId: worldId,
      scopeId: worldId,
      opType: OutboxOp.upsert,
      payloadJson: jsonEncode({
        'world_id': worldId,
        'world_name': worldName,
        'template_id': ?templateId,
        'template_hash': ?templateHash,
        'state': state,
      }),
    );
  }

  /// PR-SYNC-5: DM shares a personal package into a world. Coalesced per
  /// (worldId, packageName) — same package re-shared collapses to one push.
  Future<void> enqueueWorldPackageShare({
    required String worldId,
    required String packageName,
    required Map<String, dynamic> state,
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldPackage,
      entityId: '$worldId:$packageName',
      scopeId: worldId,
      opType: OutboxOp.upsert,
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
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.worldPackage,
      entityId: '$worldId:$packageName',
      scopeId: worldId,
      opType: OutboxOp.delete,
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
  }) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.personalPackage,
      entityId: packageName,
      opType: OutboxOp.upsert,
      payloadJson: jsonEncode({'state': state}),
    );
  }

  Future<void> enqueuePersonalPackageDelete({required String packageName}) {
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: OutboxKind.personalPackage,
      entityId: packageName,
      opType: OutboxOp.delete,
      payloadJson: '{}',
    );
  }

  /// Cloud backup snapshot for a worldless / world-offline item. [type] is
  /// either `world`, `template`, `package`, or `character`.
  Future<void> enqueueCloudBackupUpsert({
    required String itemId,
    required String itemName,
    required String type,
    required Map<String, dynamic> data,
  }) {
    final kind = type == 'package' || type == 'template'
        ? OutboxKind.cloudBackupPackage
        : OutboxKind.cloudBackupWorld;
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: kind,
      entityId: '$type:$itemId',
      opType: OutboxOp.upsert,
      payloadJson: jsonEncode({
        'item_id': itemId,
        'item_name': itemName,
        'type': type,
        'data': data,
      }),
    );
  }

  Future<void> enqueueCloudBackupDelete({
    required String itemId,
    required String type,
  }) {
    final kind = type == 'package' || type == 'template'
        ? OutboxKind.cloudBackupPackage
        : OutboxKind.cloudBackupWorld;
    return _db.syncOutboxDao.enqueue(
      opId: _newOpId(),
      entityKind: kind,
      entityId: '$type:$itemId',
      opType: OutboxOp.delete,
      payloadJson: jsonEncode({'item_id': itemId, 'type': type}),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Drain loop
  // ────────────────────────────────────────────────────────────────────

  Future<void> _tick() async {
    if (_running || _paused) return;
    // Skip if signed out — there's nothing the server-side handlers can do.
    if (_ref.read(authProvider) == null) return;
    _running = true;
    try {
      var drained = 0;
      while (true) {
        final batch = await _db.syncOutboxDao.nextBatch(limit: _batchSize);
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
      debugPrint('SyncEngine tick error: $e\n$st');
    } finally {
      _running = false;
    }
  }

  Future<void> _handle(SyncOutboxRow row) async {
    if (row.attempts >= _dlqAttempts) {
      // Dead-lettered — leave in table for inspection, never retried.
      return;
    }
    try {
      switch (row.entityKind) {
        case OutboxKind.worldEntity:
          await _handleWorldEntity(row);
        case OutboxKind.worldCharacter:
          await _handleWorldCharacter(row);
        case OutboxKind.worldMapData:
          await _handleWorldMapData(row);
        case OutboxKind.worldSession:
          await _handleWorldSession(row);
        case OutboxKind.worldSettings:
          await _handleWorldSettings(row);
        case OutboxKind.worldState:
          await _handleWorldState(row);
        case OutboxKind.worldPackage:
          await _handleWorldPackage(row);
        case OutboxKind.personalPackage:
          await _handlePersonalPackage(row);
        case OutboxKind.cloudBackupWorld:
        case OutboxKind.cloudBackupPackage:
          await _handleCloudBackup(row);
        default:
          // Unknown kind — drop it so we don't loop forever.
          await _db.syncOutboxDao.deleteOp(row.opId);
          return;
      }
      await _db.syncOutboxDao.deleteOp(row.opId);
    } catch (e) {
      await _markRetry(row, e.toString());
    }
  }

  Future<void> _markRetry(SyncOutboxRow row, String error) async {
    final attempts = row.attempts + 1;
    final seconds = math
        .min(_maxBackoff.inSeconds, math.pow(2, attempts).toInt())
        .clamp(1, _maxBackoff.inSeconds);
    final delay = Duration(seconds: seconds);
    await _db.syncOutboxDao.markFailure(
      opId: row.opId,
      error: error,
      nextDelay: delay,
    );
    // Schedule a wake-up so we don't depend on the table-change stream
    // alone — important when the only retryable row is the one we just
    // bumped.
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      // ignore: discarded_futures
      _tick();
    });
  }

  // ── Handlers ───────────────────────────────────────────────────────

  Future<void> _handleWorldEntity(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final worldId = p['world_id'] as String;
    if (row.opType == OutboxOp.delete) {
      await mirror.deleteEntity(worldId: worldId, entityId: row.entityId);
      return;
    }
    final entityMap = (p['entity'] as Map).cast<String, dynamic>();
    await mirror.pushEntity(
      worldId: worldId,
      entityId: row.entityId,
      entityMap: entityMap,
      builtinPackageId: p['builtin_package_id'] as String?,
    );
  }

  Future<void> _handleWorldCharacter(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    if (row.opType == OutboxOp.delete) {
      await mirror.deleteCharacter(characterId: row.entityId);
      return;
    }
    final worldId = p['world_id'] as String;
    final char = Character.fromJson(
        (p['character'] as Map).cast<String, dynamic>());
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
    // Delete op: clear the row by upserting an empty blob. Granular delete
    // semantics are not exposed yet — the table is 1:1 with the world.
    final data = row.opType == OutboxOp.delete
        ? const <String, dynamic>{}
        : (p['data'] as Map).cast<String, dynamic>();
    await mirror.pushMapData(worldId: worldId, data: data);
  }

  Future<void> _handleWorldSession(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    if (row.opType == OutboxOp.delete) {
      await mirror.deleteSession(sessionId: row.entityId);
      return;
    }
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    await mirror.pushSession(
      worldId: p['world_id'] as String,
      sessionId: row.entityId,
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
    final settings = row.opType == OutboxOp.delete
        ? const <String, dynamic>{}
        : (p['settings'] as Map).cast<String, dynamic>();
    await mirror.pushSettings(worldId: worldId, settings: settings);
  }

  Future<void> _handleWorldState(SyncOutboxRow row) async {
    final mirror = _ref.read(worldMirrorServiceProvider);
    if (mirror == null) throw StateError('mirror service unavailable');
    if (row.opType == OutboxOp.delete) {
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
    if (row.opType == OutboxOp.delete) {
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
    // Personal package sync is beta-only.
    if (!_ref.read(isBetaActiveProvider)) {
      // Drop silently — outbox row goes away in [_handle].
      return;
    }
    if (row.opType == OutboxOp.delete) {
      await mirror.unpublishPersonalPackage(row.entityId);
      return;
    }
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    await mirror.pushPersonalPackage(
      packageName: row.entityId,
      state: (p['state'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> _handleCloudBackup(SyncOutboxRow row) async {
    if (!_ref.read(isBetaActiveProvider)) return;
    final repo = _ref.read(cloudBackupRepositoryProvider);
    final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    final itemId = p['item_id'] as String;
    final type = p['type'] as String;
    if (row.opType == OutboxOp.delete) {
      await repo.deleteBackupByItem(itemId, type);
      return;
    }
    final itemName = p['item_name'] as String;
    final data = (p['data'] as Map).cast<String, dynamic>();
    // Idempotency: hash the canonical payload + skip upload when the
    // matching cloud_backups row already carries the same payload_hash.
    // Same content saved 3x → uploaded once.
    final hash = _hashPayload(type, itemId, data);
    try {
      final remoteHash = await repo.fetchPayloadHashByItem(itemId, type);
      if (remoteHash == hash) {
        return;
      }
    } catch (_) {
      // Best-effort — on lookup failure fall through and re-upload.
    }
    await repo.uploadBackup(
      itemName,
      itemId,
      type,
      data,
      payloadHash: hash,
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

  // ── Utilities ──────────────────────────────────────────────────────

  static int _opSeq = 0;
  String _newOpId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    _opSeq = (_opSeq + 1) & 0x7fffffff;
    return 'op_${t}_$_opSeq';
  }
}
