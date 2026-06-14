/// Per-kind legacy-effect → v3 **data-field** mapper (content-convert §6;
/// master-roadmap §3 JIT / PR-3.0 slice 4).
///
/// The third pillar of the Phase-3 converter, a sibling of the value migrator
/// ([legacy_content_converter]) and the description engine
/// ([description_generator]). Where the description engine turns a legacy
/// `effects` / `granted_modifiers` row into player-facing **prose**, this module
/// turns the SAME row into the **structured data** a converted card carries so
/// the template's standing field rules (the JIT-added `when_granted` /
/// `when_equipped` rules) can keep the sheet in sync with that prose
/// (master-roadmap §1.2 "an entity card is pure data … rules fire from field
/// semantics declared once in the template").
///
/// It is **pure Dart** (zero `package:flutter` import — like its siblings) so
/// the SAME mapping runs in the offline CLI (`tool/convert_packs_v3.dart`), the
/// on-open shim, and `dart run` harnesses.
///
/// ## The canonical v3 field vocabulary ([effectTargetFields])
///
/// Each of the [parametricEffectKinds] (content-convert §6) has exactly one
/// canonical target field key. These are the field names the **JIT conversion
/// waves** add to the built-in template the moment a wave's first card needs one
/// (master-roadmap §3 decision-tree step 3) — the mapper does **not** author any
/// template field or rule itself (RULE RESET stays intact); it only produces the
/// card-side data writes, naming the fields the waves will declare. End-state
/// "every rule-bearing field is used by ≥1 card" (§3 shift 2) is preserved
/// because a field is only ever written when a real card carries that effect.
///
/// A row is written in one of three [FieldWriteMode]s:
///
///   * [FieldWriteMode.appendRow] — the field is a `recordList` / `relation`
///     list; each effect appends one row (multiple grants accumulate).
///   * [FieldWriteMode.addScalar] — the field is a numeric bonus; repeated
///     effects of the same kind **sum** (e.g. two `+1 AC` features → `ac_bonus`
///     2), matching the additive `modify_stat` fold.
///   * [FieldWriteMode.setScalar] — the field is a single scalar/text value
///     (e.g. an unarmored-AC formula); last write wins.
///
/// **Mapped rows stay described.** The converter ALSO renders every mapped row
/// into the card's Markdown (master-roadmap §3 "keep the row ALSO described") —
/// the data field automates the mechanic, the prose documents it.
library;

/// How a single [EffectFieldWrite] is applied to a converted card's attributes.
enum FieldWriteMode {
  /// Append [EffectFieldWrite.value] (a row `Map`) to a list field, creating the
  /// list if absent. Multiple grants of the same kind accumulate as rows.
  appendRow,

  /// Add [EffectFieldWrite.value] (a `num`) to the field's current numeric value
  /// (default `0`). Repeated bonuses of the same kind sum.
  addScalar,

  /// Set the field to [EffectFieldWrite.value] outright (last write wins).
  setScalar,
}

/// One write produced by [mapEffectToFields]: the target [fieldKey], the
/// [value] to write, and the [mode] describing how to merge it into a card's
/// attributes. Immutable.
class EffectFieldWrite {
  const EffectFieldWrite(this.fieldKey, this.value, this.mode);

  /// The canonical v3 template field key this effect feeds (see
  /// [effectTargetFields]).
  final String fieldKey;

  /// The value to write — a row `Map<String, dynamic>` for [FieldWriteMode.appendRow],
  /// a `num` for [FieldWriteMode.addScalar], or any scalar for [FieldWriteMode.setScalar].
  final Object? value;

  /// How [value] merges into the card's existing field value.
  final FieldWriteMode mode;

  @override
  String toString() => '$fieldKey ${mode.name} $value';
}

