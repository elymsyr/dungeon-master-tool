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

  /// Faz 5g — silme karakterin kapsamına ([characterScope]) yazılır, dünyaya
  /// değil: karakter turu sahiplik kapısıyla koşuyor. Yalnız bulutta duran
  /// (`is_online`) satır için.
  ///
  /// [tombstone] false: satır yalnız bu cihazdan kalkıyor (sahiplik başkasına
  /// geçti, bulut silmesi uygulanıyor). Kayıt bıraksaydı tur bulut satırını
  /// silerdi — DM'in cihazı oyuncunun karakterini böyle silebiliyordu.
  Future<int> deleteById(String id, {bool tombstone = true}) async {
    final row = await getById(id);
    if (tombstone && row != null && row.isOnline) {
      await recordTombstone('world_characters', id, worldId: characterScope);
    }
    return (delete(worldCharacters)..where((t) => t.id.equals(id))).go();
  }

  /// Dünya yerelden silinirken karakterleri de. Tombstone **yok**: dünyanın
  /// karakterleri arasında oyuncularınki de var, DM'in cihazından buluta
  /// silme gitmemeli. Online dünyanın bulut tarafı multiplayer'ı kapatma
  /// akışında (sahipsizler silinir, sahipliler dünyasız kalır).
  Future<int> deleteByWorld(String worldId) =>
      (delete(worldCharacters)..where((t) => t.worldId.equals(worldId))).go();

  /// Bulutta duran karakterlerin id'leri — anahtarın UI'ı için.
  Stream<Set<String>> watchOnlineIds() =>
      (selectOnly(worldCharacters)
            ..addColumns([worldCharacters.id])
            ..where(worldCharacters.isOnline.equals(true)))
          .watch()
          .map((rows) => {for (final r in rows) r.read(worldCharacters.id)!});

  /// Faz 5g — karakterin kendi anahtarı. Açılınca satır damgalanır: tur
  /// damgadan sonra değişenleri gönderiyor, eski bir karakter yoksa hiç
  /// gitmezdi.
  Future<void> setOnline(String id, bool online) =>
      (update(worldCharacters)..where((t) => t.id.equals(id))).write(
          WorldCharactersCompanion(
              isOnline: Value(online),
              updatedAt:
                  online ? Value(DateTime.now()) : const Value.absent()));

  /// Turun yazdığı satırlar bulutta: damgaya dokunmadan işaretlenir.
  Future<void> markOnline(Iterable<String> ids) =>
      (update(worldCharacters)..where((t) => t.id.isIn(ids)))
          .write(const WorldCharactersCompanion(isOnline: Value(true)));

  /// Karakter kapsamının damgaları (`cloud_scopes`, Faz 5g).
  Future<({DateTime? pushedAt, int revision})> cloudMark() async {
    final r = await customSelect(
      'SELECT last_push_at, cloud_revision FROM cloud_scopes WHERE scope = ?',
      variables: [const Variable<String>(characterScope)],
    ).getSingleOrNull();
    final at = r?.data['last_push_at'];
    return (
      pushedAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
      revision: (r?.data['cloud_revision'] as int?) ?? 0,
    );
  }

  Future<void> setCloudPushAt(DateTime at) => customStatement(
        'INSERT INTO cloud_scopes (scope, last_push_at) VALUES (?, ?) '
        'ON CONFLICT (scope) DO UPDATE SET last_push_at = excluded.last_push_at',
        [characterScope, at.millisecondsSinceEpoch],
      );

  /// [ifEquals] verilirse yalnız damga hâlâ o değerdeyse yazar: tur sürerken
  /// bir pull ilerlettiyse ona dokunmaz.
  Future<void> setCloudRevision(int revision, {int? ifEquals}) =>
      customStatement(
        'INSERT INTO cloud_scopes (scope, cloud_revision) VALUES (?, ?) '
        'ON CONFLICT (scope) DO UPDATE SET cloud_revision = excluded.cloud_revision'
        '${ifEquals == null ? '' : ' WHERE cloud_scopes.cloud_revision = ?'}',
        [characterScope, revision, ?ifEquals],
      );

  /// Sahipliği düşürmek buluta da gitmeli (RLS `owner_id`'ye bakıyor), o
  /// yüzden satır damgalanıyor — damgasız kalsa push taramasına girmezdi.
  Future<int> dropOwnership(String id) =>
      (update(worldCharacters)..where((t) => t.id.equals(id))).write(
          WorldCharactersCompanion(
              ownerId: const Value(null), updatedAt: Value(DateTime.now())));

  /// `.dmtz` import: yeniden adlandırma zamanını kaydet.
  Future<void> setRenamedAt(String id, DateTime renamedAt) async {
    await (update(worldCharacters)..where((t) => t.id.equals(id)))
        .write(WorldCharactersCompanion(renamedAt: Value(renamedAt)));
  }
}
