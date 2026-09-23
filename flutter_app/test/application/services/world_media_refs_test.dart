// Faz 5d — dünya medyasının iki ucu aynı sha'ları görmeli:
//
//   Paylaşım: yerel yollar → payload'da `dmt-content://{sha}{ext}`
//   Push:     giden satırlar → yüklenecek sha'lar ve sınıfları (`mediaRefsOf`)
//
// Ayrışırlarsa oyuncu hiç yüklenmemiş bir sha'yı ister ve görsel asla gelmez
// — sessizce.
//
//   flutter test test/application/services/world_media_refs_test.dart

import 'dart:convert';

import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/services/cloud_push_service.dart';
import 'package:dungeon_master_tool/application/services/entity_share_prepare.dart';
import 'package:dungeon_master_tool/application/services/world_media_sync.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:dungeon_master_tool/domain/value_objects/media_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const imageKeys = ['gallery', 'sigil'];
  final shaA = 'a' * 64;
  final shaB = 'b' * 64;
  final shaE = 'e' * 64;

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

  String content(String sha, String ext) =>
      AssetRef.formatContentUri(sha, ext);

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

    test('içerik ref\'i taşıyan kartta yerel yol yok', () {
      expect(
        localMediaPathsOf(entityWith(portrait: content(shaA, '.png')), imageKeys),
        isEmpty,
      );
    });

    test('remapEntityMedia orijinal entity\'yi değiştirmez', () {
      final e = entityWith(portrait: '/w/media/a.png');
      remapEntityMedia(e, {'/w/media/a.png': content(shaA, '.png')}, imageKeys);
      expect(e.imagePath, '/w/media/a.png');
    });
  });

  test('paylaşım gövdesindeki her sha, aynı kartın push satırında da var', () {
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
      '/w/media/a.png': content(shaA, '.png'),
      '/w/media/b.jpg': content(shaB, '.jpg'),
      '/w/media/e.webp': content(shaE, '.webp'),
    };
    final payload = jsonEncode(entityToRaw(remapEntityMedia(e, remap, imageKeys)));
    expect(payload, isNot(contains('/w/media/')));

    // Push'un giden satırı: aynı ref'ler, kolonlara dağılmış hâlde.
    final refs = mediaRefsOf([
      CloudPushBatch('world_entities', [
        {
          'image_path': content(shaA, '.png'),
          'images_json': jsonEncode([content(shaB, '.jpg')]),
          'fields_json': jsonEncode({
            'gallery': [content(shaB, '.jpg')],
            'sigil': content(shaE, '.webp'),
            'hp': 12,
          }),
        },
      ]),
    ]);
    for (final sha in [shaA, shaB, shaE]) {
      expect(payload, contains(sha));
      expect(refs, contains(sha));
    }
    expect(refs[shaE], const WorldMediaRef('.webp', MediaKind.worldEntityImage));
  });

  group('mediaRefsOf — sınıf', () {
    test('dünya haritası ve savaş haritası harita, geri kalan "diğer"', () {
      final refs = mediaRefsOf([
        CloudPushBatch('world_map_data', [
          {'data_json': jsonEncode({'image': content(shaA, '.png')})},
        ]),
        CloudPushBatch('world_encounters', [
          {'map_path': content(shaB, '.jpg')},
        ]),
        CloudPushBatch('world_mind_map_nodes', [
          {'image_url': content(shaE, '.png')},
        ]),
      ]);
      expect(refs[shaA]!.kind, MediaKind.battleMap);
      expect(refs[shaB]!.kind, MediaKind.battleMap);
      expect(refs[shaE]!.kind, MediaKind.worldEntityImage);
    });

    test('aynı sha iki yerdeyse büyük limit (harita) kazanır — sıra fark etmez', () {
      for (final order in [false, true]) {
        final batches = [
          CloudPushBatch('world_entities', [
            {'image_path': content(shaA, '.png')},
          ]),
          CloudPushBatch('world_encounters', [
            {'map_path': content(shaA, '.png')},
          ]),
        ];
        final refs = mediaRefsOf(order ? batches.reversed : batches);
        expect(refs[shaA]!.kind, MediaKind.battleMap, reason: 'ters=$order');
      }
    });

    test('PDF ve ses uzantısına göre, tablodan bağımsız', () {
      final refs = mediaRefsOf([
        CloudPushBatch('world_encounters', [
          {'map_path': content(shaA, '.PDF')},
        ]),
        CloudPushBatch('world_settings', [
          {'settings_json': jsonEncode({'track': content(shaB, '.mp3')})},
        ]),
      ]);
      expect(refs[shaA]!.kind, MediaKind.worldPdf);
      expect(refs[shaB]!.kind, MediaKind.worldAudio);
    });

    test('içerik-adresli olmayan ref ve medya olmayan kolon atlanır', () {
      final refs = mediaRefsOf([
        CloudPushBatch('world_entities', [
          {
            'image_path': 'dmt-asset://u/c/${'f' * 64}.png',
            'images_json': jsonEncode([
              'dmt-public://u/${'f' * 64}.png',
              'dmt-art://abc.webp',
              '/local/path.png',
              'dmt-content://short.png',
            ]),
            // Medya kolonu değil: burada geçen ref sayılmaz.
            'description': content(shaA, '.png'),
          },
        ]),
        CloudPushBatch('world_map_pins', [
          {'note': content(shaB, '.png')},
        ]),
      ]);
      expect(refs, isEmpty);
    });
  });
}
