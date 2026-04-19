import '../core/ability.dart';
import '../core/advantage_state.dart';
import '../core/dice_expression.dart';
import '../core/proficiency.dart';
import 'duration.dart';
import 'effect_descriptor.dart';
import 'predicate.dart';

/// JSON codecs for the Tier 2 sealed families ([EffectDescriptor], [Predicate],
/// [EffectDuration], [AcFormula]). Closed tagged unions keyed on `"t"` — unknown
/// tags fail fast at decode time with a `FormatException` carrying the caller's
/// context id.
///
/// Wire conventions:
///   * Dice: canonical string (`DiceExpression.toString()` / `parse`).
///   * Enums: `.name`.
///   * ContentReference: namespaced id string, emitted as-is.
///   * Optional fields: omitted when absent or equal to the domain default;
///     decoders fill defaults back in.
///
/// Every decoder accepts an opaque `Object? json` and a `ctx` prefix; callers
/// should pass the owning entry id (e.g. `"srd:fireball"`) so error messages
/// stay traceable.

// ----------------------------------------------------------------------------
// EffectDescriptor
// ----------------------------------------------------------------------------

Map<String, Object?> encodeEffect(EffectDescriptor e) {
  return switch (e) {
    ModifyAttackRoll() => _encodeModifyAttackRoll(e),
    ModifyDamageRoll() => _encodeModifyDamageRoll(e),
    ModifySave() => _encodeModifySave(e),
    ModifyAc() => _encodeModifyAc(e),
    ModifyResistances() => _encodeModifyResistances(e),
    GrantCondition() => _encodeGrantCondition(e),
    GrantProficiency() => _encodeGrantProficiency(e),
    GrantSenseOrSpeed() => _encodeGrantSenseOrSpeed(e),
    Heal() => _encodeHeal(e),
    ConditionInteraction() => _encodeConditionInteraction(e),
    CustomEffect() => _encodeCustomEffect(e),
  };
}

EffectDescriptor decodeEffect(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'EffectDescriptor');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'modifyAttackRoll':
      return _decodeModifyAttackRoll(m, ctx);
    case 'modifyDamageRoll':
      return _decodeModifyDamageRoll(m, ctx);
    case 'modifySave':
      return _decodeModifySave(m, ctx);
    case 'modifyAc':
      return _decodeModifyAc(m, ctx);
    case 'modifyResistances':
      return _decodeModifyResistances(m, ctx);
    case 'grantCondition':
      return _decodeGrantCondition(m, ctx);
    case 'grantProficiency':
      return _decodeGrantProficiency(m, ctx);
    case 'grantSenseOrSpeed':
      return _decodeGrantSenseOrSpeed(m, ctx);
    case 'heal':
      return _decodeHeal(m, ctx);
    case 'conditionInteraction':
      return _decodeConditionInteraction(m, ctx);
    case 'customEffect':
      return _decodeCustomEffect(m, ctx);
    default:
      throw FormatException('$ctx: unknown effect tag "$tag".');
  }
}

Map<String, Object?> _encodeModifyAttackRoll(ModifyAttackRoll e) {
  final out = <String, Object?>{'t': 'modifyAttackRoll'};
  if (e.when is! Always) out['when'] = encodePredicate(e.when);
  if (e.flatBonus != 0) out['flatBonus'] = e.flatBonus;
  if (e.advantage != AdvantageState.normal) out['advantage'] = e.advantage.name;
  if (e.extraDice != null) out['extraDice'] = e.extraDice!.toString();
  if (e.appliesTo != EffectTarget.attacker) {
    out['appliesTo'] = e.appliesTo.name;
  }
  return out;
}

ModifyAttackRoll _decodeModifyAttackRoll(Map<String, Object?> m, String ctx) {
  return ModifyAttackRoll(
    when: _optPredicate(m, 'when', ctx) ?? const Always(),
    flatBonus: _optInt(m, 'flatBonus', ctx) ?? 0,
    advantage: _optEnum(m, 'advantage', ctx, AdvantageState.values) ??
        AdvantageState.normal,
    extraDice: _optDice(m, 'extraDice', ctx),
    appliesTo: _optEnum(m, 'appliesTo', ctx, EffectTarget.values) ??
        EffectTarget.attacker,
  );
}

