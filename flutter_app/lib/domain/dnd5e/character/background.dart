import '../catalog/content_reference.dart';
import '../effect/effect_descriptor.dart';

/// Tier 1: background (Acolyte, Criminal, ...). Grants proficiencies and a
/// starting feat (2024 SRD); represented as [EffectDescriptor]s so the build
/// pipeline applies them uniformly.
class Background {
  final String id;
  final String name;
  final List<EffectDescriptor> effects;
  final String description;

  Background._(this.id, this.name, this.effects, this.description);

  factory Background({
    required String id,
    required String name,
    List<EffectDescriptor> effects = const [],
    String description = '',
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Background.name must not be empty');
    return Background._(
      id,
      name,
      List.unmodifiable(effects),
      description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Background && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Background($id)';
}
