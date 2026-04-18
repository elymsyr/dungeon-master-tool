// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'schema/rule_expressions_v3.dart';

part 'applied_effect.freezed.dart';
part 'applied_effect.g.dart';

/// Duration spec — effect'in ne kadar süreyle aktif olacağı.
@Freezed(unionKey: 'type')
abstract class DurationSpec with _$DurationSpec {
  /// Round sayısı (combat).
  const factory DurationSpec.rounds(int count) = RoundsDuration;

  /// Dakika (encounter dışı).
  const factory DurationSpec.minutes(int count) = MinutesDuration;

  /// Saat.
  const factory DurationSpec.hours(int count) = HoursDuration;

  /// Concentration bağlı — caster concentration kırılınca biter.
  const factory DurationSpec.concentration() = ConcentrationDuration;

  /// Kalıcı (disenchant edilene kadar).
  const factory DurationSpec.permanent() = PermanentDuration;

  /// Uzun dinlenmeye kadar.
  const factory DurationSpec.untilLongRest() = UntilLongRestDuration;

  /// Kısa dinlenmeye kadar.
  const factory DurationSpec.untilShortRest() = UntilShortRestDuration;

  factory DurationSpec.fromJson(Map<String, dynamic> json) =>
      _$DurationSpecFromJson(json);
}

/// Geçici modifier — spell, condition, item-provided buff/debuff.
/// Entity.activeEffects listesinde durur; engine her evaluation'da merge eder.
@freezed
abstract class AppliedEffect with _$AppliedEffect {
  const factory AppliedEffect({
    required String effectId,

    /// Etki kaynağı — spell/feature/magic-item id.
    @Default('') String sourceId,

    /// Hangi field'ı modify ediyor (ör. 'combat_stats.ac', 'str_mod').
    /// Condition'lar için boş olabilir — sadece conditionId set edilir.
    @Default('') String targetField,

    /// Uygulanacak modifier expression (ör. +2 AC = literal(2)).
    ValueExpressionV3? modifier,

    /// Süre.
    @Default(DurationSpec.permanent()) DurationSpec duration,

    /// Kalan tur sayısı (duration=rounds için countdown).
    int? remainingTurns,

    /// Concentration gerektiriyor mu — caster'ın concentration slot'unu tutar.
    @Default(false) bool requiresConcentration,

    /// Condition id (ör. 'condition-poisoned') — varsa entity bu condition altında.
    String? conditionId,

    /// Exhaustion gibi stackable condition'lar için seviye.
    @Default(0) int level,

    /// Serbest metadata (tooltip, description, vb.).
    @Default({}) Map<String, dynamic> metadata,
  }) = _AppliedEffect;

  factory AppliedEffect.fromJson(Map<String, dynamic> json) =>
      _$AppliedEffectFromJson(json);
}

/// Choice option — presentChoice effect'inde kullanıcıya sunulan seçenek.
@freezed
abstract class ChoiceOption with _$ChoiceOption {
  const factory ChoiceOption({
    required String id,
    required String label,
    @JsonKey(name: 'value') dynamic value,
    String? description,
  }) = _ChoiceOption;

  factory ChoiceOption.fromJson(Map<String, dynamic> json) =>
      _$ChoiceOptionFromJson(json);
}
