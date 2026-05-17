import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/trash_items_table.dart';

part 'trash_dao.g.dart';

@DriftAccessor(tables: [TrashItems])
class TrashDao extends DatabaseAccessor<AppDatabase> with _$TrashDaoMixin {
  TrashDao(super.db);

  Future<List<TrashItem>> getByKind(String kind) =>
      (select(trashItems)
            ..where((t) => t.kind.equals(kind))
            ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
          .get();

  Stream<List<TrashItem>> watchByKind(String kind) =>
      (select(trashItems)
            ..where((t) => t.kind.equals(kind))
            ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
          .watch()
          .distinct();

  Future<TrashItem?> getById(String id) =>
      (select(trashItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Was this `sourceId` (original char/world/package id) soft-deleted by the
  /// user? Used as the "user-intent: deleted" gate so concurrent cloud pulls
  /// don't resurrect a row the user already trashed.
  Future<bool> existsBySource(String kind, String sourceId) async {
    final q = select(trashItems)
      ..where((t) => t.kind.equals(kind) & t.sourceId.equals(sourceId))
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  Future<void> upsert(TrashItemsCompanion row) =>
      into(trashItems).insertOnConflictUpdate(row);

  Future<int> deleteById(String id) =>
      (delete(trashItems)..where((t) => t.id.equals(id))).go();

  Future<int> purgeOlderThan(DateTime cutoff) =>
      (delete(trashItems)
            ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
          .go();
}
