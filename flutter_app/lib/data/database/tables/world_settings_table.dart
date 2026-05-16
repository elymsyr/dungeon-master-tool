import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_settings` (migration 042). 1:1 with world.
class WorldSettings extends Table {
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {worldId};
}
