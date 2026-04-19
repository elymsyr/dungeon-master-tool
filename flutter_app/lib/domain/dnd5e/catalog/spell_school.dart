import 'content_reference.dart';

/// Tier 1: spell school (abjuration, evocation, ...). [color] is an optional
/// hex string (e.g. '#FF5533') used purely for UI tinting.
class SpellSchool {
  final String id;
  final String name;
  final String? color;

  const SpellSchool._(this.id, this.name, this.color);

  factory SpellSchool({required String id, required String name, String? color}) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('SpellSchool name must not be empty');
    if (color != null && !_isHex(color)) {
      throw ArgumentError('SpellSchool.color must be a hex string like #RRGGBB');
    }
    return SpellSchool._(id, name, color);
  }

  static final _hexRe = RegExp(r'^#[0-9A-Fa-f]{6}$');
  static bool _isHex(String s) => _hexRe.hasMatch(s);

  SpellSchool copyWith({String? id, String? name, String? color}) => SpellSchool(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SpellSchool && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SpellSchool($id)';
}
