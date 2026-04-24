import 'dart:convert';

import '../core/spell_level.dart';
import '../effect/effect_descriptor.dart';
import '../effect/effect_descriptor_codec.dart';
import '../package/catalog_entry.dart';
import 'area_of_effect.dart';
import 'casting_time.dart';
import 'spell.dart';
import 'spell_components.dart';
import 'spell_duration.dart';
import 'spell_range.dart';
import 'spell_target.dart';

/// JSON codec for Tier 2 content class [Spell] and its sealed sub-families:
/// [CastingTime], [SpellRange], [AreaOfEffect], [SpellDuration],
/// [SpellComponent]. Tagged-union shape on `"t"` — unknown tags fail fast
/// with the owning entry id prefix.
///
/// Effects are nested through [encodeEffect]/[decodeEffect] from
/// `effect_descriptor_codec.dart`.

// ----------------------------------------------------------------------------
// Spell (top-level)
// ----------------------------------------------------------------------------

/// `body`: see docstring above for the canonical shape.
Spell spellFromEntry(CatalogEntry e) {
  final body = _decodeBody(e, 'Spell');
  return Spell(
    id: e.id,
    name: e.name,
    level: SpellLevel(_requireInt(body, 'level', e.id)),
    schoolId: _requireString(body, 'schoolId', e.id),
    castingTime: decodeCastingTime(body['castingTime'], e.id),
    range: decodeSpellRange(body['range'], e.id),
    components: _decodeComponentList(body, 'components', e.id),
    duration: decodeSpellDuration(body['duration'], e.id),
    targets: _decodeTargetList(body, 'targets', e.id),
    area: body['area'] == null ? null : decodeAreaOfEffect(body['area'], e.id),
    effects: _decodeEffectList(body, 'effects', e.id),
    ritual: _optBool(body, 'ritual', e.id) ?? false,
    classListIds: _optStringList(body, 'classListIds', e.id),
    description: _optString(body, 'description', e.id) ?? '',
    cantripUpgrade: _optString(body, 'cantripUpgrade', e.id) ?? '',
    higherLevelSlot: _optString(body, 'higherLevelSlot', e.id) ?? '',
  );
}

CatalogEntry spellToEntry(Spell s) {
  final body = <String, Object?>{
    'level': s.level.value,
    'schoolId': s.schoolId,
    'castingTime': encodeCastingTime(s.castingTime),
    'range': encodeSpellRange(s.range),
    'components': s.components.map(encodeSpellComponent).toList(),
    'duration': encodeSpellDuration(s.duration),
  };
  if (s.targets.isNotEmpty) {
    body['targets'] = s.targets.map((t) => t.name).toList();
  }
  if (s.area != null) body['area'] = encodeAreaOfEffect(s.area!);
  if (s.effects.isNotEmpty) {
    body['effects'] = s.effects.map(encodeEffect).toList();
  }
  if (s.ritual) body['ritual'] = true;
  if (s.classListIds.isNotEmpty) {
    body['classListIds'] = s.classListIds.toList();
  }
  if (s.description.isNotEmpty) body['description'] = s.description;
  if (s.cantripUpgrade.isNotEmpty) body['cantripUpgrade'] = s.cantripUpgrade;
  if (s.higherLevelSlot.isNotEmpty) body['higherLevelSlot'] = s.higherLevelSlot;
  return CatalogEntry(id: s.id, name: s.name, bodyJson: jsonEncode(body));
}

// ----------------------------------------------------------------------------
// CastingTime
// ----------------------------------------------------------------------------

Map<String, Object?> encodeCastingTime(CastingTime c) {
  return switch (c) {
    ActionCast() => const {'t': 'action'},
    BonusActionCast() => const {'t': 'bonusAction'},
    ReactionCast() => {'t': 'reaction', 'trigger': c.trigger},
    MinutesCast() => {'t': 'minutes', 'minutes': c.minutes},
    HoursCast() => {'t': 'hours', 'hours': c.hours},
  };
}

