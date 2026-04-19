import 'dart:convert';

import '../core/ability.dart';
import '../core/ability_score.dart';
import '../core/ability_scores.dart';
import '../core/challenge_rating.dart';
import '../core/dice_expression.dart';
import '../core/proficiency.dart';
import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'legendary_action.dart';
import 'monster.dart';
import 'monster_action.dart';
import 'stat_block.dart';

/// JSON codec for Tier 2 content class [Monster] and its sub-families:
/// [StatBlock] (with [MonsterSpeeds] + [MonsterSenses]), [MonsterAction]
/// (sealed: Attack/Multiattack/Save/Special), and [LegendaryAction].
/// Tagged-union shape on `"t"` for [MonsterAction]; `FormatException`
/// on unknown tags / missing required fields, prefixed with entry id.

// ----------------------------------------------------------------------------
// Monster (top-level)
// ----------------------------------------------------------------------------

Monster monsterFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Monster');
  final stats = body['stats'];
  if (stats is! Map) {
    throw FormatException('${e.id}: missing or non-object "stats".');
  }
  return Monster(
    id: e.id,
    name: e.name,
    stats: _decodeStatBlock(stats.cast<String, Object?>(), e.id),
    traits: _decodeEffectList(body, 'traits', e.id),
    actions: _decodeActionList(body, 'actions', e.id),
    bonusActions: _decodeActionList(body, 'bonusActions', e.id),
    reactions: _decodeActionList(body, 'reactions', e.id),
    legendaryActions: _decodeLegendaryList(body, 'legendaryActions', e.id),
    legendaryActionSlots:
        _optInt(body, 'legendaryActionSlots', e.id) ?? 0,
    description: _optString(body, 'description', e.id) ?? '',
  );
}

CatalogEntry monsterToEntry(Monster m) {
  final body = <String, Object?>{
    'stats': _encodeStatBlock(m.stats),
  };
  if (m.traits.isNotEmpty) {
    body['traits'] = m.traits.map(encodeEffect).toList();
  }
  if (m.actions.isNotEmpty) {
    body['actions'] = m.actions.map(encodeMonsterAction).toList();
  }
  if (m.bonusActions.isNotEmpty) {
    body['bonusActions'] =
        m.bonusActions.map(encodeMonsterAction).toList();
  }
  if (m.reactions.isNotEmpty) {
    body['reactions'] = m.reactions.map(encodeMonsterAction).toList();
  }
  if (m.legendaryActions.isNotEmpty) {
    body['legendaryActions'] =
        m.legendaryActions.map(encodeLegendaryAction).toList();
  }
  if (m.legendaryActionSlots > 0) {
    body['legendaryActionSlots'] = m.legendaryActionSlots;
  }
  if (m.description.isNotEmpty) body['description'] = m.description;
  return CatalogEntry(id: m.id, name: m.name, bodyJson: jsonEncode(body));
}

// ----------------------------------------------------------------------------
// StatBlock (+ Speeds + Senses + ability scores + skills)
// ----------------------------------------------------------------------------

Map<String, Object?> _encodeStatBlock(StatBlock s) {
  final out = <String, Object?>{
    'sizeId': s.sizeId,
    'typeId': s.typeId,
    if (s.alignmentId != null) 'alignmentId': s.alignmentId,
    'armorClass': s.armorClass,
    'hitPoints': s.hitPoints,
    if (s.hitPointsFormula != null) 'hitPointsFormula': s.hitPointsFormula,
    'speeds': _encodeSpeeds(s.speeds),
    'abilities': _encodeAbilityScores(s.abilities),
    'cr': s.cr.canonical,
  };
  if (s.savingThrows.isNotEmpty) {
    out['savingThrows'] = _encodeAbilityProficiencyMap(s.savingThrows);
  }
  if (s.skills.isNotEmpty) {
    out['skills'] = _encodeSkillMap(s.skills);
  }
  if (s.damageResistanceIds.isNotEmpty) {
    out['damageResistanceIds'] = (s.damageResistanceIds.toList()..sort());
  }
  if (s.damageImmunityIds.isNotEmpty) {
    out['damageImmunityIds'] = (s.damageImmunityIds.toList()..sort());
  }
  if (s.damageVulnerabilityIds.isNotEmpty) {
    out['damageVulnerabilityIds'] =
        (s.damageVulnerabilityIds.toList()..sort());
  }
  if (s.conditionImmunityIds.isNotEmpty) {
    out['conditionImmunityIds'] =
        (s.conditionImmunityIds.toList()..sort());
  }
  final senses = _encodeSenses(s.senses);
  if (senses.isNotEmpty) out['senses'] = senses;
  if (s.languageIds.isNotEmpty) {
    out['languageIds'] = (s.languageIds.toList()..sort());
  }
  return out;
}

