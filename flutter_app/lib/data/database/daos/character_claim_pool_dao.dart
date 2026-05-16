import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/character_claim_pool_table.dart';

part 'character_claim_pool_dao.g.dart';

@DriftAccessor(tables: [CharacterClaimPool])
class CharacterClaimPoolDao extends DatabaseAccessor<AppDatabase>
    with _$CharacterClaimPoolDaoMixin {
  CharacterClaimPoolDao(super.db);

  Future<CharacterClaimPoolData?> get(String characterId) =>
      (select(characterClaimPool)
            ..where((t) => t.characterId.equals(characterId)))
          .getSingleOrNull();

  Stream<List<CharacterClaimPoolData>> watchAvailable(String worldId) =>
      (select(characterClaimPool)
            ..where((t) =>
                t.worldId.equals(worldId) & t.available.equals(true)))
          .watch()
          .distinct();

  Future<void> upsert(CharacterClaimPoolCompanion row) =>
      into(characterClaimPool).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<CharacterClaimPoolCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(characterClaimPool, rows);
    });
  }

  Future<int> deleteById(String characterId) =>
      (delete(characterClaimPool)
            ..where((t) => t.characterId.equals(characterId)))
          .go();
}
