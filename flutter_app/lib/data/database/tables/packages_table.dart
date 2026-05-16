import 'package:drift/drift.dart';

/// Paket tablosu — Campaign'in basitleştirilmiş karşılığı.
class Packages extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get stateJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Last successful cloud push timestamp (PR-SYNC-1).
  DateTimeColumn get lastCloudPushAt => dateTime().nullable()();

  /// SHA-256 of the last payload pushed to the cloud (PR-SYNC-1).
  TextColumn get lastPushedHash => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
