import 'dart:convert';

import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/services/missing_media_reporter.dart';
import 'package:dungeon_master_tool/application/services/shared_media_courier.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// Talep-üzerine medya akışının iki ucu tek testte:
///
///   DM: yerel yollar → payload'da `dmt-content://{sha}{ext}`
///   Oyuncu: payload → eksik SHA listesi
///
/// Bu ikisi ayrışırsa oyuncu ya hiç bildiremez (resim asla gelmez) ya da
/// olmayan bir SHA ister (DM boşuna tarar) — ikisi de sessiz.
void main() {
  const imageKeys = ['gallery', 'sigil'];

  Entity entityWith({
    required String portrait,
    List<String> images = const [],
    Map<String, dynamic> fields = const {},
  }) =>
      Entity(
        id: 'e1',
        name: 'Kara Şövalye',
        categorySlug: 'npc',
        imagePath: portrait,
        images: images,
        fields: fields,
      );

  group('localMediaPathsOf', () {
    test('portre + galeri + image alanlarındaki yerel yolları toplar', () {
      final e = entityWith(
        portrait: '/w/media/a.png',
        images: const ['/w/media/b.png', 'dmt-asset://x/c.png'],
        fields: const {
          'gallery': ['/w/media/d.png', '/w/media/b.png'],
          'sigil': '/w/media/e.png',
          'hp': 12,
        },
      );
      expect(
        localMediaPathsOf(e, imageKeys),
        ['/w/media/a.png', '/w/media/b.png', '/w/media/d.png', '/w/media/e.png'],
      );
    });

    test('bulut ref taşıyan kartta yerel yol yok', () {
      for (final ref in [
        'dmt-transient://${'a' * 64}.png',
        'dmt-content://${'a' * 64}.png',
      ]) {
        expect(localMediaPathsOf(entityWith(portrait: ref), imageKeys), isEmpty);
      }
    });
  });

  group('remapEntityMedia → collectContentRefs', () {
    test('paylaşım gövdesindeki her yerel yol tam olarak bir SHA olur', () {
      final shaA = 'a' * 64;
      final shaB = 'b' * 64;
      final shaE = 'e' * 64;
      final e = entityWith(
        portrait: '/w/media/a.png',
        images: const ['/w/media/b.jpg'],
        fields: const {
          'gallery': ['/w/media/b.jpg'],
          'sigil': '/w/media/e.webp',
          'hp': 12,
        },
      );
      final remap = {
        '/w/media/a.png': AssetRef.formatContentUri(shaA, '.png'),
        '/w/media/b.jpg': AssetRef.formatContentUri(shaB, '.jpg'),
        '/w/media/e.webp': AssetRef.formatContentUri(shaE, '.webp'),
      };

      // DM tarafı: kopya üzerinde remap, sonra gerçek yol (JSON kolonu).
      final remapped = remapEntityMedia(e, remap, imageKeys);
      final payload =
          jsonDecode(jsonEncode(entityToRaw(remapped))) as Map<String, dynamic>;

      // Oyuncu tarafı: gövdeyi tara.
      final found = collectContentRefs({'e1': payload});

      expect(found.keys.toSet(), {shaA, shaB, shaE});
      expect(found[shaA], 'dmt-content://$shaA.png');
      expect(found[shaE], 'dmt-content://$shaE.webp');
      // Yerel yollardan hiçbiri gövdede kalmadı.
      expect(jsonEncode(payload), isNot(contains('/w/media/')));
    });

    test('remapEntityMedia orijinal entity\'yi değiştirmez', () {
      final e = entityWith(portrait: '/w/media/a.png');
      remapEntityMedia(
        e,
        {'/w/media/a.png': AssetRef.formatContentUri('c' * 64, '.png')},
        imageKeys,
      );
      expect(e.imagePath, '/w/media/a.png');
    });

    test('içerik-adresli olmayan ref\'ler eksik listesine girmez', () {
      final found = collectContentRefs({
        'p': 'dmt-asset://u/c/${'f' * 64}.png',
        'q': 'dmt-public://u/${'f' * 64}.png',
        'r': 'dmt-art://abc.webp',
        's': '/local/path.png',
        't': 'dmt-content://short.png',
      });
      expect(found, isEmpty);
    });

    test('Faz 3.5 öncesi dmt-transient:// gövdeleri hâlâ taranıyor', () {
      final sha = 'd' * 64;
      final found = collectContentRefs({'old': 'dmt-transient://$sha.png'});
      expect(found[sha], 'dmt-transient://$sha.png');
    });
  });
}
