import '../../entities/entity.dart';
import '../entity_ref.dart';
import 'bound_rule.dart';
import 'choice_spec.dart';
import 'prereq_evaluator.dart';
import 'rule_trigger.dart';

/// Compiles a content entity's mechanics into an ordered [BoundRule] list —
/// the "dynamic rules read the fields on the card" layer of the rules engine
/// (PR-R2).
///
/// Two rule sources are merged per entity:
///   1. EXPLICIT rules: rows authored in `rule_effects` / `effects` /
///      `granted_modifiers` / `features[].effects`.
///   2. IMPLICIT rules: derived on the fly from the typed fields the schema
///      already declares (`granted_skill_refs`, `speed_fly_ft`,
///      `saving_throw_refs`, `prereq_*`, ...). No data migration — 20k+ pack
///      cards keep their wire format; the compiler interprets it.
///
/// PARITY CONTRACT (PR-R2): the granular `compile*` entry points emit rules
/// in EXACTLY the order the legacy resolver pass bodies read the same
/// fields, and only rules whose gates already pass (subclass
/// `granted_at_level`, feature-row level). `CharacterResolver` consumes them
/// at the same pass positions, so the resolved output is byte-identical to
/// the frozen `LegacyCharacterResolver`. Do not reorder emissions without
/// re-running the parity matrix.
///
/// Internal effect kinds (resolver apply-wrapper only, never authored):
/// `trait_grant`, `alternate_speed`, `level_gated_spells`,
/// `background_asi_apply`, `feat_asi_apply`, `proficiency_grant_raw`,
/// `feature_row`, `prerequisite`.
class RuleCompiler {
  /// Everything the derivations need from the in-flight resolution.
  /// `classLevels` gates subclass/feature emissions.
  final Map<String, Entity> entitiesById;
  final Map<String, int> classLevels;

  const RuleCompiler({
    required this.entitiesById,
    this.classLevels = const {},
  });

