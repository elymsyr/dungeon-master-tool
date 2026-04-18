import '../../domain/entities/schema/rule_effects_v3.dart';
import '../../domain/entities/schema/rule_expressions_v3.dart';
import '../../domain/entities/schema/rule_predicates_v3.dart';
import '../../domain/entities/schema/rule_triggers.dart';
import '../../domain/entities/schema/rule_v2.dart'
    hide
        AlwaysPredicate,
        ComparePredicate,
        AndPredicate,
        OrPredicate,
        NotPredicate;
import '../../domain/entities/schema/rule_v3.dart';

/// V2 Rule → V3 Rule upgrade adapter.
///
/// V2 rule'lar her zaman reactive (always trigger) olarak çalışır.
/// Predicate/expression/effect tip-tip V3 eşdeğerine map edilir.
class RuleV2ToV3Adapter {
  /// Tek bir V2 rule'u V3 RuleV3 formuna çevir.
  static RuleV3 upgrade(RuleV2 v2) {
    return RuleV3(
      ruleId: v2.ruleId,
      name: v2.name,
      description: v2.description,
      enabled: v2.enabled,
      priority: v2.priority,
      trigger: const RuleTrigger.always(),
      when_: upgradePredicate(v2.when_),
      then_: upgradeEffect(v2.then_),
    );
  }

  /// Liste upgrade kolaylık metodu.
  static List<RuleV3> upgradeAll(List<RuleV2> rules) =>
      rules.map(upgrade).toList();

  // ── Predicate ──────────────────────────────────────────────────────────────

  static PredicateV3 upgradePredicate(Predicate p) {
    return p.when(
      compare: (left, op, right, literal) => PredicateV3.compare(
        left: left,
        op: op,
        right: right,
        literalValue: literal,
      ),
      and: (children) =>
          PredicateV3.and(children.map(upgradePredicate).toList()),
      or: (children) =>
          PredicateV3.or(children.map(upgradePredicate).toList()),
      not: (child) => PredicateV3.not(upgradePredicate(child)),
      always: () => const PredicateV3.always(),
    );
  }

  // ── ValueExpression ────────────────────────────────────────────────────────

  static ValueExpressionV3 upgradeExpression(ValueExpression v2) {
    return v2.when(
      fieldValue: (source) => ValueExpressionV3.fieldValue(source),
      aggregate: (rel, src, op, onlyEq) => ValueExpressionV3.aggregate(
        relationFieldKey: rel,
        sourceFieldKey: src,
        op: op,
        onlyEquipped: onlyEq,
      ),
      literal: (value) => ValueExpressionV3.literal(value),
      arithmetic: (left, op, right) => ValueExpressionV3.arithmetic(
        left: upgradeExpression(left),
        op: op,
        right: upgradeExpression(right),
      ),
      tableLookup: (table, key, fallback) => ValueExpressionV3.tableLookup(
        table: table,
        key: upgradeExpression(key),
        fallback: fallback == null ? null : upgradeExpression(fallback),
      ),
      modifier: (source) => ValueExpressionV3.modifier(source),
    );
  }

  // ── RuleEffect ─────────────────────────────────────────────────────────────

  static RuleEffectV3 upgradeEffect(RuleEffect v2) {
    return v2.when(
      setValue: (targetKey, value) => RuleEffectV3.setValue(
        targetFieldKey: targetKey,
        value: upgradeExpression(value),
      ),
      gateEquip: (blockReason) => RuleEffectV3.gateEquip(
        blockReason: blockReason,
      ),
      modifyWhileEquipped: (targetKey, value) =>
          RuleEffectV3.modifyWhileEquipped(
        targetFieldKey: targetKey,
        value: upgradeExpression(value),
      ),
      styleItems: (listKey, style) => RuleEffectV3.styleItems(
        listFieldKey: listKey,
        style: style,
      ),
    );
  }
}

/// V3 → V2 downgrade (yalnız V2-equivalent tip'ler için).
/// V3-only tip'ler (resource/choice/condition/d20/…) için null döner —
/// caller tarafında filtrelenir.
class RuleV3ToV2Adapter {
  /// V3 rule'u V2'ye indir. V3-only trigger/predicate/effect varsa null.
  static RuleV2? downgrade(RuleV3 v3) {
    if (v3.trigger is! AlwaysTrigger) return null;
    final pred = downgradePredicate(v3.when_);
    if (pred == null) return null;
    final effect = downgradeEffect(v3.then_);
    if (effect == null) return null;
    return RuleV2(
      ruleId: v3.ruleId,
      name: v3.name,
      description: v3.description,
      enabled: v3.enabled,
      priority: v3.priority,
      when_: pred,
      then_: effect,
    );
  }

  static Predicate? downgradePredicate(PredicateV3 p) {
    return switch (p) {
      AlwaysPredicate() => const Predicate.always(),
      ComparePredicate c => Predicate.compare(
          left: c.left,
          op: c.op,
          right: c.right,
          literalValue: c.literalValue,
        ),
      AndPredicate a => () {
          final kids = a.children.map(downgradePredicate).toList();
          if (kids.any((k) => k == null)) return null;
          return Predicate.and(kids.cast<Predicate>());
        }(),
      OrPredicate o => () {
          final kids = o.children.map(downgradePredicate).toList();
          if (kids.any((k) => k == null)) return null;
          return Predicate.or(kids.cast<Predicate>());
        }(),
      NotPredicate n => () {
          final child = downgradePredicate(n.child);
          return child == null ? null : Predicate.not(child);
        }(),
      _ => null,
    };
  }

  static ValueExpression? downgradeExpression(ValueExpressionV3 e) {
    return switch (e) {
      LiteralExprV3 l => ValueExpression.literal(l.value),
      FieldValueExprV3 f => ValueExpression.fieldValue(f.source),
      AggregateExprV3 a => ValueExpression.aggregate(
          relationFieldKey: a.relationFieldKey,
          sourceFieldKey: a.sourceFieldKey,
          op: a.op,
          onlyEquipped: a.onlyEquipped,
        ),
      ArithmeticExprV3 x => () {
          final l = downgradeExpression(x.left);
          final r = downgradeExpression(x.right);
          if (l == null || r == null) return null;
          return ValueExpression.arithmetic(left: l, op: x.op, right: r);
        }(),
      TableLookupExprV3 t => () {
          final k = downgradeExpression(t.key);
          if (k == null) return null;
          final fb = t.fallback == null
              ? null
              : downgradeExpression(t.fallback!);
          return ValueExpression.tableLookup(
            table: t.table,
            key: k,
            fallback: fb,
          );
        }(),
      ModifierExprV3 m => ValueExpression.modifier(m.source),
      _ => null,
    };
  }

  static RuleEffect? downgradeEffect(RuleEffectV3 e) {
    return switch (e) {
      SetValueEffectV3 s => () {
          final v = downgradeExpression(s.value);
          return v == null
              ? null
              : RuleEffect.setValue(targetFieldKey: s.targetFieldKey, value: v);
        }(),
      GateEquipEffectV3 g => RuleEffect.gateEquip(blockReason: g.blockReason),
      ModifyWhileEquippedEffectV3 m => () {
          final v = downgradeExpression(m.value);
          return v == null
              ? null
              : RuleEffect.modifyWhileEquipped(
                  targetFieldKey: m.targetFieldKey,
                  value: v,
                );
        }(),
      StyleItemsEffectV3 s => RuleEffect.styleItems(
          listFieldKey: s.listFieldKey,
          style: s.style,
        ),
      _ => null,
    };
  }
}
