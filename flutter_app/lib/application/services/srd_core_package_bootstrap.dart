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
/// content pack as a real `Packages` row in the DB. Runs once per app
/// session (gated by [_installed]).
class SrdCorePackageBootstrap {
  final AppDatabase _db;
  SrdCorePackageBootstrap(this._db);

  static bool _installed = false;

  Future<int> ensureInstalled() async {
    if (_installed) return 0;
    _installed = true;

    final build = generateBuiltinDnd5eV2Schema();
    final schema = build.schema;
    final pack = buildSrdCorePack();

    return _db.transaction(() async {
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
  }

  Future<Package?> _findByName(String name) async {
    final all = await _db.packagesDao.getAll();
    for (final p in all) {
      if (p.name == name) return p;
    }
    return null;
  }

  static void resetInstallGate() {
    _installed = false;
  }
}
