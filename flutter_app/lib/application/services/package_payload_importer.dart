import '../../data/schema/auto_grant_inversion.dart';
import '../../data/schema/rule_effects_migration.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/repositories/package_repository.dart';

/// Imports an Open5e-style content payload (`package_name` + `metadata` +
/// `entities`) into the local package store, attaching the *live* built-in v2
/// schema so the pack always renders against the current category/field
/// definitions instead of a frozen copy.
///
/// Shared by [AssetsPackInstaller] (admin, bundled `assets/`) and the
/// marketplace official-catalog installer — they differ only in where the
/// payload comes from (rootBundle vs R2) and the [installedFrom] marker stamped
/// into `metadata.installed_from` (read back by `packageMetadataProvider` to
/// tag the source in the package list).
class PackagePayloadImporter {
  const PackagePayloadImporter(this._repo);
  final PackageRepository _repo;

  /// Saves [payload] as a local package and returns its name. [installedFrom]
  /// is recorded under `metadata.installed_from` ('assets' for bundled,
  /// 'official' for the R2 catalog); [extraMetadata] (e.g. `catalog_version`)
  /// is merged into the package metadata.
  Future<String> install(
    Map<String, dynamic> payload, {
    required String installedFrom,
    Map<String, dynamic>? extraMetadata,
  }) async {
    final rawEntities =
        (payload['entities'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    // Old-format payloads (bundled packs / R2 catalog builds that predate the
    // rule-system removal) carry `rule_effects` / `granted_modifiers` rows —
    // convert them to named grant fields at install time so the stored pack
    // is already in the current shape. No-op on current-format payloads.
    final entities = <String, dynamic>{
      for (final e in rawEntities.entries)
        e.key: _migrateEntity(e.value),
    };
    // Same vintage, but cross-entity: a feat that still declares which class
    // grants it has that edge moved onto the class card. Runs over the whole
    // payload because it writes to a different entity than it reads.
    invertAutoGrants(entities);
    final metadata = <String, dynamic>{
      ...?(payload['metadata'] as Map?)?.cast<String, dynamic>(),
      ...?extraMetadata,
      'installed_from': installedFrom,
    };

    // Prefer the human title (`metadata.title`, e.g. "Adventurer's Guide") as
    // the local package name; the payload's `package_name` is the machine slug
    // (`open5e-a5e-ag`). Fall back to the slug when no title is present.
    final title = (metadata['title'] as String?)?.trim();
    final packageName = (title != null && title.isNotEmpty)
        ? title
        : payload['package_name'] as String;

    final schema = generateBuiltinDnd5eV2Schema().schema;
    await _repo.save(packageName, {
      'entities': entities,
      'world_schema': schema.toJson(),
      'template_id': builtinDnd5eV2SchemaId,
      'template_original_hash': builtinDnd5eV2OriginalHash,
      'metadata': metadata,
    });
    return packageName;
  }

  /// Convert one payload entity's `attributes` through [migrateRuleEffects],
  /// leaving every other key untouched.
  static Object? _migrateEntity(Object? entity) {
    if (entity is! Map) return entity;
    final attrs = entity['attributes'];
    if (attrs is! Map) return entity;
    final migrated =
        migrateRuleEffects(Map<String, dynamic>.from(attrs));
    if (identical(migrated, attrs)) return entity;
    return {...entity, 'attributes': migrated};
  }
}
