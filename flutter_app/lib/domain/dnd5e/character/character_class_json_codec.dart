import 'dart:convert';

import '../core/ability.dart';
import '../core/die.dart';
import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'caster_kind.dart';
import 'character_class.dart';

/// JSON codec for Tier 1 content class [CharacterClass]. Body shape:
/// `{"hitDie": String, "casterKind": String, "spellcastingAbility"?: String,
/// "savingThrows"?: [String...], "featureTable"?: [<row>...],
/// "casterFraction"?: num, "description"?: String}`
///
/// Enums encoded via `.name`. `casterFraction` omitted when it equals the
/// default for `casterKind`. Rows emitted sorted by level for deterministic
/// output. Empty lists + empty description omitted.

CharacterClass characterClassFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'CharacterClass');
  return CharacterClass(
    id: e.id,
    name: e.name,
    hitDie: _requireDie(body, 'hitDie', e.id),
    casterKind: _requireCasterKind(body, 'casterKind', e.id),
    spellcastingAbility: _optAbility(body, 'spellcastingAbility', e.id),
    savingThrows: _decodeAbilityList(body, 'savingThrows', e.id),
    featureTable: _decodeRows(body, 'featureTable', e.id),
    casterFraction: _optNum(body, 'casterFraction', e.id)?.toDouble(),
    description: _optString(body, 'description', e.id) ?? '',
    startingArmorIds: _optStringList(body, 'startingArmorIds', e.id),
    startingWeaponIds: _optStringList(body, 'startingWeaponIds', e.id),
    startingToolIds: _optStringList(body, 'startingToolIds', e.id),
    grantedSkillChoiceCount:
        _optInt(body, 'grantedSkillChoiceCount', e.id) ?? 0,
    grantedSkillOptions: _optStringList(body, 'grantedSkillOptions', e.id),
    startingEquipmentIds: _optStringList(body, 'startingEquipmentIds', e.id),
  );
}

CatalogEntry characterClassToEntry(CharacterClass c) {
  final rows = [...c.featureTable]..sort((a, b) => a.level.compareTo(b.level));
  final defaultFraction = _defaultFractionFor(c.casterKind);
  return CatalogEntry(
    id: c.id,
    name: c.name,
    bodyJson: jsonEncode(<String, Object?>{
      'hitDie': c.hitDie.name,
      'casterKind': c.casterKind.name,
      if (c.spellcastingAbility != null)
        'spellcastingAbility': c.spellcastingAbility!.name,
      if (c.savingThrows.isNotEmpty)
        'savingThrows': c.savingThrows.map((a) => a.name).toList(),
      if (rows.isNotEmpty) 'featureTable': rows.map(_encodeRow).toList(),
      if (c.casterFraction != defaultFraction)
        'casterFraction': c.casterFraction,
      if (c.startingArmorIds.isNotEmpty)
        'startingArmorIds': c.startingArmorIds,
      if (c.startingWeaponIds.isNotEmpty)
        'startingWeaponIds': c.startingWeaponIds,
      if (c.startingToolIds.isNotEmpty)
        'startingToolIds': c.startingToolIds,
      if (c.grantedSkillChoiceCount != 0)
        'grantedSkillChoiceCount': c.grantedSkillChoiceCount,
      if (c.grantedSkillOptions.isNotEmpty)
        'grantedSkillOptions': c.grantedSkillOptions,
      if (c.startingEquipmentIds.isNotEmpty)
        'startingEquipmentIds': c.startingEquipmentIds,
      if (c.description.isNotEmpty) 'description': c.description,
    }),
  );
}

int? _optInt(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! int) {
    throw FormatException('$ctx: field "$key" must be an int when present.');
  }
  return v;
}

Map<String, Object?> _encodeRow(ClassFeatureRow r) => <String, Object?>{
      'level': r.level,
      if (r.featureIds.isNotEmpty) 'featureIds': r.featureIds,
      if (r.effects.isNotEmpty)
        'effects': r.effects.map(encodeEffect).toList(),
    };

List<ClassFeatureRow> _decodeRows(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) {
    if (e is! Map) {
      throw FormatException('$ctx: "$key" entries must be JSON objects.');
    }
    final m = e.cast<String, Object?>();
    return ClassFeatureRow(
      level: _requireInt(m, 'level', ctx),
      featureIds: _optStringList(m, 'featureIds', ctx),
      effects: _decodeEffectList(m, 'effects', ctx),
    );
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

List<Ability> _decodeAbilityList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) {
    if (e is! String) {
      throw FormatException('$ctx: "$key" entries must be strings.');
    }
    for (final a in Ability.values) {
      if (a.name == e) return a;
    }
    throw FormatException('$ctx: unknown Ability "$e" in "$key".');
  }).toList();
}

List<String> _optStringList(
    Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return const [];
  if (v is! List) {
    throw FormatException('$ctx: field "$key" must be an array when present.');
  }
  return v.map((e) {
    if (e is! String) {
      throw FormatException('$ctx: "$key" entries must be strings.');
    }
    return e;
  }).toList();
}

Die _requireDie(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('$ctx: missing or non-string field "$key".');
  }
  for (final d in Die.values) {
    if (d.name == v) return d;
  }
  throw FormatException('$ctx: unknown Die "$v" in "$key".');
}

CasterKind _requireCasterKind(
    Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('$ctx: missing or non-string field "$key".');
  }
  for (final k in CasterKind.values) {
    if (k.name == v) return k;
  }
  throw FormatException('$ctx: unknown CasterKind "$v" in "$key".');
}

Ability? _optAbility(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! String) {
    throw FormatException('$ctx: field "$key" must be a string when present.');
  }
  for (final a in Ability.values) {
    if (a.name == v) return a;
  }
  throw FormatException('$ctx: unknown Ability "$v" in "$key".');
}

double _defaultFractionFor(CasterKind k) {
  switch (k) {
    case CasterKind.none:
      return 0;
    case CasterKind.full:
      return 1.0;
    case CasterKind.half:
      return 0.5;
    case CasterKind.third:
      return 1 / 3;
    case CasterKind.pact:
      return 0;
  }
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

num? _optNum(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! num) {
    throw FormatException('$ctx: field "$key" must be a number when present.');
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
