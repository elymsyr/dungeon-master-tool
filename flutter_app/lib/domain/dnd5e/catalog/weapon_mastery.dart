import 'content_reference.dart';

/// Tier 1: weapon mastery property (2024 PHB) — Cleave, Graze, Nick, Push, ...
/// Behavior lives in attached [EffectDescriptor]s at the Weapon level; here we
/// only carry the catalog entry.
class WeaponMastery {
  final String id;
  final String name;
  final String description;

  const WeaponMastery._(this.id, this.name, this.description);

  factory WeaponMastery({
    required String id,
    required String name,
    String description = '',
  }) {
    validateContentId(id);
    if (name.isEmpty) {
      throw ArgumentError('WeaponMastery name must not be empty');
    }
    return WeaponMastery._(id, name, description);
  }

  WeaponMastery copyWith({String? id, String? name, String? description}) =>
      WeaponMastery(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WeaponMastery && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WeaponMastery($id)';
}
