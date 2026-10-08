import 'package:dungeon_master_tool/application/providers/campaign_provider.dart';
import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/data/database/database_provider.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/database/entity_card.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

/// KNOWN_ISSUES: kart 300 ms kayıt gecikmesi dolmadan kapanırsa son yazılan
/// kaybolmamalı.
void main() {
  testWidgets('closing the card inside the debounce window keeps the edit',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 3200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = openTestDatabase();
    final container =
        ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);

    await tester.runAsync(() async {
      final worldId = await container
          .read(campaignRepositoryProvider)
          .create('W', template: generateBuiltinDnd5eV2Schema().schema);
      await container.read(activeCampaignProvider.notifier).load(worldId);
    });
    final skill = container.read(entityProvider).values.firstWhere(
        (e) => e.categorySlug == 'skill' && e.name == 'Animal Handling');
    // Bağlı SRD kartı düzenlenince kopyalanır — kopyayla çalış.
    container
        .read(entityProvider.notifier)
        .update(skill.copyWith(description: 'x'));
    final copy = container.read(entityProvider).values.firstWhere(
        (e) => e.categorySlug == 'skill' && e.description == 'x');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildThemeData('dark'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(body: EntityCard(entityId: copy.id, readOnly: false)),
      ),
    ));
    await tester.pump();

    await tester.enterText(find.text('Animal Handling'), 'Animal Handling!');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox()); // gecikme dolmadan kapat
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(container.read(entityProvider)[copy.id]!.name, 'Animal Handling!');

    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(() async {
      container.dispose();
      await db.close();
    });
  });
}
