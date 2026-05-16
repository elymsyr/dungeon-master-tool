import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_invites_table.dart';

part 'world_invites_dao.g.dart';

@DriftAccessor(tables: [WorldInvites])
class WorldInvitesDao extends DatabaseAccessor<AppDatabase>
    with _$WorldInvitesDaoMixin {
  WorldInvitesDao(super.db);

  Future<WorldInvite?> getByCode(String code) =>
      (select(worldInvites)..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  Stream<List<WorldInvite>> watchByWorld(String worldId) =>
      (select(worldInvites)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Future<void> upsert(WorldInvitesCompanion row) =>
      into(worldInvites).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WorldInvitesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldInvites, rows);
    });
  }

  Future<int> deleteByCode(String code) =>
      (delete(worldInvites)..where((t) => t.code.equals(code))).go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldInvites)..where((t) => t.worldId.equals(worldId))).go();
}
