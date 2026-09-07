import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dungeon_master_tool/application/services/asset_ref_resolver.dart';
import 'package:dungeon_master_tool/application/services/publish_media_pinner.dart';
import 'package:dungeon_master_tool/data/network/asset_service.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:dungeon_master_tool/domain/value_objects/media_kind.dart';

class _MockAssets extends Mock implements AssetService {}

class _MockResolver extends Mock implements AssetRefResolver {}

/// `isMediaRef` yayının tek karar noktası: yanlış pozitif her metin alanını
/// R2'ye yüklemeye kalkar, yanlış negatif medyayı yayında kırık bırakır.
void main() {
  setUpAll(() {
    registerFallbackValue(AssetRef(''));
    registerFallbackValue(File('x'));
    registerFallbackValue(MediaKind.worldEntityImage);
  });

  // Regresyon: patlayan bir ref'i ikinci kez denemek `pub_asset_reserve` +
  // rollback `pub_asset_release` ciftini tekrarlar, yani evict kuyruguna ayni
  // sha icin ikinci bayat satir atar (migration 090'in temizledigi durum).
  test('ayni ref iki kez gecse de bir kez denenir', () async {
    final assets = _MockAssets();
    final resolver = _MockResolver();
    const raw = r'C:\worlds\w\media\x.png';
    when(() => resolver.resolve(any())).thenAnswer((_) async => File(raw));
    when(() => assets.uploadPub(any(),
            kind: any(named: 'kind'), refKey: any(named: 'refKey')))
        .thenThrow(AssetServiceException('pub_upload_failed_500', ''));

    final res = await PublishMediaPinner(assets, resolver).pin(
      payload: {
        'a': {'image': raw},
        'b': [raw],
      },
      refKey: 'listing-1',
      kind: MediaKind.worldEntityImage,
    );

    verify(() => assets.uploadPub(any(),
        kind: any(named: 'kind'), refKey: any(named: 'refKey'))).called(1);
    expect(res.failures, [raw]);
    expect(res.pinnedCount, 0);
  });

  group('PublishMediaPinner.isMediaRef', () {
    test('pinlenir: local görsel path, public, transient, sayılan cloud', () {
      expect(PublishMediaPinner.isMediaRef('/home/a/media/x.png'), isTrue);
      expect(PublishMediaPinner.isMediaRef(r'C:\worlds\w\media\x.JPG'), isTrue);
      expect(PublishMediaPinner.isMediaRef('dmt-public://u/${'a' * 64}.png'),
          isTrue);
      expect(PublishMediaPinner.isMediaRef('dmt-transient://${'a' * 64}.png'),
          isTrue);
      expect(
          PublishMediaPinner.isMediaRef('dmt-asset://u/w/${'a' * 64}.png'),
          isTrue);
    });

    test('pinlenmez: zaten pub/, first-party art, düz metin', () {
      expect(PublishMediaPinner.isMediaRef('dmt-asset://pub/${'a' * 64}.png'),
          isFalse);
      expect(PublishMediaPinner.isMediaRef('dmt-art://abc.webp'), isFalse);
      expect(PublishMediaPinner.isMediaRef(''), isFalse);
      expect(PublishMediaPinner.isMediaRef('Goblin'), isFalse);
      expect(PublishMediaPinner.isMediaRef('a.png'), isFalse); // ayırıcı yok
      expect(PublishMediaPinner.isMediaRef('notes/readme.txt'), isFalse);
      expect(PublishMediaPinner.isMediaRef('x' * 2000), isFalse);
    });
  });
}
