import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/dnd5e_content_dao.dart';
import '../../data/database/database_provider.dart';

/// Tier 2 typed content providers — read Drift rows by id for
/// `TypedCardDispatcher`. Rows still carry JSON bodies; per-card widgets
/// decode via existing domain codecs.

final dnd5eContentDaoProvider = Provider<Dnd5eContentDao>((ref) {
  return ref.watch(appDatabaseProvider).dnd5eContentDao;
});

final spellRowProvider =
    FutureProvider.family<Spell?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getSpell(id);
});

final monsterRowProvider =
    FutureProvider.family<Monster?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getMonster(id);
});

final itemRowProvider =
    FutureProvider.family<Item?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getItem(id);
});

final featRowProvider =
    FutureProvider.family<Feat?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getFeat(id);
});

final backgroundRowProvider =
    FutureProvider.family<Background?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getBackground(id);
});

final speciesRowProvider =
    FutureProvider.family<SpeciesCatalogData?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getSpecies(id);
});

final subclassRowProvider =
    FutureProvider.family<SubclassesData?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getSubclass(id);
});

final classProgressionRowProvider =
    FutureProvider.family<ClassProgression?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getClassProgression(id);
});

final conditionRowProvider =
    FutureProvider.family<Condition?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getCondition(id);
});

final homebrewEntryRowProvider =
    FutureProvider.family<HomebrewEntry?, String>((ref, id) async {
  return ref.watch(dnd5eContentDaoProvider).getHomebrewEntry(id);
});

final allHomebrewProvider = StreamProvider<List<HomebrewEntry>>((ref) {
  return ref.watch(dnd5eContentDaoProvider).watchAllHomebrew();
});

final allSpellsProvider = StreamProvider<List<Spell>>((ref) {
  return ref.watch(dnd5eContentDaoProvider).watchAllSpells();
});

final allMonstersProvider = StreamProvider<List<Monster>>((ref) {
  return ref.watch(dnd5eContentDaoProvider).watchAllMonsters();
});

final allItemsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(dnd5eContentDaoProvider).watchAllItems();
});

final allFeatsProvider = StreamProvider<List<Feat>>((ref) {
  return ref.watch(dnd5eContentDaoProvider).watchAllFeats();
});

final allBackgroundsProvider = StreamProvider<List<Background>>((ref) {
  return ref.watch(dnd5eContentDaoProvider).watchAllBackgrounds();
});
