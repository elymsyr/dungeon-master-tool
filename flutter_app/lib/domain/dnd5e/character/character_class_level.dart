import '../catalog/content_reference.dart';

/// One multiclass entry. References a CharacterClass (and optionally Subclass)
/// by namespaced id and the number of levels taken in it.
class CharacterClassLevel {
  final String classId;
  final String? subclassId;
  final int level;

  const CharacterClassLevel._(this.classId, this.subclassId, this.level);

  factory CharacterClassLevel({
    required String classId,
    String? subclassId,
    required int level,
  }) {
    validateContentId(classId);
    if (subclassId != null) validateContentId(subclassId);
    if (level < 1 || level > 20) {
      throw ArgumentError('CharacterClassLevel.level must be in [1, 20]');
    }
    return CharacterClassLevel._(classId, subclassId, level);
  }

  CharacterClassLevel copyWith({String? classId, String? subclassId, int? level}) =>
      CharacterClassLevel(
        classId: classId ?? this.classId,
        subclassId: subclassId ?? this.subclassId,
        level: level ?? this.level,
      );

  @override
  bool operator ==(Object other) =>
      other is CharacterClassLevel &&
      other.classId == classId &&
      other.subclassId == subclassId &&
      other.level == level;

  @override
  int get hashCode => Object.hash(classId, subclassId, level);

  @override
  String toString() =>
      'CharacterClassLevel($classId${subclassId == null ? '' : '/$subclassId'} L$level)';
}
