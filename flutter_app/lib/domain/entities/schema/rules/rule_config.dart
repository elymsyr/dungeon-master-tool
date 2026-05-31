/// Template-scoped, editable numeric rules that were previously hardcoded in
/// the resolver and the level-up planner: the proficiency-bonus progression,
/// the hit-die→HP table, the ASI/feat levels, and the Armor Class constants.
///
/// [dnd5eDefaults] reproduces the exact values that were hardcoded, so a world
/// with no override resolves byte-identically. A world only diverges when a DM
/// writes `metadata['rule_config']` (see `ruleConfigProvider`) — which is also
/// the correct moment for the template content-hash to change.
///
/// Threaded as a plain value param (never looked up inside the resolver hot
/// loop) and value-equal (`==`/`hashCode`) so an unchanged config does not
/// cascade provider rebuilds.
library;

class RuleConfig {
  /// Levels at which an Ability Score Improvement / feat is granted.
  final List<int> asiLevels;

  /// Hit-die string → fixed HP gained per level after L1 (average rounded up).
  final Map<String, int> hitDieToHp;

  /// Unarmored AC base (SRD: 10).
  final int acUnarmoredBase;

  /// Flat AC granted by an equipped shield (SRD: +2).
  final int acShieldBonus;

  /// Levels at which proficiency bonus increases by 1 over the base of +2.
  final List<int> proficiencyBonusBreakpoints;

  const RuleConfig({
    required this.asiLevels,
    required this.hitDieToHp,
    required this.acUnarmoredBase,
    required this.acShieldBonus,
    required this.proficiencyBonusBreakpoints,
  });

  /// The exact values previously hardcoded across `character_resolver`,
  /// `level_up_planner` and `dnd5e_constants`.
  static const RuleConfig dnd5eDefaults = RuleConfig(
    asiLevels: [4, 8, 12, 16, 19],
    hitDieToHp: {'d6': 4, 'd8': 5, 'd10': 6, 'd12': 7},
    acUnarmoredBase: 10,
    acShieldBonus: 2,
    proficiencyBonusBreakpoints: [5, 9, 13, 17],
  );

  /// SRD §1 proficiency bonus by level (2 → 6).
  int proficiencyBonusFor(int level) {
    var pb = 2;
    for (final b in proficiencyBonusBreakpoints) {
      if (level >= b) pb++;
    }
    return pb;
  }

  /// Fixed HP per level after L1 for a hit die; 0 for unknown/malformed input.
  int hpPerLevelFor(String? hitDie) => hitDieToHp[hitDie] ?? 0;

  bool isAsiLevel(int level) => asiLevels.contains(level);

  /// `ability_mod = floor((score - 10) / 2)`.
  int abilityModifier(int score) => ((score - 10) / 2).floor();

  Map<String, dynamic> toJson() => {
        'asi_levels': asiLevels,
        'hit_die_to_hp': hitDieToHp,
        'ac_unarmored_base': acUnarmoredBase,
        'ac_shield_bonus': acShieldBonus,
        'proficiency_bonus_breakpoints': proficiencyBonusBreakpoints,
      };

  /// Lenient parse — any missing/malformed key falls back to [base].
  factory RuleConfig.fromJson(Map<String, dynamic> json,
      {RuleConfig base = dnd5eDefaults}) {
    List<int> ints(Object? v, List<int> fb) =>
        v is List ? v.whereType<num>().map((e) => e.toInt()).toList() : fb;
    int int_(Object? v, int fb) => v is num ? v.toInt() : fb;
    return RuleConfig(
      asiLevels: ints(json['asi_levels'], base.asiLevels),
      hitDieToHp: json['hit_die_to_hp'] is Map
          ? {
              for (final e in (json['hit_die_to_hp'] as Map).entries)
                e.key.toString():
                    (e.value is num) ? (e.value as num).toInt() : 0,
            }
          : base.hitDieToHp,
      acUnarmoredBase: int_(json['ac_unarmored_base'], base.acUnarmoredBase),
      acShieldBonus: int_(json['ac_shield_bonus'], base.acShieldBonus),
      proficiencyBonusBreakpoints: ints(
          json['proficiency_bonus_breakpoints'],
          base.proficiencyBonusBreakpoints),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleConfig &&
          _listEq(asiLevels, other.asiLevels) &&
          _mapEq(hitDieToHp, other.hitDieToHp) &&
          acUnarmoredBase == other.acUnarmoredBase &&
          acShieldBonus == other.acShieldBonus &&
          _listEq(proficiencyBonusBreakpoints, other.proficiencyBonusBreakpoints);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(asiLevels),
        Object.hashAll(hitDieToHp.keys),
        Object.hashAll(hitDieToHp.values),
        acUnarmoredBase,
        acShieldBonus,
        Object.hashAll(proficiencyBonusBreakpoints),
      );
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
