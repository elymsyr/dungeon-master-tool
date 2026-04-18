import '../../../domain/entities/resource_state.dart';
import '../../../domain/entities/schema/rule_effects_v3.dart';
import 'context.dart';
import 'expression_evaluator.dart';
import 'predicate_evaluator.dart';
import 'rule_evaluation_result_v3.dart';

/// Tek bir rule'un effect'ini result'a uygular. Recursive — composite +
/// conditional alt-effect'leri için tekrar kendini çağırır.
class EffectApplier {
  EffectApplier({
    required this.expressionEvaluator,
    required this.predicateEvaluator,
    this.maxDepth = 16,
  });

  final ExpressionEvaluator expressionEvaluator;
  final PredicateEvaluator predicateEvaluator;
  final int maxDepth;

  void apply({
    required RuleEffectV3 effect,
    required RuleContext ctx,
    required RuleEvaluationResultV3 result,
    required String sourceRuleId,
  }) {
    if (ctx.depth > maxDepth) return;

    switch (effect) {
      case SetValueEffectV3 e:
        final v = expressionEvaluator.eval(e.value, ctx);
        if (v != null) result.computedValues[e.targetFieldKey] = v;

      case GateEquipEffectV3 e:
        final itemId = ctx.listItemId;
        if (itemId != null) {
          result.equipGates[itemId] =
              e.blockReason.isNotEmpty ? e.blockReason : 'Requirements not met';
        }

      case ModifyWhileEquippedEffectV3 e:
        final v = expressionEvaluator.eval(e.value, ctx);
        if (v != null) {
          final existing = result.equippedModifiers[e.targetFieldKey];
          if (existing == null) {
            result.equippedModifiers[e.targetFieldKey] = v;
          } else if (existing is num && v is num) {
            result.equippedModifiers[e.targetFieldKey] = existing + v;
          } else if (existing is List && v is List) {
            result.equippedModifiers[e.targetFieldKey] = [...existing, ...v];
          } else {
            result.equippedModifiers[e.targetFieldKey] = v;
          }
        }

      case StyleItemsEffectV3 e:
        final itemId = ctx.listItemId;
        if (itemId != null) result.itemStyles[itemId] = e.style;

      // ── Resources ──────────────────────────────────────────────────────────

      case SetResourceMaxEffect e:
        final maxVal = _toInt(expressionEvaluator.eval(e.value, ctx));
        final existing = ctx.entity.resources[e.resourceKey] ??
            ResourceState(resourceKey: e.resourceKey, max: 0, current: 0);
        result.computedResources[e.resourceKey] = existing.copyWith(
          max: maxVal,
          current: existing.current.clamp(0, maxVal),
          refreshRule: e.refreshRule,
        );
        result.resourceDeltas.add(ResourceDelta(
          resourceKey: e.resourceKey,
          setMax: maxVal,
          setRefreshRule: e.refreshRule,
        ));

      case ConsumeResourceEffect e:
        final amount = _toInt(expressionEvaluator.eval(e.amount, ctx));
        final state = result.computedResources[e.resourceKey] ??
            ctx.entity.resources[e.resourceKey];
        if (state != null) {
          if (e.blockIfInsufficient && state.current < amount) {
            // Insufficient — skip silently (engine caller decides UX).
            return;
          }
          final newCurrent = (state.current - amount).clamp(0, state.max);
          result.computedResources[e.resourceKey] =
              state.copyWith(current: newCurrent);
        }
        result.resourceDeltas.add(ResourceDelta(
          resourceKey: e.resourceKey,
          consume: amount,
        ));

      case RefreshResourceEffect e:
        final state = result.computedResources[e.resourceKey] ??
            ctx.entity.resources[e.resourceKey];
        int? amt;
        if (e.amount != null) {
          amt = _toInt(expressionEvaluator.eval(e.amount!, ctx));
        }
        if (state != null) {
          int newCurrent;
          if (e.fraction != null) {
            final add = (state.max * e.fraction!).ceil();
            newCurrent = (state.current + add).clamp(0, state.max);
          } else if (amt != null) {
            newCurrent = (state.current + amt).clamp(0, state.max);
          } else {
            newCurrent = state.max;
          }
          result.computedResources[e.resourceKey] =
              state.copyWith(current: newCurrent);
        }
        result.resourceDeltas.add(ResourceDelta(
          resourceKey: e.resourceKey,
          refreshAmount: amt,
          refreshFraction: e.fraction,
          refreshToFull: amt == null && e.fraction == null,
        ));

      // ── Features / Conditions ──────────────────────────────────────────────

      case GrantFeatureEffect e:
        result.grantedFeatures.add(FeatureGrant(
          featureId: e.featureId,
          source: e.source,
          sourceRuleId: sourceRuleId,
        ));

      case RevokeFeatureEffect e:
        result.revokedFeatures.add(e.featureId);

      case ApplyConditionEffect e:
        result.appliedConditions.add(e.conditionId);

      case RemoveConditionEffect e:
        result.removedConditions.add(e.conditionId);

      // ── D20 Context ────────────────────────────────────────────────────────

      case GrantAdvantageEffect e:
        result.advantages.add(GrantedAdvantage(
          scope: e.scope,
          filter: e.filter,
          sourceRuleId: sourceRuleId,
        ));

      case GrantDisadvantageEffect e:
        result.disadvantages.add(GrantedAdvantage(
          scope: e.scope,
          filter: e.filter,
          sourceRuleId: sourceRuleId,
        ));

      case ModifyCriticalRangeEffect e:
        final current = result.criticalRangeMin ?? 20;
        if (e.newMinRange < current) result.criticalRangeMin = e.newMinRange;

      // ── Damage / Attack ────────────────────────────────────────────────────

      case DamageRollEffect e:
        final amt = _toNum(expressionEvaluator.eval(e.value, ctx));
        result.damageRollMutations.add(DamageRollMutation(
          op: e.op,
          amount: amt,
          sourceRuleId: sourceRuleId,
        ));

      case AttackRollEffect e:
        final bonus = _toNum(expressionEvaluator.eval(e.bonus, ctx));
        result.attackRollBonus += bonus;

      // ── HP / Healing ───────────────────────────────────────────────────────

      case TempHpEffect e:
        final amt = _toInt(expressionEvaluator.eval(e.amount, ctx));
        // RAW: Temp HP doesn't stack — higher wins.
        if (amt > result.grantedTempHp) result.grantedTempHp = amt;

      case HealEffect e:
        final amt = _toNum(expressionEvaluator.eval(e.amount, ctx));
        result.healings.add(MapEntry(
          e.targetField ?? 'combat_stats.hp',
          amt,
        ));

      // ── Applied Effects ────────────────────────────────────────────────────

      case ApplyAppliedEffectEffect e:
        result.grantedEffects.add(e.effect);

      case BreakConcentrationEffect():
        result.concentrationBroken = true;

      // ── Turn Economy ───────────────────────────────────────────────────────

      case GrantActionEffect e:
        result.grantedActions
            .add((actionId: e.actionId, type: e.actionType));

      // ── Choice ─────────────────────────────────────────────────────────────

      case PresentChoiceEffect e:
        result.pendingChoices.add(ChoicePrompt(
          choiceKey: e.choiceKey,
          options: e.options,
          sourceRuleId: sourceRuleId,
          required: e.required,
        ));

      // ── Composition ────────────────────────────────────────────────────────

      case CompositeEffect e:
        for (final sub in e.effects) {
          apply(
            effect: sub,
            ctx: ctx.withDepth(),
            result: result,
            sourceRuleId: sourceRuleId,
          );
        }

      case ConditionalEffect e:
        if (predicateEvaluator.eval(e.condition, ctx)) {
          apply(
            effect: e.then_,
            ctx: ctx.withDepth(),
            result: result,
            sourceRuleId: sourceRuleId,
          );
        } else if (e.else_ != null) {
          apply(
            effect: e.else_!,
            ctx: ctx.withDepth(),
            result: result,
            sourceRuleId: sourceRuleId,
          );
        }

      default:
        break;
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }
}
