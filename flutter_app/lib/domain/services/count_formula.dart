import '../entities/entity.dart';

/// Resolve a `count_formula` token (e.g. `wis_mod_min_1`, `monk_level`,
/// `paladin_level_x5`, `pb`) to an integer using the PC's abilities and
/// class levels. Returns null when the token is unknown so the caller can
/// fall back to other count sources (scaled tables, raw payload count).
///
/// Shared between [CharacterResolver] (full character resolution) and
/// the planner's resource pool resolver so both pipelines agree on token
/// semantics.
int? evalCountFormula(
  String? token, {
  required Map<String, int> abilities,
  required Map<String, int> classLevels,
  required Map<String, Entity> entitiesById,
}) {
  if (token == null || token.isEmpty) return null;
  int mod(String ab) => ((abilities[ab] ?? 10) - 10) >> 1;
  int classLevel(String name) {
    for (final entry in classLevels.entries) {
      final e = entitiesById[entry.key];
      if (e == null) continue;
      if (e.name.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return 0;
  }

  switch (token.toLowerCase()) {
    case 'str_mod':
      return mod('STR');
    case 'dex_mod':
      return mod('DEX');
    case 'con_mod':
      return mod('CON');
    case 'int_mod':
      return mod('INT');
    case 'wis_mod':
      return mod('WIS');
    case 'cha_mod':
      return mod('CHA');
    case 'str_mod_min_1':
      return mod('STR') < 1 ? 1 : mod('STR');
    case 'dex_mod_min_1':
      return mod('DEX') < 1 ? 1 : mod('DEX');
    case 'con_mod_min_1':
      return mod('CON') < 1 ? 1 : mod('CON');
    case 'int_mod_min_1':
      return mod('INT') < 1 ? 1 : mod('INT');
    case 'wis_mod_min_1':
      return mod('WIS') < 1 ? 1 : mod('WIS');
    case 'cha_mod_min_1':
      return mod('CHA') < 1 ? 1 : mod('CHA');
    case 'barbarian_level':
      return classLevel('Barbarian');
    case 'bard_level':
      return classLevel('Bard');
    case 'cleric_level':
      return classLevel('Cleric');
    case 'druid_level':
      return classLevel('Druid');
    case 'fighter_level':
      return classLevel('Fighter');
    case 'monk_level':
      return classLevel('Monk');
    case 'paladin_level':
      return classLevel('Paladin');
    case 'paladin_level_x5':
      return classLevel('Paladin') * 5;
    case 'ranger_level':
      return classLevel('Ranger');
    case 'rogue_level':
      return classLevel('Rogue');
    case 'sorcerer_level':
      return classLevel('Sorcerer');
    case 'warlock_level':
      return classLevel('Warlock');
    case 'wizard_level':
      return classLevel('Wizard');
    case 'character_level':
      return classLevels.values.fold<int>(0, (a, b) => a + b);
    case 'pb':
    case 'proficiency_bonus':
      final lvl = classLevels.values.fold<int>(0, (a, b) => a + b);
      if (lvl >= 17) return 6;
      if (lvl >= 13) return 5;
      if (lvl >= 9) return 4;
      if (lvl >= 5) return 3;
      return 2;
  }
  return null;
}
