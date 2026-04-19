import '../catalog/content_reference.dart';
import '../core/spell_level.dart';
import '../effect/effect_descriptor.dart';
import 'area_of_effect.dart';
import 'casting_time.dart';
import 'spell_components.dart';
import 'spell_duration.dart';
import 'spell_range.dart';
import 'spell_target.dart';

/// Tier 1: immutable spell definition. Behavior lives in [effects] (Tier 2);
/// text, geometry, components are display/targeting metadata.
class Spell {
  final String id;
  final String name;
  final SpellLevel level;
  final String schoolId;
  final CastingTime castingTime;
  final SpellRange range;
  final List<SpellComponent> components;
  final SpellDuration duration;
  final List<SpellTarget> targets;
  final AreaOfEffect? area;
  final List<EffectDescriptor> effects;
  final bool ritual;
  final List<String> classListIds;
  final String description;

  Spell._({
    required this.id,
    required this.name,
    required this.level,
    required this.schoolId,
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.targets,
    required this.area,
    required this.effects,
    required this.ritual,
    required this.classListIds,
    required this.description,
  });

  factory Spell({
    required String id,
    required String name,
    required SpellLevel level,
    required ContentReference schoolId,
    required CastingTime castingTime,
    required SpellRange range,
    required List<SpellComponent> components,
    required SpellDuration duration,
    List<SpellTarget> targets = const [],
    AreaOfEffect? area,
    List<EffectDescriptor> effects = const [],
    bool ritual = false,
    List<ContentReference> classListIds = const [],
    String description = '',
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Spell.name must not be empty');
    validateContentId(schoolId);
    for (final cid in classListIds) {
      validateContentId(cid);
    }
    return Spell._(
      id: id,
      name: name,
      level: level,
      schoolId: schoolId,
      castingTime: castingTime,
      range: range,
      components: List.unmodifiable(components),
      duration: duration,
      targets: List.unmodifiable(targets),
      area: area,
      effects: List.unmodifiable(effects),
      ritual: ritual,
      classListIds: List.unmodifiable(classListIds),
      description: description,
    );
  }

  bool get isCantrip => level.isCantrip;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Spell && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Spell($id, L${level.value})';
}
