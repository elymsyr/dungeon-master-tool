import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_invites` (migration 026). Local cache for
/// DM-side invite management.
class WorldInvites extends Table {
  TextColumn get code => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get createdBy => text()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  IntColumn get usesLeft => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {code};
}
