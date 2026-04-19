import '../catalog/content_reference.dart';
import '../catalog/size.dart';
import '../effect/effect_descriptor.dart';

/// Tier 1: species (Dragonborn, Elf, Human, ...). [sizeId] references the
/// catalog Size; [baseSpeedFt] is the walking speed granted at level 1; [effects]
/// cover darkvision, resistances, save advantages, bonus languages, etc.
class Species {
  final String id;
  final String name;
  final String sizeId;
  final int baseSpeedFt;
  final List<EffectDescriptor> effects;
  final String description;

  Species._(this.id, this.name, this.sizeId, this.baseSpeedFt, this.effects,
      this.description);

  factory Species({
    required String id,
    required String name,
    required ContentReference<Size> sizeId,
    required int baseSpeedFt,
    List<EffectDescriptor> effects = const [],
    String description = '',
  }) {
    validateContentId(id);
    validateContentId(sizeId);
    if (name.isEmpty) throw ArgumentError('Species.name must not be empty');
    if (baseSpeedFt < 0) {
      throw ArgumentError('Species.baseSpeedFt must be >= 0');
    }
    return Species._(
      id,
      name,
      sizeId,
      baseSpeedFt,
      List.unmodifiable(effects),
      description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Species && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Species($id)';
}
