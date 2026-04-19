import 'content_reference.dart';

/// Tier 1: magic-item rarity (Common, Uncommon, ..., Artifact). [sortOrder] gives
/// a stable rank across installed packages (lower = commoner). [attunementTierReq]
/// is the lowest character level at which a DM may reasonably hand out items of
/// this rarity — purely an advisory slot, engine does not enforce.
class Rarity {
  final String id;
  final String name;
  final int sortOrder;
  final int? attunementTierReq;

  const Rarity._(this.id, this.name, this.sortOrder, this.attunementTierReq);

  factory Rarity({
    required String id,
    required String name,
    required int sortOrder,
    int? attunementTierReq,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Rarity name must not be empty');
    if (attunementTierReq != null &&
        (attunementTierReq < 1 || attunementTierReq > 20)) {
      throw ArgumentError(
          'Rarity.attunementTierReq must be in [1, 20] (or null)');
    }
    return Rarity._(id, name, sortOrder, attunementTierReq);
  }

  Rarity copyWith({
    String? id,
    String? name,
    int? sortOrder,
    int? attunementTierReq,
  }) =>
      Rarity(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        attunementTierReq: attunementTierReq ?? this.attunementTierReq,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Rarity && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Rarity($id)';
}
