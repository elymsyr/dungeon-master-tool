import '../catalog/content_reference.dart';
import '../effect/effect_descriptor.dart';

/// 2024 SRD feat category.
enum FeatCategory { origin, general, fightingStyle, epicBoon }

/// Tier 1: feat. [repeatable] matches the SRD "Repeatable: Yes" clause.
/// [prerequisite] is a short free-form string for UI display; machine-checked
/// prerequisites live in [effects] (e.g. a ModifyAttackRoll with a Predicate
/// guards their application).
class Feat {
  final String id;
  final String name;
  final FeatCategory category;
  final bool repeatable;
  final String? prerequisite;
  final List<EffectDescriptor> effects;
  final String description;

  Feat._(this.id, this.name, this.category, this.repeatable, this.prerequisite,
      this.effects, this.description);

  factory Feat({
    required String id,
    required String name,
    required FeatCategory category,
    bool repeatable = false,
    String? prerequisite,
    List<EffectDescriptor> effects = const [],
    String description = '',
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Feat.name must not be empty');
    return Feat._(
      id,
      name,
      category,
      repeatable,
      prerequisite,
      List.unmodifiable(effects),
      description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Feat && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Feat($id)';
}
