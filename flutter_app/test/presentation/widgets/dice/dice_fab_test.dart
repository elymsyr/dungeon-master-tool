import 'package:dungeon_master_tool/application/providers/ui_state_provider.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/dice/dice_fab.dart';
import 'package:dungeon_master_tool/presentation/widgets/dice/dice_roll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tests have no Flutter GPU, so this also walks the results-only fallback.
  testWidgets('menu builds a set, rolls it, shows the result, tap closes', (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      theme: buildThemeData('dark'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: const Scaffold(floatingActionButton: DiceFab()),
    )));

    await tester.tap(find.byType(DiceFab));
    await tester.pumpAndSettle();
    final roll = find.widgetWithText(FilledButton, 'Roll');
    expect(tester.widget<FilledButton>(roll).onPressed, isNull);

    final plus = find.byIcon(Icons.add); // one per row, in diceKinds order
    await tester.tap(plus.at(1)); // d6
    await tester.tap(plus.at(1));
    await tester.tap(plus.at(5)); // d20
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Roll 2d6 + 1d20'));
    await tester.pump(); // builds the roll view, which starts the throw isolate
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'^2d6: \d \+ \d = \d+  ·  d20: \d+$')), findsOneWidget);
    expect(find.text('Tap to close'), findsOneWidget);

    await tester.tap(find.byType(DiceRollView));
    await tester.pumpAndSettle();
    expect(find.byType(DiceRollView), findsNothing);
    expect(find.byIcon(Icons.casino), findsOneWidget); // back to the plain button
  });

  testWidgets('rollDice adds the modifier and titles the card', (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      theme: buildThemeData('dark'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () {
            // Another look than the test above: DiceKit caches its load, and a
            // future made in that test's zone never completes in this one.
            ref.read(uiStateProvider.notifier).update((s) => s.copyWith(diceTheme: 'rose'));
            rollDice(context, ref, const {'d20': 1}, modifier: 5, label: 'Stealth');
          },
          child: const Text('go'),
        ),
      ),
    )));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pumpAndSettle();

    expect(find.text('Stealth'), findsOneWidget);
    final d20 = int.parse(RegExp(r'^d20: (\d+) \+ 5$')
        .firstMatch(tester.widget<Text>(find.textContaining('d20: ')).data!)!
        .group(1)!);
    expect(find.text('${d20 + 5}'), findsOneWidget);
  });

  test('dice look follows the app theme on auto, else the pick', () {
    expect(diceLooks.keys, containsAll(themeNames)); // every theme has its resin; named styles follow
    expect(resolveDiceLook('auto', 'nord'), 'nord');
    expect(resolveDiceLook('rose', 'nord'), 'rose');
    expect(resolveDiceLook('gone', 'nord'), 'dark');
  });
}
