import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/catalog_tables.dart';
import '../tables/dnd5e_content_tables.dart';
import '../tables/homebrew_entries_table.dart';

part 'dnd5e_content_dao.g.dart';

/// Tier 2 typed content accessor — reads the Doc 03 JSON-blob tables by id.
/// Backs typed cards (SpellCard / MonsterCard / …) via
/// `typed_content_provider.dart`. No per-field SQL; whole row loaded.
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

  Future<void> upsertHomebrewEntry(HomebrewEntriesCompanion row) =>
      into(homebrewEntries).insertOnConflictUpdate(row);

  Future<int> deleteHomebrewEntry(String id) =>
      (delete(homebrewEntries)..where((t) => t.id.equals(id))).go();

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
}
