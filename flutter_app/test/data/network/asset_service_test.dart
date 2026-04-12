import 'package:dungeon_master_tool/data/network/asset_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssetService.extractShaFromKey', () {
    const validSha =
        'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';

    test('extracts sha from standard key', () {
      final key = 'user-uuid/campaign-1/$validSha.png';
      expect(AssetService.extractShaFromKey(key), validSha);
    });

    test('lowercases mixed-case hash', () {
      const mixed =
          'ABC123def456ABC123def456ABC123def456ABC123def456ABC123def456abcd';
      final key = 'u/c/$mixed.jpg';
      expect(AssetService.extractShaFromKey(key), validSha);
    });

    test('accepts key without extension', () {
      final key = 'u/c/$validSha';
      expect(AssetService.extractShaFromKey(key), validSha);
    });

    test('throws on short hash', () {
      expect(
        () => AssetService.extractShaFromKey('u/c/deadbeef.png'),
        throwsA(isA<AssetServiceException>()),
      );
    });

    test('throws on non-hex hash', () {
      const bad =
          'ZZZ123def456abc123def456abc123def456abc123def456abc123def456abcd';
      expect(
        () => AssetService.extractShaFromKey('u/c/$bad.png'),
        throwsA(isA<AssetServiceException>()),
      );
    });

    test('throws on empty key', () {
      expect(
        () => AssetService.extractShaFromKey(''),
        throwsA(isA<AssetServiceException>()),
      );
    });
  });

  group('AssetServiceException', () {
    test('toString contains code and detail', () {
      final e = AssetServiceException('upload_failed', 'boom');
      expect(e.toString(), contains('upload_failed'));
      expect(e.toString(), contains('boom'));
    });
  });

  group('AssetService.maxItemBytes', () {
    test('is 10 MB — synced with cloud_backup_repository_impl', () {
      expect(AssetService.maxItemBytes, 10 * 1024 * 1024);
    });
  });

  group('CommunityAssetRow.fromJson', () {
    test('parses full row', () {
      final row = CommunityAssetRow.fromJson({
        'id': 'asset-uuid',
        'r2_object_key': 'user-uuid/camp/abcdef.png',
        'sha256_hash': 'abcdef',
        'mime_type': 'image/png',
        'size_bytes': 1234,
        'original_filename': 'map.png',
        'campaign_id': 'camp',
      });
      expect(row.id, 'asset-uuid');
      expect(row.r2Key, 'user-uuid/camp/abcdef.png');
      expect(row.sha256, 'abcdef');
      expect(row.mimeType, 'image/png');
      expect(row.sizeBytes, 1234);
      expect(row.originalFilename, 'map.png');
      expect(row.campaignId, 'camp');
    });

    test('handles null optional fields', () {
      final row = CommunityAssetRow.fromJson({
        'id': 'a',
        'r2_object_key': 'k',
        'sha256_hash': 's',
        'mime_type': 'application/octet-stream',
        'size_bytes': 0,
        'original_filename': null,
        'campaign_id': null,
      });
      expect(row.originalFilename, isNull);
      expect(row.campaignId, isNull);
    });

    test('coerces size_bytes from num', () {
      final row = CommunityAssetRow.fromJson({
        'id': 'a',
        'r2_object_key': 'k',
        'sha256_hash': 's',
        'mime_type': 'image/png',
        'size_bytes': 9.0,
        'original_filename': null,
        'campaign_id': null,
      });
      expect(row.sizeBytes, 9);
    });
  });
}
