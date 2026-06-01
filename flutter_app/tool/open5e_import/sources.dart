// Document registry — one entry per Open5e source document we turn into a
// package. The registry is *auto-discovered*: every `data/v2/<publisher>/<doc>/`
// directory holding a `Document.json` and at least one content type we map
// (Creature / Spell / MagicItem) becomes a [SourceDoc]. Title, publisher,
// license and game-system are read straight from `Document.json`, so adding a
// new Open5e source needs no code change.
import 'dart:convert';
import 'dart:io';

/// License → human attribution notice embedded in every package's metadata and
/// surfaced in the package About panel (mirrors `srdAttribution`).
const _ogl10aAttribution =
    'This work includes material taken from the System Reference Document 5.1 '
    '("SRD 5.1") and other Open Game Content distributed by Open5e '
    '(https://open5e.com), licensed under the Open Game License 1.0a. The '
    'original publisher of this material retains all rights; redistribution is '
    'permitted under the terms of the OGL 1.0a.';

const _ccBy4Attribution =
    'This work includes material distributed by Open5e (https://open5e.com) '
    'under the Creative Commons Attribution 4.0 International License '
    '(https://creativecommons.org/licenses/by/4.0/legalcode).';

const _cc0Attribution =
    'This work includes material distributed by Open5e (https://open5e.com) '
    'released under the Creative Commons Zero 1.0 Universal public-domain '
    'dedication (https://creativecommons.org/publicdomain/zero/1.0/).';

String attributionFor(String license) {
  switch (license) {
    case 'cc-by-40':
    case 'cc-by-4.0':
    case 'cc_by_4.0':
      return _ccBy4Attribution;
    case 'cc0':
      return _cc0Attribution;
    case 'ogl-10a':
    default:
      return _ogl10aAttribution;
  }
}

/// Publisher slug → display name (fallback: title-cased slug).
const _publisherNames = {
  'wizards-of-the-coast': 'Wizards of the Coast',
  'kobold-press': 'Kobold Press',
  'en-publishing': 'EN Publishing',
  'green-ronin': 'Green Ronin',
  'open5e': 'Open5e',
  'somanyrobots': 'SoMany Robots',
};

/// Content-type fixture files this tool knows how to map (parent rows; their
/// child files — CreatureAction, ClassFeature, … — are loaded opportunistically).
const _mappedFiles = [
  'Creature.json',
  'Spell.json',
  'MagicItem.json',
  'CharacterClass.json',
  'Species.json',
  'Background.json',
  'Feat.json',
];

/// A source document to package.
class SourceDoc {
  /// Open5e document slug (e.g. `tob`).
  final String slug;

  /// Human title shown in the marketplace / package hub.
  final String title;

  final String publisher;
  final String license; // ogl-10a / cc-by-40 / cc0
  final String gameSystem; // 5e-2014 / 5e-2024 / a5e

  /// Absolute path to the v2 document directory holding the fixture files.
  final String v2Dir;

  /// Whether this document duplicates built-in SRD content (excluded from the
  /// default marketplace publish step to avoid confusing duplicate listings).
  final bool isSrdOverlap;

  /// Fixture file base-names present in [v2Dir] that we map (subset of
  /// [_mappedFiles]).
  final Set<String> files;

  const SourceDoc({
    required this.slug,
    required this.title,
    required this.publisher,
    required this.license,
    required this.gameSystem,
    required this.v2Dir,
    required this.files,
    this.isSrdOverlap = false,
  });

  /// Unique local package name key.
  String get packageName => 'open5e-$slug';

  String get attribution => attributionFor(license);

  String v2File(String name) => '$v2Dir${Platform.pathSeparator}$name';

  bool get hasCreatures => files.contains('Creature.json');
  bool get hasSpells => files.contains('Spell.json');
  bool get hasMagicItems => files.contains('MagicItem.json');
  bool get hasClasses => files.contains('CharacterClass.json');
  bool get hasSpecies => files.contains('Species.json');
  bool get hasBackgrounds => files.contains('Background.json');
  bool get hasFeats => files.contains('Feat.json');
}

/// Discover every packageable document under `<dataRoot>/v2/**`. [dataRoot] is
/// `open5e-api-staging/data`.
List<SourceDoc> sourceDocs(String dataRoot) {
  final v2 = Directory('$dataRoot${Platform.pathSeparator}v2');
  if (!v2.existsSync()) return const [];
  final docs = <SourceDoc>[];

  for (final pubDir in v2.listSync().whereType<Directory>()) {
    for (final docDir in pubDir.listSync().whereType<Directory>()) {
      final docFile = File('${docDir.path}${Platform.pathSeparator}Document.json');
      if (!docFile.existsSync()) continue;

      final present = <String>{
        for (final f in _mappedFiles)
          if (File('${docDir.path}${Platform.pathSeparator}$f').existsSync()) f,
      };
      if (present.isEmpty) continue; // nothing we can map yet

      final meta = _readDocument(docFile);
      if (meta == null) continue;

      final publisherSlug = meta['publisher'] as String? ?? 'open5e';
      docs.add(SourceDoc(
        slug: meta['slug'] as String,
        title: meta['name'] as String,
        publisher: _publisherNames[publisherSlug] ?? _titleCaseSlug(publisherSlug),
        license: _preferredLicense(meta['licenses'] as List? ?? const []),
        gameSystem: meta['gamesystem'] as String? ?? '5e-2014',
        v2Dir: docDir.path,
        files: present,
        isSrdOverlap: publisherSlug == 'wizards-of-the-coast',
      ));
    }
  }

  docs.sort((a, b) => a.slug.compareTo(b.slug));
  return docs;
}

/// Read the single Django-fixture record in a `Document.json`.
Map<String, dynamic>? _readDocument(File f) {
  final raw = jsonDecode(f.readAsStringSync());
  if (raw is! List || raw.isEmpty) return null;
  final rec = raw.first;
  if (rec is! Map) return null;
  final fields = rec['fields'];
  if (fields is! Map) return null;
  return {
    'slug': rec['pk'].toString(),
    'name': fields['name'],
    'publisher': fields['publisher'],
    'licenses': fields['licenses'],
    'gamesystem': fields['gamesystem'],
  };
}

/// Pick the most permissive single license to attribute under. OGL covers all
/// SRD-derived Open Game Content; CC-BY for CC-only docs; CC0 last.
String _preferredLicense(List licenses) {
  final set = licenses.map((e) => e.toString()).toSet();
  if (set.contains('ogl-10a')) return 'ogl-10a';
  if (set.contains('cc-by-40')) return 'cc-by-40';
  if (set.contains('cc0')) return 'cc0';
  return set.isEmpty ? 'ogl-10a' : set.first;
}

String _titleCaseSlug(String s) => s
    .split(RegExp(r'[-_]'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');
