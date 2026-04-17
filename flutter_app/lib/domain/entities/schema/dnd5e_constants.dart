/// D&D 5e sabit referans tabloları.
/// Skills/saving throws presetleri, proficiency bonus tablosu, ability listesi.
library;

/// D&D 5e ability kısaltmaları (ProficiencyTable row.ability için).
const kDnd5eAbilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

/// Proficiency bonus by character level (1–20).
/// L1–4: +2, L5–8: +3, L9–12: +4, L13–16: +5, L17–20: +6.
int proficiencyBonusForLevel(int level) {
  if (level <= 0) return 2;
  if (level >= 17) return 6;
  if (level >= 13) return 5;
  if (level >= 9) return 4;
  if (level >= 5) return 3;
  return 2;
}

/// `ability_mod = floor((score - 10) / 2)`.
int abilityModifier(int score) {
  final diff = score - 10;
  return (diff < 0 && diff.isOdd) ? (diff ~/ 2) - 1 : diff ~/ 2;
}

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
