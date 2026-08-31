/// Blueprint → `.pkg.json` dönüştürücü + doğrulayıcı.
///
/// Kullanım (flutter_app/ içinden):
///   dart run tool/content/convert_blueprint.dart \
///     --dir assets/worlds/99_devils_of_uzrahs_palace_shadowdark
///
///   `--out <path>`   çıktı dosyası (varsayılan: `<dir>/<slug>.pkg.json`)
///   --check        hiçbir şey yazma, sadece doğrula
///
/// Çözülemeyen tek bir ref bile **non-zero exit** demektir. Sebep:
/// çözülemeyen soft ref uygulamada okuma anında sessizce düşer, yani bozuk
/// bir blueprint hatasız kurulur ve kullanıcı eksik ekipman/trait/spell
/// listesini hiç fark etmez. Kırılma noktası burası olmalı.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/services/builtin_content_names.dart';
import 'package:dungeon_master_tool/domain/services/world_blueprint_converter.dart';

void main(List<String> args) {
  String? dir;
  String? out;
  var checkOnly = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--dir':
        if (i + 1 < args.length) dir = args[++i];
      case '--out':
        if (i + 1 < args.length) out = args[++i];
      case '--check':
        checkOnly = true;
    }
  }
  if (dir == null) {
    stderr.writeln('usage: convert_blueprint.dart --dir <world dir> '
        '[--out <file>] [--check]');
    exit(64);
  }

  final manifest = _readJson('$dir/manifest.json');
  if (manifest == null) {
    stderr.writeln('✗ $dir/manifest.json not found');
    exit(66);
  }
  final worldBp = _readJson('$dir/world-blueprint.json');
  final charBp = _readJson('$dir/blueprint.json');

  final packageName = manifest['slug'] as String;
  final converter = WorldBlueprintConverter(
    packageName: packageName,
    sourceTitle: '${manifest['title']}, ${manifest['system']}',
    tier0Slugs: blueprintTier0Slugs(),
    contentSlugs: blueprintContentSlugs(),
    knownNames: builtinContentNames(),
    fieldKeys: blueprintFieldKeys(),
    relationTargets: blueprintRelationTargets(),
    // Zip/pkg içinde yollar relative kalmalı; burada sadece dosyanın gerçekten
    // pakete girdiğini doğruluyoruz.
    mediaResolver: (rel) =>
        File('$dir/$rel').existsSync() ? rel : null,
  );

  final result = converter.convert(
    worldBlueprint: worldBp,
    characterBlueprint: charBp,
  );

  for (final issue in result.issues) {
    stderr.writeln(issue);
  }

  final counts = result.counts;
  stdout.writeln('${result.entities.length} entities '
      '(${counts.entries.map((e) => '${e.key}=${e.value}').join(', ')})');
  // PC'ler entity değil: kurulumda dünyanın Characters sekmesine ownersız
  // karakter olarak yazılıyorlar.
  stdout.writeln('${result.characters.length} player character(s)');

  if (result.hasErrors) {
    stderr.writeln('✗ ${result.errors.length} unresolved reference(s) — '
        'nothing written. Add the missing entity to the blueprint (or fix the '
        'name so it matches the SRD pack) and re-run.');
    exit(1);
  }

  if (checkOnly) {
    stdout.writeln('✓ blueprint is clean');
    return;
  }

  final target = out ?? '$dir/$packageName.pkg.json';
  final pkg = {
    'package_name': packageName,
    'metadata': {
      'title': manifest['title'],
      'publisher': manifest['publisher'],
      'license': manifest['license'],
      'attribution': manifest['attribution'],
      'game_system': manifest['system'],
      'source': manifest['title'],
      'pack_version': manifest['version'],
      'counts': {...counts, 'player-character': result.characters.length},
    },
    'entities': result.entities,
    'characters': result.characters,
  };
  File(target).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(pkg));
  stdout.writeln('✓ wrote $target');
}

Map<String, dynamic>? _readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
}
