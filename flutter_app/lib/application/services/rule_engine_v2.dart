import 'dart:math' as math;

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/rule_v2.dart';

/// Kural değerlendirme sonucu.
class RuleEvaluationResult {
  /// fieldKey → hesaplanan değer
  final Map<String, dynamic> computedValues;

  /// entityId (liste içindeki) → per-item stil
  final Map<String, ItemStyle> itemStyles;

  /// entityId (liste içindeki) → engel nedeni (boş string = izin var)
  final Map<String, String> equipGates;

  /// fieldKey → "while equipped" modifiers birleştirilmiş
  final Map<String, dynamic> equippedModifiers;

  const RuleEvaluationResult({
    this.computedValues = const {},
    this.itemStyles = const {},
    this.equipGates = const {},
    this.equippedModifiers = const {},
  });

  static const empty = RuleEvaluationResult();

  bool get isEmpty =>
      computedValues.isEmpty &&
      itemStyles.isEmpty &&
      equipGates.isEmpty &&
      equippedModifiers.isEmpty;
}

/// Yeni nesil kural motoru — RuleV2 modellerini değerlendirir.
class RuleEngineV2 {
  /// Maksimum relation traversal derinliği (döngüsel zinciri önler).
  static const _maxDepth = 3;

  /// Kuralları değerlendir, sonuçları döndür.
  static RuleEvaluationResult evaluate({
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
  }) {
    if (category.rules.isEmpty) return RuleEvaluationResult.empty;

    final ctx = _EvalContext(entity, allEntities);
    final computedValues = <String, dynamic>{};
    final itemStyles = <String, ItemStyle>{};
    final equipGates = <String, String>{};
    final equippedModifiers = <String, dynamic>{};

    // Manual-only base cache per list field — rule-sourced itemlar temizlenir.
    final listBases = <String, List<dynamic>>{};
    List<dynamic> manualBase(String key) {
      return listBases.putIfAbsent(key, () {
        final existing = entity.fields[key];
        if (existing is! List) return <dynamic>[];
        return existing.where((item) {
          if (item is! Map) return true;
          final src = item['source']?.toString() ?? 'manual';
          return src == 'manual';
        }).toList();
      });
    }

    // Öncelik sırasına göre sırala
    final rules = category.rules.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final rule in rules) {
      if (!rule.enabled) continue;

      rule.then_.when(
        setValue: (targetFieldKey, value) {
          if (_evalPredicate(rule.when_, ctx)) {
            final computed = _evalValue(value, ctx);
            if (computed == null) return;
            if (computed is List) {
              // List setValue: manual itemları koru, rule-sourced olanları
              // bu kuralın ID'siyle tagla ve birleştir.
              final tagged = computed.map((item) {
                if (item is Map) {
                  return {
                    ...Map<String, dynamic>.from(item),
                    'source': 'rule:${rule.ruleId}',
                  };
                }
                return {
                  'id': item.toString(),
                  'equipped': false,
                  'source': 'rule:${rule.ruleId}',
                };
              }).toList();
              final base = computedValues.containsKey(targetFieldKey)
                  ? (computedValues[targetFieldKey] as List)
                  : manualBase(targetFieldKey);
              computedValues[targetFieldKey] = [...base, ...tagged];
            } else {
              computedValues[targetFieldKey] = computed;
            }
          }
        },
        gateEquip: (blockReason) {
          _evalGateEquip(rule, ctx, equipGates);
        },
        modifyWhileEquipped: (targetFieldKey, value) {
          _evalWhileEquipped(rule, ctx, equippedModifiers);
        },
        styleItems: (listFieldKey, style) {
          _evalStyleItems(rule, ctx, itemStyles);
        },
      );
    }

