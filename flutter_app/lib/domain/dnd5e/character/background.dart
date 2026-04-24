import '../catalog/content_reference.dart';
import '../catalog/skill.dart';
import '../catalog/language.dart';
import '../effect/effect_descriptor.dart';

/// Tier 1: background (Acolyte, Criminal, ...). Grants proficiencies and a
/// starting feat (2024 SRD). Skill/tool/language proficiency grants live in
/// [effects] as `GrantProficiency` descriptors so the combat resolver and the
/// character builder both read a single source. First-class fields cover
/// grants that the effect DSL cannot represent cleanly (the starting feat is
/// a distinct game mechanic, starting equipment is state not a modifier).
class Background {
  final String id;
  final String name;
  final List<EffectDescriptor> effects;
  final ContentReference? grantedFeatId;
  final List<String> startingEquipmentIds;
  final String description;

  Background._(this.id, this.name, this.effects, this.grantedFeatId,
      this.startingEquipmentIds, this.description);

  factory Background({
    required String id,
    required String name,
    List<EffectDescriptor> effects = const [],
    ContentReference? grantedFeatId,
    List<String> startingEquipmentIds = const [],
    String description = '',
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Background.name must not be empty');
    if (grantedFeatId != null) validateContentId(grantedFeatId);
    for (final itemId in startingEquipmentIds) {
      validateContentId(itemId);
    }
    return Background._(
      id,
      name,
      List.unmodifiable(effects),
      grantedFeatId,
      List.unmodifiable(startingEquipmentIds),
      description,
    );
  }

  /// Skill proficiency ids derived from [effects]. Used by the character
  /// builder + card UI to render a dedicated "Skill Proficiencies" section
  /// without re-parsing the effect list at every call site.
  List<ContentReference<Skill>> get skillProficiencyIds =>
      _proficiencyIdsOfKind(ProficiencyKind.skill);

  List<String> get toolProficiencyIds =>
      _proficiencyIdsOfKind(ProficiencyKind.tool);

  List<ContentReference<Language>> get languageIds =>
      _proficiencyIdsOfKind(ProficiencyKind.language);

  List<String> _proficiencyIdsOfKind(ProficiencyKind kind) {
    final ids = <String>[];
    for (final e in effects) {
      if (e is GrantProficiency && e.kind == kind) {
        ids.add(e.targetId);
      }
    }
    return List.unmodifiable(ids);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Background && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Background($id)';
}
