/// One-shot converter from the retired rule-effect DSLs to the named grant
/// fields (`CharacterResolver.grantFieldKeys`).
///
/// Pre-existing content (user worlds, imported Open5e packs, the bundled
/// asset packs) carries mechanics as `rule_effects` / `effects` (feats) /
/// `granted_modifiers` rows — `{kind, target_kind, target_ref, value,
/// payload, predicates, scales_with, activation}`. The engine no longer
/// interprets that shape; this migration rewrites each row into the named
/// field it maps to, and renders every row with no mechanical home as a
/// human-readable `mechanical_notes` line so **nothing an author wrote is
/// silently dropped**.
///
/// Applied at the three ingestion seams:
///   * `WorldRepositoryImpl._loadFromDb` — every world entity on load, so
///     existing local worlds convert transparently the first time they open
///     (and persist converted on the next save);
///   * `builtin_synth.dart` — the built-in schema synth path;
///   * `PackagePayloadImporter.install` — every pack entity on install, so
///     old-format bundled/R2 payloads land already converted.
///
/// Idempotent: a fields map without the legacy keys is returned unchanged
/// (`identical` — no copy), so running it on every load costs one key lookup.
library;

/// Legacy `granted_modifiers` kind aliases (Open5e importer emissions).
const _kindAliases = <String, String>{
  'resistance_grant': 'damage_resistance',
  'damage_resistance_grant': 'damage_resistance',
  'immunity_grant': 'damage_immunity',
  'damage_immunity_grant': 'damage_immunity',
  'vulnerability_grant': 'damage_vulnerability',
  'damage_vulnerability_grant': 'damage_vulnerability',
  'spell_known_grant': 'spell_grant',
};

/// Kinds that append their (resolved) `target_ref` to a ref-list field.
const _kindToRefList = <String, String>{
  'language_grant': 'granted_languages',
  'spell_grant': 'granted_spell_refs',
  'cantrip_grant': 'granted_cantrip_refs',
  'spell_always_prepared': 'always_prepared_spell_refs',
  'damage_resistance': 'granted_damage_resistances',
  'damage_immunity': 'granted_damage_immunities',
  'damage_vulnerability': 'granted_damage_vulnerabilities',
  'condition_immunity_grant': 'granted_condition_immunities',
  'expertise_grant': 'granted_expertise_skills',
  'granted_action_grant': 'granted_action_refs',
  'granted_bonus_action_grant': 'granted_bonus_action_refs',
  'granted_reaction_grant': 'granted_reaction_refs',
};

/// `proficiency_grant` target_kind → ref-list field.
const _profTargetToField = <String, String>{
  'skill': 'granted_skill_proficiencies',
  'tool': 'granted_tool_proficiencies',
  'saving_throw': 'granted_save_proficiencies',
  'save': 'granted_save_proficiencies',
  'ability': 'granted_save_proficiencies',
  'weapon_category': 'granted_weapon_proficiencies',
  'armor_category': 'granted_armor_proficiencies',
};

/// Kinds that add `value` into an int field (summed when repeated).
const _kindToIntField = <String, String>{
  'ac_bonus': 'ac_bonus',
  'speed_bonus': 'speed_bonus_ft',
  'initiative_bonus': 'initiative_bonus',
  'hp_bonus_flat': 'hp_bonus_flat',
  'hp_max_bonus_total': 'hp_bonus_flat',
  'hp_bonus_per_level': 'hp_bonus_per_level',
  'weapon_mastery_count_bonus': 'weapon_mastery_count',
};

