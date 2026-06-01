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
    final packageName = payload['package_name'] as String;
    final entities = (payload['entities'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final metadata = <String, dynamic>{
      ...?(payload['metadata'] as Map?)?.cast<String, dynamic>(),
      ...?extraMetadata,
      'installed_from': installedFrom,
    };

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
}
