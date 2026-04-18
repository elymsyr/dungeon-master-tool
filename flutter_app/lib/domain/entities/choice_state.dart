// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'choice_state.freezed.dart';
part 'choice_state.g.dart';

/// Kullanıcı seçim kaydı — karakter yaratımda veya level up'ta yapılan
/// seçimler burada kalıcı tutulur (species_lineage, fighting_style,
/// expertise_skills, vb.).
///
/// `chosenValue` string id veya liste olabilir. Rule context'te
/// `ValueExpressionV3.choice(choiceKey)` ile erişilir.
@freezed
abstract class ChoiceState with _$ChoiceState {
  const factory ChoiceState({
    required String choiceKey,

    /// Seçilen değer — id string, list of ids, veya yapı.
    @JsonKey(name: 'value') dynamic chosenValue,

    /// Hangi rule bu seçimi presentChoice ile istedi.
    @Default('') String sourceRuleId,

    /// Seçimin yapıldığı tarih/context.
    String? chosenAt,
  }) = _ChoiceState;

  factory ChoiceState.fromJson(Map<String, dynamic> json) =>
      _$ChoiceStateFromJson(json);
}
