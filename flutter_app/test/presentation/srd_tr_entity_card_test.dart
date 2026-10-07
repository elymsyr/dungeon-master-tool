import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/content_translator_provider.dart';
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/application/providers/locale_provider.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/database/entity_card.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

/// Dil ayarını diske yazmadan değiştirir (gerçek `setLocale` bir kayıt
/// zamanlayıcısı kurar).
class _TestLocale extends LocaleNotifier {
  _TestLocale(super.ref) {
    state = const Locale('tr');
  }
  void set(String code) => state = Locale(code);
}

/// **SRD TR Faz 4.7 — koruma testleri.** Gerçek dünya (in-memory DB, SRD
/// kartları), gerçek çeviri tabloları (`assets/srd_l10n/tr`), gerçek
/// [EntityCard]: Türkçede okuma modu Türkçe görünür, düzenleme modu
/// İngilizce gösterir, kaydedilen her şey İngilizce kalır (K3).
void main() {
  testWidgets('SRD kartı TR okuma modunda Türkçe, düzenleme ve kayıt İngilizce',
      (tester) async {
    // Kart tembel bir ListView — tüm alanlar ekranda kurulsun.
    tester.view
      ..physicalSize = const Size(1600, 3200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = openTestDatabase();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      localeProvider.overrideWith(_TestLocale.new),
    ]);

    Future<void> waitTranslator(bool loaded) => tester.runAsync(() async {
          for (var i = 0;
              i < 400 &&
                  container.read(contentTranslatorProvider).isIdentity ==
                      loaded;
              i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });

    await tester.runAsync(() async {
      final worldId = await container
          .read(campaignRepositoryProvider)
          .create('W', template: generateBuiltinDnd5eV2Schema().schema);
      await container.read(activeCampaignProvider.notifier).load(worldId);
      // Yükleyici gerçek asset IO'su yapar — test saatinin dışında başlasın.
      container.listen(contentTranslatorProvider, (_, _) {});
    });
    await waitTranslator(true);
    expect(container.read(contentTranslatorProvider).isIdentity, isFalse);

    final skill = container.read(entityProvider).values.firstWhere(
        (e) => e.categorySlug == 'skill' && e.name == 'Animal Handling');
    expect(skill.fields['summary'], 'Calm or train animals.');
    // Açıklama yolunu da gerçek tabloyla sınamak için: aynı scope'ta
    // çevirisi olan bir metin.
    container
        .read(entityProvider.notifier)
        .update(skill.copyWith(description: 'Calm or train animals.'));
    // SRD kartını düzenlemek ev yapımı bir kopya üretir (fork-on-edit);
    // kopya aynı İngilizce metni taşır, çeviri onda da çalışır.
    final copy = container.read(entityProvider).values.firstWhere((e) =>
        e.categorySlug == 'skill' &&
        e.description == 'Calm or train animals.');
    expect(copy.linked, isFalse);
    final poisoned = container.read(entityProvider).values.firstWhere(
        (e) => e.categorySlug == 'condition' && e.name == 'Poisoned');

    Widget card({required bool readOnly, String? id}) =>
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildThemeData('dark'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: Scaffold(
              body: EntityCard(
                entityId: id ?? copy.id,
                readOnly: readOnly,
              ),
            ),
          ),
        );
    const trDesc = 'Hayvanları sakinleştir ya da eğit.';

    // SRD'nin kendi (pakete bağlı) Poisoned kartı.
    await tester.pumpWidget(card(readOnly: true, id: poisoned.id));
    await tester.pump();
    expect(find.text('Zehirlenme'), findsOneWidget);
    expect(find.text('Poisoned'), findsNothing);

    // Okuma modu: ad, açıklama ve metin alanı Türkçe.
    await tester.pumpWidget(card(readOnly: true));
    await tester.pump();
    expect(find.text('Hayvan İdaresi'), findsOneWidget);
    expect(find.text('Animal Handling'), findsNothing);
    expect(find.text(trDesc, findRichText: true), findsNWidgets(2));

    // Düzenleme modu: değerler orijinal İngilizce.
    await tester.pumpWidget(card(readOnly: false));
    await tester.pump();
    expect(find.text('Hayvan İdaresi'), findsNothing);
    expect(find.text(trDesc, findRichText: true), findsNothing);
    expect(find.text('Animal Handling'), findsOneWidget);

    // Okuma ↔ düzenleme geçişi hiçbir şey yazmadı.
    expect(identical(container.read(entityProvider)[copy.id], copy), isTrue);

    // K3: düzenleme modunda yazılan kaydedilir; çevrilmiş metin hiçbir
    // yoldan veriye geçmez.
    await tester.enterText(find.text('Animal Handling'), 'Animal Handling!');
    await tester.pump(const Duration(milliseconds: 400)); // kayıt gecikmesi
    final saved = container.read(entityProvider)[copy.id]!;
    expect(saved.name, 'Animal Handling!');
    expect(saved.description, 'Calm or train animals.');
    expect(saved.fields['summary'], 'Calm or train animals.');

    // Düzenlenen ad tabloyla eşleşmez → kullanıcının yazdığı görünür;
    // dokunulmamış açıklama çevrili kalır. Okuma modu yine hiçbir şey yazmaz.
    await tester.pumpWidget(card(readOnly: true));
    await tester.pump();
    expect(find.text('Animal Handling!'), findsOneWidget);
    expect(find.text(trDesc, findRichText: true), findsNWidgets(2));
    expect(identical(container.read(entityProvider)[copy.id], saved), isTrue);

    // İngilizceye dönünce aynı kart İngilizce.
    await tester.runAsync(() async {
      (container.read(localeProvider.notifier) as _TestLocale).set('en');
      container.read(contentTranslatorProvider);
    });
    await waitTranslator(false);
    await tester.pumpWidget(card(readOnly: true));
    await tester.pump();
    expect(find.text('Calm or train animals.', findRichText: true),
        findsNWidgets(2));
    expect(find.text(trDesc, findRichText: true), findsNothing);
    await tester.pumpWidget(card(readOnly: true, id: poisoned.id));
    await tester.pump();
    expect(find.text('Poisoned'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(() async {
      container.dispose();
      await db.close();
    });
  });
}
