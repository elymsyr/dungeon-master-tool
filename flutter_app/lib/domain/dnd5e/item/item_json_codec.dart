import 'dart:convert';

import '../core/ability.dart';
import '../core/dice_expression.dart';
import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'item.dart';

/// JSON codec for Tier 2 content class [Item] — sealed family with 7 variants
/// (Weapon, Armor, Shield, Gear, Tool, Ammunition, MagicItem) plus the nested
/// sealed [AttunementPrereq] family (4 variants). Tagged on `"t"`. Magic-item
/// effects route through the shared `effect_descriptor_codec`.
///
/// Item-wide base fields (`id`, `name`, `weightLb`, `costCp`, `rarityId`) are
/// written into every variant's body; optional numeric defaults (`weightLb=0`,
/// `costCp=0`) are omitted on encode.
///
/// `id` + `name` live on the owning [CatalogEntry]; the codec asserts they
/// match on decode and only re-emits variant-specific fields inside the body.

// ----------------------------------------------------------------------------
// Item (top-level)
// ----------------------------------------------------------------------------

Item itemFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Item');
  final tag = _requireString(body, 't', e.id);
  final weightLb = _optNum(body, 'weightLb', e.id)?.toDouble() ?? 0;
  final costCp = _optInt(body, 'costCp', e.id) ?? 0;
  final rarityId = _requireString(body, 'rarityId', e.id);
  switch (tag) {
    case 'weapon':
      return _decodeWeapon(e, body, weightLb, costCp, rarityId);
    case 'armor':
      return _decodeArmor(e, body, weightLb, costCp, rarityId);
    case 'shield':
      return _decodeShield(e, body, weightLb, costCp, rarityId);
    case 'gear':
      return _decodeGear(e, body, weightLb, costCp, rarityId);
    case 'tool':
      return _decodeTool(e, body, weightLb, costCp, rarityId);
    case 'ammunition':
      return _decodeAmmunition(e, body, weightLb, costCp, rarityId);
    case 'magicItem':
      return _decodeMagicItem(e, body, weightLb, costCp, rarityId);
    default:
      throw FormatException('${e.id}: unknown item tag "$tag".');
  }
}

CatalogEntry itemToEntry(Item i) {
  final body = <String, Object?>{};
  switch (i) {
    case Weapon():
      body['t'] = 'weapon';
      break;
    case Armor():
      body['t'] = 'armor';
      break;
    case Shield():
      body['t'] = 'shield';
      break;
    case Gear():
      body['t'] = 'gear';
      break;
    case Tool():
      body['t'] = 'tool';
      break;
    case Ammunition():
      body['t'] = 'ammunition';
      break;
    case MagicItem():
      body['t'] = 'magicItem';
      break;
  }
  if (i.weightLb != 0) body['weightLb'] = i.weightLb;
  if (i.costCp != 0) body['costCp'] = i.costCp;
  body['rarityId'] = i.rarityId;
  switch (i) {
    case Weapon():
      _encodeWeapon(body, i);
      break;
    case Armor():
      _encodeArmor(body, i);
      break;
    case Shield():
      _encodeShield(body, i);
      break;
    case Gear():
      _encodeGear(body, i);
      break;
    case Tool():
      _encodeTool(body, i);
      break;
    case Ammunition():
      _encodeAmmunition(body, i);
      break;
    case MagicItem():
      _encodeMagicItem(body, i);
      break;
  }
  return CatalogEntry(id: i.id, name: i.name, bodyJson: jsonEncode(body));
}

// ----------------------------------------------------------------------------
// Weapon
// ----------------------------------------------------------------------------

void _encodeWeapon(Map<String, Object?> body, Weapon w) {
  body['category'] = w.category.name;
  body['type'] = w.type.name;
  body['damage'] = w.damage.toString();
  body['damageTypeId'] = w.damageTypeId;
  if (w.propertyIds.isNotEmpty) {
    body['propertyIds'] = (w.propertyIds.toList()..sort());
  }
  if (w.masteryId != null) body['masteryId'] = w.masteryId;
  if (w.range != null) {
    body['range'] = <String, Object?>{
      'normal': w.range!.normal,
      'long': w.range!.long,
    };
  }
  if (w.versatileDamage != null) {
    body['versatileDamage'] = w.versatileDamage!.toString();
  }
}

