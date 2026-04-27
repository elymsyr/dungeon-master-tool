import 'package:drift/drift.dart';

import 'campaigns_table.dart';

/// Supabase mirror: entities tablosu.
/// fields_json → schema-driven dynamic alanlar (Supabase'de jsonb).
class Entities extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
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
  TextColumn get packageId => text().nullable()();
  TextColumn get packageEntityId => text().nullable()();
  BoolColumn get linked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
