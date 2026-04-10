import 'package:drift/drift.dart';

import 'packages_table.dart';

/// Paket schema tablosu — WorldSchemas'ın paket karşılığı.
class PackageSchemas extends Table {
  TextColumn get id => text()();
  TextColumn get packageId => text().references(Packages, #id)();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get version => text().withDefault(const Constant('1.0'))();
  TextColumn get baseSystem => text().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get categoriesJson => text().withDefault(const Constant('[]'))();
  TextColumn get encounterConfigJson =>
      text().withDefault(const Constant('{}'))();
  TextColumn get encounterLayoutsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  TextColumn get templateId => text().nullable()();
  TextColumn get templateHash => text().nullable()();
  TextColumn get templateOriginalHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
