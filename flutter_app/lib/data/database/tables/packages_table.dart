import 'package:drift/drift.dart';

/// Paket tablosu — Campaign'in basitleştirilmiş karşılığı.
class Packages extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get stateJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
