// The bundled-world → official-catalog contract, checked against the real
// `assets/worlds/` tree and the manifest `build_catalog.dart` emits.
//
// This is the gate on the parts that are silent when they break: an adventure
// PDF accidentally uploaded to our bucket (it is `all-rights-reserved`), a
// media path in the manifest with no file behind it, or a world entry the app
// parses into an empty download.
import 'dart:convert';
import 'dart:io';

import 'package:dungeon_master_tool/domain/entities/catalog/catalog_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/catalog_publish/world_payload.dart';

const _worldDir = 'assets/worlds/99_devils_of_uzrahs_palace_shadowdark';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('worldMediaPaths', () {
    test('collects every media leaf and drops the PDF + its publisher link',
        () {
      final files = _json('$_worldDir/manifest.json')['files'] as Map;
      final paths = worldMediaPaths(files);

      // 1 cover + 3 maps + 6 handouts + 34 tokens + 31 gcs
      expect(paths, hasLength(75));
      expect(paths, contains('media/Title-Image.webp'));
      expect(paths, contains('media/GURPS GCS Characters/Cobra.gcs'));

      // The PDF is licensed all-rights-reserved: never an R2 object.
      expect(paths.where((p) => p.toLowerCase().endsWith('.pdf')), isEmpty);
      // `pdf_url` is a download link, not a path — treating it as media would
      // report "file not found" on every install.
      expect(paths.any((p) => p.startsWith('http')), isFalse);
    });

    test('every collected path exists on disk', () {
      final files = _json('$_worldDir/manifest.json')['files'] as Map;
      for (final rel in worldMediaPaths(files)) {
        expect(File('$_worldDir/$rel').existsSync(), isTrue,
            reason: 'missing media file: $rel');
      }
    });
  });

  group('buildWorldEnvelope', () {
    test('carries the manifest and both blueprints', () {
      final envelope = buildWorldEnvelope(_worldDir);
      expect(envelope.keys,
          containsAll(['manifest', 'world_blueprint', 'character_blueprint']));
      expect((envelope['manifest'] as Map)['slug'],
          '99-devils-of-uzrahs-palace-shadowdark');
    });

    test('encodes to gzip that round-trips', () {
      final bytes = encodeWorldEnvelope(buildWorldEnvelope(_worldDir));
      final back = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map;
      expect((back['manifest'] as Map)['title'], "99 Devils of Uzrah's Palace");
    });

    test('throws rather than publishing a world with no manifest', () {
      expect(() => buildWorldEnvelope('assets/worlds'), throwsStateError);
    });
  });

  group('CatalogEntry', () {
    late CatalogEntry world;

    setUp(() {
      final entries =
          _json('assets/first_party/manifest.json')['entries'] as List;
      world = entries
          .cast<Map>()
          .map((m) => CatalogEntry.fromJson(m.cast<String, dynamic>()))
          .firstWhere((e) => e.itemType == 'world');
    });

    test('parses the world-only fields the store card needs', () {
      expect(world.slug, '99-devils-of-uzrahs-palace-shadowdark');
      expect(world.description, isNotEmpty);
      expect(world.author, isNotEmpty);
      expect(world.sourceUrl, startsWith('https://'));
      expect(world.bundledDir, _worldDir);
      expect(world.coverImage, 'media/Title-Image.webp');
      expect(world.r2Path, endsWith('.json.gz'));
    });

    test('media keys are versioned and cover every file', () {
      expect(world.media, hasLength(75));
      for (final m in world.media) {
        expect(m.r2Key,
            'world-media/${world.slug}@${world.version}/${m.rel}');
        expect(m.sizeBytes, greaterThan(0));
      }
    });

    test('the PDF is an external link, not a hosted object', () {
      expect(world.media.any((m) => m.rel.endsWith('.pdf')), isFalse);
      expect(world.externalFiles, hasLength(1));
      expect(world.externalFiles.single.rel, endsWith('.pdf'));
      expect(world.externalFiles.single.url, startsWith('https://'));
    });

    test('the cover image resolves to a real media object', () {
      // `officialCoverUrl` looks the cover up in `media` by `rel`. If the two
      // ever disagree the card silently falls back to `banners/<slug>.jpg`,
      // which no world has — a 404 that renders as a blank card, not an error.
      expect(world.coverImage, isNotEmpty);
      expect(
        world.media.map((m) => m.rel),
        contains(world.coverImage),
        reason: 'cover_image must name one of the uploaded media objects',
      );
    });

    test('downloadBytes counts payload + media but not the external PDF', () {
      final mediaTotal =
          world.media.fold<int>(0, (a, m) => a + m.sizeBytes);
      expect(world.downloadBytes, world.sizeBytes + mediaTotal);
      // The 46 MB PDF is excluded, so the total stays well under it.
      expect(world.downloadBytes, lessThan(46 * 1024 * 1024));
    });

    test('every published world links its PDF, and the campaign card '
        'repeats that exact link', () {
      // The app no longer downloads the adventure PDF at all — the ONLY way a
      // user reaches it is these two links. If either side drifts (a world
      // with no `pdf_url`, or a campaign page pointing somewhere else) the
      // world installs "successfully" with its adventure text unreachable,
      // and nothing fails loudly. Army of the Damned shipped exactly that way.
      final entries =
          (_json('assets/first_party/manifest.json')['entries'] as List)
              .cast<Map>()
              .map((m) => CatalogEntry.fromJson(m.cast<String, dynamic>()))
              .where((e) => e.itemType == 'world');
      expect(entries, isNotEmpty);

      for (final w in entries) {
        expect(w.externalFiles, hasLength(1), reason: '${w.slug}: no PDF link');
        final url = w.externalFiles.single.url;
        expect(url, startsWith('https://'), reason: w.slug);

        final campaign = ((_json('${w.bundledDir}/world-blueprint.json')
            ['categories'] as Map)['campaign'] as List).single as Map;
        final pages =
            ((campaign['mapping'] as Map)['pages'] as List).cast<String>();
        expect(
          pages.any((p) => p.contains(url)),
          isTrue,
          reason: '${w.slug}: campaign card does not carry $url',
        );
      }
    });

    test('package entries are unaffected by the new fields', () {
      final entries =
          _json('assets/first_party/manifest.json')['entries'] as List;
      final pkg = entries
          .cast<Map>()
          .map((m) => CatalogEntry.fromJson(m.cast<String, dynamic>()))
          .firstWhere((e) => e.itemType == 'package');
      expect(pkg.media, isEmpty);
      expect(pkg.externalFiles, isEmpty);
      expect(pkg.bundledDir, isEmpty);
      expect(pkg.downloadBytes, pkg.sizeBytes);
    });
  });
}
