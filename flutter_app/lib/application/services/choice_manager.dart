import '../../domain/entities/choice_state.dart';
import '../../domain/entities/entity.dart';

/// Kullanıcı seçimlerini Entity'ye kaydeden manager.
///
/// UI (prompt dialog) bir `ChoiceOption` seçildiğinde [record] çağırır.
/// Rule context'te `ValueExpressionV3.choice(choiceKey)` bu kayıttan
/// değer çeker.
///
/// Stateless — Entity al, mutated Entity döndür.
class ChoiceManager {
  const ChoiceManager();

  /// Seçim kaydet. Aynı key mevcutsa üzerine yazar (re-choice support).
  Entity record({
    required Entity entity,
    required String choiceKey,
    required dynamic value,
    String sourceRuleId = '',
    String? chosenAt,
  }) {
    final state = ChoiceState(
      choiceKey: choiceKey,
      chosenValue: value,
      sourceRuleId: sourceRuleId,
      chosenAt: chosenAt ?? DateTime.now().toIso8601String(),
    );
    return entity.copyWith(
      choices: {...entity.choices, choiceKey: state},
    );
  }

  /// Seçimi sil.
  Entity clear({
    required Entity entity,
    required String choiceKey,
  }) {
    if (!entity.choices.containsKey(choiceKey)) return entity;
    final copy = Map<String, ChoiceState>.from(entity.choices);
    copy.remove(choiceKey);
    return entity.copyWith(choices: copy);
  }

  /// Tek bir seçim oku.
  ChoiceState? read({
    required Entity entity,
    required String choiceKey,
  }) =>
      entity.choices[choiceKey];

  /// Seçilen değeri (raw) oku. Yoksa null.
  dynamic value({
    required Entity entity,
    required String choiceKey,
  }) =>
      entity.choices[choiceKey]?.chosenValue;

  bool has({
    required Entity entity,
    required String choiceKey,
  }) =>
      entity.choices.containsKey(choiceKey);
}