/// The canonical target field key for every parametric effect kind — the single
/// source of truth for the JIT waves (which add these fields to the built-in
/// template) and the harness (which asserts [mapEffectToFields] writes here).
/// Kept in lock-step with the `switch` in [mapEffectToFields]; its key set must
/// equal `parametricEffectKinds` in [description_generator] (the disposition
/// classifier and the field mapper dispatch over the same closed set).
const Map<String, String> effectTargetFields = {
  'ability_score_bonus': 'ability_bonuses',
  'ac_bonus': 'ac_bonus',
  'speed_bonus': 'speed_bonus',
  'hp_bonus_flat': 'hp_bonus',
  'hp_max_bonus_total': 'hp_bonus',
  'hp_bonus_per_level': 'hp_bonus_per_level',
  'initiative_bonus': 'initiative_bonus',
  'temp_hp_grant': 'temp_hp_grants',
  'proficiency_grant': 'granted_proficiencies',
  'proficiency_grant_raw': 'granted_proficiencies',
  'expertise_grant': 'granted_expertise',
  'language_grant': 'granted_languages',
  'spell_grant': 'granted_spells',
  'spell_always_prepared': 'always_prepared_spells',
  'cantrip_grant': 'granted_cantrips',
  'damage_resistance': 'damage_resistances',
  'damage_resistance_grant': 'damage_resistances',
  'damage_immunity': 'damage_immunities',
  'damage_immunity_grant': 'damage_immunities',
  'damage_vulnerability': 'damage_vulnerabilities',
  'damage_vulnerability_grant': 'damage_vulnerabilities',
  'condition_immunity_grant': 'condition_immunities',
  'sense_grant': 'granted_senses',
  'truesight_grant': 'granted_senses',
  'blindsight_grant': 'granted_senses',
  'unarmored_ac_formula': 'unarmored_ac_formula',
  'resource_pool_grant': 'granted_resources',
  'recovery_grant': 'resource_recovery',
  'slot_recovery_short_rest': 'resource_recovery',
  'granted_action_grant': 'granted_actions',
  'granted_bonus_action_grant': 'granted_actions',
  'granted_reaction_grant': 'granted_actions',
  'extra_attack_count': 'extra_attacks',
  'extra_attack_bump': 'extra_attacks',
  'class_level_grant': 'granted_class_levels',
  'choice_group': 'choices',
};

