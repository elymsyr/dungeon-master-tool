// Offline pack-conversion CLI — legacy bundled packs → Template v3
// (content-convert.md §Tooling item 2 / §8; master-roadmap PR-3.0).
//
// This is the converter that ties the two Phase-3 migration libraries together:
//
//   * `legacy_content_converter.dart` — per-field **value** migrations
//     (content-convert §1-2: wire-identical type renames + pip→checkboxPouch).
//   * `description_generator.dart`    — the player-facing **Markdown**
//     description engine (master-roadmap §4.1): per-kind effect/clause text
//     templates + the per-category section assembler.
//
// For every entity in a `*.pkg.json` pack it:
//   1. skips cards already stamped `"format": 3` (idempotent — content-convert
//      §Verification),
//   2. (a) runs the value migrations (a no-op for offline content packs, which
//      carry no pip-pouch fields; the same primitives run in the PC/world
//      on-open shim where those fields exist),
//   3. (b) assembles the card's completed `description` from its original prose
//      (intro) ⊕ rendered `effects`/`granted_modifiers` rows ⊕ `prereq_clauses`
//      bullets, in the §4.1 per-category section order,
//   4. (c) tallies the row dispositions (mapped / noted / dropped — §6) into a
//      per-pack `conversion_report.json` (the `unmapped_report.json` pattern),
//   5. stamps `"format": 3` on the entity and the pack metadata.
//
// SCOPE (PR-3.0 slice 4): the per-kind `effects` → v3 **data-field** mapping is
// now wired (`effect_field_mapper.dart`) — each parametric row is counted as
// `mapped`, its mechanics written into the canonical v3 data field, AND it is
// still surfaced in the description (master-roadmap §3 "keep the row ALSO
// described"). The mapper names the fields the JIT waves add to the template; it
// authors no template rule itself (RULE RESET intact). The mass conversion still
// runs in the Phase-3 waves, so the CLI defaults to **--dry-run** (it does not
// rewrite the committed pack assets unless `--write` is passed).
//
// Run from the Flutter project root (`flutter_app/`):
//
//     dart run tool/convert_packs_v3.dart                       # dry-run, all bundled packs
//     dart run tool/convert_packs_v3.dart assets/open5e_packs/open5e-bfrd.pkg.json
//     dart run tool/convert_packs_v3.dart --write --report-dir=build/conv  # apply + reports
//
// Exit code 0 = ok; 2 = usage / IO / parse error. Dev/CI script only; NOT part
// of the app build.
//
// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/services/template_migration/description_generator.dart';
import 'package:dungeon_master_tool/domain/services/template_migration/effect_field_mapper.dart';
import 'package:dungeon_master_tool/domain/services/template_migration/legacy_content_converter.dart';

/// Default location of the bundled packs (relative to the Flutter project root).
const String defaultPackDir = 'assets/open5e_packs';

// ─────────────────────────────────────────────────────────────────────────
// Report
// ─────────────────────────────────────────────────────────────────────────

/// Per-pack conversion tally (content-convert §8). Counts the §6 dispositions
/// of every effect/modifier row plus per-kind breakdowns and a sample of the
/// `noted` rows (so a reviewer can spot-check that each is visible as rules text
/// on its card — §Verification). Follows the `unmapped_report.json` shape.
class ConversionReport {
  ConversionReport({required this.packName});

  final String packName;

  /// Entities whose description was (re)assembled this run.
  int converted = 0;

  /// Entities already at `"format": 3` (idempotent skip).
  int skipped = 0;

  /// Parametric rows ([parametricEffectKinds]) — mapped to a v3 data field.
  int mapped = 0;

  /// Out-of-scope / unknown rows preserved as rules text in the description.
  int noted = 0;

  /// Null/empty rows that rendered to nothing (should be 0 for clean data).
  int dropped = 0;

  /// Prerequisite clauses rendered into the `### Prerequisites` bullet list.
  int prereqs = 0;

  /// Total v3 data-field writes produced by mapped rows (slice 4). A row may
  /// produce more than one write, so this can exceed [mapped].
  int fieldWrites = 0;

  /// Mapped rows that wrote to more than one distinct field (observability for
  /// a future multi-field kind — content-convert §6).
  int multiFieldRows = 0;

  final Map<String, int> mappedKinds = <String, int>{};
  final Map<String, int> notedKinds = <String, int>{};
  final Map<String, int> fieldWriteKeys = <String, int>{};
  final List<String> notedSamples = <String>[];

  void _bump(Map<String, int> bucket, String kind) {
    final key = kind.isEmpty ? '(none)' : kind;
    bucket[key] = (bucket[key] ?? 0) + 1;
  }

