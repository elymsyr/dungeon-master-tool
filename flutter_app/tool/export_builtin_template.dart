// One-shot exporter: serializes the built-in D&D 5e v3 template
// ([generateBuiltinDnd5eTemplateV3]) to its bundled JSON asset
// (`assets/templates/dnd5e_srd.template.json`).
//
// Run from the Flutter project root (`flutter_app/`):
//
//     dart run tool/export_builtin_template.dart
//
// The output is canonical (map keys sorted recursively) and pretty-printed
// (2-space indent) so the committed asset diffs cleanly line-by-line — every
// just-in-time template edit (Phase 3 waves) shows up as a reviewable JSON
// hunk. The exporter is idempotent: a fixed timestamp
// ([builtinDnd5eTemplateTimestamp]) is stamped on the template, so re-running
// against an unchanged generator produces a byte-identical file (clean
// `git diff`).
//
// RULE RESET INVARIANT: the exporter aborts if any field carries `rules` — the
// v3 built-in must ship rule-free (roadmap §1.1). It also prints the content
// hash so it can be cross-checked against the loader's debug assert in a
// running app.
//
// This is a dev/CI script only; it is NOT part of the app build.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_template_v3.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema_hash.dart';

void main(List<String> args) {
  final schema = generateBuiltinDnd5eTemplateV3();
  final json = schema.toJson();

  // Guard: the v3 built-in must be rule-free (RULE RESET, roadmap §1.1).
  final offenders = _fieldsWithRules(json);
  if (offenders.isNotEmpty) {
    stderr.writeln(
      'ABORT: ${offenders.length} field(s) carry rules; the built-in '
      'template must ship rule-free.\n  ${offenders.join('\n  ')}',
    );
    exitCode = 2;
    return;
  }

  final canonical = _canonicalize(json);
  final encoded = '${const JsonEncoder.withIndent('  ').convert(canonical)}\n';

  final outFile = File(builtinDnd5eTemplateAssetPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(encoded);

  final hash = computeWorldSchemaContentHash(schema);
  final categories = (json['categories'] as List).length;
  final seedRows = (json['seedRows'] as Map?)?.length ?? 0;
  print('Wrote ${outFile.path}');
  print('  categories : $categories');
  print('  seedRows   : $seedRows catalog(s)');
  print('  formatVer  : ${json['formatVersion']}');
  print('  contentHash: $hash');
  print(
    'Confirm this hash matches BuiltinTemplateLoader\'s debug assert in a '
    'running app.',
  );
}

/// Collects `"<categorySlug>/<fieldKey>"` for every field that carries a
/// non-empty `rules` list — used to enforce the rule-free invariant.
List<String> _fieldsWithRules(Map<String, dynamic> schemaJson) {
  final out = <String>[];
  final categories = (schemaJson['categories'] as List?) ?? const [];
  for (final cat in categories) {
    if (cat is! Map) continue;
    final slug = cat['slug'] ?? cat['categoryId'] ?? '?';
    final fields = (cat['fields'] as List?) ?? const [];
    for (final f in fields) {
      if (f is! Map) continue;
      final rules = f['rules'];
      if (rules is List && rules.isNotEmpty) {
        out.add('$slug/${f['fieldKey'] ?? f['fieldId'] ?? '?'}');
      }
    }
  }
  return out;
}

/// Recursively sorts map keys so the encoded asset is deterministic.
/// List order is preserved (meaningful for categories/fields). Mirrors the
/// canonicalization in `world_schema_hash.dart` so the pretty-printed asset
/// and the hashed form agree on key ordering.
Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in sortedKeys) k: _canonicalize(value[k])};
  }
  if (value is List) {
    return [for (final e in value) _canonicalize(e)];
  }
  return value;
}
