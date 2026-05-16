import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/world_characters_table.dart';

part 'world_characters_dao.g.dart';

/// **Opaque-blob rule**: `payloadJson` MUST round-trip byte-for-byte. Never
/// parse/normalize/re-serialize the column — losing keys orphans level-up
/// state. See `docs/full_drift_migration_plan.md` § Character Mechanics
/// Preservation.
@DriftAccessor(tables: [WorldCharacters])
class WorldCharactersDao extends DatabaseAccessor<AppDatabase>
    with _$WorldCharactersDaoMixin {
  WorldCharactersDao(super.db);

  Future<WorldCharacterRow?> getById(String id) =>
      (select(worldCharacters)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Hub char tab cold-load. Returns every row in the table; CharacterRepository
  /// is responsible for filtering by ownership when the UI demands it.
  Future<List<WorldCharacterRow>> getAllChars() =>
      (select(worldCharacters)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Stream<WorldCharacterRow?> watchById(String id) =>
      (select(worldCharacters)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .distinct();

  Stream<List<WorldCharacterRow>> watchByWorld(String worldId) =>
      (select(worldCharacters)
            ..where((t) => t.worldId.equals(worldId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch()
          .distinct();

  Stream<List<WorldCharacterRow>> watchByOwner(String ownerId) =>
      (select(worldCharacters)
            ..where((t) => t.ownerId.equals(ownerId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch()
          .distinct();

  Stream<List<WorldCharacterRow>> watchOrphans(String worldId) =>
      (select(worldCharacters)
            ..where(
                (t) => t.worldId.equals(worldId) & t.ownerId.isNull()))
          .watch()
          .distinct();

  Future<void> upsert(WorldCharactersCompanion row) =>
      into(worldCharacters).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WorldCharactersCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldCharacters, rows);
    });
  }

  Future<int> deleteById(String id) =>
      (delete(worldCharacters)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByWorld(String worldId) =>
      (delete(worldCharacters)..where((t) => t.worldId.equals(worldId))).go();

  Future<int> dropOwnership(String id) =>
      (update(worldCharacters)..where((t) => t.id.equals(id)))
          .write(const WorldCharactersCompanion(ownerId: Value(null)));
}
