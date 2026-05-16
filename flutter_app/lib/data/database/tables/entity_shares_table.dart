import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.entity_shares` (migration 026). DM "Paylaş"
/// records. `sharedWith` NULL = visible to all world members.
class EntityShares extends Table {
  TextColumn get id => text()();
  TextColumn get entityId => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get sharedWith => text().nullable()();
  TextColumn get sharedBy => text()();
  DateTimeColumn get sharedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
