import 'event_kind.dart';
import 'rule_effects_v3.dart';
import 'rule_expressions_v3.dart';
import 'rule_predicates_v3.dart';
import 'rule_triggers.dart';
import 'rule_v2.dart';
import 'rule_v3.dart';

/// D&D 5e SRD 5.2.1 seed rule builders.
///
/// Guide §11 — Dnd5eRulesV3 categorize builder. Player category için
/// reactive + event + d20 rule seed'leri üretir. Default schema builder
/// bu listelerin concatenation'ını `EntityCategorySchema.rulesV3`'e koyar.
class Dnd5eRulesV3 {
  Dnd5eRulesV3._();

  /// Player kategorisinin tüm seed rule'larını birleştirir.
  static List<RuleV3> forPlayerCategory() => [
        ...forPlayerReactive(),
        ...forPlayerEvents(),
        ...forPlayerD20Tests(),
      ];

  // ── Reactive Rules ────────────────────────────────────────────────────────

  static List<RuleV3> forPlayerReactive() => [
        ..._abilityModifierRules(),
        _proficiencyBonusRule(),
        _passivePerceptionRule(),
        _passiveInvestigationRule(),
        _passiveInsightRule(),
        _spellSaveDcRule(),
        _spellAttackBonusRule(),
        _attunementCapRule(),
        _carryingCapacityRule(),
      ];

  static List<RuleV3> forPlayerEvents() => [
        _onLongRestSpellSlotsRule(),
        _onLongRestHitDiceRule(),
        _onLongRestExhaustionRule(),
        _onSpellCastConsumeSlotRule(),
        _onDamageTakenConcentrationFlagRule(),
      ];

  static List<RuleV3> forPlayerD20Tests() => [
        _poisonedDisadvantageOnAttackRule(),
        _poisonedDisadvantageOnCheckRule(),
        _frightenedDisadvantageRule(),
        _exhaustionLv3DisadvantageRule(),
        _rageStrAdvantageRule(),
      ];

  // ─── Ability Modifiers ────────────────────────────────────────────────────

