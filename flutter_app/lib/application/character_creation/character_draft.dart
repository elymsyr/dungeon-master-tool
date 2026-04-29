import 'package:freezed_annotation/freezed_annotation.dart';

import 'ability_score_method.dart';

part 'character_draft.freezed.dart';
part 'character_draft.g.dart';

/// Pure value object holding the character creation wizard's collected
/// answers. Survives step navigation; committed to `characterListProvider`
/// only on the Review step.
///
/// All entity-id fields point at entities in the active campaign (race /
/// class / background categories). The wizard does not author new
/// entities — it only references what the campaign already provides.
@freezed
abstract class CharacterDraft with _$CharacterDraft {
  const factory CharacterDraft({
    @Default('') String name,
    @Default('') String description,
    @Default('') String portraitPath,
    @Default([]) List<String> tags,

    /// Active campaign / world this character will be bound to. Empty =
    /// orphan (creation will refuse to commit until set).
    @Default('') String worldName,

    /// Template the wizard authors against — must contain a Player
    /// category. Resolved up-front by the launcher so the wizard never
    /// renders without one.
    @Default('') String templateId,
    @Default('') String templateName,

    /// 1-20.
    @Default(1) int level,

    /// Free-text alignment label (e.g. "Lawful Good"). Wizard offers a
    /// dropdown of the canonical 9 + Unaligned but storage is loose so
    /// homebrew templates can extend.
    @Default('') String alignment,

    /// Entity IDs in the active campaign.
    String? raceId,
    String? classId,
    String? backgroundId,

    @Default(AbilityScoreMethod.standardArray) AbilityScoreMethod abilityMethod,

    /// Six-key ability map. Default = all 10s; wizard updates via the
    /// method-specific UI on the Abilities step.
    @Default({'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10})
    Map<String, int> baseAbilities,

    /// Racial bonuses chosen on the Abilities step (origin feat +3 spread,
    /// 2024 SRD). Stored separately from base so the wizard can let the
    /// user retry the racial assignment without losing base scores.
    @Default({'STR': 0, 'DEX': 0, 'CON': 0, 'INT': 0, 'WIS': 0, 'CHA': 0})
    Map<String, int> racialBonuses,
  }) = _CharacterDraft;

  factory CharacterDraft.fromJson(Map<String, dynamic> json) =>
      _$CharacterDraftFromJson(json);
}