  void recordMapped(String kind) {
    mapped++;
    _bump(mappedKinds, kind);
  }

  /// Records the v3 data-field writes a mapped row produced (slice 4), tallying
  /// the per-field counts and flagging a row that fed more than one field.
  void recordFieldWrites(List<EffectFieldWrite> writes) {
    if (writes.isEmpty) return;
    final keys = <String>{};
    for (final w in writes) {
      fieldWrites++;
      _bump(fieldWriteKeys, w.fieldKey);
      keys.add(w.fieldKey);
    }
    if (keys.length > 1) multiFieldRows++;
  }

  void recordNoted(String kind, String entityName) {
    noted++;
    final label = kind.isEmpty ? '(prose)' : kind;
    _bump(notedKinds, label);
    if (notedSamples.length < 50) {
      notedSamples.add('$entityName — $label');
    }
  }

  /// Merges another report's totals into this one (for the run-wide rollup).
  void absorb(ConversionReport other) {
    converted += other.converted;
    skipped += other.skipped;
    mapped += other.mapped;
    noted += other.noted;
    dropped += other.dropped;
    prereqs += other.prereqs;
    fieldWrites += other.fieldWrites;
    multiFieldRows += other.multiFieldRows;
    other.mappedKinds.forEach((k, v) => mappedKinds[k] = (mappedKinds[k] ?? 0) + v);
    other.notedKinds.forEach((k, v) => notedKinds[k] = (notedKinds[k] ?? 0) + v);
    other.fieldWriteKeys
        .forEach((k, v) => fieldWriteKeys[k] = (fieldWriteKeys[k] ?? 0) + v);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'package': packName,
        'format': 3,
        'entities_converted': converted,
        'entities_skipped': skipped,
        'effects': <String, int>{
          'mapped': mapped,
          'noted': noted,
          'dropped': dropped,
        },
        'prerequisite_clauses': prereqs,
        'field_writes': <String, dynamic>{
          'total': fieldWrites,
          'multi_field_rows': multiFieldRows,
          'by_field': _sortedByCountDesc(fieldWriteKeys),
        },
        'mapped_kinds': _sortedByCountDesc(mappedKinds),
        'noted_kinds': _sortedByCountDesc(notedKinds),
        'noted_samples': notedSamples,
      };

  String get summaryLine =>
      '$packName: converted $converted, skipped $skipped | '
      'effects mapped $mapped / noted $noted / dropped $dropped | '
      'fields $fieldWrites | prereqs $prereqs';
}

/// A map sorted by descending count then key, for stable, readable report JSON.
Map<String, int> _sortedByCountDesc(Map<String, int> m) {
  final entries = m.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return <String, int>{for (final e in entries) e.key: e.value};
}

// ─────────────────────────────────────────────────────────────────────────
// Conversion core (pure — no dart:io, so the harness can drive it)
// ─────────────────────────────────────────────────────────────────────────

/// The `###` section that receives a card's rendered effect rows / mechanical
/// prose, per the §4.1 section table for [categorySlug]. The returned heading is
/// one of that category's canonical sections so [assembleDescription] slots it
/// into the right place; an unmapped category gets `Effects` (still emitted —
/// appended — so content is never dropped).
String effectsSectionFor(String categorySlug) {
  switch (categorySlug) {
    case 'feat':
      return 'Effects';
    case 'species':
    case 'subspecies':
      return 'Traits';
    case 'monster':
    case 'npc':
    case 'animal':
    case 'creature-action':
    case 'trait':
      return 'Traits';
    case 'class':
      return 'Class Features';
    case 'subclass':
      return 'Features by Level';
    case 'background':
      return 'Proficiencies';
    case 'spell':
      return 'Effect';
    case 'adventuring-gear':
    case 'tool':
    case 'pack':
    case 'ammunition':
    case 'trinket':
    case 'mount':
    case 'vehicle':
    case 'armor':
    case 'weapon':
    case 'magic-item':
    case 'curse':
    case 'poison':
      return 'Properties';
    default:
      return 'Effects';
  }
}