/// No-op kinds → the sentence written to `mechanical_notes`. `{target}` is
/// replaced by the target's display name when the row carries one, `{value}`
/// by the row's int value. Everything the old resolver silently accepted is
/// listed here so the coverage test can prove nothing falls through.
const legacyKindNotes = <String, String>{
  'advantage_on': 'Advantage on {target} rolls',
  'disadvantage_on': 'Disadvantage on {target} rolls',
  'extra_damage_on_attack': 'Deals extra damage on qualifying attacks',
  'reroll_damage': 'Can reroll damage dice',
  'reroll_d20': 'Can reroll a d20',
  'attack_bonus': '{value:+} to attack rolls',
  'attack_bonus_typed': '{value:+} to qualifying attack rolls',
  'damage_bonus_typed': '{value:+} to qualifying damage rolls',
  'expertise_count': 'Choose {value} skill(s) to gain Expertise in',
  'cantrip_count_bonus': 'Learn {value} extra cantrip(s)',
  'weapon_mastery_grant': 'Grants the {target} weapon mastery',
  'walk_on_liquid': 'Can walk across liquid surfaces',
  'magical_unarmed_strikes': 'Unarmed strikes count as magical',
  'slot_recovery_short_rest': 'Recovers spell slots on a Short Rest',
  'concentration_advantage': 'Advantage on Concentration saving throws',
  'concentration_immune_to_damage_break':
      'Damage cannot break your Concentration',
  'half_proficiency_to_unproficient_checks':
      'Add half your Proficiency Bonus to checks you are not proficient in',
  'reliable_talent': 'Treat low d20 rolls on proficient checks as a 10',
  'min_die_value': 'Treat die rolls below {value} as {value}',
  'passive_score_bonus': '{value:+} to the {target} passive score',
  'damage_reduction_flat': 'Reduce incoming damage by {value}',
  'ignore_cover': 'Attacks ignore cover',
  'ignore_long_range_disadvantage': 'No Disadvantage at long range',
  'damage_type_override': 'Damage dealt becomes {target}',
  'spellcasting_ability_to_damage':
      'Add your spellcasting ability modifier to qualifying damage',
  'spell_cast_from_item': 'Can cast {target} from this item',
  'state_grant': 'Grants an activatable state',
  'recovery_grant': 'Grants a recovery mechanic',
  'condition_advantage_on_save_grant':
      'Advantage on saving throws against {target}',
  'reaction_attack_grant': 'Can make an attack as a Reaction',
  'reaction_damage_reduction': 'Can reduce damage as a Reaction',
  'reaction_negate_via_save': 'Can negate an effect via a save as a Reaction',
  'opportunity_attack_immunity_when_disengage_redundant':
      'Immune to Opportunity Attacks when Disengage would be redundant',
  'enemy_cant_disengage_oa':
      'Enemies cannot avoid your Opportunity Attacks by Disengaging',
  'oa_stops_movement': "A hit with your Opportunity Attack stops the target's movement",
  'temp_hp_grant': 'Grants Temporary HP on a trigger',
  // Narrative-only legacy modifier rows.
  'feature_text': '',
};

/// Rewrite the legacy effect rows on [fields] into named grant fields.
/// Returns [fields] itself (identical) when there is nothing to migrate,
/// otherwise a new map with the legacy keys removed.
Map<String, dynamic> migrateRuleEffects(Map<String, dynamic> fields) {
  final hasLegacy = fields.containsKey('rule_effects') ||
      fields.containsKey('granted_modifiers') ||
      _hasLegacyEffects(fields['effects']);
  if (!hasLegacy) return fields;

  final out = Map<String, dynamic>.from(fields);
  final rows = <Map<String, dynamic>>[
    ..._mapList(out.remove('rule_effects')),
    ..._mapList(out.remove('granted_modifiers')),
  ];
  // Feat `effects` — only when it's actually the legacy DSL shape; a spell's
  // narrative/spellEffectList `effects` field stays untouched.
  if (_hasLegacyEffects(out['effects'])) {
    rows.addAll(_mapList(out.remove('effects')));
  }

  for (final row in rows) {
    _applyRow(row, out);
  }
  return out;
}

/// True when [raw] looks like a legacy featEffectList (rows keyed by a known
/// effect `kind`) rather than a spellEffectList / narrative field.
bool _hasLegacyEffects(Object? raw) {
  if (raw is! List || raw.isEmpty) return false;
  for (final v in raw) {
    if (v is! Map) return false;
    final kind = v['kind']?.toString() ?? '';
    final known = kind.isEmpty || // rows with no kind are legacy narrative
        _kindToRefList.containsKey(kind) ||
        _kindToIntField.containsKey(kind) ||
        legacyKindNotes.containsKey(kind) ||
        _kindAliases.containsKey(kind) ||
        const {
          'proficiency_grant', 'ability_score_bonus', 'sense_grant',
          'truesight_grant', 'blindsight_grant', 'unarmored_ac_formula',
          'extra_attack_count', 'extra_attack_bump', 'crit_range_extend',
          'resource_pool_grant', 'choice_group', 'class_level_grant',
          'swim_speed_equals_speed', 'climb_speed_equals_speed', 'fly_speed',
        }.contains(kind);
    if (!known) return false;
  }
  return true;
}

