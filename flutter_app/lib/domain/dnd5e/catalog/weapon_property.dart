import 'content_reference.dart';
import 'weapon_property_flag.dart';

/// Tier 1: weapon property like Finesse, Heavy, Versatile. The id is namespaced;
/// [flags] carry the Tier 0 engine-semantics (see [PropertyFlag]).
class WeaponProperty {
  final String id;
  final String name;
  final Set<PropertyFlag> flags;
  final String? description;

  const WeaponProperty._(this.id, this.name, this.flags, this.description);

  factory WeaponProperty({
    required String id,
    required String name,
    Set<PropertyFlag> flags = const {},
    String? description,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('WeaponProperty name must not be empty');
    return WeaponProperty._(
        id, name, Set.unmodifiable(flags), description);
  }

  bool hasFlag(PropertyFlag f) => flags.contains(f);

  WeaponProperty copyWith({
    String? id,
    String? name,
    Set<PropertyFlag>? flags,
    String? description,
  }) =>
      WeaponProperty(
        id: id ?? this.id,
        name: name ?? this.name,
        flags: flags ?? this.flags,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WeaponProperty && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WeaponProperty($id)';
}
