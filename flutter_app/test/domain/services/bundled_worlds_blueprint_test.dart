import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/services/builtin_content_names.dart';
import 'package:dungeon_master_tool/domain/services/world_blueprint_converter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ships-broken guard: every bundled world under `assets/worlds/` must convert
/// with zero issues.
///
/// Bir blueprint hatası hiçbir yerde patlamıyor — çözülemeyen soft ref okuma
/// anında sessizce düşer, şemada olmayan alan `attributes` içinde ölü kalır.
/// Dolayısıyla kırılma noktası burası: bozuk bir dünya build'i geçemez.
void main() {
  final root = Directory('assets/worlds');
  final manifest = File('${root.path}/manifest.json');
  if (!manifest.existsSync()) return;

  final worlds = (jsonDecode(manifest.readAsStringSync())
      as Map<String, dynamic>)['worlds'] as List;

  for (final w in worlds.cast<Map<String, dynamic>>()) {
    final dir = '${root.path}/${w['dir']}';

    test('bundled world "${w['title']}" converts cleanly', () {
      final meta = jsonDecode(File('$dir/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

      Map<String, dynamic>? read(String name) {
        final f = File('$dir/$name');
        return f.existsSync()
            ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
            : null;
      }

      final result = WorldBlueprintConverter(
        packageName: meta['slug'] as String,
        sourceTitle: '${meta['title']}, ${meta['system']}',
        tier0Slugs: blueprintTier0Slugs(),
        contentSlugs: blueprintContentSlugs(),
        knownNames: builtinContentNames(),
        fieldKeys: blueprintFieldKeys(),
        mediaResolver: (rel) => File('$dir/$rel').existsSync() ? rel : null,
      ).convert(
        worldBlueprint: read('world-blueprint.json'),
        characterBlueprint: read('blueprint.json'),
      );

      expect(
        result.issues.map((i) => '$i'),
        isEmpty,
        reason: 'run `dart run tool/content/convert_blueprint.dart --dir $dir '
            '--check` for the full report',
      );
      expect(result.entities, isNotEmpty);
    });

    test('bundled world "${w['title']}" is declared in pubspec assets', () {
      // Flutter asset directories are not recursive. A world whose media
      // subfolders are not listed ships as a manifest and nothing else — the
      // installer then finds no blueprints and no images in a release build.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dirs = <String>{
        for (final d
            in Directory(dir).listSync(recursive: true).whereType<Directory>())
          if (!d.path.split(Platform.pathSeparator).any((s) => s.startsWith('.')))
            '${d.path.replaceAll(r'\', '/')}/',
        '$dir/',
      };
      for (final d in dirs) {
        expect(
          pubspec.contains('- $d') || pubspec.contains('- "$d"'),
          isTrue,
          reason: 'pubspec.yaml flutter.assets is missing `- $d`',
        );
      }
    });
  }
}
