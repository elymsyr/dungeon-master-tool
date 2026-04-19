/// Six D&D 5e ability scores. Tier 0 — structural primitive.
enum Ability {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma;

  /// Three-letter uppercase label per SRD (STR/DEX/CON/INT/WIS/CHA).
  String get short => switch (this) {
        strength => 'STR',
        dexterity => 'DEX',
        constitution => 'CON',
        intelligence => 'INT',
        wisdom => 'WIS',
        charisma => 'CHA',
      };

  String get label => switch (this) {
        strength => 'Strength',
        dexterity => 'Dexterity',
        constitution => 'Constitution',
        intelligence => 'Intelligence',
        wisdom => 'Wisdom',
        charisma => 'Charisma',
      };

  static Ability fromShort(String short) {
    for (final a in Ability.values) {
      if (a.short == short.toUpperCase()) return a;
    }
    throw ArgumentError('Unknown Ability short code: "$short"');
  }
}
