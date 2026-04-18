import '../../domain/entities/applied_effect.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/resource_state.dart';
import 'rule_evaluator/rule_evaluation_result_v3.dart';

/// RuleEvaluationResultV3 → Entity mutation.
///
/// Engine pure — mutation'ı entity'ye uygulamaz. Bu sınıf result'ı alır ve
/// `Entity` copyWith ile yeni instance üretir. EventBus cascade akışında
/// repo'ya yazılmadan önce bu applier zincirlenir.
///
/// Sadece entity-local mutation'ları uygular. Cross-entity effect'ler
/// (heal target, dealt damage vb.) caller'da ayrıca işlenir.
class RuleEventMutationApplier {
  /// Reactive/event sonucundaki değişiklikleri [entity]'ye uygula.
  /// Result'taki `computedValues`/`equippedModifiers` write yapılmaz —
  /// onlar read-time derived; mutation olan alanlar yalnız resources,
  /// activeEffects, conditions, temp HP, healings.
  Entity apply({
    required Entity entity,
    required RuleEvaluationResultV3 result,
  }) {
    var next = entity;

    // ── Resources ─────────────────────────────────────────────────────────
    if (result.computedResources.isNotEmpty) {
      final merged = <String, ResourceState>{
        ...entity.resources,
        ...result.computedResources,
      };
      next = next.copyWith(resources: merged);
    }

    // ── Granted AppliedEffects ────────────────────────────────────────────
    if (result.grantedEffects.isNotEmpty) {
      next = next.copyWith(
        activeEffects: [...next.activeEffects, ...result.grantedEffects],
      );
    }

    // ── applyCondition / removeCondition ──────────────────────────────────
    if (result.appliedConditions.isNotEmpty) {
      final newEffects = result.appliedConditions
          .where((id) => !next.activeEffects.any((e) => e.conditionId == id))
          .map((id) => AppliedEffect(
                effectId: 'auto_$id',
                conditionId: id,
              ))
          .toList();
      if (newEffects.isNotEmpty) {
        next = next.copyWith(
          activeEffects: [...next.activeEffects, ...newEffects],
        );
      }
    }
    if (result.removedConditions.isNotEmpty) {
      next = next.copyWith(
        activeEffects: next.activeEffects
            .where((e) => !result.removedConditions.contains(e.conditionId))
            .toList(),
      );
    }

    // ── Break concentration ───────────────────────────────────────────────
    if (result.concentrationBroken) {
      next = next.copyWith(
        activeEffects: next.activeEffects
            .where((e) => !e.requiresConcentration)
            .toList(),
      );
      if (next.turnState != null) {
        next = next.copyWith(
          turnState: next.turnState!.copyWith(concentratingOn: null),
        );
      }
    }

    // ── Temp HP (combat_stats.temp_hp field) ──────────────────────────────
    if (result.grantedTempHp > 0) {
      final combat = Map<String, dynamic>.from(
        (next.fields['combat_stats'] as Map?) ?? const {},
      );
      final existing = combat['temp_hp'];
      final current = existing is num ? existing.toInt() : 0;
      if (result.grantedTempHp > current) {
        combat['temp_hp'] = result.grantedTempHp;
        final fields = Map<String, dynamic>.from(next.fields);
        fields['combat_stats'] = combat;
        next = next.copyWith(fields: fields);
      }
    }

    // ── Healings ──────────────────────────────────────────────────────────
    for (final heal in result.healings) {
      next = _applyHealing(next, heal.key, heal.value);
    }

    return next;
  }

  Entity _applyHealing(Entity entity, String path, num amount) {
    final parts = path.split('.');
    if (parts.isEmpty) return entity;
    final fields = Map<String, dynamic>.from(entity.fields);
    if (parts.length == 1) {
      final existing = fields[parts[0]];
      final cur = existing is num ? existing.toDouble() : 0.0;
      fields[parts[0]] = cur + amount;
      return entity.copyWith(fields: fields);
    }
    // nested path: a.b.c
    final topKey = parts.first;
    final nested = Map<String, dynamic>.from(
      (fields[topKey] as Map?) ?? const {},
    );
    _setNested(nested, parts.sublist(1), amount);
    fields[topKey] = nested;
    return entity.copyWith(fields: fields);
  }

  void _setNested(Map<String, dynamic> map, List<String> path, num amount) {
    if (path.length == 1) {
      final existing = map[path[0]];
      final cur = existing is num ? existing.toDouble() : 0.0;
      final result = cur + amount;
      map[path[0]] = result == result.roundToDouble() ? result.toInt() : result;
      return;
    }
    final next = Map<String, dynamic>.from(
      (map[path.first] as Map?) ?? const {},
    );
    _setNested(next, path.sublist(1), amount);
    map[path.first] = next;
  }
}
