import 'package:drift/drift.dart';

import 'campaigns_table.dart';
import 'mind_map_nodes_table.dart';

/// Supabase mirror: mind_map_edges tablosu.
@ReferenceName('sourceEdges')
@ReferenceName('targetEdges')
class MindMapEdges extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text().references(Campaigns, #id)();
  TextColumn get mapId => text()();
  @ReferenceName('sourceEdges')
  TextColumn get sourceId => text().references(MindMapNodes, #id)();
  @ReferenceName('targetEdges')
  TextColumn get targetId => text().references(MindMapNodes, #id)();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get styleJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
