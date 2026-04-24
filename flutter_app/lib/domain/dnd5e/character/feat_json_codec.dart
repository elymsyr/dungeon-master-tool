import 'dart:convert';

import '../core/ability.dart';
import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'feat.dart';
import 'feat_prerequisite.dart';
import 'feat_prerequisite_codec.dart';

/// JSON codec for Tier 1 content class [Feat]. Body shape:
/// `{"category": String, "repeatable"?: bool, "prerequisite"?: String,
///   "prerequisites"?: [<featPrereq>...], "effects"?: [<effect>...],
///   "grantedSpellIds"?: [String...], "grantedSkillChoiceCount"?: int,
///   "grantedSkillOptions"?: [String...],
///   "abilityIncreases"?: {"STR": 1, ...}, "description"?: String}`
///
/// `category` encodes [FeatCategory.name] (origin/general/fightingStyle/epicBoon).
/// `repeatable` is omitted when false. `effects` route through
/// `effect_descriptor_codec`. `prerequisites` route through
/// `feat_prerequisite_codec`. Empty lists + empty description omitted.

Feat featFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Feat');
  return Feat(
    id: e.id,
    name: e.name,
    category: _requireCategory(body, 'category', e.id),
    repeatable: _optBool(body, 'repeatable', e.id) ?? false,
    prerequisite: _optString(body, 'prerequisite', e.id),
    prerequisites: _decodePrereqList(body, 'prerequisites', e.id),
    effects: _decodeEffectList(body, 'effects', e.id),
    grantedSpellIds: _decodeStringList(body, 'grantedSpellIds', e.id),
    grantedSkillChoiceCount:
        _optInt(body, 'grantedSkillChoiceCount', e.id) ?? 0,
    grantedSkillOptions: _decodeStringList(body, 'grantedSkillOptions', e.id),
    abilityIncreases: _decodeAbilityIncreases(body, 'abilityIncreases', e.id),
    description: _optString(body, 'description', e.id) ?? '',
  );
}

CatalogEntry featToEntry(Feat f) {
  return CatalogEntry(
    id: f.id,
    name: f.name,
    bodyJson: jsonEncode(<String, Object?>{
      'category': f.category.name,
      if (f.repeatable) 'repeatable': true,
      if (f.prerequisite != null) 'prerequisite': f.prerequisite,
      if (f.prerequisites.isNotEmpty)
        'prerequisites':
            f.prerequisites.map(encodeFeatPrerequisite).toList(),
      if (f.effects.isNotEmpty)
        'effects': f.effects.map(encodeEffect).toList(),
      if (f.grantedSpellIds.isNotEmpty)
        'grantedSpellIds': f.grantedSpellIds,
      if (f.grantedSkillChoiceCount != 0)
        'grantedSkillChoiceCount': f.grantedSkillChoiceCount,
      if (f.grantedSkillOptions.isNotEmpty)
        'grantedSkillOptions': f.grantedSkillOptions,
      if (f.abilityIncreases.isNotEmpty)
        'abilityIncreases': {
          for (final e in f.abilityIncreases.entries) e.key.short: e.value,
        },
      if (f.description.isNotEmpty) 'description': f.description,
    }),
  );
}

List<FeatPrerequisite> _decodePrereqList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeFeatPrerequisite(e, ctx)).toList();
}

List<String> _decodeStringList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((v) {
    if (v is! String) {
      throw FormatException('$ctx: "$key" entries must be strings.');
    }
    return v;
  }).toList();
}

Map<Ability, int> _decodeAbilityIncreases(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const {};
  if (raw is! Map) {
    throw FormatException(
        '$ctx: "$key" must be an object mapping ability shorts to ints.');
  }
  final out = <Ability, int>{};
  raw.forEach((k, v) {
    if (k is! String) {
      throw FormatException('$ctx: "$key" keys must be strings (STR/DEX/...).');
    }
    if (v is! int) {
      throw FormatException('$ctx: "$key.$k" must be int.');
    }
    out[Ability.fromShort(k)] = v;
  });
  return out;
}

int? _optInt(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! int) {
    throw FormatException('$ctx: field "$key" must be an int when present.');
  }
  return v;
}

FeatCategory _requireCategory(
    Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('$ctx: missing or non-string field "$key".');
  }
  for (final c in FeatCategory.values) {
    if (c.name == v) return c;
  }
  throw FormatException('$ctx: unknown "$key" value "$v".');
}

List<EffectDescriptor> _decodeEffectList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeEffect(e, ctx)).toList();
}

Map<String, Object?> _decodeBody(CatalogEntry e, String typeName) {
  final Object? decoded;
  try {
    decoded = jsonDecode(e.bodyJson);
  } on FormatException catch (err) {
    throw FormatException(
        '${e.id}: $typeName body is not valid JSON: ${err.message}');
  }
  if (decoded is! Map) {
    throw FormatException(
        '${e.id}: $typeName body must be a JSON object (got ${decoded.runtimeType}).');
  }
  return decoded.cast<String, Object?>();
}

String? _optString(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! String) {
    throw FormatException('$ctx: field "$key" must be a string when present.');
  }
  return v;
}

bool? _optBool(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! bool) {
    throw FormatException('$ctx: field "$key" must be a bool when present.');
  }
  return v;
}
