// SRD 5.2.1 Classes (pp. 28–82): Barbarian, Bard, Cleric, Druid, Fighter,
// Monk, Paladin, Ranger, Rogue, Sorcerer, Warlock, Wizard.
//
// Each class ships with full Core Traits (primary/saves/proficiencies/armor
// training/starting equipment + gold dice) and a typed `features` list
// covering the Level 1 features verbatim from the SRD. Higher-level features
// are summarized in `description` markdown plus the per-level entries the SRD
// "Features by Level" table calls out by name; the full mechanical text is
// abbreviated to fit the multi-page transcription budget. Power users can
// later expand individual entries by editing the cloned campaign.

import '_helpers.dart';

/// Build a single classFeatures-list entry: `{level, name, description}`.
Map<String, dynamic> _f(int level, String name, String description) =>
    {'level': level, 'name': name, 'description': description};

List<Map<String, dynamic>> srdClasses() => [
      // ─── Barbarian ───────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Barbarian',
        description:
            'Fierce warrior of primitive background who can enter a battle rage. '
            'Hit Die d12. Strength-primary. Wears Light/Medium armor; trained with all weapons.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Strength'),
          'hit_die': 'd12',
          'saving_throw_refs': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Constitution'),
          ],
          'skill_proficiency_choice_count': 2,
          'skill_proficiency_options': [
            lookup('skill', 'Animal Handling'),
            lookup('skill', 'Athletics'),
            lookup('skill', 'Intimidation'),
            lookup('skill', 'Nature'),
            lookup('skill', 'Perception'),
            lookup('skill', 'Survival'),
          ],
          'weapon_proficiency_categories': [
            lookup('weapon-category', 'Simple'),
            lookup('weapon-category', 'Martial'),
          ],
          'armor_training_refs': [
            lookup('armor-category', 'Light'),
            lookup('armor-category', 'Medium'),
            lookup('armor-category', 'Shield'),
          ],
          'caster_kind': 'None',
          'complexity': 'Low',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Strength')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Greataxe, 4 Handaxes, Explorer\'s Pack, 15 GP',
                  items: [
                    eqItem('weapon', 'Greataxe'),
                    eqItem('weapon', 'Handaxe', qty: 4),
                    eqItem('pack', 'Explorer\'s Pack'),
                  ],
                  goldGp: 15,
                ),
                eqOption(optionId: 'B', label: '75 GP', goldGp: 75),
              ],
            ),
          ],
          'starting_gold_dice': '2d4 × 10',
          'features': [
            _f(1, 'Rage',
                'You can imbue yourself with primal power as a Bonus Action while not in Heavy armor. While raging you have Resistance to B/P/S, gain a damage bonus on Strength attacks, Advantage on Strength checks/saves, can\'t cast spells or maintain Concentration. Lasts to the end of your next turn; extend by attacking, forcing a save, or a Bonus Action. Up to 10 minutes per Rage.'),
            _f(1, 'Unarmored Defense',
                'While not wearing armor, your AC = 10 + Dex mod + Con mod. You can use a Shield and still gain this benefit.'),
            _f(1, 'Weapon Mastery',
                'Use the mastery property of two kinds of Simple/Martial Melee weapons. Swap one choice on a Long Rest. More kinds unlock at higher levels.'),
            _f(2, 'Danger Sense',
                'Advantage on Dex saves while not Incapacitated.'),
            _f(2, 'Reckless Attack',
                'On your first attack of the turn, gain Advantage on Strength attacks until the start of your next turn; attacks against you also have Advantage during that time.'),
            _f(3, 'Barbarian Subclass',
                'Choose a subclass (Path of the Berserker in this SRD).'),
            _f(3, 'Primal Knowledge',
                'Gain proficiency in another barbarian skill. While raging you can substitute Strength for ability checks made with Acrobatics, Intimidation, Perception, Stealth, or Survival.'),
            _f(4, 'Ability Score Improvement',
                'Gain the Ability Score Improvement feat or another feat you qualify for. Repeats at levels 8, 12, 16.'),
            _f(5, 'Extra Attack',
                'Attack twice when you take the Attack action.'),
            _f(5, 'Fast Movement',
                '+10 ft. Speed while not in Heavy armor.'),
            _f(7, 'Feral Instinct', 'Advantage on Initiative rolls.'),
            _f(7, 'Instinctive Pounce',
                'When you Bonus Action into Rage, move up to half your Speed.'),
            _f(9, 'Brutal Strike',
                'When you Reckless Attack, you can forgo Advantage on one Str attack to deal +1d10 damage and apply a Brutal Strike effect (Forceful Blow or Hamstring Blow).'),
            _f(11, 'Relentless Rage',
                'When dropped to 0 HP while raging, DC 10 Con save to drop to twice your level instead. DC +5 each subsequent use; resets on a rest.'),
            _f(13, 'Improved Brutal Strike',
                'Adds Staggering Blow and Sundering Blow to your Brutal Strike options.'),
            _f(15, 'Persistent Rage',
                'When you roll Initiative, regain all uses of Rage (once per Long Rest). Rage now lasts 10 minutes without extending.'),
            _f(17, 'Improved Brutal Strike (II)',
                'Brutal Strike extra damage rises to 2d10 and you can apply two effects per use.'),
            _f(18, 'Indomitable Might',
                'If your Strength check/save total is less than your Str score, use the score instead.'),
            _f(19, 'Epic Boon',
                'Gain an Epic Boon feat or another feat you qualify for. Boon of Irresistible Offense is recommended.'),
            _f(20, 'Primal Champion',
                'Strength and Constitution scores increase by 4, max 25.'),
          ],
        },
      ),

      // ─── Bard ────────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Bard',
        description:
            'Inspiring magician whose power echoes the music of creation. '
            'Hit Die d8. Charisma-primary full caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Charisma'),
          'hit_die': 'd8',
          'saving_throw_refs': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Charisma'),
          ],
          'skill_proficiency_choice_count': 3,
          'weapon_proficiency_categories': [
            lookup('weapon-category', 'Simple'),
          ],
          'armor_training_refs': [lookup('armor-category', 'Light')],
          'caster_kind': 'Full',
          'casting_ability_ref': lookup('ability', 'Charisma'),
          'complexity': 'Average',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Charisma')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Leather Armor, 2 Daggers, Entertainer\'s Pack, 19 GP',
                  items: [
                    eqItem('armor', 'Leather Armor'),
                    eqItem('weapon', 'Dagger', qty: 2),
                    eqItem('pack', 'Entertainer\'s Pack'),
                  ],
                  goldGp: 19,
                ),
                eqOption(optionId: 'B', label: '90 GP', goldGp: 90),
              ],
            ),
          ],
          'starting_gold_dice': '5d4 × 10',
          'features': [
            _f(1, 'Bardic Inspiration',
                'As a Bonus Action choose a creature within 60 feet (other than yourself); they gain a Bardic Inspiration die (d6). They can roll the die within 10 minutes and add it to one ability check, attack roll, or saving throw, deciding after the d20 but before the result is known. Number of uses = your Charisma modifier (min 1) per Long Rest. Die size grows at higher levels.'),
            _f(1, 'Spellcasting',
                'You know cantrips and spells from the Bard list. Charisma is your spellcasting ability.'),
            _f(2, 'Expertise',
                'Choose two skills you\'re proficient in; your Proficiency Bonus is doubled for ability checks with those skills. Another skill at level 9.'),
            _f(2, 'Jack of All Trades',
                'Add half your PB (rounded down) to ability checks that don\'t already include it.'),
            _f(3, 'Bard Subclass',
                'Choose a subclass (College of Lore in this SRD).'),
            _f(4, 'Ability Score Improvement', 'Repeats at levels 8, 12, 16, 19.'),
            _f(5, 'Font of Inspiration',
                'Bardic Inspiration die becomes d8. Regain expended Bardic Inspiration on a Short or Long Rest.'),
            _f(6, 'Subclass feature', ''),
            _f(7, 'Countercharm',
                'When you or a creature within 30 feet of you fails a save against being Charmed or Frightened, you can use a Reaction to let them reroll.'),
            _f(9, 'Expertise (II)', 'Choose two more skills for Expertise.'),
            _f(10, 'Magical Secrets',
                'Replace one Bard spell with a spell of the same level from any class\'s spell list. Repeats at higher levels.'),
            _f(13, 'Bardic Inspiration (d10)', ''),
            _f(15, 'Words of Creation',
                'You always have the Power Word Heal and Power Word Kill spells prepared. Power Word Heal can target an additional creature you can see and Power Word Kill an additional creature with HP threshold.'),
            _f(17, 'Bardic Inspiration (d12)', ''),
            _f(19, 'Epic Boon', 'Recommended: Boon of Spell Recall.'),
            _f(20, 'Superior Bardic Inspiration',
                'Regain two uses of Bardic Inspiration when you roll Initiative.'),
          ],
        },
      ),

      // ─── Cleric ──────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Cleric',
        description:
            'Priestly champion who wields divine magic in service of a higher power. '
            'Hit Die d8. Wisdom-primary full caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Wisdom'),
          'hit_die': 'd8',
          'saving_throw_refs': [
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'skill_proficiency_choice_count': 2,
          'skill_proficiency_options': [
            lookup('skill', 'History'),
            lookup('skill', 'Insight'),
            lookup('skill', 'Medicine'),
            lookup('skill', 'Persuasion'),
            lookup('skill', 'Religion'),
          ],
          'weapon_proficiency_categories': [lookup('weapon-category', 'Simple')],
          'armor_training_refs': [
            lookup('armor-category', 'Light'),
            lookup('armor-category', 'Medium'),
            lookup('armor-category', 'Shield'),
          ],
          'caster_kind': 'Full',
          'casting_ability_ref': lookup('ability', 'Wisdom'),
          'complexity': 'Average',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Wisdom')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Chain Shirt, Shield, Mace, Holy Symbol, Priest\'s Pack, 7 GP',
                  items: [
                    eqItem('armor', 'Chain Shirt'),
                    eqItem('armor', 'Shield'),
                    eqItem('weapon', 'Mace'),
                    eqItem('adventuring-gear', 'Amulet (Holy Symbol)'),
                    eqItem('pack', 'Priest\'s Pack'),
                  ],
                  goldGp: 7,
                ),
                eqOption(optionId: 'B', label: '110 GP', goldGp: 110),
              ],
            ),
          ],
          'starting_gold_dice': '5d4 × 10',
          'features': [
            _f(1, 'Spellcasting', 'You know Cleric cantrips and prepare spells from the Cleric list. Wisdom is your spellcasting ability. Your Holy Symbol is your spellcasting focus.'),
            _f(1, 'Divine Order',
                'Choose Protector (gain proficiency with Martial weapons and Heavy armor training) or Thaumaturge (extra cantrip, add Wis mod to chosen Cleric cantrip\'s damage).'),
            _f(2, 'Channel Divinity',
                'You gain Divine Spark and Turn Undead. Use Channel Divinity twice per Short Rest.'),
            _f(3, 'Cleric Subclass',
                'Choose a subclass (Life Domain in this SRD).'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Sear Undead',
                'Replace Turn Undead with Sear Undead: undead within 30 ft of you that fail a Wis save take Radiant damage = your Cleric level.'),
            _f(7, 'Blessed Strikes',
                'Once per turn add 1d8 Radiant damage to a hit, or boost a cantrip\'s damage by 1d8.'),
            _f(10, 'Divine Intervention',
                'Once per long rest, you can plead for divine aid: choose a Cleric spell of level 5 or lower and cast it as part of this feature.'),
            _f(14, 'Improved Blessed Strikes', 'Damage increases to 2d8.'),
            _f(19, 'Epic Boon', ''),
            _f(20, 'Greater Divine Intervention',
                'When you use Divine Intervention you can cast any Cleric spell up to level 9 without expending a slot.'),
          ],
        },
      ),

      // ─── Druid ───────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Druid',
        description:
            'Priest of the Old Faith, wielding the powers of nature and adopting animal forms. '
            'Hit Die d8. Wisdom-primary full caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Wisdom'),
          'hit_die': 'd8',
          'saving_throw_refs': [
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
          ],
          'skill_proficiency_choice_count': 2,
          'weapon_proficiency_categories': [lookup('weapon-category', 'Simple')],
          'armor_training_refs': [
            lookup('armor-category', 'Light'),
            lookup('armor-category', 'Medium'),
            lookup('armor-category', 'Shield'),
          ],
          'caster_kind': 'Full',
          'casting_ability_ref': lookup('ability', 'Wisdom'),
          'complexity': 'High',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Wisdom')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Leather Armor, Shield, Sickle, Quarterstaff, Explorer\'s Pack, Herbalism Kit, 9 GP',
                  items: [
                    eqItem('armor', 'Leather Armor'),
                    eqItem('armor', 'Shield'),
                    eqItem('weapon', 'Sickle'),
                    eqItem('weapon', 'Quarterstaff'),
                    eqItem('pack', 'Explorer\'s Pack'),
                    eqItem('tool', 'Herbalism Kit'),
                  ],
                  goldGp: 9,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
          'starting_gold_dice': '2d4 × 10',
          'features': [
            _f(1, 'Spellcasting', 'You know Druid cantrips and prepare spells from the Druid list. Wisdom is your spellcasting ability. Your Druidic Focus is your spellcasting focus.'),
            _f(1, 'Druidic',
                'You know the secret druidic language. Bonus Action to leave a magical message understandable only to other druids.'),
            _f(1, 'Primal Order',
                'Choose Magician (extra cantrip + Arcana/Nature proficiency) or Warden (Martial weapon proficiency + Medium armor training).'),
            _f(2, 'Wild Shape',
                'Bonus Action to assume the form of a Beast you\'ve seen, of CR ≤ ¼ (no flying speed). Lasts up to half your Druid level in hours. Two uses per Short or Long Rest.'),
            _f(2, 'Wild Companion',
                'Expend a Wild Shape use to cast Find Familiar without material components; the familiar lasts until you finish a Long Rest.'),
            _f(3, 'Druid Subclass',
                'Choose a subclass (Circle of the Land in this SRD).'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Wild Resurgence',
                'Convert two Wild Shape uses into a level-1 spell slot, or vice versa, once per turn (no action).'),
            _f(7, 'Elemental Fury',
                'Choose Potent Spellcasting (add Wis mod to cantrip damage) or Primal Strike (your Wild Shape attacks count as magical for resistance).'),
            _f(15, 'Improved Elemental Fury', 'Improvements to chosen option.'),
            _f(18, 'Beast Spells',
                'Cast known/prepared Druid spells with V/S components only while in Wild Shape.'),
            _f(19, 'Epic Boon', ''),
            _f(20, 'Archdruid',
                'Unlimited Wild Shape uses; ignore Verbal/Somatic components and material components without cost while in Wild Shape; age 1 year for every 10 elapsed.'),
          ],
        },
      ),

      // ─── Fighter ─────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Fighter',
        description:
            'Master of martial combat, skilled with a variety of weapons and armor. '
            'Hit Die d10. Strength or Dexterity primary; non-caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Strength'),
          'secondary_ability_ref': lookup('ability', 'Dexterity'),
          'hit_die': 'd10',
          'saving_throw_refs': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Constitution'),
          ],
          'skill_proficiency_choice_count': 2,
          'weapon_proficiency_categories': [
            lookup('weapon-category', 'Simple'),
            lookup('weapon-category', 'Martial'),
          ],
          'armor_training_refs': [
            lookup('armor-category', 'Light'),
            lookup('armor-category', 'Medium'),
            lookup('armor-category', 'Heavy'),
            lookup('armor-category', 'Shield'),
          ],
          'caster_kind': 'None',
          'complexity': 'Average',
          'multiclass_prereq_ability_refs': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
          ],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Chain Mail, Greatsword, Flail, 8 Javelins, Dungeoneer\'s Pack, 4 GP',
                  items: [
                    eqItem('armor', 'Chain Mail'),
                    eqItem('weapon', 'Greatsword'),
                    eqItem('weapon', 'Flail'),
                    eqItem('weapon', 'Javelin', qty: 8),
                    eqItem('pack', 'Dungeoneer\'s Pack'),
                  ],
                  goldGp: 4,
                ),
                eqOption(
                  optionId: 'B',
                  label: 'Studded Leather, Scimitar, Shortsword, Longbow, 20 Arrows, Quiver, Dungeoneer\'s Pack, 11 GP',
                  items: [
                    eqItem('armor', 'Studded Leather Armor'),
                    eqItem('weapon', 'Scimitar'),
                    eqItem('weapon', 'Shortsword'),
                    eqItem('weapon', 'Longbow'),
                    eqItem('ammunition', 'Arrows', qty: 20),
                    eqItem('adventuring-gear', 'Quiver'),
                    eqItem('pack', 'Dungeoneer\'s Pack'),
                  ],
                  goldGp: 11,
                ),
                eqOption(optionId: 'C', label: '155 GP', goldGp: 155),
              ],
            ),
          ],
          'starting_gold_dice': '5d4 × 10',
          'features': [
            _f(1, 'Fighting Style',
                'Gain a Fighting Style feat (see "Feats"): Archery, Defense, Great Weapon Fighting, or Two-Weapon Fighting.'),
            _f(1, 'Second Wind',
                'Bonus Action: regain HP equal to 1d10 + your Fighter level. Number of uses scales (2 at L1, 3 at L4, 4 at L10). Regain on a Short or Long Rest.'),
            _f(1, 'Weapon Mastery',
                'Use the mastery property of three Simple/Martial weapons. Swap one choice on a Long Rest. More kinds unlock at higher levels.'),
            _f(2, 'Action Surge',
                'Once per Short/Long Rest, take an additional action on your turn (twice at L17).'),
            _f(2, 'Tactical Mind',
                'When you fail an ability check, you can spend a Second Wind use (without regaining HP) to roll 1d10 and add it; if it would still fail, no use is consumed.'),
            _f(3, 'Fighter Subclass',
                'Choose a subclass (Champion in this SRD).'),
            _f(4, 'Ability Score Improvement', 'Repeats at 6, 8, 12, 14, 16, 19.'),
            _f(5, 'Extra Attack', 'Attack twice when you take the Attack action; three times at L11; four times at L20.'),
            _f(9, 'Tactical Shift',
                'When you Second Wind, also move up to half your Speed without provoking Opportunity Attacks.'),
            _f(13, 'Studied Attacks',
                'When you miss a creature, your next attack on that creature before the end of your next turn has Advantage.'),
            _f(19, 'Epic Boon', 'Recommended: Boon of Combat Prowess.'),
            _f(20, 'Three Extra Attacks', 'Attack four times when you Attack.'),
          ],
        },
      ),

      // ─── Monk ────────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Monk',
        description:
            'Master of martial arts, harnessing the power of the body in pursuit of physical and spiritual perfection. '
            'Hit Die d8. Dexterity-primary, Wisdom-secondary.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Dexterity'),
          'secondary_ability_ref': lookup('ability', 'Wisdom'),
          'hit_die': 'd8',
          'saving_throw_refs': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
          ],
          'skill_proficiency_choice_count': 2,
          'weapon_proficiency_categories': [lookup('weapon-category', 'Simple')],
          'caster_kind': 'None',
          'complexity': 'High',
          'multiclass_prereq_ability_refs': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Wisdom'),
          ],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Spear, 5 Daggers, Explorer\'s Pack, 11 GP',
                  items: [
                    eqItem('weapon', 'Spear'),
                    eqItem('weapon', 'Dagger', qty: 5),
                    eqItem('pack', 'Explorer\'s Pack'),
                  ],
                  goldGp: 11,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
          'starting_gold_dice': '2d4 × 10',
          'features': [
            _f(1, 'Martial Arts',
                'While unarmed or using a Monk weapon and not in armor or wielding a Shield, you can use Dex instead of Str for attack/damage; your Martial Arts die replaces the weapon\'s damage die (d6 at L1, scaling); Bonus Action to make an Unarmed Strike after taking the Attack action.'),
            _f(1, 'Unarmored Defense',
                'While not in armor and not wielding a Shield, AC = 10 + Dex mod + Wis mod.'),
            _f(2, 'Monk\'s Focus',
                'You gain Focus Points equal to your Monk level. Spend Focus on Flurry of Blows, Patient Defense, and Step of the Wind. Regain on a Short or Long Rest.'),
            _f(2, 'Unarmored Movement', '+10 ft. Speed while unarmored, scaling with level.'),
            _f(3, 'Monk Subclass', 'Choose a subclass (Warrior of the Open Hand in this SRD).'),
            _f(3, 'Deflect Attacks',
                'Reaction to reduce the damage from one ranged or melee attack by 1d10 + Dex + Monk level; if reduced to 0 damage and ranged, redirect at a target within 60 ft.'),
            _f(4, 'Slow Fall', 'Reaction to reduce falling damage by 5 × Monk level.'),
            _f(5, 'Extra Attack', 'Attack twice when you Attack.'),
            _f(5, 'Stunning Strike',
                'When you hit with a Monk weapon or Unarmed Strike, spend 1 Focus Point to force the target to make a Con save or be Stunned until the end of your next turn.'),
            _f(6, 'Empowered Strikes', 'Your Unarmed Strikes count as magical and you can make their damage Force.'),
            _f(7, 'Evasion',
                'When you make a Dex save against an effect that does half damage on a success, you take none on a success and half on a failure.'),
            _f(9, 'Acrobatic Movement', 'You can move along vertical surfaces and across liquids without falling while you move at least 10 feet.'),
            _f(13, 'Deflect Energy', 'Deflect Attacks now applies to spells/effects that deal damage; redirect costs Focus.'),
            _f(15, 'Perfect Focus',
                'When you roll Initiative with fewer than 4 Focus Points, regain to 4.'),
            _f(18, 'Superior Defense', 'Bonus Action to gain Resistance to all damage except Force for 1 minute (cost 3 Focus).'),
            _f(19, 'Epic Boon', ''),
            _f(20, 'Body and Mind', 'Dex and Wis scores increase by 4, max 25.'),
          ],
        },
      ),

      // ─── Paladin ─────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Paladin',
        description:
            'Holy warrior bound to a sacred oath. Hit Die d10. Strength-primary, Charisma-secondary half-caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Strength'),
          'secondary_ability_ref': lookup('ability', 'Charisma'),
          'hit_die': 'd10',
          'saving_throw_refs': [
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'skill_proficiency_choice_count': 2,
          'weapon_proficiency_categories': [
            lookup('weapon-category', 'Simple'),
            lookup('weapon-category', 'Martial'),
          ],
          'armor_training_refs': [
            lookup('armor-category', 'Light'),
            lookup('armor-category', 'Medium'),
            lookup('armor-category', 'Heavy'),
            lookup('armor-category', 'Shield'),
          ],
          'caster_kind': 'Half',
          'casting_ability_ref': lookup('ability', 'Charisma'),
          'complexity': 'Average',
          'multiclass_prereq_ability_refs': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Charisma'),
          ],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Chain Mail, Shield, Longsword, 6 Javelins, Holy Symbol, Priest\'s Pack, 9 GP',
                  items: [
                    eqItem('armor', 'Chain Mail'),
                    eqItem('armor', 'Shield'),
                    eqItem('weapon', 'Longsword'),
                    eqItem('weapon', 'Javelin', qty: 6),
                    eqItem('adventuring-gear', 'Amulet (Holy Symbol)'),
                    eqItem('pack', 'Priest\'s Pack'),
                  ],
                  goldGp: 9,
                ),
                eqOption(optionId: 'B', label: '150 GP', goldGp: 150),
              ],
            ),
          ],
          'starting_gold_dice': '5d4 × 10',
          'features': [
            _f(1, 'Lay On Hands',
                'Pool of healing equal to 5 × Paladin level. Spend points one at a time to restore HP or to cure one disease/poison (cost 5).'),
            _f(1, 'Spellcasting',
                'Half-caster on the Paladin list; Charisma is your spellcasting ability; your Holy Symbol is your spellcasting focus.'),
            _f(1, 'Weapon Mastery', 'Use the mastery property of two kinds of weapons; swap on a Long Rest.'),
            _f(2, 'Fighting Style', 'Gain a Fighting Style feat.'),
            _f(2, 'Paladin\'s Smite',
                'Always have Divine Smite prepared (no slot count). When you hit with a Melee weapon or Unarmed Strike, expend a spell slot of any level to deal extra Radiant damage = 2d8 + 1d8 per slot level above 1 (max 5d8).'),
            _f(3, 'Paladin Subclass', 'Choose a subclass (Oath of Devotion in this SRD).'),
            _f(3, 'Channel Divinity', 'Use Channel Divinity twice per Short Rest.'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Extra Attack', ''),
            _f(5, 'Faithful Steed', 'You always have Find Steed prepared.'),
            _f(6, 'Aura of Protection',
                'You and friendly creatures within 10 feet of you gain a bonus to saving throws equal to your Charisma modifier (min +1).'),
            _f(9, 'Abjure Foes',
                'Once per Long Rest as a Magic action, force creatures of your choice within 60 feet to make a Wisdom save or have the Frightened condition until the end of your next turn (additional save effects at higher levels).'),
            _f(11, 'Radiant Strikes', 'Once per turn, when you hit with a weapon, deal +1d8 Radiant damage.'),
            _f(14, 'Restoring Touch', 'Spend Lay On Hands points to also remove charmed/frightened/paralyzed/stunned conditions.'),
            _f(18, 'Aura Expansion', 'Aura of Protection range increases to 30 feet.'),
            _f(19, 'Epic Boon', ''),
            _f(20, 'Subclass capstone', 'Per chosen subclass.'),
          ],
        },
      ),

      // ─── Ranger ──────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Ranger',
        description:
            'Warrior of the wilderness skilled at tracking, survival, and primal magic. '
            'Hit Die d10. Dexterity-primary, Wisdom-secondary half-caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Dexterity'),
          'secondary_ability_ref': lookup('ability', 'Wisdom'),
          'hit_die': 'd10',
          'saving_throw_refs': [
            lookup('ability', 'Strength'),
            lookup('ability', 'Dexterity'),
          ],
          'skill_proficiency_choice_count': 3,
          'weapon_proficiency_categories': [
            lookup('weapon-category', 'Simple'),
            lookup('weapon-category', 'Martial'),
          ],
          'armor_training_refs': [
            lookup('armor-category', 'Light'),
            lookup('armor-category', 'Medium'),
            lookup('armor-category', 'Shield'),
          ],
          'caster_kind': 'Half',
          'casting_ability_ref': lookup('ability', 'Wisdom'),
          'complexity': 'Average',
          'multiclass_prereq_ability_refs': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Wisdom'),
          ],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Studded Leather, Scimitar, Shortsword, Longbow, 20 Arrows, Quiver, Explorer\'s Pack, 7 GP',
                  items: [
                    eqItem('armor', 'Studded Leather Armor'),
                    eqItem('weapon', 'Scimitar'),
                    eqItem('weapon', 'Shortsword'),
                    eqItem('weapon', 'Longbow'),
                    eqItem('ammunition', 'Arrows', qty: 20),
                    eqItem('adventuring-gear', 'Quiver'),
                    eqItem('pack', 'Explorer\'s Pack'),
                  ],
                  goldGp: 7,
                ),
                eqOption(optionId: 'B', label: '150 GP', goldGp: 150),
              ],
            ),
          ],
          'starting_gold_dice': '5d4 × 10',
          'features': [
            _f(1, 'Favored Enemy',
                'You always have Hunter\'s Mark prepared and can cast it without a slot a number of times = your Wis mod (min 1) per Long Rest.'),
            _f(1, 'Spellcasting',
                'Half-caster on the Ranger list; Wisdom is your spellcasting ability; you use a Druidic Focus.'),
            _f(1, 'Weapon Mastery', 'Use the mastery property of two kinds of weapons.'),
            _f(2, 'Deft Explorer',
                'Gain Expertise in one of your skill proficiencies; learn an extra language. More benefits at higher levels.'),
            _f(2, 'Fighting Style', 'Gain a Fighting Style feat.'),
            _f(3, 'Ranger Subclass', 'Choose a subclass (Hunter in this SRD).'),
            _f(3, 'Roving', '+5 ft. Speed; you have a Climb Speed and Swim Speed equal to your Speed.'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Extra Attack', ''),
            _f(9, 'Expertise', 'Choose two skills you\'re proficient in for Expertise.'),
            _f(10, 'Tireless',
                'You can grant yourself temporary HP equal to a roll of 1d8 + Wisdom modifier as a Magic action. Number of uses = Wis mod per Long Rest. You also reduce Exhaustion levels on a Short Rest.'),
            _f(13, 'Relentless Hunter', 'Damage taken doesn\'t break your Concentration on Hunter\'s Mark.'),
            _f(14, 'Nature\'s Veil',
                'As a Bonus Action, expend a level 1+ slot to give yourself the Invisible condition until the end of your next turn.'),
            _f(18, 'Feral Senses',
                'You don\'t suffer Disadvantage on attacks against unseen creatures within 30 feet.'),
            _f(19, 'Epic Boon', ''),
            _f(20, 'Foe Slayer',
                'Hunter\'s Mark damage die becomes 1d10. Once on each of your turns you can deal +Wis mod damage to a Hunter\'s Mark target.'),
          ],
        },
      ),

      // ─── Rogue ───────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Rogue',
        description:
            'Scoundrel who uses stealth and trickery to overcome obstacles. '
            'Hit Die d8. Dexterity-primary; non-caster (subclass dependent).',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Dexterity'),
          'hit_die': 'd8',
          'saving_throw_refs': [
            lookup('ability', 'Dexterity'),
            lookup('ability', 'Intelligence'),
          ],
          'skill_proficiency_choice_count': 4,
          'weapon_proficiency_categories': [lookup('weapon-category', 'Simple')],
          'armor_training_refs': [lookup('armor-category', 'Light')],
          'caster_kind': 'None',
          'complexity': 'Average',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Dexterity')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Leather Armor, 2 Daggers, Shortsword, Shortbow, 20 Arrows, Quiver, Thieves\' Tools, Burglar\'s Pack, 8 GP',
                  items: [
                    eqItem('armor', 'Leather Armor'),
                    eqItem('weapon', 'Dagger', qty: 2),
                    eqItem('weapon', 'Shortsword'),
                    eqItem('weapon', 'Shortbow'),
                    eqItem('ammunition', 'Arrows', qty: 20),
                    eqItem('adventuring-gear', 'Quiver'),
                    eqItem('tool', 'Thieves\' Tools'),
                    eqItem('pack', 'Burglar\'s Pack'),
                  ],
                  goldGp: 8,
                ),
                eqOption(optionId: 'B', label: '100 GP', goldGp: 100),
              ],
            ),
          ],
          'starting_gold_dice': '4d4 × 10',
          'features': [
            _f(1, 'Expertise',
                'Gain Expertise in two of your skill proficiencies. More skills at higher levels.'),
            _f(1, 'Sneak Attack',
                'Once per turn, deal +1d6 damage to a target you hit with a Finesse or Ranged weapon when you have Advantage on the attack OR when an ally is within 5 feet of the target. Damage scales with level.'),
            _f(1, 'Thieves\' Cant',
                'You know Thieves\' Cant and a signed version of it.'),
            _f(1, 'Weapon Mastery', 'Use the mastery property of two kinds of weapons.'),
            _f(2, 'Cunning Action',
                'Bonus Action: Dash, Disengage, or Hide.'),
            _f(3, 'Rogue Subclass', 'Choose a subclass (Thief in this SRD).'),
            _f(3, 'Steady Aim',
                'As a Bonus Action while you haven\'t moved this turn, give yourself Advantage on your next attack roll this turn; your Speed becomes 0 until the end of the turn.'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Cunning Strike',
                'When you hit with Sneak Attack, you can spend dice to apply effects (Poison, Trip, Withdraw, etc.).'),
            _f(5, 'Uncanny Dodge',
                'Reaction: halve the damage of an attack you can see hit you.'),
            _f(7, 'Evasion',
                'On a Dex save against an area effect, take no damage on success and half on fail.'),
            _f(7, 'Reliable Talent',
                'Treat any d20 roll of 9 or lower as a 10 on ability checks where you have proficiency.'),
            _f(11, 'Improved Cunning Strike', 'Apply two Cunning Strike effects per Sneak Attack.'),
            _f(14, 'Devious Strikes', 'New Cunning Strike options: Daze, Knock Out, Obscure.'),
            _f(15, 'Slippery Mind',
                'Gain proficiency in Wisdom and Charisma saving throws.'),
            _f(18, 'Elusive',
                'No attack roll has Advantage against you while you\'re not Incapacitated.'),
            _f(19, 'Epic Boon', ''),
            _f(20, 'Stroke of Luck',
                'Once per Short or Long Rest, treat one missed attack as a hit, or one failed ability check as 20.'),
          ],
        },
      ),

      // ─── Sorcerer ────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Sorcerer',
        description:
            'Spellcaster who draws on inherent magic from a gift or bloodline. '
            'Hit Die d6. Charisma-primary full caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Charisma'),
          'hit_die': 'd6',
          'saving_throw_refs': [
            lookup('ability', 'Constitution'),
            lookup('ability', 'Charisma'),
          ],
          'skill_proficiency_choice_count': 2,
          'weapon_proficiency_categories': [lookup('weapon-category', 'Simple')],
          'caster_kind': 'Full',
          'casting_ability_ref': lookup('ability', 'Charisma'),
          'complexity': 'High',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Charisma')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Spear, 2 Daggers, Arcane Focus (Crystal), Dungeoneer\'s Pack, 28 GP',
                  items: [
                    eqItem('weapon', 'Spear'),
                    eqItem('weapon', 'Dagger', qty: 2),
                    eqItem('adventuring-gear', 'Crystal'),
                    eqItem('pack', 'Dungeoneer\'s Pack'),
                  ],
                  goldGp: 28,
                ),
                eqOption(optionId: 'B', label: '50 GP', goldGp: 50),
              ],
            ),
          ],
          'starting_gold_dice': '3d4 × 10',
          'features': [
            _f(1, 'Spellcasting', 'Sorcerer cantrips/spells. Charisma is your casting ability.'),
            _f(1, 'Innate Sorcery',
                'Bonus Action: gain Advantage on Sorcerer spell attack rolls and increase the save DC by 1 for 1 minute. Number of uses = your Cha mod (min 1) per Long Rest.'),
            _f(2, 'Font of Magic',
                'Gain Sorcery Points equal to your Sorcerer level. Convert SP ↔ slots: 1→2 SP regen, 2→1 slot at L1, etc.'),
            _f(2, 'Metamagic',
                'Choose two Metamagic options. Add more at higher levels.'),
            _f(3, 'Sorcerer Subclass', 'Choose a subclass (Draconic Sorcery in this SRD).'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Sorcerous Restoration', 'Once per Short Rest, recover 4 expended Sorcery Points.'),
            _f(7, 'Sorcery Incarnate',
                'You can use Innate Sorcery as a free action when you cast a Sorcerer spell, even when you\'re out of uses (cost: 2 SP).'),
            _f(10, 'Metamagic (extra)', 'Learn an additional Metamagic option.'),
            _f(17, 'Metamagic (extra II)', ''),
            _f(19, 'Epic Boon', 'Recommended: Boon of Spell Recall.'),
            _f(20, 'Arcane Apotheosis',
                'When you use Innate Sorcery, you can apply one Metamagic option of your choice without expending Sorcery Points.'),
          ],
        },
      ),

      // ─── Warlock ─────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Warlock',
        description:
            'Wielder of magic granted by a pact with an otherworldly being. '
            'Hit Die d8. Charisma-primary pact caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Charisma'),
          'hit_die': 'd8',
          'saving_throw_refs': [
            lookup('ability', 'Wisdom'),
            lookup('ability', 'Charisma'),
          ],
          'skill_proficiency_choice_count': 2,
          'weapon_proficiency_categories': [lookup('weapon-category', 'Simple')],
          'armor_training_refs': [lookup('armor-category', 'Light')],
          'caster_kind': 'Pact',
          'casting_ability_ref': lookup('ability', 'Charisma'),
          'complexity': 'High',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Charisma')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: 'Leather Armor, Sickle, 2 Daggers, Arcane Focus (Orb), Book, Scholar\'s Pack, 15 GP',
                  items: [
                    eqItem('armor', 'Leather Armor'),
                    eqItem('weapon', 'Sickle'),
                    eqItem('weapon', 'Dagger', qty: 2),
                    eqItem('adventuring-gear', 'Orb'),
                    eqItem('adventuring-gear', 'Book'),
                    eqItem('pack', 'Scholar\'s Pack'),
                  ],
                  goldGp: 15,
                ),
                eqOption(optionId: 'B', label: '100 GP', goldGp: 100),
              ],
            ),
          ],
          'starting_gold_dice': '4d4 × 10',
          'features': [
            _f(1, 'Eldritch Invocations',
                'Choose two Eldritch Invocations. Add more at higher levels.'),
            _f(1, 'Pact Magic',
                'Pact spell slots regain on a Short or Long Rest. Number of slots scales (1→4); slot level scales separately. Charisma is your spellcasting ability.'),
            _f(2, 'Magical Cunning',
                'On a Short Rest, regain expended pact slots equal to half your max (rounded up). Once per Long Rest.'),
            _f(3, 'Warlock Subclass', 'Choose a subclass (Fiend Patron in this SRD).'),
            _f(3, 'Pact Boon', 'Choose Pact of the Blade, Chain, or Tome.'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Mystic Arcanum (Level 6 Spell)', ''),
            _f(7, 'Mystic Arcanum (Level 7 Spell)', ''),
            _f(9, 'Mystic Arcanum (Level 8 Spell)', ''),
            _f(11, 'Mystic Arcanum (Level 9 Spell)', ''),
            _f(13, 'Eldritch Master',
                'You can spend 1 minute to plead with your patron and regain all expended pact slots; once per Long Rest.'),
            _f(19, 'Epic Boon', ''),
            _f(20, 'Eldritch Resilience', 'Bonus uses of Magical Cunning; resists patron sundering.'),
          ],
        },
      ),

      // ─── Wizard ──────────────────────────────────────────────────────────
      packEntity(
        slug: 'class',
        name: 'Wizard',
        description:
            'Scholarly magic-user capable of manipulating the structures of reality. '
            'Hit Die d6. Intelligence-primary full caster.',
        attributes: {
          'primary_ability_ref': lookup('ability', 'Intelligence'),
          'hit_die': 'd6',
          'saving_throw_refs': [
            lookup('ability', 'Intelligence'),
            lookup('ability', 'Wisdom'),
          ],
          'skill_proficiency_choice_count': 2,
          'weapon_proficiency_categories': [lookup('weapon-category', 'Simple')],
          'caster_kind': 'Full',
          'casting_ability_ref': lookup('ability', 'Intelligence'),
          'complexity': 'High',
          'multiclass_prereq_ability_refs': [lookup('ability', 'Intelligence')],
          'multiclass_prereq_min_score': 13,
          'equipment_choice_groups': [
            eqGroup(
              groupId: 'starting_kit',
              label: 'Starting Equipment',
              options: [
                eqOption(
                  optionId: 'A',
                  label: '2 Daggers, Arcane Focus (Quarterstaff), Robe, Spellbook, Scholar\'s Pack, 5 GP',
                  items: [
                    eqItem('weapon', 'Dagger', qty: 2),
                    eqItem('weapon', 'Quarterstaff'),
                    eqItem('adventuring-gear', 'Robe'),
                    eqItem('pack', 'Scholar\'s Pack'),
                  ],
                  goldGp: 5,
                ),
                eqOption(optionId: 'B', label: '55 GP', goldGp: 55),
              ],
            ),
          ],
          'starting_gold_dice': '4d4 × 10',
          'features': [
            _f(1, 'Spellcasting',
                'You know a number of cantrips and prepare wizard spells from your spellbook. Intelligence is your spellcasting ability.'),
            _f(1, 'Ritual Adept',
                'Cast spells with the Ritual tag without expending a spell slot — even if not prepared, as long as in your spellbook.'),
            _f(1, 'Arcane Recovery',
                'Once per day after a Short Rest, recover spell slots whose combined level ≤ ½ your wizard level (rounded up); none of those slots can be 6th level or higher.'),
            _f(2, 'Scholar',
                'Choose Arcana, History, Investigation, Medicine, Nature, or Religion. You gain Expertise in that skill.'),
            _f(3, 'Wizard Subclass', 'Choose a subclass (Evoker in this SRD).'),
            _f(4, 'Ability Score Improvement', ''),
            _f(5, 'Memorize Spell',
                'After a Short Rest, replace one prepared wizard spell with another from your spellbook of the same level.'),
            _f(18, 'Spell Mastery',
                'Choose a level 1 and level 2 wizard spell you have prepared; cast each at lowest level without using a spell slot.'),
            _f(19, 'Epic Boon', 'Recommended: Boon of Spell Recall.'),
            _f(20, 'Signature Spells',
                'Choose two level 3 wizard spells from your spellbook; you always have them prepared and can cast each once without a spell slot per Short or Long Rest.'),
          ],
        },
      ),
    ];
