/// TR-to-EN translation maps for migrating legacy Python campaign data.
///
/// The old Python app (core/models.py) stored category names and field labels
/// in Turkish. These maps translate them to the Flutter slug / fieldKey
/// equivalents defined in `default_dnd5e_schema.dart`.
///
/// See also: Python `SCHEMA_MAP`, `PROPERTY_MAP`, `get_default_entity_structure()`.
library;

// ---------------------------------------------------------------------------
// 1. schemaMap — Turkish (and English) category name  ->  Flutter slug
// ---------------------------------------------------------------------------

/// Maps legacy category names to their Flutter category slugs.
///
/// Includes both the original Turkish labels from `SCHEMA_MAP` and the
/// English names so that either form resolves correctly.
const Map<String, String> schemaMap = {
  // Turkish labels (Python SCHEMA_MAP keys)
  'Canavar': 'monster',
  'Büyü (Spell)': 'spell',
  'Eşya (Equipment)': 'equipment',
  'Sınıf (Class)': 'class',
  'Irk (Race)': 'race',
  'Mekan': 'location',
  'Oyuncu': 'player',
  'Görev': 'quest',
  'Lore': 'lore',
  'Durum Etkisi': 'status-effect',
  'Feat': 'feat',
  'Background': 'background',
  'Plane': 'plane',
  'Condition': 'condition',

  // English names (Python SCHEMA_MAP values + extra Flutter categories)
  'NPC': 'npc',
  'Monster': 'monster',
  'Player': 'player',
  'Spell': 'spell',
  'Equipment': 'equipment',
  'Class': 'class',
  'Race': 'race',
  'Location': 'location',
  'Quest': 'quest',
  'Status Effect': 'status-effect',
  'Trait': 'trait',
  'Action': 'action',
  'Reaction': 'reaction',
  'Legendary Action': 'legendary-action',
};

// ---------------------------------------------------------------------------
// 2. propertyMap — Turkish field label  ->  Flutter fieldKey
// ---------------------------------------------------------------------------

/// Maps legacy Turkish property labels to their Flutter `FieldSchema.fieldKey`.
///
/// The Python app mapped these to `LBL_*` constants; here we skip that
/// indirection and go straight to the fieldKey strings used in
/// `default_dnd5e_schema.dart`.
const Map<String, String> propertyMap = {
  // NPC / Player / Monster shared fields
  'Irk': 'race',
  'Sınıf': 'class_',
  'Seviye': 'level',
  'Tavır': 'attitude',
  'Konum': 'location',

  // Monster
  'Challenge Rating (CR)': 'cr',
  'Saldırı Tipi': 'attack_type',

  // Spell
  'Okul (School)': 'school',
  'Süre (Casting Time)': 'casting_time',
  'Menzil (Range)': 'range',
  'Menzil': 'range',
  'Süreklilik (Duration)': 'duration',
  'Bileşenler (Components)': 'components',

  // Equipment
  'Kategori': 'category',
  'Nadirik (Rarity)': 'rarity',
  'Uyumlanma (Attunement)': 'attunement',
  'Maliyet': 'cost',
  'Ağırlık': 'weight',
  'Hasar Zarı': 'damage_dice',
  'Hasar Tipi': 'damage_type',
  'Zırh Sınıfı (AC)': 'ac',
  'Gereksinimler': 'requirements',
  'Özellikler': 'properties',

  // Class
  'Hit Die': 'hit_die',
  'Ana Statlar': 'main_stats',
  'Zırh/Silah Yetkinlikleri': 'proficiencies',

  // Race
  'Hız': 'speed',
  'Boyut': 'size',
  'Hizalanma Eğilimi': 'alignment',
  'Dil': 'language',

  // Location
  'Tehlike Seviyesi': 'danger_level',
  'Ortam': 'environment',

  // Quest
  'Durum': 'status',
  'Görevi Veren': 'giver',
  'Ödül': 'reward',

  // Lore
  'Gizli Bilgi': 'secret_info',

  // Status Effect
  'Süre (Tur)': 'duration_turns',
  'Etki Tipi': 'effect_type',

  // Feat
  'Prerequisite': 'prerequisite',

  // Background
  'Skill Proficiencies': 'skill_proficiencies',
  'Tool Proficiencies': 'tool_proficiencies',
  'Languages': 'languages',
  'Equipment': 'equipment',

  // Condition
  'Effects': 'effects',

  // Plane — no mapped property; 'Linked Condition' from Status Effect
  'Linked Condition': 'linked_condition',
};

// ---------------------------------------------------------------------------
// 3. defaultEntityFields — mirrors Python get_default_entity_structure()
// ---------------------------------------------------------------------------

/// Default field values for a newly-created (or imported) entity.
///
/// Excludes `name` and `type` which are handled separately by the entity
/// model. Mirrors the Python `get_default_entity_structure()` output.
const Map<String, dynamic> defaultEntityFields = {
  'source': '',
  'description': '',
  'images': <String>[],
  'image_path': '',
  'battlemaps': <String>[],
  'tags': <String>[],
  'attributes': <String, dynamic>{},
  'stats': {
    'STR': 10,
    'DEX': 10,
    'CON': 10,
    'INT': 10,
    'WIS': 10,
    'CHA': 10,
  },
  'combat_stats': {
    'hp': '',
    'max_hp': '',
    'ac': '',
    'speed': '',
    'cr': '',
    'xp': '',
    'initiative': '',
  },
  'traits': <dynamic>[],
  'actions': <dynamic>[],
  'reactions': <dynamic>[],
  'legendary_actions': <dynamic>[],
  'spells': <dynamic>[],
  'custom_spells': <dynamic>[],
  'equipment_ids': <String>[],
  'inventory': <dynamic>[],
  'pdfs': <dynamic>[],
  'location_id': null,
  'dm_notes': '',
  'saving_throws': '',
  'damage_vulnerabilities': '',
  'damage_resistances': '',
  'damage_immunities': '',
  'condition_immunities': '',
  'proficiency_bonus': '',
  'passive_perception': '',
  'skills': '',
};