StatBlock _decodeStatBlock(Map<String, Object?> m, String ctx) {
  final senses = m['senses'];
  return StatBlock(
    sizeId: _requireString(m, 'sizeId', ctx),
    typeId: _requireString(m, 'typeId', ctx),
    alignmentId: _optString(m, 'alignmentId', ctx),
    armorClass: _requireInt(m, 'armorClass', ctx),
    hitPoints: _requireInt(m, 'hitPoints', ctx),
    hitPointsFormula: _optString(m, 'hitPointsFormula', ctx),
    speeds: _decodeSpeeds(m['speeds'], ctx),
    abilities: _decodeAbilityScores(m['abilities'], ctx),
    savingThrows: _decodeAbilityProficiencyMap(m, 'savingThrows', ctx),
    skills: _decodeSkillMap(m, 'skills', ctx),
    damageResistanceIds: _optStringSet(m, 'damageResistanceIds', ctx),
    damageImmunityIds: _optStringSet(m, 'damageImmunityIds', ctx),
    damageVulnerabilityIds: _optStringSet(m, 'damageVulnerabilityIds', ctx),
    conditionImmunityIds: _optStringSet(m, 'conditionImmunityIds', ctx),
    senses: senses == null
        ? const MonsterSenses()
        : _decodeSenses(senses, ctx),
    languageIds: _optStringSet(m, 'languageIds', ctx),
    cr: ChallengeRating.parse(_requireString(m, 'cr', ctx)),
  );
}

Map<String, Object?> _encodeSpeeds(MonsterSpeeds s) => {
      'walk': s.walk,
      if (s.fly != null) 'fly': s.fly,
      if (s.swim != null) 'swim': s.swim,
      if (s.climb != null) 'climb': s.climb,
      if (s.burrow != null) 'burrow': s.burrow,
      if (s.hover) 'hover': true,
    };

MonsterSpeeds _decodeSpeeds(Object? json, String ctx) {
  if (json == null) return const MonsterSpeeds();
  final m = _asObject(json, ctx, 'MonsterSpeeds');
  return MonsterSpeeds(
    walk: _optInt(m, 'walk', ctx) ?? 30,
    fly: _optInt(m, 'fly', ctx),
    swim: _optInt(m, 'swim', ctx),
    climb: _optInt(m, 'climb', ctx),
    burrow: _optInt(m, 'burrow', ctx),
    hover: _optBool(m, 'hover', ctx) ?? false,
  );
}

Map<String, Object?> _encodeSenses(MonsterSenses s) => {
      if (s.darkvision != null) 'darkvision': s.darkvision,
      if (s.blindsight != null) 'blindsight': s.blindsight,
      if (s.tremorsense != null) 'tremorsense': s.tremorsense,
      if (s.truesight != null) 'truesight': s.truesight,
    };

MonsterSenses _decodeSenses(Object json, String ctx) {
  final m = _asObject(json, ctx, 'MonsterSenses');
  return MonsterSenses(
    darkvision: _optInt(m, 'darkvision', ctx),
    blindsight: _optInt(m, 'blindsight', ctx),
    tremorsense: _optInt(m, 'tremorsense', ctx),
    truesight: _optInt(m, 'truesight', ctx),
  );
}

Map<String, Object?> _encodeAbilityScores(AbilityScores a) => {
      'str': a.str.value,
      'dex': a.dex.value,
      'con': a.con.value,
      'int': a.int_.value,
      'wis': a.wis.value,
      'cha': a.cha.value,
    };

