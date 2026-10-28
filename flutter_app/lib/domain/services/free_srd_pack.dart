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
const freeSrdPackVersion = 1;

final Map<String, EntityCategorySchema> _categories = {
  for (final c in srdFreeTemplate.categories) c.slug: c,
};

/// [card]'s fields as the free template shows them: what
/// `freeFieldValue` reads out of the SRD shapes (Level tables, Grants,
/// the Combat stats block) and the SRD lists a markdown field shows as
/// text, written into the data (A1). An SRD value that reads as nothing
/// (a level-bound pool, granted from the class rows) is emptied, not left
/// in its SRD shape. [byId] holds every pack card. Refs and `_lookup`
/// placeholders stay; the world resolves them when it synthesises the card.
Map<String, dynamic> freeSrdFields(Entity card, Map<String, Entity> byId) {
  final cat = _categories[card.categorySlug];
  if (cat == null) return card.fields;
  final out = Map<String, dynamic>.from(card.fields);
  for (final f in cat.fields) {
    var v = freeFieldValue(f, card.fields, byId: byId);
    if (f.fieldType == FieldType.markdown && v is List) {
      v = structuredListAsMarkdown(v, (r) => entityRefName(r, byId));
    }
    if (!_blank(v) || !_blank(out[f.fieldKey])) out[f.fieldKey] = v;
  }
  return out;
}

bool _blank(Object? v) =>
    v == null ||
    (v is String && v.isEmpty) ||
    (v is List && v.isEmpty) ||
    (v is Map && v.isEmpty);
