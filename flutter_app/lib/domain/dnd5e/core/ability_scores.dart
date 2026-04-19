import 'ability.dart';
import 'ability_score.dart';

/// Full 6-ability snapshot for a creature. Tier 0 — structural.
class AbilityScores {
  final AbilityScore str;
  final AbilityScore dex;
  final AbilityScore con;
  final AbilityScore int_;
  final AbilityScore wis;
  final AbilityScore cha;

  const AbilityScores({
    required this.str,
    required this.dex,
    required this.con,
    required this.int_,
    required this.wis,
    required this.cha,
  });

  /// All tens — D&D 5e "commoner" baseline.
  factory AbilityScores.allTens() => AbilityScores(
        str: AbilityScore(10),
        dex: AbilityScore(10),
        con: AbilityScore(10),
        int_: AbilityScore(10),
        wis: AbilityScore(10),
        cha: AbilityScore(10),
      );

  AbilityScore byAbility(Ability a) => switch (a) {
        Ability.strength => str,
        Ability.dexterity => dex,
        Ability.constitution => con,
        Ability.intelligence => int_,
        Ability.wisdom => wis,
        Ability.charisma => cha,
      };

  /// Returns a new [AbilityScores] with [a] adjusted by [delta]. Clamps to
  /// the legal [1, 30] range; throws if the result would be invalid only
  /// when [delta] is so large it escapes even after clamping (never).
  AbilityScores withBonus(Ability a, int delta) {
    final current = byAbility(a).value;
    final raw = current + delta;
    final clamped = raw.clamp(1, 30);
    return _replace(a, AbilityScore(clamped));
  }

  AbilityScores _replace(Ability a, AbilityScore v) => switch (a) {
        Ability.strength => copyWith(str: v),
        Ability.dexterity => copyWith(dex: v),
        Ability.constitution => copyWith(con: v),
        Ability.intelligence => copyWith(int_: v),
        Ability.wisdom => copyWith(wis: v),
        Ability.charisma => copyWith(cha: v),
      };

  AbilityScores copyWith({
    AbilityScore? str,
    AbilityScore? dex,
    AbilityScore? con,
    AbilityScore? int_,
    AbilityScore? wis,
    AbilityScore? cha,
  }) =>
      AbilityScores(
        str: str ?? this.str,
        dex: dex ?? this.dex,
        con: con ?? this.con,
        int_: int_ ?? this.int_,
        wis: wis ?? this.wis,
        cha: cha ?? this.cha,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbilityScores &&
          other.str == str &&
          other.dex == dex &&
          other.con == con &&
          other.int_ == int_ &&
          other.wis == wis &&
          other.cha == cha;

  @override
  int get hashCode => Object.hash(str, dex, con, int_, wis, cha);
}
