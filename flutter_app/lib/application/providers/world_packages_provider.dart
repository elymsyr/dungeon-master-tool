import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import 'package_link_provider.dart';
import 'package_provider.dart';
import 'world_mirror_provider.dart';

/// PR-SYNC-5: stream of DM-shared world_packages rows for the given world.
/// Rows arrive via Supabase `world_packages` CDC + WorldMirrorApplier.
final worldPackagesProvider =
    StreamProvider.family<List<WorldPackage>, String>((ref, worldId) {
  final db = ref.watch(appDatabaseProvider);
  return db.worldPackagesDao.watchByWorld(worldId);
});

/// DM-only: share a local personal package into the active world. Reads the
/// package snapshot and calls `share_package_to_world` directly — paket
/// paylaşımı DM'in bilinçli bir eylemi, arka planda drenajı beklenen bir
/// kuyruk satırı değil. Hata çağırana yükselir ki UI gösterebilsin.
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
  final mirror = read(worldMirrorServiceProvider);
  if (mirror == null) return;
  final serverId = await mirror.shareWorldPackage(
    worldId: worldId,
    packageName: packageName,
    state: data,
  );
  final db = read(appDatabaseProvider);
  // Local mirror row so the DM sees the share immediately. The RPC returns the
  // canonical id; fall back to a local placeholder only if it came back null.
  await db.worldPackagesDao.upsert(
    WorldPackagesCompanion.insert(
      worldId: worldId,
      packageId: serverId ?? 'pending:$packageName',
      packageName: Value(packageName),
      stateJson: Value(jsonEncode(data)),
    ),
  );
  // Cascade: install pkg into the DM's local world so entities populate.
  await _installPackageInWorld(read, worldId, packageName);
}

Future<void> _installPackageInWorld(
  _RefRead read,
  String worldId,
  String packageName,
) async {
  final db = read(appDatabaseProvider);
  final pkg = await db.packagesDao.getByName(packageName);
  if (pkg == null) return;
  // Installs the package plus everything it links, dependencies first.
  await read(worldPackageInstallerProvider)
      .installIntoWorld(worldId: worldId, packageId: pkg.id);
}

Future<void> _unshareImpl(
  _RefRead read,
  String worldId,
  String packageName,
  String packageId,
) async {
  final mirror = read(worldMirrorServiceProvider);
  if (mirror != null) {
    await mirror.unshareWorldPackage(packageId: packageId);
  }
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
