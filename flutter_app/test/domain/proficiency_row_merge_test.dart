import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/domain/entities/schema/dnd5e_constants.dart';

void main() {
  test('blueprint kisa yazimi tam preset satir listesine genisler', () {
    final merged = mergeProficiencyRows(
      proficiencyTableDefault(kDnd5eSkills),
      const {
        'rows': [
          {'name': 'Stealth', 'ability': 'DEX', 'proficient': true},
        ],
      },
    );
    final rows = (merged['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows.length, kDnd5eSkills.length);
    expect(rows.firstWhere((r) => r['name'] == 'Stealth')['proficient'], true);
    // Preset alanlari (expertise/misc) korunur, digerleri proficient degil.
    expect(rows.firstWhere((r) => r['name'] == 'Stealth')['misc'], 0);
    expect(rows.where((r) => r['proficient'] == true).length, 1);
  });

  test('preset disi satir dusmez', () {
    final merged = mergeProficiencyRows(
      proficiencyTableDefault(kDnd5eSavingThrows),
      const {
        'rows': [
          {'name': 'Sanity', 'ability': 'WIS', 'proficient': true},
        ],
      },
    );
    final rows = (merged['rows'] as List).cast<Map<String, dynamic>>();
    expect(rows.length, kDnd5eSavingThrows.length + 1);
    expect(rows.last['name'], 'Sanity');
  });
}
