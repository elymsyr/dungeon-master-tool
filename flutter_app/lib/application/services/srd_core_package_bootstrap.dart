import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import '../../domain/entities/schema/world_schema_hash.dart';

const _uuid = Uuid();

/// Canonical name of the built-in SRD content package. The package row is
/// owned by the app — never deleted by `getAvailableNames` cleanup, refreshed
/// on every app start so newly-authored Tier-1 rows land without a manual
/// reinstall.
const srdCorePackageName = 'SRD 5.2.1 Core';

/// Idempotent installer that materialises the hand-authored SRD 5.2.1
/// content pack as a real `Packages` row in the DB. Gated per DB instance
/// via [_installedFor] so an auth-driven DB swap (sign-in opens a new
/// user-scoped DB) re-installs into the new DB.
class SrdCorePackageBootstrap {
  final AppDatabase _db;
  SrdCorePackageBootstrap(this._db);

  /// Tracks DB instances that already have the pack installed in the
  /// current process. Weak by `identityHashCode` so disposed DBs don't
  /// leak entries (the same hashCode would only be reused after GC, and
  /// at that point a re-install is cheap and correct).
  static final Set<int> _installedFor = <int>{};

  Future<int> ensureInstalled() async {
    final key = identityHashCode(_db);
    if (_installedFor.contains(key)) return 0;

    // Defense-in-depth: if a previous session already materialised the pack
    // in this DB, skip work without relying solely on the in-memory set.
    final existingRow = await _findByName(srdCorePackageName);
    if (existingRow != null) {
      final entities = await _db.packagesDao.getEntities(existingRow.id);
      if (entities.isNotEmpty) {
        _installedFor.add(key);
        return 0;
      }
    }

    final build = generateBuiltinDnd5eV2Schema();
    final schema = build.schema;
    final pack = buildSrdCorePack();

    final inserted = await _db.transaction(() async {
      final existing = await _findByName(srdCorePackageName);
      final packageId = existing?.id ?? _uuid.v4();

      await _db.packagesDao.upsertPackage(PackagesCompanion(
        id: Value(packageId),
        name: const Value(srdCorePackageName),
        stateJson: Value(jsonEncode({
          'metadata': pack.metadata,
        })),
        updatedAt: Value(DateTime.now()),
      ));

      // Replace schema row.
      await _db.packagesDao.deleteSchemasByPackage(packageId);
      final schemaJson = schema.toJson();
      final currentHash = computeWorldSchemaContentHash(schema);
      final originalHash = schema.originalHash ?? currentHash;
      await _db.packagesDao.upsertSchema(PackageSchemasCompanion.insert(
        id: _uuid.v4(),
        packageId: packageId,
        name: Value(schema.name),
        version: Value(schema.version),
        description: Value(schema.description),
        categoriesJson: Value(jsonEncode(schemaJson['categories'] ?? [])),
        encounterConfigJson:
            Value(jsonEncode(schemaJson['encounterConfig'] ?? {})),
        encounterLayoutsJson:
            Value(jsonEncode(schemaJson['encounterLayouts'] ?? [])),
        metadataJson: Value(jsonEncode({
          if (schemaJson['metadata'] is Map)
            ...(schemaJson['metadata'] as Map).cast<String, dynamic>(),
          ...pack.metadata,
        })),
        templateId: Value(schema.schemaId),
        templateHash: Value(currentHash),
        templateOriginalHash: Value(originalHash),
      ));

      // Replace package entities.
      await _db.packagesDao.deleteEntitiesByPackage(packageId);

      final companions = <PackageEntitiesCompanion>[];

      // Mirror Tier-0 lookup seedRows into package_entities so the package's
      // visible entity count matches a freshly seeded world.
      for (final entry in build.seedRows.entries) {
        final slug = entry.key;
        for (final row in entry.value) {
          final name = (row['name'] as String?) ?? '';
          if (name.isEmpty) continue;
          companions.add(PackageEntitiesCompanion.insert(
            id: srdStableEntityId(slug, name),
            packageId: packageId,
            categorySlug: slug,
            name: name,
            source: const Value(srdSourceTag),
            description: Value((row['description'] as String?) ?? ''),
            fieldsJson:
                Value(jsonEncode(row['fields'] ?? <String, dynamic>{})),
          ));
        }
      }

      if (pack.entities.isEmpty && companions.isEmpty) return 0;

      for (final entry in pack.entities.entries) {
        final id = entry.key;
        final raw = Map<String, dynamic>.from(entry.value as Map);
        final attrs = raw['attributes'] is Map
            ? Map<String, dynamic>.from(raw['attributes'] as Map)
            : <String, dynamic>{};
        companions.add(PackageEntitiesCompanion.insert(
          id: id,
          packageId: packageId,
          categorySlug: raw['type'] as String? ?? 'unknown',
          name: raw['name'] as String? ?? 'Unnamed',
          source: Value((raw['source'] as String?) ?? srdSourceTag),
          description: Value((raw['description'] as String?) ?? ''),
          imagePath: Value((raw['image_path'] as String?) ?? ''),
          imagesJson: Value(jsonEncode(raw['images'] ?? const [])),
          tagsJson: Value(jsonEncode(raw['tags'] ?? const [])),
          dmNotes: Value((raw['dm_notes'] as String?) ?? ''),
          pdfsJson: Value(jsonEncode(raw['pdfs'] ?? const [])),
          locationId: Value(raw['location_id'] as String?),
          fieldsJson: Value(jsonEncode(attrs)),
        ));
      }

      await _db.packagesDao.upsertEntities(companions);

      return companions.length;
    });
    // Mark this DB instance as installed only after the transaction
    // succeeds; if it threw we want a retry on the next call rather than
    // a permanent lockout.
    _installedFor.add(key);
    return inserted;
  }

  Future<Package?> _findByName(String name) async {
    final all = await _db.packagesDao.getAll();
    for (final p in all) {
      if (p.name == name) return p;
    }
    return null;
  }

  static void resetInstallGate() {
    _installedFor.clear();
  }
}
