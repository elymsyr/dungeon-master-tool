import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../data/database/app_database.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'srd_core_package_bootstrap.dart' show srdCorePackageName;

/// Registers the built-in SRD pack against a freshly-created v2 D&D 5e
/// world. F1 (built-in decouple): the world no longer stores per-row copies
/// of pack entities — `installed_packages` carries the link and
/// `WorldRepositoryImpl._loadFromDb` synthesises entries from
/// `package_entities` at read time via `synthesizeWorldBuiltins`.
///
/// Idempotency: `_srdCoreImportedAt` flag in `world_settings.settings_json`.
class SrdCoreBootstrap {
  final AppDatabase _db;
  SrdCoreBootstrap(this._db);

  /// Returns 1 once installed_packages has been linked for this world, 0
  /// otherwise (wrong schema, flag already set, or built-in pack missing).
  Future<int> ensureImported({
    required String worldId,
    required BuiltinDnd5eV2Build build,
  }) async {
    if (build.schema.schemaId != builtinDnd5eV2SchemaId) return 0;

    final settings = await _readSettings(worldId);
    if (settings['_srdCoreImportedAt'] is String) return 0;

    final linked = await _db.transaction(() async {
      final pkg = await _findPackageByName(srdCorePackageName);
      if (pkg == null) return 0;
      await _db.installedPackagesDao.upsert(
        InstalledPackagesCompanion.insert(
          worldId: worldId,
          packageId: pkg.id,
          packageName: Value(pkg.name),
        ),
      );
      return 1;
    });

    settings['_srdCoreImportedAt'] =
        DateTime.now().toUtc().toIso8601String();
    settings['_srdAttribution'] = srdAttribution;
    settings['_srdLicense'] = srdLicense;
    settings['_srdSource'] = srdSourceTag;
    await _writeSettings(worldId, settings);

    return linked;
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
}
