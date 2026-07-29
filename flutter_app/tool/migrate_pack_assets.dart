// Rewrite bundled `.pkg.json` assets from the retired effect DSLs to the named
// grant-block fields.
//
// The packs under `assets/open5e_packs/` were emitted before the rule system
// was removed, so a handful of rows still carry `rule_effects` / `effects` /
// `granted_modifiers`. `PackagePayloadImporter.install` converts them on the
// way in, so they *work* — but every install pays the conversion and the
// shipped JSON still advertises a language the app no longer has. This brings
// the assets forward once.
//
// It runs the real `migrateRuleEffects`, the same converter the import path
// uses, so there is no second implementation to drift.
//
//   dart run tool/migrate_pack_assets.dart [--dry-run] [<dir-or-file> ...]
//
// Defaults to `assets/open5e_packs`. Output matches `tool/open5e_import/
// emit.dart`: compact `jsonEncode`, no trailing newline.

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/data/schema/rule_effects_migration.dart';

const _legacyKeys = {'rule_effects', 'effects', 'granted_modifiers'};

/// `effects` is not always the retired DSL: on a magic item it is the
/// narrative blurb and on a spell / creature-action it is the separate
/// `spellEffectList`, both of which are still live. Only rows whose `effects`
/// is a *list of effect rows* on a card type that used the feat DSL should be
/// touched.
bool _isLegacyEffects(String slug, Object? value) {
  if (slug == 'magic-item' || slug == 'spell' || slug == 'creature-action') {
    return false;
  }
  if (value is! List) return false;
  return value.any((r) => r is Map && r.containsKey('kind'));
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final targets = args.where((a) => !a.startsWith('--')).toList();
  final files = <File>[];
  for (final t in targets.isEmpty ? const ['assets/open5e_packs'] : targets) {
    final dir = Directory(t);
    if (dir.existsSync()) {
      files.addAll(dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pkg.json')));
    } else if (File(t).existsSync()) {
      files.add(File(t));
    } else {
      stderr.writeln('skip (not found): $t');
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  var totalRows = 0;
  var totalPacks = 0;
  for (final file in files) {
    final root = jsonDecode(file.readAsStringSync());
    if (root is! Map<String, dynamic>) {
      stderr.writeln('skip (unexpected shape): ${file.path}');
      continue;
    }
    final entities = root['entities'];
    if (entities is! Map) {
      stderr.writeln('skip (no entities map): ${file.path}');
      continue;
    }

    var changed = 0;
    final touchedKeys = <String, int>{};
    for (final entry in entities.entries) {
      final row = entry.value;
      if (row is! Map) continue;
      final attrs = row['attributes'];
      if (attrs is! Map) continue;
      final slug = row['type']?.toString() ?? '';

      final present = _legacyKeys
          .where((k) =>
              attrs.containsKey(k) &&
              (k != 'effects' || _isLegacyEffects(slug, attrs[k])))
          .toList();
      if (present.isEmpty) continue;

      // Hand the converter only the keys it owns, so a live `effects` field on
      // a card that also has a legacy row is never swallowed.
      final input = Map<String, dynamic>.from(attrs);
      final untouched = <String, dynamic>{};
      for (final k in _legacyKeys.difference(present.toSet())) {
        if (input.containsKey(k)) untouched[k] = input.remove(k);
      }

      final migrated = migrateRuleEffects(input);
      if (identical(migrated, input) && untouched.isEmpty) continue;
      row['attributes'] = <String, dynamic>{...migrated, ...untouched};

      changed++;
      for (final k in present) {
        touchedKeys[k] = (touchedKeys[k] ?? 0) + 1;
      }
    }

    if (changed == 0) continue;
    totalPacks++;
    totalRows += changed;
    final name = file.uri.pathSegments.last;
    stdout.writeln('$name: $changed rows  $touchedKeys');
    if (!dryRun) file.writeAsStringSync(jsonEncode(root));
  }

  stdout.writeln(dryRun
      ? '\ndry run — $totalRows rows in $totalPacks packs would change'
      : '\nrewrote $totalRows rows in $totalPacks packs');
}
