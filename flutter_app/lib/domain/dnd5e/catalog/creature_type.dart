import 'content_reference.dart';

/// Tier 1: creature type (humanoid, fiend, undead, ...). Pure Tier 1 — no
/// structural flags, engine checks id-equality for spell targeting etc.
class CreatureType {
  final String id;
  final String name;

  const CreatureType._(this.id, this.name);

  factory CreatureType({required String id, required String name}) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('CreatureType name must not be empty');
    return CreatureType._(id, name);
  }

  CreatureType copyWith({String? id, String? name}) =>
      CreatureType(id: id ?? this.id, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CreatureType && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CreatureType($id)';
}
