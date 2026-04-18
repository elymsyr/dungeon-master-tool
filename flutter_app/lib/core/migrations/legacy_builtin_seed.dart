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

/// One-shot migration that preserves the legacy hardcoded D&D 5e built-in
/// template as a **personal local template** for users who previously
/// relied on it. Hits the SharedPreferences flag on first call and never
/// runs again.
///
/// The function is conditional on existing references: if nothing in the
/// user's SQLite (world_schemas / package_schemas) points at
/// `builtin-dnd5e-default`, the seed is skipped entirely so fresh
/// installs stay clean. Returns true if the seed wrote a new template
/// file, false otherwise (already-seeded, no references, or failure).
Future<bool> seedLegacyBuiltinTemplateIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_seedFlag) == true) return false;

  try {
    final hasReferences = await _hasLegacyBuiltinReferences();
    if (hasReferences) {
      await _writeTemplateIfMissing();
    }
    await prefs.setBool(_seedFlag, true);
    return hasReferences;
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

Future<void> _writeTemplateIfMissing() async {
  final targetDir = Directory(p.join(AppPaths.cacheDir, 'templates'));
  await targetDir.create(recursive: true);
  final targetFile = File(p.join(targetDir.path, '$_legacyBuiltinId.json'));
  if (await targetFile.exists()) return;

  final schema = generateDefaultDnd5eSchema();
  await TemplateLocalDataSource().save(schema);
}
