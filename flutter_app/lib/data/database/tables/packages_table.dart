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
  DateTimeColumn get renamedAt => dateTime().nullable()();

  /// Faz 4 — paketin bulut aynası açık mı (dünyayla aynı mantık, §1.2).
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();
  IntColumn get cloudRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
