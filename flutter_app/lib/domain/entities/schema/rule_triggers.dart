// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'event_kind.dart';
import 'rule_predicates_v3.dart';

part 'rule_triggers.freezed.dart';
part 'rule_triggers.g.dart';

/// Rule trigger — kuralın hangi konfigürasyonda çalışacağını belirler.
///
/// 5 tip:
/// - always: reactive (her entity read'te)
/// - event: belirli bir event kind'ında (+opsiyonel filter)
/// - d20Test: d20 test context'inde (ability/skill/save filter)
/// - damageApply: damage pipeline içinde (type/direction filter)
/// - turnPhase: turn akışında belirli fazda
@Freezed(unionKey: 'type')
abstract class RuleTrigger with _$RuleTrigger {
  const factory RuleTrigger.always() = AlwaysTrigger;

  const factory RuleTrigger.event({
    required EventKind event,
    PredicateV3? filter,
  }) = EventTrigger;

  const factory RuleTrigger.d20Test({
    required D20TestType testType,
    String? abilityFilter,
    String? skillFilter,
    String? saveAgainstFilter,
  }) = D20Trigger;

  const factory RuleTrigger.damageApply({
    String? damageTypeFilter,
    @Default(DamageDirection.taken) DamageDirection direction,
  }) = DamageTrigger;

  const factory RuleTrigger.turnPhase({
    required TurnPhase phase,
  }) = TurnTrigger;

  factory RuleTrigger.fromJson(Map<String, dynamic> json) =>
      _$RuleTriggerFromJson(json);
}
