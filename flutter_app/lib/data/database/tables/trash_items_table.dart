import 'package:drift/drift.dart';

/// Replaces the legacy `/trash/` file directory. Soft-delete records for
/// recovery (kind = entity/character/package/etc).
class TrashItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get sourceId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get deletedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
