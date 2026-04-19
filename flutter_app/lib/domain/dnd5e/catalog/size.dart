import 'content_reference.dart';

/// Tier 1: creature size category. [spaceFt] is the square side the creature
/// occupies (Medium = 5, Large = 10, ...). [tokenScale] is a map-space multiplier
/// relative to a 1×1 Medium token; useful for battlemap rendering.
class Size {
  final String id;
  final String name;
  final double spaceFt;
  final double tokenScale;

  const Size._(this.id, this.name, this.spaceFt, this.tokenScale);

  factory Size({
    required String id,
    required String name,
    required double spaceFt,
    required double tokenScale,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Size name must not be empty');
    if (spaceFt <= 0) throw ArgumentError('Size.spaceFt must be > 0');
    if (tokenScale <= 0) throw ArgumentError('Size.tokenScale must be > 0');
    return Size._(id, name, spaceFt, tokenScale);
  }

  Size copyWith({String? id, String? name, double? spaceFt, double? tokenScale}) =>
      Size(
        id: id ?? this.id,
        name: name ?? this.name,
        spaceFt: spaceFt ?? this.spaceFt,
        tokenScale: tokenScale ?? this.tokenScale,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Size && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Size($id)';
}