    return RuleEvaluationResult(
      computedValues: computedValues,
      itemStyles: itemStyles,
      equipGates: equipGates,
      equippedModifiers: equippedModifiers,
    );
  }

  /// ValueExpression → insan-okunur formül string. Edit mode'da
  /// kullanıcıya formülü göstermek için.
  static String stringify(ValueExpression expr) {
    return expr.when(
      fieldValue: (src) => _refStr(src),
      aggregate: (rel, srcField, op, onlyEq) =>
          '${op.name}($rel.$srcField${onlyEq ? ':equipped' : ''})',
      literal: (v) => v?.toString() ?? 'null',
      arithmetic: (l, op, r) =>
          '(${stringify(l)} ${_arithSym(op)} ${stringify(r)})',
      tableLookup: (table, key, fb) =>
          '${_refStr(table)}[${stringify(key)}]${fb != null ? ' ?? ${stringify(fb)}' : ''}',
      modifier: (src) => '${_refStr(src)} mod',
    );
  }

  static String _refStr(FieldRef r) {
    final base = switch (r.scope) {
      RefScope.self => r.fieldKey,
      RefScope.related => '${r.relationFieldKey ?? '?'}.${r.fieldKey}',
      RefScope.relatedItems => '${r.relationFieldKey ?? '?'}[].${r.fieldKey}',
    };
    return r.nestedFieldKey != null ? '$base.${r.nestedFieldKey}' : base;
  }

  static String _arithSym(ArithOp op) => switch (op) {
    ArithOp.add => '+',
    ArithOp.subtract => '-',
    ArithOp.multiply => '*',
    ArithOp.divide => '/',
  };

  /// Entity'nin rule'larından bağımlı entity ID'lerini topla.
  /// Provider'ın hangi entity'leri izlemesi gerektiğini belirler.
  static Set<String> collectDependencyIds(
    Entity entity,
    EntityCategorySchema category,
  ) {
    final ids = <String>{};
    for (final rule in category.rules) {
      if (!rule.enabled) continue;
      _collectIdsFromPredicate(rule.when_, entity, ids);
      _collectIdsFromEffect(rule.then_, entity, ids);
    }
    return ids;
  }

  // ─── Predicate Evaluation ──────────────────────────────────────────────────

  static bool _evalPredicate(Predicate pred, _EvalContext ctx, {int depth = 0}) {
    if (depth > _maxDepth) return false;

    return pred.when(
      compare: (left, op, right, literalValue) {
        final leftVal = _resolveRef(left, ctx, depth: depth);
        final rightVal = right != null
            ? _resolveRef(right, ctx, depth: depth)
            : literalValue;
        return _compare(leftVal, op, rightVal);
      },
      and: (children) => children.every((c) => _evalPredicate(c, ctx, depth: depth + 1)),
      or: (children) => children.any((c) => _evalPredicate(c, ctx, depth: depth + 1)),
      not: (child) => !_evalPredicate(child, ctx, depth: depth + 1),
      always: () => true,
    );
  }

  // ─── Value Expression Evaluation ───────────────────────────────────────────

  static dynamic _evalValue(ValueExpression expr, _EvalContext ctx, {int depth = 0}) {
    if (depth > _maxDepth) return null;

    return expr.when(
      fieldValue: (source) => _resolveRef(source, ctx, depth: depth),
      aggregate: (relationFieldKey, sourceFieldKey, op, onlyEquipped) =>
          _evalAggregate(relationFieldKey, sourceFieldKey, op, onlyEquipped, ctx),
      literal: (value) => value,
      arithmetic: (left, arithOp, right) {
        final l = _toDouble(_evalValue(left, ctx, depth: depth + 1));
        final r = _toDouble(_evalValue(right, ctx, depth: depth + 1));
        final result = switch (arithOp) {
          ArithOp.add => l + r,
          ArithOp.subtract => l - r,
          ArithOp.multiply => l * r,
          ArithOp.divide => r != 0 ? l / r : 0.0,
        };
        return result == result.roundToDouble() ? result.toInt() : result;
      },
      tableLookup: (table, key, fallback) {
        final tableValue = _resolveRef(table, ctx, depth: depth + 1);
        final keyValue = _evalValue(key, ctx, depth: depth + 1);
        if (tableValue is! Map) {
          return fallback != null ? _evalValue(fallback, ctx, depth: depth + 1) : null;
        }
        final keyStr = keyValue?.toString();
        if (keyStr == null) {
          return fallback != null ? _evalValue(fallback, ctx, depth: depth + 1) : null;
        }
        // Storage: Map<String, num>; tolerate int keys as well.
        final hit = tableValue[keyStr] ?? tableValue[keyValue];
        if (hit != null) return hit is num && hit == hit.toInt() ? hit.toInt() : hit;
        return fallback != null ? _evalValue(fallback, ctx, depth: depth + 1) : null;
      },
      modifier: (source) {
        final raw = _resolveRef(source, ctx, depth: depth + 1);
        final score = _toDouble(raw);
        // D&D 5e: floor((score - 10) / 2). Dart ~/ floors toward zero, so for
        // negative odd values subtract 1 to emulate math floor.
        final diff = score.toInt() - 10;
        if (diff >= 0) return diff ~/ 2;
        return -((-diff + 1) ~/ 2);
      },
    );
  }

  // ─── Effect Evaluators ─────────────────────────────────────────────────────

  /// "To Be Equipped" — relation list'teki her öğe için gate kontrolü.
  /// Predicate, her öğenin ilişkili entity'si bağlamında değerlendirilir.
  static void _evalGateEquip(
    RuleV2 rule,
    _EvalContext ctx,
    Map<String, String> gates,
  ) {
    final effect = rule.then_ as GateEquipEffect;

    // Tüm relation list field'larındaki öğeleri kontrol et
    for (final entry in ctx.entity.fields.entries) {
      final value = entry.value;
      if (value is! List) continue;

      for (final item in value) {
        final itemId = item is Map ? item['id']?.toString() : item?.toString();
        if (itemId == null || itemId.isEmpty) continue;

        final related = ctx.allEntities[itemId];
        if (related == null) continue;

        // Öğe bağlamında predicate'i değerlendir
        final itemCtx = _EvalContext(ctx.entity, ctx.allEntities, relatedEntity: related);
        if (!_evalPredicate(rule.when_, itemCtx)) {
          gates[itemId] = effect.blockReason.isNotEmpty
              ? effect.blockReason
              : 'Requirements not met';
        }
      }
    }
  }

  /// "When Equipped" — equip edilmiş öğelerden gelen modifierlar.
  static void _evalWhileEquipped(
    RuleV2 rule,
    _EvalContext ctx,
    Map<String, dynamic> modifiers,
  ) {
    final effect = rule.then_ as ModifyWhileEquippedEffect;

    for (final entry in ctx.entity.fields.entries) {
      final value = entry.value;
      if (value is! List) continue;

      for (final item in value) {
        if (item is! Map) continue;
        final isEquipped = item['equipped'] == true;
        if (!isEquipped) continue;

        final itemId = item['id']?.toString();
        if (itemId == null || itemId.isEmpty) continue;

        final related = ctx.allEntities[itemId];
        if (related == null) continue;

        final itemCtx = _EvalContext(ctx.entity, ctx.allEntities, relatedEntity: related);
        if (!_evalPredicate(rule.when_, itemCtx)) continue;

        final computed = _evalValue(effect.value, itemCtx);
        if (computed == null) continue;

        // Mevcut modifier'la birleştir
        final existing = modifiers[effect.targetFieldKey];
        if (existing == null) {
          modifiers[effect.targetFieldKey] = computed;
        } else if (existing is List && computed is List) {
          modifiers[effect.targetFieldKey] = [...existing, ...computed];
        } else if (existing is num && computed is num) {
          modifiers[effect.targetFieldKey] = existing + computed;
        } else {
          // Replace — son gelen kazanır
          modifiers[effect.targetFieldKey] = computed;
        }
      }
    }
  }

  /// Per-item stil uygula — listFieldKey'deki her öğe için predicate değerlendir.
  static void _evalStyleItems(
    RuleV2 rule,
    _EvalContext ctx,
    Map<String, ItemStyle> styles,
  ) {
    final effect = rule.then_ as StyleItemsEffect;
    final listValue = ctx.entity.fields[effect.listFieldKey];
    if (listValue is! List) return;

    for (final item in listValue) {
      final itemId = item is Map ? item['id']?.toString() : item?.toString();
      if (itemId == null || itemId.isEmpty) continue;

      final related = ctx.allEntities[itemId];
      if (related == null) continue;

      final itemCtx = _EvalContext(ctx.entity, ctx.allEntities, relatedEntity: related);
      // Predicate false → stil uygula (koşul sağlanmadığında stil uygulanır)
      if (!_evalPredicate(rule.when_, itemCtx)) {
        styles[itemId] = effect.style;
      }
    }
  }

  // ─── FieldRef Resolution ───────────────────────────────────────────────────

  static dynamic _resolveRef(FieldRef ref, _EvalContext ctx, {int depth = 0}) {
    if (depth > _maxDepth) return null;

    switch (ref.scope) {
      case RefScope.self:
        final value = ctx.entity.fields[ref.fieldKey];
        return ref.nestedFieldKey != null ? _nestedValue(value, ref.nestedFieldKey!) : value;

      case RefScope.related:
        // relatedEntity context'te varsa onu kullan (gateEquip/styleItems bağlamı)
        Entity? related = ctx.relatedEntity;
        if (related == null && ref.relationFieldKey != null) {
          related = _getRelatedEntity(ctx.entity, ref.relationFieldKey!, ctx.allEntities);
        }
        if (related == null) return null;
        final value = related.fields[ref.fieldKey];
        return ref.nestedFieldKey != null ? _nestedValue(value, ref.nestedFieldKey!) : value;

      case RefScope.relatedItems:
        // Liste relation field'ındaki tüm entity'lerin field değerlerini topla
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
          final resolved = ref.nestedFieldKey != null ? _nestedValue(value, ref.nestedFieldKey!) : value;
          if (resolved is List) {
            results.addAll(resolved);
          } else if (resolved != null) {
            results.add(resolved);
          }
        }
        return results;
    }
  }

  // ─── Aggregate ─────────────────────────────────────────────────────────────

  static dynamic _evalAggregate(
    String relationFieldKey,
    String sourceFieldKey,
    AggregateOp op,
    bool onlyEquipped,
    _EvalContext ctx,
  ) {
    final listValue = ctx.entity.fields[relationFieldKey];
    if (listValue is! List) return null;

    // Kaynak entity'leri topla
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

    switch (op) {
      case AggregateOp.sum:
        double result = 0;
        for (final e in entries) {
          result += _toDouble(e.entity.fields[sourceFieldKey]);
        }
        return result == result.roundToDouble() ? result.toInt() : result;

      case AggregateOp.product:
        if (entries.isEmpty) return 0;
        double result = 1;
        for (final e in entries) {
          result *= _toDouble(e.entity.fields[sourceFieldKey]);
        }
        return result == result.roundToDouble() ? result.toInt() : result;

      case AggregateOp.min:
        if (entries.isEmpty) return null;
        double? result;
        for (final e in entries) {
          final v = _toDouble(e.entity.fields[sourceFieldKey]);
          result = result == null ? v : math.min(result, v);
        }
        return result != null && result == result.roundToDouble() ? result.toInt() : result;

      case AggregateOp.max:
        if (entries.isEmpty) return null;
        double? result;
        for (final e in entries) {
          final v = _toDouble(e.entity.fields[sourceFieldKey]);
          result = result == null ? v : math.max(result, v);
        }
        return result != null && result == result.roundToDouble() ? result.toInt() : result;

      case AggregateOp.concat:
        final buf = StringBuffer();
        for (final e in entries) {
          final v = e.entity.fields[sourceFieldKey];
          if (v != null) buf.write(v.toString());
        }
        return buf.toString();

      case AggregateOp.append:
        // conditionalList benzeri davranış — [{id, equipped, from}] formatında
        final result = <Map<String, dynamic>>[];
        // Mevcut equip toggle'larını koru
        final existingItems = <String, bool>{};
        final targetValues = ctx.entity.fields[sourceFieldKey];
        if (targetValues is List) {
          for (final item in targetValues) {
            if (item is Map) {
              existingItems[item['id']?.toString() ?? ''] = item['equipped'] == true;
            }
          }
        }

        for (final e in entries) {
          final sourceVal = e.entity.fields[sourceFieldKey];
          if (sourceVal is List) {
            for (final sv in sourceVal) {
              final svId = sv is Map ? sv['id']?.toString() : sv?.toString();
              if (svId != null && svId.isNotEmpty) {
                final equip = onlyEquipped
                    ? (e.equipped ? (existingItems[svId] ?? true) : false)
                    : (existingItems[svId] ?? true);
                result.add({
                  'id': svId,
                  'equipped': equip,
                  'from': e.entity.name,
                  '_sourceActive': e.equipped,
                });
              }
            }
          } else if (sourceVal is String && sourceVal.isNotEmpty) {
            final equip = onlyEquipped
                ? (e.equipped ? (existingItems[sourceVal] ?? true) : false)
                : (existingItems[sourceVal] ?? true);
            result.add({
              'id': sourceVal,
              'equipped': equip,
              'from': e.entity.name,
              '_sourceActive': e.equipped,
            });
          }
        }
        return result;

      case AggregateOp.replace:
        if (entries.isEmpty) return null;
        return entries.first.entity.fields[sourceFieldKey];
    }
  }

  // ─── Comparison ────────────────────────────────────────────────────────────

  static bool _compare(dynamic left, CompareOp op, dynamic right) {
    switch (op) {
      case CompareOp.isEmpty:
        return _isEmpty(left);
      case CompareOp.isNotEmpty:
        return !_isEmpty(left);
      case CompareOp.eq:
        return _equals(left, right);
      case CompareOp.neq:
        return !_equals(left, right);
      case CompareOp.gt:
        return _numCompare(left, right) > 0;
      case CompareOp.gte:
        return _numCompare(left, right) >= 0;
      case CompareOp.lt:
        return _numCompare(left, right) < 0;
      case CompareOp.lte:
        return _numCompare(left, right) <= 0;
      case CompareOp.contains:
        return _toSet(left).contains(_scalar(right));
      case CompareOp.notContains:
        return !_toSet(left).contains(_scalar(right));
      case CompareOp.isSubsetOf:
        final ls = _toSet(left);
        final rs = _toSet(right);
        return ls.every((e) => rs.contains(e));
      case CompareOp.isSupersetOf:
        final ls = _toSet(left);
        final rs = _toSet(right);
        return rs.every((e) => ls.contains(e));
      case CompareOp.isDisjointFrom:
        final ls = _toSet(left);
        final rs = _toSet(right);
        return ls.intersection(rs).isEmpty;
    }
  }

  // ─── Dependency Collection ─────────────────────────────────────────────────

  static void _collectIdsFromPredicate(Predicate pred, Entity entity, Set<String> ids) {
    pred.when(
      compare: (left, op, right, literal) {
        _collectIdsFromRef(left, entity, ids);
        if (right != null) _collectIdsFromRef(right, entity, ids);
      },
      and: (children) {
        for (final c in children) {
          _collectIdsFromPredicate(c, entity, ids);
        }
      },
      or: (children) {
        for (final c in children) {
          _collectIdsFromPredicate(c, entity, ids);
        }
      },
      not: (child) => _collectIdsFromPredicate(child, entity, ids),
      always: () {},
    );
  }

  static void _collectIdsFromEffect(RuleEffect effect, Entity entity, Set<String> ids) {
    effect.when(
      setValue: (targetFieldKey, value) => _collectIdsFromValue(value, entity, ids),
      gateEquip: (_) => _collectIdsFromAllLists(entity, ids),
      modifyWhileEquipped: (_, value) {
        _collectIdsFromAllLists(entity, ids);
        _collectIdsFromValue(value, entity, ids);
      },
      styleItems: (listFieldKey, _) {
        _collectIdsFromListField(entity, listFieldKey, ids);
      },
    );
  }

  static void _collectIdsFromValue(ValueExpression expr, Entity entity, Set<String> ids) {
    expr.when(
      fieldValue: (source) => _collectIdsFromRef(source, entity, ids),
      aggregate: (relationFieldKey, _, _, _) {
        _collectIdsFromListField(entity, relationFieldKey, ids);
      },
      literal: (_) {},
      arithmetic: (left, _, right) {
        _collectIdsFromValue(left, entity, ids);
        _collectIdsFromValue(right, entity, ids);
      },
      tableLookup: (table, key, fallback) {
        _collectIdsFromRef(table, entity, ids);
        _collectIdsFromValue(key, entity, ids);
        if (fallback != null) _collectIdsFromValue(fallback, entity, ids);
      },
      modifier: (source) => _collectIdsFromRef(source, entity, ids),
    );
  }

  static void _collectIdsFromRef(FieldRef ref, Entity entity, Set<String> ids) {
    if (ref.scope == RefScope.self) return;

    final relKey = ref.relationFieldKey;
    if (relKey == null) return;

    final relValue = entity.fields[relKey];
    if (relValue is String && relValue.isNotEmpty) {
      ids.add(relValue);
    } else if (relValue is List) {
      for (final item in relValue) {
        final id = item is Map ? item['id']?.toString() : item?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
  }

  static void _collectIdsFromListField(Entity entity, String fieldKey, Set<String> ids) {
    final value = entity.fields[fieldKey];
    if (value is List) {
      for (final item in value) {
        final id = item is Map ? item['id']?.toString() : item?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
  }

  static void _collectIdsFromAllLists(Entity entity, Set<String> ids) {
    for (final value in entity.fields.values) {
      if (value is List) {
        for (final item in value) {
          final id = item is Map ? item['id']?.toString() : item?.toString();
          if (id != null && id.isNotEmpty) ids.add(id);
        }
      }
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static Entity? _getRelatedEntity(Entity entity, String relationFieldKey, Map<String, Entity> all) {
    final relValue = entity.fields[relationFieldKey];
    if (relValue is String && relValue.isNotEmpty) {
      return all[relValue];
    }
    return null;
  }

  static dynamic _nestedValue(dynamic value, String key) {
    if (value is Map) return value[key];
    return null;
  }

  static double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }

  static bool _isEmpty(dynamic val) {
    if (val == null) return true;
    if (val is String) return val.isEmpty;
    if (val is List) return val.isEmpty;
    if (val is Map) return val.isEmpty;
    return false;
  }

  static bool _equals(dynamic a, dynamic b) {
    if (a is num && b is num) return a == b;
    return a?.toString() == b?.toString();
  }

  static int _numCompare(dynamic a, dynamic b) {
    return _toDouble(a).compareTo(_toDouble(b));
  }

  static Set<String> _toSet(dynamic val) {
    if (val is List) {
      return val.map((e) {
        if (e is Map) return e['id']?.toString() ?? e.toString();
        return e?.toString() ?? '';
      }).where((s) => s.isNotEmpty).toSet();
    }
    if (val is String && val.isNotEmpty) return {val};
    if (val != null) return {val.toString()};
    return {};
  }

  static String _scalar(dynamic val) {
    if (val is Map) return val['id']?.toString() ?? val.toString();
    return val?.toString() ?? '';
  }
}

class _EvalContext {
  final Entity entity;
  final Map<String, Entity> allEntities;
  /// gateEquip / styleItems bağlamında: şu an değerlendirilen ilişkili entity
  final Entity? relatedEntity;

  _EvalContext(this.entity, this.allEntities, {this.relatedEntity});
}

class _AggEntry {
  final Entity entity;
  final bool equipped;
  final String id;
  _AggEntry(this.entity, this.equipped, this.id);
}
