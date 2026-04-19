import '../catalog/content_reference.dart';
import '../effect/effect_descriptor.dart';
import 'species.dart';

/// Tier 1: lineage (sub-species) — High Elf, Forest Gnome, Hill Dwarf.
/// Parented to a [Species] via [parentSpeciesId]. Engine merges parent species
/// effects + lineage effects at character build time.
class Lineage {
  final String id;
  final String name;
  final String parentSpeciesId;
  final List<EffectDescriptor> effects;
  final String description;

  Lineage._(this.id, this.name, this.parentSpeciesId, this.effects,
      this.description);

  factory Lineage({
    required String id,
    required String name,
    required ContentReference<Species> parentSpeciesId,
    List<EffectDescriptor> effects = const [],
    String description = '',
  }) {
    validateContentId(id);
    validateContentId(parentSpeciesId);
    if (name.isEmpty) throw ArgumentError('Lineage.name must not be empty');
    return Lineage._(
      id,
      name,
      parentSpeciesId,
      List.unmodifiable(effects),
      description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Lineage && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Lineage($id)';
}
