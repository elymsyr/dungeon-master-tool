import 'content_reference.dart';

/// Tier 1: damage type (fire, piercing, radiant, ...). [physical] is true for
/// bludgeoning/piercing/slashing — relevant for the "nonmagical weapons" clause
/// of many resistance/immunity entries.
class DamageType {
  final String id;
  final String name;
  final bool physical;

  const DamageType._(this.id, this.name, this.physical);

  factory DamageType({
    required String id,
    required String name,
    bool physical = false,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('DamageType name must not be empty');
    return DamageType._(id, name, physical);
  }

  DamageType copyWith({String? id, String? name, bool? physical}) =>
      DamageType(
        id: id ?? this.id,
        name: name ?? this.name,
        physical: physical ?? this.physical,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DamageType && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DamageType($id)';
}
