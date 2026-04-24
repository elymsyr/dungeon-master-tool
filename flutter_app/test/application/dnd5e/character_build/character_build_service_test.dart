import 'package:dungeon_master_tool/application/dnd5e/character_build/character_build_service.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/background.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/caster_kind.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/feat.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/species.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/subclass.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/die.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/hit_points.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/proficiency.dart';
import 'package:dungeon_master_tool/domain/dnd5e/effect/effect_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

Character _seed() => Character(
      id: 'char-1',
      name: 'Test',
      classLevels: [CharacterClassLevel(classId: 'srd:fighter', level: 1)],
      speciesId: 'srd:human',
      backgroundId: 'srd:soldier',
      alignmentId: 'srd:neutral',
      abilities: AbilityScores.allTens(),
      hp: HitPoints(current: 10, max: 10),
    );

void main() {
  group('CharacterBuildService', () {
    test('builds Acolyte Human Fighter with full grants cascade', () {
      const svc = CharacterBuildService();
      final species = Species(
        id: 'srd:human',
        name: 'Human',
        sizeId: 'srd:medium',
        baseSpeedFt: 30,
      );
      final background = Background(
        id: 'srd:acolyte',
        name: 'Acolyte',
        effects: [
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:insight',
          ),
          GrantProficiency(
            kind: ProficiencyKind.skill,
            targetId: 'srd:religion',
          ),
          GrantProficiency(
            kind: ProficiencyKind.language,
            targetId: 'srd:celestial',
          ),
        ],
        grantedFeatId: 'srd:magic-initiate-cleric',
        startingEquipmentIds: ['srd:holy-symbol'],
      );
      final fighter = CharacterClass(
        id: 'srd:fighter',
        name: 'Fighter',
        hitDie: Die.d10,
        savingThrows: [Ability.strength, Ability.constitution],
        startingArmorIds: ['srd:light-armor', 'srd:medium-armor'],
        startingWeaponIds: ['srd:simple-weapons', 'srd:martial-weapons'],
        grantedSkillChoiceCount: 2,
        grantedSkillOptions: [
          'srd:acrobatics',
          'srd:athletics',
          'srd:intimidation',
          'srd:perception',
        ],
      );
      final feat = Feat(
        id: 'srd:savage-attacker',
        name: 'Savage Attacker',
        category: FeatCategory.origin,
      );

      final c = svc.build(
        seed: _seed(),
        species: species,
        background: background,
        classes: [
          ClassSelection(
            cls: fighter,
            level: 1,
            chosenSkillIds: ['srd:athletics', 'srd:perception'],
          ),
        ],
        feats: [FeatSelection(feat: feat)],
      );

      // Background grants
      expect(c.proficiencies.skills['srd:insight'], Proficiency.full);
      expect(c.proficiencies.skills['srd:religion'], Proficiency.full);
      expect(c.languageIds, contains('srd:celestial'));
      expect(c.featIds, contains('srd:magic-initiate-cleric'));
      expect(c.inventory.entries.map((e) => e.itemId),
          contains('srd:holy-symbol'));

      // Class save proficiencies
      expect(c.proficiencies.saves[Ability.strength], Proficiency.full);
      expect(c.proficiencies.saves[Ability.constitution], Proficiency.full);

      // Class starting armor + weapon proficiencies
      expect(
          c.proficiencies.armor['srd:light-armor'], Proficiency.full);
      expect(
          c.proficiencies.weapons['srd:martial-weapons'], Proficiency.full);

      // User-chosen fighter skills
      expect(c.proficiencies.skills['srd:athletics'], Proficiency.full);
      expect(c.proficiencies.skills['srd:perception'], Proficiency.full);

      // Feat id
      expect(c.featIds, contains('srd:savage-attacker'));
    });

    test('multiclass: saves only from first class', () {
      const svc = CharacterBuildService();
      final fighter = CharacterClass(
        id: 'srd:fighter',
        name: 'Fighter',
        hitDie: Die.d10,
        savingThrows: [Ability.strength, Ability.constitution],
      );
      final wizard = CharacterClass(
        id: 'srd:wizard',
        name: 'Wizard',
        hitDie: Die.d6,
        savingThrows: [Ability.intelligence, Ability.wisdom],
        casterKind: CasterKind.full,
        spellcastingAbility: Ability.intelligence,
      );
      final c = svc.build(
        seed: _seed().copyWith(classLevels: [
          CharacterClassLevel(classId: 'srd:fighter', level: 1),
          CharacterClassLevel(classId: 'srd:wizard', level: 1),
        ]),
        classes: [
          ClassSelection(cls: fighter, level: 1),
          ClassSelection(cls: wizard, level: 1),
        ],
      );
      // Fighter (first) saves present
      expect(c.proficiencies.saves[Ability.strength], Proficiency.full);
      expect(c.proficiencies.saves[Ability.constitution], Proficiency.full);
      // Wizard saves must NOT be granted (multiclass rule)
      expect(c.proficiencies.saves[Ability.intelligence], null);
      expect(c.proficiencies.saves[Ability.wisdom], null);
    });

    test('subclass bonus spells merged at correct level', () {
      const svc = CharacterBuildService();
      final cleric = CharacterClass(
        id: 'srd:cleric',
        name: 'Cleric',
        hitDie: Die.d8,
        casterKind: CasterKind.full,
        spellcastingAbility: Ability.wisdom,
      );
      final lightDomain = Subclass(
        id: 'srd:light-domain',
        name: 'Light Domain',
        parentClassId: 'srd:cleric',
        bonusSpellIds: {
          1: ['srd:burning-hands', 'srd:faerie-fire'],
          3: ['srd:flaming-sphere'],
          5: ['srd:daylight'],
        },
      );
      final c = svc.build(
        seed: _seed(),
        classes: [
          ClassSelection(cls: cleric, level: 3, subclass: lightDomain),
        ],
      );
      // Level 1 + 3 spells present
      expect(c.preparedSpells.contains('srd:burning-hands'), true);
      expect(c.preparedSpells.contains('srd:flaming-sphere'), true);
      // Level 5 NOT yet
      expect(c.preparedSpells.contains('srd:daylight'), false);
    });

    test('isSpellcaster detects any caster in class list', () {
      const svc = CharacterBuildService();
      final fighter = CharacterClass(
        id: 'srd:fighter',
        name: 'Fighter',
        hitDie: Die.d10,
      );
      final wizard = CharacterClass(
        id: 'srd:wizard',
        name: 'Wizard',
        hitDie: Die.d6,
        casterKind: CasterKind.full,
        spellcastingAbility: Ability.intelligence,
      );
      expect(svc.isSpellcaster([ClassSelection(cls: fighter, level: 1)]),
          false);
      expect(
          svc.isSpellcaster([
            ClassSelection(cls: fighter, level: 3),
            ClassSelection(cls: wizard, level: 1),
          ]),
          true);
    });
  });
}
