import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/data/services/first_party_art_service.dart';
import 'package:dungeon_master_tool/data/services/first_party_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Zip'i bellekten servis eden sahte catalog — worker'a çıkmadan
/// `prefetchBundle`'ın indir/aç yolunu sınar.
class _FakeCatalog extends FirstPartyCatalogService {
  _FakeCatalog(this.bytes);
  final Uint8List? bytes;
  var calls = 0;

  @override
  Future<bool> downloadCatalogTo(String r2Key, File dest) async {
    calls++;
    if (bytes == null) return false;
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes!, flush: true);
    return true;
  }
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('art_bundle_test');
    AppPaths.cacheDir = p.join(tmp.path, 'cache');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Uint8List zipOf(Map<String, List<int>> files) {
    final a = Archive();
    files.forEach((n, b) => a.addFile(ArchiveFile(n, b.length, b)));
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  test('zip bundle tek istekte açılır ve cache dizinine yazılır', () async {
    final catalog = _FakeCatalog(zipOf({
      'a.webp': [1, 2, 3],
      'b.webp': [4, 5],
      '../evil.webp': [9], // path guard: yazılmamalı
    }));
    final svc = FirstPartyArtService(catalog);

    final ok = await svc.prefetchBundle(
        'art-bundle/x@1.0.0.zip', ['a.webp', 'b.webp']);

    expect(ok, 2);
    expect(catalog.calls, 1, reason: 'görsel başına istek atılmamalı');
    expect(File(p.join(AppPaths.cacheDir, 'art', 'a.webp')).readAsBytesSync(),
        [1, 2, 3]);
    expect(File(p.join(tmp.path, 'evil.webp')).existsSync(), isFalse);
    expect(Directory(p.join(AppPaths.cacheDir, 'art'))
        .listSync()
        .where((e) => e.path.endsWith('.zip')), isEmpty,
        reason: 'geçici arşiv silinmeli');
  });

  test('zip inmezse görsel yazılmaz ve kurulum düşmez', () async {
    final catalog = _FakeCatalog(null);
    final svc = FirstPartyArtService(catalog);

    final ok = await svc.prefetchBundle('art-bundle/x@1.0.0.zip', ['a.webp']);

    expect(ok, 0);
    expect(catalog.calls, 1, reason: 'görsel başına yedek istek atılmamalı');
  });
}
