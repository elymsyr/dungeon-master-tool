/// One media object a world entry ships on R2 (`catalog/world-media/...`),
/// alongside the relative path it must land on under the world's media root.
class CatalogMedia {
  final String rel;
  final String r2Key;
  final int sizeBytes;
  const CatalogMedia(
      {required this.rel, required this.r2Key, required this.sizeBytes});

  factory CatalogMedia.fromJson(Map<String, dynamic> j) => CatalogMedia(
        rel: j['rel'] as String? ?? '',
        r2Key: j['r2_key'] as String? ?? '',
        sizeBytes: (j['size_bytes'] as num?)?.toInt() ?? 0,
      );
}

/// A file an entry references but the catalog deliberately does NOT host —
/// today only the adventure PDF, which is `all-rights-reserved` and downloads
/// free from the publisher. Fetched from [url] straight into [rel]'s place.
class CatalogExternalFile {
  final String rel;
  final String url;
  const CatalogExternalFile({required this.rel, required this.url});

  factory CatalogExternalFile.fromJson(Map<String, dynamic> j) =>
      CatalogExternalFile(
        rel: j['rel'] as String? ?? '',
        url: j['url'] as String? ?? '',
      );
}

/// One entry from the first-party catalog manifest (`catalog/manifest.json` on
/// R2, or the bundled `assets/first_party/manifest.json` fallback). Describes an
/// installable official item — a `package` (one JSON file) or a `world`
/// (a directory: payload envelope + media objects).
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

  /// Banner artwork attribution from `banner-credits.yaml`, baked into the
  /// manifest by the catalog builder. Both null when the slug has no credit.
  final String? bannerCreditCreator;
  final String? bannerCreditLink;

  /// Slugs of other catalog entries this package links, emitted by
  /// `build_catalog.dart` from the pack's `metadata.links`. Installing this
  /// entry installs its requirements first (transitively) so a package that
  /// borrows another's content never lands half-resolved. Empty for every
  /// self-contained pack.
  final List<String> requires;

  /// Long-form store description. Worlds carry the blurb from their bundled
  /// `manifest.json`; packages have none.
  final String description;

  /// Credited author and the publisher's page for the work (world entries).
  final String author;
  final String sourceUrl;

  /// A world is a directory, not a single file: [bundledDir] is the asset dir
  /// (`assets/worlds/<dir>`) that backs the offline fallback, [media] names
  /// every R2 object to download, [externalFiles] the ones we don't host, and
  /// [coverImage] is the media-relative path of the card art. All empty for
  /// packages, which use [bundledAsset] + the `banners/<slug>.jpg` convention.
  final String bundledDir;
  final String coverImage;
  final List<CatalogMedia> media;
  final List<CatalogExternalFile> externalFiles;

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
    this.bannerCreditCreator,
    this.bannerCreditLink,
    this.requires = const [],
    this.description = '',
    this.author = '',
    this.sourceUrl = '',
    this.bundledDir = '',
    this.coverImage = '',
    this.media = const [],
    this.externalFiles = const [],
  });

  int get totalEntities => counts.values.fold(0, (a, b) => a + b);

  /// Everything the install actually downloads from R2: the payload plus every
  /// media object. Excludes [externalFiles], which come from the publisher.
  int get downloadBytes =>
      sizeBytes + media.fold(0, (a, m) => a + m.sizeBytes);

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
        bannerCreditCreator:
            (j['banner_credit'] as Map?)?['creator'] as String?,
        bannerCreditLink: (j['banner_credit'] as Map?)?['link'] as String?,
        requires: ((j['requires'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(growable: false),
        description: j['description'] as String? ?? '',
        author: j['author'] as String? ?? '',
        sourceUrl: j['source_url'] as String? ?? '',
        bundledDir: j['bundled_dir'] as String? ?? '',
        coverImage: j['cover_image'] as String? ?? '',
        media: ((j['media'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => CatalogMedia.fromJson(m.cast<String, dynamic>()))
            .toList(growable: false),
        externalFiles: ((j['external_files'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                CatalogExternalFile.fromJson(m.cast<String, dynamic>()))
            .toList(growable: false),
      );
}
