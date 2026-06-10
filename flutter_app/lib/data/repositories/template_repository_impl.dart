import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/template_repository.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// Drift-backed implementation of [TemplateRepository] over the `templates`
/// table (PR-1.4). Each row is the full `WorldSchema` JSON blob; the typed
/// `name`/`originalHash`/`currentHash` columns are projections kept in sync on
/// every write so the library list never has to parse a blob just to render.
///
/// The built-in template is an asset (`BuiltinTemplateLoader`), never a row —
/// this repository deliberately knows nothing about it, so it can never be
/// renamed, deleted, or overwritten through here.
class TemplateRepositoryImpl implements TemplateRepository {
  final AppDatabase _db;

  TemplateRepositoryImpl(this._db);

  @override
  Future<List<WorldSchema>> listUserTemplates() async {
    final rows = await _db.templatesDao.getAll();
    final out = <WorldSchema>[];
    for (final row in rows) {
      final schema = _tryParse(row);
      if (schema != null) out.add(schema);
    }
    return out;
  }

  @override
  Future<WorldSchema?> load(String schemaId) async {
    final row = await _db.templatesDao.getById(schemaId);
    if (row == null) return null;
    return _tryParse(row);
  }

  @override
  Future<WorldSchema> save(WorldSchema template) async {
    final currentHash = computeWorldSchemaContentHash(template);
    // Backfill the frozen lineage hash on first save if it was never set.
    final originalHash = template.originalHash ?? currentHash;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final existing = await _db.templatesDao.getById(template.schemaId);
    final createdAt = existing?.createdAt ?? now;

    final toStore = template.copyWith(
      originalHash: originalHash,
      // Preserve the original creation timestamp on update; stamp now on insert.
      createdAt: createdAt.toIso8601String(),
      updatedAt: nowIso,
    );

    await _db.templatesDao.upsert(TemplatesCompanion(
      id: Value(toStore.schemaId),
      name: Value(toStore.name),
      dataJson: Value(jsonEncode(toStore.toJson())),
      originalHash: Value(originalHash),
      currentHash: Value(currentHash),
      createdAt: Value(createdAt),
      updatedAt: Value(now),
    ));
    return toStore;
  }

  @override
  Future<WorldSchema> copy({
    required WorldSchema source,
    required String newName,
  }) async {
    // Fresh schemaId, preserved originalHash (roadmap §1.4). If the source has
    // no originalHash yet (legacy), seed the lineage from its current content
    // hash so the copy still anchors to a stable ancestor.
    final originalHash =
        source.originalHash ?? computeWorldSchemaContentHash(source);
    final copy = source.copyWith(
      schemaId: _freshSchemaId(),
      name: newName,
      originalHash: originalHash,
    );
    return save(copy);
  }

  @override
  Future<WorldSchema?> rename(String schemaId, String newName) async {
    final current = await load(schemaId);
    if (current == null) return null;
    // Update the embedded name too so the blob stays authoritative.
    return save(current.copyWith(name: newName));
  }

  @override
  Future<void> delete(String schemaId) =>
      _db.templatesDao.deleteById(schemaId);

  @override
  Future<bool> nameExists(String name) async =>
      (await _db.templatesDao.getByName(name)) != null;

  // --- Internal helpers ---

  /// A globally-unique `schemaId` for a new template/copy. Prefixed so it is
  /// visibly distinct from the built-in lineage ids in logs / drift reports.
  String _freshSchemaId() => 'tmpl-${_uuid.v4()}';

  WorldSchema? _tryParse(Template row) {
    try {
      final map = Map<String, dynamic>.from(jsonDecode(row.dataJson) as Map);
      final schema = WorldSchema.fromJson(map);
      // Trust the row's denormalised id/name if the blob somehow disagrees
      // (defensive — keeps the list keyed consistently with the table).
      if (schema.schemaId == row.id) return schema;
      return schema.copyWith(schemaId: row.id, name: row.name);
    } catch (_) {
      return null;
    }
  }
}