/// Converts a single pack entity **in place**, tallying into [report]. Returns
/// `true` if the entity was (re)assembled, `false` if it was skipped because it
/// is already at `"format": 3` (idempotent). Deterministic.
bool convertEntity(Map<String, dynamic> entity, ConversionReport report) {
  final rawAttrs = entity['attributes'];
  final attributes = rawAttrs is Map
      ? Map<String, dynamic>.from(rawAttrs)
      : <String, dynamic>{};

  // Idempotent skip — a card already at format 3 is left byte-identical.
  if (_isFormat3(entity['format']) || _isFormat3(attributes['format'])) {
    report.skipped++;
    return false;
  }

  final categorySlug = _str(entity['type']);

  // (a) value migrations — content-convert §1-2. Offline content packs declare
  // no pip-pouch fields, so this is identity here; the SAME call drives the
  // PC/world on-open shim, where the pouch fields (death saves, heroic
  // inspiration) are present and the pip→checkboxPouch rule fires.
  _applyValueMigrations(attributes, pipPouchFields: const <String, int>{});

  // (b) description assembly.
  final intro = _firstNonEmptyStr(
    [entity['description'], attributes['description']],
  );
  final effectRows = <Map<String, dynamic>>[];
  final proseParts = <String>[];
  _collectEffects(attributes['effects'], effectRows, proseParts);
  _collectEffects(attributes['granted_modifiers'], effectRows, proseParts);
  final rawPrereqRows = _mapList(attributes['prereq_clauses']);
  final prereqRows = rawPrereqRows
      .map(normalizePrereqClause)
      .toList(growable: false);

  // (c) tally row dispositions (§6 / §8) and, for mapped rows, write the v3
  // data field the standing template rules read (slice 4). The row stays
  // described regardless (renderEffectsBody below renders every row).
  for (final row in effectRows) {
    final kind = _str(row['kind']);
    switch (classifyEffectRow(row)) {
      case EffectDisposition.mapped:
        report.recordMapped(kind);
        final writes = mapEffectToFields(row);
        applyEffectWrites(attributes, writes);
        report.recordFieldWrites(writes);
      case EffectDisposition.noted:
        report.recordNoted(kind, _str(entity['name']));
      case EffectDisposition.dropped:
        report.dropped++;
    }
  }
  // Mechanical prose carried as a bare string (e.g. a magic item's `effects`)
  // is preserved verbatim in the description — a `noted` disposition.
  final introTrim = intro.trim();
  final uniqueProse =
      proseParts.where((p) => p.trim() != introTrim).toList(growable: false);
  for (final _ in uniqueProse) {
    report.recordNoted('', _str(entity['name']));
  }
  report.prereqs += rawPrereqRows.length;

  // Build sections and assemble.
  final sections = <String, String>{};
  final effectsBody = <String>[
    renderEffectsBody(effectRows),
    ...uniqueProse,
  ].where((s) => s.trim().isNotEmpty).join('\n\n');
  if (effectsBody.trim().isNotEmpty) {
    sections[effectsSectionFor(categorySlug)] = effectsBody;
  }
  final prereqBody = renderPrerequisitesBody(prereqRows);
  if (prereqBody.trim().isNotEmpty) {
    sections['Prerequisites'] = prereqBody;
  }

  final newDescription = assembleDescription(
    categorySlug: categorySlug,
    intro: intro,
    sections: sections,
  );
  entity['description'] = newDescription;
  if (attributes.containsKey('description')) {
    attributes['description'] = newDescription;
  }

  // Stamp the entity (per-card idempotency key).
  attributes['format'] = 3;
  entity['attributes'] = attributes;
  report.converted++;
  return true;
}

/// Converts every entity in [pack] **in place** and returns the pack's report.
/// Stamps `"format": 3` on the pack metadata (content-convert §8).
ConversionReport convertPack(Map<String, dynamic> pack) {
  final report = ConversionReport(packName: _str(pack['package_name']));
  final entities = pack['entities'];
  if (entities is Map) {
    for (final key in entities.keys.toList()) {
      final value = entities[key];
      if (value is Map) {
        final entity = Map<String, dynamic>.from(value);
        convertEntity(entity, report);
        entities[key] = entity;
      }
    }
  }
  final meta = pack['metadata'];
  if (meta is Map) meta['format'] = 3;
  pack['format'] = 3;
  return report;
}

// ─────────────────────────────────────────────────────────────────────────
// Pure helpers
// ─────────────────────────────────────────────────────────────────────────

bool _isFormat3(dynamic value) {
  if (value is num) return value.toInt() == 3;
  if (value is String) return value.trim() == '3';
  return false;
}

String _str(dynamic v) => v == null ? '' : v.toString();

