import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_stamp.dart';
import '../tables/world_sessions_table.dart';

part 'world_sessions_dao.g.dart';

@DriftAccessor(tables: [WorldSessions])
class WorldSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$WorldSessionsDaoMixin {
  WorldSessionsDao(super.db);

  Future<WorldSession?> getById(String id) =>
      (select(worldSessions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<List<WorldSession>> watchByWorld(String worldId) =>
      (select(worldSessions)
            ..where((t) => t.worldId.equals(worldId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch()
          .distinct();

  Future<List<WorldSession>> getByWorld(String worldId) =>
      (select(worldSessions)
            ..where((t) => t.worldId.equals(worldId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<void> upsert(WorldSessionsCompanion row) =>
      into(worldSessions).insert(row, onConflict: _sameWorld(row));

  Future<void> upsertAll(List<WorldSessionsCompanion> rows) async {
    await batch((b) {
      for (final r in rows) {
        b.insert(worldSessions, r, onConflict: _sameWorld(r));
      }
    });
  }

  /// Başka dünyanın satırı taşınmaz — bkz. `WorldEntitiesDao._sameWorld`.
  static DoUpdate<$WorldSessionsTable, WorldSession> _sameWorld(
    WorldSessionsCompanion row,
  ) =>
      DoUpdate((_) => row,
          where: row.worldId.present
              ? (old) => old.worldId.equals(row.worldId.value)
              : null);

  /// [worldId] dışındaki dünyalardaki oturum id'leri → sahip dünya.
  Future<Map<String, String>> ownersOutside(String worldId) async {
    final q = selectOnly(worldSessions)
      ..addColumns([worldSessions.id, worldSessions.worldId])
      ..where(worldSessions.worldId.equals(worldId).not());
    return {
      for (final r in await q.get())
        r.read(worldSessions.id)!: r.read(worldSessions.worldId)!,
    };
  }

  Future<int> deleteById(String id) async {
    final row = await (select(worldSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row != null) {
      await recordTombstone('world_sessions', id, worldId: row.worldId);
    }
    return (delete(worldSessions)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteByWorld(String worldId) async {
    final ids = (await (select(worldSessions)
              ..where((t) => t.worldId.equals(worldId)))
            .get())
        .map((e) => e.id);
    await recordTombstones('world_sessions', ids, worldId: worldId);
    return (delete(worldSessions)..where((t) => t.worldId.equals(worldId)))
        .go();
  }

  /// `.dmtz` birleştirmesi sonrası satır damgası — bkz.
  /// `WorldEntitiesDao.setUpdatedAt`.
  Future<void> setUpdatedAt(String id, DateTime updatedAt) async {
    await (update(worldSessions)..where((t) => t.id.equals(id)))
        .write(WorldSessionsCompanion(updatedAt: Value(updatedAt)));
  }
}