CastingTime decodeCastingTime(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'CastingTime');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'action':
      return const ActionCast();
    case 'bonusAction':
      return const BonusActionCast();
    case 'reaction':
      return ReactionCast(_requireString(m, 'trigger', ctx));
    case 'minutes':
      return MinutesCast(_requireInt(m, 'minutes', ctx));
    case 'hours':
      return HoursCast(_requireInt(m, 'hours', ctx));
    default:
      throw FormatException('$ctx: unknown casting-time tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// SpellRange
// ----------------------------------------------------------------------------

Map<String, Object?> encodeSpellRange(SpellRange r) {
  return switch (r) {
    SelfRange() => const {'t': 'self'},
    TouchRange() => const {'t': 'touch'},
    FeetRange() => {'t': 'feet', 'feet': r.feet},
    MilesRange() => {'t': 'miles', 'miles': r.miles},
    SightRange() => const {'t': 'sight'},
    UnlimitedRange() => const {'t': 'unlimited'},
  };
}

SpellRange decodeSpellRange(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'SpellRange');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'self':
      return const SelfRange();
    case 'touch':
      return const TouchRange();
    case 'feet':
      return FeetRange(_requireNum(m, 'feet', ctx).toDouble());
    case 'miles':
      return MilesRange(_requireNum(m, 'miles', ctx).toDouble());
    case 'sight':
      return const SightRange();
    case 'unlimited':
      return const UnlimitedRange();
    default:
      throw FormatException('$ctx: unknown range tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// AreaOfEffect
// ----------------------------------------------------------------------------

Map<String, Object?> encodeAreaOfEffect(AreaOfEffect a) {
  return switch (a) {
    ConeAoE() => {'t': 'cone', 'lengthFt': a.lengthFt},
    CubeAoE() => {'t': 'cube', 'sideFt': a.sideFt},
    CylinderAoE() => {
        't': 'cylinder',
        'radiusFt': a.radiusFt,
        'heightFt': a.heightFt,
      },
    EmanationAoE() => {'t': 'emanation', 'distanceFt': a.distanceFt},
    LineAoE() => {'t': 'line', 'lengthFt': a.lengthFt, 'widthFt': a.widthFt},
    SphereAoE() => {'t': 'sphere', 'radiusFt': a.radiusFt},
  };
}

AreaOfEffect decodeAreaOfEffect(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'AreaOfEffect');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'cone':
      return ConeAoE(_requireNum(m, 'lengthFt', ctx).toDouble());
    case 'cube':
      return CubeAoE(_requireNum(m, 'sideFt', ctx).toDouble());
    case 'cylinder':
      return CylinderAoE(
        radiusFt: _requireNum(m, 'radiusFt', ctx).toDouble(),
        heightFt: _requireNum(m, 'heightFt', ctx).toDouble(),
      );
    case 'emanation':
      return EmanationAoE(_requireNum(m, 'distanceFt', ctx).toDouble());
    case 'line':
      return LineAoE(
        lengthFt: _requireNum(m, 'lengthFt', ctx).toDouble(),
        widthFt: _requireNum(m, 'widthFt', ctx).toDouble(),
      );
    case 'sphere':
      return SphereAoE(_requireNum(m, 'radiusFt', ctx).toDouble());
    default:
      throw FormatException('$ctx: unknown AoE tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// SpellDuration
// ----------------------------------------------------------------------------

Map<String, Object?> encodeSpellDuration(SpellDuration d) {
  return switch (d) {
    SpellInstantaneous() => const {'t': 'instantaneous'},
    SpellRounds() => {
        't': 'rounds',
        'rounds': d.rounds,
        if (d.concentration) 'concentration': true,
      },
    SpellMinutes() => {
        't': 'minutes',
        'minutes': d.minutes,
        if (d.concentration) 'concentration': true,
      },
    SpellHours() => {
        't': 'hours',
        'hours': d.hours,
        if (d.concentration) 'concentration': true,
      },
    SpellDays() => {'t': 'days', 'days': d.days},
    SpellUntilDispelled() => const {'t': 'untilDispelled'},
    SpellSpecial() => {'t': 'special', 'description': d.description},
  };
}

SpellDuration decodeSpellDuration(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'SpellDuration');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'instantaneous':
      return const SpellInstantaneous();
    case 'rounds':
      return SpellRounds(
        rounds: _requireInt(m, 'rounds', ctx),
        concentration: _optBool(m, 'concentration', ctx) ?? false,
      );
    case 'minutes':
      return SpellMinutes(
        minutes: _requireInt(m, 'minutes', ctx),
        concentration: _optBool(m, 'concentration', ctx) ?? false,
      );
    case 'hours':
      return SpellHours(
        hours: _requireInt(m, 'hours', ctx),
        concentration: _optBool(m, 'concentration', ctx) ?? false,
      );
    case 'days':
      return SpellDays(_requireInt(m, 'days', ctx));
    case 'untilDispelled':
      return const SpellUntilDispelled();
    case 'special':
      return SpellSpecial(_requireString(m, 'description', ctx));
    default:
      throw FormatException('$ctx: unknown spell-duration tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// SpellComponent
// ----------------------------------------------------------------------------

Map<String, Object?> encodeSpellComponent(SpellComponent c) {
  return switch (c) {
    VerbalComponent() => const {'t': 'v'},
    SomaticComponent() => const {'t': 's'},
    MaterialComponent() => {
        't': 'm',
        'description': c.description,
        if (c.costCp != null) 'costCp': c.costCp,
        if (c.consumed) 'consumed': true,
      },
  };
}

SpellComponent decodeSpellComponent(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'SpellComponent');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'v':
      return const VerbalComponent();
    case 's':
      return const SomaticComponent();
    case 'm':
      return MaterialComponent(
        description: _requireString(m, 'description', ctx),
        costCp: _optInt(m, 'costCp', ctx),
        consumed: _optBool(m, 'consumed', ctx) ?? false,
      );
    default:
      throw FormatException('$ctx: unknown component tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// List helpers
// ----------------------------------------------------------------------------

List<SpellComponent> _decodeComponentList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  return raw.map((e) => decodeSpellComponent(e, ctx)).toList();
}

List<SpellTarget> _decodeTargetList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  final out = <SpellTarget>[];
  for (final s in raw) {
    if (s is! String) {
      throw FormatException('$ctx: "$key" must contain only strings.');
    }
    out.add(_enumByName(SpellTarget.values, s, key, ctx));
  }
  return out;
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

List<String> _optStringList(
    Map<String, Object?> body, String key, String ctx) {
  final raw = body[key];
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  final out = <String>[];
  for (final s in raw) {
    if (s is! String) {
      throw FormatException('$ctx: "$key" must contain only strings.');
    }
    out.add(s);
  }
  return out;
}

// ----------------------------------------------------------------------------
// Scalar helpers (duplicated from catalog_json_codecs to keep codec modules
// standalone; renaming to a shared module is a refactor for another turn).
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
