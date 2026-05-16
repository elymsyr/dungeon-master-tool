import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';

const _uuid = Uuid();

/// Result of a sync run against a single (world, package) pair.
class PackageSyncResult {
  final int added;
  final int updated;
  final int removed;
  final int detachedSurvived;

  const PackageSyncResult({
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
    this.detachedSurvived = 0,
  });

  int get total => added + updated + removed;
}

/// Live-link sync between an installed package and a world.
///
/// Behavior:
///   - new pack entity → insert as linked row in world
///   - existing pack entity, linked → overwrite row from pack
///   - existing pack entity, detached → leave alone (homebrew copy)
///   - removed pack entity, linked → delete from world
///   - removed pack entity, detached → keep, clear package_id (now full
///     homebrew, source becomes "Homebrew")
class PackageSyncService {
  final AppDatabase _db;
  PackageSyncService(this._db);

  /// Sync the world's linked entities to match the package's current
  /// state. Resolver translates Tier-0 lookup placeholders embedded in the
  /// package entity attributes — pass null when the package's pack rows
  /// already store resolved IDs.
  Future<PackageSyncResult> sync({
    required String worldId,
    required String packageId,
    Map<String, dynamic> Function(Map<String, dynamic> attrs)? resolveAttrs,
  }) async {
    return _db.transaction(() async {
      // Load current pack entities.
      final packRows = await _db.packagesDao.getEntities(packageId);
      final packById = {for (final r in packRows) r.id: r};

      // Load world-side entities tied to this package.
      final campRows = await (_db.select(_db.worldEntities)
            ..where((t) =>
                t.worldId.equals(worldId) &
                t.packageId.equalsExp(Variable<String>(packageId))))
          .get();
      final byPackEntId = <String, WorldEntity>{};
      for (final r in campRows) {
        if (r.packageEntityId != null) byPackEntId[r.packageEntityId!] = r;
      }

      // Build pack_id → world_id map. Existing rows reuse their UUIDs;
      // new pack rows get fresh UUIDs minted now so cross-references in
      // the same batch resolve in one pass.
      final packToWorld = <String, String>{};
      for (final pack in packRows) {
        final existing = byPackEntId[pack.id];
        packToWorld[pack.id] = existing?.id ?? _uuid.v4();
      }

      var added = 0;
      var updated = 0;
      var removed = 0;
      var detachedSurvived = 0;

      // Add + update.
      for (final pack in packRows) {
        final existing = byPackEntId[pack.id];
        final attrsRaw =
            jsonDecode(pack.fieldsJson) as Map<String, dynamic>? ?? const {};
        final attrsResolved = resolveAttrs != null
            ? resolveAttrs(Map<String, dynamic>.from(attrsRaw))
            : Map<String, dynamic>.from(attrsRaw);
        // Rewrite pack-side Tier-1 UUIDs to this world's UUIDs so
        // relations (class_refs, trait_refs, action_refs, …) resolve.
        final attrs = _remapPackRefs(attrsResolved, packToWorld)
            as Map<String, dynamic>;

        if (existing == null) {
          // New entity: insert linked.
          await _db.worldEntitiesDao.upsert(WorldEntitiesCompanion.insert(
            id: packToWorld[pack.id]!,
            worldId: worldId,
            categorySlug: pack.categorySlug,
            name: pack.name,
            source: Value(pack.source),
            description: Value(pack.description),
            imagePath: Value(pack.imagePath),
            imagesJson: Value(pack.imagesJson),
            tagsJson: Value(pack.tagsJson),
            dmNotes: Value(pack.dmNotes),
            pdfsJson: Value(pack.pdfsJson),
            locationId: Value(pack.locationId),
            fieldsJson: Value(jsonEncode(attrs)),
            packageId: Value(packageId),
            packageEntityId: Value(pack.id),
            linked: const Value(true),
          ));
          added++;
        } else if (existing.linked) {
          // Linked: overwrite from pack.
          await _db.worldEntitiesDao.upsert(WorldEntitiesCompanion(
            id: Value(existing.id),
            worldId: Value(worldId),
            categorySlug: Value(pack.categorySlug),
            name: Value(pack.name),
            source: Value(pack.source),
            description: Value(pack.description),
            imagePath: Value(pack.imagePath),
            imagesJson: Value(pack.imagesJson),
            tagsJson: Value(pack.tagsJson),
            dmNotes: Value(pack.dmNotes),
            pdfsJson: Value(pack.pdfsJson),
            locationId: Value(pack.locationId),
            fieldsJson: Value(jsonEncode(attrs)),
            packageId: Value(packageId),
            packageEntityId: Value(pack.id),
            linked: const Value(true),
            updatedAt: Value(DateTime.now()),
          ));
          updated++;
        }
        // else: detached, leave alone.
      }

      // Remove.
      for (final entry in byPackEntId.entries) {
        if (packById.containsKey(entry.key)) continue;
        final row = entry.value;
        if (row.linked) {
          await _db.worldEntitiesDao.deleteById(row.id);
          removed++;
        } else {
          // Detached: clear package_id, becomes pure homebrew.
          await _db.worldEntitiesDao.upsert(WorldEntitiesCompanion(
            id: Value(row.id),
            worldId: Value(row.worldId),
            categorySlug: Value(row.categorySlug),
            name: Value(row.name),
            packageId: const Value(null),
            packageEntityId: const Value(null),
            source: const Value('Homebrew'),
            updatedAt: Value(DateTime.now()),
          ));
          detachedSurvived++;
        }
      }

      await _db.installedPackagesDao.upsert(InstalledPackagesCompanion(
        worldId: Value(worldId),
        packageId: Value(packageId),
        lastSyncedAt: Value(DateTime.now()),
      ));

      return PackageSyncResult(
        added: added,
        updated: updated,
        removed: removed,
        detachedSurvived: detachedSurvived,
      );
    });
  }

