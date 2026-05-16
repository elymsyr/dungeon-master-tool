import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_packages` (migration 043). DM-shared
/// package state visible to all world members.
class WorldPackages extends Table {
  TextColumn get packageId => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get packageName => text().withDefault(const Constant(''))();
  TextColumn get sharedBy => text().nullable()();
  TextColumn get stateJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {packageId};
}
