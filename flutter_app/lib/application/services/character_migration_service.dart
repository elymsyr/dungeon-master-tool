import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_paths.dart';
import '../../data/database/app_database.dart';
import '../../domain/entities/character.dart';

/// PR-SYNC-0: one-shot JSON → Drift migration for characters.
///
/// Reads every `*.json` under `AppPaths.charactersDir` and batch-inserts a
/// row into the Drift `characters` table. The JSON files were left in place
/// as a rollback snapshot; PR-SYNC-6's [cleanupLegacyJsonIfNeeded] deletes
/// them after the migration flag has been set.
///
/// The migration flag is namespaced per user (`AppPaths.currentUserId`) so
/// multi-account installs migrate each user's directory independently.
class CharacterMigrationService {
  CharacterMigrationService(this._db);

  final AppDatabase _db;

  static const _flagPrefix = 'characters_drift_migrated_v1';
  static const _cleanupFlagPrefix = 'characters_json_cleanup_v1';

  String get _flagKey {
    final uid = AppPaths.currentUserId;
    return uid == null ? _flagPrefix : '${_flagPrefix}__$uid';
  }

  String get _cleanupFlagKey {
    final uid = AppPaths.currentUserId;
    return uid == null ? _cleanupFlagPrefix : '${_cleanupFlagPrefix}__$uid';
  }

  Future<bool> isMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_flagKey) ?? false;
  }

  Future<void> _markMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flagKey, true);
  }

  Future<bool> _isCleanedUp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cleanupFlagKey) ?? false;
  }

  Future<void> _markCleanedUp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cleanupFlagKey, true);
  }

  /// Runs the migration if it hasn't run for the active user. Idempotent.
  /// Returns the number of rows inserted (0 if already migrated or no files).
  Future<int> migrateFromJsonIfNeeded() async {
    if (await isMigrated()) return 0;
    return _runMigration();
  }

  /// PR-SYNC-6: once the Drift migration has settled, delete the legacy
  /// `*.json` snapshots under `AppPaths.charactersDir`. Keeps non-`.json`
  /// sidecars (`.pending_releases.json` lives in the same dir and is still
  /// the source of truth for release queueing). Idempotent via
  /// `_cleanupFlagKey`.
  Future<int> cleanupLegacyJsonIfNeeded() async {
    if (!await isMigrated()) return 0;
    if (await _isCleanedUp()) return 0;
    final dir = Directory(AppPaths.charactersDir);
    if (!await dir.exists()) {
      await _markCleanedUp();
      return 0;
    }
    var removed = 0;
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      // Skip dot-prefixed sidecars (e.g. `.pending_releases.json`).
      if (name.startsWith('.')) continue;
      if (!name.endsWith('.json')) continue;
      try {
        await entry.delete();
        removed++;
      } catch (e) {
        debugPrint('character cleanup: failed to delete ${entry.path}: $e');
      }
    }
    await _markCleanedUp();
    debugPrint('character cleanup: removed $removed legacy json file(s)');
    return removed;
  }

  Future<int> _runMigration() async {
    final dir = Directory(AppPaths.charactersDir);
    if (!await dir.exists()) {
      await _markMigrated();
      return 0;
    }
    final rows = <CharactersCompanion>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final text = await entry.readAsString();
        final map = jsonDecode(text) as Map<String, dynamic>;
        final companion = _companionFromJson(map);
        if (companion != null) rows.add(companion);
      } catch (e) {
        debugPrint('character migration: skip corrupt ${entry.path}: $e');
      }
    }
    if (rows.isNotEmpty) {
      await _db.characterDao.insertAll(rows);
    }
    await _markMigrated();
    debugPrint('character migration: imported ${rows.length} row(s)');
    return rows.length;
  }

  /// Converts a raw character JSON map into the Drift companion. Returns
  /// null when the row is unusable (missing id / unparseable entity).
  CharactersCompanion? _companionFromJson(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) return null;

    final templateId = (map['template_id'] as String?) ?? '';
    final templateName = (map['template_name'] as String?) ?? '';
    final worldId = map['world_id'] as String?;
    final ownerId = map['owner_id'] as String?;
    final createdAt = _parseTs(map['created_at']) ?? DateTime.now().toUtc();
    final updatedAt = _parseTs(map['updated_at']) ?? createdAt;

    final entityRaw = map['entity'];
    if (entityRaw is! Map) return null;
    final entityJson = jsonEncode(entityRaw);

    return CharactersCompanion(
      id: Value(id),
      templateId: Value(templateId),
      templateName: Value(templateName),
      entityJson: Value(entityJson),
      worldId: Value(worldId),
      ownerId: Value(ownerId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  static DateTime? _parseTs(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v)?.toUtc();
  }

  /// Returns the union of Drift rows and any JSON files that failed to
  /// migrate — used by CharacterRepository as a defensive fallback if the
  /// Drift table somehow comes up empty after a migration was supposedly
  /// completed.
  static Future<List<Character>> readJsonSnapshot() async {
    final dir = Directory(AppPaths.charactersDir);
    if (!await dir.exists()) return const [];
    final out = <Character>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final map =
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
        out.add(Character.fromJson(map));
      } catch (_) {}
    }
    return out;
  }
}
