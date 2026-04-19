import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_paths.dart';
import 'daos/campaign_dao.dart';
import 'daos/entity_dao.dart';
import 'daos/map_dao.dart';
import 'daos/mind_map_dao.dart';
import 'daos/package_dao.dart';
import 'daos/session_dao.dart';
import 'tables/campaigns_table.dart';
import 'tables/catalog_tables.dart';
import 'tables/combat_conditions_table.dart';
import 'tables/combatants_table.dart';
import 'tables/dnd5e_content_tables.dart';
import 'tables/encounters_table.dart';
import 'tables/entities_table.dart';
import 'tables/installed_packages_table.dart';
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
    // Doc 03 — Tier 1 catalog tables (read-mostly, package-populated).
    Conditions,
    DamageTypes,
    Skills,
    Sizes,
    CreatureTypes,
    Alignments,
    Languages,
    SpellSchools,
    WeaponProperties,
    WeaponMasteries,
    ArmorCategories,
    Rarities,
    // Doc 03 — Tier 1 D&D 5e content tables (JSON-blob catalog).
    Monsters,
    Spells,
    Items,
    Feats,
    Backgrounds,
    SpeciesCatalog,
    Subclasses,
    ClassProgressions,
    // Doc 14 — Installed package registry (typed system).
    InstalledPackages,
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
  int get schemaVersion => 7;

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
          if (from < 6) {
            // v6: Doc 03 typed D&D 5e schema. Additive (does not drop v5
            // tables so still-live consumers keep working until Doc 04
            // Step 5 lands). Catalogs start empty; SRD Core package
            // populates them at install time.
            await m.createTable(conditions);
            await m.createTable(damageTypes);
            await m.createTable(skills);
            await m.createTable(sizes);
            await m.createTable(creatureTypes);
            await m.createTable(alignments);
            await m.createTable(languages);
            await m.createTable(spellSchools);
            await m.createTable(weaponProperties);
            await m.createTable(weaponMasteries);
            await m.createTable(armorCategories);
            await m.createTable(rarities);
            await m.createTable(monsters);
            await m.createTable(spells);
            await m.createTable(items);
            await m.createTable(feats);
            await m.createTable(backgrounds);
            await m.createTable(speciesCatalog);
            await m.createTable(subclasses);
            await m.createTable(classProgressions);
          }
          if (from < 7) {
            // v7: Doc 14 typed-package installed registry (coexists with v5
            // template-coupled `packages` until Doc 04 Step 5 lands).
            await m.createTable(installedPackages);
          }
        },
      );
}

LazyDatabase _openConnection() => _openConnectionForUser(null);

/// Opens the SQLite DB under `AppPaths.dataRoot/db/dmt.sqlite` (per-user:
/// `AppPaths.dataRoot/users/{userId}/db/dmt.sqlite`), unifying the DB with
/// all other user data so update/backup semantics cover everything.
///
/// On first launch after the Apr 2026 migration, the legacy file at
/// `{getApplicationSupportDirectory}/DungeonMasterTool[/users/{userId}]/dmt.sqlite`
/// is copied to the new location if no new-location DB exists yet. The
/// legacy file is NOT deleted — leaves a recovery path if something goes
/// wrong — but a `.moved_to_dataroot` marker is written next to it so we
/// know it's superseded.
LazyDatabase _openConnectionForUser(String? userId) {
  return LazyDatabase(() async {
    final base = userId != null
        ? p.join(AppPaths.dataRoot, 'users', userId)
        : AppPaths.dataRoot;
    final dbDir = Directory(p.join(base, 'db'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    final newFile = File(p.join(dbDir.path, 'dmt.sqlite'));

    if (!newFile.existsSync()) {
      try {
        final support = await getApplicationSupportDirectory();
        final legacyBase = userId != null
            ? p.join(support.path, 'DungeonMasterTool', 'users', userId)
            : p.join(support.path, 'DungeonMasterTool');
        final legacyFile = File(p.join(legacyBase, 'dmt.sqlite'));
        if (legacyFile.existsSync()) {
          await legacyFile.copy(newFile.path);
          await File(p.join(legacyBase, '.moved_to_dataroot'))
              .writeAsString(newFile.path);
        }
      } catch (_) {
        // path_provider unavailable (e.g. tests) — create fresh DB.
      }
    }
    return NativeDatabase.createInBackground(newFile);
  });
}
