import 'package:drift/drift.dart';

import '../app_database.dart';
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
      into(timelinePins).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<TimelinePinsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(timelinePins, rows);
    });
  }

  Future<int> deleteById(String id) =>
      (delete(timelinePins)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(timelinePins)..where((t) => t.worldId.equals(worldId))).go();
}
