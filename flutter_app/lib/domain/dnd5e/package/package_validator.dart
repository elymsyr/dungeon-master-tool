import '../effect/custom_effect_registry.dart';
import 'dnd5e_package.dart';
import 'package_slug.dart';

sealed class ValidationIssue {
  final String message;
  const ValidationIssue(this.message);
}

class ValidationError extends ValidationIssue {
  const ValidationError(super.message);
}

class ValidationWarning extends ValidationIssue {
  const ValidationWarning(super.message);
}

/// Pre-import sanity checks. Structural-only; deep per-entity validation
/// (spell level 0..9, CR 0..30, etc.) moves here when typed codecs land in
/// Doc 15. For now: slug, format, duplicate local ids, runtime extensions.
class PackageValidator {
  final CustomEffectRegistry customEffectRegistry;

  PackageValidator(this.customEffectRegistry);

  List<ValidationIssue> validate(Dnd5ePackage pkg) {
    final issues = <ValidationIssue>[];

    if (pkg.formatVersion != '2') {
      issues.add(ValidationError(
          'Unsupported formatVersion "${pkg.formatVersion}" (expected 2)'));
    }
    if (pkg.gameSystemId != 'dnd5e') {
      issues.add(ValidationError(
          'Wrong gameSystemId "${pkg.gameSystemId}" (expected dnd5e)'));
    }
    if (!isValidPackageSlug(pkg.packageIdSlug)) {
      issues.add(ValidationError(
          'packageIdSlug "${pkg.packageIdSlug}" must match [a-z][a-z0-9_]{0,31}'));
    }
    if (pkg.name.isEmpty) {
      issues.add(const ValidationError('Package name must not be empty'));
    }
    if (pkg.version.isEmpty) {
      issues.add(const ValidationError('Package version must not be empty'));
    }

    for (final extId in pkg.requiredRuntimeExtensions) {
      if (!customEffectRegistry.contains(extId)) {
        issues.add(ValidationError(
            'Required runtime extension "$extId" is not registered'));
      }
    }

    _checkDupes('conditions', pkg.conditions.map((e) => e.id), issues);
    _checkDupes('damageTypes', pkg.damageTypes.map((e) => e.id), issues);
    _checkDupes('skills', pkg.skills.map((e) => e.id), issues);
    _checkDupes('sizes', pkg.sizes.map((e) => e.id), issues);
    _checkDupes('creatureTypes', pkg.creatureTypes.map((e) => e.id), issues);
    _checkDupes('alignments', pkg.alignments.map((e) => e.id), issues);
    _checkDupes('languages', pkg.languages.map((e) => e.id), issues);
    _checkDupes('spellSchools', pkg.spellSchools.map((e) => e.id), issues);
    _checkDupes(
        'weaponProperties', pkg.weaponProperties.map((e) => e.id), issues);
    _checkDupes(
        'weaponMasteries', pkg.weaponMasteries.map((e) => e.id), issues);
    _checkDupes(
        'armorCategories', pkg.armorCategories.map((e) => e.id), issues);
    _checkDupes('rarities', pkg.rarities.map((e) => e.id), issues);
    _checkDupes('spells', pkg.spells.map((e) => e.id), issues);
    _checkDupes('monsters', pkg.monsters.map((e) => e.id), issues);
    _checkDupes('items', pkg.items.map((e) => e.id), issues);
    _checkDupes('feats', pkg.feats.map((e) => e.id), issues);
    _checkDupes('backgrounds', pkg.backgrounds.map((e) => e.id), issues);
    _checkDupes('species', pkg.species.map((e) => e.id), issues);
    _checkDupes('subclasses', pkg.subclasses.map((e) => e.id), issues);
    _checkDupes(
        'classProgressions', pkg.classProgressions.map((e) => e.id), issues);

    for (final s in pkg.spells) {
      if (s.level < 0 || s.level > 9) {
        issues.add(
            ValidationError('spells[${s.id}] level ${s.level} out of 0..9'));
      }
    }

    return issues;
  }

  bool isFatal(List<ValidationIssue> issues) =>
      issues.any((i) => i is ValidationError);
}

void _checkDupes(
    String table, Iterable<String> ids, List<ValidationIssue> out) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      out.add(ValidationError('$table contains duplicate id "$id"'));
    }
  }
}
