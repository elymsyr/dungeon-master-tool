import '../catalog/content_reference.dart';
import 'character_class.dart';

/// Tier 1: a subclass (archetype). Parented to one CharacterClass via
/// [parentClassId]. Subclass features slot into [featureTable] at the class's
/// subclass-feature levels (engine merges parent + subclass rows).
class Subclass {
  final String id;
  final String name;
  final String parentClassId;
  final List<ClassFeatureRow> featureTable;
  final String description;

  Subclass._(this.id, this.name, this.parentClassId, this.featureTable,
      this.description);

  factory Subclass({
    required String id,
    required String name,
    required String parentClassId,
    List<ClassFeatureRow> featureTable = const [],
    String description = '',
  }) {
    validateContentId(id);
    validateContentId(parentClassId);
    if (name.isEmpty) throw ArgumentError('Subclass.name must not be empty');
    return Subclass._(
      id,
      name,
      parentClassId,
      List.unmodifiable(featureTable),
      description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Subclass && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Subclass($id)';
}
