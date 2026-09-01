/// D&D 5e sabit referans tabloları.
/// Skills/saving throws presetleri, proficiency bonus tablosu, ability listesi.
library;

import 'rule_config.dart';

/// D&D 5e ability kısaltmaları (ProficiencyTable row.ability için).
const kDnd5eAbilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

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

/// Kayıtlı proficiency-table değerini şablon default'ıyla birleştirir.
///
/// Blueprint / paket verisi tabloyu kısa yazıyor: yalnızca proficient olan
/// satırlar (`{name, ability, proficient: true}`). Bu değer olduğu gibi
/// gösterilirse tablonun kalan 13 skill'i / 4 save'i hiç görünmez. Preset
/// satır listesi taban alınır, kayıtlı satır aynı `name` üstüne yazılır;
/// preset'te olmayan custom satırlar sona eklenir.
Map<String, dynamic> mergeProficiencyRows(Object? defaultValue, Object? stored) {
  List<Map<String, dynamic>> rowsOf(Object? v) => (v is Map && v['rows'] is List)
      ? [
          for (final r in v['rows'] as List)
            if (r is Map) Map<String, dynamic>.from(r)
        ]
      : const [];

  final base = rowsOf(defaultValue);
  final storedRows = rowsOf(stored);
  if (base.isEmpty) return {'rows': storedRows};
  final byName = {for (final r in storedRows) '${r['name']}': r};
  final out = <Map<String, dynamic>>[];
  for (final r in base) {
    final s = byName.remove('${r['name']}');
    out.add(s == null ? r : {...r, ...s});
  }
  out.addAll(byName.values);
  return {'rows': out};
}
