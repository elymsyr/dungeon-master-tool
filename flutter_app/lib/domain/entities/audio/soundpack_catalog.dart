/// A single downloadable soundpack from the curated GitHub catalog.
///
/// A soundpack maps onto the existing soundpad *theme folder* concept: its
/// files (a self-contained `theme.yaml` + audio) are downloaded into
/// `{soundpadRoot}/{id}/` and then auto-discovered by
/// `SoundpadLoader.loadAllThemes`. No user sharing — read-only catalog.
class SoundpackCatalogEntry {
  const SoundpackCatalogEntry({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.files,
    this.description,
    this.author,
    this.sizeBytes = 0,
  });

  /// Stable pack id; doubles as the install sub-directory and theme id.
  final String id;
  final String name;
  final String? description;
  final String? author;

  /// Base URL each file path is appended to (must end with `/`).
  final String baseUrl;

  /// Relative file paths within the pack (e.g. `theme.yaml`, `normal_base.ogg`).
  final List<String> files;

  /// Total download size in bytes (best-effort, for display only).
  final int sizeBytes;

  factory SoundpackCatalogEntry.fromJson(Map<String, dynamic> json) {
    final rawBase = (json['baseUrl'] as String? ?? '').trim();
    final base = rawBase.endsWith('/') ? rawBase : '$rawBase/';
    return SoundpackCatalogEntry(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String?)?.trim(),
      author: (json['author'] as String?)?.trim(),
      baseUrl: base,
      files: ((json['files'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isValid => id.isNotEmpty && baseUrl.length > 1 && files.isNotEmpty;
}
