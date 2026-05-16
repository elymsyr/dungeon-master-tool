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

  Future<void> upsert(TrashItemsCompanion row) =>
      into(trashItems).insertOnConflictUpdate(row);

  Future<int> deleteById(String id) =>
      (delete(trashItems)..where((t) => t.id.equals(id))).go();

  Future<int> purgeOlderThan(DateTime cutoff) =>
      (delete(trashItems)
            ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
          .go();
}
