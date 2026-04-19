import 'dart:convert';

import '../core/ability.dart';
import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'alignment.dart';
import 'armor_category.dart';
import 'condition.dart';
import 'creature_type.dart';
import 'damage_type.dart';
import 'language.dart';
import 'rarity.dart';
import 'size.dart';
import 'skill.dart';
import 'spell_school.dart';
import 'weapon_mastery.dart';
import 'weapon_property.dart';
import 'weapon_property_flag.dart';

/// Per-entity JSON codecs that bridge [CatalogEntry] (the Doc 15 wire shape —
/// `{id, name, bodyJson}`) to domain Tier 1 catalog objects.
///
/// Entries must carry **already-namespaced** ids (`srd:stunned`, not `stunned`);
/// call [CatalogEntry.namespaced] before handing entries in.
///
/// `body` is a JSON-encoded object whose keys are the domain-specific fields
/// (see each codec's dartdoc). Missing optional keys take the domain default.
/// Unknown keys are ignored for forward compatibility.
///
/// `Condition.effects` is serialized via the Tier 2 `effect_descriptor_codec`.

// ----------------------------------------------------------------------------
// Condition
// ----------------------------------------------------------------------------

/// `body`: `{"description": String, "effects": [<effect>...]}`.
Condition conditionFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Condition');
  return Condition(
    id: e.id,
    name: e.name,
    description: _optString(body, 'description', e.id) ?? '',
    effects: _decodeEffectList(body, 'effects', e.id),
  );
}

CatalogEntry conditionToEntry(Condition c) => CatalogEntry(
      id: c.id,
      name: c.name,
      bodyJson: jsonEncode(<String, Object?>{
        'description': c.description,
        if (c.effects.isNotEmpty)
          'effects': c.effects.map(encodeEffect).toList(),
      }),
    );

List<EffectDescriptor> _decodeEffectList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeEffect(e, ctx)).toList();
}

// ----------------------------------------------------------------------------
// DamageType
// ----------------------------------------------------------------------------

/// `body`: `{"physical": bool}`.
DamageType damageTypeFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'DamageType');
  return DamageType(
    id: e.id,
    name: e.name,
    physical: _optBool(body, 'physical', e.id) ?? false,
  );
}

CatalogEntry damageTypeToEntry(DamageType d) => CatalogEntry(
      id: d.id,
      name: d.name,
      bodyJson: jsonEncode(<String, Object?>{'physical': d.physical}),
    );

// ----------------------------------------------------------------------------
// Skill
// ----------------------------------------------------------------------------

/// `body`: `{"ability": <Ability.name>}`  (e.g. `"strength"`).
Skill skillFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Skill');
  final abilityName = _requireString(body, 'ability', e.id);
  return Skill(
    id: e.id,
    name: e.name,
    ability: _abilityFromName(abilityName, e.id),
  );
}

CatalogEntry skillToEntry(Skill s) => CatalogEntry(
      id: s.id,
      name: s.name,
      bodyJson: jsonEncode(<String, Object?>{'ability': s.ability.name}),
    );

// ----------------------------------------------------------------------------
// Size
// ----------------------------------------------------------------------------

/// `body`: `{"spaceFt": num, "tokenScale": num}`.
Size sizeFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Size');
  return Size(
    id: e.id,
    name: e.name,
    spaceFt: _requireNum(body, 'spaceFt', e.id).toDouble(),
    tokenScale: _requireNum(body, 'tokenScale', e.id).toDouble(),
  );
}

CatalogEntry sizeToEntry(Size s) => CatalogEntry(
      id: s.id,
      name: s.name,
      bodyJson: jsonEncode(<String, Object?>{
        'spaceFt': s.spaceFt,
        'tokenScale': s.tokenScale,
      }),
    );

// ----------------------------------------------------------------------------
// CreatureType
// ----------------------------------------------------------------------------

/// `body`: `{}` — no extra fields.
CreatureType creatureTypeFromEntry(CatalogEntry e) {
  _decodeBody(e, 'CreatureType');
  return CreatureType(id: e.id, name: e.name);
}

CatalogEntry creatureTypeToEntry(CreatureType c) => CatalogEntry(
      id: c.id,
      name: c.name,
      bodyJson: jsonEncode(const <String, Object?>{}),
    );

// ----------------------------------------------------------------------------
// Alignment
// ----------------------------------------------------------------------------

/// `body`: `{"lawChaos": <LawChaosAxis.name>, "goodEvil": <GoodEvilAxis.name>}`.
Alignment alignmentFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Alignment');
  final lc = _requireString(body, 'lawChaos', e.id);
  final ge = _requireString(body, 'goodEvil', e.id);
  return Alignment(
    id: e.id,
    name: e.name,
    lawChaos: _enumByName(LawChaosAxis.values, lc, 'lawChaos', e.id),
    goodEvil: _enumByName(GoodEvilAxis.values, ge, 'goodEvil', e.id),
  );
}

CatalogEntry alignmentToEntry(Alignment a) => CatalogEntry(
      id: a.id,
      name: a.name,
      bodyJson: jsonEncode(<String, Object?>{
        'lawChaos': a.lawChaos.name,
        'goodEvil': a.goodEvil.name,
      }),
    );