Weapon _decodeWeapon(CatalogEntry e, Map<String, Object?> body, double weightLb,
    int costCp, String rarityId) {
  final rawRange = body['range'];
  RangePair? range;
  if (rawRange != null) {
    if (rawRange is! Map) {
      throw FormatException('${e.id}: "range" must be an object.');
    }
    final r = rawRange.cast<String, Object?>();
    range = RangePair(
      normal: _requireInt(r, 'normal', e.id),
      long: _requireInt(r, 'long', e.id),
    );
  }
  return Weapon(
    id: e.id,
    name: e.name,
    weightLb: weightLb,
    costCp: costCp,
    rarityId: rarityId,
    category: _requireEnum(body, 'category', e.id, WeaponCategory.values),
    type: _requireEnum(body, 'type', e.id, WeaponType.values),
    damage: _requireDice(body, 'damage', e.id),
    damageTypeId: _requireString(body, 'damageTypeId', e.id),
    propertyIds: _optStringSet(body, 'propertyIds', e.id),
    masteryId: _optString(body, 'masteryId', e.id),
    range: range,
    versatileDamage: _optDice(body, 'versatileDamage', e.id),
  );
}

// ----------------------------------------------------------------------------
// Armor
// ----------------------------------------------------------------------------

void _encodeArmor(Map<String, Object?> body, Armor a) {
  body['categoryId'] = a.categoryId;
  body['baseAc'] = a.baseAc;
  if (a.strengthRequirement != null) {
    body['strengthRequirement'] = a.strengthRequirement;
  }
}

Armor _decodeArmor(CatalogEntry e, Map<String, Object?> body, double weightLb,
        int costCp, String rarityId) =>
    Armor(
      id: e.id,
      name: e.name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      categoryId: _requireString(body, 'categoryId', e.id),
      baseAc: _requireInt(body, 'baseAc', e.id),
      strengthRequirement: _optInt(body, 'strengthRequirement', e.id),
    );

// ----------------------------------------------------------------------------
// Shield
// ----------------------------------------------------------------------------

void _encodeShield(Map<String, Object?> body, Shield s) {
  if (s.acBonus != 2) body['acBonus'] = s.acBonus;
}

Shield _decodeShield(CatalogEntry e, Map<String, Object?> body, double weightLb,
        int costCp, String rarityId) =>
    Shield(
      id: e.id,
      name: e.name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      acBonus: _optInt(body, 'acBonus', e.id) ?? 2,
    );

// ----------------------------------------------------------------------------
// Gear
// ----------------------------------------------------------------------------

void _encodeGear(Map<String, Object?> body, Gear g) {
  if (g.description.isNotEmpty) body['description'] = g.description;
}

Gear _decodeGear(CatalogEntry e, Map<String, Object?> body, double weightLb,
        int costCp, String rarityId) =>
    Gear(
      id: e.id,
      name: e.name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      description: _optString(body, 'description', e.id) ?? '',
    );

// ----------------------------------------------------------------------------
// Tool
// ----------------------------------------------------------------------------

void _encodeTool(Map<String, Object?> body, Tool t) {
  if (t.proficiencyId != null) body['proficiencyId'] = t.proficiencyId;
}

Tool _decodeTool(CatalogEntry e, Map<String, Object?> body, double weightLb,
        int costCp, String rarityId) =>
    Tool(
      id: e.id,
      name: e.name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      proficiencyId: _optString(body, 'proficiencyId', e.id),
    );

// ----------------------------------------------------------------------------
// Ammunition
// ----------------------------------------------------------------------------

void _encodeAmmunition(Map<String, Object?> body, Ammunition a) {
  if (a.quantityPerStack != 1) body['quantityPerStack'] = a.quantityPerStack;
}

Ammunition _decodeAmmunition(CatalogEntry e, Map<String, Object?> body,
        double weightLb, int costCp, String rarityId) =>
    Ammunition(
      id: e.id,
      name: e.name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      quantityPerStack: _optInt(body, 'quantityPerStack', e.id) ?? 1,
    );

// ----------------------------------------------------------------------------
// MagicItem
// ----------------------------------------------------------------------------

