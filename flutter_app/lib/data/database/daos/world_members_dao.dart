import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_members_table.dart';

part 'world_members_dao.g.dart';

@DriftAccessor(tables: [WorldMembers])
class WorldMembersDao extends DatabaseAccessor<AppDatabase>
    with _$WorldMembersDaoMixin {
  WorldMembersDao(super.db);

  Future<List<WorldMember>> getByWorld(String worldId) =>
      (select(worldMembers)..where((t) => t.worldId.equals(worldId))).get();

  Stream<List<WorldMember>> watchByWorld(String worldId) =>
      (select(worldMembers)..where((t) => t.worldId.equals(worldId)))
          .watch()
          .distinct();

  Stream<List<WorldMember>> watchByUser(String userId) =>
      (select(worldMembers)..where((t) => t.userId.equals(userId)))
          .watch()
          .distinct();

  Future<WorldMember?> get(String worldId, String userId) =>
      (select(worldMembers)
            ..where(
                (t) => t.worldId.equals(worldId) & t.userId.equals(userId)))
          .getSingleOrNull();

  Future<void> upsert(WorldMembersCompanion row) =>
      into(worldMembers).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WorldMembersCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldMembers, rows);
    });
  }

  Future<int> deleteOne(String worldId, String userId) =>
      (delete(worldMembers)
            ..where(
                (t) => t.worldId.equals(worldId) & t.userId.equals(userId)))
          .go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldMembers)..where((t) => t.worldId.equals(worldId))).go();
}
