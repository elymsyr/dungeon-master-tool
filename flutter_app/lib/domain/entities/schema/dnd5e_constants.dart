/// D&D 5e sabit referans tabloları.
/// Skills/saving throws presetleri, proficiency bonus tablosu, ability listesi.
library;

import 'rules/rule_config.dart';

/// D&D 5e ability kısaltmaları (ProficiencyTable row.ability için).
const kDnd5eAbilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

/// Proficiency bonus by character level (1–20). Delegates to the single
/// [RuleConfig] source so the sheet, wizard and planner never diverge.
int proficiencyBonusForLevel(int level) =>
    RuleConfig.dnd5eDefaults.proficiencyBonusFor(level < 1 ? 1 : level);

/// `ability_mod = floor((score - 10) / 2)`. Delegates to [RuleConfig].
int abilityModifier(int score) =>
    RuleConfig.dnd5eDefaults.abilityModifier(score);

/// Tek bir proficiency-table satırı (skill / saving throw).
/// Preset olarak gömülür; kullanıcı değer girdiğinde bu satırlar üstüne
/// `proficient`, `expertise`, `misc` değerleri yazılır.
class ProficiencyRowPreset {
  final String name;
  final String ability;

  const ProficiencyRowPreset(this.name, this.ability);
}

/// 18 standart D&D 5e skill (CON'un skill'i yok).
const kDnd5eSkills = <ProficiencyRowPreset>[
  ProficiencyRowPreset('Acrobatics', 'DEX'),
  ProficiencyRowPreset('Animal Handling', 'WIS'),
  ProficiencyRowPreset('Arcana', 'INT'),
  ProficiencyRowPreset('Athletics', 'STR'),
  ProficiencyRowPreset('Deception', 'CHA'),
  ProficiencyRowPreset('History', 'INT'),
  ProficiencyRowPreset('Insight', 'WIS'),
  ProficiencyRowPreset('Intimidation', 'CHA'),
  ProficiencyRowPreset('Investigation', 'INT'),
  ProficiencyRowPreset('Medicine', 'WIS'),
  ProficiencyRowPreset('Nature', 'INT'),
  ProficiencyRowPreset('Perception', 'WIS'),
  ProficiencyRowPreset('Performance', 'CHA'),
  ProficiencyRowPreset('Persuasion', 'CHA'),
  ProficiencyRowPreset('Religion', 'INT'),
  ProficiencyRowPreset('Sleight of Hand', 'DEX'),
  ProficiencyRowPreset('Stealth', 'DEX'),
  ProficiencyRowPreset('Survival', 'WIS'),
];

/// 6 standart saving throw (her ability için bir).
const kDnd5eSavingThrows = <ProficiencyRowPreset>[
  ProficiencyRowPreset('Strength', 'STR'),
  ProficiencyRowPreset('Dexterity', 'DEX'),
  ProficiencyRowPreset('Constitution', 'CON'),
  ProficiencyRowPreset('Intelligence', 'INT'),
  ProficiencyRowPreset('Wisdom', 'WIS'),
  ProficiencyRowPreset('Charisma', 'CHA'),
];

/// ProficiencyTable default value — presetten `Map<String, dynamic>` üretir.
/// Shape: `{rows: [{name, ability, proficient, expertise, misc}]}`.
/// Widget bu değeri okur, ability modifier + PB türevlerini runtime'da hesaplar.
Map<String, dynamic> proficiencyTableDefault(List<ProficiencyRowPreset> preset) {
  return {
    'rows': preset
        .map((p) => {
              'name': p.name,
              'ability': p.ability,
              'proficient': false,
              'expertise': false,
              'misc': 0,
            })
        .toList(),
  };
}
