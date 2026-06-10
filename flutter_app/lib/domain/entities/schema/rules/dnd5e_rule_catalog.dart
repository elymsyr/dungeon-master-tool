/// The D&D 5e Rule Catalog — the declared, introspectable counterpart of the
/// effect `kind`s understood by `CharacterResolver`.
///
/// Membership is the UNION of (a) every `kind` with a real `applyEffect` case
/// in the resolver and (b) every kind historically offered by the effect
/// editor, so the catalog can fully replace the old hardcoded `_featEffectKinds`
/// dropdown list without hiding any token present in existing content.
///
/// [RuleDefinition.resolverStatus] records whether the resolver folds the rule
/// into a stat at resolve time (`applied`) or merely records it for the combat
/// tracker to read at runtime (`deferred`). Keep this aligned with the
/// resolver's switch — see `CharacterResolver.knownEffectKinds` and the
/// Phase-0 drift cross-check.
library;

import 'rule_definition.dart';

// ── reusable param specs ───────────────────────────────────────────────────

const _valueInt = RuleParamSpec(
  key: 'value',
  label: 'Value',
  type: RuleParamType.int_,
);

const _rangeFtPayload = RuleParamSpec(
  key: 'range_ft',
  label: 'Range (ft)',
  type: RuleParamType.int_,
  location: RuleParamLocation.payload,
);

// ── target-kind tokens (match resolver / SRD data) ──────────────────────────

const _profTargets = [
  'skill',
  'tool',
  'saving_throw',
  'ability',
  'armor_category',
  'weapon_category',
];

/// Historical editor target-kind list — used as the fallback when a rule
/// declares no `allowedTargetKinds`, so undeclared rules behave exactly as the
/// pre-catalog dropdown did.
const _targetKindFallback = [
  'ac', 'save', 'skill', 'speed', 'hp', 'sense', 'damage_type', 'condition', //
  'class', 'spell', 'cantrip', 'language', 'feat', 'tool', 'weapon', 'ability',
];

/// Closed predicate-kind enumeration (the `{kind, args}` predicate rows).
/// The resolver evaluates a subset at resolve time; the rest are recorded for
/// the combat tracker. Mirrors the documented set in `field_schema.dart`.
const _predicateKinds = [
  'class_level_at_least',
  'equipped_armor_kind',
  'equipped_shield',
  'has_proficiency',
  'has_state',
  'has_condition',
  'target_has_condition',
  'weapon_property',
  'weapon_kind_used',
  'attack_uses_ability',
  'attack_was_critical',
  'attack_was_miss',
  'dim_or_dark_light',
  'concentration_break_save',
  'sneak_attack_eligibility',
  'not_incapacitated',
];

RuleDefinition _r(
  String id,
  String label,
  RuleCategory category,
  String description, {
  List<RuleParamSpec> params = const [],
  List<String> allowedTargetKinds = const [],
  List<String> allowedTriggers = const [],
  bool predicates = false,
  bool scaling = false,
  bool activation = false,
  bool payload = false,
  RuleResolverStatus status = RuleResolverStatus.applied,
}) =>
    RuleDefinition(
      id: id,
      label: label,
      description: description,
      category: category,
      params: params,
      allowedTargetKinds: allowedTargetKinds,
      allowedTriggers: allowedTriggers,
      supportsPredicates: predicates,
      supportsScaling: scaling,
      supportsActivation: activation,
      supportsPayload: payload,
      resolverStatus: status,
    );

