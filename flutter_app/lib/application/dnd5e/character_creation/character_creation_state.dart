import 'character_creation_step.dart';
import 'character_draft.dart';

/// Immutable snapshot of where the user is in the wizard + what they've filled
/// in so far + which steps have cleared validation. A Notifier rebuilds this
/// with `copyWith` on every edit.
class CharacterCreationState {
  final CharacterCreationStep currentStep;
  final CharacterDraft draft;
  final Set<CharacterCreationStep> completedSteps;

  /// Per-step validation message, `null` = step clean. The UI surfaces this
  /// inline under the step content and disables "Next" while non-null.
  final Map<CharacterCreationStep, String?> validationMessages;

  const CharacterCreationState({
    required this.currentStep,
    required this.draft,
    required this.completedSteps,
    required this.validationMessages,
  });

  static const CharacterCreationState initial = CharacterCreationState(
    currentStep: CharacterCreationStep.startMode,
    draft: CharacterDraft.empty,
    completedSteps: <CharacterCreationStep>{},
    validationMessages: <CharacterCreationStep, String?>{},
  );

  /// `true` when the CURRENT step has no outstanding validation error — the
  /// "Next" button should be enabled.
  bool get canAdvance => validationMessages[currentStep] == null;

  /// `true` when the user can move to the previous step (every step except
  /// the first).
  bool get canGoBack => !currentStep.isFirst;

  CharacterCreationState copyWith({
    CharacterCreationStep? currentStep,
    CharacterDraft? draft,
    Set<CharacterCreationStep>? completedSteps,
    Map<CharacterCreationStep, String?>? validationMessages,
  }) {
    return CharacterCreationState(
      currentStep: currentStep ?? this.currentStep,
      draft: draft ?? this.draft,
      completedSteps: completedSteps ?? this.completedSteps,
      validationMessages: validationMessages ?? this.validationMessages,
    );
  }
}
