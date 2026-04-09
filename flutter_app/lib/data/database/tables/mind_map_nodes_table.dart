import 'package:drift/drift.dart';

import 'campaigns_table.dart';
import 'entities_table.dart';

/// Supabase mirror: mind_map_nodes tablosu.
class MindMapNodes extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
  TextColumn get mapId => text()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get nodeType =>
      text().withDefault(const Constant('note'))();
  RealColumn get x => real().withDefault(const Constant(0.0))();
  RealColumn get y => real().withDefault(const Constant(0.0))();
  RealColumn get width => real().withDefault(const Constant(150.0))();
  RealColumn get height => real().withDefault(const Constant(80.0))();
  TextColumn get entityId =>
      text().nullable().references(Entities, #id)();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get styleJson => text().withDefault(const Constant('{}'))();
  TextColumn get color => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
