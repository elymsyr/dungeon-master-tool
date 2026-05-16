import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_entities` (migration 026). Replaces v11's
/// `entities` (renamed; `campaign_id` → `world_id`).
class WorldEntities extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
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
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
