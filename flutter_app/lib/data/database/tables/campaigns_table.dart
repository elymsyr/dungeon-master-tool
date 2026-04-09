import 'package:drift/drift.dart';

/// Supabase mirror: campaigns tablosu.
class Campaigns extends Table {
  TextColumn get id => text()();
  TextColumn get worldName => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