/// Maps one legacy effect/modifier row to the v3 data-field write(s) that carry
/// its mechanics (content-convert §6). Returns an empty list for a null/empty
/// row or a non-parametric kind (those render to description prose only — the
/// `noted` disposition — and write no field). Deterministic and side-effect-free.
///
/// The architecture supports a row mapping to **multiple** fields (the return is
/// a list); today every kind maps to one canonical field, but the converter's
/// report counts multi-field rows so a future split is observable.
List<EffectFieldWrite> mapEffectToFields(Map<String, dynamic>? effect) {
  if (effect == null || effect.isEmpty) return const <EffectFieldWrite>[];
  final kind = _str(effect['kind']);
  switch (kind) {
    case 'ability_score_bonus':
      return [
        EffectFieldWrite(
          'ability_bonuses',
          <String, dynamic>{
            'ability': _abilityKey(effect['ability'] ?? effect['target_kind']),
            'amount': _num(effect['value'], 1),
          },
          FieldWriteMode.appendRow,
        ),
      ];
    case 'ac_bonus':
      return [EffectFieldWrite('ac_bonus', _num(effect['value'], 1), FieldWriteMode.addScalar)];
    case 'speed_bonus':
      return [EffectFieldWrite('speed_bonus', _num(effect['value'], 5), FieldWriteMode.addScalar)];
    case 'hp_bonus_flat':
    case 'hp_max_bonus_total':
      return [EffectFieldWrite('hp_bonus', _num(effect['value'], 1), FieldWriteMode.addScalar)];
    case 'hp_bonus_per_level':
      return [EffectFieldWrite('hp_bonus_per_level', _num(effect['value'], 1), FieldWriteMode.addScalar)];
    case 'initiative_bonus':
      return [EffectFieldWrite('initiative_bonus', _num(effect['value'], 1), FieldWriteMode.addScalar)];
    case 'temp_hp_grant':
      return [
        EffectFieldWrite(
          'temp_hp_grants',
          <String, dynamic>{'amount': effect['value'] ?? _formula(effect)},
          FieldWriteMode.appendRow,
        ),
      ];
    case 'proficiency_grant':
    case 'proficiency_grant_raw':
      return [EffectFieldWrite('granted_proficiencies', _proficiencyRow(effect), FieldWriteMode.appendRow)];
    case 'expertise_grant':
      return [EffectFieldWrite('granted_expertise', _proficiencyRow(effect), FieldWriteMode.appendRow)];
    case 'language_grant':
      return [
        EffectFieldWrite(
          'granted_languages',
          <String, dynamic>{'language': _refValue(effect)},
          FieldWriteMode.appendRow,
        ),
      ];
    case 'spell_grant':
      return [
        EffectFieldWrite('granted_spells', <String, dynamic>{'spell': _refValue(effect)},
            FieldWriteMode.appendRow),
      ];
    case 'spell_always_prepared':
      return [
        EffectFieldWrite('always_prepared_spells',
            <String, dynamic>{'spell': _refValue(effect)}, FieldWriteMode.appendRow),
      ];
    case 'cantrip_grant':
      return [
        EffectFieldWrite('granted_cantrips', <String, dynamic>{'cantrip': _refValue(effect)},
            FieldWriteMode.appendRow),
      ];
    case 'damage_resistance':
    case 'damage_resistance_grant':
      return [
        EffectFieldWrite('damage_resistances',
            <String, dynamic>{'damage_type': _refValue(effect)}, FieldWriteMode.appendRow),
      ];
    case 'damage_immunity':
    case 'damage_immunity_grant':
      return [
        EffectFieldWrite('damage_immunities',
            <String, dynamic>{'damage_type': _refValue(effect)}, FieldWriteMode.appendRow),
      ];
    case 'damage_vulnerability':
    case 'damage_vulnerability_grant':
      return [
        EffectFieldWrite('damage_vulnerabilities',
            <String, dynamic>{'damage_type': _refValue(effect)}, FieldWriteMode.appendRow),
      ];
    case 'condition_immunity_grant':
      return [
        EffectFieldWrite('condition_immunities',
            <String, dynamic>{'condition': _refValue(effect)}, FieldWriteMode.appendRow),
      ];
    case 'sense_grant':
      return [EffectFieldWrite('granted_senses', _senseRow(effect, null), FieldWriteMode.appendRow)];
    case 'truesight_grant':
      return [EffectFieldWrite('granted_senses', _senseRow(effect, 'truesight'), FieldWriteMode.appendRow)];
    case 'blindsight_grant':
      return [EffectFieldWrite('granted_senses', _senseRow(effect, 'blindsight'), FieldWriteMode.appendRow)];
    case 'unarmored_ac_formula':
      return [EffectFieldWrite('unarmored_ac_formula', _formula(effect), FieldWriteMode.setScalar)];
    case 'resource_pool_grant':
      return [EffectFieldWrite('granted_resources', _resourceRow(effect), FieldWriteMode.appendRow)];
    case 'recovery_grant':
    case 'slot_recovery_short_rest':
      return [EffectFieldWrite('resource_recovery', _recoveryRow(effect, kind), FieldWriteMode.appendRow)];
    case 'granted_action_grant':
      return [EffectFieldWrite('granted_actions', _actionRow(effect, 'action'), FieldWriteMode.appendRow)];
    case 'granted_bonus_action_grant':
      return [EffectFieldWrite('granted_actions', _actionRow(effect, 'bonus_action'), FieldWriteMode.appendRow)];
    case 'granted_reaction_grant':
      return [EffectFieldWrite('granted_actions', _actionRow(effect, 'reaction'), FieldWriteMode.appendRow)];
    case 'extra_attack_count':
    case 'extra_attack_bump':
      return [EffectFieldWrite('extra_attacks', _num(effect['value'], 1), FieldWriteMode.addScalar)];
    case 'class_level_grant':
      return [
        EffectFieldWrite(
          'granted_class_levels',
          <String, dynamic>{'class': _refValue(effect), 'levels': _num(effect['value'], 1)},
          FieldWriteMode.appendRow,
        ),
      ];
    case 'choice_group':
      return [EffectFieldWrite('choices', _choiceRow(effect), FieldWriteMode.appendRow)];
    default:
      // Non-parametric (out-of-scope combat/VTT or unknown) — no data field;
      // the description engine surfaces it as `noted` rules text instead.
      return const <EffectFieldWrite>[];
  }
}

