// Bundled pack → PackagePayloadImporter → Drift → load() round-trip.
//
// `bundled_pack_resolve_test` (M1) ve `wizard_pack_families_test` (U2) paket
// JSON'unu **doğrudan** okur; kurulum yolunu hiç kullanmazlar. Bu dosya aradaki
// katmanı kapatır: gerçek importer gerçek bir Drift DB'sine yazar, sonra
// `PackageRepository.load` ile geri okunur. Sütunlara ayrılıp yeniden birleşen
// alanların kaybolması, tanınmayan bir kategori slug'ı ya da metadata/link
// düşmesi burada patlar.
//
//   cd flutter_app && flutter test test/application/services/pack_install_roundtrip_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/application/services/package_payload_importer.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/data/repositories/package_repository_impl.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Legacy anahtarları olan bir kart importer'da dönüştürülür, o yüzden
/// attributes birebir karşılaştırılmaz.
const _legacyKeys = {'rule_effects', 'granted_modifiers'};

void main() {
  final packFiles = Directory('assets/open5e_packs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final knownSlugs = {
    for (final c in generateBuiltinDnd5eV2Schema().schema.categories) c.slug,
  };

  test('there are packs to test', () => expect(packFiles, isNotEmpty));

  late AppDatabase db;
  late PackagePayloadImporter importer;
  late PackageRepositoryImpl repo;

  setUp(() {
    db = openTestDatabase();
    repo = PackageRepositoryImpl(db);
    importer = PackagePayloadImporter(repo);
  });

  tearDown(() async => db.close());

  for (final file in packFiles) {
    final slug = file.uri.pathSegments.last.replaceAll('.pkg.json', '');

    test('$slug installs and reads back unchanged', () async {
      final payload =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final entities = (payload['entities'] as Map).cast<String, dynamic>();

      final name = await importer.install(
        payload,
        installedFrom: 'official',
        extraMetadata: {'catalog_version': '9.9.9'},
      );
      final loaded = await repo.load(name);

      final back = (loaded['entities'] as Map).cast<String, dynamic>();
      expect(back.keys.toSet(), entities.keys.toSet(),
          reason: '$slug: kurulumda kart kayboldu ya da eklendi');

      for (final id in entities.keys) {
        final src = (entities[id] as Map).cast<String, dynamic>();
        final got = (back[id] as Map).cast<String, dynamic>();
        expect(got['name'], src['name'], reason: '$slug/$id name');
        expect(got['type'], src['type'], reason: '$slug/$id type');
        expect(knownSlugs, contains(src['type']),
            reason: '$slug/$id: şemada olmayan kategori — uygulama render '
                'edemez');

        final srcAttrs =
            (src['attributes'] as Map?)?.cast<String, dynamic>() ?? const {};
        final gotAttrs =
            (got['attributes'] as Map?)?.cast<String, dynamic>() ?? const {};
        if (srcAttrs.keys.any(_legacyKeys.contains)) {
          // Dönüştürülüyor — sadece boşa düşmediğini doğrula.
          expect(gotAttrs, isNotEmpty, reason: '$slug/$id legacy migration');
        } else {
          expect(gotAttrs, srcAttrs, reason: '$slug/$id attributes');
        }
      }

      final meta = (loaded['metadata'] as Map).cast<String, dynamic>();
      expect(meta['installed_from'], 'official');
      expect(meta['catalog_version'], '9.9.9');
      expect(meta['pack_version'],
          (payload['metadata'] as Map)['pack_version'],
          reason: '$slug: kaynak metadata düştü');
    });
  }

  test('re-installing the same pack is idempotent', () async {
    final payload = jsonDecode(packFiles.first.readAsStringSync())
        as Map<String, dynamic>;
    final name =
        await importer.install(payload, installedFrom: 'official');
    final first = await repo.load(name);
    await importer.install(payload, installedFrom: 'official');
    final second = await repo.load(name);

    expect((second['entities'] as Map).length,
        (first['entities'] as Map).length);
    expect(await repo.getAvailable(), contains(name));
  });
}
