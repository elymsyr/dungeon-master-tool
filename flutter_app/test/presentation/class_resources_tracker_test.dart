import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/presentation/theme/dm_tool_colors.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/class_resources_card.dart';

DmToolColors get _palette => themePalettes['dark']!;

Entity _pool(String id, String name, {String slug = 'resource-pool'}) =>
    Entity(id: id, name: name, categorySlug: slug);

EffectiveCharacter _withPool({required String id, int max = 1}) =>
    EffectiveCharacter(
      characterId: 'c1',
      resourcePools: [
        {'pool_ref': id, 'max': max, 'recharge': 'long_rest'}
      ],
      grantSources: {
        id: const ['class:Bard'],
      },
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: [_palette]),
      home: Scaffold(body: child),
    );

/// Kullanım kutuları (pip) — dolu olanı harcanabilir kullanımdır.
Finder get _pips => find.byWidgetPredicate(
      (w) => w is InkWell && w.child is Container,
    );

void main() {
  group('ClassResourcesTracker', () {
    testWidgets('renders one pip per use, all filled when nothing spent',
        (tester) async {
      final pool = _pool('p1', 'pool:bardic_inspiration');
      await tester.pumpWidget(_wrap(ClassResourcesTracker(
        effective: _withPool(id: pool.id, max: 3),
        entities: {pool.id: pool},
        palette: _palette,
      )));

      expect(find.textContaining('Bardic Inspiration'), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(_pips, findsNWidgets(3));
    });

    testWidgets('tapping a filled pip spends down to it', (tester) async {
      final pool = _pool('p1', 'pool:rage_uses');
      Map<String, int>? captured;
      await tester.pumpWidget(_wrap(ClassResourcesTracker(
        effective: _withPool(id: pool.id, max: 3),
        entities: {pool.id: pool},
        palette: _palette,
        onPoolRemainingChanged: (m) => captured = m,
      )));

      // 3. kutu (index 2) → kalan 2.
      await tester.tap(_pips.at(2));
      await tester.pump();
      expect(captured!['p1'], 2);
    });

    testWidgets('tapping an empty pip restores up to it', (tester) async {
      final pool = _pool('p1', 'pool:rage_uses');
      Map<String, int>? captured;
      await tester.pumpWidget(_wrap(ClassResourcesTracker(
        effective: _withPool(id: pool.id, max: 3),
        entities: {pool.id: pool},
        palette: _palette,
        poolRemaining: const {'p1': 0},
        onPoolRemainingChanged: (m) => captured = m,
      )));

      await tester.tap(_pips.at(1));
      await tester.pump();
      expect(captured!['p1'], 2);
    });

    testWidgets('long rest restores to max and drops the sparse key',
        (tester) async {
      final pool = _pool('p1', 'pool:rage_uses');
      Map<String, int>? captured;
      await tester.pumpWidget(_wrap(ClassResourcesTracker(
        effective: _withPool(id: pool.id, max: 2),
        entities: {pool.id: pool},
        palette: _palette,
        poolRemaining: const {'p1': 0},
        onPoolRemainingChanged: (m) => captured = m,
      )));

      await tester.tap(find.byIcon(Icons.bedtime_outlined));
      await tester.pump();
      expect(captured!.containsKey('p1'), isFalse);
    });

    testWidgets('innate-spell pools (pool_ref = spell id) render too',
        (tester) async {
      final spell = _pool('sp1', 'Hellish Rebuke', slug: 'spell');
      await tester.pumpWidget(_wrap(ClassResourcesTracker(
        effective: _withPool(id: spell.id),
        entities: {spell.id: spell},
        palette: _palette,
      )));

      expect(find.textContaining('Hellish Rebuke'), findsOneWidget);
      expect(_pips, findsOneWidget);
    });

    testWidgets('unresolvable pool_ref renders nothing', (tester) async {
      // Resolver artık zarfı id'ye çeviriyor; çeviremediğinde uydurma
      // kapasiteli bir sayaç göstermektense satırı hiç çizmiyoruz.
      final eff = EffectiveCharacter(
        characterId: 'c1',
        resourcePools: [
          {
            'pool_ref': {'name': 'pool:rage_uses'},
            'max': 2,
            'recharge': 'long_rest',
          }
        ],
      );
      await tester.pumpWidget(_wrap(ClassResourcesTracker(
        effective: eff,
        entities: const <String, Entity>{},
        palette: _palette,
      )));

      expect(_pips, findsNothing);
    });
  });
}
