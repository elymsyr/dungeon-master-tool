import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/campaign_packages_table.dart';
import '../tables/catalog_tables.dart';
import '../tables/dnd5e_content_tables.dart';
import '../tables/homebrew_entries_table.dart';

part 'dnd5e_content_dao.g.dart';

/// Tier 2 typed content accessor — reads the Doc 03 JSON-blob tables by id.
/// Backs typed cards (SpellCard / MonsterCard / …) via
/// `typed_content_provider.dart`. No per-field SQL; whole row loaded.
///
/// Per-world scoping (Doc 51): `watchFor`/`getFor`-prefixed methods take a
/// campaign id + enabled package set and return rows whose `campaignId`
/// matches the world OR whose `sourcePackageId` is in the enabled set.
/// `watchAll*` unfiltered variants remain for settings/admin screens that
/// should see every installed row.
@DriftAccessor(tables: [
  Spells,
  Monsters,
  Items,
  Feats,
  Backgrounds,
  SpeciesCatalog,
  Subclasses,
  ClassProgressions,
  Conditions,
  HomebrewEntries,
  CampaignPackages,
])
class Dnd5eContentDao extends DatabaseAccessor<AppDatabase>
    with _$Dnd5eContentDaoMixin {
  Dnd5eContentDao(super.db);

  Future<Spell?> getSpell(String id) =>
      (select(spells)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Monster?> getMonster(String id) =>
      (select(monsters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Item?> getItem(String id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Feat?> getFeat(String id) =>
      (select(feats)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Background?> getBackground(String id) =>
      (select(backgrounds)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<SpeciesCatalogData?> getSpecies(String id) =>
      (select(speciesCatalog)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<SubclassesData?> getSubclass(String id) =>
      (select(subclasses)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ClassProgression?> getClassProgression(String id) =>
      (select(classProgressions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<Condition?> getCondition(String id) =>
      (select(conditions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<HomebrewEntry?> getHomebrewEntry(String id) =>
      (select(homebrewEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<HomebrewEntry>> homebrewByCategory(String categorySlug) =>
      (select(homebrewEntries)
            ..where((t) => t.categorySlug.equals(categorySlug)))
          .get();

  Stream<List<HomebrewEntry>> watchAllHomebrew() =>
      select(homebrewEntries).watch();

  Stream<List<HomebrewEntry>> watchHomebrewForCampaign(String campaignId) =>
      (select(homebrewEntries)
            ..where((t) => t.campaignId.equals(campaignId) | t.campaignId.isNull()))
          .watch();

  Future<void> upsertHomebrewEntry(HomebrewEntriesCompanion row) =>
      into(homebrewEntries).insertOnConflictUpdate(row);

  Future<int> deleteHomebrewEntry(String id) =>
      (delete(homebrewEntries)..where((t) => t.id.equals(id))).go();

  // --- Unfiltered reads (admin / settings / tests) ---

  Future<List<Spell>> allSpells() => select(spells).get();
  Future<List<Monster>> allMonsters() => select(monsters).get();
  Future<List<Item>> allItems() => select(items).get();
  Future<List<Feat>> allFeats() => select(feats).get();
  Future<List<Background>> allBackgrounds() => select(backgrounds).get();

  Stream<List<Spell>> watchAllSpells() => select(spells).watch();
  Stream<List<Monster>> watchAllMonsters() => select(monsters).watch();
  Stream<List<Item>> watchAllItems() => select(items).watch();
  Stream<List<Feat>> watchAllFeats() => select(feats).watch();
  Stream<List<Background>> watchAllBackgrounds() =>
      select(backgrounds).watch();

  // --- Per-world filtered reads ---

  /// True when a row is visible in [campaignId] given [enabledInstalledPackageIds]:
  /// package-owned rows match via [Spells.installedPackageId] (etc.) being
  /// in the enabled set; user-created homebrew matches via the `campaignId`
  /// column. Caller passes `installed_packages.id` values — splits that
  /// share a slug (e.g. `srd-rules-1`, `srd-spells-1` both under `srd`) are
  /// togglable independently.
  Stream<List<Spell>> watchSpellsForCampaign(
    String campaignId,
    Set<String> enabledInstalledPackageIds,
  ) =>
      (select(spells)
            ..where((t) =>
                t.campaignId.equals(campaignId) |
                t.installedPackageId.isIn(enabledInstalledPackageIds)))
          .watch();

  Stream<List<Monster>> watchMonstersForCampaign(
    String campaignId,
    Set<String> enabledInstalledPackageIds,
  ) =>
      (select(monsters)
            ..where((t) =>
                t.campaignId.equals(campaignId) |
                t.installedPackageId.isIn(enabledInstalledPackageIds)))
          .watch();

  Stream<List<Item>> watchItemsForCampaign(
    String campaignId,
    Set<String> enabledInstalledPackageIds,
  ) =>
      (select(items)
            ..where((t) =>
                t.campaignId.equals(campaignId) |
                t.installedPackageId.isIn(enabledInstalledPackageIds)))
          .watch();

  Stream<List<Feat>> watchFeatsForCampaign(
    String campaignId,
    Set<String> enabledInstalledPackageIds,
  ) =>
      (select(feats)
            ..where((t) =>
                t.campaignId.equals(campaignId) |
                t.installedPackageId.isIn(enabledInstalledPackageIds)))
          .watch();

  Stream<List<Background>> watchBackgroundsForCampaign(
    String campaignId,
    Set<String> enabledInstalledPackageIds,
  ) =>
      (select(backgrounds)
            ..where((t) =>
                t.campaignId.equals(campaignId) |
                t.installedPackageId.isIn(enabledInstalledPackageIds)))
          .watch();

  // --- Typed-content writes (homebrew) ---

  Future<void> upsertSpell(SpellsCompanion row) =>
      into(spells).insertOnConflictUpdate(row);
  Future<void> upsertMonster(MonstersCompanion row) =>
      into(monsters).insertOnConflictUpdate(row);
  Future<void> upsertItem(ItemsCompanion row) =>
      into(items).insertOnConflictUpdate(row);
  Future<void> upsertFeat(FeatsCompanion row) =>
      into(feats).insertOnConflictUpdate(row);
  Future<void> upsertBackground(BackgroundsCompanion row) =>
      into(backgrounds).insertOnConflictUpdate(row);

  // --- Campaign ↔ package enablement ---

  Future<void> enablePackageInCampaign(String campaignId, String packageId) =>
      into(campaignPackages).insertOnConflictUpdate(
        CampaignPackagesCompanion.insert(
          campaignId: campaignId,
          packageId: packageId,
        ),
      );

  Future<int> disablePackageInCampaign(String campaignId, String packageId) =>
      (delete(campaignPackages)
            ..where((t) =>
                t.campaignId.equals(campaignId) &
                t.packageId.equals(packageId)))
          .go();

  Future<List<String>> enabledPackageIdsForCampaign(String campaignId) async {
    final rows = await (select(campaignPackages)
          ..where((t) => t.campaignId.equals(campaignId)))
        .get();
    return rows.map((r) => r.packageId).toList();
  }

  Stream<List<String>> watchEnabledPackageIdsForCampaign(String campaignId) =>
      (select(campaignPackages)
            ..where((t) => t.campaignId.equals(campaignId)))
          .watch()
          .map((rows) => rows.map((r) => r.packageId).toList());
}
