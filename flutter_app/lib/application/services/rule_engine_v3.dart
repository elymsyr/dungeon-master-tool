import 'dart:math' as math;

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/event_kind.dart';
import '../../domain/entities/schema/rule_triggers.dart';
import '../../domain/entities/schema/rule_v2.dart'
    show AggregateOp, FieldRef, RefScope;
import '../../domain/entities/schema/rule_v3.dart';
import '../../domain/entities/turn_state.dart';
import 'dice_roller.dart';
import 'rule_evaluator/context.dart';
import 'rule_evaluator/effect_applier.dart';
import 'rule_evaluator/expression_evaluator.dart';
import 'rule_evaluator/predicate_evaluator.dart';
import 'rule_evaluator/rule_evaluation_result_v3.dart';

/// Top-level Rule Engine V3.
///
/// Guide §4 — 5 evaluation path:
/// - reactive (always trigger, her entity read'te)
/// - event (EventKind bazlı, cascade destekli)
/// - d20Test (attack/save/check context)
/// - damage (apply pipeline önce)
/// - turnPhase (turn flow)
///
/// Bu sınıf stateless — input (entity, rules, trigger) + output
/// ([RuleEvaluationResultV3]). Cascade ve side-effect'ler caller'da.
class RuleEngineV3 {
  RuleEngineV3({
    DiceRoller? diceRoller,
    this.maxDepth = 16,
    this.maxCascadeEvents = 50,
  }) : _dice = diceRoller ?? DefaultDiceRoller() {
    _predicateEval = PredicateEvaluator(
      resolveField: _resolveField,
      maxDepth: maxDepth,
    );
    _exprEval = ExpressionEvaluator(
      resolveField: _resolveField,
      resolveAggregate: _resolveAggregate,
      predicateEvaluator: _predicateEval,
      maxDepth: maxDepth,
    );
    _applier = EffectApplier(
      expressionEvaluator: _exprEval,
      predicateEvaluator: _predicateEval,
      maxDepth: maxDepth,
    );
  }

  final DiceRoller _dice;
  final int maxDepth;
  final int maxCascadeEvents;

  late final PredicateEvaluator _predicateEval;
  late final ExpressionEvaluator _exprEval;
  late final EffectApplier _applier;

  PredicateEvaluator get predicateEvaluator => _predicateEval;
  ExpressionEvaluator get expressionEvaluator => _exprEval;
  EffectApplier get effectApplier => _applier;

  // ── Reactive Path ──────────────────────────────────────────────────────────

  /// Always-trigger rule'ları değerlendir.
  RuleEvaluationResultV3 evaluateReactive({
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
    required List<RuleV3> rules,
    TurnState? turnState,
  }) {
    return _evaluate(
      entity: entity,
      category: category,
      allEntities: allEntities,
      rules: rules,
      trigger: const RuleTrigger.always(),
      turnState: turnState,
    );
  }

  // ── Event Path ─────────────────────────────────────────────────────────────

  /// Event trigger'lı rule'ları değerlendir. Payload event-specific veri.
  RuleEvaluationResultV3 evaluateEvent({
    required EventKind kind,
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
    required List<RuleV3> rules,
    Map<String, dynamic> payload = const {},
    TurnState? turnState,
  }) {
    return _evaluate(
      entity: entity,
      category: category,
      allEntities: allEntities,
      rules: rules,
      trigger: RuleTrigger.event(event: kind),
      eventPayload: payload,
      turnState: turnState,
    );
  }

  // ── D20 Path ───────────────────────────────────────────────────────────────

  RuleEvaluationResultV3 evaluateD20Test({
    required D20TestType testType,
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
    required List<RuleV3> rules,
    String? ability,
    String? skill,
    String? saveAgainst,
    TurnState? turnState,
  }) {
    return _evaluate(
      entity: entity,
      category: category,
      allEntities: allEntities,
      rules: rules,
      trigger: RuleTrigger.d20Test(
        testType: testType,
        abilityFilter: ability,
        skillFilter: skill,
        saveAgainstFilter: saveAgainst,
      ),
      turnState: turnState,
    );
  }

