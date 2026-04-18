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
  /// V3 rule engine: resource pool'ları (spell slots, hit dice, rage, vb.).
  TextColumn get resourcesJson => text().withDefault(const Constant('{}'))();
  /// V3 rule engine: kullanıcı seçimleri.
  TextColumn get choicesJson => text().withDefault(const Constant('{}'))();
  /// V3 rule engine: encounter turn state (null ise "{}" JSON blob).
  TextColumn get turnStateJson => text().withDefault(const Constant('{}'))();
  /// V3 rule engine: aktif buff/debuff/condition listesi.
  TextColumn get activeEffectsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
