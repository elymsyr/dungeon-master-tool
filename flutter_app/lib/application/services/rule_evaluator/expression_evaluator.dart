import 'dart:math' as math;

import '../../../domain/entities/schema/event_kind.dart';
import '../../../domain/entities/schema/rule_expressions_v3.dart';
import '../../../domain/entities/schema/rule_v2.dart'
    hide
        FieldValueExpr,
        AggregateExpr,
        LiteralExpr,
        ArithmeticExpr,
        TableLookupExpr,
        ModifierExpr;
import 'context.dart';
import 'predicate_evaluator.dart';

typedef AggregateResolver = dynamic Function(
  String relationFieldKey,
  String sourceFieldKey,
  AggregateOp op,
  bool onlyEquipped,
  RuleContext ctx,
);

/// ValueExpressionV3 evaluator — 17 tip destekler.
///
/// `dice` için ctx.diceRoller kullanılır; `ifThenElse` için predicateEvaluator
/// çağrılır (cross-dep inject).
class ExpressionEvaluator {
  ExpressionEvaluator({
    required this.resolveField,
    required this.resolveAggregate,
    required this.predicateEvaluator,
    this.maxDepth = 16,
  });

  final FieldResolver resolveField;
  final AggregateResolver resolveAggregate;
  final PredicateEvaluator predicateEvaluator;
  final int maxDepth;

  dynamic eval(ValueExpressionV3 expr, RuleContext ctx) {
    if (ctx.depth > maxDepth) return null;

    return switch (expr) {
      LiteralExprV3 e => e.value,
      FieldValueExprV3 e => resolveField(e.source, ctx),
      AggregateExprV3 e => resolveAggregate(
          e.relationFieldKey,
          e.sourceFieldKey,
          e.op,
          e.onlyEquipped,
          ctx,
        ),
      ArithmeticExprV3 e => _arithmetic(e, ctx),
      TableLookupExprV3 e => _tableLookup(e, ctx),
      ModifierExprV3 e => _modifier(e, ctx),
      IfThenElseExpr e =>
        predicateEvaluator.eval(e.condition, ctx.withDepth())
            ? eval(e.then_, ctx.withDepth())
            : eval(e.else_, ctx.withDepth()),
      ListLengthExpr e => _listLength(e, ctx),
      ListFilterExpr e => _listFilter(e, ctx),
      MinExpr e => _minmax(e.values, ctx, isMin: true),
      MaxExpr e => _minmax(e.values, ctx, isMin: false),
      ClampExpr e => _clamp(e, ctx),
      DiceExpr e => _dice(e, ctx),
      StringFormatExpr e => _stringFormat(e, ctx),
      ResourceExpr e => _resourceValue(e, ctx),
      ChoiceExpr e => _choice(e, ctx),
      ContextExpr e => ctx.contextValue(e.contextKey),
      LevelInClassExpr e => _levelInClass(e.classId, ctx),
      TotalLevelExpr() => _totalLevel(ctx),
      PBExpr() => _proficiencyBonus(ctx),
      _ => null,
    };
  }

  // ── V2 parity ──────────────────────────────────────────────────────────────

  dynamic _arithmetic(ArithmeticExprV3 e, RuleContext ctx) {
    final l = _toDouble(eval(e.left, ctx.withDepth()));
    final r = _toDouble(eval(e.right, ctx.withDepth()));
    final result = switch (e.op) {
      ArithOp.add => l + r,
      ArithOp.subtract => l - r,
      ArithOp.multiply => l * r,
      ArithOp.divide => r != 0 ? l / r : 0.0,
    };
    return result == result.roundToDouble() ? result.toInt() : result;
  }

  dynamic _tableLookup(TableLookupExprV3 e, RuleContext ctx) {
    final table = resolveField(e.table, ctx);
    final key = eval(e.key, ctx.withDepth());
    if (table is! Map) {
      return e.fallback != null ? eval(e.fallback!, ctx.withDepth()) : null;
    }
    final keyStr = key?.toString();
    if (keyStr == null) {
      return e.fallback != null ? eval(e.fallback!, ctx.withDepth()) : null;
    }
    final hit = table[keyStr] ?? table[key];
    if (hit != null) return hit is num && hit == hit.toInt() ? hit.toInt() : hit;
    return e.fallback != null ? eval(e.fallback!, ctx.withDepth()) : null;
  }

  dynamic _modifier(ModifierExprV3 e, RuleContext ctx) {
    final score = _toDouble(resolveField(e.source, ctx)).toInt();
    final diff = score - 10;
    if (diff >= 0) return diff ~/ 2;
    return -((-diff + 1) ~/ 2);
  }

  // ── V3 new ─────────────────────────────────────────────────────────────────

  dynamic _listLength(ListLengthExpr e, RuleContext ctx) {
    final raw = resolveField(e.list, ctx);
    return raw is List ? raw.length : 0;
  }

