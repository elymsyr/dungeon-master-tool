// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'event_kind.dart';
import 'rule_effects_v3.dart';
import 'rule_predicates_v3.dart';
import 'rule_triggers.dart';

part 'rule_v3.freezed.dart';
part 'rule_v3.g.dart';

/// Rule V3 — (trigger, when, then, scope) tuple.
///
/// V2'den farkları:
/// - `trigger` alanı: reactive/event/d20/damage/turn scope'larını ayırır
/// - `scope`: engine routing için (pre-computed)
/// - `dependsOn`: topological sort için diğer rule id'lerine referans
/// - `schemaVersion`: format evolution için
///
/// Backward compat: V2 RuleV2 → V3 RuleV3 için [rule_v2_to_v3_adapter.dart]
/// `scope = reactive`, `trigger = always()` ile upgrade eder.
@freezed
abstract class RuleV3 with _$RuleV3 {
  const factory RuleV3({
    required String ruleId,
    required String name,
    @Default('') String description,
    @Default(true) bool enabled,

    /// Çalışma sırası (düşük = önce). `dependsOn` ile birlikte topological
    /// sort'un tie-breaker'ı.
    @Default(0) int priority,

    /// Ne zaman çalışır (always / event / d20 / damage / turnPhase).
    @Default(RuleTrigger.always()) RuleTrigger trigger,

    /// Koşul — true dönerse effect uygulanır.
    @JsonKey(name: 'when') required PredicateV3 when_,

    /// Effect.
    @JsonKey(name: 'then') required RuleEffectV3 then_,

    /// Engine routing hint. Trigger'dan da çıkarılabilir; hızlı filter için burada.
    @Default(RuleScope.reactive) RuleScope scope,

    /// Bu rule çalışmadan önce çalışması gereken rule id'leri.
    @Default(<String>[]) List<String> dependsOn,

    /// Format evolution.
    @Default(1) int schemaVersion,
  }) = _RuleV3;

  factory RuleV3.fromJson(Map<String, dynamic> json) => _$RuleV3FromJson(json);
}
