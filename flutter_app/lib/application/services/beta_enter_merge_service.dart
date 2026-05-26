import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/package_provider.dart';
import '../providers/sync_engine_provider.dart';
import '../providers/world_mirror_provider.dart';
import 'beta_enter_gate.dart';
import 'srd_core_package_bootstrap.dart';
import 'sync_engine.dart';
import 'sync_telemetry.dart' show SyncTelemetry, syncTelemetryProvider;
import 'world_mirror_service.dart';

/// First-time beta-enter merge: push every piece of owned local content to the
/// cloud BEFORE any cloud→local applier runs, so a stale cloud row from a prior
/// beta session can never overwrite (and wipe) the user's offline work.
///
/// Conflict policy on first enter: **local wins**. Subsequent enters fall back
/// to normal last-write-wins because the sentinel is set.
///
/// Lifecycle:
///   • [merge] is idempotent — the per-user sentinel
///     ([BetaEnterGate.markCompleted]) is set only after a clean pass.
///   • [BetaNotifier.leaveBeta] clears the sentinel so a future re-enter
///     re-runs this merge against potentially new local content.
class BetaEnterMergeService {
  BetaEnterMergeService({
    required this.ref,
    required this.client,
    required this.db,
    required this.repository,
    required this.mirror,
    required this.syncEngine,
    required this.gate,
  });

  final Ref ref;
  final SupabaseClient client;
  final AppDatabase db;
  final CampaignRepository repository;
  final WorldMirrorService mirror;
  final SyncEngine syncEngine;
  final BetaEnterGate gate;

  Future<MergeResult> merge() async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return const MergeResult.empty();
    if (await gate.isCompleted(uid)) return const MergeResult.alreadyMerged();

    final pushedWorlds = <String>[];
    final pushedChars = <String>[];
    final pushedPackages = <String>[];
    final failed = <String>[];

    // 1. Owned local worlds — push state + every granular table.
    final worlds = await db.worldsDao.getAll();
    for (final w in worlds) {
      if (w.ownerId != null && w.ownerId != uid) continue;
      try {
        await _pushWorld(w, uid);
        pushedWorlds.add(w.id);
      } catch (e, st) {
        debugPrint('BetaEnterMerge world ${w.id} error: $e\n$st');
        failed.add('world:${w.id}');
      }
    }

    // 2. Worldless / orphan-world chars — push via cloud_backup snapshot
    // (the canonical path for non-world-bound characters; see
    // CharacterListNotifier._cloudBackupPush).
    final worldIds = worlds.map((w) => w.id).toSet();
    final allChars = await db.worldCharactersDao.getAllChars();
    for (final c in allChars) {
      final boundToOwnedWorld =
          c.worldId.isNotEmpty && worldIds.contains(c.worldId);
      if (boundToOwnedWorld) continue;
      if (c.ownerId != null && c.ownerId != uid) continue;
      try {
        await _pushWorldlessChar(c);
        pushedChars.add(c.id);
      } catch (e, st) {
        debugPrint('BetaEnterMerge char ${c.id} error: $e\n$st');
        failed.add('char:${c.id}');
      }
    }

    // 3. Personal packages — push package row + each entity row.
    final packages = await db.packagesDao.getAll();
    for (final p in packages) {
      if (p.name == srdCorePackageName) continue;
      try {
        await _pushPackage(p);
        pushedPackages.add(p.name);
      } catch (e, st) {
        debugPrint('BetaEnterMerge package ${p.name} error: $e\n$st');
        failed.add('pkg:${p.name}');
      }
    }

    // 4. Drain the outbox so the enqueued upserts land before any cloud→local
    // applier runs. forceTick walks the outbox once; SyncEngine will keep
    // retrying anything that didn't land.
    try {
      await syncEngine.forceTick();
    } catch (e) {
      debugPrint('BetaEnterMerge forceTick error: $e');
    }

    // 5. Sentinel — set only when every row pushed cleanly. Partial failure
    // leaves the gate unset so the next merge retry covers the misses; the
    // wipe guards in PR-B1 keep local data safe in the interim.
    final telemetry = ref.read(syncTelemetryProvider);
    if (failed.isEmpty) {
      await gate.markCompleted(uid);
      await telemetry.incrementCounter(SyncTelemetry.betaEnterMergeCompleted);
    } else {
      debugPrint(
          'BetaEnterMerge: ${failed.length} failed rows — sentinel NOT set');
      for (var i = 0; i < failed.length; i++) {
        await telemetry.incrementCounter(SyncTelemetry.betaEnterMergeFailed);
      }
    }

