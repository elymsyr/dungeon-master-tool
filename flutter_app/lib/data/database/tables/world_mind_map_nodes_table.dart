import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_mind_map_nodes` (migration 026).
class WorldMindMapNodes extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get mapId => text()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get nodeType => text().withDefault(const Constant('note'))();
  RealColumn get x => real().withDefault(const Constant(0.0))();
  RealColumn get y => real().withDefault(const Constant(0.0))();
  RealColumn get width => real().withDefault(const Constant(150.0))();
  RealColumn get height => real().withDefault(const Constant(80.0))();
  TextColumn get entityId => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get styleJson => text().withDefault(const Constant('{}'))();
  TextColumn get color => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
