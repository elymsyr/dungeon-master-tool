import 'package:drift/drift.dart';

import 'campaigns_table.dart';

/// PR-SYNC-5: local mirror of a DM-shared world package. Rows arrive via
/// Supabase `world_packages` CDC and provide the package state visible to
/// all members of a world.
class WorldPackages extends Table {
  TextColumn get worldId => text().references(Campaigns, #id)();
  TextColumn get packageId => text()();
  TextColumn get packageName => text().withDefault(const Constant(''))();
  TextColumn get sharedBy => text().nullable()();
  TextColumn get stateJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {worldId, packageId};
}