/// Build the D&D 5e rule catalog. Pure, cheap, no I/O — safe to call from a
/// provider. Declared once and memoized at the provider layer.
RuleCatalog dnd5eRuleCatalog() {
  final defs = <RuleDefinition>[
    // ── Grants ───────────────────────────────────────────────────────────
    _r('class_level_grant', 'Class Level Grant', RuleCategory.grant,
        'Adds levels in a class (multiclass support).',
        params: const [
          RuleParamSpec(
              key: 'value', label: 'Levels', type: RuleParamType.int_),
        ],
        allowedTargetKinds: ['class'],
        predicates: true),
    _r('ability_score_bonus', 'Ability Score Bonus', RuleCategory.grant,
        'Increases an ability score by a flat amount.',
        params: [_valueInt],
        allowedTargetKinds: ['ability'],
        predicates: true),
    _r('proficiency_grant', 'Proficiency Grant', RuleCategory.grant,
        'Grants proficiency in a skill, tool, save, armor or weapon category.',
        allowedTargetKinds: _profTargets,
        predicates: true),
    _r('expertise_grant', 'Expertise Grant', RuleCategory.grant,
        'Doubles proficiency bonus on a skill (expertise).',
        allowedTargetKinds: ['skill'],
        predicates: true),
    _r('language_grant', 'Language Grant', RuleCategory.grant,
        'Grants knowledge of a language.',
        allowedTargetKinds: ['language']),
    _r('granted_action_grant', 'Granted Action', RuleCategory.grant,
        'Grants a creature action (e.g. Breath Weapon).',
        allowedTargetKinds: ['creature-action'],
        activation: true),
    _r('granted_bonus_action_grant', 'Granted Bonus Action', RuleCategory.grant,
        'Grants a bonus action.',
        allowedTargetKinds: ['creature-action'],
        activation: true),
    _r('granted_reaction_grant', 'Granted Reaction', RuleCategory.grant,
        'Grants a reaction.',
        allowedTargetKinds: ['creature-action'],
        activation: true),

    // ── Flat bonuses ───────────────────────────────────────────────────────
    _r('ac_bonus', 'AC Bonus', RuleCategory.bonus,
        'Flat bonus to Armor Class.',
        params: [_valueInt], predicates: true),
    _r('speed_bonus', 'Speed Bonus', RuleCategory.bonus,
        'Bonus to walking speed (ft).',
        params: [_valueInt], predicates: true),
    _r('initiative_bonus', 'Initiative Bonus', RuleCategory.bonus,
        'Bonus to initiative rolls.',
        params: [_valueInt], predicates: true),
    _r('hp_bonus_per_level', 'HP Bonus / Level', RuleCategory.bonus,
        'Adds HP for each character level.',
        params: [_valueInt]),
    _r('hp_bonus_flat', 'HP Bonus (Flat)', RuleCategory.bonus,
        'Adds a flat amount of maximum HP.',
        params: [_valueInt]),
    _r('hp_max_bonus_total', 'Max HP Bonus (Total)', RuleCategory.bonus,
        'One-time total bonus to maximum HP.',
        params: [_valueInt]),
    _r('passive_score_bonus', 'Passive Score Bonus', RuleCategory.bonus,
        'Bonus to a passive check score (e.g. Passive Perception).',
        params: [_valueInt], allowedTargetKinds: ['skill']),

    // ── Defense ──────────────────────────────────────────────────────────
    _r('damage_resistance', 'Damage Resistance', RuleCategory.defense,
        'Resistance to a damage type (half damage).',
        allowedTargetKinds: ['damage-type'], predicates: true),
    _r('damage_immunity', 'Damage Immunity', RuleCategory.defense,
        'Immunity to a damage type.',
        allowedTargetKinds: ['damage-type']),
    _r('damage_vulnerability', 'Damage Vulnerability', RuleCategory.defense,
        'Vulnerability to a damage type (double damage).',
        allowedTargetKinds: ['damage-type']),
    _r('condition_immunity_grant', 'Condition Immunity', RuleCategory.defense,
        'Immunity to a condition.',
        allowedTargetKinds: ['condition']),
    _r('unarmored_ac_formula', 'Unarmored AC Formula', RuleCategory.defense,
        'Replaces unarmored AC with base + ability modifiers (Barbarian/Monk/Draconic).',
        params: const [
          RuleParamSpec(
              key: 'base',
              label: 'Base AC',
              type: RuleParamType.int_,
              location: RuleParamLocation.payload),
          RuleParamSpec(
              key: 'ability_mods',
              label: 'Ability Mods',
              type: RuleParamType.abilityList,
              location: RuleParamLocation.payload),
          RuleParamSpec(
              key: 'shield_allowed',
              label: 'Shield Allowed',
              type: RuleParamType.bool_,
              location: RuleParamLocation.payload),
        ],
        payload: true),
    _r('damage_reduction_flat', 'Flat Damage Reduction', RuleCategory.defense,
        'Reduces incoming damage by a flat amount.',
        params: [_valueInt], status: RuleResolverStatus.deferred),

    // ── Senses ─────────────────────────────────────────────────────────────
    _r('sense_grant', 'Sense Grant', RuleCategory.sense,
        'Grants a sense (e.g. Darkvision) at a range.',
        params: [_rangeFtPayload],
        allowedTargetKinds: ['sense'],
        payload: true),
    _r('truesight_grant', 'Truesight', RuleCategory.sense,
        'Grants truesight at a range.',
        params: [_rangeFtPayload], payload: true),
    _r('blindsight_grant', 'Blindsight', RuleCategory.sense,
        'Grants blindsight at a range.',
        params: [_rangeFtPayload], payload: true),

    // ── Movement ───────────────────────────────────────────────────────────
    _r('fly_speed', 'Fly Speed', RuleCategory.movement,
        'Grants a flying speed (explicit ft, or equal to walking when 0).',
        params: [_valueInt]),
    _r('swim_speed_equals_speed', 'Swim = Walk Speed', RuleCategory.movement,
        'Grants a swimming speed equal to walking speed.'),
    _r('climb_speed_equals_speed', 'Climb = Walk Speed', RuleCategory.movement,
        'Grants a climbing speed equal to walking speed.'),
    _r('walk_on_liquid', 'Walk on Liquid', RuleCategory.movement,
        'Allows walking across liquid surfaces.',
        status: RuleResolverStatus.deferred),

    // ── Spellcasting ───────────────────────────────────────────────────────
    _r('spell_grant', 'Spell Grant', RuleCategory.spellcasting,
        'Grants a known/prepared spell.',
        allowedTargetKinds: ['spell'], scaling: true),
    _r('cantrip_grant', 'Cantrip Grant', RuleCategory.spellcasting,
        'Grants a known cantrip.',
        allowedTargetKinds: ['spell', 'cantrip']),
    _r('cantrip_count_bonus', 'Cantrip Count Bonus', RuleCategory.spellcasting,
        'Increases the number of known cantrips.',
        params: [_valueInt], scaling: true),
    _r('spell_always_prepared', 'Always-Prepared Spell',
        RuleCategory.spellcasting, 'Marks a spell as always prepared.',
        allowedTargetKinds: ['spell'], scaling: true),
    _r('spell_cast_from_item', 'Spell from Item', RuleCategory.spellcasting,
        'Grants the ability to cast a spell from an item.',
        allowedTargetKinds: ['spell'], payload: true),
    _r('spellcasting_ability_to_damage', 'Spell Ability to Damage',
        RuleCategory.spellcasting,
        'Adds the spellcasting ability modifier to certain damage.'),
    _r('concentration_advantage', 'Concentration Advantage',
        RuleCategory.spellcasting,
        'Advantage on concentration saving throws.'),
    _r('concentration_immune_to_damage_break', 'Concentration Damage Immunity',
        RuleCategory.spellcasting,
        'Damage cannot break concentration.'),
    _r('slot_recovery_short_rest', 'Slot Recovery (Short Rest)',
        RuleCategory.spellcasting,
        'Recovers spell slots on a short rest.',
        status: RuleResolverStatus.deferred),

    // ── Resources ──────────────────────────────────────────────────────────
    _r('resource_pool_grant', 'Resource Pool', RuleCategory.resource,
        'Grants a per-rest resource pool (Rage, Ki, Sorcery Points, …).',
        params: const [
          RuleParamSpec(
              key: 'pool_ref',
              label: 'Pool',
              type: RuleParamType.relation,
              location: RuleParamLocation.payload,
              relationAllowedTypes: ['resource-pool']),
          RuleParamSpec(
              key: 'count',
              label: 'Count',
              type: RuleParamType.int_,
              location: RuleParamLocation.payload),
          RuleParamSpec(
              key: 'count_formula',
              label: 'Count Formula',
              type: RuleParamType.string_,
              location: RuleParamLocation.payload),
          RuleParamSpec(
              key: 'recharge',
              label: 'Recharge',
              type: RuleParamType.enumChoice,
              location: RuleParamLocation.payload,
              enumOptions: ['short_rest', 'long_rest']),
        ],
        payload: true,
        scaling: true),
    _r('temp_hp_grant', 'Temporary HP', RuleCategory.resource,
        'Grants temporary HP, usually on a trigger.',
        payload: true, activation: true),
    _r('recovery_grant', 'Recovery Grant', RuleCategory.resource,
        'Grants a recovery mechanic.',
        status: RuleResolverStatus.deferred),

    // ── Combat ───────────────────────────────────────────────────────────
    _r('extra_attack_count', 'Extra Attack Count', RuleCategory.combat,
        'Sets the number of attacks per Attack action.',
        params: [_valueInt], scaling: true),
    _r('extra_attack_bump', 'Extra Attack Bump', RuleCategory.combat,
        'Incrementally raises the extra-attack count.',
        params: [_valueInt], scaling: true),
    _r('crit_range_extend', 'Crit Range Extend', RuleCategory.combat,
        'Lowers the critical-hit threshold (e.g. 20→19).',
        params: [_valueInt]),
    _r('weapon_mastery_grant', 'Weapon Mastery Grant', RuleCategory.combat,
        'Grants access to a weapon mastery.',
        allowedTargetKinds: ['weapon']),
    _r('weapon_mastery_count_bonus', 'Weapon Mastery Count',
        RuleCategory.combat, 'Increases weapon-mastery slots.',
        params: [_valueInt], scaling: true),
    _r('expertise_count', 'Expertise Count', RuleCategory.combat,
        'Increases the number of expertise slots.',
        params: [_valueInt], scaling: true),
    _r('magical_unarmed_strikes', 'Magical Unarmed Strikes',
        RuleCategory.combat, 'Unarmed strikes count as magical.'),
    _r('damage_type_override', 'Damage Type Override', RuleCategory.combat,
        'Overrides the damage type dealt.',
        allowedTargetKinds: ['damage-type'], status: RuleResolverStatus.deferred),
    _r('half_proficiency_to_unproficient_checks', 'Half Proficiency (Jack)',
        RuleCategory.combat,
        'Adds half proficiency to checks you are not proficient in.'),
    _r('reliable_talent', 'Reliable Talent', RuleCategory.combat,
        'Treats a low d20 ability check as a minimum value.',
        status: RuleResolverStatus.deferred),
    _r('min_die_value', 'Minimum Die Value', RuleCategory.combat,
        'Sets a floor on a die roll.',
        params: [_valueInt], status: RuleResolverStatus.deferred),

    // ── Combat — deferred (combat tracker reads these at runtime) ───────────
    _r('advantage_on', 'Advantage On', RuleCategory.combat,
        'Grants advantage on a category of rolls.',
        allowedTargetKinds: ['check', 'save', 'attack'],
        predicates: true, status: RuleResolverStatus.deferred),
    _r('disadvantage_on', 'Disadvantage On', RuleCategory.combat,
        'Imposes disadvantage on a category of rolls.',
        allowedTargetKinds: ['check', 'save', 'attack'],
        predicates: true, status: RuleResolverStatus.deferred),
    _r('condition_advantage_on_save_grant', 'Advantage vs Condition',
        RuleCategory.combat,
        'Advantage on saves against a condition.',
        allowedTargetKinds: ['condition'], status: RuleResolverStatus.deferred),
    _r('extra_damage_on_attack', 'Extra Damage on Attack', RuleCategory.combat,
        'Adds extra damage to an attack.',
        predicates: true, scaling: true, status: RuleResolverStatus.deferred),
    _r('reroll_damage', 'Reroll Damage', RuleCategory.combat,
        'Allows rerolling damage dice.',
        predicates: true, status: RuleResolverStatus.deferred),
    _r('reroll_d20', 'Reroll d20', RuleCategory.combat,
        'Allows rerolling a d20.',
        predicates: true, status: RuleResolverStatus.deferred),
    _r('attack_bonus', 'Attack Bonus', RuleCategory.combat,
        'Flat bonus to attack rolls.',
        params: [_valueInt], status: RuleResolverStatus.deferred),
    _r('attack_bonus_typed', 'Attack Bonus (Typed)', RuleCategory.combat,
        'Bonus to attacks of a specific type.',
        params: [_valueInt], predicates: true,
        status: RuleResolverStatus.deferred),
    _r('damage_bonus_typed', 'Damage Bonus (Typed)', RuleCategory.combat,
        'Bonus to damage of a specific type.',
        params: [_valueInt], predicates: true,
        status: RuleResolverStatus.deferred),
    _r('ignore_cover', 'Ignore Cover', RuleCategory.combat,
        'Ignores cover when attacking.',
        status: RuleResolverStatus.deferred),
    _r('ignore_long_range_disadvantage', 'Ignore Long-Range Disadvantage',
        RuleCategory.combat, 'No disadvantage at long range.',
        status: RuleResolverStatus.deferred),
    _r('reaction_attack_grant', 'Reaction Attack', RuleCategory.combat,
        'Grants a reaction attack.',
        activation: true, status: RuleResolverStatus.deferred),
    _r('reaction_damage_reduction', 'Reaction Damage Reduction',
        RuleCategory.combat, 'Reduces damage as a reaction.',
        activation: true, status: RuleResolverStatus.deferred),
    _r('reaction_negate_via_save', 'Reaction Negate via Save',
        RuleCategory.combat, 'Negates an effect via a saving throw reaction.',
        activation: true, status: RuleResolverStatus.deferred),
    _r('opportunity_attack_immunity_when_disengage_redundant',
        'OA Immunity (Disengage Redundant)', RuleCategory.combat,
        'Immune to opportunity attacks when Disengage is redundant.',
        status: RuleResolverStatus.deferred),
    _r('enemy_cant_disengage_oa', "Enemy Can't Disengage (OA)",
        RuleCategory.combat, 'Enemies cannot avoid your opportunity attacks by disengaging.',
        status: RuleResolverStatus.deferred),
    _r('oa_stops_movement', 'OA Stops Movement', RuleCategory.combat,
        'A hit with an opportunity attack stops the target\'s movement.',
        status: RuleResolverStatus.deferred),

    // ── Meta / state ───────────────────────────────────────────────────────
    _r('state_grant', 'State Grant', RuleCategory.meta,
        'Grants an activatable character state (e.g. Rage).',
        activation: true, status: RuleResolverStatus.deferred),
    _r('choice_group', 'Choice Group', RuleCategory.meta,
        'A deferred player choice (pick N skills/spells/options).',
        payload: true, status: RuleResolverStatus.deferred),
    // Constrained-choice descriptor (PR-R5) — `choice_group`'s richer
    // successor: payload {group_id, label, pick_kind, pick, options?,
    // distributions?}. Parsed by ChoiceSpec.fromEffectRow; pending-choice
    // seeding + pick validation consume it. Same legacy wire accepted.
    _r('choice_spec', 'Constrained Choice', RuleCategory.meta,
        'Pick N of a set (or an ability distribution like +2/+1) — '
        'preserved as data instead of degrading to the full option list.',
        payload: true, status: RuleResolverStatus.deferred),
    // Prereq-trigger rule: never folds stats. Carries `clauses`
    // (rules/prereq_evaluator.dart vocabulary); the resolver warn-keeps,
    // pickers filter. Only the three prereq triggers are selectable.
    _r('prerequisite', 'Prerequisite', RuleCategory.meta,
        'Requirement gate (warn-keep): clauses checked when the source is '
        'granted / equipped / attuned; unmet → sheet warning.',
        allowedTriggers: [
          'prereq_to_grant',
          'prereq_to_equip',
          'prereq_to_attune',
        ],
        status: RuleResolverStatus.deferred),
  ];

  return RuleCatalog(
    rules: {for (final d in defs) d.id: d},
    predicateKinds: _predicateKinds,
    targetKindFallback: _targetKindFallback,
  );
}
