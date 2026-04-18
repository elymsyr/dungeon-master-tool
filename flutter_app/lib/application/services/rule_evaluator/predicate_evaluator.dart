import '../../../domain/entities/schema/event_kind.dart';
import '../../../domain/entities/schema/rule_predicates_v3.dart';
import '../../../domain/entities/schema/rule_triggers.dart';
import '../../../domain/entities/schema/rule_v2.dart'
    hide AlwaysPredicate, ComparePredicate, AndPredicate, OrPredicate, NotPredicate;
import 'context.dart';

typedef FieldResolver = dynamic Function(FieldRef ref, RuleContext ctx);

/// PredicateV3 evaluator — 13 tip destekler.
///
/// Recursion derinliği [maxDepth] ile sınırlı (RuleV3 spec §8.1).
class PredicateEvaluator {
  PredicateEvaluator({
    required this.resolveField,
    this.maxDepth = 16,
  });

  final FieldResolver resolveField;
  final int maxDepth;

  bool eval(PredicateV3 predicate, RuleContext ctx) {
    if (ctx.depth > maxDepth) return false;

    return switch (predicate) {
      AlwaysPredicate() => true,
      ComparePredicate p => _compare(p, ctx),
      AndPredicate p =>
        p.children.every((c) => eval(c, ctx.withDepth())),
      OrPredicate p =>
        p.children.any((c) => eval(c, ctx.withDepth())),
      NotPredicate p => !eval(p.child, ctx.withDepth()),
      ListLengthPredicate p => _listLength(p, ctx),
      ResourcePredicate p => _resource(p, ctx),
      HasChoicePredicate p => _hasChoice(p, ctx),
      HasConditionPredicate p => _hasCondition(p, ctx),
      HasFeaturePredicate p => _hasFeature(p, ctx),
      InTurnPhasePredicate p => _turnPhase(p, ctx),
      ActionAvailablePredicate p => _actionAvail(p, ctx),
      LevelPredicate p => _level(p, ctx),
      ContextPredicate p => _context(p, ctx),
      _ => false,
    };
  }

  bool _compare(ComparePredicate p, RuleContext ctx) {
    final left = resolveField(p.left, ctx);
    final right = p.right != null
        ? resolveField(p.right!, ctx)
        : p.literalValue;
    return _applyCompareOp(left, p.op, right);
  }

  bool _listLength(ListLengthPredicate p, RuleContext ctx) {
    final raw = resolveField(p.list, ctx);
    final len = raw is List ? raw.length : 0;
    return _applyCompareOp(len, p.op, p.value);
  }

  bool _resource(ResourcePredicate p, RuleContext ctx) {
    final state = ctx.entity.resources[p.resourceKey];
    if (state == null) return _applyCompareOp(0, p.op, p.value);
    final lhs = switch (p.field) {
      ResourceField.current => state.current,
      ResourceField.max => state.max,
      ResourceField.expended => state.expended,
    };
    return _applyCompareOp(lhs, p.op, p.value);
  }

  bool _hasChoice(HasChoicePredicate p, RuleContext ctx) {
    final choice = ctx.entity.choices[p.choiceKey];
    if (choice == null) return false;
    if (p.expectedValue == null) return true;
    final chosen = choice.chosenValue;
    if (chosen is List) return chosen.contains(p.expectedValue);
    return chosen?.toString() == p.expectedValue;
  }

  bool _hasCondition(HasConditionPredicate p, RuleContext ctx) {
    for (final effect in ctx.entity.activeEffects) {
      if (effect.conditionId != p.conditionId) continue;
      if (p.minLevel == null) return true;
      if (effect.level >= p.minLevel!) return true;
    }
    return false;
  }

  bool _hasFeature(HasFeaturePredicate p, RuleContext ctx) {
    // Feature'lar fields['features'] listesinde (granted) veya
    // choices'da kayıtlı olabilir. Her ikisini de kontrol et.
    final features = ctx.entity.fields['features'];
    if (features is List) {
      for (final f in features) {
        if (f is String && f == p.featureId) return true;
        if (f is Map && (f['id'] == p.featureId)) return true;
      }
    }
    for (final choice in ctx.entity.choices.values) {
      final v = choice.chosenValue;
      if (v == p.featureId) return true;
      if (v is List && v.contains(p.featureId)) return true;
    }
    return false;
  }

