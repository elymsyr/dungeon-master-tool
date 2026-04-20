import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_paths.dart';
import 'daos/campaign_dao.dart';
import 'daos/dnd5e_content_dao.dart';
import 'daos/entity_dao.dart';
import 'daos/map_dao.dart';
import 'daos/mind_map_dao.dart';
import 'daos/package_dao.dart';
import 'daos/session_dao.dart';
import 'tables/campaign_packages_table.dart';
import 'tables/campaigns_table.dart';
import 'tables/catalog_tables.dart';
import 'tables/combat_conditions_table.dart';
import 'tables/combatants_table.dart';
import 'tables/dnd5e_content_tables.dart';
import 'tables/encounters_table.dart';
import 'tables/entities_table.dart';
import 'tables/homebrew_entries_table.dart';
import 'tables/installed_packages_table.dart';
import 'tables/map_pins_table.dart';
import 'tables/mind_map_edges_table.dart';
import 'tables/mind_map_nodes_table.dart';
import 'tables/package_entities_table.dart';
import 'tables/package_schemas_table.dart';
import 'tables/packages_table.dart';
import 'tables/sessions_table.dart';
import 'tables/timeline_pins_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Campaigns,
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
    // Doc 50 — Homebrew world-content entries (quest/location/lore/plane/
    // status-effect). Additive; legacy `entities` blob still live.
    HomebrewEntries,
    // Doc 51 — Per-world package enablement (M:N campaigns ↔ installed_packages).
    CampaignPackages,
  ],
  daos: [
    CampaignDao,
    EntityDao,
    SessionDao,
    MapDao,
    MindMapDao,
    PackageDao,
    Dnd5eContentDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Per-user database: userId verilirse user-scoped path kullanılır.
  AppDatabase.forUser(String? userId) : super(_openConnectionForUser(userId));

  /// Test ve custom path desteği.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: campaigns.state_json eklendi
            await m.addColumn(campaigns, campaigns.stateJson);
          }
          if (from < 3) {
            // v3: world_schemas.template_id + template_hash — legacy column
            // adds on a since-dropped table. No-op under v9.
          }
          if (from < 4) {
            // v4: world_schemas.template_original_hash — legacy column add
            // on a since-dropped table. No-op under v9.
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
          if (from < 8) {
            // v8: Doc 15 attribution surface — author + license + description
            // columns on installed_packages so the CC BY 4.0 attribution
            // screen can render every installed package without re-loading
            // its source asset.
            await m.addColumn(installedPackages, installedPackages.authorName);
            await m.addColumn(
                installedPackages, installedPackages.sourceLicense);
            await m.addColumn(installedPackages, installedPackages.description);
          }
          if (from < 9) {
            // v9: Doc 04 Step 7 partial — drop the legacy `world_schemas`
            // table. The single hardcoded D&D 5e schema is now always
            // injected at read time via `generateDefaultDnd5eSchema()`,
            // so per-campaign schema rows carry no value.
            // LegacyDbBackup snapshots the pre-v9 DB to
            // `dmt.v4.backup.sqlite` before this fires.
            await m.deleteTable('world_schemas');
          }
          if (from < 10) {
            // v10: Doc 50 Batch 7 — typed homebrew world-content entries.
            // Additive only; the legacy `entities` blob stays live until
            // Phase D's full typed-UI cutover retires it.
            await m.createTable(homebrewEntries);
          }
          if (from < 11) {
            // v11: Doc 51 — per-world package enablement + typed-content
            // campaignId scope. New `campaign_packages` join table; typed
            // content tables gain nullable `campaignId` (user-created
            // homebrew scoped to one world) and `installedPackageId`
            // (points at `installed_packages.id` so content rows from
            // splits that share a `packageIdSlug` — e.g. `srd-rules-1` and
            // `srd-spells-1` under slug `srd` — can be enabled/disabled
            // independently per world).
            await m.createTable(campaignPackages);
            await m.addColumn(spells, spells.campaignId);
            await m.addColumn(spells, spells.installedPackageId);
            await m.addColumn(monsters, monsters.campaignId);
            await m.addColumn(monsters, monsters.installedPackageId);
            await m.addColumn(items, items.campaignId);
            await m.addColumn(items, items.installedPackageId);
            await m.addColumn(feats, feats.campaignId);
            await m.addColumn(feats, feats.installedPackageId);
            await m.addColumn(backgrounds, backgrounds.campaignId);
            await m.addColumn(backgrounds, backgrounds.installedPackageId);
            await m.addColumn(speciesCatalog, speciesCatalog.campaignId);
            await m.addColumn(
                speciesCatalog, speciesCatalog.installedPackageId);
            await m.addColumn(subclasses, subclasses.campaignId);
            await m.addColumn(subclasses, subclasses.installedPackageId);
            await m.addColumn(classProgressions, classProgressions.campaignId);
            await m.addColumn(
                classProgressions, classProgressions.installedPackageId);
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
