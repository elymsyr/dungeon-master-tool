import 'package:dungeon_master_tool/domain/entities/schema/rule_config.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/presentation/dialogs/rule_config_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorldSchema _schema({Map<String, dynamic> metadata = const {}}) => WorldSchema(
      schemaId: 'test-schema',
      createdAt: '0',
      updatedAt: '0',
      metadata: metadata,
    );

Future<TextField> _fieldByLabel(WidgetTester tester, String label) async {
  final fields = tester.widgetList<TextField>(find.byType(TextField));
  return fields.firstWhere((f) => f.decoration?.labelText == label);
}

Future<void> _enterByLabel(
    WidgetTester tester, String label, String text) async {
  final field = await _fieldByLabel(tester, label);
  await tester.enterText(find.byWidget(field), text);
}

void main() {
  testWidgets('editing values writes rule_config into metadata',
      (tester) async {
    WorldSchema? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RuleConfigDialog(
          schema: _schema(),
          onSave: (updated) async => saved = updated,
        ),
      ),
    ));

    await _enterByLabel(tester, 'ASI / feat levels', '4, 6, 8');
    await _enterByLabel(tester, 'Unarmored base', '13');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    final raw = saved!.metadata['rule_config'];
    expect(raw, isA<Map<String, dynamic>>());
    final config = RuleConfig.fromJson(Map<String, dynamic>.from(raw as Map));
    expect(config.asiLevels, [4, 6, 8]);
    expect(config.acUnarmoredBase, 13);
    expect(config.acShieldBonus, RuleConfig.dnd5eDefaults.acShieldBonus);
  });

  testWidgets('values equal to the defaults remove the rule_config key',
      (tester) async {
    WorldSchema? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RuleConfigDialog(
          schema: _schema(metadata: {
            'rule_config': {'ac_unarmored_base': 13},
            'other_key': 'untouched',
          }),
          onSave: (updated) async => saved = updated,
        ),
      ),
    ));

    // Bring the single divergent value back to the default.
    await _enterByLabel(tester, 'Unarmored base', '10');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.metadata.containsKey('rule_config'), isFalse,
        reason: 'default-equal config must not churn the content hash');
    expect(saved!.metadata['other_key'], 'untouched');
  });

  testWidgets('reset button restores defaults, save then drops the override',
      (tester) async {
    WorldSchema? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RuleConfigDialog(
          schema: _schema(metadata: {
            'rule_config': {
              'asi_levels': [3],
              'ac_shield_bonus': 5,
            },
          }),
          onSave: (updated) async => saved = updated,
        ),
      ),
    ));

    // The override is loaded into the fields.
    final asiField = await _fieldByLabel(tester, 'ASI / feat levels');
    expect(asiField.controller?.text, '3');

    await tester.tap(find.text('Reset to D&D 5e defaults'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.metadata.containsKey('rule_config'), isFalse);
  });

  testWidgets('existing override pre-fills every field', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RuleConfigDialog(
          schema: _schema(metadata: {
            'rule_config': {
              'asi_levels': [4, 10],
              'hit_die_to_hp': {'d6': 4, 'd8': 6, 'd10': 6, 'd12': 7},
              'ac_unarmored_base': 11,
              'ac_shield_bonus': 3,
              'proficiency_bonus_breakpoints': [6, 12],
            },
          }),
          onSave: (_) async {},
        ),
      ),
    ));

    expect((await _fieldByLabel(tester, 'ASI / feat levels')).controller?.text,
        '4, 10');
    expect(
        (await _fieldByLabel(tester, 'Proficiency bonus increases at'))
            .controller
            ?.text,
        '6, 12');
    expect((await _fieldByLabel(tester, 'd8')).controller?.text, '6');
    expect((await _fieldByLabel(tester, 'Unarmored base')).controller?.text,
        '11');
    expect(
        (await _fieldByLabel(tester, 'Shield bonus')).controller?.text, '3');
  });
}
