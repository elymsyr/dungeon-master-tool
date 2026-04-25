import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/datasources/local/template_local_ds.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../config/app_paths.dart';
import '../services/log_buffer.dart';

const _seedFlag = 'seed_builtin_dnd5e_v1';
const _legacyBuiltinId = 'builtin-dnd5e-default';

/// Preserves the legacy hardcoded D&D 5e built-in template as a personal
/// local template for users who previously relied on it. Original first-run
/// gate uses [SharedPreferences]; later runs re-seed when the bundled
/// generator's version is newer than the on-disk file (so field-default
/// additions ship to existing installs without manual deletion).
///
/// The function is conditional on existing references: if nothing in the
/// user's SQLite (world_schemas / package_schemas) points at
/// `builtin-dnd5e-default`, the seed is skipped entirely so fresh installs
/// stay clean. Returns true if a fresh template file was written.
Future<bool> seedLegacyBuiltinTemplateIfNeeded() async {
  try {
    final hasReferences = await _hasLegacyBuiltinReferences();
    if (!hasReferences) {
      // No campaigns reference v1; mark the original first-run flag so we
      // don't keep checking, and bail out.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seedFlag, true);
      return false;
    }
    return await _writeTemplateIfStale();
  } catch (e, st) {
    LogBuffer.instance.recordError(e, st, context: 'seedLegacyBuiltin');
    return false;
  }
}

Future<bool> _hasLegacyBuiltinReferences() async {
  final db = AppDatabase();
  try {
    final worldHit = await db
        .customSelect(
          'SELECT 1 FROM world_schemas WHERE template_id = ?1 LIMIT 1',
          variables: [Variable<String>(_legacyBuiltinId)],
        )
        .getSingleOrNull();
    if (worldHit != null) return true;

    final packageHit = await db
        .customSelect(
          'SELECT 1 FROM package_schemas WHERE template_id = ?1 LIMIT 1',
          variables: [Variable<String>(_legacyBuiltinId)],
        )
        .getSingleOrNull();
    if (packageHit != null) return true;

    return false;
  } finally {
    await db.close();
  }
}

Future<bool> _writeTemplateIfStale() async {
  final targetDir = Directory(p.join(AppPaths.cacheDir, 'templates'));
  await targetDir.create(recursive: true);
  final targetFile = File(p.join(targetDir.path, '$_legacyBuiltinId.json'));

  final schema = generateDefaultDnd5eSchema();

  if (await targetFile.exists()) {
    final onDisk = _readVersion(targetFile);
    if (onDisk != null && _compareVersions(onDisk, schema.version) >= 0) {
      return false;
    }
  }

  await TemplateLocalDataSource().save(schema);
  return true;
}

String? _readVersion(File f) {
  try {
    final raw = f.readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final v = json['version'];
    return v is String ? v : null;
  } catch (_) {
    return null;
  }
}

int _compareVersions(String a, String b) {
  final ap = a.split('.');
  final bp = b.split('.');
  final n = ap.length > bp.length ? ap.length : bp.length;
  for (var i = 0; i < n; i++) {
    final ai = i < ap.length ? int.tryParse(ap[i]) ?? 0 : 0;
    final bi = i < bp.length ? int.tryParse(bp[i]) ?? 0 : 0;
    if (ai != bi) return ai - bi;
  }
  return 0;
}
