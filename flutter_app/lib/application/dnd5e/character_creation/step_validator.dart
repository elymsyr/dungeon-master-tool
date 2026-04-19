import '../../../domain/dnd5e/core/ability.dart';
import 'ability_score_method.dart';
import 'character_creation_step.dart';
import 'character_draft.dart';

/// Content-derived constraints the validator needs that aren't on the draft
/// itself. The Notifier builds one of these per step from the catalog lookups
/// (class definitions, background tables, species requirements) before
/// calling into [CharacterDraftValidator].
///
/// Every field is nullable so the validator runs cleanly with partial
/// content — the relevant checks are skipped until the caller can populate
/// the hint. This is what lets Doc 10 ship before Doc 15 (SRD content).
class StepValidationContext {
  /// Earliest level at which the chosen class forces a subclass pick.
  /// Skipped when null (e.g. class not yet selected).
  final int? subclassChoiceLevel;

  /// Number of skill proficiencies the chosen class grants. Skipped when null.
  final int? requiredClassSkillCount;

  /// Total languages the player must choose at origin (background + species
  /// grants combined). Skipped when null.
  final int? requiredLanguageCount;

  /// Total tools the chosen background makes the player pick. Skipped when null.
  final int? requiredToolCount;

  /// `true` iff the chosen species has lineage variants and the player must
  /// pick one. Skipped when null.
  final bool? speciesRequiresLineage;

  /// The 3 abilities the chosen background lists for its +4 bonus pool.
  /// Skipped when null.
  final Set<Ability>? backgroundListedAbilities;

  /// Number of equipment bundle options the chosen class exposes (`A`/`B`/...)
  /// in SRD §16 — `equipmentChoice` must be `0..count-1`. Skipped when null.
  final int? equipmentOptionCount;

  const StepValidationContext({
    this.subclassChoiceLevel,
    this.requiredClassSkillCount,
    this.requiredLanguageCount,
    this.requiredToolCount,
    this.speciesRequiresLineage,
    this.backgroundListedAbilities,
    this.equipmentOptionCount,
  });

  static const StepValidationContext empty = StepValidationContext();
}

/// Pure per-step validator. Every method returns `null` on success or a
/// human-readable message on the first failure.
class CharacterDraftValidator {
  final AbilityScoreValidator _scores;

  const CharacterDraftValidator({
    AbilityScoreValidator scores = const AbilityScoreValidator(),
  }) : _scores = scores;

  String? validate(
    CharacterCreationStep step,
    CharacterDraft draft,
    StepValidationContext ctx,
  ) {
    switch (step) {
      case CharacterCreationStep.startMode:
        return _startMode(draft);
      case CharacterCreationStep.classChoice:
        return _classChoice(draft, ctx);
      case CharacterCreationStep.origin:
        return _origin(draft, ctx);
      case CharacterCreationStep.abilities:
        return _abilities(draft, ctx);
      case CharacterCreationStep.alignment:
        return _alignment(draft);
      case CharacterCreationStep.details:
        return _details(draft, ctx);
      case CharacterCreationStep.review:
        return null;
    }
  }

  String? _startMode(CharacterDraft d) {
    if (d.startingLevel < 1 || d.startingLevel > 20) {
      return 'Starting level must be between 1 and 20 (got ${d.startingLevel}).';
    }
    return null;
  }

  String? _classChoice(CharacterDraft d, StepValidationContext ctx) {
    if (d.classLevels.isEmpty) return 'Pick at least one class.';
    final total = d.totalLevel;
    if (total != d.startingLevel) {
      return 'Class levels total $total but starting level is ${d.startingLevel}.';
    }
    if (ctx.subclassChoiceLevel != null &&
        d.classLevels.isNotEmpty &&
        d.classLevels.first.level >= ctx.subclassChoiceLevel! &&
        d.classLevels.first.subclassId == null) {
      return 'Subclass choice required at level ${ctx.subclassChoiceLevel}.';
    }
    if (ctx.requiredClassSkillCount != null &&
        d.chosenSkillIds.length != ctx.requiredClassSkillCount) {
      return 'Pick exactly ${ctx.requiredClassSkillCount} class skills '
          '(currently ${d.chosenSkillIds.length}).';
    }
    return null;
  }

  String? _origin(CharacterDraft d, StepValidationContext ctx) {
    if (d.speciesId == null) return 'Pick a species.';
    if (ctx.speciesRequiresLineage == true && d.lineageId == null) {
      return 'This species needs a lineage choice.';
    }
    if (d.backgroundId == null) return 'Pick a background.';
    if (ctx.requiredLanguageCount != null &&
        d.chosenLanguageIds.length != ctx.requiredLanguageCount) {
      return 'Pick exactly ${ctx.requiredLanguageCount} languages '
          '(currently ${d.chosenLanguageIds.length}).';
    }
    if (ctx.requiredToolCount != null &&
        d.chosenToolIds.length != ctx.requiredToolCount) {
      return 'Pick exactly ${ctx.requiredToolCount} tools '
          '(currently ${d.chosenToolIds.length}).';
    }
    return null;
  }

  String? _abilities(CharacterDraft d, StepValidationContext ctx) {
    if (d.scoreMethod == null) return 'Pick an ability score method.';
    final String? methodMsg;
    switch (d.scoreMethod!) {
      case AbilityScoreGenerationMethod.standardArray:
        methodMsg = _scores.validateStandardArray(d.baseScores);
      case AbilityScoreGenerationMethod.random:
        methodMsg = _scores.validateRandom(d.baseScores);
      case AbilityScoreGenerationMethod.pointBuy:
        methodMsg = _scores.validatePointBuy(d.baseScores);
    }
    if (methodMsg != null) return methodMsg;
    if (ctx.backgroundListedAbilities != null) {
      return _scores.validateBackgroundBonuses(
        baseScores: d.baseScores,
        bonuses: d.backgroundBonuses,
        listedAbilities: ctx.backgroundListedAbilities!,
      );
    }
    return null;
  }

  String? _alignment(CharacterDraft d) {
    if (d.alignmentId == null) return 'Pick an alignment.';
    return null;
  }

  String? _details(CharacterDraft d, StepValidationContext ctx) {
    final name = d.name?.trim() ?? '';
    if (name.isEmpty) return 'Name cannot be empty.';
    if (ctx.equipmentOptionCount != null) {
      final pick = d.equipmentChoice;
      if (pick == null ||
          pick < 0 ||
          pick >= ctx.equipmentOptionCount!) {
        return 'Pick an equipment bundle '
            '(1..${ctx.equipmentOptionCount}).';
      }
    }
    return null;
  }
}
