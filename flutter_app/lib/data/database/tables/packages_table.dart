import 'package:drift/drift.dart';

/// Local hub-level package catalog. No Postgres counterpart — `personal_packages`
/// (33) carries sync-relevant state; this table is the catalog index DM uses.
class Packages extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get stateJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastCloudPushAt => dateTime().nullable()();
  TextColumn get lastPushedHash => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