  static List<RuleV3> _abilityModifierRules() =>
      ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'].map((abbr) {
        final lower = abbr.toLowerCase();
        return RuleV3(
          ruleId: 'rule_${lower}_mod',
          name: '$abbr modifier',
          description: 'floor((score - 10) / 2)',
          priority: 0,
          when_: const PredicateV3.always(),
          then_: RuleEffectV3.setValue(
            targetFieldKey: '${lower}_mod',
            value: ValueExpressionV3.modifier(
              FieldRef(
                scope: RefScope.self,
                fieldKey: 'stat_block',
                nestedFieldKey: abbr,
              ),
            ),
          ),
        );
      }).toList();

  static RuleV3 _proficiencyBonusRule() => const RuleV3(
        ruleId: 'rule_proficiency_bonus',
        name: 'Proficiency Bonus',
        description: 'PB by level (SRD p.6)',
        priority: 1,
        when_: PredicateV3.always(),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'proficiency_bonus',
          value: ValueExpressionV3.proficiencyBonus(),
        ),
      );

  // ─── Passive Scores ───────────────────────────────────────────────────────

  /// Passive Perception = 10 + WIS mod + PB (if proficient).
  /// Direkt stat_block.WIS'den modifier hesaplar — computed values layer yok.
  static RuleV3 _passivePerceptionRule() =>
      _passiveSkillRule('perception', 'WIS');

  static RuleV3 _passiveInvestigationRule() =>
      _passiveSkillRule('investigation', 'INT');

  static RuleV3 _passiveInsightRule() =>
      _passiveSkillRule('insight', 'WIS');

  static RuleV3 _passiveSkillRule(String skillSlug, String abilityAbbr) =>
      RuleV3(
        ruleId: 'rule_passive_$skillSlug',
        name: 'Passive ${skillSlug[0].toUpperCase()}${skillSlug.substring(1)}',
        description: '10 + $abilityAbbr mod + PB(if proficient)',
        priority: 10,
        when_: const PredicateV3.always(),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'passive_$skillSlug',
          value: ValueExpressionV3.ifThenElse(
            condition: PredicateV3.compare(
              left: FieldRef(
                scope: RefScope.self,
                fieldKey: 'skill_${skillSlug}_proficient',
              ),
              op: CompareOp.eq,
              literalValue: true,
            ),
            then_: ValueExpressionV3.arithmetic(
              left: ValueExpressionV3.arithmetic(
                left: const ValueExpressionV3.literal(10),
                op: ArithOp.add,
                right: ValueExpressionV3.modifier(
                  FieldRef(
                    scope: RefScope.self,
                    fieldKey: 'stat_block',
                    nestedFieldKey: abilityAbbr,
                  ),
                ),
              ),
              op: ArithOp.add,
              right: const ValueExpressionV3.proficiencyBonus(),
            ),
            else_: ValueExpressionV3.arithmetic(
              left: const ValueExpressionV3.literal(10),
              op: ArithOp.add,
              right: ValueExpressionV3.modifier(
                FieldRef(
                  scope: RefScope.self,
                  fieldKey: 'stat_block',
                  nestedFieldKey: abilityAbbr,
                ),
              ),
            ),
          ),
        ),
      );

  // ─── Spellcasting DC & Attack ────────────────────────────────────────────

  /// Spell Save DC = 8 + PB + casting ability mod.
  /// Casting ability field: `casting_ability_mod` (schema bu alanı class'a
  /// göre alias eder — Wizard=INT mod, Cleric=WIS mod, vb.).
  static RuleV3 _spellSaveDcRule() => const RuleV3(
        ruleId: 'rule_spell_save_dc',
        name: 'Spell Save DC',
        description: '8 + PB + casting ability mod',
        priority: 20,
        dependsOn: ['rule_proficiency_bonus'],
        when_: PredicateV3.always(),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'spell_save_dc',
          value: ValueExpressionV3.arithmetic(
            left: ValueExpressionV3.arithmetic(
              left: ValueExpressionV3.literal(8),
              op: ArithOp.add,
              right: ValueExpressionV3.proficiencyBonus(),
            ),
            op: ArithOp.add,
            right: ValueExpressionV3.fieldValue(
              FieldRef(scope: RefScope.self, fieldKey: 'casting_ability_mod'),
            ),
          ),
        ),
      );

  /// Spell Attack = PB + casting ability mod.
  static RuleV3 _spellAttackBonusRule() => const RuleV3(
        ruleId: 'rule_spell_attack_bonus',
        name: 'Spell Attack Bonus',
        description: 'PB + casting ability mod',
        priority: 20,
        dependsOn: ['rule_proficiency_bonus'],
        when_: PredicateV3.always(),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'spell_attack_bonus',
          value: ValueExpressionV3.arithmetic(
            left: ValueExpressionV3.proficiencyBonus(),
            op: ArithOp.add,
            right: ValueExpressionV3.fieldValue(
              FieldRef(scope: RefScope.self, fieldKey: 'casting_ability_mod'),
            ),
          ),
        ),
      );

  // ─── Attunement ───────────────────────────────────────────────────────────

  /// 3 attunement limit — 4. attune bloklanır (gateEquip benzeri).
  /// attunements list < 3 iken flag true.
  static RuleV3 _attunementCapRule() => const RuleV3(
        ruleId: 'rule_attunement_slots_available',
        name: 'Attunement Slots Available',
        description: 'max 3 attunements (SRD p.204)',
        priority: 30,
        when_: PredicateV3.listLength(
          list: FieldRef(scope: RefScope.self, fieldKey: 'attunements'),
          op: CompareOp.lt,
          value: 3,
        ),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'attunement_slot_available',
          value: ValueExpressionV3.literal(true),
        ),
      );

  // ─── Carrying Capacity ───────────────────────────────────────────────────

  /// Carrying capacity = STR score × 15.
  static RuleV3 _carryingCapacityRule() => const RuleV3(
        ruleId: 'rule_carrying_capacity',
        name: 'Carrying Capacity',
        description: 'STR × 15 (SRD p.199)',
        priority: 30,
        when_: PredicateV3.always(),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'carrying_capacity',
          value: ValueExpressionV3.arithmetic(
            left: ValueExpressionV3.fieldValue(
              FieldRef(
                scope: RefScope.self,
                fieldKey: 'stat_block',
                nestedFieldKey: 'STR',
              ),
            ),
            op: ArithOp.multiply,
            right: ValueExpressionV3.literal(15),
          ),
        ),
      );

  // ── Event: Rest Recovery ──────────────────────────────────────────────────

  static RuleV3 _onLongRestSpellSlotsRule() => const RuleV3(
        ruleId: 'rule_long_rest_spell_slots',
        name: 'Long Rest — Refresh Spell Slots',
        description: 'All spell slot resources refill to max',
        trigger: RuleTrigger.event(event: EventKind.onLongRest),
        when_: PredicateV3.always(),
        // Tek effect ile tüm spell slot'ları yenilemek için schema-level
        // birden çok RefreshResource rule yerine; kaynak isimleri sabit:
        // engine refreshResource tek key alır. Multi-key için composite.
        then_: RuleEffectV3.composite([
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_1'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_2'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_3'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_4'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_5'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_6'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_7'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_8'),
          RuleEffectV3.refreshResource(resourceKey: 'spell_slot_9'),
          RuleEffectV3.refreshResource(resourceKey: 'rage_uses'),
          RuleEffectV3.refreshResource(resourceKey: 'channel_divinity'),
          RuleEffectV3.refreshResource(resourceKey: 'bardic_inspiration'),
        ]),
      );

  /// Long rest → half hit dice recovery (SRD p.186).
  static RuleV3 _onLongRestHitDiceRule() => const RuleV3(
        ruleId: 'rule_long_rest_hit_dice',
        name: 'Long Rest — Half Hit Dice Recovery',
        description: 'Each hit die pool recovers max/2 (ceil, min 1)',
        trigger: RuleTrigger.event(event: EventKind.onLongRest),
        when_: PredicateV3.always(),
        then_: RuleEffectV3.composite([
          RuleEffectV3.refreshResource(
            resourceKey: 'hit_dice_d6',
            fraction: 0.5,
          ),
          RuleEffectV3.refreshResource(
            resourceKey: 'hit_dice_d8',
            fraction: 0.5,
          ),
          RuleEffectV3.refreshResource(
            resourceKey: 'hit_dice_d10',
            fraction: 0.5,
          ),
          RuleEffectV3.refreshResource(
            resourceKey: 'hit_dice_d12',
            fraction: 0.5,
          ),
        ]),
      );

  /// Exhaustion: long rest reduces level by 1 (handled via TurnManager from
  /// caller typically; bu rule saf bir marker — engine seviyesinde
  /// decrement effect yok; ama condition var. Rule engine hardcore flow
  /// yerine TurnManager çağrılır. Buna yer tutucu — placeholder reference.
  static RuleV3 _onLongRestExhaustionRule() => const RuleV3(
        ruleId: 'rule_long_rest_exhaustion_marker',
        name: 'Long Rest — Exhaustion Marker',
        description: 'Caller decrements exhaustion via TurnManager; rule '
            'flags a derived boolean',
        trigger: RuleTrigger.event(event: EventKind.onLongRest),
        when_: PredicateV3.hasCondition(conditionId: 'condition-exhaustion'),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'long_rest_should_reduce_exhaustion',
          value: ValueExpressionV3.literal(true),
        ),
      );

  /// Spell cast → consume slot (slot_level payload'dan).
  /// Payload `slot_level` int bekler. Switch-case yerine 9 ayrı conditional.
  static RuleV3 _onSpellCastConsumeSlotRule() => const RuleV3(
        ruleId: 'rule_on_spell_cast_consume_slot',
        name: 'Spell Cast — Consume Slot',
        description: 'trigger.slot_level ile ilgili slot -1',
        trigger: RuleTrigger.event(event: EventKind.onSpellCast),
        when_: PredicateV3.always(),
        then_: RuleEffectV3.composite([
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 1,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_1',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 2,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_2',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 3,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_3',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 4,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_4',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 5,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_5',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 6,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_6',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 7,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_7',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 8,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_8',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
          RuleEffectV3.conditional(
            condition: PredicateV3.context(
              contextKey: 'trigger.slot_level',
              expectedValue: 9,
            ),
            then_: RuleEffectV3.consumeResource(
              resourceKey: 'spell_slot_9',
              amount: ValueExpressionV3.literal(1),
            ),
          ),
        ]),
      );

  /// Damage taken + concentrating → flag for caller to roll CON save
  /// (caller computes DC via DamagePipeline).
  static RuleV3 _onDamageTakenConcentrationFlagRule() => const RuleV3(
        ruleId: 'rule_damage_concentration_check',
        name: 'Damage — Concentration Save Needed',
        description:
            'If concentrating, flag — caller handles DC / save dispatch',
        trigger: RuleTrigger.event(event: EventKind.onDamageTaken),
        when_: PredicateV3.resource(
          resourceKey: 'concentration',
          field: ResourceField.current,
          op: CompareOp.gt,
          value: 0,
        ),
        then_: RuleEffectV3.setValue(
          targetFieldKey: 'pending_concentration_save',
          value: ValueExpressionV3.literal(true),
        ),
      );

  // ── D20 Test Rules ────────────────────────────────────────────────────────

  static RuleV3 _poisonedDisadvantageOnAttackRule() => const RuleV3(
        ruleId: 'rule_poisoned_disadv_attack',
        name: 'Poisoned — Disadvantage on Attack',
        trigger: RuleTrigger.d20Test(testType: D20TestType.attackRoll),
        when_: PredicateV3.hasCondition(conditionId: 'condition-poisoned'),
        then_: RuleEffectV3.grantDisadvantage(
          scope: AdvantageScope.attackRoll,
        ),
      );

  static RuleV3 _poisonedDisadvantageOnCheckRule() => const RuleV3(
        ruleId: 'rule_poisoned_disadv_check',
        name: 'Poisoned — Disadvantage on Ability Checks',
        trigger: RuleTrigger.d20Test(testType: D20TestType.abilityCheck),
        when_: PredicateV3.hasCondition(conditionId: 'condition-poisoned'),
        then_: RuleEffectV3.grantDisadvantage(
          scope: AdvantageScope.abilityCheck,
        ),
      );

  static RuleV3 _frightenedDisadvantageRule() => const RuleV3(
        ruleId: 'rule_frightened_disadv',
        name: 'Frightened — Disadvantage on Attack / Checks',
        trigger: RuleTrigger.d20Test(testType: D20TestType.attackRoll),
        when_: PredicateV3.hasCondition(conditionId: 'condition-frightened'),
        then_: RuleEffectV3.grantDisadvantage(
          scope: AdvantageScope.attackRoll,
        ),
      );

  /// Exhaustion Lv3+: disadvantage on ability checks, attack rolls, saves.
  static RuleV3 _exhaustionLv3DisadvantageRule() => const RuleV3(
        ruleId: 'rule_exhaustion_lv3_disadv',
        name: 'Exhaustion 3+ — Disadvantage on Attacks/Checks/Saves',
        trigger: RuleTrigger.d20Test(testType: D20TestType.attackRoll),
        when_: PredicateV3.hasCondition(
          conditionId: 'condition-exhaustion',
          minLevel: 3,
        ),
        then_: RuleEffectV3.grantDisadvantage(
          scope: AdvantageScope.d20Test,
        ),
      );

  /// Rage active → advantage on STR checks & STR saves.
  /// Rage active flag = rage_uses.current < rage_uses.max (birisi harcandı).
  /// Alternatif: choice 'rage_active' = true. Bu rule choice-bazlı varsayar.
  static RuleV3 _rageStrAdvantageRule() => const RuleV3(
        ruleId: 'rule_rage_str_advantage',
        name: 'Rage — Advantage on STR checks/saves',
        trigger: RuleTrigger.d20Test(
          testType: D20TestType.abilityCheck,
          abilityFilter: 'STR',
        ),
        when_: PredicateV3.hasChoice(
          choiceKey: 'rage_active',
          expectedValue: 'true',
        ),
        then_: RuleEffectV3.grantAdvantage(
          scope: AdvantageScope.abilityCheck,
          filter: 'STR',
        ),
      );
}
