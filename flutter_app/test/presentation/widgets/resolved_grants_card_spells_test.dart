import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/presentation/theme/dm_tool_colors.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/resolved_grants_card.dart';

/// Spells handed out by a class / subclass level table are resolved but never
/// mirrored onto the PC's `spells_known` — the sheet has to read them off the
/// resolved character. Before this row existed `alwaysPreparedSpellIds` had
/// exactly two references in the whole codebase: its declaration and the
/// resolver line that filled it.
void main() {
  final theme = buildThemeData('dark');
  final palette = theme.extension<DmToolColors>()!;

  final entities = <String, Entity>{
    'sp_alarm': const Entity(
        id: 'sp_alarm', categorySlug: 'spell', name: 'Alarm', fields: {}),
    'sp_aid':
        const Entity(id: 'sp_aid', categorySlug: 'spell', name: 'Aid', fields: {}),
  };

  Future<void> pump(WidgetTester tester, EffectiveCharacter effective) =>
      tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResolvedGrantsCard(
              effective: effective,
              entities: entities,
              palette: palette,
            ),
          ),
        ),
      ));

  testWidgets('always-prepared spells render on the sheet', (tester) async {
    await pump(
      tester,
      const EffectiveCharacter(
        characterId: 'pc1',
        alwaysPreparedSpellIds: ['sp_alarm', 'sp_aid'],
      ),
    );

    expect(find.text('Always Prepared'), findsOneWidget);
    expect(find.text('Alarm'), findsOneWidget);
    expect(find.text('Aid'), findsOneWidget);
  });

  testWidgets('the card is not hidden when spells are its only content',
      (tester) async {
    // The empty-check gate: every grant list is consulted before the card
    // renders, so a list left out of it makes the whole card disappear.
    await pump(
      tester,
      const EffectiveCharacter(
          characterId: 'pc1', alwaysPreparedSpellIds: ['sp_alarm']),
    );
    expect(find.text('Resolved Grants'), findsOneWidget);
  });

  testWidgets('nothing granted still collapses the card', (tester) async {
    await pump(tester, const EffectiveCharacter(characterId: 'pc1'));
    expect(find.text('Resolved Grants'), findsNothing);
  });
}
