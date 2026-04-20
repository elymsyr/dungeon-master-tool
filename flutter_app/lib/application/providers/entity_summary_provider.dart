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
  List<String> tags,
});

/// Merged summary list for the left sidebar. Generic entities stream from
/// [entityProvider]; typed content streams from the Tier 2 Drift tables.
/// Missing typed streams fall back to empty so the sidebar never blocks on
/// them. Doc 50 Batch 4.
final combinedEntitySummaryProvider =
    Provider<List<EntitySummary>>((ref) {
  final generic = ref.watch(entityProvider.select((m) => m.values
      .map((e) => (
            id: e.id,
            name: e.name,
            categorySlug: e.categorySlug,
            source: e.source,
            tags: e.tags,
          ))
      .toList()));

  final spells = ref
      .watch(allSpellsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final monsters = ref
      .watch(allMonstersProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final items = ref
      .watch(allItemsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final feats = ref
      .watch(allFeatsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final backgrounds = ref
      .watch(allBackgroundsProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);
  final homebrew = ref
      .watch(allHomebrewProvider)
      .maybeWhen(data: (rows) => rows, orElse: () => const []);

  EntitySummary summary({
    required String id,
    required String name,
    required String categorySlug,
    required String? sourcePackageId,
  }) =>
      (
        id: id,
        name: name,
        categorySlug: categorySlug,
        source: sourcePackageId ?? 'typed',
        tags: const <String>[],
      );

  return <EntitySummary>[
    ...generic,
    for (final r in spells)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'spell',
          sourcePackageId: r.sourcePackageId),
    for (final r in monsters)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'monster',
          sourcePackageId: r.sourcePackageId),
    for (final r in items)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'equipment',
          sourcePackageId: r.sourcePackageId),
    for (final r in feats)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'feat',
          sourcePackageId: r.sourcePackageId),
    for (final r in backgrounds)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: 'background',
          sourcePackageId: r.sourcePackageId),
    for (final r in homebrew)
      summary(
          id: r.id,
          name: r.name,
          categorySlug: r.categorySlug,
          sourcePackageId: r.sourcePackageId),
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