  // ── shared helpers ──────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _mapList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final v in raw)
        if (v is Map) Map<String, dynamic>.from(v),
    ];
  }

  /// Same lenient int coercion as the resolver's `_intOf` — string-valued
  /// numbers in pack data must gate emissions identically.
  static int _intOf(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Dynamic field refs (PR-R3): any `value` / payload entry shaped
  /// `{"$field": "<fieldKey>"}` resolves against the HOST card's own fields,
  /// so one generic rule can act on per-card data
  /// (`{"kind": "speed_bonus", "value": {"$field": "speed_bonus_ft"}}`).
  /// Returns null when a referenced key is absent/null on the card — the
  /// caller SKIPS the row (skip, don't mis-apply; the editor's validator
  /// flags the bad key at authoring time).
  static Map<String, dynamic>? resolveFieldRefs(
    Map<String, dynamic> row,
    Map<String, dynamic> hostFields,
  ) {
    var missing = false;
    Object? resolveValue(Object? v) {
      if (v is Map && v.length == 1 && v.containsKey(r'$field')) {
        final key = v[r'$field'];
        final resolved = key is String ? hostFields[key] : null;
        if (resolved == null) missing = true;
        return resolved;
      }
      return v;
    }

    var changed = false;
    final out = <String, dynamic>{...row};
    final v = resolveValue(row['value']);
    if (!identical(v, row['value'])) {
      out['value'] = v;
      changed = true;
    }
    final payload = row['payload'];
    if (payload is Map) {
      Map<String, dynamic>? newPayload;
      payload.forEach((k, pv) {
        final rv = resolveValue(pv);
        if (!identical(rv, pv)) {
          newPayload ??= Map<String, dynamic>.from(payload);
          newPayload![k] = rv;
        }
      });
      if (newPayload != null) {
        out['payload'] = newPayload;
        changed = true;
      }
    }
    if (missing) return null;
    return changed ? out : row;
  }

  /// Re-shape a legacy `grantedModifiers` row into an effect-row kind the
  /// resolver understands. (Moved here from the resolver so both the
  /// interpreter and the editor's derived-rules panel share it.)
  static Map<String, dynamic> modifierAsEffect(Map<String, dynamic> m) {
    final kind = (m['kind'] ?? '').toString();
    final mapped = <String, dynamic>{...m};
    switch (kind) {
      case 'ac_bonus':
      case 'speed_bonus':
      case 'hp_bonus_flat':
      case 'hp_bonus_per_level':
      case 'initiative_bonus':
      case 'proficiency_grant':
      case 'language_grant':
      case 'spell_grant':
      case 'cantrip_grant':
      case 'ability_score_bonus':
      case 'sense_grant':
      case 'truesight_grant':
      case 'blindsight_grant':
      case 'condition_immunity_grant':
      case 'damage_resistance_grant':
      case 'damage_immunity_grant':
      case 'damage_vulnerability_grant':
        break; // already an effect kind name
      default:
        mapped['kind'] = kind; // unknown legacy kind — resolver warns
    }
    return mapped;
  }

  // ── explicit rules: rule_effects / effects rows ─────────────────────────

  /// Explicit `rule_effects` rows on any rule-bearing entity (legacy Pass 5b).
  /// Row `trigger` key wins; absent → [RuleTrigger.defaultFor] the category.
  List<BoundRule> compileRuleEffects(Entity e, String sourceLabel) {
    final out = <BoundRule>[];
    for (final raw in _mapList(e.fields['rule_effects'])) {
      final row = resolveFieldRefs(raw, e.fields);
      if (row == null) continue; // unresolvable $field ref — skip the row
      // `kind: prerequisite` without an explicit trigger is still a prereq
      // gate — never let it fall through to applyEffect.
      final trigger = RuleTrigger.fromWire(row['trigger']) ??
          (row['kind'] == 'prerequisite'
              ? RuleTrigger.prereqToGrant
              : RuleTrigger.defaultFor(e.categorySlug));
      // when_level_up rows carry their gate in trigger_args:
      // {at_level: int, gate: 'class'|'character'} — exposed on the
      // BoundRule for the level-up planner / resolver gating.
      final args = row['trigger_args'];
      final atLevel = (trigger == RuleTrigger.whenLevelUp && args is Map)
          ? _intOf(args['at_level'])
          : 0;
      final gateIsCharacter =
          args is Map && args['gate']?.toString() == 'character';
      out.add(BoundRule(
        sourceEntityId: e.id,
        sourceLabel: sourceLabel,
        trigger: trigger,
        atLevel: atLevel,
        gateClassId: trigger == RuleTrigger.whenLevelUp && !gateIsCharacter
            ? (e.categorySlug == 'subclass'
                ? resolveEntityRef(e.fields['parent_class_ref'], entitiesById)
                : e.id)
            : null,
        effect: row,
        clauses: trigger.isPrereq ? _mapList(row['clauses']) : const [],
      ));
    }
    return out;
  }

  // ── class / subclass: leveled features (legacy Pass 2) ──────────────────

  /// Feature rows up to [gateLevel]: one `feature_row` display rule per row
  /// plus the row's inline `effects` as when_level_up rules. Mirrors
  /// `_collectFeaturesByLevel` exactly (default row level 1, rows above the
  /// gate skipped, effects deferred by the resolver to the legacy Pass-4
  /// position).
  List<BoundRule> compileFeatures(Entity e, int gateLevel) {
    final kind = e.categorySlug == 'subclass' ? 'subclass' : 'class';
    final sourceLabel = '$kind:${e.name}';
    final gateClassId = e.categorySlug == 'subclass'
        ? resolveEntityRef(e.fields['parent_class_ref'], entitiesById)
        : e.id;
    final out = <BoundRule>[];
    for (final r in _mapList(e.fields['features'])) {
      final lvl = (r['level'] is int) ? r['level'] as int : 1;
      if (lvl > gateLevel) continue;
      out.add(BoundRule(
        sourceEntityId: e.id,
        sourceLabel: sourceLabel,
        trigger: RuleTrigger.whenLevelUp,
        atLevel: lvl,
        gateClassId: gateClassId,
        effect: {
          'kind': 'feature_row',
          'level': lvl,
          'description': (r['description'] ?? '').toString(),
        },
        derived: true,
        derivedFromField: 'features',
      ));
      for (final eff in _mapList(r['effects'])) {
        out.add(BoundRule(
          sourceEntityId: e.id,
          sourceLabel: sourceLabel,
          trigger: RuleTrigger.whenLevelUp,
          atLevel: lvl,
          gateClassId: gateClassId,
          effect: eff,
          derivedFromField: 'features',
        ));
      }
    }
    return out;
  }

  // ── class / subclass: top-level proficiency grants (legacy Pass 8) ──────

  /// `saving_throw_refs` / `granted_tool_refs` (refs) and
  /// `weapon_proficiency_categories` / `armor_training_refs` (VERBATIM
  /// strings — the legacy pass never resolved them; `proficiency_grant_raw`
  /// preserves that). Subclasses grant no tools at this level (legacy
  /// behavior: tools only on class).
  List<BoundRule> compileTopLevelProficiencies(Entity e, String sourceLabel) {
    final out = <BoundRule>[];
    void refRules(String field, String targetKind) {
      final raw = e.fields[field];
      if (raw is! List) return;
      for (final v in raw) {
        out.add(BoundRule(
          sourceEntityId: e.id,
          sourceLabel: sourceLabel,
          trigger: RuleTrigger.whenGranted,
          effect: {
            'kind': 'proficiency_grant',
            'target_kind': targetKind,
            'target_ref': v,
          },
          derived: true,
          derivedFromField: field,
        ));
      }
    }

    void rawRules(String field, String targetKind) {
      final raw = e.fields[field];
      if (raw is! List) return;
      for (final v in raw) {
        if (v is! String) continue;
        out.add(BoundRule(
          sourceEntityId: e.id,
          sourceLabel: sourceLabel,
          trigger: RuleTrigger.whenGranted,
          effect: {
            'kind': 'proficiency_grant_raw',
            'target_kind': targetKind,
            'value': v,
          },
          derived: true,
          derivedFromField: field,
        ));
      }
    }

    refRules('saving_throw_refs', 'saving_throw');
    if (e.categorySlug != 'subclass') {
      refRules('granted_tool_refs', 'tool');
    }
    rawRules('weapon_proficiency_categories', 'weapon_category');
    rawRules('armor_training_refs', 'armor_category');
    return out;
  }

  // ── species / subspecies grants (legacy Pass 5 `applyGrantsFrom`) ───────

  /// Grant rules for a species-shaped fields map — the species entity, a
  /// first-class subspecies entity, or a legacy nested `subspecies_options`
  /// row (all share the field set, mirroring the legacy factoring).
  /// Emission order is the legacy statement order; do not reorder.
  List<BoundRule> compileGrantsMap(
    Map<String, dynamic> f, {
    required String sourceEntityId,
    required String sourceLabel,
  }) {
    final out = <BoundRule>[];
    BoundRule rule(
      Map<String, dynamic> effect,
      String field, {
      bool noteSourceOverride = false,
    }) =>
        BoundRule(
          sourceEntityId: sourceEntityId,
          sourceLabel: sourceLabel,
          trigger: RuleTrigger.whenGranted,
          effect: effect,
          noteSourceOverride: noteSourceOverride,
          derived: true,
          derivedFromField: field,
        );

    void refRules(
      String field,
      String kind, {
      String? targetKind,
      bool noteSourceOverride = false,
    }) {
      final raw = f[field];
      if (raw is! List) return;
      for (final v in raw) {
        out.add(rule(
          {
            'kind': kind,
            'target_kind': ?targetKind,
            'target_ref': v,
          },
          field,
          noteSourceOverride: noteSourceOverride,
        ));
      }
    }

    // 1. Innate alternate speeds (absolute feet, max-merge per mode).
    const speedModeByField = {
      'speed_fly_ft': 'fly',
      'speed_swim_ft': 'swim',
      'speed_climb_ft': 'climb',
      'speed_burrow_ft': 'burrow',
    };
    speedModeByField.forEach((field, mode) {
      final v = f[field];
      if (v is int && v > 0) {
        out.add(rule(
          {'kind': 'alternate_speed', 'mode': mode, 'value': v},
          field,
        ));
      }
    });
    // 2. Legacy granted_modifiers DSL.
    for (final m in _mapList(f['granted_modifiers'])) {
      out.add(BoundRule(
        sourceEntityId: sourceEntityId,
        sourceLabel: sourceLabel,
        trigger: RuleTrigger.whenGranted,
        effect: modifierAsEffect(m),
        derivedFromField: 'granted_modifiers',
      ));
    }
    // 3-9. Ref-list grants (legacy statement order).
    refRules('granted_senses', 'sense_grant');
    refRules('granted_damage_resistances', 'damage_resistance');
    refRules('granted_damage_immunities', 'damage_immunity');
    refRules('granted_damage_vulnerabilities', 'damage_vulnerability');
    refRules('granted_condition_immunities', 'condition_immunity_grant');
    refRules('granted_languages', 'language_grant');
    refRules('granted_skill_proficiencies', 'proficiency_grant',
        targetKind: 'skill');
    refRules('trait_refs', 'trait_grant');
    // Action grants: applyEffect only notes the source on first add; the
    // legacy grant path noted it ALWAYS — override keeps grantSources equal.
    refRules('granted_action_refs', 'granted_action_grant',
        noteSourceOverride: true);
    refRules('granted_bonus_action_refs', 'granted_bonus_action_grant',
        noteSourceOverride: true);
    refRules('granted_reaction_refs', 'granted_reaction_grant',
        noteSourceOverride: true);
    // Spell/cantrip grants: applyEffect never notes sources — override.
    refRules('granted_spell_refs', 'spell_grant', noteSourceOverride: true);
    refRules('granted_cantrip_refs', 'cantrip_grant',
        noteSourceOverride: true);
    // Level-gated innate spells — one internal rule carrying the raw rows;
    // the resolver wrapper delegates to `_applyLevelGatedSpells` (exact
    // semantics incl. per-spell daily pools + dedupe).
    final gated = _mapList(f['granted_spells_at_level']);
    if (gated.isNotEmpty) {
      out.add(rule(
        {'kind': 'level_gated_spells', 'rows': gated},
        'granted_spells_at_level',
      ));
    }
    return out;
  }

  // ── background grants (legacy Pass 5 tail) ──────────────────────────────

  List<BoundRule> compileBackground(Entity bg) {
    final sourceLabel = 'background:${bg.name}';
    final out = <BoundRule>[];
    void refRules(String field, String targetKind) {
      final raw = bg.fields[field];
      if (raw is! List) return;
      for (final v in raw) {
        out.add(BoundRule(
          sourceEntityId: bg.id,
          sourceLabel: sourceLabel,
          trigger: RuleTrigger.whenGranted,
          effect: {
            'kind': 'proficiency_grant',
            'target_kind': targetKind,
            'target_ref': v,
          },
          derived: true,
          derivedFromField: field,
        ));
      }
    }

    refRules('granted_skill_refs', 'skill');
    refRules('granted_tool_refs', 'tool');
    // SRD 2024 background ASI — the stored `background_asi` pick map is
    // applied gated by `ability_score_options` (out-of-list → warning).
    // Internal rule; the wrapper runs the legacy block verbatim.
    out.add(BoundRule(
      sourceEntityId: bg.id,
      sourceLabel: sourceLabel,
      trigger: RuleTrigger.whenGranted,
      effect: {
        'kind': 'background_asi_apply',
        'payload': {
          'ability_score_options': bg.fields['ability_score_options'],
          'source_name': bg.name,
        },
      },
      derived: true,
      derivedFromField: 'ability_score_options',
    ));
    return out;
  }

  // ── feat (legacy Pass 3) ─────────────────────────────────────────────────

  /// One feat's apply-order rules: scalar ASI (when declared), then `effects`
  /// rows, then legacy `granted_modifiers`. `class_level_grant` rows are
  /// included — `applyEffect` no-ops them (already consumed in Pass 1).
  List<BoundRule> compileFeat(Entity feat) {
    final sourceLabel = 'feat:${feat.name}';
    final out = <BoundRule>[];
    final asiAmount = _intOf(feat.fields['asi_amount']);
    if (asiAmount > 0) {
      out.add(BoundRule(
        sourceEntityId: feat.id,
        sourceLabel: sourceLabel,
        trigger: RuleTrigger.whenGranted,
        effect: {
          'kind': 'feat_asi_apply',
          'payload': {
            'feat_id': feat.id,
            'asi_amount': asiAmount,
            'asi_max_score': feat.fields['asi_max_score'] is int
                ? feat.fields['asi_max_score']
                : 20,
            'asi_ability_options': feat.fields['asi_ability_options'],
          },
        },
        derived: true,
        derivedFromField: 'asi_amount',
      ));
    }
    for (final raw in _mapList(feat.fields['effects'])) {
      final eff = resolveFieldRefs(raw, feat.fields);
      if (eff == null) continue; // unresolvable $field ref — skip the row
      final trigger = RuleTrigger.fromWire(eff['trigger']) ??
          (eff['kind'] == 'prerequisite'
              ? RuleTrigger.prereqToGrant
              : RuleTrigger.alwaysOn);
      out.add(BoundRule(
        sourceEntityId: feat.id,
        sourceLabel: sourceLabel,
        trigger: trigger,
        effect: eff,
        clauses: trigger.isPrereq ? _mapList(eff['clauses']) : const [],
      ));
    }
    for (final m in _mapList(feat.fields['granted_modifiers'])) {
      out.add(BoundRule(
        sourceEntityId: feat.id,
        sourceLabel: sourceLabel,
        trigger: RuleTrigger.alwaysOn,
        effect: modifierAsEffect(m),
        derivedFromField: 'granted_modifiers',
      ));
    }
    return out;
  }

  /// A feat's prerequisite gate as one prereq_to_grant rule (typed
  /// `prereq_clauses` preferred, flat `prereq_*` lowered otherwise — see
  /// [effectivePrereqClauses]). Null when the feat declares no gate.
  BoundRule? compileFeatPrereq(Entity feat) {
    final clauses = effectivePrereqClauses(feat.fields);
    if (clauses.isEmpty) return null;
    return BoundRule(
      sourceEntityId: feat.id,
      sourceLabel: 'feat:${feat.name}',
      trigger: RuleTrigger.prereqToGrant,
      effect: const {'kind': 'prerequisite'},
      clauses: clauses,
      derived: true,
      derivedFromField: 'prereq_clauses',
    );
  }

  // ── magic-item attunement gate (PR-R4) ──────────────────────────────────

  /// The typed `attunement_*` restriction fields (declared in the magic-item
  /// schema since day one, enforced nowhere until PR-R4) compiled into one
  /// prereq_to_attune rule: `attunement_class_refs` → `class_ref` clause,
  /// `attunement_species_refs` → `species_ref`, `attunement_alignment_refs`
  /// → `alignment_ref`, `attunement_min_ability_ref`+`_score` →
  /// `ability_min`, `attunement_spellcaster_only` → `spellcasting`. The
  /// narrative `attunement_prereq` markdown becomes a display-only `other`
  /// clause (never blocks). Null when the item carries no typed restriction.
  BoundRule? compileAttunementPrereq(Entity item) {
    if (item.fields['requires_attunement'] != true) return null;
    final clauses = <Map<String, dynamic>>[];
    void optList(String field, String clauseType, String optionsKey) {
      final raw = item.fields[field];
      if (raw is List && raw.isNotEmpty) {
        clauses.add({'type': clauseType, optionsKey: raw});
      }
    }

    optList('attunement_class_refs', 'class_ref', 'class_options');
    optList('attunement_species_refs', 'species_ref', 'species_options');
    optList('attunement_alignment_refs', 'alignment_ref', 'alignment_options');
    final minScore = _intOf(item.fields['attunement_min_ability_score']);
    final abilityRef = item.fields['attunement_min_ability_ref'];
    if (minScore > 0 && abilityRef != null) {
      clauses.add({
        'type': 'ability_min',
        'ability_options': [abilityRef],
        'min_score': minScore,
      });
    }
    if (item.fields['attunement_spellcaster_only'] == true) {
      clauses.add({'type': 'spellcasting'});
    }
    final prose = item.fields['attunement_prereq'];
    if (prose is String && prose.trim().isNotEmpty) {
      clauses.add({'type': 'other', 'text': prose.trim()});
    }
    if (clauses.isEmpty) return null;
    return BoundRule(
      sourceEntityId: item.id,
      sourceLabel: 'item:${item.name}',
      trigger: RuleTrigger.prereqToAttune,
      effect: const {'kind': 'prerequisite'},
      clauses: clauses,
      derived: true,
      derivedFromField: 'requires_attunement',
    );
  }

  // ── constrained choices (PR-R5; roadmap 1.4) ────────────────────────────

  /// Every constrained choice this entity grants, as first-class
  /// [ChoiceSpec]s — "pick N of set / pick a distribution" preserved as data.
  /// Consumed by the level-up planner (pending-choice generation, PR-R6),
  /// the wizard's distribution UI, and the resolver's stored-pick validation
  /// (warn-keep).
  List<ChoiceSpec> compileChoiceSpecs(Entity e, RuleAttachment attachment) {
    final out = <ChoiceSpec>[];
    void countSpec(String countField, String optionsField, String pickKind,
        String label) {
      final n = _intOf(e.fields[countField]);
      if (n <= 0) return;
      final raw = e.fields[optionsField];
      out.add(ChoiceSpec(
        specId: countField,
        label: label,
        pickKind: pickKind,
        pick: n,
        options: raw is List ? List<Object>.from(raw) : const [],
      ));
    }

    switch (attachment) {
      case RuleAttachment.background:
        final distributions =
            ChoiceSpec.parseDistributions(e.fields['asi_distribution_options']);
        final abilityOpts = e.fields['ability_score_options'];
        if (distributions.isNotEmpty ||
            (abilityOpts is List && abilityOpts.isNotEmpty)) {
          out.add(ChoiceSpec(
            specId: 'background_asi',
            label: 'Ability Score Increase',
            pickKind: 'ability_distribution',
            options: abilityOpts is List
                ? List<Object>.from(abilityOpts)
                : const [],
            distributions: distributions,
          ));
        }
        countSpec('granted_language_count', 'granted_language_options',
            'language', 'Bonus Languages');
      case RuleAttachment.classHeld:
        countSpec('skill_proficiency_choice_count',
            'skill_proficiency_options', 'skill', 'Skill Proficiencies');
        countSpec('tool_proficiency_count', 'tool_proficiency_options', 'tool',
            'Tool Proficiencies');
      case RuleAttachment.subclass:
        countSpec('bonus_skill_pick_count', 'skill_proficiency_options',
            'skill', 'Bonus Skill Proficiencies');
      case RuleAttachment.feat:
      case RuleAttachment.autoFeat:
        countSpec('bonus_skill_pick_count', 'skill_proficiency_options',
            'skill', 'Bonus Skill Proficiencies');
        countSpec('bonus_expertise_pick_count', '', 'expertise', 'Expertise');
        for (final row in _mapList(e.fields['effects'])) {
          final spec = ChoiceSpec.fromEffectRow(row);
          if (spec != null) out.add(spec);
        }
      case RuleAttachment.species:
      case RuleAttachment.subspecies:
      case RuleAttachment.trait:
      case RuleAttachment.equippedItem:
      case RuleAttachment.attunedItem:
        break;
    }
    return out;
  }

  // ── whole-entity view (editor / derived-rules panel) ────────────────────

  /// Every rule this entity contributes, explicit + implicit, in apply order.
  /// [gateLevel] caps leveled feature emission (pass 20 to see everything).
  /// This is the editor-facing aggregate; the resolver uses the granular
  /// entry points above to preserve legacy pass interleaving.
  List<BoundRule> compile(
    Entity e, {
    required RuleAttachment attachment,
    int gateLevel = 20,
  }) {
    final label = switch (attachment) {
      RuleAttachment.classHeld => 'class:${e.name}',
      RuleAttachment.subclass => 'subclass:${e.name}',
      RuleAttachment.species => 'species:${e.name}',
      RuleAttachment.subspecies => 'subspecies:${e.name}',
      RuleAttachment.background => 'background:${e.name}',
      RuleAttachment.feat || RuleAttachment.autoFeat => 'feat:${e.name}',
      RuleAttachment.trait => 'trait:${e.name}',
      RuleAttachment.equippedItem ||
      RuleAttachment.attunedItem =>
        'item:${e.name}',
    };
    final out = <BoundRule>[];
    switch (attachment) {
      case RuleAttachment.classHeld:
      case RuleAttachment.subclass:
        out.addAll(compileFeatures(e, gateLevel));
        out.addAll(compileTopLevelProficiencies(e, label));
      case RuleAttachment.species:
      case RuleAttachment.subspecies:
        out.addAll(compileGrantsMap(e.fields,
            sourceEntityId: e.id, sourceLabel: label));
      case RuleAttachment.background:
        out.addAll(compileBackground(e));
      case RuleAttachment.feat:
      case RuleAttachment.autoFeat:
        final prereq = compileFeatPrereq(e);
        if (prereq != null) out.add(prereq);
        out.addAll(compileFeat(e));
      case RuleAttachment.trait:
        break; // rule_effects only, added below
      case RuleAttachment.equippedItem:
      case RuleAttachment.attunedItem:
        final attune = compileAttunementPrereq(e);
        if (attune != null) out.add(attune);
    }
    out.addAll(compileRuleEffects(e, label));
    return out;
  }
}
