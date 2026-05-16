import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../domain/entities/character.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// PR-D4 v12 rewrite. Characters now ride on the `world_characters` Drift
/// table (Postgres-mirror). Worldless chars are gone — domain `worldId` is
/// still nullable but persisted as the empty string; v12 fresh-cut means no
/// pre-existing worldless rows. Trash uses `trash_items.kind = 'character'`.
class CharacterLoadResult {
  final List<Character> chars;

  /// Legacy `world_name` → `world_id` migration map. v12 fresh-cut keeps it
  /// for completeness but it always returns empty.
  final Map<String, String> legacyWorldNames;
  const CharacterLoadResult({
    required this.chars,
    required this.legacyWorldNames,
  });
}

class CharacterRepository {
  CharacterRepository(this._db);

  final AppDatabase _db;

  Future<List<Character>> loadAll() async => (await loadAllWithLegacy()).chars;

  Future<CharacterLoadResult> loadAllWithLegacy() async {
    final rows = await _db.worldCharactersDao.getAllChars();
    final out = <Character>[];
    for (final row in rows) {
      try {
        out.add(Character.fromJson(_rowToCharacterJson(row)));
      } catch (_) {
        // Corrupt payload — skip rather than block the whole list.
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return CharacterLoadResult(chars: out, legacyWorldNames: const {});
  }

  Future<void> save(Character character) async {
    await _db.worldCharactersDao.upsert(_characterToCompanion(character));
  }

  /// Soft delete — snapshot the row into `trash_items` then drop from
  /// `world_characters`. UI restore reads the trash row by id.
  Future<void> delete(String id, {String? displayName}) async {
    final row = await _db.worldCharactersDao.getById(id);
    if (row == null) return;
    final map = _rowToCharacterJson(row);
    final originalName = (displayName ?? '').trim().isEmpty
        ? ((map['entity'] as Map<String, dynamic>?)?['name'] as String? ?? id)
        : displayName!;
    await _db.trashDao.upsert(TrashItemsCompanion.insert(
      id: _uuid.v4(),
      kind: 'character',
      sourceId: id,
      payloadJson: jsonEncode({
        ...map,
        '_original_name': originalName,
      }),
    ));
    await _db.worldCharactersDao.deleteById(id);
  }

  /// Restore a soft-deleted character. [trashId] is the `trash_items.id`
  /// surfaced by the trash list provider — replaces the v11 directory-name
  /// argument.
  Future<Character?> restoreFromTrash(String trashId) async {
    final trash = await _db.trashDao.getById(trashId);
    if (trash == null || trash.kind != 'character') return null;
    try {
      final map = jsonDecode(trash.payloadJson) as Map<String, dynamic>;
      map.remove('_original_name');
      final c = Character.fromJson(map);
      final existing = await _db.worldCharactersDao.getById(c.id);
      if (existing != null) {
        // Conflict — drop the trash row, leave Drift untouched.
        await _db.trashDao.deleteById(trashId);
        return null;
      }
      await save(c);
      await _db.trashDao.deleteById(trashId);
      return c;
    } catch (_) {
      return null;
    }
  }

  /// Hard-delete a trash row.
  Future<void> permanentlyDelete(String trashId) =>
      _db.trashDao.deleteById(trashId);

  Map<String, dynamic> _rowToCharacterJson(WorldCharacterRow row) {
    final payload = jsonDecode(row.payloadJson);
    if (payload is! Map<String, dynamic>) {
      throw StateError('Corrupt payload_json for character ${row.id}');
    }
    // Column values are canonical; payload values fill in everything else.
    return {
      ...payload,
      'id': row.id,
      'template_id': row.templateId,
      'template_name': row.templateName,
      'world_id': row.worldId.isEmpty ? null : row.worldId,
      'owner_id': row.ownerId,
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'created_at': payload['created_at'] is String
          ? payload['created_at']
          : row.createdAt.toUtc().toIso8601String(),
    };
  }

  WorldCharactersCompanion _characterToCompanion(Character c) {
    return WorldCharactersCompanion(
      id: Value(c.id),
      // FK to worlds is declared but PRAGMA foreign_keys=OFF (see
      // app_database.dart). Empty string represents an orphan worldless
      // char; fresh-cut v12 doesn't expect any but the domain model still
      // allows it.
      worldId: Value(c.worldId ?? ''),
      ownerId: Value(c.ownerId),
      templateId: Value(c.templateId),
      templateName: Value(c.templateName),
      // Opaque round-trip blob — never normalize. See world_characters_dao.dart
      // and docs/full_drift_migration_plan.md § Character Mechanics Preservation.
      payloadJson: Value(jsonEncode(c.toJson())),
      createdAt: Value(
        DateTime.tryParse(c.createdAt)?.toUtc() ?? DateTime.now().toUtc(),
      ),
      updatedAt: Value(
        DateTime.tryParse(c.updatedAt)?.toUtc() ?? DateTime.now().toUtc(),
      ),
    );
  }
}
