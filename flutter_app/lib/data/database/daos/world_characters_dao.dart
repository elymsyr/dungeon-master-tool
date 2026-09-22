import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_stamp.dart';
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
      into(worldCharacters).insertOnConflictUpdate(
          row.copyWith(updatedAt: stampedNow(row.updatedAt)));

  Future<void> upsertAll(List<WorldCharactersCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(worldCharacters, [
        for (final r in rows) r.copyWith(updatedAt: stampedNow(r.updatedAt)),
      ]);
    });
  }

  Future<int> deleteById(String id) async {
    final row = await getById(id);
    if (row != null) {
      await recordTombstone('world_characters', id, worldId: row.worldId);
    }
    return (delete(worldCharacters)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteByWorld(String worldId) async {
    final ids = (await (select(worldCharacters)
              ..where((t) => t.worldId.equals(worldId)))
            .get())
        .map((e) => e.id);
    await recordTombstones('world_characters', ids, worldId: worldId);
    return (delete(worldCharacters)..where((t) => t.worldId.equals(worldId)))
        .go();
  }

  /// Sahipliği düşürmek buluta da gitmeli (RLS `owner_id`'ye bakıyor), o
  /// yüzden satır damgalanıyor — damgasız kalsa push taramasına girmezdi.
  Future<int> dropOwnership(String id) =>
      (update(worldCharacters)..where((t) => t.id.equals(id))).write(
          WorldCharactersCompanion(
              ownerId: const Value(null), updatedAt: Value(DateTime.now())));

  /// LAN sync: yeniden adlandırma zamanını kaydet.
  Future<void> setRenamedAt(String id, DateTime renamedAt) async {
    await (update(worldCharacters)..where((t) => t.id.equals(id)))
        .write(WorldCharactersCompanion(renamedAt: Value(renamedAt)));
  }
}