Map<String, Object?> _encodeModifyDamageRoll(ModifyDamageRoll e) {
  final out = <String, Object?>{'t': 'modifyDamageRoll'};
  if (e.when is! Always) out['when'] = encodePredicate(e.when);
  if (e.flatBonus != 0) out['flatBonus'] = e.flatBonus;
  if (e.extraDice != null) out['extraDice'] = e.extraDice!.toString();
  if (e.extraTypedDice.isNotEmpty) {
    out['extraTypedDice'] = e.extraTypedDice
        .map((td) => <String, Object?>{
              'dice': td.dice.toString(),
              'damageTypeId': td.damageTypeId,
            })
        .toList();
  }
  if (e.damageTypeOverride != null) {
    out['damageTypeOverride'] = e.damageTypeOverride;
  }
  return out;
}

ModifyDamageRoll _decodeModifyDamageRoll(Map<String, Object?> m, String ctx) {
  final rawTyped = m['extraTypedDice'];
  final typed = <TypedDice>[];
  if (rawTyped != null) {
    if (rawTyped is! List) {
      throw FormatException(
          '$ctx: "extraTypedDice" must be an array (got ${rawTyped.runtimeType}).');
    }
    for (final raw in rawTyped) {
      if (raw is! Map) {
        throw FormatException('$ctx: "extraTypedDice" entries must be objects.');
      }
      final entry = raw.cast<String, Object?>();
      typed.add(TypedDice(
        dice: _requireDice(entry, 'dice', ctx),
        damageTypeId: _requireString(entry, 'damageTypeId', ctx),
      ));
    }
  }
  return ModifyDamageRoll(
    when: _optPredicate(m, 'when', ctx) ?? const Always(),
    flatBonus: _optInt(m, 'flatBonus', ctx) ?? 0,
    extraDice: _optDice(m, 'extraDice', ctx),
    extraTypedDice: typed,
    damageTypeOverride: _optString(m, 'damageTypeOverride', ctx),
  );
}

Map<String, Object?> _encodeModifySave(ModifySave e) {
  final out = <String, Object?>{
    't': 'modifySave',
    'ability': e.ability.name,
  };
  if (e.when is! Always) out['when'] = encodePredicate(e.when);
  if (e.flatBonus != 0) out['flatBonus'] = e.flatBonus;
  if (e.advantage != AdvantageState.normal) out['advantage'] = e.advantage.name;
  if (e.autoSucceed) out['autoSucceed'] = true;
  if (e.autoFail) out['autoFail'] = true;
  return out;
}

ModifySave _decodeModifySave(Map<String, Object?> m, String ctx) {
  return ModifySave(
    ability: _requireEnum(m, 'ability', ctx, Ability.values),
    when: _optPredicate(m, 'when', ctx) ?? const Always(),
    flatBonus: _optInt(m, 'flatBonus', ctx) ?? 0,
    advantage: _optEnum(m, 'advantage', ctx, AdvantageState.values) ??
        AdvantageState.normal,
    autoSucceed: _optBool(m, 'autoSucceed', ctx) ?? false,
    autoFail: _optBool(m, 'autoFail', ctx) ?? false,
  );
}

Map<String, Object?> _encodeModifyAc(ModifyAc e) {
  final out = <String, Object?>{'t': 'modifyAc'};
  if (e.when is! Always) out['when'] = encodePredicate(e.when);
  if (e.flat != 0) out['flat'] = e.flat;
  if (e.formula != null) out['formula'] = encodeAcFormula(e.formula!);
  return out;
}

ModifyAc _decodeModifyAc(Map<String, Object?> m, String ctx) {
  final rawFormula = m['formula'];
  return ModifyAc(
    when: _optPredicate(m, 'when', ctx) ?? const Always(),
    flat: _optInt(m, 'flat', ctx) ?? 0,
    formula: rawFormula == null ? null : decodeAcFormula(rawFormula, ctx),
  );
}

Map<String, Object?> _encodeModifyResistances(ModifyResistances e) {
  return <String, Object?>{
    't': 'modifyResistances',
    'kind': e.kind.name,
    if (e.add.isNotEmpty) 'add': (e.add.toList()..sort()),
    if (e.remove.isNotEmpty) 'remove': (e.remove.toList()..sort()),
  };
}

ModifyResistances _decodeModifyResistances(
    Map<String, Object?> m, String ctx) {
  return ModifyResistances(
    kind: _requireEnum(m, 'kind', ctx, ResistanceKind.values),
    add: _optStringSet(m, 'add', ctx),
    remove: _optStringSet(m, 'remove', ctx),
  );
}

