// Upstream Tier-0 vocabulary read (audit phase **B9**).
//
// `normalize.dart`'s canon is the built-in v2 schema's Tier-0 seed rows, and it
// matches Open5e's raw values against them by lowercasing / title-casing the
// string the content fixtures carry. That string is a **fixture pk**
// (`thieves-cant`, `void-speech`, `titanic`), not a display name — so any pk
// whose canonical name is not a mechanical title-casing of itself misses, and
// any value the built-in Tier-0 simply does not have misses too. Both land in
// `unmapped_report.json` and the field is dropped.
//
// Open5e ships the display names as fixtures: eleven vocabulary files in the
// `open5e/core` document plus per-document extensions (`a5e-mm/Size.json`,
// `tob/Language.json`, `a5e-ag/Condition.json`, …). This file reads **every**
// vocabulary file under `data/v2/<publisher>/<doc>/`, globally — a Tome of
// Beasts 2 monster speaks `void-speech`, but the fixture defining it lives in
// `kobold-press/tob/`, so a per-document read would not see it.
//
// Note the shape: `open5e/core` is a document `sourceDocs` **correctly refuses
// to turn into a package** (it holds no content). This is a vocabulary read, not
// a new `_mappedFiles` entry.
//
// Two outcomes per aliased value:
//
//   * the upstream name IS a built-in Tier-0 row (`thieves-cant` →
//     `Thieves' Cant`) → an ordinary `{_lookup}` placeholder, nothing new ships;
//   * it is genuinely new (`void-speech`, `titanic`) → [seedTier0Row] mints a
//     Tier-0 **entity in the pack** and the caller gets a build-gated
//     `{_ref}`. Per the audit's §2, third-party vocabulary is seeded in the
//     package that needs it and never in the built-in schema.
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';

import 'loaders.dart';
import 'normalize.dart' show titleCase;
import 'refgraph.dart';

/// Upstream vocabulary file → the Tier-0 category slug it defines.
///
/// `Environment.json` (19 core rows + `tob_badlands`) is deliberately absent:
/// there is no `environment` slug in `tier0Slugs`, so it has no home to map to.
/// `ItemCategory.json` is absent for the reason A1 recorded — it is an item
/// taxonomy, and nothing currently fails to map for `magic-item-category`.
const vocabFileSlugs = <String, String>{
  'Ability.json': 'ability',
  'Alignment.json': 'alignment',
  'Condition.json': 'condition',
  'CreatureType.json': 'creature-type',
  'DamageType.json': 'damage-type',
  'ItemRarity.json': 'rarity',
  'Language.json': 'language',
  'Size.json': 'size',
  'Skill.json': 'skill',
  'SpellSchool.json': 'spell-school',
};

/// The upstream display names for every Tier-0 slug, indexed by every spelling
/// a content fixture might use to point at them.
class Vocabulary {
  /// slug -> (lowercased alias -> upstream display name)
  final Map<String, Map<String, String>> _alias;

  /// slug -> (upstream display name -> the fixture row, for its extra fields)
  final Map<String, Map<String, Fixture>> _rows;

  const Vocabulary._(this._alias, this._rows);

  const Vocabulary.empty()
      : _alias = const {},
        _rows = const {};

