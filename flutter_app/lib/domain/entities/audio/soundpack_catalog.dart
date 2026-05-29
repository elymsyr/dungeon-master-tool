/// Kind of soundpack — determines how it installs.
/// - [theme]: a self-contained theme folder (`theme.yaml` + audio) installed
///   into `{soundpadRoot}/{id}/` and auto-discovered by `loadAllThemes`.
/// - [library]: ambience/SFX entries merged into the global
///   `soundpad_library.yaml`; audio installed at its declared paths under the
///   soundpad root.
enum SoundpackKind { theme, library }

/// A single ambience/SFX entry contributed by a [SoundpackKind.library] pack.
/// Mirrors a row in `soundpad_library.yaml` — [file] is a path relative to the
/// soundpad root (e.g. `ambience/rain`), matching the bundled layout.
class SoundpackLibraryEntry {
  const SoundpackLibraryEntry({
    required this.category,
    required this.id,
    required this.name,
    required this.file,
  });

  /// `'ambience'` or `'sfx'`.
  final String category;
  final String id;
  final String name;
  final String file;

  factory SoundpackLibraryEntry.fromJson(Map<String, dynamic> json) {
    return SoundpackLibraryEntry(
      category: (json['category'] as String? ?? '').trim(),
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      file: (json['file'] as String? ?? '').trim(),
    );
  }

  bool get isValid =>
      (category == 'ambience' || category == 'sfx') &&
      id.isNotEmpty &&
      file.isNotEmpty;
}

/// A single downloadable soundpack from the curated GitHub catalog.
///
/// A [SoundpackKind.theme] pack maps onto the existing soundpad *theme folder*
/// concept; a [SoundpackKind.library] pack contributes ambience/SFX entries.
/// No user sharing — read-only catalog.
class SoundpackCatalogEntry {
  const SoundpackCatalogEntry({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.files,
    this.kind = SoundpackKind.theme,
    this.entries = const [],
    this.description,
    this.author,
    this.sizeBytes = 0,
  });

  /// Stable pack id; for theme packs also the install sub-directory + theme id.
  final String id;
  final String name;
  final String? description;
  final String? author;
  final SoundpackKind kind;

  /// Base URL each file path is appended to (must end with `/`).
  final String baseUrl;

  /// Relative file paths to download. For theme packs these land under
  /// `{soundpadRoot}/{id}/`; for library packs under `{soundpadRoot}/` directly
  /// (so the declared [entries] `file` paths resolve).
  final List<String> files;

  /// Library entries to merge into `soundpad_library.yaml`
  /// (only for [SoundpackKind.library]).
  final List<SoundpackLibraryEntry> entries;

  /// Total download size in bytes (best-effort, for display only).
  final int sizeBytes;

  factory SoundpackCatalogEntry.fromJson(Map<String, dynamic> json) {
    final rawBase = (json['baseUrl'] as String? ?? '').trim();
    final base = rawBase.endsWith('/') ? rawBase : '$rawBase/';
    final kind = (json['kind'] as String? ?? 'theme').trim() == 'library'
        ? SoundpackKind.library
        : SoundpackKind.theme;
    return SoundpackCatalogEntry(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String?)?.trim(),
      author: (json['author'] as String?)?.trim(),
      kind: kind,
      baseUrl: base,
      files: ((json['files'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      entries: ((json['entries'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SoundpackLibraryEntry.fromJson)
          .where((e) => e.isValid)
          .toList(growable: false),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isValid {
    if (id.isEmpty || baseUrl.length <= 1 || files.isEmpty) return false;
    if (kind == SoundpackKind.library) return entries.isNotEmpty;
    return true;
  }
}