void _encodeMagicItem(Map<String, Object?> body, MagicItem mi) {
  if (mi.baseItemId != null) body['baseItemId'] = mi.baseItemId;
  if (mi.requiresAttunement) body['requiresAttunement'] = true;
  if (mi.attunementPrereq != null) {
    body['attunementPrereq'] = encodeAttunementPrereq(mi.attunementPrereq!);
  }
  if (mi.effects.isNotEmpty) {
    body['effects'] = mi.effects.map(encodeEffect).toList();
  }
  if (mi.grantsSpellIds.isNotEmpty) {
    body['grantsSpellIds'] = mi.grantsSpellIds;
  }
  if (mi.grantsChargedSpells.isNotEmpty) {
    body['grantsChargedSpells'] = mi.grantsChargedSpells
        .map((cs) => <String, Object?>{
              'spellId': cs.spellId,
              if (cs.chargesCost != 1) 'chargesCost': cs.chargesCost,
            })
        .toList();
  }
  if (mi.acBonus != 0) body['acBonus'] = mi.acBonus;
  if (mi.abilityBonuses.isNotEmpty) {
    body['abilityBonuses'] = {
      for (final e in mi.abilityBonuses.entries) e.key.short: e.value,
    };
  }
}

MagicItem _decodeMagicItem(CatalogEntry e, Map<String, Object?> body,
    double weightLb, int costCp, String rarityId) {
  final rawPrereq = body['attunementPrereq'];
  final prereq =
      rawPrereq == null ? null : decodeAttunementPrereq(rawPrereq, e.id);
  final rawEffects = body['effects'];
  final effects = <EffectDescriptor>[];
  if (rawEffects != null) {
    if (rawEffects is! List) {
      throw FormatException('${e.id}: "effects" must be an array.');
    }
    for (final eff in rawEffects) {
      effects.add(decodeEffect(eff, e.id));
    }
  }
  final grantsChargedSpells = <ChargedSpell>[];
  final rawCharged = body['grantsChargedSpells'];
  if (rawCharged != null) {
    if (rawCharged is! List) {
      throw FormatException(
          '${e.id}: "grantsChargedSpells" must be an array.');
    }
    for (final entry in rawCharged) {
      if (entry is! Map) {
        throw FormatException(
            '${e.id}: "grantsChargedSpells" entries must be objects.');
      }
      final m = entry.cast<String, Object?>();
      grantsChargedSpells.add(ChargedSpell(
        spellId: _requireString(m, 'spellId', e.id),
        chargesCost: _optInt(m, 'chargesCost', e.id) ?? 1,
      ));
    }
  }
  return MagicItem(
    id: e.id,
    name: e.name,
    weightLb: weightLb,
    costCp: costCp,
    rarityId: rarityId,
    baseItemId: _optString(body, 'baseItemId', e.id),
    requiresAttunement: _optBool(body, 'requiresAttunement', e.id) ?? false,
    attunementPrereq: prereq,
    effects: effects,
    grantsSpellIds: _decodeStringList(body, 'grantsSpellIds', e.id),
    grantsChargedSpells: grantsChargedSpells,
    acBonus: _optInt(body, 'acBonus', e.id) ?? 0,
    abilityBonuses: _decodeAbilityBonuses(body, 'abilityBonuses', e.id),
  );
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

Map<Ability, int> _decodeAbilityBonuses(
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

// ----------------------------------------------------------------------------
// AttunementPrereq
// ----------------------------------------------------------------------------

Map<String, Object?> encodeAttunementPrereq(AttunementPrereq p) {
  return switch (p) {
    AttunementByClass() => {'t': 'byClass', 'classId': p.classId},
    AttunementBySpecies() => {'t': 'bySpecies', 'speciesId': p.speciesId},
    AttunementByAlignment() => {
        't': 'byAlignment',
        'alignmentId': p.alignmentId,
      },
    AttunementBySpellcaster() => const {'t': 'bySpellcaster'},
  };
}

AttunementPrereq decodeAttunementPrereq(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'AttunementPrereq');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'byClass':
      return AttunementByClass(_requireString(m, 'classId', ctx));
    case 'bySpecies':
      return AttunementBySpecies(_requireString(m, 'speciesId', ctx));
    case 'byAlignment':
      return AttunementByAlignment(_requireString(m, 'alignmentId', ctx));
    case 'bySpellcaster':
      return const AttunementBySpellcaster();
    default:
      throw FormatException('$ctx: unknown attunement prereq tag "$tag".');
  }
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

num? _optNum(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is! num) {
    throw FormatException('$ctx: field "$key" must be numeric when present.');
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

T _requireEnum<T extends Enum>(
    Map<String, Object?> m, String key, String ctx, List<T> values) {
  final name = _requireString(m, key, ctx);
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('$ctx: field "$key" has unknown enum value "$name".');
}
