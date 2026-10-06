import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/widgets/dice/dice_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupL10n(const Locale('en'));

  test('names the user, character and what was rolled', () {
    expect(
      diceLogLine(en, user: 'eren', character: 'Thorin', kind: DiceRollKind.skill, label: 'Stealth', total: 17, detail: 'd20: 12 + 5'),
      'eren (Thorin) — Stealth check: 17 (d20: 12 + 5)',
    );
    expect(
      diceLogLine(en, user: 'eren', kind: DiceRollKind.save, label: 'Dexterity', total: 9, detail: 'd20: 7 + 2'),
      'eren — Dexterity saving throw: 9 (d20: 7 + 2)',
    );
    expect(
      diceLogLine(en, kind: DiceRollKind.roll, total: 7, detail: '2d6: 3 + 4 = 7'),
      'Roll: 7 (2d6: 3 + 4 = 7)',
    );
  });
}
