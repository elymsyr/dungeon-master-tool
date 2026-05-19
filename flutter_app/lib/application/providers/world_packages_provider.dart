import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../data/database/util/builtin_synth.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../services/package_import_service.dart';
import '../services/package_sync_service.dart';
import 'package_provider.dart';
import 'sync_engine_provider.dart';

/// PR-SYNC-5: stream of DM-shared world_packages rows for the given world.
/// Rows arrive via Supabase `world_packages` CDC + WorldMirrorApplier.
final worldPackagesProvider =
    StreamProvider.family<List<WorldPackage>, String>((ref, worldId) {
  final db = ref.watch(appDatabaseProvider);
  return db.worldPackagesDao.watchByWorld(worldId);
});

/// DM-only: share a local personal package into the active world. Reads
/// the package snapshot from [packageStateProvider] and enqueues a
/// world-package outbox row; SyncEngine drains via `share_package_to_world`.
/// Reader contract shared by Ref + WidgetRef so the helpers below work
/// from both notifiers and widgets without duplication.
typedef _RefRead = T Function<T>(ProviderListenable<T> p);

Future<void> _shareImpl(
  _RefRead read,
  String worldId,
  String packageName,
) async {
  final repo = read(packageRepositoryProvider);
  final data = await repo.load(packageName);
  final engine = read(syncEngineProvider);
  await engine.enqueueWorldPackageShare(
    worldId: worldId,
    packageName: packageName,
    state: data,
  );
  final db = read(appDatabaseProvider);
  // Echo the serialized form into the local mirror so the DM sees the row
  // immediately without waiting for the CDC round-trip. The temporary
  // package_id gets replaced by the server's canonical id on next CDC.
  await db.worldPackagesDao.upsert(
    WorldPackagesCompanion.insert(
      worldId: worldId,
      packageId: 'pending:$packageName',
      packageName: Value(packageName),
      stateJson: Value(jsonEncode(data)),
    ),
  );
  // Cascade: install pkg into DM's local world so entities populate
  // `world_entities`. Each row pushes through the outbox so other devices
  // see it via world_entities CDC.
  await _installPackageInWorld(db, worldId, packageName);
}

Future<void> _installPackageInWorld(
  AppDatabase db,
  String worldId,
  String packageName,
) async {
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
}

Future<void> _unshareImpl(
  _RefRead read,
  String worldId,
  String packageName,
  String packageId,
) async {
  final engine = read(syncEngineProvider);
  await engine.enqueueWorldPackageUnshare(
    worldId: worldId,
    packageName: packageName,
    packageId: packageId,
  );
  await read(appDatabaseProvider).worldPackagesDao.deleteByPackage(packageId);
}

Future<void> shareLocalPackageToWorld({
  required WidgetRef ref,
  required String worldId,
  required String packageName,
}) =>
    _shareImpl(ref.read, worldId, packageName);

Future<void> unshareWorldPackage({
  required WidgetRef ref,
  required String worldId,
  required String packageName,
  required String packageId,
}) =>
    _unshareImpl(ref.read, worldId, packageName, packageId);