  dynamic _listFilter(ListFilterExpr e, RuleContext ctx) {
    final raw = resolveField(e.list, ctx);
    if (raw is! List) return null;

    // Her öğe için predicate'i değerlendir — öğe related ctx'te.
    final filtered = <dynamic>[];
    for (final item in raw) {
      final itemId = item is Map ? item['id']?.toString() : item?.toString();
      final related =
          itemId != null ? ctx.allEntities[itemId] : null;
      final itemCtx = ctx.withRelated(related, itemId: itemId).withDepth();
      if (predicateEvaluator.eval(e.filter, itemCtx)) {
        filtered.add(item);
      }
    }

    if (e.sourceFieldKey == null) {
      // Sadece öğe sayısı/listesi aggregate et.
      switch (e.op) {
        case AggregateOp.sum:
        case AggregateOp.product:
          return filtered.length;
        case AggregateOp.min:
        case AggregateOp.max:
          return filtered.isEmpty ? null : filtered.length;
        case AggregateOp.concat:
          return filtered.map((i) => i.toString()).join();
        case AggregateOp.append:
          return filtered;
        case AggregateOp.replace:
          return filtered.isEmpty ? null : filtered.first;
      }
    }

    // sourceFieldKey varsa, her filtrelenmiş öğenin ilişkili entity'sinin
    // belirtilen field'ını toplayarak aggregate et.
    final values = <dynamic>[];
    for (final item in filtered) {
      final itemId = item is Map ? item['id']?.toString() : item?.toString();
      if (itemId == null) continue;
      final related = ctx.allEntities[itemId];
      if (related == null) continue;
      values.add(related.fields[e.sourceFieldKey]);
    }
    return _aggregatePrimitives(values, e.op);
  }

  dynamic _minmax(List<ValueExpressionV3> values, RuleContext ctx,
      {required bool isMin}) {
    if (values.isEmpty) return null;
    double? result;
    for (final v in values) {
      final n = _toDouble(eval(v, ctx.withDepth()));
      result = result == null
          ? n
          : (isMin ? math.min(result, n) : math.max(result, n));
    }
    if (result == null) return null;
    return result == result.roundToDouble() ? result.toInt() : result;
  }

  dynamic _clamp(ClampExpr e, RuleContext ctx) {
    final v = _toDouble(eval(e.value, ctx.withDepth()));
    final lo = _toDouble(eval(e.minValue, ctx.withDepth()));
    final hi = _toDouble(eval(e.maxValue, ctx.withDepth()));
    final r = v.clamp(lo, hi);
    return r == r.roundToDouble() ? r.toInt() : r;
  }

  dynamic _dice(DiceExpr e, RuleContext ctx) {
    final bonus = e.bonus == null ? 0 : _toDouble(eval(e.bonus!, ctx.withDepth())).toInt();
    if (e.average) {
      final avg = ctx.diceRoller.average(e.notation) + bonus;
      return avg == avg.roundToDouble() ? avg.toInt() : avg;
    }
    return ctx.diceRoller.roll(e.notation) + bonus;
  }

  String _stringFormat(StringFormatExpr e, RuleContext ctx) {
    var out = e.template;
    for (var i = 0; i < e.args.length; i++) {
      final v = eval(e.args[i], ctx.withDepth());
      out = out.replaceAll('{$i}', v?.toString() ?? '');
    }
    return out;
  }

  dynamic _resourceValue(ResourceExpr e, RuleContext ctx) {
    final state = ctx.entity.resources[e.resourceKey];
    if (state == null) return 0;
    return switch (e.field) {
      ResourceField.current => state.current,
      ResourceField.max => state.max,
      ResourceField.expended => state.expended,
    };
  }

  dynamic _choice(ChoiceExpr e, RuleContext ctx) {
    final c = ctx.entity.choices[e.choiceKey];
    if (c != null) return c.chosenValue;
    return e.fallback != null ? eval(e.fallback!, ctx.withDepth()) : null;
  }

  int _levelInClass(String classId, RuleContext ctx) {
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

  int _totalLevel(RuleContext ctx) {
    final direct = ctx.entity.fields['total_level'];
    if (direct is num) return direct.toInt();
    final classes = ctx.entity.fields['classes'];
    if (classes is List) {
      var sum = 0;
      for (final c in classes) {
        if (c is Map && c['level'] is num) sum += (c['level'] as num).toInt();
      }
      return sum;
    }
    return 0;
  }

  int _proficiencyBonus(RuleContext ctx) {
    // SRD: (total_level - 1) ~/ 4 + 2
    final level = _totalLevel(ctx);
    if (level <= 0) return 2;
    return ((level - 1) ~/ 4) + 2;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    if (v is bool) return v ? 1.0 : 0.0;
    return 0.0;
  }

  dynamic _aggregatePrimitives(List<dynamic> values, AggregateOp op) {
    switch (op) {
      case AggregateOp.sum:
        double s = 0;
        for (final v in values) {
          s += _toDouble(v);
        }
        return s == s.roundToDouble() ? s.toInt() : s;
      case AggregateOp.product:
        if (values.isEmpty) return 0;
        double p = 1;
        for (final v in values) {
          p *= _toDouble(v);
        }
        return p == p.roundToDouble() ? p.toInt() : p;
      case AggregateOp.min:
        if (values.isEmpty) return null;
        double? r;
        for (final v in values) {
          final n = _toDouble(v);
          r = r == null ? n : math.min(r, n);
        }
        return r != null && r == r.roundToDouble() ? r.toInt() : r;
      case AggregateOp.max:
        if (values.isEmpty) return null;
        double? r;
        for (final v in values) {
          final n = _toDouble(v);
          r = r == null ? n : math.max(r, n);
        }
        return r != null && r == r.roundToDouble() ? r.toInt() : r;
      case AggregateOp.concat:
        return values.map((v) => v?.toString() ?? '').join();
      case AggregateOp.append:
        return values;
      case AggregateOp.replace:
        return values.isEmpty ? null : values.first;
    }
  }
}
