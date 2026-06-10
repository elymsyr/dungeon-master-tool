import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/templates_table.dart';

part 'templates_dao.g.dart';

/// Data access for the hub-level Template library ([Templates]).
///
/// Thin CRUD over a single-blob-per-row table; all schema parsing /
/// hash recomputation lives in `TemplateRepositoryImpl`, this DAO only moves
/// rows. Built-in template is an asset, never a row here (see [Templates]).
@DriftAccessor(tables: [Templates])
class TemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

  /// All library rows, newest-edited first (matches the packages tab ordering).
  Future<List<Template>> getAll() => (select(templates)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .get();

  /// Reactive variant for a live-updating library list.
  Stream<List<Template>> watchAll() => (select(templates)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch()
      .distinct();

  Future<Template?> getById(String id) =>
      (select(templates)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// First row whose display name matches (case-sensitive) — for copy-name
  /// collision checks before insert.
  Future<Template?> getByName(String name) =>
      (select(templates)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<void> upsert(TemplatesCompanion row) =>
      into(templates).insertOnConflictUpdate(row);

  /// Renames a row in place without touching [Templates.dataJson]. The caller
  /// is responsible for also updating the embedded `name` in the blob on the
  /// next full save; this fast path keeps the list label fresh immediately.
  Future<int> rename(String id, String newName) =>
      (update(templates)..where((t) => t.id.equals(id))).write(
        TemplatesCompanion(
          name: Value(newName),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> deleteById(String id) =>
      (delete(templates)..where((t) => t.id.equals(id))).go();
}
