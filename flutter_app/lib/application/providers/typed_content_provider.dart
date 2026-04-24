import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/dnd5e_content_dao.dart';
import '../../data/database/database_provider.dart';
import 'campaign_packages_provider.dart';
import 'campaign_provider.dart';

/// Tier 2 typed content providers — read Drift rows by id for
/// `TypedCardDispatcher`. Rows still carry JSON bodies; per-card widgets
/// decode via existing domain codecs.

final dnd5eContentDaoProvider = Provider<Dnd5eContentDao>((ref) {
  return ref.watch(appDatabaseProvider).dnd5eContentDao;
});

/// When the active campaign has a homebrew override at `hb:<cid>:<id>`,
/// typed-row reads transparently prefer that row so a single card opens
/// the user's edit instead of the pristine package row.
Future<T?> _withOverride<T>(
  Ref ref,
  String id,
  Future<T?> Function(String) lookup,
) async {
  final cid = ref.watch(activeCampaignIdProvider);
  if (cid != null) {
    final prefix = 'hb:$cid:';
    if (!id.startsWith(prefix)) {
      final override = await lookup('$prefix$id');
      if (override != null) return override;
    }
  }
  return lookup(id);
}

final spellRowProvider =
    FutureProvider.family<Spell?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getSpell);
});

final monsterRowProvider =
    FutureProvider.family<Monster?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getMonster);
});

final itemRowProvider =
    FutureProvider.family<Item?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getItem);
});

final featRowProvider =
    FutureProvider.family<Feat?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getFeat);
});

final backgroundRowProvider =
    FutureProvider.family<Background?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getBackground);
});

final speciesRowProvider =
    FutureProvider.family<SpeciesCatalogData?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getSpecies);
});

final subclassRowProvider =
    FutureProvider.family<SubclassesData?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getSubclass);
});

final classProgressionRowProvider =
    FutureProvider.family<ClassProgression?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getClassProgression);
});

final conditionRowProvider =
    FutureProvider.family<Condition?, String>((ref, id) async {
  final dao = ref.watch(dnd5eContentDaoProvider);
  return _withOverride(ref, id, dao.getCondition);
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

// --- Per-world scoped providers (Doc 51) ---

/// Emits the list of typed rows visible in the currently-active campaign —
/// either because the row's `installedPackageId` is enabled in the world
/// (via `campaign_packages`) or because the row is user-created homebrew
/// scoped to this world via `campaignId`.
///
/// When no campaign is active (hub screen with nothing loaded) these
/// providers yield the empty list — they are strictly world-scoped.

Stream<List<T>> _emptyStream<T>() => const Stream.empty();

final spellsForActiveCampaignProvider = StreamProvider<List<Spell>>((ref) {
  final campaignId = ref.watch(activeCampaignIdProvider);
  if (campaignId == null) return _emptyStream();
  final dao = ref.watch(dnd5eContentDaoProvider);
  final enabledAsync =
      ref.watch(enabledPackageIdsForCampaignProvider(campaignId));
  final enabled = enabledAsync.valueOrNull ?? const <String>{};
  return dao.watchSpellsForCampaign(campaignId, enabled);
});

final monstersForActiveCampaignProvider =
    StreamProvider<List<Monster>>((ref) {
  final campaignId = ref.watch(activeCampaignIdProvider);
  if (campaignId == null) return _emptyStream();
  final dao = ref.watch(dnd5eContentDaoProvider);
  final enabledAsync =
      ref.watch(enabledPackageIdsForCampaignProvider(campaignId));
  final enabled = enabledAsync.valueOrNull ?? const <String>{};
  return dao.watchMonstersForCampaign(campaignId, enabled);
});

final itemsForActiveCampaignProvider = StreamProvider<List<Item>>((ref) {
  final campaignId = ref.watch(activeCampaignIdProvider);
  if (campaignId == null) return _emptyStream();
  final dao = ref.watch(dnd5eContentDaoProvider);
  final enabledAsync =
      ref.watch(enabledPackageIdsForCampaignProvider(campaignId));
  final enabled = enabledAsync.valueOrNull ?? const <String>{};
  return dao.watchItemsForCampaign(campaignId, enabled);
});

final featsForActiveCampaignProvider = StreamProvider<List<Feat>>((ref) {
  final campaignId = ref.watch(activeCampaignIdProvider);
  if (campaignId == null) return _emptyStream();
  final dao = ref.watch(dnd5eContentDaoProvider);
  final enabledAsync =
      ref.watch(enabledPackageIdsForCampaignProvider(campaignId));
  final enabled = enabledAsync.valueOrNull ?? const <String>{};
  return dao.watchFeatsForCampaign(campaignId, enabled);
});

final backgroundsForActiveCampaignProvider =
    StreamProvider<List<Background>>((ref) {
  final campaignId = ref.watch(activeCampaignIdProvider);
  if (campaignId == null) return _emptyStream();
  final dao = ref.watch(dnd5eContentDaoProvider);
  final enabledAsync =
      ref.watch(enabledPackageIdsForCampaignProvider(campaignId));
  final enabled = enabledAsync.valueOrNull ?? const <String>{};
  return dao.watchBackgroundsForCampaign(campaignId, enabled);
});

final homebrewForActiveCampaignProvider =
    StreamProvider<List<HomebrewEntry>>((ref) {
  final campaignId = ref.watch(activeCampaignIdProvider);
  if (campaignId == null) return _emptyStream();
  final dao = ref.watch(dnd5eContentDaoProvider);
  return dao.watchHomebrewForCampaign(campaignId);
});

// --- Shared catalog streams (Doc 03 Tier 1) ---
//
// Catalog tables (conditions, damage types, sizes, spell schools, rarities,
// alignments, weapon properties, skills, creature types, languages, weapon
// masteries, armor categories) are shared across campaigns — they don't
// carry a `campaignId` column. We still expose them as per-app streams so
// `entitySummaryByIdProvider` can resolve ids to their proper display name
// (otherwise link chips fall back to a slug-cased guess).

final allConditionsProvider = StreamProvider<List<Condition>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.conditions).watch();
});

final allDamageTypesProvider = StreamProvider<List<DamageType>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.damageTypes).watch();
});

final allSizesProvider = StreamProvider<List<Size>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.sizes).watch();
});

final allSpellSchoolsProvider = StreamProvider<List<SpellSchool>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.spellSchools).watch();
});

final allRaritiesProvider = StreamProvider<List<Rarity>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.rarities).watch();
});

final allAlignmentsProvider = StreamProvider<List<Alignment>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.alignments).watch();
});

final allWeaponPropertiesProvider =
    StreamProvider<List<WeaponProperty>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.weaponProperties).watch();
});

final allWeaponMasteriesProvider =
    StreamProvider<List<WeaponMastery>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.weaponMasteries).watch();
});

final allArmorCategoriesProvider =
    StreamProvider<List<ArmorCategory>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.armorCategories).watch();
});

final allSkillsProvider = StreamProvider<List<Skill>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.skills).watch();
});

final allCreatureTypesProvider = StreamProvider<List<CreatureType>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.creatureTypes).watch();
});

final allLanguagesProvider = StreamProvider<List<Language>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.languages).watch();
});

final allSpeciesProvider = StreamProvider<List<SpeciesCatalogData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.speciesCatalog).watch();
});

final allSubclassesProvider = StreamProvider<List<SubclassesData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.subclasses).watch();
});

final allClassProgressionsProvider =
    StreamProvider<List<ClassProgression>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.classProgressions).watch();
});
