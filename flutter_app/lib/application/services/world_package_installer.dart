import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/database/util/builtin_synth.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/repositories/package_repository.dart';
import 'package_import_service.dart';
import 'package_link_service.dart';
import 'package_sync_service.dart';
import 'srd_core_package_bootstrap.dart' show srdCorePackageName;

/// Result of installing one package (and its link closure) into a world.
class WorldInstallResult {
  /// Per-package sync results, in the order they were installed (dependencies
  /// first, the requested package last).
  final List<({String packageId, String packageName, PackageSyncResult sync})>
      installed;

  const WorldInstallResult(this.installed);

  int get added => installed.fold(0, (n, r) => n + r.sync.added);
  int get updated => installed.fold(0, (n, r) => n + r.sync.updated);
  int get removed => installed.fold(0, (n, r) => n + r.sync.removed);

  /// Packages pulled in purely because the requested one links them.
  int get dependencyCount => installed.length > 1 ? installed.length - 1 : 0;
}

/// The single entry point for "install a package into a world".
///
/// Replaces the three hand-rolled copies of the same "register the link, build
/// the Tier-0 lookup index, sync" block (import dialog, DM package share,
/// world settings re-sync) and adds the two things a link-aware install needs:
///
///   1. **Closure install** — a package's linked packages are installed too,
///      dependencies first, so linked content is present in the world.
///   2. **Cross-package ref remap** — refs pointing at a linked package's
///      entities are rewritten to that package's world-side ids (see
///      [buildForeignRefIndex]).
///
/// Uninstall deliberately does NOT cascade: dependencies stay installed and
/// the user removes them explicitly. `installed_packages` has no
/// "installed as a dependency" column, and adding one would bump the Drift
/// schema past the v12 fresh cut (which renames every existing user DB), so
/// provenance simply is not tracked.
class WorldPackageInstaller {
  final AppDatabase _db;
  final PackageRepository _repo;

  WorldPackageInstaller(this._db, this._repo);

  PackageLinkService get _links => PackageLinkService(_db, _repo);

  /// Installs [packageId] and everything it links into [worldId].
  ///
  /// Returns one entry per installed package. A package whose row is missing
  /// yields an empty result rather than throwing.
  Future<WorldInstallResult> installIntoWorld({
    required String worldId,
    required String packageId,
  }) async {
    final root = await _db.packagesDao.getById(packageId);
    if (root == null) return const WorldInstallResult([]);

    // Dependency order: closure() returns links first, the root last.
    final order = await _links.closure(root.name);
    final chain = order.isEmpty ? [root] : order;

    // Register every link up front so a package syncing early can already see
    // its siblings in `installed_packages`.
    for (final pkg in chain) {
      await _db.installedPackagesDao.upsert(InstalledPackagesCompanion.insert(
        worldId: worldId,
        packageId: pkg.id,
        packageName: Value(pkg.name),
      ));
    }

    final resolveAttrs = await buildLookupResolver(worldId);
    final results =
        <({String packageId, String packageName, PackageSyncResult sync})>[];
    final sync = PackageSyncService(_db);

    for (final pkg in chain) {
      // Rebuilt per package: syncing a dependency mints its world rows, and
      // the next package in the chain must see those ids to remap its refs.
      final foreignRefs = await buildForeignRefIndex(worldId);
      final result = await sync.sync(
        worldId: worldId,
        packageId: pkg.id,
        resolveAttrs: resolveAttrs,
        foreignRefs: foreignRefs,
      );
      results.add((packageId: pkg.id, packageName: pkg.name, sync: result));
    }

    return WorldInstallResult(results);
  }

  /// Re-syncs an already-installed package (and its links) — same path as
  /// install, since [PackageSyncService.sync] is idempotent.
  Future<WorldInstallResult> resync({
    required String worldId,
    required String packageId,
  }) =>
      installIntoWorld(worldId: worldId, packageId: packageId);

  /// Removes ONE package from the world. Linked packages stay installed.
  Future<PackageSyncResult> uninstallFromWorld({
    required String worldId,
    required String packageId,
    bool purgeDetached = false,
  }) {
    return PackageSyncService(_db).uninstall(
      worldId: worldId,
      packageId: packageId,
      purgeDetached: purgeDetached,
    );
  }

  /// `packageEntityId → world-side id` for every entity already present in
  /// [worldId], regardless of which package owns it.
  ///
  /// Two sources, in precedence order:
  ///   1. Built-in SRD pack — its rows are never materialised in
  ///      `world_entities`; they are synthesised at read time under
  ///      [synthBuiltinEntityId]. A ref into an SRD spell resolves here.
  ///   2. Real `world_entities` rows carrying a `package_entity_id` — every
  ///      other installed package, including ones synced moments ago in the
  ///      same closure run. These win, matching `buildTier0LookupIndex`
  ///      (a homebrew fork overrides the pristine pack entry).
  Future<Map<String, String>> buildForeignRefIndex(String worldId) async {
    final out = <String, String>{};

    final installed = await _db.installedPackagesDao.getByWorld(worldId);
    for (final link in installed) {
      final pkg = await _db.packagesDao.getById(link.packageId);
      if (pkg == null || pkg.name != srdCorePackageName) continue;
      for (final row in await _db.packagesDao.getEntities(pkg.id)) {
        out[row.id] = synthBuiltinEntityId(worldId, row.id);
      }
    }

    final rows = await (_db.select(_db.worldEntities)
          ..where((t) =>
              t.worldId.equals(worldId) & t.packageEntityId.isNotNull()))
        .get();
    for (final row in rows) {
      final packEntityId = row.packageEntityId;
      if (packEntityId != null) out[packEntityId] = row.id;
    }

    return out;
  }

  /// Tier-0 `_lookup` placeholder resolver for [worldId], ready to hand to
  /// [PackageSyncService.sync]. Wraps [buildTier0LookupIndex] so callers stop
  /// re-deriving the seed slug set themselves.
  Future<Map<String, dynamic> Function(Map<String, dynamic>)>
      buildLookupResolver(String worldId) async {
    final build = generateBuiltinDnd5eV2Schema();
    final tier0Index = await buildTier0LookupIndex(
      _db,
      worldId,
      tier0Slugs: build.seedRows.keys.toSet(),
    );
    return (attrs) => PackageImportService.resolveLookupPlaceholder(
          attrs,
          tier0Index,
        ) as Map<String, dynamic>;
  }
}
