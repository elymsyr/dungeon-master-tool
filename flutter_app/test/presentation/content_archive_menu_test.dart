// `.dmtz` düğmesi satırdaki komşularıyla aynı görünmeli.
//
// İlk sürümde tetikleyici çıplak bir `PopupMenuButton`'dı: içeride bir
// `IconButton` üretiyor, yani kenarlıksız, zeminsiz ve farklı yükseklikte.
// "Yükle / Kopyala / Sil" satırında tek başına sırıtıyordu. Düzeltme,
// görünümü tema üzerinden almak: tetikleyici gerçek bir `OutlinedButton`,
// tıpkı yanındaki "Kopyala" gibi.
//
// Testin bağladığı şey tetikleyicinin **tipi**: `OutlinedButton` olduğu
// sürece kenarlık, zemin, köşe yarıçapı ve dolgu `outlinedButtonTheme`'den
// gelir, yani widget'ta sabit değer olmasına gerek kalmaz.
//
// Yükseklik tek başına ayırt etmiyor: ölçtük, eski `IconButton` da 48 px
// idi (Material'ın asgari dokunma hedefi), fark 48×48 kenarlıksız kutu ile
// 150×48 kenarlıklı düğme arasındaydı. Bu yüzden yükseklik eşitliği burada
// yalnız hizalama güvencesi; regresyonu yakalayan asıl iddia tip kontrolü.
//
//   cd flutter_app && flutter test test/presentation/content_archive_menu_test.dart

import 'package:dungeon_master_tool/application/services/content_transfer/content_item.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/content_archive_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hub'ın dünya sekmesindeki satırın küçültülmüş hâli.
Widget _row(String theme) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: buildThemeData(theme),
        home: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                key: const Key('komsu'),
                onPressed: () {},
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('Kopyala'),
              ),
              const SizedBox(width: 8),
              const ContentArchiveMenu(
                key: Key('aktar'),
                type: ContentItemType.world,
                selectedId: 'w-1',
                selectedName: 'Barovia',
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  for (final theme in const ['dark', 'light']) {
    testWidgets('$theme: tetikleyici komşusuyla aynı türde ve hizalı',
        (tester) async {
      await tester.pumpWidget(_row(theme));

      // Asıl iddia: aynı widget türü → aynı tema kaynağı.
      expect(
        find.descendant(
          of: find.byKey(const Key('aktar')),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
        reason: 'tetikleyici OutlinedButton değil — görünümü temadan almıyor',
      );

      final neighbour = tester.getSize(find.byKey(const Key('komsu')));
      final transfer = tester.getSize(find.byKey(const Key('aktar')));
      expect(transfer.height, neighbour.height, reason: 'satırda hizasız');
    });
  }

  testWidgets('tek eylem kalınca ikon düğmesi olur (karakter düzenleyici)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: buildThemeData('dark'),
        home: const Scaffold(
          body: ContentArchiveMenu(
            key: Key('aktar'),
            type: ContentItemType.character,
            selectedId: 'c-1',
            selectedName: 'Strahd',
            showImport: false,
          ),
        ),
      ),
    ));

    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('seçim yokken dışa aktarma kapalı', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: buildThemeData('dark'),
        home: const Scaffold(
          body: ContentArchiveMenu(type: ContentItemType.world),
        ),
      ),
    ));

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    final l10n = await L10n.delegate.load(const Locale('en'));
    // İçe aktarma her zaman açık, dışa aktarma seçim ister.
    expect(
      tester.widget<PopupMenuItem<bool>>(
        find.widgetWithText(PopupMenuItem<bool>, l10n.contentArchiveExport),
      ).enabled,
      isFalse,
    );
    expect(
      tester.widget<PopupMenuItem<bool>>(
        find.widgetWithText(PopupMenuItem<bool>, l10n.contentArchiveImport),
      ).enabled,
      isTrue,
    );
  });
}
