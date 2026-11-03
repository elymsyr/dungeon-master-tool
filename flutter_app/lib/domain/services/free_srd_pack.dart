import '../entities/entity.dart';
import '../entities/schema/entity_category_schema.dart';
import '../entities/schema/field_schema.dart';
import 'entity_ref.dart';
import 'free_field_styles.dart';
import 'free_template.dart' show srdFreeTemplate;

/// The free SRD package's data (docs/free-template/SRD-FREE-ALANLAR.md §8):
/// the core pack's cards in [srdFreeTemplate]'s shape, built once when the
/// package is seeded, so the package needs no read-time conversion. The
/// core pack itself never changes (ROADMAP K1).

/// Bumped whenever [freeSrdFields] writes something new: the free package
/// re-seeds on a change (`SrdCorePackageBootstrap._ensureFree`).
const freeSrdPackVersion = 2;

/// The categories finished so far (SRD-FREE-ALANLAR §11): their cards hold
/// only the copy's fields and no description of their own (S1). One more
/// with each phase; A10 closes them all.
const freeSrdClosed = {'spell'};

final Map<String, EntityCategorySchema> _categories = {
  for (final c in srdFreeTemplate.categories) c.slug: c,
};

/// Whether the free package carries [slug]'s cards: the copy drops some
/// categories (§5.14).
bool inFreeSrd(String slug) => _categories.containsKey(slug);

/// [card]'s fields as the free template shows them: what
/// `freeFieldValue` reads out of the SRD shapes (Level tables, Grants,
/// the Combat stats block) and the SRD lists a markdown field shows as
/// text, written into the data (A1); a closed category's lines in the
/// SRD's own words, and nothing the copy does not declare. An SRD value
/// that reads as nothing (a level-bound pool, granted from the class rows)
/// is emptied, not left in its SRD shape. [byId] holds every pack card.
/// Refs and `_lookup` placeholders stay; the world resolves them when it
/// synthesises the card.
Map<String, dynamic> freeSrdFields(Entity card, Map<String, Entity> byId) {
  final cat = _categories[card.categorySlug];
  if (cat == null) return card.fields;
  final closed = freeSrdClosed.contains(card.categorySlug);
  final src = {
    ...card.fields,
    if (card.categorySlug == 'spell') ..._spellLines(card.fields, byId),
  };
  final out = closed
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(card.fields);
  for (final f in cat.fields) {
    var v = freeFieldValue(f, src, byId: byId);
    if (f.fieldType == FieldType.markdown && v is List) {
      v = structuredListAsMarkdown(v, (r) => entityRefName(r, byId));
    }
    if (!_blank(v) || !_blank(out[f.fieldKey])) out[f.fieldKey] = v;
  }
  return out;
}

/// [card]'s description in the free package. A closed category's rules
/// text is its own text field, so the description above it goes (S1).
String freeSrdDescription(Entity card) =>
    freeSrdClosed.contains(card.categorySlug) ? '' : card.description;

/// A spell's header lines as the SRD writes them (§5.1): "1 minute or
/// Ritual", "150 feet", "V, S, M (a diamond worth 500+ GP, which the spell
/// consumes)", "Concentration, up to 1 minute".
Map<String, String> _spellLines(
  Map<String, dynamic> f,
  Map<String, Entity> byId,
) {
  String name(Object? r) => entityRefName(r, byId);

  final castUnit = name(f['casting_time_unit_ref']);
  var cast = castUnit == 'Minute' || castUnit == 'Hour'
      ? _count(f['casting_time_amount'] as num? ?? 1, castUnit)
      : castUnit;
  if (f['reaction_trigger'] case final String t when t.isNotEmpty) {
    cast += ', which you take ${_lower(t).replaceFirst(RegExp(r'\.$'), '')}';
  }
  if (f['is_ritual'] == true) cast += ' or Ritual';

  final range = switch ((f['range_type'], f['range_ft'])) {
    ('Ranged', final num ft) => '${_num(ft)} feet',
    // The builder stores a range it cannot type ("Special") as bare Ranged.
    ('Ranged', _) => 'Special',
    (final String t, _) => t,
    _ => '',
  };

  var material = _lower(f['material_description'] as String? ?? '');
  if (material.isNotEmpty) {
    // Find Familiar's 10 GP is in no text.
    final gp = f['material_cost_gp'];
    if (gp is num && !material.contains('GP')) {
      material += ', worth ${_num(gp)}+ GP';
    }
    if (f['material_consumed'] == true && !material.contains('consume')) {
      material += ', which the spell consumes';
    }
  }
  const abbrev = {'Verbal': 'V', 'Somatic': 'S', 'Material': 'M'};
  final components = [
    for (final c in f['components'] as List? ?? const [])
      switch (abbrev[name(c)] ?? name(c)) {
        'M' when material.isNotEmpty => 'M ($material)',
        final a => a,
      },
  ].join(', ');

  final durUnit = name(f['duration_unit_ref']);
  var duration = switch (f['duration_amount']) {
    final num n => _count(n, durUnit),
    _ => durUnit == 'Until Dispelled' ? 'Until dispelled' : durUnit,
  };
  if (f['requires_concentration'] == true) {
    duration = 'Concentration, up to $duration';
  }

  return {
    'casting_time': cast,
    'range': range,
    'components': components,
    'duration': duration,
  };
}

/// "1 minute", "10 minutes" from a unit name either way ("Minute",
/// "Minutes").
String _count(num n, String unit) =>
    '${_num(n)} ${unit.toLowerCase().replaceFirst(RegExp(r's$'), '')}'
    '${n == 1 ? '' : 's'}';

/// The SRD's numbers: "1,000".
String _num(num n) =>
    '$n'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

String _lower(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

bool _blank(Object? v) =>
    v == null ||
    (v is String && v.isEmpty) ||
    (v is List && v.isEmpty) ||
    (v is Map && v.isEmpty);
