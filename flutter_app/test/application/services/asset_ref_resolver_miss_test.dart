// Faz 9 — görsel gelmediğinde kullanıcıya söylenen neden. Üç nedenin
// karışması ("bulutta yok"u ağ hatası diye göstermek ya da tersi) kullanıcıyı
// yanlış yere baktırır.
//
//   cd flutter_app && flutter test test/application/services/asset_ref_resolver_miss_test.dart

import 'package:dungeon_master_tool/application/services/asset_ref_resolver.dart';
import 'package:dungeon_master_tool/application/services/content_ref_index.dart';
import 'package:dungeon_master_tool/application/services/content_store.dart';
import 'package:dungeon_master_tool/data/network/asset_service.dart';
import 'package:dungeon_master_tool/data/services/first_party_art_service.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Assets extends Mock implements AssetService {}

class _Store extends Mock implements ContentStore {}

class _Index extends Mock implements ContentRefIndex {}

class _Art extends Mock implements FirstPartyArtService {}

void main() {
  const sha =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final content = AssetRef('dmt-content://$sha.png');
  late _Assets assets;
  late AssetRefResolver resolver;

  setUp(() {
    assets = _Assets();
    final store = _Store();
    final index = _Index();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => index.fileForSha(any())).thenAnswer((_) async => null);
    resolver = AssetRefResolver(assets, null, store, _Art(), index);
  });

  test('yerel yol diskte yok → bu cihazda yok', () async {
    final ref = AssetRef('/nope/does-not-exist.png');
    expect(await resolver.resolve(ref), isNull);
    expect(resolver.missOf(ref), AssetMiss.notOnDevice);
  });

  test('imza sha için url vermedi → bulutta yok', () async {
    when(() => assets.signWorldMedia('get', any()))
        .thenAnswer((_) async => const {});
    expect(await resolver.resolve(content), isNull);
    expect(resolver.missOf(content), AssetMiss.notInCloud);
  });

  test('imza isteği hata verdi → indirilemedi', () async {
    when(() => assets.signWorldMedia('get', any()))
        .thenThrow(Exception('offline'));
    expect(await resolver.resolve(content), isNull);
    expect(resolver.missOf(content), AssetMiss.downloadFailed);
  });

  test('indirme hata verdi → indirilemedi', () async {
    when(() => assets.signWorldMedia('get', any()))
        .thenAnswer((_) async => {sha: 'https://r2/x'});
    when(() => assets.downloadSigned(any(), any(), any()))
        .thenThrow(Exception('reset'));
    expect(await resolver.resolve(content), isNull);
    expect(resolver.missOf(content), AssetMiss.downloadFailed);
  });
}