  // ── Damage Path ────────────────────────────────────────────────────────────

  RuleEvaluationResultV3 evaluateDamage({
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
    required List<RuleV3> rules,
    required DamageDirection direction,
    String? damageType,
    int? amount,
    TurnState? turnState,
  }) {
    return _evaluate(
      entity: entity,
      category: category,
      allEntities: allEntities,
      rules: rules,
      trigger: RuleTrigger.damageApply(
        damageTypeFilter: damageType,
        direction: direction,
      ),
      eventPayload: {
        'damage_type': ?damageType,
        'damage_amount': ?amount,
      },
      turnState: turnState,
    );
  }

  // ── Turn Phase Path ────────────────────────────────────────────────────────

  RuleEvaluationResultV3 evaluateTurnPhase({
    required TurnPhase phase,
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
    required List<RuleV3> rules,
    TurnState? turnState,
  }) {
    return _evaluate(
      entity: entity,
      category: category,
      allEntities: allEntities,
      rules: rules,
      trigger: RuleTrigger.turnPhase(phase: phase),
      turnState: turnState,
    );
  }

  // ── Core ───────────────────────────────────────────────────────────────────

  RuleEvaluationResultV3 _evaluate({
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
    required List<RuleV3> rules,
    required RuleTrigger trigger,
    Map<String, dynamic> eventPayload = const {},
    TurnState? turnState,
  }) {
    final result = RuleEvaluationResultV3();
    if (rules.isEmpty) return result;

    final ordered = _orderRules(rules);

    final baseCtx = RuleContext(
      entity: entity,
      category: category,
      allEntities: allEntities,
      trigger: trigger,
      eventPayload: eventPayload,
      turnState: turnState,
      diceRoller: _dice,
    );

    for (final rule in ordered) {
      if (!rule.enabled) continue;
      if (!_triggerMatches(rule.trigger, trigger)) continue;
      if (!_triggerFilterPasses(rule.trigger, baseCtx)) continue;

      // Effect-specific context loops (gateEquip/styleItems → per-item).
      final scopes = _contextsForEffect(rule, baseCtx);
      for (final ctx in scopes) {
        if (!_predicateEval.eval(rule.when_, ctx)) continue;
        _applier.apply(
          effect: rule.then_,
          ctx: ctx,
          result: result,
          sourceRuleId: rule.ruleId,
        );
      }
    }

    return result;
  }

  /// Topological sort: dependsOn (edges) + priority (tie-break).
  List<RuleV3> _orderRules(List<RuleV3> rules) {
    final byId = {for (final r in rules) r.ruleId: r};
    final visited = <String>{};
    final onStack = <String>{};
    final ordered = <RuleV3>[];

    void visit(RuleV3 rule) {
      if (visited.contains(rule.ruleId)) return;
      if (onStack.contains(rule.ruleId)) return; // cycle → skip
      onStack.add(rule.ruleId);
      for (final dep in rule.dependsOn) {
        final depRule = byId[dep];
        if (depRule != null) visit(depRule);
      }
      onStack.remove(rule.ruleId);
      visited.add(rule.ruleId);
      ordered.add(rule);
    }

    // Priority ascending ilk sıra; topological ilişki sırasında dep'ler önce.
    final sorted = rules.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (final r in sorted) {
      visit(r);
    }
    return ordered;
  }

