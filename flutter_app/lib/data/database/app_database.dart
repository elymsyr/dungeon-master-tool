import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/campaign_dao.dart';
import 'daos/entity_dao.dart';
import 'daos/map_dao.dart';
import 'daos/mind_map_dao.dart';
import 'daos/package_dao.dart';
import 'daos/session_dao.dart';
import 'tables/campaigns_table.dart';
import 'tables/combat_conditions_table.dart';
import 'tables/combatants_table.dart';
import 'tables/encounters_table.dart';
import 'tables/entities_table.dart';
import 'tables/map_pins_table.dart';
import 'tables/mind_map_edges_table.dart';
import 'tables/mind_map_nodes_table.dart';
import 'tables/package_entities_table.dart';
import 'tables/package_schemas_table.dart';
import 'tables/packages_table.dart';
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
    Packages,
    PackageSchemas,
    PackageEntities,
  ],
  daos: [
    CampaignDao,
    EntityDao,
    SessionDao,
    MapDao,
    MindMapDao,
    PackageDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Per-user database: userId verilirse user-scoped path kullanılır.
  AppDatabase.forUser(String? userId) : super(_openConnectionForUser(userId));

  /// Test ve custom path desteği.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: campaigns.state_json eklendi
            await m.addColumn(campaigns, campaigns.stateJson);
          }
          if (from < 3) {
            // v3: world_schemas.template_id + template_hash — lazy
            // template-sync drift detection.
            await m.addColumn(worldSchemas, worldSchemas.templateId);
            await m.addColumn(worldSchemas, worldSchemas.templateHash);
          }
          if (from < 4) {
            // v4: world_schemas.template_original_hash — frozen lineage
            // identifier alongside the existing template_hash (which is
            // now the "current" hash at last sync). Lets the sync flow
            // match a campaign back to its template even after the
            // template's schemaId / current hash change.
            await m.addColumn(
                worldSchemas, worldSchemas.templateOriginalHash);
          }
          if (from < 5) {
            // v5: Paket sistemi — packages, package_schemas, package_entities.
            await m.createTable(packages);
            await m.createTable(packageSchemas);
            await m.createTable(packageEntities);
          }
        },
      );
}

LazyDatabase _openConnection() => _openConnectionForUser(null);

LazyDatabase _openConnectionForUser(String? userId) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final basePath = userId != null
        ? p.join(dir.path, 'DungeonMasterTool', 'users', userId)
        : p.join(dir.path, 'DungeonMasterTool');
    final dbDir = Directory(basePath);
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final file = File(p.join(dbDir.path, 'dmt.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