String _firstNonEmptyStr(List<dynamic> candidates) {
  for (final c in candidates) {
    final s = _str(c).trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

/// Splits a polymorphic `effects` / `granted_modifiers` value into structured
/// modifier [rows] (`{kind, …}` maps) and free-text [prose] (a bare string, or
/// string entries in a list — e.g. a magic item's `effects` markdown).
void _collectEffects(
  dynamic raw,
  List<Map<String, dynamic>> rows,
  List<String> prose,
) {
  if (raw is List) {
    for (final r in raw) {
      if (r is Map) {
        rows.add(Map<String, dynamic>.from(r));
      } else if (r is String && r.trim().isNotEmpty) {
        prose.add(r.trim());
      }
    }
  } else if (raw is String && raw.trim().isNotEmpty) {
    prose.add(raw.trim());
  }
}

/// Normalises an open5e `prereq_clauses` row (discriminated by `type`, with
/// option-ref shapes) into the closed clause vocabulary [renderPrereqClause]
/// understands (`kind` + the §4.2 fields). content-convert §5 keeps the clause
/// *meaning* unchanged; bridging the source's `type`/`*_options` shape to the
/// engine's `kind`/`target_ref` shape is the converter's job, so the engine
/// stays a single closed vocabulary. An authored `text` clause passes straight
/// through; an unknown `type` is forwarded with `kind` set so the engine
/// humanizes it (never dropped).
Map<String, dynamic> normalizePrereqClause(Map<String, dynamic> clause) {
  if (_str(clause['text']).isNotEmpty) return clause;

  final type = _str(clause['type']).isNotEmpty
      ? _str(clause['type'])
      : _str(clause['kind']);
  switch (type) {
    case 'ability_min':
      return <String, dynamic>{
        'kind': 'min_ability_score',
        'ability': _firstRefName(clause['ability_options']),
        'value': clause['min_score'] ?? clause['value'] ?? 13,
      };
    case 'character_level':
    case 'min_level':
      return <String, dynamic>{
        'kind': 'min_character_level',
        'value': clause['min_level'] ?? clause['value'] ?? 1,
      };
    case 'spellcasting':
      return const <String, dynamic>{'kind': 'spellcasting'};
    case 'armor_proficiency':
      final cat = _str(clause['category']).isNotEmpty
          ? _str(clause['category'])
          : _refName(clause['category_ref']);
      return <String, dynamic>{
        'kind': 'proficiency',
        'target_kind': 'armor_category',
        'target_ref': <String, dynamic>{
          'name': cat.isEmpty ? 'armor' : '$cat armor',
        },
      };
    case 'skill_proficiency':
      final skills = _refNames(clause['skill_options']);
      return <String, dynamic>{
        'kind': 'proficiency',
        'target_kind': 'skill',
        'target_ref': <String, dynamic>{
          'name': skills.isEmpty ? 'a skill' : skills,
        },
      };
    case 'weapon_proficiency':
      final wc = _str(clause['weapon_class']).isNotEmpty
          ? _str(clause['weapon_class'])
          : _refNames(clause['weapon_options']);
      return <String, dynamic>{
        'kind': 'proficiency',
        'target_kind': 'weapon_category',
        'target_ref': <String, dynamic>{
          'name': wc.isEmpty ? 'weapons' : '$wc weapons',
        },
      };
    default:
      // Unknown clause — forward with `kind` set so the engine humanizes it.
      if (_str(clause['kind']).isEmpty && type.isNotEmpty) {
        return <String, dynamic>{...clause, 'kind': type};
      }
      return clause;
  }
}

String _refName(dynamic ref) {
  if (ref is Map) return _str(ref['name']);
  return _str(ref);
}

String _firstRefName(dynamic list) {
  if (list is List && list.isNotEmpty) return _refName(list.first);
  return _refName(list);
}

String _refNames(dynamic list) {
  if (list is! List) return _refName(list);
  final names = list.map(_refName).where((s) => s.isNotEmpty).toList();
  return names.join(' or ');
}

List<Map<String, dynamic>> _mapList(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final r in raw)
      if (r is Map) Map<String, dynamic>.from(r),
  ];
}

