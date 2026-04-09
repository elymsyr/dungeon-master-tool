import 'package:drift/drift.dart';

import 'campaigns_table.dart';

/// Supabase mirror: world_schemas tablosu.
/// categories, encounter_config, encounter_layouts → jsonb columns.
class WorldSchemas extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