  bool _triggerMatches(RuleTrigger ruleTrigger, RuleTrigger callTrigger) {
    // Both AlwaysTrigger → match.
    if (ruleTrigger is AlwaysTrigger && callTrigger is AlwaysTrigger) {
      return true;
    }
    // Always rules fire only on always evaluation.
    if (ruleTrigger is AlwaysTrigger) return false;
    if (callTrigger is AlwaysTrigger) return false;

    if (ruleTrigger is EventTrigger && callTrigger is EventTrigger) {
      return ruleTrigger.event == callTrigger.event;
    }
    if (ruleTrigger is D20Trigger && callTrigger is D20Trigger) {
      if (ruleTrigger.testType != callTrigger.testType) return false;
      if (ruleTrigger.abilityFilter != null &&
          ruleTrigger.abilityFilter != callTrigger.abilityFilter) {
        return false;
      }
      if (ruleTrigger.skillFilter != null &&
          ruleTrigger.skillFilter != callTrigger.skillFilter) {
        return false;
      }
      if (ruleTrigger.saveAgainstFilter != null &&
          ruleTrigger.saveAgainstFilter != callTrigger.saveAgainstFilter) {
        return false;
      }
      return true;
    }
    if (ruleTrigger is DamageTrigger && callTrigger is DamageTrigger) {
      if (ruleTrigger.direction != callTrigger.direction) return false;
      if (ruleTrigger.damageTypeFilter != null &&
          ruleTrigger.damageTypeFilter != callTrigger.damageTypeFilter) {
        return false;
      }
      return true;
    }
    if (ruleTrigger is TurnTrigger && callTrigger is TurnTrigger) {
      return ruleTrigger.phase == callTrigger.phase;
    }
    return false;
  }

  bool _triggerFilterPasses(RuleTrigger trigger, RuleContext ctx) {
    if (trigger is EventTrigger && trigger.filter != null) {
      return _predicateEval.eval(trigger.filter!, ctx);
    }
    return true;
  }

  /// gateEquip / styleItems / modifyWhileEquipped → entity'nin relation
  /// listelerindeki her öğe için ayrı context üret. Aksi halde tek context.
  List<RuleContext> _contextsForEffect(RuleV3 rule, RuleContext base) {
    final effectType = rule.then_.runtimeType.toString();
    final perItem = effectType.contains('GateEquip') ||
        effectType.contains('StyleItems') ||
        effectType.contains('ModifyWhileEquipped');

    if (!perItem) return [base];

    final contexts = <RuleContext>[];
    for (final entry in base.entity.fields.entries) {
      final value = entry.value;
      if (value is! List) continue;
      for (final item in value) {
        final itemId = item is Map
            ? item['id']?.toString()
            : item?.toString();
        if (itemId == null || itemId.isEmpty) continue;

        // modifyWhileEquipped: yalnız equipped olanlar.
        if (effectType.contains('ModifyWhileEquipped')) {
          final equipped = item is Map && item['equipped'] == true;
          if (!equipped) continue;
        }

        final related = base.allEntities[itemId];
        if (related == null) continue;
        contexts.add(base.withRelated(related, itemId: itemId));
      }
    }
    return contexts.isEmpty ? [base] : contexts;
  }

  // ── Field Resolver ─────────────────────────────────────────────────────────

  dynamic _resolveField(FieldRef ref, RuleContext ctx) {
    if (ctx.depth > maxDepth) return null;

    switch (ref.scope) {
      case RefScope.self:
        final value = ctx.entity.fields[ref.fieldKey];
        return ref.nestedFieldKey != null
            ? _nestedValue(value, ref.nestedFieldKey!)
            : value;

      case RefScope.related:
        Entity? related = ctx.relatedEntity;
        if (related == null && ref.relationFieldKey != null) {
          related =
              _getRelatedEntity(ctx.entity, ref.relationFieldKey!, ctx.allEntities);
        }
        if (related == null) return null;
        final value = related.fields[ref.fieldKey];
        return ref.nestedFieldKey != null
            ? _nestedValue(value, ref.nestedFieldKey!)
            : value;

      case RefScope.relatedItems:
        if (ref.relationFieldKey == null) return null;
        final listValue = ctx.entity.fields[ref.relationFieldKey!];
        if (listValue is! List) return null;

        final results = <dynamic>[];
        for (final item in listValue) {
          final itemId = item is Map ? item['id']?.toString() : item?.toString();
          if (itemId == null || itemId.isEmpty) continue;
          final related = ctx.allEntities[itemId];
          if (related == null) continue;
          final value = related.fields[ref.fieldKey];
          final resolved = ref.nestedFieldKey != null
              ? _nestedValue(value, ref.nestedFieldKey!)
              : value;
          if (resolved is List) {
            results.addAll(resolved);
          } else if (resolved != null) {
            results.add(resolved);
          }
        }
        return results;
    }
  }

