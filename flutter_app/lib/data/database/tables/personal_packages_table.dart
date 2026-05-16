import 'package:drift/drift.dart';

/// Mirrors Postgres `public.personal_packages` (migration 033).
class PersonalPackages extends Table {
  TextColumn get ownerId => text()();
  TextColumn get packageName => text()();
  TextColumn get stateJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {ownerId, packageName};
}
