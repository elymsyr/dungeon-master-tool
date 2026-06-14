/// AspectContext — the v3 template aspect map (SHADOW).
///
/// Roadmap PR-T7 / PR-2.4 (slice 2). Builds the read-only **aspect context**
/// described in docs/new_system/the-template-system.md §4.3: a flat
/// `name → number` map derived from the PC card's own fields, against which a
/// rule's `field` / `formula` value source is evaluated (§4.2). It is the
/// resolver's view of "the current character" — the inputs a derivation reads.
///
/// **Authority status — SHADOW ONLY.** Nothing in the live app builds or reads
/// this yet; it is exercised only by `tool/template_rule_resolver_harness.dart`.
/// The old hardcoded engine (`character_resolver.dart`) stays authoritative
/// until the Phase 3.11 flip.
///
/// **Sources (§4.3), all from the PC card:**
///   * each `abilityScoreTable` with `publishAspects: true` exports `<col>` and
///     `<col>_mod` (modifier = `floor((score − base) / step)`);
///   * each `combatStatsTable` exports `level`, `ac`, `max_hp`;
///   * a plain `integer` field opts in via `typeConfig.publishAspect: "<name>"`;
///   * computed `class_level(<slug>)` per class, supplied by the caller (which
///     has the entity table needed to map a stored class id → its slug).
///
/// This slice only *builds* the context; the `formula` value source that
/// consumes the full map lands in slice 3 with `formula_evaluator.dart`. The
/// `field` source (slice 2) reads a stored field value directly, not an aspect.
library;

import '../../entities/schema/entity_category_schema.dart';
import '../../entities/schema/field_schema.dart';

/// An immutable `aspectName → number` lookup (the-template-system.md §4.3).
class AspectContext {
  /// The resolved aspect values (e.g. `{'dex_mod': 2, 'level': 5, 'ac': 17}`).
  final Map<String, num> aspects;

  const AspectContext(this.aspects);

  /// An empty context — the default when no PC card is supplied (e.g. folding a
  /// standalone attachment set in a test).
  static const AspectContext empty = AspectContext(<String, num>{});

  /// The value of [name], or null when the aspect is not published.
  num? operator [](String name) => aspects[name];

  /// The value of [name], or 0 when absent (the formula-eval default in §4.3).
  num value(String name) => aspects[name] ?? 0;

  /// Whether [name] is a published aspect.
  bool has(String name) => aspects.containsKey(name);

  bool get isEmpty => aspects.isEmpty;

  /// Build the aspect map from the PC card's [pcCategory] schema + stored
  /// [values] (keyed by [FieldSchema.fieldKey]).
  ///
  /// [classLevelsBySlug] is the per-class level map already resolved to slugs by
  /// the caller — it becomes `class_level(<slug>)` aspects. (The stored
  /// `class_levels` field is keyed by class *entity id*; only the caller has the
  /// entity table to map id → slug, so the context takes the resolved form.)
  factory AspectContext.fromPcCard({
    required EntityCategorySchema pcCategory,
    required Map<String, dynamic> values,
    Map<String, int> classLevelsBySlug = const <String, int>{},
  }) {
    final out = <String, num>{};

    for (final field in pcCategory.fields) {
      switch (field.fieldType) {
        case FieldType.abilityScoreTable:
          _publishAbilityScores(field, values[field.fieldKey], out);
        case FieldType.combatStatsTable:
          _publishCombatStats(values[field.fieldKey], out);
        case FieldType.integer:
          _publishIntegerOptIn(field, values[field.fieldKey], out);
        default:
          break;
      }
    }

    classLevelsBySlug.forEach((slug, level) {
      final s = slug.trim();
      if (s.isNotEmpty) out['class_level($s)'] = level;
    });

    return AspectContext(out);
  }

  /// `abilityScoreTable`: for every configured column, publish `<key>` (the raw
  /// score) and `<key>_mod` (`floor((score − base) / step)`). Only when the
  /// field opts in with `publishAspects: true` (§4.3). Aspect names use the
  /// column key **verbatim** — the same string a formula must reference.
  static void _publishAbilityScores(
    FieldSchema field,
    dynamic value,
    Map<String, num> out,
  ) {
    final cfg = field.typeConfig;
    if (cfg == null || cfg['publishAspects'] != true) return;
    if (value is! Map) return;

    final base = _numOr(cfg['modifierBase'], 10).toInt();
    final stepRaw = _numOr(cfg['modifierStep'], 2).toInt();
    final step = stepRaw == 0 ? 1 : stepRaw; // guard div-by-zero

    final columns = cfg['columns'];
    if (columns is! List) return;

    for (final col in columns) {
      if (col is! Map) continue;
      final key = (col['key'] as String?)?.trim();
      if (key == null || key.isEmpty) continue;
      final score = _num(value[key]);
      if (score == null) continue;
      out[key] = score;
      out['${key}_mod'] = _floorDiv(score.toInt() - base, step);
    }
  }

  /// `combatStatsTable`: publish exactly the three canonical aspects the doc
  /// names — `level`, `ac`, `max_hp` (the-template-system.md §4.3 / §3).
  static void _publishCombatStats(dynamic value, Map<String, num> out) {
    if (value is! Map) return;
    for (final key in const ['level', 'ac', 'max_hp']) {
      final n = _num(value[key]);
      if (n != null) out[key] = n;
    }
  }

  /// A plain `integer` field opts a single aspect in via
  /// `typeConfig.publishAspect: "<name>"` (e.g. `prof_bonus`).
  static void _publishIntegerOptIn(
    FieldSchema field,
    dynamic value,
    Map<String, num> out,
  ) {
    final name = (field.typeConfig?['publishAspect'] as String?)?.trim();
    if (name == null || name.isEmpty) return;
    final n = _num(value);
    if (n != null) out[name] = n;
  }

  /// Floor division that rounds toward negative infinity (so a sub-base score
  /// like 9 → `floor((9−10)/2) = −1`, matching §4.3's `floor()`). Dart's `~/`
  /// truncates toward zero, which would give 0 here.
  static int _floorDiv(int a, int b) {
    final q = a ~/ b;
    if ((a % b != 0) && ((a < 0) != (b < 0))) return q - 1;
    return q;
  }

  static num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  static num _numOr(dynamic v, num fallback) => _num(v) ?? fallback;
}
