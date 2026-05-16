import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/personal_packages_table.dart';

part 'personal_packages_dao.g.dart';

@DriftAccessor(tables: [PersonalPackages])
class PersonalPackagesDao extends DatabaseAccessor<AppDatabase>
    with _$PersonalPackagesDaoMixin {
  PersonalPackagesDao(super.db);

  Future<PersonalPackage?> get(String ownerId, String packageName) =>
      (select(personalPackages)
            ..where((t) =>
                t.ownerId.equals(ownerId) &
                t.packageName.equals(packageName)))
          .getSingleOrNull();

  Stream<List<PersonalPackage>> watchByOwner(String ownerId) =>
      (select(personalPackages)..where((t) => t.ownerId.equals(ownerId)))
          .watch()
          .distinct();

  Future<void> upsert(PersonalPackagesCompanion row) =>
      into(personalPackages).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<PersonalPackagesCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(personalPackages, rows);
    });
  }

  Future<int> deleteOne(String ownerId, String packageName) =>
      (delete(personalPackages)
            ..where((t) =>
                t.ownerId.equals(ownerId) &
                t.packageName.equals(packageName)))
          .go();
}
