import '../../domain/entities/schema/template_compatibility.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_diff.dart';
import '../../domain/entities/schema/world_schema_hash.dart';

/// İki template arasındaki uyumluluğu kontrol eder.
///
/// Mevcut hash ve diff fonksiyonlarını birleştirerek üç seviyeli sonuç döner:
/// - perfect: birebir aynı template
/// - compatible: farklılıklar var ama import edilebilir
/// - incompatible: hiç ortak kategori yok
class TemplateCompatibilityService {
  TemplateCompatibility check(
    WorldSchema packageSchema,
    WorldSchema worldSchema,
  ) {
    final pkgHash = computeWorldSchemaContentHash(packageSchema);
    final worldHash = computeWorldSchemaContentHash(worldSchema);

    // Perfect match — aynı lineage ve aynı content
    if (packageSchema.originalHash == worldSchema.originalHash &&
        pkgHash == worldHash) {
      return const TemplateCompatibility(level: CompatibilityLevel.perfect);
    }

    // Diff hesapla
    final diff = computeWorldSchemaDiff(packageSchema, worldSchema);

    // Kategori analizi
    final pkgCatNames =
        packageSchema.categories.map((c) => c.name).toSet();
    final worldCatNames =
        worldSchema.categories.map((c) => c.name).toSet();
    final shared = pkgCatNames.intersection(worldCatNames);

    // Field analizi — yalnızca ortak kategoriler için
    final addedFields = <String>[];
    final removedFields = <String>[];
    final pkgCatByName = {
      for (final c in packageSchema.categories) c.name: c,
    };
    final worldCatByName = {
      for (final c in worldSchema.categories) c.name: c,
    };

    for (final catName in shared) {
      final pkgCat = pkgCatByName[catName]!;
      final worldCat = worldCatByName[catName]!;
      final pkgFields = {for (final f in pkgCat.fields) f.label};
      final worldFields = {for (final f in worldCat.fields) f.label};

      for (final f in worldFields.difference(pkgFields)) {
        addedFields.add('$catName: $f');
      }
      for (final f in pkgFields.difference(worldFields)) {
        removedFields.add('$catName: $f');
      }
    }

    // Same lineage (originalHash matches) — compatible even if content differs.
    // The field differences are shown as warnings but import is allowed.
    final sameLineage =
        packageSchema.originalHash != null &&
        packageSchema.originalHash == worldSchema.originalHash;

    if (sameLineage) {
      return TemplateCompatibility(
        level: CompatibilityLevel.compatible,
        warnings: diff,
        addedFields: addedFields,
        removedFields: removedFields,
        addedCategories: worldCatNames.difference(pkgCatNames).toList(),
        removedCategories: pkgCatNames.difference(worldCatNames).toList(),
      );
    }

    // Different lineage — check if there are any shared categories.
    if (shared.isEmpty) {
      return TemplateCompatibility(
        level: CompatibilityLevel.incompatible,
        warnings: diff,
        addedFields: addedFields,
        removedFields: removedFields,
        addedCategories: worldCatNames.difference(pkgCatNames).toList(),
        removedCategories: pkgCatNames.difference(worldCatNames).toList(),
      );
    }

    return TemplateCompatibility(
      level: CompatibilityLevel.compatible,
      warnings: diff,
      addedFields: addedFields,
      removedFields: removedFields,
      addedCategories: worldCatNames.difference(pkgCatNames).toList(),
      removedCategories: pkgCatNames.difference(worldCatNames).toList(),
    );
  }
}