/// Applies [writes] to a card's [attributes] in place, per each write's
/// [FieldWriteMode]. Creates missing list/scalar fields; accumulates rows and
/// sums scalars so multiple effects of the same kind combine correctly.
/// Idempotency is the converter's responsibility (it skips already-`format:3`
/// cards), so this never double-applies in practice.
void applyEffectWrites(
  Map<String, dynamic> attributes,
  List<EffectFieldWrite> writes,
) {
  for (final w in writes) {
    switch (w.mode) {
      case FieldWriteMode.appendRow:
        final existing = attributes[w.fieldKey];
        final list = existing is List ? List<dynamic>.from(existing) : <dynamic>[];
        list.add(w.value);
        attributes[w.fieldKey] = list;
      case FieldWriteMode.addScalar:
        final existing = attributes[w.fieldKey];
        final base = existing is num ? existing : 0;
        final value = w.value;
        attributes[w.fieldKey] = base + (value is num ? value : 0);
      case FieldWriteMode.setScalar:
        attributes[w.fieldKey] = w.value;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Row builders (pure)
// ─────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _proficiencyRow(Map<String, dynamic> effect) {
  final tk = _str(effect['target_kind']);
  return <String, dynamic>{
    if (tk.isNotEmpty) 'target_kind': tk,
    'target': _refValue(effect),
  };
}

Map<String, dynamic> _senseRow(Map<String, dynamic> effect, String? fixedSense) {
  final sense = fixedSense ?? _firstNonEmptyStr([effect['sense'], effect['name']]);
  final range = _rangeFeet(effect);
  return <String, dynamic>{
    'sense': sense.isEmpty ? 'special sense' : sense,
    if (range != null) 'range_ft': range,
  };
}

Map<String, dynamic> _resourceRow(Map<String, dynamic> effect) {
  final payload = effect['payload'] is Map
      ? Map<String, dynamic>.from(effect['payload'] as Map)
      : const <String, dynamic>{};
  final recovery =
      _str(payload['recovery'] ?? payload['refill_on'] ?? effect['refill_on']);
  return <String, dynamic>{
    'name': _firstNonEmptyStr([effect['name'], payload['name']]),
    'max': payload['count'] ?? effect['value'] ?? payload['max'],
    if (recovery.isNotEmpty) 'recovery': recovery,
  };
}

Map<String, dynamic> _recoveryRow(Map<String, dynamic> effect, String kind) {
  final on = kind == 'slot_recovery_short_rest'
      ? 'short_rest'
      : _str(effect['on'] ?? effect['rest'] ?? effect['refill_on']);
  return <String, dynamic>{
    'target': _refValue(effect),
    if (on.isNotEmpty) 'on': on,
  };
}

Map<String, dynamic> _actionRow(Map<String, dynamic> effect, String actionType) =>
    <String, dynamic>{
      'action_type': actionType,
      'action': _refValue(effect),
    };

Map<String, dynamic> _choiceRow(Map<String, dynamic> effect) {
  final prompt = _firstNonEmptyStr([effect['prompt'], effect['name']]);
  return <String, dynamic>{
    if (prompt.isNotEmpty) 'prompt': prompt,
    'pick': _num(effect['pick'] ?? effect['choice_count'] ?? effect['count'], 1),
    if (effect['options'] is List) 'options': effect['options'],
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Small shared helpers (pure)
// ─────────────────────────────────────────────────────────────────────────

/// The most useful value for a ref-bearing effect: a typed `target_ref` / `ref`
/// (preserved as-is so a hard uuid ref survives), else a scalar `value` / `name`.
Object? _refValue(Map<String, dynamic> effect) =>
    effect['target_ref'] ?? effect['ref'] ?? effect['value'] ?? effect['name'];

int? _rangeFeet(Map<String, dynamic> effect) {
  final payload = effect['payload'];
  final raw = (payload is Map)
      ? (payload['range_ft'] ?? payload['range'] ?? payload['value_ft'])
      : (effect['range_ft'] ?? effect['range'] ?? effect['value']);
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

Object? _formula(Map<String, dynamic> effect) {
  final payload = effect['payload'];
  return (payload is Map ? payload['formula'] : null) ??
      effect['formula'] ??
      effect['value'];
}

/// Normalises an ability input (string / abbreviation / ref) to the lowercase
/// three-letter key (`str`…`cha`) the v3 ability fields use.
String _abilityKey(dynamic raw) {
  final s = _refName(raw).toLowerCase().trim();
  return switch (s) {
    'strength' || 'str' => 'str',
    'dexterity' || 'dex' => 'dex',
    'constitution' || 'con' => 'con',
    'intelligence' || 'int' => 'int',
    'wisdom' || 'wis' => 'wis',
    'charisma' || 'cha' => 'cha',
    _ => s,
  };
}

String _refName(dynamic ref) {
  if (ref is Map) {
    return _str(ref['name'] ?? ref['lookup'] ?? ref['ref'] ?? ref['_ref']);
  }
  return _str(ref);
}

String _firstNonEmptyStr(List<dynamic> candidates) {
  for (final c in candidates) {
    final s = _str(c).trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

String _str(dynamic v) => v == null ? '' : v.toString();

int _num(dynamic v, int fallback) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}