// ----------------------------------------------------------------------------
// Language
// ----------------------------------------------------------------------------

/// `body`: `{"script": String?}` — null when unwritten.
Language languageFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Language');
  return Language(
    id: e.id,
    name: e.name,
    script: _optString(body, 'script', e.id),
  );
}

CatalogEntry languageToEntry(Language l) => CatalogEntry(
      id: l.id,
      name: l.name,
      bodyJson: jsonEncode(<String, Object?>{'script': l.script}),
    );

// ----------------------------------------------------------------------------
// SpellSchool
// ----------------------------------------------------------------------------

/// `body`: `{"color": String?}`  (hex `#RRGGBB` or null).
SpellSchool spellSchoolFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'SpellSchool');
  return SpellSchool(
    id: e.id,
    name: e.name,
    color: _optString(body, 'color', e.id),
  );
}

CatalogEntry spellSchoolToEntry(SpellSchool s) => CatalogEntry(
      id: s.id,
      name: s.name,
      bodyJson: jsonEncode(<String, Object?>{'color': s.color}),
    );

// ----------------------------------------------------------------------------
// WeaponProperty
// ----------------------------------------------------------------------------

/// `body`: `{"flags": [<PropertyFlag.name>...], "description": String?}`.
WeaponProperty weaponPropertyFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'WeaponProperty');
  final rawFlags = body['flags'];
  final flags = <PropertyFlag>{};
  if (rawFlags != null) {
    if (rawFlags is! List) {
      throw FormatException(
          '${e.id}: "flags" must be an array (got ${rawFlags.runtimeType}).');
    }
    for (final f in rawFlags) {
      if (f is! String) {
        throw FormatException('${e.id}: "flags" must contain only strings.');
      }
      flags.add(_enumByName(PropertyFlag.values, f, 'flags', e.id));
    }
  }
  return WeaponProperty(
    id: e.id,
    name: e.name,
    flags: flags,
    description: _optString(body, 'description', e.id),
  );
}

CatalogEntry weaponPropertyToEntry(WeaponProperty w) => CatalogEntry(
      id: w.id,
      name: w.name,
      bodyJson: jsonEncode(<String, Object?>{
        'flags': w.flags.map((f) => f.name).toList()..sort(),
        'description': w.description,
      }),
    );

// ----------------------------------------------------------------------------
// WeaponMastery
// ----------------------------------------------------------------------------

/// `body`: `{"description": String}`.
WeaponMastery weaponMasteryFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'WeaponMastery');
  return WeaponMastery(
    id: e.id,
    name: e.name,
    description: _optString(body, 'description', e.id) ?? '',
  );
}

CatalogEntry weaponMasteryToEntry(WeaponMastery w) => CatalogEntry(
      id: w.id,
      name: w.name,
      bodyJson: jsonEncode(<String, Object?>{'description': w.description}),
    );

// ----------------------------------------------------------------------------
// ArmorCategory
// ----------------------------------------------------------------------------

/// `body`: `{"stealthDisadvantage": bool, "maxDexCap": int?}`.
ArmorCategory armorCategoryFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'ArmorCategory');
  return ArmorCategory(
    id: e.id,
    name: e.name,
    stealthDisadvantage:
        _optBool(body, 'stealthDisadvantage', e.id) ?? false,
    maxDexCap: _optInt(body, 'maxDexCap', e.id),
  );
}

CatalogEntry armorCategoryToEntry(ArmorCategory a) => CatalogEntry(
      id: a.id,
      name: a.name,
      bodyJson: jsonEncode(<String, Object?>{
        'stealthDisadvantage': a.stealthDisadvantage,
        'maxDexCap': a.maxDexCap,
      }),
    );

// ----------------------------------------------------------------------------
// Rarity
// ----------------------------------------------------------------------------

/// `body`: `{"sortOrder": int, "attunementTierReq": int?}`.
Rarity rarityFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Rarity');
  return Rarity(
    id: e.id,
    name: e.name,
    sortOrder: _requireInt(body, 'sortOrder', e.id),
    attunementTierReq: _optInt(body, 'attunementTierReq', e.id),
  );
}

CatalogEntry rarityToEntry(Rarity r) => CatalogEntry(
      id: r.id,
      name: r.name,
      bodyJson: jsonEncode(<String, Object?>{
        'sortOrder': r.sortOrder,
        'attunementTierReq': r.attunementTierReq,
      }),
    );

// ----------------------------------------------------------------------------
// Private helpers — uniform FormatException shape: `<entry.id>: <reason>`.
// ----------------------------------------------------------------------------

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

bool? _optBool(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! bool) {
    throw FormatException('$ctx: field "$key" must be a bool when present.');
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

int? _optInt(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! int) {
    throw FormatException('$ctx: field "$key" must be an int when present.');
  }
  return v;
}

num _requireNum(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! num) {
    throw FormatException('$ctx: missing or non-numeric field "$key".');
  }
  return v;
}

T _enumByName<T extends Enum>(
    List<T> values, String name, String field, String ctx) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('$ctx: field "$field" has unknown enum value "$name".');
}

Ability _abilityFromName(String name, String ctx) =>
    _enumByName(Ability.values, name, 'ability', ctx);
