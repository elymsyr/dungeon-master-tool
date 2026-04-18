/// D&D 5e SRD 5.2.1 tabloları — V3 rule engine için.
///
/// Rule'lar `ValueExpressionV3.tableLookup` + `FieldRef(RefScope.self,
/// 'pb_table')` ile bu tabloları okur. Default schema builder entity'nin
/// fields'ine bu map'leri default olarak set eder (`Map<String, num>`).
library;

/// Proficiency bonus by total character level.
/// `Map<String, num>` — json_serializable tableLookup uyumlu (int key → string).
const Map<String, int> kPbByLevel = {
  '1': 2, '2': 2, '3': 2, '4': 2,
  '5': 3, '6': 3, '7': 3, '8': 3,
  '9': 4, '10': 4, '11': 4, '12': 4,
  '13': 5, '14': 5, '15': 5, '16': 5,
  '17': 6, '18': 6, '19': 6, '20': 6,
};

/// Full-caster spell slots table.
/// `kFullCasterSlots[<class level>][<spell level>]` → int slot count.
/// Wizard, Cleric, Sorcerer, Bard, Druid.
const Map<String, Map<String, int>> kFullCasterSlots = {
  '1': {'1': 2},
  '2': {'1': 3},
  '3': {'1': 4, '2': 2},
  '4': {'1': 4, '2': 3},
  '5': {'1': 4, '2': 3, '3': 2},
  '6': {'1': 4, '2': 3, '3': 3},
  '7': {'1': 4, '2': 3, '3': 3, '4': 1},
  '8': {'1': 4, '2': 3, '3': 3, '4': 2},
  '9': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 1},
  '10': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2},
  '11': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1},
  '12': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1},
  '13': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1},
  '14': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1},
  '15': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1, '8': 1},
  '16': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1, '8': 1},
  '17': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2, '6': 1, '7': 1, '8': 1, '9': 1},
  '18': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 3, '6': 1, '7': 1, '8': 1, '9': 1},
  '19': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 3, '6': 2, '7': 1, '8': 1, '9': 1},
  '20': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 3, '6': 2, '7': 2, '8': 1, '9': 1},
};

/// Half-caster spell slots (Paladin, Ranger).
const Map<String, Map<String, int>> kHalfCasterSlots = {
  '1': {},
  '2': {'1': 2},
  '3': {'1': 3},
  '4': {'1': 3},
  '5': {'1': 4, '2': 2},
  '6': {'1': 4, '2': 2},
  '7': {'1': 4, '2': 3},
  '8': {'1': 4, '2': 3},
  '9': {'1': 4, '2': 3, '3': 2},
  '10': {'1': 4, '2': 3, '3': 2},
  '11': {'1': 4, '2': 3, '3': 3},
  '12': {'1': 4, '2': 3, '3': 3},
  '13': {'1': 4, '2': 3, '3': 3, '4': 1},
  '14': {'1': 4, '2': 3, '3': 3, '4': 1},
  '15': {'1': 4, '2': 3, '3': 3, '4': 2},
  '16': {'1': 4, '2': 3, '3': 3, '4': 2},
  '17': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 1},
  '18': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 1},
  '19': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2},
  '20': {'1': 4, '2': 3, '3': 3, '4': 3, '5': 2},
};

/// Barbarian rage uses by level.
const Map<String, int> kRageUsesByLevel = {
  '1': 2, '2': 2, '3': 3, '4': 3, '5': 3, '6': 4, '7': 4, '8': 4,
  '9': 4, '10': 4, '11': 4, '12': 5, '13': 5, '14': 5, '15': 5,
  '16': 5, '17': 6, '18': 6, '19': 6, '20': 999, // L20 unlimited
};

/// Barbarian rage damage bonus by level.
const Map<String, int> kRageDamageByLevel = {
  '1': 2, '2': 2, '3': 2, '4': 2, '5': 2, '6': 2, '7': 2, '8': 2,
  '9': 3, '10': 3, '11': 3, '12': 3, '13': 3, '14': 3, '15': 3,
  '16': 4, '17': 4, '18': 4, '19': 4, '20': 4,
};

/// Hit dice side per class (die size).
const Map<String, int> kHitDiceSizeByClass = {
  'barbarian': 12,
  'fighter': 10,
  'paladin': 10,
  'ranger': 10,
  'bard': 8,
  'cleric': 8,
  'druid': 8,
  'monk': 8,
  'rogue': 8,
  'warlock': 8,
  'sorcerer': 6,
  'wizard': 6,
};

/// Armor base AC lookup (plate/chain/leather/...).
const Map<String, int> kArmorBaseAc = {
  'padded': 11,
  'leather': 11,
  'studded-leather': 12,
  'hide': 12,
  'chain-shirt': 13,
  'scale-mail': 14,
  'breastplate': 14,
  'half-plate': 15,
  'ring-mail': 14,
  'chain-mail': 16,
  'splint': 17,
  'plate': 18,
};

/// Armor DEX cap: null = full dex; int = cap amount; 0 = no dex.
const Map<String, int?> kArmorDexCap = {
  'padded': null,
  'leather': null,
  'studded-leather': null,
  'hide': 2,
  'chain-shirt': 2,
  'scale-mail': 2,
  'breastplate': 2,
  'half-plate': 2,
  'ring-mail': 0,
  'chain-mail': 0,
  'splint': 0,
  'plate': 0,
};

/// Full-caster class slugs.
const Set<String> kFullCasterClasses = {
  'wizard', 'cleric', 'sorcerer', 'bard', 'druid',
};

/// Half-caster class slugs.
const Set<String> kHalfCasterClasses = {'paladin', 'ranger'};

/// Default entity fields map'ine table'ları inject eden helper.
/// Schema builder `fieldsDefault` üretirken çağırır — rule'lar bu key'leri
/// `FieldRef(self, '<tableKey>')` ile okuyabilir.
Map<String, dynamic> seedDnd5eTables() {
  return {
    'pb_table': Map<String, num>.from(kPbByLevel),
    'full_caster_slots_table': kFullCasterSlots.map(
      (k, v) => MapEntry(k, Map<String, num>.from(v)),
    ),
    'half_caster_slots_table': kHalfCasterSlots.map(
      (k, v) => MapEntry(k, Map<String, num>.from(v)),
    ),
    'rage_uses_table': Map<String, num>.from(kRageUsesByLevel),
    'rage_damage_table': Map<String, num>.from(kRageDamageByLevel),
    'hit_dice_size_by_class': Map<String, num>.from(kHitDiceSizeByClass),
  };
}
