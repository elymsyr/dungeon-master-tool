import '../core/ability.dart';
import 'feat_prerequisite.dart';

/// JSON codec for [FeatPrerequisite]. Tagged on `"t"`.
/// - AbilityMinimum: `{"t": "abilityMin", "ability": "STR", "minimum": 13}`
/// - ProficiencyRequired: `{"t": "proficiency", "proficiencyId": "srd:light-armor"}`
/// - SpellcasterRequired: `{"t": "spellcaster"}`
/// - ClassRequired: `{"t": "class", "classId": "srd:wizard"}`
/// - SpeciesRequired: `{"t": "species", "speciesId": "srd:elf"}`
/// - LevelMinimum: `{"t": "levelMin", "minimum": 4}`

Map<String, Object?> encodeFeatPrerequisite(FeatPrerequisite p) {
  return switch (p) {
    AbilityMinimum() => {
        't': 'abilityMin',
        'ability': p.ability.short,
        'minimum': p.minimum,
      },
    ProficiencyRequired() => {
        't': 'proficiency',
        'proficiencyId': p.proficiencyId,
      },
    SpellcasterRequired() => const {'t': 'spellcaster'},
    ClassRequired() => {'t': 'class', 'classId': p.classId},
    SpeciesRequired() => {'t': 'species', 'speciesId': p.speciesId},
    LevelMinimum() => {'t': 'levelMin', 'minimum': p.minimum},
  };
}

FeatPrerequisite decodeFeatPrerequisite(Object? json, String ctx) {
  if (json is! Map) {
    throw FormatException(
        '$ctx: FeatPrerequisite must be a JSON object (got ${json.runtimeType}).');
  }
  final m = json.cast<String, Object?>();
  final tag = m['t'];
  if (tag is! String) {
    throw FormatException('$ctx: FeatPrerequisite missing "t" tag.');
  }
  switch (tag) {
    case 'abilityMin':
      final abilityStr = _requireString(m, 'ability', ctx);
      return AbilityMinimum(
        ability: Ability.fromShort(abilityStr),
        minimum: _requireInt(m, 'minimum', ctx),
      );
    case 'proficiency':
      return ProficiencyRequired(_requireString(m, 'proficiencyId', ctx));
    case 'spellcaster':
      return const SpellcasterRequired();
    case 'class':
      return ClassRequired(_requireString(m, 'classId', ctx));
    case 'species':
      return SpeciesRequired(_requireString(m, 'speciesId', ctx));
    case 'levelMin':
      return LevelMinimum(_requireInt(m, 'minimum', ctx));
    default:
      throw FormatException('$ctx: unknown FeatPrerequisite tag "$tag".');
  }
}

String _requireString(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('$ctx: missing or non-string field "$key".');
  }
  return v;
}

int _requireInt(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! int) {
    throw FormatException('$ctx: missing or non-int field "$key".');
  }
  return v;
}