Map<String, Object?> _encodeGrantCondition(GrantCondition e) {
  final out = <String, Object?>{
    't': 'grantCondition',
    'conditionId': e.conditionId,
    'duration': encodeDuration(e.duration),
  };
  if (e.saveToResist != null) {
    final s = e.saveToResist!;
    out['saveToResist'] = <String, Object?>{
      'ability': s.ability.name,
      'dc': s.dc,
      if (s.halfOnSuccess) 'halfOnSuccess': true,
    };
  }
  return out;
}

GrantCondition _decodeGrantCondition(Map<String, Object?> m, String ctx) {
  final rawSave = m['saveToResist'];
  SaveSpec? save;
  if (rawSave != null) {
    if (rawSave is! Map) {
      throw FormatException('$ctx: "saveToResist" must be an object.');
    }
    final s = rawSave.cast<String, Object?>();
    save = SaveSpec(
      ability: _requireEnum(s, 'ability', ctx, Ability.values),
      dc: _requireInt(s, 'dc', ctx),
      halfOnSuccess: _optBool(s, 'halfOnSuccess', ctx) ?? false,
    );
  }
  return GrantCondition(
    conditionId: _requireString(m, 'conditionId', ctx),
    duration: decodeDuration(m['duration'], ctx),
    saveToResist: save,
  );
}

Map<String, Object?> _encodeGrantProficiency(GrantProficiency e) {
  final out = <String, Object?>{
    't': 'grantProficiency',
    'kind': e.kind.name,
    'targetId': e.targetId,
  };
  if (e.level != Proficiency.full) out['level'] = e.level.name;
  return out;
}

GrantProficiency _decodeGrantProficiency(Map<String, Object?> m, String ctx) {
  return GrantProficiency(
    kind: _requireEnum(m, 'kind', ctx, ProficiencyKind.values),
    targetId: _requireString(m, 'targetId', ctx),
    level: _optEnum(m, 'level', ctx, Proficiency.values) ?? Proficiency.full,
  );
}

Map<String, Object?> _encodeGrantSenseOrSpeed(GrantSenseOrSpeed e) => {
      't': 'grantSenseOrSpeed',
      'kind': e.kind.name,
      'value': e.value,
    };

GrantSenseOrSpeed _decodeGrantSenseOrSpeed(
    Map<String, Object?> m, String ctx) {
  return GrantSenseOrSpeed(
    kind: _requireEnum(m, 'kind', ctx, SenseOrSpeedKind.values),
    value: _requireInt(m, 'value', ctx),
  );
}

Map<String, Object?> _encodeHeal(Heal e) {
  final out = <String, Object?>{'t': 'heal'};
  if (e.dice != null) out['dice'] = e.dice!.toString();
  if (e.flatBonus != 0) out['flatBonus'] = e.flatBonus;
  return out;
}

Heal _decodeHeal(Map<String, Object?> m, String ctx) {
  return Heal(
    dice: _optDice(m, 'dice', ctx),
    flatBonus: _optInt(m, 'flatBonus', ctx) ?? 0,
  );
}

Map<String, Object?> _encodeConditionInteraction(ConditionInteraction e) {
  final out = <String, Object?>{'t': 'conditionInteraction'};
  if (e.incapacitated) out['incapacitated'] = true;
  if (e.speedZero) out['speedZero'] = true;
  if (e.autoFailSavesOf.isNotEmpty) {
    out['autoFailSavesOf'] =
        (e.autoFailSavesOf.map((a) => a.name).toList()..sort());
  }
  if (e.imposedAdvantageOnAttacksAgainst) {
    out['imposedAdvantageOnAttacksAgainst'] = true;
  }
  if (e.attacksHaveDisadvantage) out['attacksHaveDisadvantage'] = true;
  if (e.cannotTakeActions) out['cannotTakeActions'] = true;
  if (e.cannotTakeReactions) out['cannotTakeReactions'] = true;
  if (e.grappled) out['grappled'] = true;
  if (e.restrained) out['restrained'] = true;
  if (e.invisibleToSight) out['invisibleToSight'] = true;
  return out;
}

