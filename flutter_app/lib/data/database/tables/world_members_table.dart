import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_members` (migration 026).
class WorldMembers extends Table {
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get userId => text()();
  TextColumn get role => text()(); // 'dm' | 'player'
  DateTimeColumn get joinedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {worldId, userId};
}
