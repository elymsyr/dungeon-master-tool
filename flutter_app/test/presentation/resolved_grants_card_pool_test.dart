import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/presentation/theme/dm_tool_colors.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/resolved_grants_card.dart';

DmToolColors get _palette => themePalettes['dark']!;

Entity _spell(String id, String name) => Entity(
      id: id,
      name: name,
      categorySlug: 'spell',
    );

EffectiveCharacter _withPool({
  required String spellId,
  int max = 1,
}) {
  return EffectiveCharacter(
    characterId: 'c1',
    resourcePools: [
      {'pool_ref': spellId, 'max': max, 'recharge': 'long_rest'}
    ],
    grantSources: {
      spellId: const ['subspecies:Tiefling/Infernal'],
    },
  );
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [_palette],
      ),
      home: Scaffold(body: child),
    );

void main() {
  group('ResolvedGrantsCard granted resource pool', () {
    testWidgets('renders pool row with name and max/max when remaining empty',
        (tester) async {
      final spell = _spell('sp_hellish_rebuke', 'Hellish Rebuke');
      final eff = _withPool(spellId: spell.id);

      await tester.pumpWidget(_wrap(ResolvedGrantsCard(
        effective: eff,
        entities: {spell.id: spell},
        palette: _palette,
      )));

      expect(find.textContaining('Hellish Rebuke'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('minus button emits decremented map', (tester) async {
      final spell = _spell('sp_x', 'Fancy Spell');
      final eff = _withPool(spellId: spell.id, max: 3);
      Map<String, int>? captured;

      await tester.pumpWidget(_wrap(ResolvedGrantsCard(
        effective: eff,
        entities: {spell.id: spell},
        palette: _palette,
        onPoolRemainingChanged: (m) => captured = m,
      )));

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured![spell.id], 2);
    });

    testWidgets('reset button restores to max (sparse: key removed)',
        (tester) async {
      final spell = _spell('sp_x', 'Fancy Spell');
      final eff = _withPool(spellId: spell.id, max: 2);
      Map<String, int>? captured;

      await tester.pumpWidget(_wrap(ResolvedGrantsCard(
        effective: eff,
        entities: {spell.id: spell},
        palette: _palette,
        poolRemaining: const {'sp_x': 0},
        onPoolRemainingChanged: (m) => captured = m,
      )));

      await tester.tap(find.byIcon(Icons.bedtime_outlined));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.containsKey('sp_x'), isFalse);
    });

    testWidgets('plus button increments when below max', (tester) async {
      final spell = _spell('sp_x', 'Fancy Spell');
      final eff = _withPool(spellId: spell.id, max: 2);
      Map<String, int>? captured;

      await tester.pumpWidget(_wrap(ResolvedGrantsCard(
        effective: eff,
        entities: {spell.id: spell},
        palette: _palette,
        poolRemaining: const {'sp_x': 0},
        onPoolRemainingChanged: (m) => captured = m,
      )));

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!['sp_x'], 1);
    });

    testWidgets('class pool entries (Map pool_ref) are skipped', (tester) async {
      // Class pool entries arrive with `pool_ref` as a Map, not a String id.
      // The card should ignore them — class pool tracking lives elsewhere.
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

      await tester.pumpWidget(_wrap(ResolvedGrantsCard(
        effective: eff,
        entities: const <String, Entity>{},
        palette: _palette,
      )));

      // No card rendered at all because there are no granted pools/grants.
      expect(find.text('Granted Pools'), findsNothing);
    });
  });
}
