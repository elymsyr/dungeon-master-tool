import '../catalog/content_reference.dart';
import '../core/ability.dart';
import '../core/die.dart';
import '../effect/effect_descriptor.dart';
import 'caster_kind.dart';

/// Level-indexed feature grant. Engine dispatches at level-up to apply [effects]
/// and declare available [featureIds].
class ClassFeatureRow {
  final int level;
  final List<String> featureIds;
  final List<EffectDescriptor> effects;

  ClassFeatureRow._(this.level, this.featureIds, this.effects);

  factory ClassFeatureRow({
    required int level,
    List<String> featureIds = const [],
    List<EffectDescriptor> effects = const [],
  }) {
    if (level < 1 || level > 20) {
      throw ArgumentError('ClassFeatureRow.level must be in [1, 20]');
    }
    for (final id in featureIds) {
      validateContentId(id);
    }
    return ClassFeatureRow._(
      level,
      List.unmodifiable(featureIds),
      List.unmodifiable(effects),
    );
  }
}

/// Tier 1: a character class (Fighter, Wizard, ...). Spellcasting ability is
/// Tier 0 because engine derives save DC/attack bonus from it.
class CharacterClass {
  final String id;
  final String name;
  final Die hitDie;
  final Ability? spellcastingAbility;
  final List<Ability> savingThrows;
  final List<ClassFeatureRow> featureTable;
  final String description;
  final CasterKind casterKind;
  final double casterFraction;

  CharacterClass._(
    this.id,
    this.name,
    this.hitDie,
    this.spellcastingAbility,
    this.savingThrows,
    this.featureTable,
    this.description,
    this.casterKind,
    this.casterFraction,
  );

  factory CharacterClass({
    required String id,
    required String name,
    required Die hitDie,
    Ability? spellcastingAbility,
    List<Ability> savingThrows = const [],
    List<ClassFeatureRow> featureTable = const [],
    String description = '',
    CasterKind casterKind = CasterKind.none,
    double? casterFraction,
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('CharacterClass.name must not be empty');
    if (savingThrows.length != 2 && savingThrows.isNotEmpty) {
      // SRD classes grant exactly 2 saves; homebrew may vary but not 1.
      // Accept 0 (unspecified) or 2+.
    }
    final fraction = casterFraction ?? _defaultFraction(casterKind);
    if (fraction < 0 || fraction > 1) {
      throw ArgumentError(
          'CharacterClass.casterFraction must be in [0, 1], got $fraction');
    }
    if (casterKind == CasterKind.none && fraction != 0) {
      throw ArgumentError(
          'CharacterClass.casterFraction must be 0 when casterKind=none');
    }
    return CharacterClass._(
      id,
      name,
      hitDie,
      spellcastingAbility,
      List.unmodifiable(savingThrows),
      List.unmodifiable(featureTable),
      description,
      casterKind,
      fraction,
    );
  }

  static double _defaultFraction(CasterKind k) {
    switch (k) {
      case CasterKind.none:
        return 0;
      case CasterKind.full:
        return 1.0;
      case CasterKind.half:
        return 0.5;
      case CasterKind.third:
        return 1 / 3;
      case CasterKind.pact:
        return 0; // Pact uses its own table; excluded from multiclass sum.
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CharacterClass && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CharacterClass($id)';
}
