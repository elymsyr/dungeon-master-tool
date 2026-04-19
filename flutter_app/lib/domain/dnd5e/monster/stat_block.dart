import '../catalog/content_reference.dart';
import '../core/ability.dart';
import '../core/ability_scores.dart';
import '../core/challenge_rating.dart';
import '../core/proficiency.dart';

/// Per-creature movement speeds (walk/fly/swim/climb/burrow) in feet.
class MonsterSpeeds {
  final int walk;
  final int? fly;
  final int? swim;
  final int? climb;
  final int? burrow;
  final bool hover;

  const MonsterSpeeds({
    this.walk = 30,
    this.fly,
    this.swim,
    this.climb,
    this.burrow,
    this.hover = false,
  });
}

/// Senses in feet + passive perception advisory (engine recomputes passive).
class MonsterSenses {
  final int? darkvision;
  final int? blindsight;
  final int? tremorsense;
  final int? truesight;

  const MonsterSenses({
    this.darkvision,
    this.blindsight,
    this.tremorsense,
    this.truesight,
  });
}

/// The full stat-block payload sans name/description (those live on [Monster]).
class StatBlock {
  final String sizeId;
  final String typeId;
  final String? alignmentId;
  final int armorClass;
  final int hitPoints;
  final String? hitPointsFormula;
  final MonsterSpeeds speeds;
  final AbilityScores abilities;
  final Map<Ability, Proficiency> savingThrows;
  final Map<String, Proficiency> skills;
  final Set<String> damageResistanceIds;
  final Set<String> damageImmunityIds;
  final Set<String> damageVulnerabilityIds;
  final Set<String> conditionImmunityIds;
  final MonsterSenses senses;
  final Set<String> languageIds;
  final ChallengeRating cr;

  StatBlock._({
    required this.sizeId,
    required this.typeId,
    required this.alignmentId,
    required this.armorClass,
    required this.hitPoints,
    required this.hitPointsFormula,
    required this.speeds,
    required this.abilities,
    required this.savingThrows,
    required this.skills,
    required this.damageResistanceIds,
    required this.damageImmunityIds,
    required this.damageVulnerabilityIds,
    required this.conditionImmunityIds,
    required this.senses,
    required this.languageIds,
    required this.cr,
  });

  factory StatBlock({
    required ContentReference sizeId,
    required ContentReference typeId,
    ContentReference? alignmentId,
    required int armorClass,
    required int hitPoints,
    String? hitPointsFormula,
    MonsterSpeeds speeds = const MonsterSpeeds(),
    required AbilityScores abilities,
    Map<Ability, Proficiency> savingThrows = const {},
    Map<String, Proficiency> skills = const {},
    Set<ContentReference> damageResistanceIds = const {},
    Set<ContentReference> damageImmunityIds = const {},
    Set<ContentReference> damageVulnerabilityIds = const {},
    Set<ContentReference> conditionImmunityIds = const {},
    MonsterSenses senses = const MonsterSenses(),
    Set<ContentReference> languageIds = const {},
    required ChallengeRating cr,
  }) {
    validateContentId(sizeId);
    validateContentId(typeId);
    if (alignmentId != null) validateContentId(alignmentId);
    if (armorClass < 0) throw ArgumentError('StatBlock.armorClass must be >= 0');
    if (hitPoints < 1) throw ArgumentError('StatBlock.hitPoints must be >= 1');
    for (final id in skills.keys) {
      validateContentId(id);
    }
    for (final id in damageResistanceIds) {
      validateContentId(id);
    }
    for (final id in damageImmunityIds) {
      validateContentId(id);
    }
    for (final id in damageVulnerabilityIds) {
      validateContentId(id);
    }
    for (final id in conditionImmunityIds) {
      validateContentId(id);
    }
    for (final id in languageIds) {
      validateContentId(id);
    }
    return StatBlock._(
      sizeId: sizeId,
      typeId: typeId,
      alignmentId: alignmentId,
      armorClass: armorClass,
      hitPoints: hitPoints,
      hitPointsFormula: hitPointsFormula,
      speeds: speeds,
      abilities: abilities,
      savingThrows: Map.unmodifiable(savingThrows),
      skills: Map.unmodifiable(skills),
      damageResistanceIds: Set.unmodifiable(damageResistanceIds),
      damageImmunityIds: Set.unmodifiable(damageImmunityIds),
      damageVulnerabilityIds: Set.unmodifiable(damageVulnerabilityIds),
      conditionImmunityIds: Set.unmodifiable(conditionImmunityIds),
      senses: senses,
      languageIds: Set.unmodifiable(languageIds),
      cr: cr,
    );
  }
}