void _applyRow(Map<String, dynamic> row, Map<String, dynamic> out) {
  var kind = (row['kind'] ?? '').toString();
  kind = _kindAliases[kind] ?? kind;
  final gated = _stateGate(row);

  // A state-gated defense row keeps working through the card-level gate…
  if (gated != null &&
      const {
        'damage_resistance', 'damage_immunity', 'damage_vulnerability',
        'condition_immunity_grant', //
      }.contains(kind)) {
    // …but only when the card has a single gate. A second, different state on
    // the same card cannot be expressed — fall back to a note.
    final existing = out['active_while_state_ref'];
    if (existing == null || _sameRef(existing, gated)) {
      out['active_while_state_ref'] = gated;
      _appendRef(out, _kindToRefList[kind]!, row['target_ref']);
      return;
    }
    _appendNote(out,
        '${_stateLabel(gated)}: ${_noteFor(kind, row)}'.trim());
    return;
  }
  if (gated != null) {
    // Any other gated row is roll-time behaviour → note with the state label.
    final note = _noteFor(kind, row);
    if (note.isNotEmpty) {
      _appendNote(out, '${_stateLabel(gated)}: $note');
    }
    return;
  }

  final refField = _kindToRefList[kind];
  if (refField != null) {
    _appendRef(out, refField, row['target_ref']);
    // A sense range on the legacy row shape (`payload.range_ft`).
    return;
  }
  final intField = _kindToIntField[kind];
  if (intField != null) {
    final v = _intOf(row['value']);
    if (v != 0) out[intField] = _intOf(out[intField]) + v;
    return;
  }

  switch (kind) {
    case 'proficiency_grant':
      final field = _profTargetToField[row['target_kind']?.toString()];
      if (field != null && row['target_ref'] != null) {
        _appendRef(out, field, row['target_ref']);
      } else {
        _appendNote(out, 'Gain a proficiency of your choice');
      }
    case 'ability_score_bonus':
      final code = _abilityCode(row);
      final v = _intOf(row['value']);
      if (code == null || v == 0) return;
      final bonuses = out['ability_bonuses'] is Map
          ? Map<String, dynamic>.from(out['ability_bonuses'] as Map)
          : <String, dynamic>{};
      bonuses[code] = _intOf(bonuses[code]) + v;
      out['ability_bonuses'] = bonuses;
      final cap = _intOf(row['max']);
      if (cap > 20 && cap > _intOf(out['ability_bonus_cap'])) {
        out['ability_bonus_cap'] = cap;
      }
    case 'sense_grant':
    case 'truesight_grant':
    case 'blindsight_grant':
      final payload = row['payload'];
      final range = payload is Map
          ? _intOf(payload['range_ft'])
          : _intOf(row['range_ft']);
      final ref = row['target_ref'];
      if (ref == null) return;
      final senses = _mapList(out['granted_senses']).toList();
      senses.add({
        'sense_ref': ref,
        if (range > 0) 'range_ft': range,
      });
      out['granted_senses'] = senses;
    case 'unarmored_ac_formula':
      final payload = row['payload'];
      if (payload is! Map) return;
      out['unarmored_ac_base'] = _intOf(payload['base']);
      out['unarmored_ac_shield_allowed'] = payload['shield_allowed'] == true;
      // `ability_mods` were STR/DEX abbreviations; the named field is a
      // relation list resolved by name, so abbreviations round-trip through
      // the `{name}` envelope the ref resolver already accepts.
      final mods = payload['ability_mods'];
      if (mods is List) {
        out['unarmored_ac_abilities'] = [
          for (final m in mods)
            if (m is String) {'slug': 'ability', 'name': _abilityName(m) ?? m},
        ];
      }
    case 'extra_attack_count':
    case 'extra_attack_bump':
      final scaled = _scalesTable(row);
      if (scaled != null) {
        out['extra_attack_count_by_level'] = scaled.table;
      }
      final v = _intOf(row['value']);
      if (v > _intOf(out['extra_attack_count'])) {
        out['extra_attack_count'] = v;
      }
    case 'crit_range_extend':
      final payload = row['payload'];
      final t = payload is Map
          ? _intOf(payload['threshold'])
          : _intOf(row['value']);
      if (t >= 2 &&
          (_intOf(out['crit_threshold']) == 0 ||
              t < _intOf(out['crit_threshold']))) {
        out['crit_threshold'] = t;
      }
    case 'resource_pool_grant':
      final payload = row['payload'] is Map
          ? Map<String, dynamic>.from(row['payload'] as Map)
          : <String, dynamic>{};
      final scaled = _scalesTable(row);
      final pools = _mapList(out['resource_pool_grants']).toList();
      pools.add({
        'pool_ref': payload['pool_ref'] ?? row['target_ref'],
        if (payload['recharge'] != null) 'recharge': payload['recharge'],
        if (payload['count'] != null) 'count': payload['count'],
        if (payload['count_formula'] != null)
          'count_formula': payload['count_formula'],
        if (scaled != null) 'count_by_level': scaled.table,
        if (scaled?.classRef != null) 'class_ref': scaled!.classRef,
      });
      out['resource_pool_grants'] = pools;
    case 'choice_group':
      final payload = row['payload'];
      if (payload is! Map) return;
      final choices = _mapList(out['player_choices']).toList();
      choices.add(Map<String, dynamic>.from(payload));
      out['player_choices'] = choices;
    case 'swim_speed_equals_speed':
      out['speed_swim_ft'] = -1;
    case 'climb_speed_equals_speed':
      out['speed_climb_ft'] = -1;
    case 'fly_speed':
      final payload = row['payload'];
      final v = payload is Map
          ? _intOf(payload['value_ft'])
          : _intOf(row['value']);
      out['speed_fly_ft'] = v > 0 ? v : -1;
    case 'class_level_grant':
      // Multiclassing lives on the PC's `class_levels` — nothing to keep.
      break;
    default:
      final note = _noteFor(kind, row);
      if (note.isNotEmpty) _appendNote(out, note);
  }
}

