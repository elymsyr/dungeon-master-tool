import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/application/services/package_import_service.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/steps/skill_mod_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Audit phase T2-1 — `skill.ability_ref` resolves end to end.**
///
/// The seed rows ship a `_lookup` placeholder; `synthesizeWorldBuiltins`
/// resolves it against a `slug → name → id` index built from the same pack
/// rows. This test rebuilds that index in-memory (no DB) and then asks the
/// wizard's helper for the chip value — the guard that used to bail.
void main() {
  final build = generateBuiltinDnd5eV2Schema();

  /// Mirrors `synthesizeWorldBuiltins`: index every Tier-0 seed row by
  /// (slug, name), then resolve each row's `_lookup` placeholders.
  Map<String, Entity> synthesise() {
    final index = <String, Map<String, String>>{};
    for (final entry in build.seedRows.entries) {
      for (final row in entry.value) {
        index.putIfAbsent(entry.key, () => {})[row['name'] as String] =
            '${entry.key}:${row['name']}';
      }
    }
    final out = <String, Entity>{};
    for (final entry in build.seedRows.entries) {
      for (final row in entry.value) {
        final id = index[entry.key]![row['name'] as String]!;
        out[id] = Entity(
          id: id,
          name: row['name'] as String,
          categorySlug: entry.key,
          fields: Map<String, dynamic>.from(
            PackageImportService.resolveLookupPlaceholder(
              row['fields'] ?? <String, dynamic>{},
              index,
            ) as Map,
          ),
        );
      }
    }
    return out;
  }

  test('every skill resolves to a real ability entity', () {
    final entities = synthesise();
    final skills = entities.values.where((e) => e.categorySlug == 'skill');
    expect(skills.length, 18);
    for (final skill in skills) {
      final ref = skill.fields['ability_ref'];
      expect(ref, isA<String>(), reason: skill.name);
      expect(entities[ref]?.categorySlug, 'ability', reason: skill.name);
    }
  });

  test('the wizard chip renders the linked ability modifier', () {
    final entities = synthesise();
    const draft = CharacterDraft(
      baseAbilities: {'DEX': 16, 'INT': 8},
      racialBonuses: {'DEX': 2},
    );
    Entity skill(String name) =>
        entities.values.firstWhere((e) => e.categorySlug == 'skill' && e.name == name);

    // Stealth is DEX: 16 base + 2 racial = 18 → +4.
    expect(skillAbilityModFor(skill('Stealth'), entities, draft), 4);
    // Arcana is INT: 8 → -1. No racial bonus applies.
    expect(skillAbilityModFor(skill('Arcana'), entities, draft), -1);
    // Unset ability defaults to 10 → +0, and formats as such.
    expect(skillAbilityModFor(skill('Athletics'), entities, draft), 0);
    expect(formatModifier(4), '+4');
  });
}
