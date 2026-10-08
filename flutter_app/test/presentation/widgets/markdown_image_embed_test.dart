// `@resim` ile eklenen `![alt](dmt-img:… "50%")` parçası markdown parser'ından
// geçince ref'i ve genişliği bozulmadan geri vermeli (Windows yolu, boşluk,
// parantez, #); render'da resim satırı tek başına kaplamalı.
//
//   cd flutter_app && flutter test test/presentation/widgets/markdown_image_embed_test.dart

import 'dart:io';

import 'package:dungeon_master_tool/application/services/asset_ref_resolver.dart';
import 'package:dungeon_master_tool/application/services/mention_text.dart';
import 'package:dungeon_master_tool/core/config/app_paths.dart';
import 'package:dungeon_master_tool/domain/value_objects/asset_ref.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/widgets/markdown_text_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoFileResolver extends Fake implements AssetRefResolver {
  @override
  Future<File?> resolve(AssetRef ref) async => null;
  @override
  AssetMiss? missOf(AssetRef ref) => null;
}

void main() {
  for (final ref in [
    r'C:\Users\a b\media\harita (eski) #2.png',
    '/home/x/worlds/w1/media/ok.webp',
    'dmt-content://abc123.png',
  ]) {
    testWidgets('round-trip: $ref', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MarkdownBody(
          data: 'önce ${markdownImage(ref, 'Kart [x]', width: 40)} sonra',
          imageBuilder: (uri, title, alt) => Text(
              '${decodeMarkdownImageRef(uri.toString().substring(markdownImageScheme.length))}'
              '|${markdownImageWidth(title)}'),
        ),
      ));
      expect(find.text('$ref|40'), findsOneWidget);
    });
  }

  test('split/join: metin ve resim blokları, ayraçlar korunur', () {
    final i1 = markdownImage('/a.png', 'A');
    final i2 = markdownImage('/b.png', 'B', width: 40);
    for (final text in [
      'giriş\n$i1\nson',
      '$i1\n$i2',
      'a\n\n$i1',
      '$i1\nb',
      'yalnız metin',
      '',
    ]) {
      expect(joinMarkdownImages(splitMarkdownImages(text)), text, reason: text);
    }
    final segs = splitMarkdownImages('x\n$i1\n$i2\ny');
    expect(segs.length, 5);
    expect(segs.whereType<String>(), ['x', '', 'y']);
    expect((segs[3] as MarkdownImageBlock).width, 40);
  });

  testWidgets('aynı satırdaki yazı resmin altına geçer', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [assetRefResolverProvider.overrideWithValue(_NoFileResolver())],
      child: MaterialApp(
        home: Scaffold(
          body: MarkdownTextArea(
            controller: TextEditingController(
                text: 'önce ${markdownImage('/x.png', 'X', width: 50)} sonra'),
            readOnly: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final image = tester.getRect(find.byType(MarkdownEmbeddedImage));
    final after = tester.getRect(find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('sonra')));
    expect(image.width, tester.getSize(find.byType(MarkdownBody)).width);
    expect(after.top, greaterThanOrEqualTo(image.bottom));
  });

  testWidgets('edit modda resim blok olarak görünür: yaz, boyutla, sil',
      (tester) async {
    final img = markdownImage('/x.png', 'X');
    final c = TextEditingController(text: 'a\n$img\nb');
    final changes = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [assetRefResolverProvider.overrideWithValue(_NoFileResolver())],
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: MarkdownTextArea(
              controller: c, maxLines: 5, onChanged: changes.add),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(MarkdownEmbeddedImage), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).last, 'bc');
    expect(c.text, 'a\n$img\nbc');

    // Sürüklerken yalnız resim değişir; metin bırakınca bir kez yazılır.
    final saved = changes.length;
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Slider)));
    await gesture.moveBy(const Offset(-2000, 0));
    await tester.pump();
    expect(find.text('10%'), findsOneWidget);
    expect(c.text, 'a\n$img\nbc');
    expect(changes.length, saved);
    await gesture.up();
    await tester.pump();
    expect(c.text, 'a\n${markdownImage('/x.png', 'X', width: 10)}\nbc');
    expect(changes.length, saved + 1);
    expect(changes.last, c.text);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(c.text, 'a\nbc');
    expect(find.byType(MarkdownEmbeddedImage), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  // entityProvider zinciri DB açıyor: boş bir dataRoot yeterli.
  setUpAll(() async {
    AppPaths.dataRoot =
        (await Directory.systemTemp.createTemp('md_image_kw')).path;
    await AppPaths.setUser(null);
  });

  for (final (locale, typed, label) in [
    (const Locale('tr'), '@image', 'Resim ekle'),
    (const Locale('en'), '@resim', 'Add image'),
    (const Locale('de'), '@res', 'Bild hinzufügen'),
  ]) {
    testWidgets('$typed (${locale.languageCode}) → $label', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: MarkdownTextArea(controller: TextEditingController()),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), typed);
      await tester.pump();
      expect(find.text(label), findsOneWidget);
    });
  }
}
