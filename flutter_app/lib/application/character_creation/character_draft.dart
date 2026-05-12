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

    /// Optional subclass entity ID. Wizard always shows the subclass step
    /// when the chosen class declares a subclass relationship; the resolver
    /// gates feature application by `granted_at_level`.
    String? subclassId,

    /// Optional lineage / subspecies key (e.g. 'High Elf', 'Wood Elf',
    /// 'Black Dragonborn'). Resolved against the active species entity's
    /// `subspecies_options` list. The race step renders a second picker
    /// when the chosen species declares any options.
    String? subspeciesId,

    /// Selected equipment-choice option per group. Key = `group_id` from
    /// the class/background `equipment_choice_groups` field; value =
    /// `option_id` (e.g. 'A', 'B', 'C').
    @Default({}) Map<String, String> equipmentChoices,

    /// Skill proficiency IDs picked from the chosen class's
    /// `skill_proficiency_options` list. Wizard caps selection at the
    /// class's `skill_proficiency_choice_count`. Background-granted skills
    /// (`granted_skill_refs`) are auto-applied separately and not stored
    /// here.
    @Default([]) List<String> skillChoiceIds,

    /// Tool proficiency IDs picked from the chosen class's
    /// `tool_proficiency_options`. Cap = class's `tool_proficiency_count`.
    @Default([]) List<String> toolChoiceIds,

    /// Language IDs picked from the active campaign's `language` lookups.
    /// Cap = background's `granted_language_count`.
    @Default([]) List<String> languageChoiceIds,

    /// Cantrip spell IDs (spell entities where `level == 0`). Cap derived
    /// from the class's `cantrips_known_by_level` or fallback by caster
    /// kind when the table is unpopulated.
    @Default([]) List<String> cantripIds,

    /// Prepared/known spell IDs of level >= 1. Cap derived from the
    /// class's `prepared_spells_by_level`; max spell level filtered by the
    /// caster-kind slot table.
    @Default([]) List<String> preparedSpellIds,

    /// SRD personality components — short prose written by the player on
    /// the Personality & Flavor step. Empty strings are valid; the wizard
    /// doesn't gate progression on them.
    @Default('') String personalityTraits,
    @Default('') String ideals,
    @Default('') String bonds,
    @Default('') String flaws,
    @Default('') String backstory,

    /// Optional Tiny trinket (SRD §1 Trinkets). Free-text so the user can
    /// roll on the d100 table, pick from a curated list, or invent their
    /// own.
    @Default('') String trinket,

    /// Feats taken during creation. Background's `origin_feat_ref` is added
    /// implicitly by the wizard; level-up feats land here too.
    @Default([]) List<String> featIds,

    /// Sub-picks for feats with `choice_group` payloads (e.g. Magic Initiate
    /// spell list). Key = `<feat_id>:<group_id>`; value = option_id.
    @Default({}) Map<String, String> originFeatChoices,

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