AbilityScores _decodeAbilityScores(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'AbilityScores');
  return AbilityScores(
    str: AbilityScore(_requireInt(m, 'str', ctx)),
    dex: AbilityScore(_requireInt(m, 'dex', ctx)),
    con: AbilityScore(_requireInt(m, 'con', ctx)),
    int_: AbilityScore(_requireInt(m, 'int', ctx)),
    wis: AbilityScore(_requireInt(m, 'wis', ctx)),
    cha: AbilityScore(_requireInt(m, 'cha', ctx)),
  );
}

Map<String, Object?> _encodeAbilityProficiencyMap(
    Map<Ability, Proficiency> src) {
  // Sorted by Ability.index for deterministic output.
  final keys = src.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
  return {for (final k in keys) k.name: src[k]!.name};
}

Map<Ability, Proficiency> _decodeAbilityProficiencyMap(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const {};
  if (raw is! Map) {
    throw FormatException('$ctx: "$key" must be an object when present.');
  }
  final out = <Ability, Proficiency>{};
  raw.forEach((k, v) {
    if (k is! String || v is! String) {
      throw FormatException('$ctx: "$key" map entries must be String→String.');
    }
    out[_enumByName(Ability.values, k, key, ctx)] =
        _enumByName(Proficiency.values, v, key, ctx);
  });
  return out;
}

Map<String, Object?> _encodeSkillMap(Map<String, Proficiency> src) {
  final keys = src.keys.toList()..sort();
  return {for (final k in keys) k: src[k]!.name};
}

Map<String, Proficiency> _decodeSkillMap(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const {};
  if (raw is! Map) {
    throw FormatException('$ctx: "$key" must be an object when present.');
  }
  final out = <String, Proficiency>{};
  raw.forEach((k, v) {
    if (k is! String || v is! String) {
      throw FormatException('$ctx: "$key" map entries must be String→String.');
    }
    out[k] = _enumByName(Proficiency.values, v, key, ctx);
  });
  return out;
}

// ----------------------------------------------------------------------------
// MonsterAction
// ----------------------------------------------------------------------------

Map<String, Object?> encodeMonsterAction(MonsterAction a) {
  return switch (a) {
    AttackAction() => {
        't': 'attack',
        'name': a.name,
        if (a.description.isNotEmpty) 'description': a.description,
        'attackBonus': a.attackBonus,
        if (a.reachFt != 5) 'reachFt': a.reachFt,
        if (a.rangeNormalFt != null) 'rangeNormalFt': a.rangeNormalFt,
        if (a.rangeLongFt != null) 'rangeLongFt': a.rangeLongFt,
        'damage': a.damage.toString(),
        'damageTypeId': a.damageTypeId,
      },
    MultiattackAction() => {
        't': 'multiattack',
        if (a.name != 'Multiattack') 'name': a.name,
        if (a.description.isNotEmpty) 'description': a.description,
        'actionNames': a.actionNames,
      },
    SaveAction() => {
        't': 'save',
        'name': a.name,
        if (a.description.isNotEmpty) 'description': a.description,
        'ability': a.ability.name,
        'dc': a.dc,
        if (a.damage != null) 'damage': a.damage!.toString(),
        if (a.damageTypeId != null) 'damageTypeId': a.damageTypeId,
        if (!a.halfOnSave) 'halfOnSave': false,
      },
    SpecialAction() => {
        't': 'special',
        'name': a.name,
        if (a.description.isNotEmpty) 'description': a.description,
        if (a.effects.isNotEmpty)
          'effects': a.effects.map(encodeEffect).toList(),
      },
  };
}

