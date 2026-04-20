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

/// Merged summary list for the left sidebar. Generic entities stream from
/// [entityProvider]; typed content streams from the per-campaign scoped
/// providers in `typed_content_provider.dart` so the sidebar only shows
/// content from packages the user has enabled in this world plus the
/// world's own user-created homebrew. Outside an active campaign the typed
/// streams are empty — the hub screens see only the generic blob.
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
  ];
});

/// O(1) lookup by entity id. Covers the same typed + generic merge as
/// [combinedEntitySummaryProvider]. Used by MindMap / BattleMap node
/// renderers that need an entity's name + category for display.
final entitySummaryByIdProvider =
    Provider<Map<String, EntitySummary>>((ref) {
  final list = ref.watch(combinedEntitySummaryProvider);
  return {for (final s in list) s.id: s};
});