  /// Reads every vocabulary file under every `data/v2/<publisher>/<doc>/`.
  ///
  /// Later documents never overwrite an earlier definition of the same alias —
  /// `core` is enumerated first so its rows win, and a third-party document can
  /// only ever *add* vocabulary.
  factory Vocabulary.load(String dataRoot) {
    final alias = <String, Map<String, String>>{};
    final rows = <String, Map<String, Fixture>>{};
    final v2 = Directory('$dataRoot/v2');
    if (!v2.existsSync()) return const Vocabulary.empty();

    final docDirs = <String>[];
    for (final pub in v2.listSync().whereType<Directory>()) {
      for (final doc in pub.listSync().whereType<Directory>()) {
        docDirs.add(doc.path);
      }
    }
    // `open5e/core` holds the canon; read it before the extensions.
    docDirs.sort((a, b) {
      final ac = a.endsWith('/core') ? 0 : 1;
      final bc = b.endsWith('/core') ? 0 : 1;
      return ac != bc ? ac - bc : a.compareTo(b);
    });

    for (final dir in docDirs) {
      for (final entry in vocabFileSlugs.entries) {
        for (final f in loadFixtures('$dir/${entry.key}')) {
          final name = (f['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue;
          final slug = entry.value;
          final a = alias.putIfAbsent(slug, () => <String, String>{});
          for (final key in _aliasesFor(f['_pk']?.toString() ?? '', name)) {
            a.putIfAbsent(key, () => name);
          }
          rows.putIfAbsent(slug, () => <String, Fixture>{})
              .putIfAbsent(name, () => f);
        }
      }
    }
    return Vocabulary._(alias, rows);
  }

  /// Every spelling of one row a content fixture is known to use: the raw pk,
  /// the pk with its `<doc>_` prefix stripped (`a5e-ag_bloodied` → `bloodied`),
  /// and the display name itself.
  static Iterable<String> _aliasesFor(String pk, String name) {
    final out = <String>{};
    void put(String s) {
      final t = s.trim().toLowerCase();
      if (t.isNotEmpty) out.add(t);
    }

    put(pk);
    final us = pk.indexOf('_');
    if (us > 0) put(pk.substring(us + 1));
    put(name);
    return out;
  }

  /// Upstream display name for [raw] in [slug], or null when no fixture defines
  /// it. Independent of what the built-in Tier-0 happens to contain.
  String? name(String slug, String raw) =>
      _alias[slug]?[raw.trim().toLowerCase()];

  /// The fixture row behind an upstream display name (for its extra fields).
  Fixture? row(String slug, String name) => _rows[slug]?[name];

  int get slugCount => _alias.length;
  int get rowCount => _rows.values.fold(0, (n, m) => n + m.length);
}

/// Mints a Tier-0 lookup **entity inside [pack]** for an upstream vocabulary
/// row the built-in schema does not have, and returns a build-gated
/// `{_ref, name}` pointing at it. Idempotent per (slug, name).
///
/// The extra fields are filled only from what the fixture actually states, and
/// only for `language` and `size` — the two slugs whose upstream columns line up
/// with a built-in Tier-0 field *and* whose types are scalar. (`skill.ability`
/// looks mappable but the built-in field is `ability_ref`, a relation, so it is
/// deliberately left out rather than guessed.) Everything else ships with name +
/// summary, which is enough for the relation to resolve and render.
Map<String, String> seedTier0Row(
  PackBuilder pack,
  Vocabulary vocab, {
  required String slug,
  required String name,
  required String source,
}) {
  if (!pack.has(slug, name)) {
    final f = vocab.row(slug, name) ?? const <String, dynamic>{};
    final desc = (f['desc'] as String?)?.trim() ?? '';
    final attrs = <String, dynamic>{
      if (desc.isNotEmpty) 'summary': desc,
      ..._tier0Extras(slug, f),
    };
    pack.add(packEntity(
      slug: slug,
      name: name,
      description: desc,
      source: source,
      attributes: attrs,
    ));
  }
  return ref(slug, name);
}

Map<String, dynamic> _tier0Extras(String slug, Fixture f) {
  switch (slug) {
    case 'language':
      return <String, dynamic>{
        // Open5e's only tier signal. `is_exotic` maps to the built-in
        // Standard/Rare enum; `is_secret` (Druidic, Thieves' Cant) is also Rare.
        'tier': (f['is_exotic'] == true || f['is_secret'] == true)
            ? 'Rare'
            : 'Standard',
        if ((f['script_language'] as String?)?.trim().isNotEmpty ?? false)
          'script': titleCase(f['script_language'] as String),
      };
    case 'size':
      final space = f['space_diameter'];
      final hd = _dieSides(f['suggested_hit_dice'] as String?);
      return <String, dynamic>{
        if (space is num) 'space_ft': space.toDouble(),
        'hit_die_size': ?hd,
        // Not upstream: extrapolated from the built-in ladder, which doubles
        // every step (Large 2, Huge 4, Gargantuan 8). Recorded in the audit as
        // the one derived value B9 writes.
        if (space is num && space > 20) 'carrying_multiplier': 16.0,
      };
    default:
      return const <String, dynamic>{};
  }
}

/// `'d20'` → 20. Null for anything that is not a plain die.
int? _dieSides(String? raw) {
  final m = RegExp(r'^\s*d(\d+)\s*$', caseSensitive: false).firstMatch(raw ?? '');
  return m == null ? null : int.tryParse(m.group(1)!);
}