MonsterAction decodeMonsterAction(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'MonsterAction');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'attack':
      return AttackAction(
        name: _requireString(m, 'name', ctx),
        description: _optString(m, 'description', ctx) ?? '',
        attackBonus: _requireInt(m, 'attackBonus', ctx),
        reachFt: _optInt(m, 'reachFt', ctx) ?? 5,
        rangeNormalFt: _optInt(m, 'rangeNormalFt', ctx),
        rangeLongFt: _optInt(m, 'rangeLongFt', ctx),
        damage: _requireDice(m, 'damage', ctx),
        damageTypeId: _requireString(m, 'damageTypeId', ctx),
      );
    case 'multiattack':
      final rawNames = m['actionNames'];
      if (rawNames is! List) {
        throw FormatException(
            '$ctx: "actionNames" must be an array (got ${rawNames.runtimeType}).');
      }
      final names = <String>[];
      for (final s in rawNames) {
        if (s is! String) {
          throw FormatException('$ctx: "actionNames" must contain only strings.');
        }
        names.add(s);
      }
      return MultiattackAction(
        name: _optString(m, 'name', ctx) ?? 'Multiattack',
        description: _optString(m, 'description', ctx) ?? '',
        actionNames: names,
      );
    case 'save':
      return SaveAction(
        name: _requireString(m, 'name', ctx),
        description: _optString(m, 'description', ctx) ?? '',
        ability: _requireEnum(m, 'ability', ctx, Ability.values),
        dc: _requireInt(m, 'dc', ctx),
        damage: _optDice(m, 'damage', ctx),
        damageTypeId: _optString(m, 'damageTypeId', ctx),
        halfOnSave: _optBool(m, 'halfOnSave', ctx) ?? true,
      );
    case 'special':
      final rawEffects = m['effects'];
      final effects = <EffectDescriptor>[];
      if (rawEffects != null) {
        if (rawEffects is! List) {
          throw FormatException('$ctx: "effects" must be an array.');
        }
        for (final e in rawEffects) {
          effects.add(decodeEffect(e, ctx));
        }
      }
      return SpecialAction(
        name: _requireString(m, 'name', ctx),
        description: _optString(m, 'description', ctx) ?? '',
        effects: effects,
      );
    default:
      throw FormatException('$ctx: unknown monster-action tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// LegendaryAction
// ----------------------------------------------------------------------------

Map<String, Object?> encodeLegendaryAction(LegendaryAction la) => {
      'name': la.name,
      if (la.description.isNotEmpty) 'description': la.description,
      if (la.cost != 1) 'cost': la.cost,
      'inner': encodeMonsterAction(la.inner),
    };

LegendaryAction decodeLegendaryAction(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'LegendaryAction');
  return LegendaryAction(
    name: _requireString(m, 'name', ctx),
    description: _optString(m, 'description', ctx) ?? '',
    cost: _optInt(m, 'cost', ctx) ?? 1,
    inner: decodeMonsterAction(m['inner'], ctx),
  );
}

// ----------------------------------------------------------------------------
// List helpers
// ----------------------------------------------------------------------------

List<EffectDescriptor> _decodeEffectList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeEffect(e, ctx)).toList();
}

List<MonsterAction> _decodeActionList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeMonsterAction(e, ctx)).toList();
}

List<LegendaryAction> _decodeLegendaryList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeLegendaryAction(e, ctx)).toList();
}

Set<String> _optStringSet(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const {};
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  final out = <String>{};
  for (final s in raw) {
    if (s is! String) {
      throw FormatException('$ctx: "$key" must contain only strings.');
    }
    out.add(s);
  }
  return out;
}

// ----------------------------------------------------------------------------
// Scalar helpers
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

Map<String, Object?> _asObject(Object? json, String ctx, String typeName) {
  if (json is! Map) {
    throw FormatException(
        '$ctx: $typeName must be a JSON object (got ${json.runtimeType}).');
  }
  return json.cast<String, Object?>();
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

DiceExpression _requireDice(Map<String, Object?> m, String key, String ctx) {
  final s = _requireString(m, key, ctx);
  try {
    return DiceExpression.parse(s);
  } on FormatException catch (err) {
    throw FormatException('$ctx: field "$key" is not valid dice: ${err.message}');
  }
}

DiceExpression? _optDice(Map<String, Object?> m, String key, String ctx) {
  final s = _optString(m, key, ctx);
  if (s == null) return null;
  try {
    return DiceExpression.parse(s);
  } on FormatException catch (err) {
    throw FormatException('$ctx: field "$key" is not valid dice: ${err.message}');
  }
}

T _requireEnum<T extends Enum>(
    Map<String, Object?> m, String key, String ctx, List<T> values) {
  final name = _requireString(m, key, ctx);
  return _enumByName(values, name, key, ctx);
}

T _enumByName<T extends Enum>(
    List<T> values, String name, String field, String ctx) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('$ctx: field "$field" has unknown enum value "$name".');
}
