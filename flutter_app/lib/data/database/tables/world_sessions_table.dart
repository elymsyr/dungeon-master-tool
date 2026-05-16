import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_sessions` (migration 042). Replaces v11's
/// `sessions` (legacy notes/logs columns dropped — collapsed into data_json).
class WorldSessions extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
