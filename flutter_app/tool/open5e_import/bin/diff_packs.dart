// Pack asset ⟷ pack asset differ (offline audit tool).
//
//   dart run tool/open5e_import/bin/diff_packs.dart --new <dir>
//                                                   [--old assets/open5e_packs]
//                                                   [--only trait,monster,...]
//                                                   [--examples 1]
//                                                   [--markdown]
//
// Third sibling of `audit_packs.dart` (are the fields filled?) and
// `dupe_census.dart` (should this entity exist?). This one asks: **what did a
// rebuild change?**
//
// `build_packs.dart` writes 25 MB of minified single-line JSON, so `diff` on the
// assets is unreadable — one changed field per pack shows up as one 1.3 MB line.
// This tool answers the question `docs/open5e_content_audit.md` §4 A0 actually
// asks ("every diff hunk is explained, not no diff") by aggregating differences
// into change *classes*: `(category, field key, kind) → count` plus one worked
// example each. A rebuild that moved 30 k values usually has a handful of
// classes, and each class is one decision.
//
// Entity identity is the uuidv5 id, which is stable across rebuilds (derived
// from package + slug + name in `refgraph.dart`), so a renamed entity reads as
// one removal + one addition and a re-mapped field reads as a change.
//
// Five reports:
//
//   1. pack set          — packs only in old / only in new (a new upstream
//                          document, or one that failed its ref gate, shows here)
//   2. metadata          — per-pack `metadata` key diffs. `source_data_rev` is
//                          expected to differ whenever `--rev` changed
//   3. counts            — per-pack, per-category entity counts old vs new
//   4. entity churn      — added / removed / changed ids per category
//   5. change classes    — the aggregation described above, over `attributes`
//                          keys *and* the top-level wire keys (name, tags, …)
//
// Plus a **spell class-tag coverage** table: `spell.tags` carries the class
// linkage recovered from the v1 fixtures, and it is the only thing making
// bundled spells visible in character creation today (see `build_packs.dart`
// `_v1ClassIndex` and the audit doc §2.3.1). A rebuild that silently loses it
// regresses chargen while every other number improves, so it gets its own line.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Top-level entity wire keys worth diffing. `attributes` is walked key by key
/// instead (see [_diffEntity]); the rest are scalars or short lists.
const _topLevelKeys = [
  'name',
  'type',
  'source',
  'description',
  'tags',
  'image_path',
  'images',
  'dm_notes',
  'pdfs',
  'location_id',
];

/// The 13 SRD class names a `spell.tags` entry has to match for the chargen
/// spell pickers to see it (`spells_step.dart` matches the class name as a tag).
const _classNames = {
  'Artificer',
  'Barbarian',
  'Bard',
  'Cleric',
  'Druid',
  'Fighter',
  'Monk',
  'Paladin',
  'Ranger',
  'Rogue',
  'Sorcerer',
  'Warlock',
  'Wizard',
};

