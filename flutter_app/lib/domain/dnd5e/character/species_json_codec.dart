import 'dart:convert';

import '../core/ability.dart';
import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'species.dart';

/// JSON codec for Tier 1 content class [Species]. Body shape:
/// `{"sizeId": String, "baseSpeedFt": int, "effects"?: [<effect>...],
///   "abilityIncreases"?: {"STR": 1, "DEX": 2, ...},
///   "innateSpellIds"?: [String...], "damageResistanceIds"?: [String...],
///   "description"?: String}`
///
/// `effects` route through `effect_descriptor_codec`. Empty/unset fields are
/// omitted from the encoded body so round-trip stays minimal.

Species speciesFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Species');
  return Species(
    id: e.id,
    name: e.name,
    sizeId: _requireString(body, 'sizeId', e.id),
    baseSpeedFt: _requireInt(body, 'baseSpeedFt', e.id),
    effects: _decodeEffectList(body, 'effects', e.id),
    abilityIncreases: _decodeAbilityIncreases(body, 'abilityIncreases', e.id),
    innateSpellIds: _decodeStringList(body, 'innateSpellIds', e.id),
    damageResistanceIds:
        _decodeStringList(body, 'damageResistanceIds', e.id),
    description: _optString(body, 'description', e.id) ?? '',
  );
}

CatalogEntry speciesToEntry(Species s) {
  return CatalogEntry(
    id: s.id,
    name: s.name,
    bodyJson: jsonEncode(<String, Object?>{
      'sizeId': s.sizeId,
      'baseSpeedFt': s.baseSpeedFt,
      if (s.effects.isNotEmpty)
        'effects': s.effects.map(encodeEffect).toList(),
      if (s.abilityIncreases.isNotEmpty)
        'abilityIncreases': {
          for (final e in s.abilityIncreases.entries) e.key.short: e.value,
        },
      if (s.innateSpellIds.isNotEmpty) 'innateSpellIds': s.innateSpellIds,
      if (s.damageResistanceIds.isNotEmpty)
        'damageResistanceIds': s.damageResistanceIds,
      if (s.description.isNotEmpty) 'description': s.description,
    }),
  );
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

String _requireString(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('$ctx: missing or non-string field "$key".');
  }
  return v;
}

String? _optString(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! String) {
    throw FormatException('$ctx: field "$key" must be a string when present.');
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