ConditionInteraction _decodeConditionInteraction(
    Map<String, Object?> m, String ctx) {
  final rawSaves = m['autoFailSavesOf'];
  final saves = <Ability>{};
  if (rawSaves != null) {
    if (rawSaves is! List) {
      throw FormatException('$ctx: "autoFailSavesOf" must be an array.');
    }
    for (final s in rawSaves) {
      if (s is! String) {
        throw FormatException(
            '$ctx: "autoFailSavesOf" entries must be strings.');
      }
      saves.add(_enumByName(Ability.values, s, 'autoFailSavesOf', ctx));
    }
  }
  return ConditionInteraction(
    incapacitated: _optBool(m, 'incapacitated', ctx) ?? false,
    speedZero: _optBool(m, 'speedZero', ctx) ?? false,
    autoFailSavesOf: saves,
    imposedAdvantageOnAttacksAgainst:
        _optBool(m, 'imposedAdvantageOnAttacksAgainst', ctx) ?? false,
    attacksHaveDisadvantage:
        _optBool(m, 'attacksHaveDisadvantage', ctx) ?? false,
    cannotTakeActions: _optBool(m, 'cannotTakeActions', ctx) ?? false,
    cannotTakeReactions: _optBool(m, 'cannotTakeReactions', ctx) ?? false,
    grappled: _optBool(m, 'grappled', ctx) ?? false,
    restrained: _optBool(m, 'restrained', ctx) ?? false,
    invisibleToSight: _optBool(m, 'invisibleToSight', ctx) ?? false,
  );
}

Map<String, Object?> _encodeCustomEffect(CustomEffect e) {
  final out = <String, Object?>{
    't': 'customEffect',
    'implementationId': e.implementationId,
  };
  if (e.parameters.isNotEmpty) out['parameters'] = e.parameters;
  return out;
}

CustomEffect _decodeCustomEffect(Map<String, Object?> m, String ctx) {
  final rawParams = m['parameters'];
  Map<String, Object?> params = const {};
  if (rawParams != null) {
    if (rawParams is! Map) {
      throw FormatException('$ctx: "parameters" must be an object.');
    }
    params = rawParams.cast<String, Object?>();
  }
  return CustomEffect(
    implementationId: _requireString(m, 'implementationId', ctx),
    parameters: params,
  );
}

// ----------------------------------------------------------------------------
// Predicate
// ----------------------------------------------------------------------------

Map<String, Object?> encodePredicate(Predicate p) {
  return switch (p) {
    Always() => const {'t': 'always'},
    All() => {'t': 'all', 'of': p.all.map(encodePredicate).toList()},
    Any() => {'t': 'any', 'of': p.any.map(encodePredicate).toList()},
    Not() => {'t': 'not', 'p': encodePredicate(p.p)},
    AttackerHasCondition() => {'t': 'attackerHasCondition', 'id': p.id},
    TargetHasCondition() => {'t': 'targetHasCondition', 'id': p.id},
    AttackIsMelee() => const {'t': 'attackIsMelee'},
    AttackIsRanged() => const {'t': 'attackIsRanged'},
    AttackUsesAbility() => {'t': 'attackUsesAbility', 'ability': p.ability.name},
    WeaponHasProperty() => {'t': 'weaponHasProperty', 'id': p.id},
    DamageTypeIs() => {'t': 'damageTypeIs', 'id': p.id},
    IsCritical() => const {'t': 'isCritical'},
    HasAdvantage() => const {'t': 'hasAdvantage'},
    EffectActive() => {'t': 'effectActive', 'effectId': p.effectId},
  };
}

Predicate decodePredicate(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'Predicate');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'always':
      return const Always();
    case 'all':
      return All(_requirePredList(m, 'of', ctx));
    case 'any':
      return Any(_requirePredList(m, 'of', ctx));
    case 'not':
      return Not(decodePredicate(m['p'], ctx));
    case 'attackerHasCondition':
      return AttackerHasCondition(_requireString(m, 'id', ctx));
    case 'targetHasCondition':
      return TargetHasCondition(_requireString(m, 'id', ctx));
    case 'attackIsMelee':
      return const AttackIsMelee();
    case 'attackIsRanged':
      return const AttackIsRanged();
    case 'attackUsesAbility':
      return AttackUsesAbility(_requireEnum(m, 'ability', ctx, Ability.values));
    case 'weaponHasProperty':
      return WeaponHasProperty(_requireString(m, 'id', ctx));
    case 'damageTypeIs':
      return DamageTypeIs(_requireString(m, 'id', ctx));
    case 'isCritical':
      return const IsCritical();
    case 'hasAdvantage':
      return const HasAdvantage();
    case 'effectActive':
      return EffectActive(_requireString(m, 'effectId', ctx));
    default:
      throw FormatException('$ctx: unknown predicate tag "$tag".');
  }
}

