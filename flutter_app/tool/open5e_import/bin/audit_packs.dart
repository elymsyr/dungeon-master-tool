// Bundled-pack field census (offline audit tool).
//
//   dart run tool/open5e_import/bin/audit_packs.dart [--packs assets/open5e_packs]
//                                                    [--only class,subclass,...]
//                                                    [--markdown]
//                                                    [--builtin]
//
// `--builtin` (audit phase T2) points the same census at the built-in pack
// instead of the bundled assets: `generateBuiltinDnd5eV2Schema().seedRows`
// (Tier-0 rows) + `buildSrdCorePack()` (Tier-1 content). It is the target of
// every softRef this audit writes and nothing had ever measured it. Category
// selection widens to whatever those two actually ship — the `_auditedSlugs`
// allow-list below describes an *Open5e* pack, not the built-in one.
//
// Joins two things the rest of the toolchain never compares: the *declared*
// shape of a category (`generateBuiltinDnd5eV2Schema()` — every field, its
// group, whether it is required) and the *actual* contents of the shipped
// `assets/open5e_packs/*.pkg.json`. For each category it prints one row per
// declared field with how many bundled entities actually carry a value.
//
// This is the machine behind `docs/open5e_content_audit.md`: the Fill % column
// there is this tool's output, so the doc can be refreshed instead of
// hand-maintained. `--markdown` emits the tables in the doc's exact shape.
//
// A field counts as filled when its value is non-null and not an empty
// string/list/map. A `0` or `false` counts as filled — the mapper wrote it on
// purpose (e.g. `repeatable: false`), and treating it as absent would hide
// real coverage.
//
// A filled field is not the same as a *sourced* one. When every entity in a
// category carries the identical value, the mapper wrote a constant rather
// than reading the source (species `creature_type_ref` is hardcoded Humanoid;
// the synthesised gear stubs all carry `cost_cp: 0`). Those rows are marked
// `⚠ const` so a 100% column cannot be mistaken for real coverage.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';

/// Categories a pack can ship. Tier-0 lookups and Tier-2 DM categories never
/// appear in an Open5e pack, so auditing them would be noise.
const _auditedSlugs = [
  'class',
  'subclass',
  'species',
  'subspecies',
  'background',
  'feat',
  'spell',
  'magic-item',
  'monster',
  'creature-action',
  'trait',
  'adventuring-gear',
];

