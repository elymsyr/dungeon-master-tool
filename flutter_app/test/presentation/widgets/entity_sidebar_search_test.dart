import 'package:dungeon_master_tool/application/providers/builtin_package_provider.dart';
import 'package:dungeon_master_tool/application/providers/content_translator_provider.dart';
import 'package:dungeon_master_tool/application/providers/entity_sidebar_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';
import 'package:dungeon_master_tool/domain/services/content_translator.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/entity_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arama önceden katlanmış metin üzerinden: ad (İ katlaması dahil), SRD'nin
/// İngilizce adı, kaynak ve etiketler eşleşir; alanlar arası eşleşme olmaz.
void main() {
  EntitySummary s(String id, String name,
          {String source = '',
          List<String> tags = const [],
          bool linked = false}) =>
      (
        id: id,
        name: name,
        categorySlug: 'monster',
        source: source,
        tags: tags,
        packageId: null,
        linked: linked,
      );

  final summaries = [
    s('1', 'İskelet'),
    s('2', 'Goblin Warrior', source: srdSourceTag, linked: true),
    s('3', 'Ork', source: 'Homebrew'),
    s('4', 'Ejderha', tags: ['Boss']),
  ];
  const tr = ContentTranslator({
    'monster': {'Goblin Warrior': 'Goblin Savaşçı'},
  });

  Future<void> search(WidgetTester t, String q) async {
    await t.enterText(find.byType(TextField).first, q);
    await t.pump(const Duration(milliseconds: 250));
  }

  testWidgets('sidebar search matches folded name, EN name, source, tag',
      (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        entitySummaryListProvider.overrideWithValue(summaries),
        contentTranslatorProvider.overrideWithValue(tr),
        builtinPackageIdProvider.overrideWith((_) async => null),
      ],
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [themePalettes['dark']!]),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: const Scaffold(body: EntitySidebar(pinning: false)),
      ),
    ));
    await t.pumpAndSettle();

    await search(t, 'iske');
    expect(find.text('İskelet'), findsOneWidget);
    expect(find.text('Ork'), findsNothing);

    await search(t, 'warrior'); // İngilizce ad, ekranda Türkçe
    expect(find.text('Goblin Savaşçı'), findsOneWidget);

    await search(t, 'homebrew');
    expect(find.text('Ork'), findsOneWidget);
    expect(find.text('İskelet'), findsNothing);

    await search(t, 'boss');
    expect(find.text('Ejderha'), findsOneWidget);

    await search(t, 'orkhome'); // alanlar arası eşleşme yok
    expect(find.text('Ork'), findsNothing);
  });
}
