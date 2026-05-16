import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package_import_service.dart';
import 'srd_core_package_bootstrap.dart' show srdCorePackageName;

const _uuid = Uuid();

/// One-shot bootstrap that seeds a freshly-created v2 D&D 5e world with:
///   1. Tier-0 lookup rows from [BuiltinDnd5eV2Build.seedRows].
///   2. The hand-authored SRD 5.2.1 content pack from [buildSrdCorePack].
///
/// Operates directly on [AppDatabase] (not via [EntityNotifier]) because it
/// runs during `WorldRepositoryImpl.create`, before any world is loaded.
///
/// Idempotency: tracks `_srdCoreImportedAt` inside `world_settings.settings_json`.
/// `builtin-dnd5e-default` (v1) worlds are intentionally skipped.
class SrdCoreBootstrap {
  final AppDatabase _db;
  SrdCoreBootstrap(this._db);

  /// Tier-0 `(slug, name) -> uuid` index built during seeding; consumed by
  /// the SRD pack import to resolve `_lookup` placeholders.
  Map<String, Map<String, String>> _tier0Ids = const {};

  /// Returns the number of entities inserted (Tier-0 + Tier-1).
  /// Returns 0 when the schema isn't v2 or the guard flag is already set.
  Future<int> ensureImported({
    required String worldId,
    required BuiltinDnd5eV2Build build,
  }) async {
    if (build.schema.schemaId != builtinDnd5eV2SchemaId) return 0;

    final settings = await _readSettings(worldId);
    if (settings['_srdCoreImportedAt'] is String) return 0;

    final inserted = await _db.transaction(() async {
      final pkg = await _findPackageByName(srdCorePackageName);
      final tier0Count = await _seedTier0(
          worldId: worldId, build: build, packageId: pkg?.id);
      final tier1Count = await _importSrdCore(
        worldId: worldId,
        packageId: pkg?.id,
      );
      if (pkg != null) {
        await _db.installedPackagesDao.upsert(
          InstalledPackagesCompanion.insert(
            worldId: worldId,
            packageId: pkg.id,
            packageName: Value(pkg.name),
          ),
        );
      }
      return tier0Count + tier1Count;
    });

    settings['_srdCoreImportedAt'] =
        DateTime.now().toUtc().toIso8601String();
    settings['_srdAttribution'] = srdAttribution;
    settings['_srdLicense'] = srdLicense;
    settings['_srdSource'] = srdSourceTag;
    await _writeSettings(worldId, settings);

    return inserted;
  }

  Future<Map<String, dynamic>> _readSettings(String worldId) async {
    final row = await _db.worldSettingsDao.get(worldId);
    if (row == null || row.settingsJson.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(row.settingsJson);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _writeSettings(
      String worldId, Map<String, dynamic> settings) async {
    await _db.worldSettingsDao.upsert(WorldSettingsCompanion(
      worldId: Value(worldId),
      settingsJson: Value(jsonEncode(settings)),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<Package?> _findPackageByName(String name) async {
    final all = await _db.packagesDao.getAll();
    for (final p in all) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// Inserts every seed row from [build.seedRows] as a world entity belonging
  /// to [worldId]. Populates [_tier0Ids] for downstream relation resolution.
  Future<int> _seedTier0({
    required String worldId,
    required BuiltinDnd5eV2Build build,
    String? packageId,
  }) async {
    final rows = <WorldEntitiesCompanion>[];
    final index = <String, Map<String, String>>{};

    for (final entry in build.seedRows.entries) {
      final slug = entry.key;
      final slugIdx = index.putIfAbsent(slug, () => <String, String>{});
      for (final row in entry.value) {
        final id = _uuid.v4();
        final name = (row['name'] as String?) ?? '';
        if (name.isEmpty) continue;
        slugIdx[name] = id;
        rows.add(WorldEntitiesCompanion.insert(
          id: id,
          worldId: worldId,
          categorySlug: slug,
          name: name,
          source: const Value(srdSourceTag),
          description: Value((row['description'] as String?) ?? ''),
          fieldsJson: Value(jsonEncode(row['fields'] ?? <String, dynamic>{})),
          packageId: Value(packageId),
          packageEntityId: packageId == null
              ? const Value.absent()
              : Value(srdStableEntityId(slug, name)),
          linked: Value(packageId != null),
        ));
      }
    }

    if (rows.isEmpty) {
      _tier0Ids = index;
      return 0;
    }

    await _db.worldEntitiesDao.upsertAll(rows);
    _tier0Ids = index;
    return rows.length;
  }

  Future<int> _importSrdCore({
    required String worldId,
    String? packageId,
  }) async {
    final pack = buildSrdCorePack();
    if (pack.entities.isEmpty) return 0;

    final packToWorld = <String, String>{
      for (final id in pack.entities.keys) id: _uuid.v4(),
    };

    final rows = <WorldEntitiesCompanion>[];
    for (final entry in pack.entities.entries) {
      final id = entry.key;
      final raw = Map<String, dynamic>.from(entry.value as Map);
      final attrs = raw['attributes'] is Map
          ? Map<String, dynamic>.from(raw['attributes'] as Map)
          : <String, dynamic>{};
      final resolvedAttrs =
          PackageImportService.resolveLookupPlaceholder(attrs, _tier0Ids)
              as Map<String, dynamic>;
      final remappedAttrs =
          _remapPackRefs(resolvedAttrs, packToWorld) as Map<String, dynamic>;
      final worldEntityId = packToWorld[id]!;
      rows.add(WorldEntitiesCompanion.insert(
        id: worldEntityId,
        worldId: worldId,
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
        fieldsJson: Value(jsonEncode(remappedAttrs)),
        packageId: Value(packageId),
        packageEntityId: Value(id),
        linked: Value(packageId != null),
      ));
    }

    if (rows.isEmpty) return 0;
    await _db.worldEntitiesDao.upsertAll(rows);
    return rows.length;
  }

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