  /// Remove a package from a world.
  ///
  /// [purgeDetached]:
  ///   - false (default): linked rows deleted, detached (user-edited) rows
  ///     kept as homebrew (package_id cleared, source → "Homebrew").
  ///   - true: every row tied to this package is deleted, including
  ///     user-edited detached copies.
  ///
  /// [extraScrubSlugs]: extra category slugs to wipe alongside the normal
  /// packageId match. Used to clean up legacy worlds where Tier-0 lookup
  /// rows were seeded without a packageId — caller passes the SRD pack's
  /// Tier-0 slugs so they get removed too. Only applied when
  /// [purgeDetached] is true.
  ///
  /// [extraScrubSource]: when set, only orphan rows whose `source` matches
  /// this value are deleted.
  Future<PackageSyncResult> uninstall({
    required String worldId,
    required String packageId,
    bool purgeDetached = false,
    Set<String> extraScrubSlugs = const {},
    String? extraScrubSource,
  }) async {
    return _db.transaction(() async {
      final rows = await (_db.select(_db.worldEntities)
            ..where((t) =>
                t.worldId.equals(worldId) &
                t.packageId.equals(packageId)))
          .get();
      var removed = 0;
      var detachedSurvived = 0;
      for (final row in rows) {
        if (row.linked || purgeDetached) {
          await _db.worldEntitiesDao.deleteById(row.id);
          removed++;
        } else {
          await _db.worldEntitiesDao.upsert(WorldEntitiesCompanion(
            id: Value(row.id),
            worldId: Value(row.worldId),
            categorySlug: Value(row.categorySlug),
            name: Value(row.name),
            packageId: const Value(null),
            packageEntityId: const Value(null),
            source: const Value('Homebrew'),
            updatedAt: Value(DateTime.now()),
          ));
          detachedSurvived++;
        }
      }
      if (purgeDetached && extraScrubSlugs.isNotEmpty) {
        final query = _db.select(_db.worldEntities)
          ..where((t) =>
              t.worldId.equals(worldId) &
              t.categorySlug.isIn(extraScrubSlugs) &
              t.packageId.isNull());
        if (extraScrubSource != null) {
          query.where((t) => t.source.equals(extraScrubSource));
        }
        final orphans = await query.get();
        for (final row in orphans) {
          await _db.worldEntitiesDao.deleteById(row.id);
          removed++;
        }
      }
      await _db.installedPackagesDao.deleteOne(worldId, packageId);
      return PackageSyncResult(
        removed: removed,
        detachedSurvived: detachedSurvived,
      );
    });
  }

  /// Walks [value] and replaces any string that matches a key in
  /// [packToWorld] with the mapped world-side UUID. Used to rewrite
  /// inter-Tier-1 relations (class_refs, trait_refs, action_refs, …) so
  /// they point at this world's row IDs instead of pack-side UUIDs.
  static dynamic _remapPackRefs(
      dynamic value, Map<String, String> packToWorld) {
    if (value is String) return packToWorld[value] ?? value;
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((k, v) {
        out[k.toString()] = _remapPackRefs(v, packToWorld);
      });
      return out;
    }
    if (value is List) {
      return value.map((e) => _remapPackRefs(e, packToWorld)).toList();
    }
    return value;
  }
}
