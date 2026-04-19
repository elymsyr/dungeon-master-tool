import 'content_reference.dart';

/// Tier 1: armor category (Light, Medium, Heavy, Shield). Structural flags —
/// [stealthDisadvantage] and [maxDexCap] — are the behaviors the engine reads.
/// [maxDexCap] null means "no cap" (Light armor); 0 means "Dex does not
/// contribute" (Heavy armor).
class ArmorCategory {
  final String id;
  final String name;
  final bool stealthDisadvantage;
  final int? maxDexCap;

  const ArmorCategory._(
      this.id, this.name, this.stealthDisadvantage, this.maxDexCap);

  factory ArmorCategory({
    required String id,
    required String name,
    bool stealthDisadvantage = false,
    int? maxDexCap,
  }) {
    validateContentId(id);
    if (name.isEmpty) {
      throw ArgumentError('ArmorCategory name must not be empty');
    }
    if (maxDexCap != null && maxDexCap < 0) {
      throw ArgumentError('ArmorCategory.maxDexCap must be >= 0 (or null)');
    }
    return ArmorCategory._(id, name, stealthDisadvantage, maxDexCap);
  }

  ArmorCategory copyWith({
    String? id,
    String? name,
    bool? stealthDisadvantage,
    int? maxDexCap,
  }) =>
      ArmorCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        stealthDisadvantage: stealthDisadvantage ?? this.stealthDisadvantage,
        maxDexCap: maxDexCap ?? this.maxDexCap,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ArmorCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ArmorCategory($id)';
}
