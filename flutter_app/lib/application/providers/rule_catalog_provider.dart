import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/schema/rules/dnd5e_rule_catalog.dart';
import '../../domain/entities/schema/rules/rule_definition.dart';
import '../../domain/services/character_resolver.dart';
import 'entity_provider.dart';

/// Built once — the dnd5e catalog is pure, code-declared data with no I/O.
final _dnd5eCatalog = _buildDnd5eCatalog();

RuleCatalog _buildDnd5eCatalog() {
  final catalog = dnd5eRuleCatalog();
  // Debug-only drift guard: every kind the resolver actually applies must be
  // declared in the catalog. Stripped in release builds.
  assert(() {
    final missing =
        CharacterResolver.knownEffectKinds.difference(catalog.rules.keys.toSet());
    if (missing.isNotEmpty) {
      throw StateError(
        'Rule catalog is missing resolver-handled kinds: $missing',
      );
    }
    return true;
  }());
  return catalog;
}

/// The Rule Catalog for the active template, keyed off `baseSystem`.
///
/// The catalog is NOT persisted into the schema (never hashed by
/// [computeWorldSchemaContentHash]); it is served here so the effect editor,
/// validator and any rule browser read one source of truth. Today only the
/// D&D 5e catalog exists; the switch is the extension point for future systems.
final ruleCatalogProvider = Provider<RuleCatalog>((ref) {
  final baseSystem = ref.watch(
    worldSchemaProvider.select((s) => s.baseSystem),
  );
  switch (baseSystem) {
    case 'dnd5e':
    default:
      return _dnd5eCatalog;
  }
});
