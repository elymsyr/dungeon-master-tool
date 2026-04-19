import 'content_reference.dart';

/// Tier 1: named language (Common, Dwarvish, Infernal, ...). [script] is the
/// writing system ("Dethek", "Infernal", ...) when the language is written;
/// null for purely spoken/telepathic langs (e.g. Druidic sign speech).
class Language {
  final String id;
  final String name;
  final String? script;

  const Language._(this.id, this.name, this.script);

  factory Language({
    required String id,
    required String name,
    String? script,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Language name must not be empty');
    if (script != null && script.isEmpty) {
      throw ArgumentError('Language.script, when given, must not be empty');
    }
    return Language._(id, name, script);
  }

  Language copyWith({String? id, String? name, String? script}) => Language(
        id: id ?? this.id,
        name: name ?? this.name,
        script: script ?? this.script,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Language && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Language($id)';
}
