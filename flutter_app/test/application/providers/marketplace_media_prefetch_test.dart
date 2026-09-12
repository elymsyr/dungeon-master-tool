import 'package:dungeon_master_tool/application/providers/marketplace_listing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// İndirilen bir listing'in medyası artık kurulum anında çekiliyor; onu besleyen
/// gezgin budur. Ref payload'da anahtar adına göre değil değerin kendisine göre
/// bulunur, çünkü payload şekli world/package/character arasında değişiyor.
void main() {
  test('finds cloud + public refs at any depth, deduplicated', () {
    final refs = remoteMediaRefs({
      'cover': 'dmt-asset://pub/aaa.png',
      'entities': {
        'e1': {'image_path': 'dmt-asset://pub/bbb.webp'},
        'e2': {
          'gallery': [
            'dmt-public://free/ccc.jpg',
            'dmt-asset://pub/aaa.png', // tekrar — bir kez sayılmalı
          ],
        },
      },
    });

    expect(refs.toSet(), {
      'dmt-asset://pub/aaa.png',
      'dmt-asset://pub/bbb.webp',
      'dmt-public://free/ccc.jpg',
    });
  });

  test('skips local paths, art and transient refs', () {
    // Local: indirende zaten kırık. Art: paket zip'iyle geliyor.
    // Transient: LRU'ya tabi, yayına giremez.
    final refs = remoteMediaRefs({
      'a': '/home/eren/Pictures/map.png',
      'b': r'C:\maps\keep.jpg',
      'c': 'dmt-art://2f3c.webp',
      'd': 'dmt-transient://abc.png',
      'e': 'Goblin',
      'f': '',
      'g': 42,
      'h': null,
    });

    expect(refs, isEmpty);
  });
}
