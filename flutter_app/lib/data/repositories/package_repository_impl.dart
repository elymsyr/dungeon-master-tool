import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/services/srd_core_package_bootstrap.dart';
import '../../core/utils/deep_copy.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/package_info.dart';
import '../../domain/entities/schema/world_schema.dart' as domain;
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/package_repository.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// PR-D4 v12 rewrite. Packages now route through `PackagesDao` (Packages +
/// PackageSchemas + PackageEntities) and trash through `TrashDao`. The old
/// `package_local_ds.dart` sidecar JSON store is gone.
class PackageRepositoryImpl implements PackageRepository {
  final AppDatabase _db;

  PackageRepositoryImpl(this._db);

  @override
  Future<List<String>> getAvailable() async {
    final rows = await _db.packagesDao.getAll();
    return rows.map((p) => p.name).toList()..sort();
  }

  @override
  Future<List<PackageInfo>> getPackageInfoList() async {
    final rows = await _db.packagesDao.getAll();
    final out = <PackageInfo>[];
    for (final pkg in rows) {
      final schemas = await _db.packagesDao.getSchemas(pkg.id);
      final entities = await _db.packagesDao.getEntities(pkg.id);
      out.add(PackageInfo(
        name: pkg.name,
        templateName:
            schemas.isNotEmpty ? schemas.first.name : '',
        entityCount: entities.length,
      ));
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>> load(String packageName) async {
    final existing = await _findByName(packageName);
    if (existing == null) {
      throw StateError('Package not found: $packageName');
    }
    return _loadFromDb(existing.id);
  }

  @override
  Future<void> save(String packageName, Map<String, dynamic> data) async {
    if (packageName == srdCorePackageName) {
      // Built-in pack is regenerated from code on every app start.
      return;
    }
    final existing = await _findByName(packageName);
    if (existing != null) {
      await _saveToDb(existing.id, packageName, data);
      return;
    }
    final packageId = data['package_id'] as String? ?? _uuid.v4();
    data['package_id'] = packageId;
    await _db.packagesDao.upsertPackage(PackagesCompanion.insert(
      id: packageId,
      name: packageName,
    ));
    await _saveToDb(packageId, packageName, data);
  }

  @override
  Future<void> delete(String packageName) async {
    if (packageName == srdCorePackageName) {
      // Built-in pack — protected. UI also blocks Delete; this is the
      // belt-and-suspenders fallback for any non-UI caller.
      return;
    }
    final existing = await _findByName(packageName);
    if (existing == null) return;

    // Snapshot for trash row before cascade wipe.
    Map<String, dynamic> snapshot = const {};
    try {
      snapshot = await _loadFromDb(existing.id);
    } catch (_) {}
    await _db.trashDao.upsert(TrashItemsCompanion.insert(
      id: _uuid.v4(),
      kind: 'package',
      sourceId: existing.id,
      payloadJson: jsonEncode({
        ...snapshot,
        '_original_name': packageName,
      }),
    ));

    await _purgePackage(existing.id);
  }

  /// Restore a soft-deleted package from `trash_items`. UI passes the trash
  /// row id; previously this was a directory name on disk.
  @override
  Future<bool> restoreFromTrash(String trashId) async {
    final trash = await _db.trashDao.getById(trashId);
    if (trash == null || trash.kind != 'package') return false;
    try {
      final payload = jsonDecode(trash.payloadJson) as Map<String, dynamic>;
      final originalName = (payload.remove('_original_name') as String?) ??
          (payload['package_name'] as String?) ??
          trash.sourceId;
      // Conflict — skip restore if a package with that name already exists.
      final clash = await _findByName(originalName);
      if (clash != null) {
        await _db.trashDao.deleteById(trashId);
        return false;
      }
      await save(originalName, payload);
      await _db.trashDao.deleteById(trashId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> permanentlyDelete(String trashId) =>
      _db.trashDao.deleteById(trashId);

  @override
  Future<String> create(String packageName,
      {domain.WorldSchema? template}) async {
    final existing = await _findByName(packageName);
    if (existing != null) {
      throw StateError('Package already exists: $packageName');
    }

    final packageId = _uuid.v4();
    final schema = template;

    await _db.packagesDao.upsertPackage(PackagesCompanion.insert(
      id: packageId,
      name: packageName,
    ));

    if (schema != null) {
      final schemaJson =
          deepCopyJson(schema.toJson()) as Map<String, dynamic>;
      final currentHash = computeWorldSchemaContentHash(schema);
      final originalHash = schema.originalHash ?? currentHash;
      await _db.packagesDao.upsertSchema(PackageSchemasCompanion.insert(
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
  Future<void> saveEntity(
    String packageName,
    String entityId,
    Map<String, dynamic> row,
  ) async {
    if (packageName == srdCorePackageName) return;
    final existing = await _findByName(packageName);
    if (existing == null) {
      throw StateError('Package not found: $packageName');
    }
    final packageId = existing.id;
    await _db.transaction(() async {
      await _db.packagesDao
          .upsertEntity(_packageEntityCompanion(packageId, entityId, row));
      await _touchPackage(packageId, packageName);
    });
  }

  @override
  Future<void> deleteEntity(String packageName, String entityId) async {
    if (packageName == srdCorePackageName) return;
    final existing = await _findByName(packageName);
    if (existing == null) return;
    final packageId = existing.id;
    await _db.transaction(() async {
      await _db.packagesDao.deleteEntity(entityId);
      await _touchPackage(packageId, packageName);
    });
  }

  @override
  Future<void> saveStatePatch(
    String packageName,
    Map<String, dynamic> patch,
  ) async {
    if (packageName == srdCorePackageName) return;
    if (patch.isEmpty) return;
    final existing = await _findByName(packageName);
    if (existing == null) {
      throw StateError('Package not found: $packageName');
    }
    final packageId = existing.id;
    await _db.transaction(() async {
      final pkg = await _db.packagesDao.getById(packageId);
      final merged = <String, dynamic>{};
      if (pkg != null && pkg.stateJson.isNotEmpty && pkg.stateJson != '{}') {
        try {
          final decoded = jsonDecode(pkg.stateJson);
          if (decoded is Map) {
            merged.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
      merged.addAll(patch);
      await _db.packagesDao.upsertPackage(PackagesCompanion(
        id: Value(packageId),
        name: Value(packageName),
        stateJson: Value(jsonEncode(merged)),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }

  Future<void> _touchPackage(String packageId, String packageName) async {
    await _db.packagesDao.upsertPackage(PackagesCompanion(
      id: Value(packageId),
      name: Value(packageName),
      updatedAt: Value(DateTime.now()),
    ));
  }

  PackageEntitiesCompanion _packageEntityCompanion(
    String packageId,
    String entityId,
    Map<String, dynamic> m,
  ) {
    return PackageEntitiesCompanion.insert(
      id: entityId,
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
  }

  @override
  Future<String> copy({
    required String sourceName,
    required String destinationName,
  }) async {
    if (destinationName == srdCorePackageName) {
      throw StateError('Cannot overwrite the built-in package');
    }
    final existing = await _findByName(destinationName);
    if (existing != null) {
      throw StateError('Package already exists: $destinationName');
    }
    final src = await _findByName(sourceName);
    if (src == null) {
      throw StateError('Source package not found: $sourceName');
    }

    final srcData = await _loadFromDb(src.id);
    final newId = _uuid.v4();

    srcData['package_id'] = newId;
    srcData['package_name'] = destinationName;
    srcData.remove('marketplace_listing_id');
    srcData.remove('marketplace_version');

    await _db.packagesDao.upsertPackage(PackagesCompanion.insert(
      id: newId,
      name: destinationName,
    ));
    await _saveToDb(newId, destinationName, srcData);
    return destinationName;
  }

  // --- Internal helpers ---

  Future<Package?> _findByName(String name) async {
    final all = await _db.packagesDao.getAll();
    for (final p in all) {
      if (p.name == name) return p;
    }
    return null;
  }

  Future<Map<String, dynamic>> _loadFromDb(String packageId) async {
    final pkg = await _db.packagesDao.getById(packageId);
    if (pkg == null) throw StateError('Package not found: $packageId');

    final schemas = await _db.packagesDao.getSchemas(packageId);
    final schemaRow = schemas.isNotEmpty ? schemas.first : null;

    final entityRows = await _db.packagesDao.getEntities(packageId);
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

    // Reconstruct WorldSchema map from the package_schemas row.
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

    // Unpack the stateJson sidecar (metadata, marketplace fields, etc.) so
    // callers see the dynamic state they wrote via save().
    final stateBlob = <String, dynamic>{};
    if (pkg.stateJson.isNotEmpty && pkg.stateJson != '{}') {
      try {
        final decoded = jsonDecode(pkg.stateJson);
        if (decoded is Map) {
          stateBlob.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    return {
      ...stateBlob,
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

  Future<void> _saveToDb(
    String packageId,
    String packageName,
    Map<String, dynamic> data,
  ) async {
    final stateBlob = <String, dynamic>{};
    for (final entry in data.entries) {
      if (_typedTopKeys.contains(entry.key)) continue;
      stateBlob[entry.key] = entry.value;
    }
    final stateJsonStr = jsonEncode(stateBlob);

    await _db.transaction(() async {
      await _db.packagesDao.upsertPackage(PackagesCompanion(
        id: Value(packageId),
        name: Value(packageName),
        stateJson: Value(stateJsonStr),
        updatedAt: Value(DateTime.now()),
      ));

      // Entities — full replace strategy. F5 (row-level personal pkg) routes
      // per-mutation through [saveEntity]; this bulk path stays as the
      // import/restore safety net.
      await _db.packagesDao.deleteEntitiesByPackage(packageId);
      final entities = data['entities'] as Map<String, dynamic>? ?? {};
      if (entities.isNotEmpty) {
        final companions = entities.entries.map((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          return _packageEntityCompanion(packageId, e.key, m);
        }).toList();
        await _db.packagesDao.upsertEntities(companions);
      }

      // Schema — also full replace.
      final schemaData = data['world_schema'] as Map<String, dynamic>?;
      if (schemaData != null) {
        await _db.packagesDao.deleteSchemasByPackage(packageId);

        String pickStr(String camel, String snake, [String fallback = '']) =>
            (schemaData[camel] ?? schemaData[snake] ?? fallback) as String;
        dynamic pickAny(String camel, String snake) =>
            schemaData[camel] ?? schemaData[snake];

        final templateId = data['template_id'] as String?;
        final templateHash = data['template_hash'] as String?;
        final templateOriginalHash =
            data['template_original_hash'] as String?;
        await _db.packagesDao.upsertSchema(PackageSchemasCompanion.insert(
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
        ));
      }
    });
  }

  Future<void> _purgePackage(String packageId) async {
    await _db.transaction(() async {
      await _db.packagesDao.deleteEntitiesByPackage(packageId);
      await _db.packagesDao.deleteSchemasByPackage(packageId);
      await _db.packagesDao.deletePackage(packageId);
    });
  }
}
