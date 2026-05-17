import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'visible_entity_provider.dart';

/// Compact row tuple consumed by the sidebar list. Same shape as the inline
/// `.select(...)` projection that used to live in `entity_sidebar.dart`.
typedef EntitySummary = ({
  String id,
  String name,
  String categorySlug,
  String source,
  List<String> tags,
  String? packageId,
  bool linked,
});

/// Memoized summary list. Riverpod identity-compares the provider output,
/// so as long as `visibleEntityProvider`'s map reference is stable the
/// sidebar `ref.watch` returns the same list — no 7 K-row reallocation
/// per keyboard `viewInsets` change.
///
/// `.select((map) => map.values.map(...).toList())` previously allocated a
/// fresh `List` on every read (List has no value equality), so Riverpod
/// always saw a "changed" result and forced a rebuild.
final entitySummaryListProvider = Provider<List<EntitySummary>>(
  // `visibleEntityProvider` is scope-overridden inside PackageScreen
  // (transitively via the `entityProvider` override). Riverpod requires
  // every dependent provider to declare its scoped deps so it can re-
  // create them in the overriding scope — without this, the assertion at
  // `container.dart:452` fires when the sidebar mounts inside the
  // ProviderScope.
  dependencies: [visibleEntityProvider],
  (ref) {
    final map = ref.watch(visibleEntityProvider);
    return [
      for (final e in map.values)
        (
          id: e.id,
          name: e.name,
          categorySlug: e.categorySlug,
          source: e.source,
          tags: e.tags,
          packageId: e.packageId,
          linked: e.linked,
        ),
    ];
  },
);
