import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/characters_table.dart';

part 'character_dao.g.dart';

@DriftAccessor(tables: [Characters])
class CharacterDao extends DatabaseAccessor<AppDatabase>
    with _$CharacterDaoMixin {
  CharacterDao(super.db);

  Future<List<CharacterRow>> getAll() => select(characters).get();

  Stream<List<CharacterRow>> watchAll() => select(characters).watch();

  Future<CharacterRow?> getById(String id) =>
      (select(characters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<CharacterRow>> getByWorld(String worldId) =>
      (select(characters)..where((t) => t.worldId.equals(worldId))).get();

  Future<void> upsert(CharactersCompanion row) =>
      into(characters).insertOnConflictUpdate(row);

  Future<int> deleteById(String id) =>
      (delete(characters)..where((t) => t.id.equals(id))).go();

  /// Batch insert for the JSON → Drift migration. Uses
  /// `insertOrReplace` so a partially-run migration is safely resumable.
  Future<void> insertAll(List<CharactersCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) {
      for (final row in rows) {
        b.insert(characters, row, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<int> count() async {
    final c = characters.id.count();
    final q = selectOnly(characters)..addColumns([c]);
    final r = await q.getSingle();
    return r.read(c) ?? 0;
  }
}