  bool _turnPhase(InTurnPhasePredicate p, RuleContext ctx) {
    final trigger = ctx.trigger;
    if (trigger is TurnTrigger) return trigger.phase == p.phase;
    return false;
  }

  bool _actionAvail(ActionAvailablePredicate p, RuleContext ctx) {
    final t = ctx.turnState;
    if (t == null) return true; // out-of-combat → serbest
    return switch (p.action) {
      ActionType.action => !t.actionUsed,
      ActionType.bonusAction => !t.bonusActionUsed,
      ActionType.reaction => !t.reactionUsed,
      ActionType.free => true,
      ActionType.legendary => true,
      ActionType.lair => true,
    };
  }

  bool _level(LevelPredicate p, RuleContext ctx) {
    final level = p.classFilter != null
        ? _levelInClass(ctx, p.classFilter!)
        : _totalLevel(ctx);
    return _applyCompareOp(level, p.op, p.level);
  }

  bool _context(ContextPredicate p, RuleContext ctx) {
    final v = ctx.contextValue(p.contextKey);
    return v == p.expectedValue;
  }

  int _totalLevel(RuleContext ctx) {
    final direct = ctx.entity.fields['total_level'];
    if (direct is num) return direct.toInt();
    final classes = ctx.entity.fields['classes'];
    if (classes is List) {
      var sum = 0;
      for (final c in classes) {
        if (c is Map) {
          final lvl = c['level'];
          if (lvl is num) sum += lvl.toInt();
        }
      }
      return sum;
    }
    return 0;
  }

  int _levelInClass(RuleContext ctx, String classId) {
    final classes = ctx.entity.fields['classes'];
    if (classes is! List) return 0;
    for (final c in classes) {
      if (c is Map) {
        final id = c['class_id'] ?? c['classId'] ?? c['id'];
        if (id == classId) {
          final lvl = c['level'];
          if (lvl is num) return lvl.toInt();
        }
      }
    }
    return 0;
  }

  bool _applyCompareOp(dynamic left, CompareOp op, dynamic right) {
    switch (op) {
      case CompareOp.eq:
        return _eq(left, right);
      case CompareOp.neq:
        return !_eq(left, right);
      case CompareOp.gt:
        return _numCompare(left, right, (a, b) => a > b);
      case CompareOp.gte:
        return _numCompare(left, right, (a, b) => a >= b);
      case CompareOp.lt:
        return _numCompare(left, right, (a, b) => a < b);
      case CompareOp.lte:
        return _numCompare(left, right, (a, b) => a <= b);
      case CompareOp.contains:
        if (left is List) return left.contains(right);
        if (left is String && right is String) return left.contains(right);
        return false;
      case CompareOp.notContains:
        if (left is List) return !left.contains(right);
        if (left is String && right is String) return !left.contains(right);
        return true;
      case CompareOp.isSubsetOf:
        if (left is! List || right is! List) return false;
        return left.every(right.contains);
      case CompareOp.isSupersetOf:
        if (left is! List || right is! List) return false;
        return right.every(left.contains);
      case CompareOp.isDisjointFrom:
        if (left is! List || right is! List) return false;
        return !left.any(right.contains);
      case CompareOp.isEmpty:
        if (left == null) return true;
        if (left is String) return left.isEmpty;
        if (left is List) return left.isEmpty;
        if (left is Map) return left.isEmpty;
        return false;
      case CompareOp.isNotEmpty:
        if (left == null) return false;
        if (left is String) return left.isNotEmpty;
        if (left is List) return left.isNotEmpty;
        if (left is Map) return left.isNotEmpty;
        return true;
    }
  }

  bool _eq(dynamic left, dynamic right) {
    if (left is num && right is num) return left == right;
    return left?.toString() == right?.toString();
  }

  bool _numCompare(dynamic left, dynamic right, bool Function(num, num) fn) {
    final a = _toNum(left);
    final b = _toNum(right);
    if (a == null || b == null) return false;
    return fn(a, b);
  }

  num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    if (v is bool) return v ? 1 : 0;
    return null;
  }
}
