import 'dart:io';

import 'package:dungeon_master_tool/data/services/asset_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late String campaign;
  late String source;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('asset_importer_test');
    campaign = p.join(tmp.path, 'world');
    source = p.join(tmp.path, 'src');
    await Directory(source).create(recursive: true);
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<String> writeSource(String name, String content) async {
    final f = File(p.join(source, name));
    await f.writeAsString(content);
    return f.path;
  }

  String pdfDir() => p.join(campaign, AssetImporter.pdfSubDir);

  Future<List<String>> listPdfDir() async {
    final dir = Directory(pdfDir());
    if (!await dir.exists()) return [];
    return (await dir.list().toList()).map((e) => p.basename(e.path)).toList()
      ..sort();
  }

  test('kopyayı world klasörüne orijinal adıyla koyar', () async {
    final src = await writeSource('Rulebook.pdf', 'hello');

    final out = await AssetImporter.importFiles(campaign, [src]);

    expect(out, [p.join(pdfDir(), 'Rulebook.pdf')]);
    expect(await File(out.first).readAsString(), 'hello');
  });

  test('aynı dosyayı iki kez import etmek tek kopya bırakır', () async {
    final src = await writeSource('Rulebook.pdf', 'hello');

    final first = await AssetImporter.importFiles(campaign, [src]);
    final second = await AssetImporter.importFiles(campaign, [src]);

    expect(second, first);
    expect(await listPdfDir(), ['Rulebook.pdf']);
  });

  test('aynı ad + farklı boyut ikinci kopya üretir', () async {
    final a = await writeSource('Rulebook.pdf', 'hello');
    await AssetImporter.importFiles(campaign, [a]);

    final b = await writeSource('Rulebook.pdf', 'a much longer body');
    final out = await AssetImporter.importFiles(campaign, [b]);

    expect(p.basename(out.first), 'Rulebook (2).pdf');
    expect(await listPdfDir(), ['Rulebook (2).pdf', 'Rulebook.pdf']);
  });

  test('zaten hedef klasördeki dosya kopyalanmaz', () async {
    final src = await writeSource('Rulebook.pdf', 'hello');
    final imported = (await AssetImporter.importFiles(campaign, [src])).first;

    final again = await AssetImporter.importFiles(campaign, [imported]);

    expect(again, [imported]);
    expect(await listPdfDir(), ['Rulebook.pdf']);
  });

  test('var olmayan kaynak atlanır', () async {
    final out = await AssetImporter.importFiles(
      campaign,
      [p.join(source, 'yok.pdf')],
    );

    expect(out, isEmpty);
  });

  test('importOne mevcut kopyanın yolunu döndürür', () async {
    final src = await writeSource('Rulebook.pdf', 'hello');
    await AssetImporter.importFiles(campaign, [src]);

    final reused = await AssetImporter.importOne(
      campaign,
      AssetImporter.pdfSubDir,
      src,
    );

    expect(reused, p.join(pdfDir(), 'Rulebook.pdf'));
    expect(await listPdfDir(), ['Rulebook.pdf']);
  });
}