void main(List<String> args) {
  final opts = _parseArgs(args);
  final packDir = opts['packs'] ?? 'assets/open5e_packs';
  final markdown = args.contains('--markdown');
  final builtin = args.contains('--builtin');
  final only = (opts['only'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();

  final dir = Directory(packDir);
  if (!builtin && !dir.existsSync()) {
    stderr.writeln('ERROR: pack dir not found: $packDir');
    exit(2);
  }

  final schema = generateBuiltinDnd5eV2Schema().schema;
  final bySlug = <String, EntityCategorySchema>{
    for (final c in schema.categories) c.slug: c,
  };

  final census = builtin ? _readBuiltin() : _readPacks(dir);
  final auditable = builtin
      ? schema.categories.map((c) => c.slug).where(census.containsKey)
      : _auditedSlugs;
  final slugs = auditable.where((s) => only.isEmpty || only.contains(s));

  for (final slug in slugs) {
    final cat = bySlug[slug];
    if (cat == null) {
      stderr.writeln('WARN: schema has no category "$slug"');
      continue;
    }
    final stat = census[slug];
    final total = stat?.total ?? 0;
    final groupNames = <String, String>{
      for (final g in cat.fieldGroups) g.groupId: g.name,
    };

    if (markdown) {
      _printMarkdown(cat, groupNames, stat, total);
    } else {
      _printPlain(cat, groupNames, stat, total);
    }
  }

  // Keys present in the assets that the schema does not declare — a mapper
  // writing to a field nobody renders is as much a defect as an empty one.
  final undeclared = <String, Set<String>>{};
  census.forEach((slug, stat) {
    final declared = bySlug[slug]?.fields.map((f) => f.fieldKey).toSet() ?? {};
    final extra = stat.filled.keys.where((k) => !declared.contains(k)).toSet();
    if (extra.isNotEmpty) undeclared[slug] = extra;
  });
  if (undeclared.isNotEmpty) {
    print('\n## Undeclared keys written by the importer\n');
    undeclared.forEach((slug, keys) {
      print('- `$slug`: ${keys.map((k) => '`$k`').join(', ')}');
    });
  }
}

/// Below this many entities, "every row shares one value" is chance.
const _constMinSample = 5;

/// Per-category counts across every pack asset.
class _CategoryCensus {
  int total = 0;

  /// fieldKey → number of entities carrying a non-empty value.
  final Map<String, int> filled = {};

  /// fieldKey → the distinct values seen, capped at 2 entries. Two is all the
  /// "is this a constant?" question needs, and it keeps a 2,885-monster pack
  /// from retaining every stat block in memory.
  final Map<String, Set<String>> distinct = {};

  /// Which pack assets contributed entities of this category.
  final Set<String> packs = {};

  /// Every entity of this category carries the same value for [key] — the
  /// mapper wrote a constant instead of reading the source. Needs at least
  /// [_constMinSample] entities; below that a shared value is a coincidence,
  /// not a signal (the two bundled classes both happen to be full casters).
  bool isConstant(String key) =>
      total >= _constMinSample &&
      filled[key] == total &&
      (distinct[key]?.length ?? 0) == 1;
}

Map<String, _CategoryCensus> _readPacks(Directory dir) {
  final out = <String, _CategoryCensus>{};
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    final root = jsonDecode(f.readAsStringSync());
    if (root is! Map) continue;
    final entities = root['entities'];
    if (entities is! Map) continue;
    final packName = f.uri.pathSegments.last.replaceAll('.pkg.json', '');

    for (final raw in entities.values) {
      if (raw is! Map) continue;
      final slug = raw['type']?.toString();
      if (slug == null || !_auditedSlugs.contains(slug)) continue;
      _ingest(out, slug, packName, raw['attributes']);
    }
  }
  return out;
}

/// The same census over the built-in pack (audit **T2**) — Tier-0 seed rows
/// carry their values under `fields`, Tier-1 SRD rows under `attributes`, but
/// both are the flat map the schema's fieldKeys describe.
Map<String, _CategoryCensus> _readBuiltin() {
  final out = <String, _CategoryCensus>{};
  generateBuiltinDnd5eV2Schema().seedRows.forEach((slug, rows) {
    for (final row in rows) {
      _ingest(out, slug, 'builtin_schema', row['fields']);
    }
  });
  for (final raw in buildSrdCorePack().entities.values) {
    if (raw is! Map) continue;
    final slug = raw['type']?.toString();
    if (slug == null) continue;
    _ingest(out, slug, 'srd_core', raw['attributes']);
  }
  return out;
}

/// Count one entity of [slug] and every filled key in its value map.
void _ingest(
  Map<String, _CategoryCensus> out,
  String slug,
  String packName,
  dynamic attrs,
) {
  final stat = out.putIfAbsent(slug, _CategoryCensus.new);
  stat.total++;
  stat.packs.add(packName);
  if (attrs is! Map) return;
  attrs.forEach((k, v) {
    if (!_isFilled(v)) return;
    final key = k.toString();
    stat.filled[key] = (stat.filled[key] ?? 0) + 1;
    final seen = stat.distinct.putIfAbsent(key, () => <String>{});
    if (seen.length < 2) seen.add(jsonEncode(v));
  });
}

/// Non-null and not an empty string/list/map. `0` and `false` count as filled.
bool _isFilled(dynamic v) {
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  if (v is Iterable) return v.isNotEmpty;
  if (v is Map) return v.isNotEmpty;
  return true;
}

/// Whole percent, except near the ends: 2883/2885 must not read as `100%`
/// when the two missing rows are the whole finding.
String _pct(int n, int total) {
  if (total == 0) return '—';
  if (n == total) return '100%';
  if (n == 0) return '0%';
  // Floor rather than round, so a partial column can never display as full.
  final p = 100 * n / total;
  if (p >= 99 || p < 1) return '${(p * 10).floorToDouble() / 10}%';
  return '${p.floor()}%';
}

/// `✅` fully filled · `🟡` some entities carry it · `🔴` never written.
String _status(int n, int total) {
  if (total == 0) return '—';
  if (n == 0) return '🔴';
  if (n == total) return '✅';
  return '🟡';
}

void _printPlain(
  EntityCategorySchema cat,
  Map<String, String> groupNames,
  _CategoryCensus? stat,
  int total,
) {
  print('\n===== ${cat.slug}  (entities: $total, '
      'declared fields: ${cat.fields.length}, '
      'packs: ${stat?.packs.length ?? 0})');
  var lastGroup = '';
  for (final f in _sortedFields(cat)) {
    final grp = groupNames[f.groupId] ?? (f.groupId ?? '—');
    if (grp != lastGroup) {
      print('  [$grp]');
      lastGroup = grp;
    }
    final n = stat?.filled[f.fieldKey] ?? 0;
    final constant = stat?.isConstant(f.fieldKey) ?? false;
    print('   ${_status(n, total)} ${f.isRequired ? '*' : ' '} '
        '${f.fieldKey.padRight(36)} ${_pct(n, total).padLeft(4)}  ($n/$total)'
        '${constant ? '  ⚠ const' : ''}');
  }
}

void _printMarkdown(
  EntityCategorySchema cat,
  Map<String, String> groupNames,
  _CategoryCensus? stat,
  int total,
) {
  print('\n### `${cat.slug}` — $total entities, '
      '${cat.fields.length} declared fields\n');
  print('| | Field | Group | Req | Fill |');
  print('|---|---|---|:--:|--:|');
  for (final f in _sortedFields(cat)) {
    final grp = groupNames[f.groupId] ?? '—';
    final n = stat?.filled[f.fieldKey] ?? 0;
    final constant = stat?.isConstant(f.fieldKey) ?? false;
    print('| ${_status(n, total)}${constant ? ' ⚠' : ''} | `${f.fieldKey}` | '
        '$grp | ${f.isRequired ? '**yes**' : ''} | '
        '${_pct(n, total)} ($n/$total) |');
  }
}

/// Fields in render order: by group order, then by the field's own index —
/// the same order the card editor draws, so a doc row maps to what a DM sees.
List<dynamic> _sortedFields(EntityCategorySchema cat) {
  final groupOrder = <String, int>{
    for (final g in cat.fieldGroups) g.groupId: g.orderIndex,
  };
  final fields = [...cat.fields];
  fields.sort((a, b) {
    final ga = groupOrder[a.groupId] ?? 999;
    final gb = groupOrder[b.groupId] ?? 999;
    if (ga != gb) return ga.compareTo(gb);
    return a.orderIndex.compareTo(b.orderIndex);
  });
  return fields;
}

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    final a = args[i];
    if (a.startsWith('--')) out[a.substring(2)] = args[i + 1];
  }
  return out;
}
