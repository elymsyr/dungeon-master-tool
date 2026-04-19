import 'content_reference.dart';

/// Two structural axes the SRD recognises for alignment. Tier 0 — engine reads
/// the enums, names are cosmetic.
enum LawChaosAxis { lawful, neutral, chaotic, unaligned }

enum GoodEvilAxis { good, neutral, evil, unaligned }

/// Tier 1: alignment instance. The axis values are Tier 0 so rules like
/// "detect evil" key off [goodEvil], not the id.
class Alignment {
  final String id;
  final String name;
  final LawChaosAxis lawChaos;
  final GoodEvilAxis goodEvil;

  const Alignment._(this.id, this.name, this.lawChaos, this.goodEvil);

  factory Alignment({
    required String id,
    required String name,
    required LawChaosAxis lawChaos,
    required GoodEvilAxis goodEvil,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Alignment name must not be empty');
    return Alignment._(id, name, lawChaos, goodEvil);
  }

  Alignment copyWith({
    String? id,
    String? name,
    LawChaosAxis? lawChaos,
    GoodEvilAxis? goodEvil,
  }) =>
      Alignment(
        id: id ?? this.id,
        name: name ?? this.name,
        lawChaos: lawChaos ?? this.lawChaos,
        goodEvil: goodEvil ?? this.goodEvil,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Alignment && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Alignment($id)';
}