/// content-convert §1-2 value migrations. [pipPouchFields] maps an attribute key
/// to its declared pouch `count`; for each present key the stored int is
/// migrated to a `{count, states}` pouch. Empty (and thus identity) for offline
/// content packs; populated by the PC/world on-open shim. Idempotent.
void _applyValueMigrations(
  Map<String, dynamic> attributes, {
  Map<String, int> pipPouchFields = const <String, int>{},
}) {
  for (final entry in pipPouchFields.entries) {
    if (!attributes.containsKey(entry.key)) continue;
    attributes[entry.key] = migratePipIntToCheckboxPouch(
      attributes[entry.key],
      count: entry.value,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// CLI
// ─────────────────────────────────────────────────────────────────────────

void main(List<String> args) {
  var write = false;
  var showHelp = false;
  String? reportDir;
  final paths = <String>[];

  for (final a in args) {
    if (a == '--write') {
      write = true;
    } else if (a == '--dry-run') {
      write = false;
    } else if (a == '-h' || a == '--help') {
      showHelp = true;
    } else if (a.startsWith('--report-dir=')) {
      reportDir = a.substring('--report-dir='.length);
    } else if (a.startsWith('--')) {
      stderr.writeln('Unknown flag: $a');
      exitCode = 2;
      return;
    } else {
      paths.add(a);
    }
  }

  if (showHelp) {
    _printUsage();
    return;
  }

  final List<File> files;
  try {
    files = _resolvePackFiles(paths);
  } on _CliError catch (e) {
    stderr.writeln(e.message);
    exitCode = 2;
    return;
  }
  if (files.isEmpty) {
    stderr.writeln('No `*.pkg.json` packs found.');
    exitCode = 2;
    return;
  }

  final rollup = ConversionReport(packName: '(all)');
  final encoder = const JsonEncoder.withIndent('  ');

  for (final file in files) {
    final Map<String, dynamic> pack;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        stderr.writeln('Skipping ${file.path}: not a JSON object.');
        continue;
      }
      pack = Map<String, dynamic>.from(decoded);
    } on FormatException catch (e) {
      stderr.writeln('Skipping ${file.path}: parse error — ${e.message}');
      exitCode = 2;
      continue;
    }

    final report = convertPack(pack);
    rollup.absorb(report);
    print(report.summaryLine);

    if (write) {
      file.writeAsStringSync('${encoder.convert(pack)}\n');
    }
    if (write || reportDir != null) {
      final reportFile = _reportFileFor(file, reportDir);
      reportFile.parent.createSync(recursive: true);
      reportFile.writeAsStringSync('${encoder.convert(report.toJson())}\n');
    }
  }

  print('');
  print('Total across ${files.length} pack(s): ${rollup.summaryLine}');
  if (rollup.notedKinds.isNotEmpty) {
    final kinds = _sortedByCountDesc(rollup.notedKinds);
    print('Noted kinds: ${kinds.entries.map((e) => '${e.key}×${e.value}').join(', ')}');
  }
  if (!write) {
    print('(dry run — no pack files modified; pass --write to apply.'
        '${reportDir == null ? ' Pass --report-dir=<dir> to emit reports.' : ''})');
  }
}

File _reportFileFor(File pack, String? reportDir) {
  final base = pack.uri.pathSegments.isEmpty
      ? 'pack'
      : pack.uri.pathSegments.last.replaceAll('.pkg.json', '').replaceAll('.json', '');
  final name = '$base.conversion_report.json';
  if (reportDir != null) {
    return File('$reportDir${Platform.pathSeparator}$name');
  }
  final dir = pack.parent.path;
  return File('$dir${Platform.pathSeparator}$name');
}

List<File> _resolvePackFiles(List<String> paths) {
  final files = <File>[];
  if (paths.isEmpty) {
    return _packsInDir(Directory(defaultPackDir));
  }
  for (final p in paths) {
    final file = File(p);
    final dir = Directory(p);
    if (file.existsSync()) {
      files.add(file);
    } else if (dir.existsSync()) {
      files.addAll(_packsInDir(dir));
    } else {
      throw _CliError('Not found: $p');
    }
  }
  return files;
}

List<File> _packsInDir(Directory dir) {
  if (!dir.existsSync()) {
    throw _CliError('Pack directory not found: ${dir.path}');
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

class _CliError implements Exception {
  _CliError(this.message);
  final String message;
}

void _printUsage() {
  print('''
convert_packs_v3 — legacy bundled packs → Template v3 (content-convert §Tooling).

Usage (run from flutter_app/):
  dart run tool/convert_packs_v3.dart [paths...] [--write] [--report-dir=<dir>]

Arguments:
  paths            one or more `*.pkg.json` files or directories of them.
                   Defaults to `$defaultPackDir` when omitted.

Flags:
  --write          write the converted packs back + emit conversion_report.json.
  --dry-run        analyse only, write nothing (default).
  --report-dir=D   write each pack's conversion_report.json into D
                   (implies report output even in a dry run).
  -h, --help       show this help.

Per entity: skips cards already "format": 3 (idempotent); runs value migrations
(content-convert §1-2), assembles a player-facing Markdown `description` from
the original prose + rendered effect rows + prerequisite bullets (§4.1 order),
and stamps "format": 3. Tallies mapped / noted / dropped row counts (§6/§8).
''');
}
