import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/campaign_dao.dart';
import 'daos/entity_dao.dart';
import 'daos/map_dao.dart';
import 'daos/mind_map_dao.dart';
import 'daos/session_dao.dart';
import 'tables/campaigns_table.dart';
import 'tables/combat_conditions_table.dart';
import 'tables/combatants_table.dart';
import 'tables/encounters_table.dart';
import 'tables/entities_table.dart';
import 'tables/map_pins_table.dart';
import 'tables/mind_map_edges_table.dart';
import 'tables/mind_map_nodes_table.dart';
import 'tables/sessions_table.dart';
import 'tables/timeline_pins_table.dart';
import 'tables/world_schemas_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Campaigns,
    WorldSchemas,
    Entities,
    Sessions,
    Encounters,
    Combatants,
    CombatConditions,
    MapPins,
    TimelinePins,
    MindMapNodes,
    MindMapEdges,
  ],
  daos: [
    CampaignDao,
    EntityDao,
    SessionDao,
    MapDao,
    MindMapDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test ve custom path desteği.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Future schema migrations burada yönetilecek.
          // Supabase migration'ları ile senkron tutulacak.
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'DungeonMasterTool'));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final file = File(p.join(dbDir.path, 'dmt.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