List<Predicate> _requirePredList(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v is! List) {
    throw FormatException(
        '$ctx: "$key" must be an array of predicates (got ${v.runtimeType}).');
  }
  return v.map((e) => decodePredicate(e, ctx)).toList();
}

// ----------------------------------------------------------------------------
// EffectDuration
// ----------------------------------------------------------------------------

Map<String, Object?> encodeDuration(EffectDuration d) {
  return switch (d) {
    Instantaneous() => const {'t': 'instantaneous'},
    RoundsDuration() => {'t': 'rounds', 'rounds': d.rounds},
    MinutesDuration() => {'t': 'minutes', 'minutes': d.minutes},
    UntilRest() => {'t': 'untilRest', 'kind': d.kind.name},
    ConcentrationDuration() => {
        't': 'concentration',
        'max': encodeDuration(d.max),
      },
    UntilRemoved() => const {'t': 'untilRemoved'},
  };
}

EffectDuration decodeDuration(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'EffectDuration');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'instantaneous':
      return const Instantaneous();
    case 'rounds':
      return RoundsDuration(_requireInt(m, 'rounds', ctx));
    case 'minutes':
      return MinutesDuration(_requireInt(m, 'minutes', ctx));
    case 'untilRest':
      return UntilRest(_requireEnum(m, 'kind', ctx, RestKind.values));
    case 'concentration':
      return ConcentrationDuration(decodeDuration(m['max'], ctx));
    case 'untilRemoved':
      return const UntilRemoved();
    default:
      throw FormatException('$ctx: unknown duration tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// AcFormula
// ----------------------------------------------------------------------------

Map<String, Object?> encodeAcFormula(AcFormula f) {
  return switch (f) {
    AcFlat() => {'t': 'flat', 'value': f.value},
    AcNaturalPlusDex() => {
        't': 'naturalPlusDex',
        'base': f.base,
        if (f.maxDex != null) 'maxDex': f.maxDex,
      },
    AcUnarmored() => {'t': 'unarmored', 'ability': f.ability.name},
    AcMageArmor() => const {'t': 'mageArmor'},
  };
}

AcFormula decodeAcFormula(Object? json, String ctx) {
  final m = _asObject(json, ctx, 'AcFormula');
  final tag = _requireString(m, 't', ctx);
  switch (tag) {
    case 'flat':
      return AcFlat(_requireInt(m, 'value', ctx));
    case 'naturalPlusDex':
      return AcNaturalPlusDex(
        base: _requireInt(m, 'base', ctx),
        maxDex: _optInt(m, 'maxDex', ctx),
      );
    case 'unarmored':
      return AcUnarmored(_requireEnum(m, 'ability', ctx, Ability.values));
    case 'mageArmor':
      return const AcMageArmor();
    default:
      throw FormatException('$ctx: unknown AC formula tag "$tag".');
  }
}

// ----------------------------------------------------------------------------
// Private helpers
// ----------------------------------------------------------------------------

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

Set<String> _optStringSet(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return const {};
  if (v is! List) {
    throw FormatException('$ctx: "$key" must be an array when present.');
  }
  final out = <String>{};
  for (final s in v) {
    if (s is! String) {
      throw FormatException('$ctx: "$key" must contain only strings.');
    }
    out.add(s);
  }
  return out;
}

Predicate? _optPredicate(Map<String, Object?> m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  return decodePredicate(v, ctx);
}

T _requireEnum<T extends Enum>(
    Map<String, Object?> m, String key, String ctx, List<T> values) {
  final name = _requireString(m, key, ctx);
  return _enumByName(values, name, key, ctx);
}

T? _optEnum<T extends Enum>(
    Map<String, Object?> m, String key, String ctx, List<T> values) {
  final name = _optString(m, key, ctx);
  if (name == null) return null;
  return _enumByName(values, name, key, ctx);
}

T _enumByName<T extends Enum>(
    List<T> values, String name, String field, String ctx) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('$ctx: field "$field" has unknown enum value "$name".');
}
