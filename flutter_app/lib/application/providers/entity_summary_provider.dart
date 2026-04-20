import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entity_provider.dart';
import 'typed_content_provider.dart';

/// Sidebar-facing row shape. Sits in front of both the generic `entities`
/// blob and the Tier 2 typed content tables so `EntitySidebar` can list
/// them with one watch. `id` carries the namespaced prefix (`srd:` / `hb:`)
/// for typed rows; generic rows keep their bare uuid.
typedef EntitySummary = ({
  String id,
  String name,
  String categorySlug,
  String source,
  String? installedPackageId,
  List<String> tags,
});

/// Merged summary list used both by the sidebar and by cross-entity link
/// resolution (see [entitySummaryByIdProvider]). Generic entities stream
/// from [entityProvider]; typed content streams from the per-campaign
/// scoped providers in `typed_content_provider.dart` so the sidebar only
/// shows content from packages the user has enabled in this world plus
/// the world's own user-created homebrew. Outside an active campaign the
/// campaign-scoped streams are empty — the hub sees only the generic blob.
///
/// Shared catalog rows (conditions, damage types, sizes, spell schools,
/// rarities, alignments, weapon properties, skills, creature types,
/// languages, weapon masteries, armor categories, species, subclasses,
/// class progressions) are merged too so link chips pointing at e.g.
/// `srd:blinded` resolve to the proper capitalized name instead of
/// falling back to a slug guess.
final combinedEntitySummaryProvider =
    Provider<List<EntitySummary>>((ref) {
  final generic = ref.watch(entityProvider.select((m) => m.values
      .map((e) => (
            id: e.id,
            name: e.name,
            categorySlug: e.categorySlug,
            source: e.source,
            installedPackageId: null,
            tags: e.tags,
          ))
      .toList()));

  final spells = ref
      .watch(spellsForActiveCampaignProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final monsters = ref
      .watch(monstersForActiveCampaignProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final items = ref
      .watch(itemsForActiveCampaignProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final feats = ref
      .watch(featsForActiveCampaignProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final backgrounds = ref
      .watch(backgroundsForActiveCampaignProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final homebrew = ref
      .watch(homebrewForActiveCampaignProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);

  final conditions = ref
      .watch(allConditionsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final damageTypes = ref
      .watch(allDamageTypesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final sizes = ref
      .watch(allSizesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final spellSchools = ref
      .watch(allSpellSchoolsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final rarities = ref
      .watch(allRaritiesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final alignments = ref
      .watch(allAlignmentsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final weaponProperties = ref
      .watch(allWeaponPropertiesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final weaponMasteries = ref
      .watch(allWeaponMasteriesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final armorCategories = ref
      .watch(allArmorCategoriesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final skills = ref
      .watch(allSkillsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final creatureTypes = ref
      .watch(allCreatureTypesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final languages = ref
      .watch(allLanguagesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final species = ref
      .watch(allSpeciesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final subclasses = ref
      .watch(allSubclassesProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final classProgressions = ref
      .watch(allClassProgressionsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);

  EntitySummary summary({
    required String id,
    required String name,
    required String categorySlug,
    required String? sourcePackageId,
    required String? installedPackageId,
  }) =>
      (
        id: id,
        name: name,
        categorySlug: categorySlug,
        source: sourcePackageId ?? 'typed',
        installedPackageId: installedPackageId,
        tags: const <String>[],
      );

  EntitySummary catalog({
    required String id,
    required String name,
    required String categorySlug,
    required String? sourcePackageId,
  }) =>
      (
        id: id,
        name: name,
        categorySlug: categorySlug,
        source: sourcePackageId ?? 'catalog',
        installedPackageId: null,
        tags: const <String>[],
      );

  return <EntitySummary>[
    ...generic,
    for (final r in spells)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'spell',
          sourcePackageId: r.sourcePackageId,
          installedPackageId: r.installedPackageId),
    for (final r in monsters)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'monster',
          sourcePackageId: r.sourcePackageId,
          installedPackageId: r.installedPackageId),
    for (final r in items)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'equipment',
          sourcePackageId: r.sourcePackageId,
          installedPackageId: r.installedPackageId),
    for (final r in feats)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'feat',
          sourcePackageId: r.sourcePackageId,
          installedPackageId: r.installedPackageId),
    for (final r in backgrounds)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'background',
          sourcePackageId: r.sourcePackageId,
          installedPackageId: r.installedPackageId),
    for (final r in homebrew)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: r.categorySlug,
          sourcePackageId: r.sourcePackageId,
          installedPackageId: null),
    for (final r in conditions)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'condition',
          sourcePackageId: r.sourcePackageId),
    for (final r in damageTypes)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'damage-type',
          sourcePackageId: r.sourcePackageId),
    for (final r in sizes)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'size',
          sourcePackageId: r.sourcePackageId),
    for (final r in spellSchools)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'spell-school',
          sourcePackageId: r.sourcePackageId),
    for (final r in rarities)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'rarity',
          sourcePackageId: r.sourcePackageId),
    for (final r in alignments)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'alignment',
          sourcePackageId: r.sourcePackageId),
    for (final r in weaponProperties)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'weapon-property',
          sourcePackageId: r.sourcePackageId),
    for (final r in weaponMasteries)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'weapon-mastery',
          sourcePackageId: r.sourcePackageId),
    for (final r in armorCategories)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'armor-category',
          sourcePackageId: r.sourcePackageId),
    for (final r in skills)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'skill',
          sourcePackageId: r.sourcePackageId),
    for (final r in creatureTypes)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'creature-type',
          sourcePackageId: r.sourcePackageId),
    for (final r in languages)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'language',
          sourcePackageId: r.sourcePackageId),
    for (final r in species)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'species',
          sourcePackageId: r.sourcePackageId),
    for (final r in subclasses)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'subclass',
          sourcePackageId: r.sourcePackageId),
    for (final r in classProgressions)
      catalog(
          id: r.id,
          name: r.name,
          categorySlug: 'class',
          sourcePackageId: r.sourcePackageId),
  ];
});

/// O(1) lookup by entity id. Covers the same typed + generic + catalog
/// merge as [combinedEntitySummaryProvider]. Used by MindMap / BattleMap
/// node renderers and by [EntityLinkChip] so cross-entity references
/// resolve to the referenced row's proper capitalized name.
final entitySummaryByIdProvider =
    Provider<Map<String, EntitySummary>>((ref) {
  final list = ref.watch(combinedEntitySummaryProvider);
  return {for (final s in list) s.id: s};
});