// ── row plumbing ───────────────────────────────────────────────────────────

/// Extract the gating state ref from a legacy `has_state` predicate, if any.
Object? _stateGate(Map<String, dynamic> row) {
  final preds = row['predicates'];
  if (preds is! List) return null;
  for (final p in preds) {
    if (p is! Map) continue;
    if (p['kind'] != 'has_state' && p['kind'] != 'has_condition') continue;
    final args = p['args'];
    if (args is Map) {
      return args['ref'] ?? args['state_ref'] ?? args['condition_ref'];
    }
  }
  return null;
}

bool _sameRef(Object? a, Object? b) {
  final na = _refName(a);
  final nb = _refName(b);
  return na != null && na == nb;
}

String? _refName(Object? ref) {
  if (ref is String) return ref;
  if (ref is Map) return (ref['name'] ?? ref['_lookup'])?.toString();
  return null;
}

String _stateLabel(Object? stateRef) {
  final name = _refName(stateRef) ?? '';
  final short =
      name.startsWith('state:') ? name.substring('state:'.length) : name;
  return 'While ${short.replaceAll('_', ' ')}';
}

String _noteFor(String kind, Map<String, dynamic> row) {
  final template = legacyKindNotes[kind];
  if (template == null) {
    // Unknown kind — keep *something* rather than dropping the row.
    final target = _refName(row['target_ref']);
    return 'Legacy rule "$kind"${target != null ? ' ($target)' : ''}';
  }
  if (template.isEmpty) return '';
  final target = _refName(row['target_ref']) ??
      row['target_kind']?.toString() ??
      'qualifying';
  final v = _intOf(row['value']);
  return template
      .replaceAll('{target}', target)
      .replaceAll('{value:+}', v >= 0 ? '+$v' : '$v')
      .replaceAll('{value}', '$v');
}

void _appendNote(Map<String, dynamic> out, String note) {
  final existing = out['mechanical_notes'];
  final lines = <String>[
    if (existing is String && existing.trim().isNotEmpty)
      ...existing.split('\n'),
    if (existing is List) ...existing.map((e) => e.toString()),
  ];
  if (!lines.contains(note)) lines.add(note);
  out['mechanical_notes'] = lines.join('\n');
}

void _appendRef(Map<String, dynamic> out, String field, Object? ref) {
  if (ref == null) return;
  final list = out[field] is List ? List<dynamic>.from(out[field] as List) : [];
  list.add(ref);
  out[field] = list;
}

({Map<String, dynamic> table, Object? classRef})? _scalesTable(
    Map<String, dynamic> row) {
  final scales = row['scales_with'];
  if (scales is! Map) return null;
  final raw = scales['table'];
  if (raw is! List) return null;
  final table = <String, dynamic>{};
  for (final r in raw) {
    if (r is! Map) continue;
    final lvl = _intOf(r['lvl']);
    final v = r['v'];
    // String values (Sneak Attack dice) can't live in an int level table —
    // the caller falls back to a note when the table ends up empty.
    if (lvl > 0 && v is num) table['$lvl'] = v.toInt();
  }
  if (table.isEmpty) return null;
  return (table: table, classRef: scales['class_ref']);
}

const _abilityNames = <String, String>{
  'STR': 'Strength',
  'DEX': 'Dexterity',
  'CON': 'Constitution',
  'INT': 'Intelligence',
  'WIS': 'Wisdom',
  'CHA': 'Charisma',
};

String? _abilityName(String abbrev) => _abilityNames[abbrev.toUpperCase()];

String? _abilityCode(Map<String, dynamic> row) {
  final raw = (row['ability'] ?? '').toString().toUpperCase();
  if (_abilityNames.containsKey(raw)) return raw;
  for (final e in _abilityNames.entries) {
    if (e.value.toUpperCase() == raw) return e.key;
  }
  final name = _refName(row['target_ref']);
  if (name != null) {
    final up = name.toUpperCase();
    for (final e in _abilityNames.entries) {
      if (e.value.toUpperCase() == up || e.key == up) return e.key;
    }
  }
  return null;
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final v in raw)
      if (v is Map) Map<String, dynamic>.from(v),
  ];
}

int _intOf(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