  Entity? _getRelatedEntity(
    Entity entity,
    String relationFieldKey,
    Map<String, Entity> allEntities,
  ) {
    final value = entity.fields[relationFieldKey];
    if (value == null) return null;
    String? id;
    if (value is Map) {
      id = value['id']?.toString();
    } else if (value is String) {
      id = value;
    } else if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map) {
        id = first['id']?.toString();
      } else {
        id = first?.toString();
      }
    }
    return id == null ? null : allEntities[id];
  }

  dynamic _nestedValue(dynamic value, String nestedKey) {
    if (value is Map) return value[nestedKey];
    return null;
  }

  // ── Aggregate Resolver ─────────────────────────────────────────────────────

  dynamic _resolveAggregate(
    String relationFieldKey,
    String sourceFieldKey,
    AggregateOp op,
    bool onlyEquipped,
    RuleContext ctx,
  ) {
    final listValue = ctx.entity.fields[relationFieldKey];
    if (listValue is! List) return null;

    final entries = <_AggEntry>[];
    for (final item in listValue) {
      String? id;
      bool equipped = true;
      if (item is Map) {
        id = item['id']?.toString();
        equipped = item['equipped'] != false;
      } else if (item is String) {
        id = item;
      }
      if (id == null || id.isEmpty) continue;
      if (onlyEquipped && !equipped) continue;

      final related = ctx.allEntities[id];
      if (related == null) continue;
      entries.add(_AggEntry(related, equipped, id));
    }

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    switch (op) {
      case AggregateOp.sum:
        double r = 0;
        for (final e in entries) {
          r += toDouble(e.entity.fields[sourceFieldKey]);
        }
        return r == r.roundToDouble() ? r.toInt() : r;
      case AggregateOp.product:
        if (entries.isEmpty) return 0;
        double r = 1;
        for (final e in entries) {
          r *= toDouble(e.entity.fields[sourceFieldKey]);
        }
        return r == r.roundToDouble() ? r.toInt() : r;
      case AggregateOp.min:
        if (entries.isEmpty) return null;
        double? r;
        for (final e in entries) {
          final v = toDouble(e.entity.fields[sourceFieldKey]);
          r = r == null ? v : math.min(r, v);
        }
        return r != null && r == r.roundToDouble() ? r.toInt() : r;
      case AggregateOp.max:
        if (entries.isEmpty) return null;
        double? r;
        for (final e in entries) {
          final v = toDouble(e.entity.fields[sourceFieldKey]);
          r = r == null ? v : math.max(r, v);
        }
        return r != null && r == r.roundToDouble() ? r.toInt() : r;
      case AggregateOp.concat:
        final buf = StringBuffer();
        for (final e in entries) {
          final v = e.entity.fields[sourceFieldKey];
          if (v != null) buf.write(v.toString());
        }
        return buf.toString();
      case AggregateOp.append:
        final result = <dynamic>[];
        for (final e in entries) {
          final v = e.entity.fields[sourceFieldKey];
          if (v is List) {
            result.addAll(v);
          } else if (v != null) {
            result.add(v);
          }
        }
        return result;
      case AggregateOp.replace:
        if (entries.isEmpty) return null;
        return entries.first.entity.fields[sourceFieldKey];
    }
  }
}

class _AggEntry {
  const _AggEntry(this.entity, this.equipped, this.id);
  final Entity entity;
  final bool equipped;
  final String id;
}
