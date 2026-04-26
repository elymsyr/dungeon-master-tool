import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/services/srd_core_package_bootstrap.dart';
import '../../core/utils/deep_copy.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/world_schema.dart' as domain;
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/package_repository.dart';
import '../database/app_database.dart' hide WorldSchema;
import '../datasources/local/package_local_ds.dart';

const _uuid = Uuid();

/// Drift-backed PackageRepository implementasyonu.
class PackageRepositoryImpl implements PackageRepository {
  final AppDatabase _db;
  final PackageLocalDataSource _localDs;

  PackageRepositoryImpl(this._db, this._localDs);

  @override
  Future<List<String>> getAvailable() async {
    return _db.packageDao.getAvailableNames();
  }

  @override
  Future<List<PackageInfo>> getPackageInfoList() async {
    final rows = await _db.packageDao.getPackageInfoList();
    return rows
        .map((r) => PackageInfo(
              name: r.name,
              templateName: r.templateName,
              entityCount: r.entityCount,
            ))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> load(String packageName) async {
    final existing = await _db.packageDao.getByName(packageName);
    if (existing == null) {
      throw StateError('Package not found: $packageName');
    }
    return _loadFromDb(existing.id);
  }

  @override
  Future<void> save(String packageName, Map<String, dynamic> data) async {
    if (packageName == srdCorePackageName) {
      // Built-in pack is regenerated from code on every app start.
      // Silently swallow saves so accidental "Save" presses can't corrupt
      // the canonical content.
      return;
    }
    final existing = await _db.packageDao.getByName(packageName);
    if (existing != null) {
      await _saveToDb(existing.id, data);
    } else {
      final packageId = data['package_id'] as String? ?? _uuid.v4();
      data['package_id'] = packageId;
      await _db.packageDao.createPackage(PackagesCompanion.insert(
        id: packageId,
        name: packageName,
      ));
      await _saveToDb(packageId, data);
    }
  }

  @override
  Future<void> delete(String packageName) async {
    if (packageName == srdCorePackageName) {
      // Built-in pack — protected. UI also blocks Delete; this is the
      // belt-and-suspenders fallback for any non-UI caller.
      return;
    }
    final existing = await _db.packageDao.getByName(packageName);
    Map<String, dynamic>? data;
    if (existing != null) {
      // Veriyi DB'den silmeden önce yedekle (trash restore için)
      try {
        data = await _loadFromDb(existing.id);
      } catch (_) {}
      await _db.packageDao.deletePackage(existing.id);
    }
    await _localDs.moveToTrash(packageName, data: data);
  }

  @override
  Future<String> create(String packageName,
      {domain.WorldSchema? template}) async {
    final existing = await _db.packageDao.getByName(packageName);
    if (existing != null) {
      throw StateError('Package already exists: $packageName');
    }

    final packageId = _uuid.v4();
    final schema = template;

    await _db.packageDao.createPackage(PackagesCompanion.insert(
      id: packageId,
      name: packageName,
    ));

    if (schema != null) {
      final schemaJson =
          deepCopyJson(schema.toJson()) as Map<String, dynamic>;
      final currentHash = computeWorldSchemaContentHash(schema);
      final originalHash = schema.originalHash ?? currentHash;
      await (_db.into(_db.packageSchemas))
          .insert(PackageSchemasCompanion.insert(
        id: _uuid.v4(),
        packageId: packageId,
        name: Value(schema.name),
        version: Value(schema.version),
        categoriesJson: Value(jsonEncode(schemaJson['categories'] ?? [])),
        encounterConfigJson:
            Value(jsonEncode(schemaJson['encounterConfig'] ?? {})),
        encounterLayoutsJson:
            Value(jsonEncode(schemaJson['encounterLayouts'] ?? [])),
        metadataJson: Value(jsonEncode(schemaJson['metadata'] ?? {})),
        templateId: Value(schema.schemaId),
        templateHash: Value(currentHash),
        templateOriginalHash: Value(originalHash),
      ));
    }

    return packageName;
  }

  @override
  Future<String> copy({
    required String sourceName,
    required String destinationName,
  }) async {
    if (destinationName == srdCorePackageName) {
      throw StateError('Cannot overwrite the built-in package');
    }
    final existing = await _db.packageDao.getByName(destinationName);
    if (existing != null) {
      throw StateError('Package already exists: $destinationName');
    }
    final src = await _db.packageDao.getByName(sourceName);
    if (src == null) {
      throw StateError('Source package not found: $sourceName');
    }

    final srcData = await _loadFromDb(src.id);
    final newId = _uuid.v4();

    // Strip identity so `_saveToDb` writes a fresh row keyed by newId.
    srcData['package_id'] = newId;
    srcData['package_name'] = destinationName;
    // Reset cloud provenance — the new copy has no upstream binding.
    srcData.remove('marketplace_listing_id');
    srcData.remove('marketplace_version');

    await _db.packageDao.createPackage(PackagesCompanion.insert(
      id: newId,
      name: destinationName,
    ));
    await _saveToDb(newId, srcData);
    return destinationName;
  }

  // --- Internal helpers ---

  Future<Map<String, dynamic>> _loadFromDb(String packageId) async {
    final pkg = await _db.packageDao.getById(packageId);
    if (pkg == null) throw StateError('Package not found: $packageId');

    // Schema
    final schemaRow = await (_db.select(_db.packageSchemas)
          ..where((t) => t.packageId.equals(packageId)))
        .getSingleOrNull();

    // Entities
    final entityRows = await _db.packageDao.getAllEntities(packageId);
    final entitiesMap = <String, dynamic>{};
    for (final e in entityRows) {
      entitiesMap[e.id] = {
        'name': e.name,
        'type': e.categorySlug,
        'source': e.source,
        'description': e.description,
        'image_path': e.imagePath,
        'images': jsonDecode(e.imagesJson),
        'tags': jsonDecode(e.tagsJson),
        'dm_notes': e.dmNotes,
        'pdfs': jsonDecode(e.pdfsJson),
        'location_id': e.locationId,
        'attributes': jsonDecode(e.fieldsJson),
      };
    }

    // WorldSchema reconstruct
    Map<String, dynamic>? worldSchemaMap;
    String? templateId;
    String? templateHash;
    String? templateOriginalHash;
    if (schemaRow != null) {
      worldSchemaMap = {
        'schemaId': schemaRow.id,
        'name': schemaRow.name,
        'version': schemaRow.version,
        'baseSystem': schemaRow.baseSystem,
        'description': schemaRow.description,
        'categories': jsonDecode(schemaRow.categoriesJson),
        'encounterConfig': jsonDecode(schemaRow.encounterConfigJson),
        'encounterLayouts': jsonDecode(schemaRow.encounterLayoutsJson),
        'metadata': jsonDecode(schemaRow.metadataJson),
        'createdAt': schemaRow.createdAt.toIso8601String(),
        'updatedAt': schemaRow.updatedAt.toIso8601String(),
      };
      templateId = schemaRow.templateId;
      templateHash = schemaRow.templateHash;
      templateOriginalHash = schemaRow.templateOriginalHash;
    }

    return {
      'package_id': pkg.id,
      'package_name': pkg.name,
      'created_at': pkg.createdAt.toIso8601String(),
      'entities': entitiesMap,
      'world_schema': ?worldSchemaMap,
      'template_id': ?templateId,
      'template_hash': ?templateHash,
      'template_original_hash': ?templateOriginalHash,
    };
  }

  static const _typedTopKeys = <String>{
    'package_id',
    'package_name',
    'created_at',
    'entities',
    'world_schema',
    'template_id',
    'template_hash',
    'template_original_hash',
  };

  Future<void> _saveToDb(String packageId, Map<String, dynamic> data) async {
    final stateBlob = <String, dynamic>{};
    for (final entry in data.entries) {
      if (_typedTopKeys.contains(entry.key)) continue;
      stateBlob[entry.key] = entry.value;
    }
    final stateJsonStr = jsonEncode(stateBlob);

    await _db.transaction(() async {
      await _db.packageDao.updatePackage(PackagesCompanion(
        id: Value(packageId),
        name: Value(data['package_name'] as String? ?? ''),
        stateJson: Value(stateJsonStr),
        updatedAt: Value(DateTime.now()),
      ));

      // Entities — full replace strategy
      await (_db.delete(_db.packageEntities)
            ..where((t) => t.packageId.equals(packageId)))
          .go();
      final entities = data['entities'] as Map<String, dynamic>? ?? {};
      if (entities.isNotEmpty) {
        final companions = entities.entries.map((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          return PackageEntitiesCompanion.insert(
            id: e.key,
            packageId: packageId,
            categorySlug: (m['type'] as String? ?? 'npc')
                .toLowerCase()
                .replaceAll(' ', '-'),
            name: m['name'] as String? ?? 'Unknown',
            source: Value(m['source'] as String? ?? ''),
            description: Value(m['description'] as String? ?? ''),
            imagePath: Value(m['image_path'] as String? ?? ''),
            imagesJson: Value(jsonEncode(m['images'] ?? [])),
            tagsJson: Value(jsonEncode(m['tags'] ?? [])),
            dmNotes: Value(m['dm_notes'] as String? ?? ''),
            pdfsJson: Value(jsonEncode(m['pdfs'] ?? [])),
            locationId: Value(m['location_id'] as String?),
            fieldsJson: Value(jsonEncode(m['attributes'] ?? {})),
          );
        }).toList();
        await _db.packageDao.insertAllEntities(companions);
      }

      // Schema
      final schemaData = data['world_schema'] as Map<String, dynamic>?;
      if (schemaData != null) {
        await (_db.delete(_db.packageSchemas)
              ..where((t) => t.packageId.equals(packageId)))
            .go();

        String pickStr(String camel, String snake, [String fallback = '']) =>
            (schemaData[camel] ?? schemaData[snake] ?? fallback) as String;
        dynamic pickAny(String camel, String snake) =>
            schemaData[camel] ?? schemaData[snake];

        final templateId = data['template_id'] as String?;
        final templateHash = data['template_hash'] as String?;
        final templateOriginalHash =
            data['template_original_hash'] as String?;
        await (_db.into(_db.packageSchemas)).insert(
          PackageSchemasCompanion.insert(
            id: pickStr('schemaId', 'schema_id', _uuid.v4()),
            packageId: packageId,
            name: Value(schemaData['name'] as String? ?? ''),
            version: Value(schemaData['version'] as String? ?? '1.0'),
            description: Value(schemaData['description'] as String? ?? ''),
            categoriesJson:
                Value(jsonEncode(schemaData['categories'] ?? [])),
            encounterConfigJson: Value(jsonEncode(
                pickAny('encounterConfig', 'encounter_config') ?? {})),
            encounterLayoutsJson: Value(jsonEncode(
                pickAny('encounterLayouts', 'encounter_layouts') ?? [])),
            metadataJson: Value(jsonEncode(schemaData['metadata'] ?? {})),
            templateId: Value(templateId),
            templateHash: Value(templateHash),
            templateOriginalHash: Value(templateOriginalHash),
          ),
        );
      }
    });
  }
}
