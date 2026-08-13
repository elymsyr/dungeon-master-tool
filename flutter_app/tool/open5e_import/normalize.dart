// Open5e enum string → app Tier-0 canonical name normalization.
//
// Single source of truth for the canonical names is the built-in v2 schema's
// Tier-0 seed rows (`buildTier0Lookups`). We index every seeded lookup name
// case-insensitively so Open5e's lowercase slugs ("neutral good", "humanoid",
// "fire") resolve to the exact strings the app will match at import time.
//
// Unknown / non-SRD values are never forced into a `_lookup` placeholder —
// they are recorded in the [UnmappedSink] and the caller decides whether to
// drop them or pass them through as free text.
//
// A second canon sits behind the first: Open5e's own Tier-0 vocabulary fixtures
// (`vocab.dart`, audit **B9**). Content fixtures reference Tier-0 rows by pk, so
// the vocabulary is what turns `thieves-cant` into `Thieves' Cant` — and what
// tells us `void-speech` is real third-party vocabulary rather than a typo, so
// it can be seeded into the pack instead of dropped.
import 'package:dungeon_master_tool/domain/entities/schema/builtin/lookups.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';

import 'vocab.dart';

/// Records every Open5e value that could not be mapped to a canonical Tier-0
/// name, grouped by `<slug>` with an example context, so `build_packs` can emit
/// `unmapped_report.json` for review.
class UnmappedSink {
  final Map<String, Map<String, int>> _bySlug = {};

  void add(String slug, String rawValue, {String? context}) {
    final key = context == null ? rawValue : '$rawValue  ($context)';
    (_bySlug[slug] ??= <String, int>{}).update(key, (n) => n + 1,
        ifAbsent: () => 1);
  }

  bool get isEmpty => _bySlug.isEmpty;

  Map<String, dynamic> toJson() => {
        for (final e in _bySlug.entries)
          e.key: (e.value.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .map((kv) => {'value': kv.key, 'count': kv.value})
              .toList(),
      };
}

/// Case-insensitive canonical-name index for every Tier-0 lookup slug.
class Normalizer {
  /// slug -> (lowercased name -> canonical name)
  final Map<String, Map<String, String>> _index;
  final UnmappedSink unmapped;

  /// Upstream Tier-0 vocabulary (audit **B9**). Consulted only when the
  /// built-in canon misses, so it can never change a value that already mapped.
  Vocabulary vocab = const Vocabulary.empty();

  /// Mints a Tier-0 row inside the pack currently being built and returns a
  /// `{_ref}` to it. Set per pack by `build_packs`; null → no seeding, the
  /// value goes to [unmapped] as before.
  Map<String, String>? Function(String slug, String name)? tier0Seeder;

  Normalizer._(this._index, this.unmapped);

  factory Normalizer() {
    final tier0 = buildTier0Lookups(schemaId: 'normalizer', now: 'now');
    final index = <String, Map<String, String>>{};
    for (final t in tier0) {
      final slug = t.category.slug;
      final m = index.putIfAbsent(slug, () => <String, String>{});
      for (final row in t.seedRows) {
        final name = row['name'];
        if (name is String) m[name.toLowerCase()] = name;
      }
    }
    return Normalizer._(index, UnmappedSink());
  }

  /// All canonical names seeded for [slug] (empty if the slug is unknown).
  /// Used by mappers that scan free text for any canonical value (e.g. picking
  /// out language names from a species' "Languages" trait prose).
  Iterable<String> namesFor(String slug) =>
      _index[slug]?.values ?? const <String>[];

  /// Canonical name for [raw] in [slug], or null if unknown. Tries the raw
  /// string and a title-cased variant.
  String? canonical(String slug, String raw) {
    final m = _index[slug];
    if (m == null) return null;
    final lc = raw.trim().toLowerCase();
    if (lc.isEmpty) return null;
    return m[lc] ?? m[titleCase(raw).toLowerCase()];
  }

  /// `{_lookup, name}` placeholder for [raw]; a `{_ref, name}` to a pack-local
  /// Tier-0 row when the value exists upstream but not in the built-in canon
  /// (audit **B9**); or null (and a sink entry) when nothing defines it.
  Map<String, String>? lookupRef(String slug, String raw, {String? context}) {
    final c = canonical(slug, raw);
    if (c != null) return lookup(slug, c);

    // B9: content fixtures point at Tier-0 rows by **fixture pk**, and the
    // vocabulary files are what turn a pk into a display name. Two outcomes:
    // the name is a built-in row after all (`thieves-cant` → `Thieves' Cant`,
    // which title-casing alone can never reach), or it is genuinely new
    // third-party vocabulary and gets seeded into this pack.
    final upstream = vocab.name(slug, raw);
    if (upstream != null) {
      final builtin = canonical(slug, upstream);
      if (builtin != null) return lookup(slug, builtin);
      final seeded = tier0Seeder?.call(slug, upstream);
      if (seeded != null) return seeded;
    }

    unmapped.add(slug, raw, context: context);
    return null;
  }

  /// Map a list of raw strings to lookup placeholders, skipping unknowns.
  List<Map<String, String>> lookupRefList(String slug, Iterable<String> raws,
      {String? context}) {
    final out = <Map<String, String>>[];
    for (final r in raws) {
      final ref = lookupRef(slug, r, context: context);
      if (ref != null) out.add(ref);
    }
    return out;
  }
}

/// Title case for a *proper name* — minor words stay lowercase unless they open
/// or close the name ("spare the dying" -> "Spare the Dying", "protection from
/// evil and good" -> "Protection from Evil and Good"). Prose-derived soft refs
/// have to match a target name byte-for-byte (the resolver is case-sensitive),
/// and no D&D spell capitalises its articles — plain [titleCase] emitted
/// `"Spare The Dying"`, which dangled (audit L3).
String titleCaseName(String s) {
  const minor = {
    'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'from', 'in', 'into',
    'nor', 'of', 'on', 'or', 'the', 'to', 'with',
  };
  final words = titleCase(s).split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      (i > 0 && i < words.length - 1 && minor.contains(words[i].toLowerCase()))
          ? words[i].toLowerCase()
          : words[i],
  ].join(' ');
}

/// "neutral good" -> "Neutral Good", "deep_speech" -> "Deep Speech".
String titleCase(String s) {
  final cleaned = s.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  return cleaned
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
