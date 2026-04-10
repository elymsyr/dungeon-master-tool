import 'package:drift/drift.dart';

import 'packages_table.dart';

/// Paket entity tablosu — Entities'in paket karşılığı.
class PackageEntities extends Table {
  TextColumn get id => text()();
  TextColumn get packageId => text().references(Packages, #id)();
  TextColumn get categorySlug => text()();
  TextColumn get name => text()();
  TextColumn get source => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get imagePath => text().withDefault(const Constant(''))();
  TextColumn get imagesJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get dmNotes => text().withDefault(const Constant(''))();
  TextColumn get pdfsJson => text().withDefault(const Constant('[]'))();
  TextColumn get locationId => text().nullable()();
  TextColumn get fieldsJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