    return MergeResult(
      pushedWorlds: pushedWorlds,
      pushedChars: pushedChars,
      pushedPackages: pushedPackages,
      failedIds: failed,
    );
  }

  Future<void> _pushWorld(World w, String uid) async {
    // Claim ownership locally so subsequent CDC echoes don't trip the
    // foreign-owned guard. Cloud `publish_world` RPC sets owner_id from
    // auth.uid() — local mirror must match.
    if (w.ownerId == null) {
      await (db.update(db.worlds)..where((t) => t.id.equals(w.id))).write(
        WorldsCompanion(
          ownerId: Value(uid),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }

    // Load the campaign blob (top-level fields only; granular tables ride
    // separately). repository.load reconstitutes the full entity map too,
    // but we only need the top-level keys for `state_json`.
    Map<String, dynamic> stateBlob = const <String, dynamic>{};
    try {
      final data = await repository.load(w.worldName);
      stateBlob = Map<String, dynamic>.from(data)
        ..remove('entities')
        ..remove('characters')
        ..remove('sessions')
        ..remove('map_data')
        ..remove('world_id');
    } catch (e) {
      debugPrint('BetaEnterMerge load world ${w.id} error: $e');
    }

    // worlds row — single RPC.
    await mirror.pushWorldState(
      worldId: w.id,
      worldName: w.worldName,
      templateId: w.templateId,
      templateHash: w.templateHash,
      stateJson: jsonEncode(stateBlob),
    );

    // Per-row enqueues — SyncEngine drains them on the next forceTick.
    final entities = await db.worldEntitiesDao.getByWorld(w.id);
    for (final e in entities) {
      await syncEngine.enqueueWorldEntityUpsert(
        worldId: w.id,
        entityId: e.id,
        entityMap: _entityRowToMap(e),
      );
    }

    final settings = await db.worldSettingsDao.get(w.id);
    if (settings != null) {
      Map<String, dynamic> decoded = const {};
      try {
        final v = jsonDecode(settings.settingsJson);
        if (v is Map) decoded = Map<String, dynamic>.from(v);
      } catch (_) {}
      await syncEngine.enqueueWorldSettings(
        worldId: w.id,
        settings: decoded,
      );
    }

    final mapData = await db.worldMapDataDao.get(w.id);
    if (mapData != null) {
      Map<String, dynamic> decoded = const {};
      try {
        final v = jsonDecode(mapData.dataJson);
        if (v is Map) decoded = Map<String, dynamic>.from(v);
      } catch (_) {}
      await syncEngine.enqueueWorldMapData(
        worldId: w.id,
        data: decoded,
      );
    }

    final sessions = await db.worldSessionsDao.getByWorld(w.id);
    for (final s in sessions) {
      Map<String, dynamic> decoded = const {};
      try {
        final v = jsonDecode(s.dataJson);
        if (v is Map) decoded = Map<String, dynamic>.from(v);
      } catch (_) {}
      await syncEngine.enqueueWorldSessionUpsert(
        worldId: w.id,
        sessionId: s.id,
        name: s.name,
        data: decoded,
        isActive: s.isActive,
        sortOrder: s.sortOrder,
      );
    }

    // World-bound chars belong with their world.
    final allChars = await db.worldCharactersDao.getAllChars();
    for (final c in allChars.where((c) => c.worldId == w.id)) {
      await _pushWorldBoundChar(c, w.id);
    }
  }

  Future<void> _pushWorldBoundChar(WorldCharacterRow c, String worldId) async {
    Map<String, dynamic> payload = const {};
    try {
      final v = jsonDecode(c.payloadJson);
      if (v is Map) payload = Map<String, dynamic>.from(v);
    } catch (_) {}
    Set<String> refs = const <String>{};
    try {
      final v = jsonDecode(c.referencedEntityIdsJson);
      if (v is List) refs = v.map((e) => e.toString()).toSet();
    } catch (_) {}
    // Character.fromJson tolerates a partial payload; the cloud mirror needs
    // the full row, so we hand back what we have.
    final character = _materializeCharacter(c, payload);
    await syncEngine.enqueueWorldCharacterUpsert(
      worldId: worldId,
      character: character,
      referencedEntityIds: refs,
    );
  }

  Future<void> _pushWorldlessChar(WorldCharacterRow c) async {
    // Worldless chars sync through cloud_backups (type='character'). See
    // CharacterListNotifier._cloudBackupPush.
    Map<String, dynamic> payload = const {};
    try {
      final v = jsonDecode(c.payloadJson);
      if (v is Map) payload = Map<String, dynamic>.from(v);
    } catch (_) {}
    await syncEngine.enqueueCloudBackupUpsert(
      itemId: c.id,
      itemName: c.templateName.isEmpty ? c.id : c.templateName,
      type: 'character',
      data: {'character': payload},
    );
  }

  Future<void> _pushPackage(Package p) async {
    // Package row — granular state minus entities (entities ride
    // per-row through personal_package_entities).
    Map<String, dynamic> stateBlob = const <String, dynamic>{};
    try {
      final loaded = await ref
          .read(packageRepositoryProvider)
          .load(p.name);
      stateBlob = Map<String, dynamic>.from(loaded)..remove('entities');
    } catch (e) {
      debugPrint('BetaEnterMerge load package ${p.name} error: $e');
    }
    await syncEngine.enqueuePersonalPackageUpsert(
      packageName: p.name,
      state: stateBlob,
    );
    // Entity rows.
    final entities = await db.packagesDao.getEntities(p.id);
    for (final e in entities) {
      await syncEngine.enqueuePersonalPackageEntityUpsert(
        packageName: p.name,
        entityId: e.id,
        entityMap: _packageEntityRowToMap(e),
      );
    }
  }

  Map<String, dynamic> _packageEntityRowToMap(PackageEntity e) {
    return <String, dynamic>{
      'type': e.categorySlug,
      'name': e.name,
      'source': e.source,
      'description': e.description,
      'image_path': e.imagePath,
      'images': _decodeJsonList(e.imagesJson),
      'tags': _decodeJsonList(e.tagsJson),
      'dm_notes': e.dmNotes,
      'pdfs': _decodeJsonList(e.pdfsJson),
      'location_id': e.locationId,
      'fields': _decodeJsonMap(e.fieldsJson),
    };
  }

  Map<String, dynamic> _entityRowToMap(WorldEntity e) {
    return <String, dynamic>{
      'type': e.categorySlug,
      'name': e.name,
      'source': e.source,
      'description': e.description,
      'image_path': e.imagePath,
      'images': _decodeJsonList(e.imagesJson),
      'tags': _decodeJsonList(e.tagsJson),
      'dm_notes': e.dmNotes,
      'pdfs': _decodeJsonList(e.pdfsJson),
      'location_id': e.locationId,
      'fields': _decodeJsonMap(e.fieldsJson),
      'package_id': e.packageId,
      'package_entity_id': e.packageEntityId,
      'linked': e.linked,
    };
  }

  List<dynamic> _decodeJsonList(String s) {
    try {
      final v = jsonDecode(s);
      return v is List ? v : const <dynamic>[];
    } catch (_) {
      return const <dynamic>[];
    }
  }

  Map<String, dynamic> _decodeJsonMap(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  /// Constructs the bare-minimum Character for the mirror push. The cloud
  /// `world_characters.payload_json` stores the same JSON we decode here; the
  /// downstream apply on other devices reads from `payload_json` directly, so
  /// we only need a Character instance whose `toJson()` round-trips the input.
  dynamic _materializeCharacter(
    WorldCharacterRow row,
    Map<String, dynamic> payload,
  ) {
    // ignore: avoid_dynamic_calls
    return _PayloadCharacter(
      id: row.id,
      ownerId: row.ownerId,
      worldId: row.worldId,
      templateId: row.templateId,
      templateName: row.templateName,
      updatedAt: row.updatedAt.toUtc().toIso8601String(),
      payload: payload,
    );
  }
}

/// Minimal Character look-alike: SyncEngine only reads `id`, `toJson()`,
/// `worldId`, `ownerId`, `templateId`, `templateName`, and `updatedAt` from
/// the value it gets. Using the domain Character requires a full deserialize
/// pass that may fail on legacy payloads; this shim keeps merge safe.
class _PayloadCharacter {
  _PayloadCharacter({
    required this.id,
    required this.ownerId,
    required this.worldId,
    required this.templateId,
    required this.templateName,
    required this.updatedAt,
    required this.payload,
  });

  final String id;
  final String? ownerId;
  final String worldId;
  final String templateId;
  final String templateName;
  final String updatedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => payload;
}

class MergeResult {
  const MergeResult({
    required this.pushedWorlds,
    required this.pushedChars,
    required this.pushedPackages,
    required this.failedIds,
    this.alreadyMerged = false,
  });

  const MergeResult.empty()
      : pushedWorlds = const <String>[],
        pushedChars = const <String>[],
        pushedPackages = const <String>[],
        failedIds = const <String>[],
        alreadyMerged = false;

  const MergeResult.alreadyMerged()
      : pushedWorlds = const <String>[],
        pushedChars = const <String>[],
        pushedPackages = const <String>[],
        failedIds = const <String>[],
        alreadyMerged = true;


  final List<String> pushedWorlds;
  final List<String> pushedChars;
  final List<String> pushedPackages;
  final List<String> failedIds;
  final bool alreadyMerged;

  bool get hasFailures => failedIds.isNotEmpty;
  int get totalPushed =>
      pushedWorlds.length + pushedChars.length + pushedPackages.length;
}

/// Returns null when Supabase is not configured (offline build / dev mode).
final betaEnterMergeServiceProvider =
    Provider<BetaEnterMergeService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  final mirror = ref.watch(worldMirrorServiceProvider);
  if (mirror == null) return null;
  return BetaEnterMergeService(
    ref: ref,
    client: Supabase.instance.client,
    db: ref.read(appDatabaseProvider),
    repository: ref.read(campaignRepositoryProvider),
    mirror: mirror,
    syncEngine: ref.read(syncEngineProvider),
    gate: ref.read(betaEnterGateProvider),
  );
});
