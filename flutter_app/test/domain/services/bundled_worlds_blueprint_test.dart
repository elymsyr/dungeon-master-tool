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
      expectRefsResolve(blueprint, converter, result.entities);
      // PC'ler entity değil; `Entity.fromJson`'ın beklediği biçimde
      // gelmezlerse kurulum karakteri hiç yazamaz.
      for (final c in result.characters) {
        expect(c['id'], isA<String>());
        expect(c['categorySlug'], 'player-character');
        expect(c['fields'], isA<Map<String, dynamic>>());
      }
    });
  }

  // `assets/worlds/aegis/` dünya değil, **paket** authoring kökü: üstteki
  // `manifest.json`'a yazılmazlar (uygulamaya dünya olarak paketlenmezler), ama
  // ürettikleri blueprint aynı converter'dan geçiyor. Aynı ships-broken koruması
  // burada da geçerli — bozuk bir parser çıktısı build'i geçmemeli.
  for (final packRoot in ['aegis']) {
    final packs = Directory('${root.path}/$packRoot');
    if (!packs.existsSync()) continue;
    for (final dir in packs.listSync().whereType<Directory>()) {
      final meta = File('${dir.path}/manifest.json');
      final bp = File('${dir.path}/world-blueprint.json');
      if (!meta.existsSync() || !bp.existsSync()) continue;
      final slug =
          (jsonDecode(meta.readAsStringSync()) as Map)['slug'] as String;

      test('$packRoot pack "$slug" converts cleanly', () {
        final converter = WorldBlueprintConverter(
          packageName: slug,
          sourceTitle: slug,
          tier0Slugs: blueprintTier0Slugs(),
          contentSlugs: blueprintContentSlugs(),
          knownNames: builtinContentNames(),
          fieldKeys: blueprintFieldKeys(),
          relationTargets: blueprintRelationTargets(),
          mediaResolver: (rel) =>
              File('${dir.path}/$rel').existsSync() ? rel : null,
        );
        final blueprint =
            jsonDecode(bp.readAsStringSync()) as Map<String, dynamic>;
        final result = converter.convert(worldBlueprint: blueprint);

        expect(
          result.issues.map((i) => '$i'),
          isEmpty,
          reason: 'run `dart run tool/content/convert_blueprint.dart --dir '
              '${dir.path} --check` for the full report',
        );
        expectRefsResolve(blueprint, converter, result.entities);
      });
    }
  }
}

/// Blueprint'in `pinned` / `shared` listeleri `kategori/isim` yazılıyor —
/// yazım hatası sessizce hiçbir şeyi pinlemez ya da paylaşmaz, o yüzden
/// burada id'ye çözülüp entity'de aranıyor.
void expectRefsResolve(
  Map<String, dynamic>? blueprint,
  WorldBlueprintConverter converter,
  Map<String, dynamic> entities,
) {
  for (final key in const ['pinned', 'shared']) {
    for (final ref in (blueprint?[key] as List? ?? const [])) {
      final i = (ref as String).indexOf('/');
      expect(i, greaterThan(0), reason: '$key ref must be `slug/name`: $ref');
      expect(
        entities,
        contains(converter.entityId(ref.substring(0, i), ref.substring(i + 1))),
        reason: '$key entity not found: $ref',
      );
    }
  }
}