void main(List<String> args) {
  final opts = _parseArgs(args);
  final oldDir = opts['old'] ?? 'assets/open5e_packs';
  final newDir = opts['new'];
  final markdown = args.contains('--markdown');
  final only =
      (opts['only'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
  final examples = int.tryParse(opts['examples'] ?? '1') ?? 1;

  if (newDir == null) {
    stderr.writeln('ERROR: --new <dir> is required '
        '(the rebuilt pack directory to compare against --old).');
    exit(2);
  }
  for (final d in [oldDir, newDir]) {
    if (!Directory(d).existsSync()) {
      stderr.writeln('ERROR: pack directory not found: $d');
      exit(2);
    }
  }

  final oldPacks = _loadPacks(oldDir);
  final newPacks = _loadPacks(newDir);
  final diff = _Diff(oldPacks, newPacks, only, examples);

  if (markdown) {
    diff.printMarkdown(oldDir, newDir);
  } else {
    diff.printPlain(oldDir, newDir);
  }
}

// ── Loading ───────────────────────────────────────────────────────────────

class _Pack {
  _Pack(this.name, this.metadata, this.byId);

  final String name;
  final Map<String, dynamic> metadata;

  /// entity id → raw wire map.
  final Map<String, Map<String, dynamic>> byId;

  Map<String, int> countsBySlug() {
    final out = <String, int>{};
    for (final e in byId.values) {
      final slug = e['type'] as String? ?? '?';
      out[slug] = (out[slug] ?? 0) + 1;
    }
    return out;
  }
}

Map<String, _Pack> _loadPacks(String dir) {
  final out = <String, _Pack>{};
  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final name = raw['package_name'] as String? ??
        f.uri.pathSegments.last.replaceAll('.pkg.json', '');
    final entities = (raw['entities'] as Map?) ?? const {};
    final byId = <String, Map<String, dynamic>>{};
    entities.forEach((id, value) {
      if (value is Map) byId['$id'] = value.cast<String, dynamic>();
    });
    out[name] = _Pack(
      name,
      ((raw['metadata'] as Map?) ?? const {}).cast<String, dynamic>(),
      byId,
    );
  }
  return out;
}

// ── Diff ──────────────────────────────────────────────────────────────────

/// One aggregated change class: a `(category, field, kind)` triple.
class _ChangeClass {
  int count = 0;
  final examples = <String>[];

  void record(String example, int limit) {
    count++;
    if (examples.length < limit) examples.add(example);
  }
}

enum _Kind { added, removed, changed }

class _Diff {
  _Diff(this.oldPacks, this.newPacks, this.only, this.examples) {
    onlyInOld = oldPacks.keys.where((k) => !newPacks.containsKey(k)).toList();
    onlyInNew = newPacks.keys.where((k) => !oldPacks.containsKey(k)).toList();

    for (final name in oldPacks.keys.where(newPacks.containsKey)) {
      final o = oldPacks[name]!, n = newPacks[name]!;
      _diffMetadata(name, o, n);
      _diffCounts(name, o, n);
      _diffEntities(name, o, n);
      _spellTags(name, o, n);
    }
  }

  final Map<String, _Pack> oldPacks;
  final Map<String, _Pack> newPacks;
  final Set<String> only;
  final int examples;

  late final List<String> onlyInOld;
  late final List<String> onlyInNew;

  /// pack → metadata key → `old → new`.
  final metaDiffs = <String, Map<String, String>>{};

  /// pack → slug → `(old, new)`, only where they differ.
  final countDiffs = <String, Map<String, (int, int)>>{};

  /// slug → kind → count (entity-level churn).
  final churn = <String, Map<_Kind, int>>{};

  /// `slug|field|kind` → aggregated class.
  final changeClasses = <String, _ChangeClass>{};

  /// pack → `(taggedOld, totalOld, taggedNew, totalNew, classTaggedOld,
  /// classTaggedNew)` for spells.
  final spellTags = <String, List<int>>{};

  bool _wanted(String slug) => only.isEmpty || only.contains(slug);

  void _diffMetadata(String name, _Pack o, _Pack n) {
    final keys = {...o.metadata.keys, ...n.metadata.keys};
    for (final k in keys) {
      final a = o.metadata[k], b = n.metadata[k];
      if (_enc(a) == _enc(b)) continue;
      (metaDiffs[name] ??= {})[k] = '${_short(a)} → ${_short(b)}';
    }
  }

  void _diffCounts(String name, _Pack o, _Pack n) {
    final co = o.countsBySlug(), cn = n.countsBySlug();
    for (final slug in {...co.keys, ...cn.keys}.where(_wanted)) {
      final a = co[slug] ?? 0, b = cn[slug] ?? 0;
      if (a != b) (countDiffs[name] ??= {})[slug] = (a, b);
    }
  }

  void _diffEntities(String name, _Pack o, _Pack n) {
    for (final id in o.byId.keys) {
      final oe = o.byId[id]!;
      final slug = oe['type'] as String? ?? '?';
      if (!_wanted(slug)) continue;
      final ne = n.byId[id];
      if (ne == null) {
        _bump(slug, _Kind.removed);
        continue;
      }
      if (_diffEntity(name, slug, oe, ne)) _bump(slug, _Kind.changed);
    }
    for (final id in n.byId.keys) {
      if (o.byId.containsKey(id)) continue;
      final slug = n.byId[id]!['type'] as String? ?? '?';
      if (_wanted(slug)) _bump(slug, _Kind.added);
    }
  }

  /// Records every differing field of one entity. Returns true if anything did.
  bool _diffEntity(
    String pack,
    String slug,
    Map<String, dynamic> o,
    Map<String, dynamic> n,
  ) {
    var dirty = false;
    final label = '$pack/${o['name'] ?? n['name']}';

    for (final k in _topLevelKeys) {
      if (_record(slug, k, o[k], n[k], label)) dirty = true;
    }

    final oa = ((o['attributes'] as Map?) ?? const {}).cast<String, dynamic>();
    final na = ((n['attributes'] as Map?) ?? const {}).cast<String, dynamic>();
    for (final k in {...oa.keys, ...na.keys}) {
      if (_record(slug, 'attributes.$k', oa[k], na[k], label)) dirty = true;
    }
    return dirty;
  }

  bool _record(
    String slug,
    String field,
    Object? a,
    Object? b,
    String label,
  ) {
    final ea = _enc(a), eb = _enc(b);
    if (ea == eb) return false;
    final kind = a == null
        ? _Kind.added
        : b == null
            ? _Kind.removed
            : _Kind.changed;
    final cls = changeClasses['$slug|$field|${kind.name}'] ??= _ChangeClass();
    cls.record('$label: ${_short(a)} → ${_short(b)}', examples);
    return true;
  }

  void _bump(String slug, _Kind kind) {
    final m = churn[slug] ??= {};
    m[kind] = (m[kind] ?? 0) + 1;
  }

  void _spellTags(String name, _Pack o, _Pack n) {
    final counted = <int>[0, 0, 0, 0, 0, 0];
    var any = false;
    for (final (i, pack) in [o, n].indexed) {
      for (final e in pack.byId.values) {
        if (e['type'] != 'spell') continue;
        any = true;
        counted[1 + i * 2] += 1; // total
        final tags = (e['tags'] as List?)?.whereType<String>() ?? const [];
        if (tags.isNotEmpty) counted[0 + i * 2] += 1; // any tag
        if (tags.any(_classNames.contains)) counted[4 + i] += 1; // class tag
      }
    }
    if (any) spellTags[name] = counted;
  }

  bool get isClean =>
      onlyInOld.isEmpty &&
      onlyInNew.isEmpty &&
      metaDiffs.isEmpty &&
      countDiffs.isEmpty &&
      churn.isEmpty &&
      changeClasses.isEmpty;

  // ── Output ──────────────────────────────────────────────────────────────

  void printPlain(String oldDir, String newDir) {
    print('Pack diff — old=$oldDir  new=$newDir');
    print('  ${oldPacks.length} old pack(s), ${newPacks.length} new pack(s)');
    if (isClean) {
      print('\nIdentical: no pack, metadata, count or field differences.');
      _printSpellTags(false);
      return;
    }

    if (onlyInOld.isNotEmpty || onlyInNew.isNotEmpty) {
      print('\n1. Pack set');
      for (final p in onlyInOld) {
        print('  – only in old: $p');
      }
      for (final p in onlyInNew) {
        print('  + only in new: $p');
      }
    }

    if (metaDiffs.isNotEmpty) {
      print('\n2. Metadata');
      for (final e in metaDiffs.entries) {
        print('  ${e.key}');
        for (final k in e.value.entries) {
          print('    $k');
        }
      }
    }

    if (countDiffs.isNotEmpty) {
      print('\n3. Entity counts (old → new)');
      for (final e in countDiffs.entries) {
        final parts = e.value.entries
            .map((c) => '${c.key} ${c.value.$1}→${c.value.$2}')
            .join(', ');
        print('  ${e.key}: $parts');
      }
    } else {
      print('\n3. Entity counts: identical in every shared pack.');
    }

    print('\n4. Entity churn by category (added / removed / changed)');
    if (churn.isEmpty) {
      print('  none');
    } else {
      for (final e in _sortedChurn()) {
        final m = churn[e]!;
        print('  ${e.padRight(18)} '
            '+${m[_Kind.added] ?? 0}  '
            '-${m[_Kind.removed] ?? 0}  '
            '~${m[_Kind.changed] ?? 0}');
      }
    }

    print('\n5. Change classes (category | field | kind → count)');
    if (changeClasses.isEmpty) {
      print('  none');
    } else {
      for (final key in _sortedClasses()) {
        final cls = changeClasses[key]!;
        final parts = key.split('|');
        print('  ${cls.count.toString().padLeft(6)}  '
            '${parts[0]} · ${parts[1]} · ${parts[2]}');
        for (final ex in cls.examples) {
          print('          e.g. $ex');
        }
      }
      print('  ${changeClasses.length} class(es), '
          '${_sum(changeClasses.values.map((c) => c.count))} value(s) changed');
    }

    _printSpellTags(false);
  }

  void printMarkdown(String oldDir, String newDir) {
    print('### Pack diff — `$oldDir` → `$newDir`\n');
    if (isClean) {
      print('No pack, metadata, count or field differences.\n');
      _printSpellTags(true);
      return;
    }
    if (onlyInOld.isNotEmpty || onlyInNew.isNotEmpty) {
      print('**Pack set:** '
          'only in old: ${onlyInOld.isEmpty ? "—" : onlyInOld.join(", ")}; '
          'only in new: ${onlyInNew.isEmpty ? "—" : onlyInNew.join(", ")}\n');
    }
    if (metaDiffs.isNotEmpty) {
      print('| Pack | Metadata key | Change |');
      print('|---|---|---|');
      for (final e in metaDiffs.entries) {
        for (final k in e.value.entries) {
          print('| `${e.key}` | `${k.key}` | ${k.value} |');
        }
      }
      print('');
    }
    if (countDiffs.isNotEmpty) {
      print('| Pack | Category | Old | New |');
      print('|---|---|--:|--:|');
      for (final e in countDiffs.entries) {
        for (final c in e.value.entries) {
          print('| `${e.key}` | `${c.key}` | ${c.value.$1} | ${c.value.$2} |');
        }
      }
      print('');
    }
    if (churn.isNotEmpty) {
      print('| Category | Added | Removed | Changed |');
      print('|---|--:|--:|--:|');
      for (final e in _sortedChurn()) {
        final m = churn[e]!;
        print('| `$e` | ${m[_Kind.added] ?? 0} | '
            '${m[_Kind.removed] ?? 0} | ${m[_Kind.changed] ?? 0} |');
      }
      print('');
    }
    if (changeClasses.isNotEmpty) {
      print('| Category | Field | Kind | Count | Example |');
      print('|---|---|---|--:|---|');
      for (final key in _sortedClasses()) {
        final cls = changeClasses[key]!;
        final parts = key.split('|');
        final ex = cls.examples.isEmpty ? '' : cls.examples.first;
        print('| `${parts[0]}` | `${parts[1]}` | ${parts[2]} | '
            '${cls.count} | ${ex.replaceAll("|", "\\|")} |');
      }
      print('');
    }
    _printSpellTags(true);
  }

  void _printSpellTags(bool markdown) {
    if (spellTags.isEmpty) return;
    if (markdown) {
      print('**Spell class-tag coverage** (guards the `data/v1` recovery path)\n');
      print('| Pack | Spells old | Tagged old | Class-tagged old | '
          'Spells new | Tagged new | Class-tagged new |');
      print('|---|--:|--:|--:|--:|--:|--:|');
    } else {
      print('\nSpell class-tag coverage (guards the data/v1 recovery path)');
    }
    for (final e in spellTags.entries) {
      final v = e.value;
      if (markdown) {
        print('| `${e.key}` | ${v[1]} | ${v[0]} | ${v[4]} | '
            '${v[3]} | ${v[2]} | ${v[5]} |');
      } else {
        final flag = (v[0] > v[2] || v[4] > v[5]) ? '  ← REGRESSED' : '';
        print('  ${e.key.padRight(30)} '
            'old ${v[0]}/${v[1]} (class ${v[4]})   '
            'new ${v[2]}/${v[3]} (class ${v[5]})$flag');
      }
    }
    if (markdown) print('');
  }

  List<String> _sortedChurn() => churn.keys.toList()
    ..sort((a, b) => _churnTotal(b).compareTo(_churnTotal(a)));

  int _churnTotal(String slug) => _sum(churn[slug]!.values);

  List<String> _sortedClasses() => changeClasses.keys.toList()
    ..sort((a, b) {
      final c = changeClasses[b]!.count.compareTo(changeClasses[a]!.count);
      return c != 0 ? c : a.compareTo(b);
    });
}

// ── Helpers ───────────────────────────────────────────────────────────────

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

String _enc(Object? v) => jsonEncode(v);

/// A value trimmed to something that fits one table cell.
String _short(Object? v) {
  if (v == null) return '(absent)';
  var s = v is String ? v : jsonEncode(v);
  s = s.replaceAll('\n', '⏎');
  return s.length <= 60 ? s : '${s.substring(0, 57)}…';
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final eq = a.indexOf('=');
    if (eq > 0) {
      out[a.substring(2, eq)] = a.substring(eq + 1);
    } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[a.substring(2)] = args[++i];
    }
  }
  return out;
}
