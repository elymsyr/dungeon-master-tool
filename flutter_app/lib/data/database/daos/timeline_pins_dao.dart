import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_stamp.dart';
import '../tables/timeline_pins_table.dart';

part 'timeline_pins_dao.g.dart';

@DriftAccessor(tables: [TimelinePins])
class TimelinePinsDao extends DatabaseAccessor<AppDatabase>
    with _$TimelinePinsDaoMixin {
  TimelinePinsDao(super.db);

  Future<TimelinePin?> getById(String id) =>
      (select(timelinePins)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<TimelinePin>> watchByWorld(String worldId) =>
      (select(timelinePins)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Future<void> upsert(TimelinePinsCompanion row) =>
      into(timelinePins).insertOnConflictUpdate(
          row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<void> upsertAll(List<TimelinePinsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(timelinePins, [
        for (final r in rows) r.copyWith(updatedAt: stampedNow(r.updatedAt)),
      ]);
    });
  }

  Future<int> deleteById(String id) async {
    final row = await getById(id);
    if (row != null) {
      await recordTombstone('timeline_pins', id, worldId: row.worldId);
    }
    return (delete(timelinePins)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteByWorld(String worldId) async {
    final ids = (await (select(timelinePins)
              ..where((t) => t.worldId.equals(worldId)))
            .get())
        .map((e) => e.id);
    await recordTombstones('timeline_pins', ids, worldId: worldId);
    return (delete(timelinePins)..where((t) => t.worldId.equals(worldId)))
        .go();
  }
}
