import '../core/ability.dart';
import 'content_reference.dart';

/// Tier 1: a single skill. The governing [ability] is Tier 0 because the engine
/// keys off the enum (not the id) when computing modifiers and save-category
/// proficiencies.
class Skill {
  final String id;
  final String name;
  final Ability ability;

  const Skill._(this.id, this.name, this.ability);

  factory Skill({
    required String id,
    required String name,
    required Ability ability,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Skill name must not be empty');
    return Skill._(id, name, ability);
  }

  Skill copyWith({String? id, String? name, Ability? ability}) => Skill(
        id: id ?? this.id,
        name: name ?? this.name,
        ability: ability ?? this.ability,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Skill && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Skill($id)';
}
