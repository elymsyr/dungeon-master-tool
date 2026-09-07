import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validSha =
      'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';

  group('AssetRef', () {
    test('cloud URI parses to r2Key and round-trips via formatCloudUri', () {
      const key = 'user-uuid/world-1/$validSha.png';
      final ref = AssetRef(AssetRef.formatCloudUri(key));
      expect(ref.isCloud, isTrue);
      expect(ref.isLocal, isFalse);
      expect(ref.r2Key, key);
      expect(ref.localPath, isNull);
      expect(ref.raw, 'dmt-asset://$key');
    });

    test('local absolute path is recognised as local ref', () {
      const path = '/home/user/.dmt/worlds/testlands/media/portrait.png';
      final ref = AssetRef(path);
      expect(ref.isLocal, isTrue);
      expect(ref.isCloud, isFalse);
      expect(ref.localPath, path);
      expect(ref.r2Key, isNull);
    });

    test('empty ref is neither local nor cloud', () {
      final ref = AssetRef('');
      expect(ref.isLocal, isFalse);
      expect(ref.isCloud, isFalse);
    });

    test('equality is by raw string', () {
      expect(AssetRef('/a/b'), equals(AssetRef('/a/b')));
      expect(AssetRef('/a/b'), isNot(equals(AssetRef('/a/c'))));
    });

    test('first-party art ref parses and is NOT treated as a local path', () {
      const uuid = '1fbea976-fb6a-524f-b0f7-d7202406dc52';
      final ref = AssetRef(AssetRef.formatArtUri(uuid));
      expect(ref.raw, 'dmt-art://$uuid.webp');
      expect(ref.isArt, isTrue);
      expect(ref.artName, '$uuid.webp');
      // Bir art ref'i local sayılırsa resolver onu File(path) diye açmaya
      // çalışır ve kart sessizce görselsiz kalır — bundle da R2 da denenmez.
      expect(ref.isLocal, isFalse);
      expect(ref.isCloud, isFalse);
      expect(ref.localPath, isNull);
      // Dosya adı sha değil uuid — content store'a sorulmamalı.
      expect(ref.contentSha, isNull);
    });

    test('formatCloudUri prepends the canonical scheme', () {
      expect(
        AssetRef.formatCloudUri('u/c/$validSha.jpg'),
        'dmt-asset://u/c/$validSha.jpg',
      );
    });
  });
}
