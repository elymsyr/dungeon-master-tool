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

      final blueprint = read('world-blueprint.json');
      final converter = WorldBlueprintConverter(
        packageName: meta['slug'] as String,
        sourceTitle: '${meta['title']}, ${meta['system']}',
        tier0Slugs: blueprintTier0Slugs(),
        contentSlugs: blueprintContentSlugs(),
        knownNames: builtinContentNames(),
        fieldKeys: blueprintFieldKeys(),
        mediaResolver: (rel) => File('$dir/$rel').existsSync() ? rel : null,
      );
      final result = converter.convert(
        worldBlueprint: blueprint,
        characterBlueprint: read('blueprint.json'),
      );

      expect(
        result.issues.map((i) => '$i'),
        isEmpty,
        reason: 'run `dart run tool/content/convert_blueprint.dart --dir $dir '
            '--check` for the full report',
      );
      expect(result.entities, isNotEmpty);
      // `pinned` girdileri `kategori/isim` — yazım hatası sessizce hiçbir
      // şeyi pinlemez, o yüzden burada id'ye çözülüp entity'de aranıyor.
      for (final ref in (blueprint?['pinned'] as List? ?? const [])) {
        final i = (ref as String).indexOf('/');
        expect(i, greaterThan(0), reason: 'pinned ref must be `slug/name`: $ref');
        expect(
          result.entities,
          contains(converter.entityId(ref.substring(0, i), ref.substring(i + 1))),
          reason: 'pinned entity not found: $ref',
        );
      }
      // PC'ler entity değil; `Entity.fromJson`'ın beklediği biçimde
      // gelmezlerse kurulum karakteri hiç yazamaz.
      for (final c in result.characters) {
        expect(c['id'], isA<String>());
        expect(c['categorySlug'], 'player-character');
        expect(c['fields'], isA<Map<String, dynamic>>());
      }
    });
  }

  // `assets/worlds/cairn/` dünya değil, **paket** authoring kaynağı: üstteki
  // `manifest.json`'a yazılmaz (uygulamaya dünya olarak paketlenmez), ama
  // ürettiği blueprint aynı converter'dan geçiyor. Aynı ships-broken koruması
  // burada da geçerli — bozuk bir parser çıktısı build'i geçmemeli.
  final cairn = Directory('${root.path}/cairn');
  if (cairn.existsSync()) {
    for (final dir in cairn.listSync().whereType<Directory>()) {
      final meta = File('${dir.path}/manifest.json');
      final bp = File('${dir.path}/world-blueprint.json');
      if (!meta.existsSync() || !bp.existsSync()) continue;
      final slug =
          (jsonDecode(meta.readAsStringSync()) as Map)['slug'] as String;

      test('cairn pack "$slug" converts cleanly', () {
        final result = WorldBlueprintConverter(
          packageName: slug,
          sourceTitle: slug,
          tier0Slugs: blueprintTier0Slugs(),
          contentSlugs: blueprintContentSlugs(),
          knownNames: builtinContentNames(),
          fieldKeys: blueprintFieldKeys(),
          relationTargets: blueprintRelationTargets(),
          mediaResolver: (rel) =>
              File('${dir.path}/$rel').existsSync() ? rel : null,
        ).convert(
          worldBlueprint:
              jsonDecode(bp.readAsStringSync()) as Map<String, dynamic>,
        );

        expect(
          result.issues.map((i) => '$i'),
          isEmpty,
          reason: 'run `dart run tool/content/convert_blueprint.dart --dir '
              '${dir.path} --check` for the full report',
        );
      });
    }
  }
}
