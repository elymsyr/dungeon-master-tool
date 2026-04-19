import '../../../domain/dnd5e/core/ability.dart';
import 'ability_score_method.dart';
import 'hp_method.dart';

/// One row of the wizard's class-level list. Holds the user's chosen class
/// + level target + (optional) subclass for that class.
class DraftClassLevel {
  final String classId;
  final int level;
  final String? subclassId;

  const DraftClassLevel({
    required this.classId,
    required this.level,
    this.subclassId,
  });

  DraftClassLevel copyWith({
    String? classId,
    int? level,
    Object? subclassId = _sentinel,
  }) {
    return DraftClassLevel(
      classId: classId ?? this.classId,
      level: level ?? this.level,
      subclassId: identical(subclassId, _sentinel)
          ? this.subclassId
          : subclassId as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftClassLevel &&
          other.classId == classId &&
          other.level == level &&
          other.subclassId == subclassId;

  @override
  int get hashCode => Object.hash(classId, level, subclassId);
}

const _sentinel = Object();

/// In-progress character being assembled by the wizard. Every field is
/// nullable / defaulted because the user fills them step-by-step. Pure data;
/// validation lives in `step_validator.dart`.
class CharacterDraft {
  final String? name;
  final int startingLevel;
  final List<DraftClassLevel> classLevels;

  final String? speciesId;
  final String? lineageId;
  final String? backgroundId;
  final List<String> chosenLanguageIds;
  final List<String> chosenSkillIds;
  final List<String> chosenToolIds;
  final List<String> chosenFeatIds;

  final AbilityScoreGenerationMethod? scoreMethod;
  final Map<Ability, int> baseScores;
  final Map<Ability, int> backgroundBonuses;

  final String? alignmentId;

  final HpMethod hpMethod;
  final int? equipmentChoice;

  const CharacterDraft({
    this.name,
    this.startingLevel = 1,
    this.classLevels = const <DraftClassLevel>[],
    this.speciesId,
    this.lineageId,
    this.backgroundId,
    this.chosenLanguageIds = const <String>[],
    this.chosenSkillIds = const <String>[],
    this.chosenToolIds = const <String>[],
    this.chosenFeatIds = const <String>[],
    this.scoreMethod,
    this.baseScores = const <Ability, int>{},
    this.backgroundBonuses = const <Ability, int>{},
    this.alignmentId,
    this.hpMethod = HpMethod.fixed,
    this.equipmentChoice,
  });

  static const CharacterDraft empty = CharacterDraft();

  CharacterDraft copyWith({
    Object? name = _sentinel,
    int? startingLevel,
    List<DraftClassLevel>? classLevels,
    Object? speciesId = _sentinel,
    Object? lineageId = _sentinel,
    Object? backgroundId = _sentinel,
    List<String>? chosenLanguageIds,
    List<String>? chosenSkillIds,
    List<String>? chosenToolIds,
    List<String>? chosenFeatIds,
    Object? scoreMethod = _sentinel,
    Map<Ability, int>? baseScores,
    Map<Ability, int>? backgroundBonuses,
    Object? alignmentId = _sentinel,
    HpMethod? hpMethod,
    Object? equipmentChoice = _sentinel,
  }) {
    return CharacterDraft(
      name: identical(name, _sentinel) ? this.name : name as String?,
      startingLevel: startingLevel ?? this.startingLevel,
      classLevels: classLevels ?? this.classLevels,
      speciesId: identical(speciesId, _sentinel)
          ? this.speciesId
          : speciesId as String?,
      lineageId: identical(lineageId, _sentinel)
          ? this.lineageId
          : lineageId as String?,
      backgroundId: identical(backgroundId, _sentinel)
          ? this.backgroundId
          : backgroundId as String?,
      chosenLanguageIds: chosenLanguageIds ?? this.chosenLanguageIds,
      chosenSkillIds: chosenSkillIds ?? this.chosenSkillIds,
      chosenToolIds: chosenToolIds ?? this.chosenToolIds,
      chosenFeatIds: chosenFeatIds ?? this.chosenFeatIds,
      scoreMethod: identical(scoreMethod, _sentinel)
          ? this.scoreMethod
          : scoreMethod as AbilityScoreGenerationMethod?,
      baseScores: baseScores ?? this.baseScores,
      backgroundBonuses: backgroundBonuses ?? this.backgroundBonuses,
      alignmentId: identical(alignmentId, _sentinel)
          ? this.alignmentId
          : alignmentId as String?,
      hpMethod: hpMethod ?? this.hpMethod,
      equipmentChoice: identical(equipmentChoice, _sentinel)
          ? this.equipmentChoice
          : equipmentChoice as int?,
    );
  }

  int get totalLevel =>
      classLevels.fold<int>(0, (sum, cl) => sum + cl.level);
}
