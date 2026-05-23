import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dungeon_master_tool/application/services/content_store.dart';

void main() {
  late Directory tempRoot;
  late ContentStore store;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('content_store_test_');
    store = ContentStore(Directory(p.join(tempRoot.path, 'content')));
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  String shaOf(Uint8List bytes) => sha256.convert(bytes).toString();

  test('write + read roundtrip', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final sha = shaOf(bytes);

    final written = await store.write(
      sha,
      bytes,
      ContentMetadata(
        sha: sha,
        sizeBytes: bytes.length,
        createdAt: DateTime.now(),
        lastAccessAt: DateTime.now(),
        sourceUri: 'dmt-asset://test/key',
        kind: 'entity_image',
      ),
    );
    expect(await written.exists(), isTrue);
    expect(await written.readAsBytes(), bytes);

    final got = await store.read(sha);
    expect(got, isNotNull);
    expect(await got!.readAsBytes(), bytes);

    final meta = await store.metadataFor(sha);
    expect(meta, isNotNull);
    expect(meta!.sourceUri, 'dmt-asset://test/key');
    expect(meta.kind, 'entity_image');
    expect(meta.sizeBytes, 5);
  });

  test('write rejects SHA mismatch', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final wrongSha = 'a' * 64;

    await expectLater(
      store.write(
        wrongSha,
        bytes,
        ContentMetadata(
          sha: wrongSha,
          sizeBytes: bytes.length,
          createdAt: DateTime.now(),
          lastAccessAt: DateTime.now(),
        ),
      ),
      throwsA(isA<ContentStoreException>()),
    );
  });

  test('read miss returns null', () async {
    final sha = shaOf(Uint8List.fromList([9, 9, 9]));
    expect(await store.read(sha), isNull);
    expect(await store.metadataFor(sha), isNull);
  });

  test('delete removes bin + meta', () async {
    final bytes = Uint8List.fromList([7, 8]);
    final sha = shaOf(bytes);
    await store.write(
      sha,
      bytes,
      ContentMetadata(
        sha: sha,
        sizeBytes: bytes.length,
        createdAt: DateTime.now(),
        lastAccessAt: DateTime.now(),
      ),
    );

    await store.delete(sha);
    expect(await store.read(sha), isNull);
    expect(await store.metadataFor(sha), isNull);
  });

  test('legacy migration copies from legacy dir', () async {
    final legacyDir = Directory(p.join(tempRoot.path, 'legacy'));
    await legacyDir.create(recursive: true);

    final bytes = Uint8List.fromList([10, 11, 12, 13]);
    final sha = shaOf(bytes);
    final legacyFile = File(p.join(legacyDir.path, '$sha.bin'));
    await legacyFile.writeAsBytes(bytes);

    final migratingStore = ContentStore(
      Directory(p.join(tempRoot.path, 'content')),
      legacyDirs: [legacyDir],
    );

    final result = await migratingStore.read(sha);
    expect(result, isNotNull);
    expect(await result!.readAsBytes(), bytes);

    final meta = await migratingStore.metadataFor(sha);
    expect(meta, isNotNull);
    expect(meta!.legacyMigrated, isTrue);

    // İkinci okuma yeni store'dan gelmeli (legacy artık irrelevant)
    final result2 = await migratingStore.read(sha);
    expect(result2, isNotNull);
    expect(await result2!.readAsBytes(), bytes);
  });

  test('legacy migration ignores corrupt file', () async {
    final legacyDir = Directory(p.join(tempRoot.path, 'legacy'));
    await legacyDir.create(recursive: true);

    final bytes = Uint8List.fromList([20, 21]);
    final sha = shaOf(bytes);
    // Bozuk içerik (sha eşleşmiyor)
    final legacyFile = File(p.join(legacyDir.path, '$sha.bin'));
    await legacyFile.writeAsBytes(Uint8List.fromList([99, 99]));

    final migratingStore = ContentStore(
      Directory(p.join(tempRoot.path, 'content')),
      legacyDirs: [legacyDir],
    );

    expect(await migratingStore.read(sha), isNull);
  });

  test('totalSizeBytes counts bin files only', () async {
    final a = Uint8List.fromList(List.filled(100, 1));
    final b = Uint8List.fromList(List.filled(200, 2));
    final shaA = shaOf(a);
    final shaB = shaOf(b);

    await store.write(
      shaA,
      a,
      ContentMetadata(
        sha: shaA,
        sizeBytes: a.length,
        createdAt: DateTime.now(),
        lastAccessAt: DateTime.now(),
      ),
    );
    await store.write(
      shaB,
      b,
      ContentMetadata(
        sha: shaB,
        sizeBytes: b.length,
        createdAt: DateTime.now(),
        lastAccessAt: DateTime.now(),
      ),
    );

    expect(await store.totalSizeBytes(), 300);
  });

  test('entries() streams all written items', () async {
    final pairs = <String, Uint8List>{};
    for (var i = 0; i < 3; i++) {
      final b = Uint8List.fromList([i, i + 1, i + 2]);
      final s = shaOf(b);
      pairs[s] = b;
      await store.write(
        s,
        b,
        ContentMetadata(
          sha: s,
          sizeBytes: b.length,
          createdAt: DateTime.now(),
          lastAccessAt: DateTime.now(),
        ),
      );
    }

    final collected = <String>{};
    await for (final e in store.entries()) {
      collected.add(e.sha);
      expect(e.metadata, isNotNull);
    }
    expect(collected, pairs.keys.toSet());
  });

  test('touchAccess updates lastAccessAt', () async {
    final bytes = Uint8List.fromList([30]);
    final sha = shaOf(bytes);
    final past = DateTime.now().subtract(const Duration(days: 1));
    await store.write(
      sha,
      bytes,
      ContentMetadata(
        sha: sha,
        sizeBytes: 1,
        createdAt: past,
        lastAccessAt: past,
      ),
    );

    await store.touchAccess(sha);
    final meta = await store.metadataFor(sha);
    expect(meta!.lastAccessAt.isAfter(past), isTrue);
    expect(meta.createdAt, past);
  });

  test('pruneLegacyDirs removes only listed dirs', () async {
    final legacy = Directory(p.join(tempRoot.path, 'legacy_x'));
    await legacy.create(recursive: true);
    await File(p.join(legacy.path, 'junk.bin')).writeAsString('x');

    final s = ContentStore(
      Directory(p.join(tempRoot.path, 'content2')),
      legacyDirs: [legacy],
    );

    expect(await s.pruneLegacyDirs(), 1);
    expect(await legacy.exists(), isFalse);
  });
}
