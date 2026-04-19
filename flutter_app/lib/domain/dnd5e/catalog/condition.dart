import '../effect/effect_descriptor.dart';
import 'content_reference.dart';

/// Tier 1: named condition (stunned, prone, frightened, ...). Engine reads
/// [effects] — typically one [EffectDescriptor] of case `ConditionInteraction`
/// plus any rider effects (e.g. attacks against this creature have advantage).
class Condition {
  final String id;
  final String name;
  final String description;
  final List<EffectDescriptor> effects;

  const Condition._(this.id, this.name, this.description, this.effects);

  factory Condition({
    required String id,
    required String name,
    String description = '',
    List<EffectDescriptor> effects = const [],
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Condition name must not be empty');
    return Condition._(id, name, description, List.unmodifiable(effects));
  }

  Condition copyWith({
    String? id,
    String? name,
    String? description,
    List<EffectDescriptor>? effects,
  }) =>
      Condition(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        effects: effects ?? this.effects,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Condition && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Condition($id)';
}
