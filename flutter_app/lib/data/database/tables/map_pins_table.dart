import 'package:drift/drift.dart';

import 'campaigns_table.dart';
import 'entities_table.dart';

/// Supabase mirror: map_pins tablosu.
class MapPins extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
  RealColumn get x => real()();
  RealColumn get y => real()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get pinType =>
      text().withDefault(const Constant('default'))();
  TextColumn get entityId =>
      text().nullable().references(Entities, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant(''))();
  TextColumn get styleJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
