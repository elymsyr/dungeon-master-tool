import 'package:dungeon_master_tool/domain/entities/schema/rules/dnd5e_rule_catalog.dart';
import 'package:dungeon_master_tool/domain/entities/schema/rules/rule_definition.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Promotes the debug-only assert in `ruleCatalogProvider` to a real test,
/// and adds the reverse direction the assert never checked: the catalog must
/// not claim a rule is `applied` when the resolver has no case for it.
void main() {
  final catalog = dnd5eRuleCatalog();

  group('dnd5e rule catalog ↔ resolver drift', () {
    test('catalog keys and resolver-recognized kinds are the SAME set', () {
      // Exact equality both ways: a resolver kind missing from the catalog
      // is un-authorable; a catalog kind missing from the resolver hits the
      // "not applied" warning default even though the editor offered it.
      final catalogKinds = catalog.rules.keys.toSet();
      expect(
          CharacterResolver.knownEffectKinds.difference(catalogKinds), isEmpty,
          reason: 'Rule catalog is missing resolver-recognized kinds');
      expect(
          catalogKinds.difference(CharacterResolver.knownEffectKinds), isEmpty,
          reason: 'Catalog offers kinds the resolver would warn about');
    });

    test('catalog applied-status matches the sheet-applying kinds exactly',
        () {
      // resolverStatus drives editor badges and author expectations: an
      // `applied` rule the resolver silently ignores lies to the author; a
      // `deferred` rule that actually changes the sheet hides capability.
      final applied = catalog.rules.values
          .where((r) => r.resolverStatus == RuleResolverStatus.applied)
          .map((r) => r.id)
          .toSet();
      expect(
          applied.difference(CharacterResolver.sheetAppliedEffectKinds),
          isEmpty,
          reason: 'Catalog claims these are applied at resolve time, but the '
              'resolver has no real case body for them');
      expect(
          CharacterResolver.sheetAppliedEffectKinds.difference(applied),
          isEmpty,
          reason: 'Resolver applies these to the sheet, but the catalog marks '
              'them deferred');
    });

    test('sheet-applied kinds are a subset of recognized kinds', () {
      expect(
          CharacterResolver.sheetAppliedEffectKinds
              .difference(CharacterResolver.knownEffectKinds),
          isEmpty);
    });

    test('every legacy modifier alias targets a resolver-known kind', () {
      for (final entry
          in CharacterResolver.legacyModifierKindAliases.entries) {
        expect(CharacterResolver.knownEffectKinds, contains(entry.value),
            reason: 'alias ${entry.key} → ${entry.value} would still be inert');
      }
    });

    test('catalog map keys equal their RuleDefinition.id', () {
      for (final entry in catalog.rules.entries) {
        expect(entry.value.id, entry.key);
      }
    });

    test('targetKindsFor falls back to universal list for undeclared rules',
        () {
      // A rule with a declared list returns exactly that list.
      final declared = catalog.rules.values
          .firstWhere((r) => r.allowedTargetKinds.isNotEmpty);
      expect(catalog.targetKindsFor(declared.id), declared.allowedTargetKinds);
      // Unknown/absent kind falls back to the universal list.
      expect(catalog.targetKindsFor(null), catalog.targetKindFallback);
      expect(catalog.targetKindsFor('no_such_kind'), catalog.targetKindFallback);
      expect(catalog.targetKindFallback, isNotEmpty);
    });
  });
}
