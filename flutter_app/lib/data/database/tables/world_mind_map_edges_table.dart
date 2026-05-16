import 'package:drift/drift.dart';

import 'worlds_table.dart';

/// Mirrors Postgres `public.world_mind_map_edges` (migration 026).
class WorldMindMapEdges extends Table {
  TextColumn get id => text()();
  TextColumn get worldId => text().references(Worlds, #id)();
  TextColumn get mapId => text()();
  TextColumn get sourceId => text()();
  TextColumn get targetId => text()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get styleJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
