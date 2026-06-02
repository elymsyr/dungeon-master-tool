/// One entry from the first-party catalog manifest (`catalog/manifest.json` on
/// R2, or the bundled `assets/first_party/manifest.json` fallback). Describes an
/// installable official item; v1 ships only `package` entries.
///
/// Mirrors the shape emitted by `tool/catalog_publish/bin/build_catalog.dart`:
/// each entry carries both an [r2Path] (the gzipped object the publish CLI
/// uploads) and a [bundledAsset] (a Flutter asset used as the offline fallback),
/// so install works online (R2, updatable) and offline (bundled).
class CatalogEntry {
  final String itemType;
  final String slug;
  final String title;
  final String version;
  final String publisher;
  final String license;
  final String attribution;

  /// Ruleset/system the package targets (e.g. "5e-2014", "5e-2024", "a5e").
  /// Shown on the card as the template name — the official equivalent of a
  /// user listing's `world_schema.name`. Empty when the manifest omits it.
  final String gameSystem;

  final Map<String, int> counts;
  final String r2Path;
  final String bundledAsset;
  final int sizeBytes;

  const CatalogEntry({
    required this.itemType,
    required this.slug,
    required this.title,
    required this.version,
    required this.publisher,
    required this.license,
    required this.attribution,
    required this.gameSystem,
    required this.counts,
    required this.r2Path,
    required this.bundledAsset,
    required this.sizeBytes,
  });

  int get totalEntities => counts.values.fold(0, (a, b) => a + b);

  factory CatalogEntry.fromJson(Map<String, dynamic> j) => CatalogEntry(
        itemType: j['item_type'] as String? ?? 'package',
        slug: j['slug'] as String? ?? '',
        title: j['title'] as String? ?? j['slug'] as String? ?? '',
        version: j['version'] as String? ?? '1.0.0',
        publisher: j['publisher'] as String? ?? '',
        license: j['license'] as String? ?? '',
        attribution: j['attribution'] as String? ?? '',
        gameSystem: j['game_system'] as String? ?? '',
        counts: ((j['counts'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        r2Path: j['r2_path'] as String? ?? '',
        bundledAsset: j['bundled_asset'] as String? ?? '',
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
      );
}
