// Map v2 Open5e `MagicItem.json` rows onto the app's `magic-item` package
// entity. (Mundane SRD weapons/armor/adventuring-gear are intentionally not
// imported — they duplicate built-in content 1:1 and carry no unique value.
// Magic weapons/armor/shields from sources like Vault of Magic ARE captured
// here, mapped to the Weapons/Armor magic-item categories.)
//
// Depth = stats + descriptive text: category, rarity, attunement, cost, weight
// plus the full effect markdown, and — audit **L3** — the base-item link
// (`base_item_ref`) as a softRef onto the built-in weapon/armor/gear card the
// upstream `weapon`/`armor` column names. The pack ships no base items of its
// own, which is why this is a softRef and not a `_ref`.
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';

import '../loaders.dart';
import '../normalize.dart';
import '../refgraph.dart';
import 'chargen.dart' show softRef;

/// v2 `category` slug → canonical app magic-item-category name. The app's nine
/// categories are coarser than Open5e's (shield→Armor, ammunition→Weapons).
const _categoryAlias = {
  'weapon': 'Weapons',
  'wondrous-item': 'Wondrous Items',
  'armor': 'Armor',
  'potion': 'Potions',
  'ring': 'Rings',
  'staff': 'Staffs',
  'wand': 'Wands',
  'rod': 'Rods',
  'scroll': 'Scrolls',
  'shield': 'Armor',
  'ammunition': 'Weapons',
};

/// Base-item name after [baseItemName]'s transform → the built-in name it is
/// actually filed under. Only the rows where the plain slug→title-case landing
/// misses: the 2024 SRD renamed the armors ("plate" → "Plate Armor") and
/// upstream orders the crossbows the other way round.
const _baseItemAlias = {
  'Plate': 'Plate Armor',
  'Half Plate': 'Half Plate Armor',
  'Hide': 'Hide Armor',
  'Leather': 'Leather Armor',
  'Padded': 'Padded Armor',
  'Splint': 'Splint Armor',
  'Studded Leather': 'Studded Leather Armor',
  'Crossbow Hand': 'Hand Crossbow',
  'Crossbow Heavy': 'Heavy Crossbow',
  'Crossbow Light': 'Light Crossbow',
};

/// `'srd_war-pick'` → `'War Pick'`. The prefix is the owning document, not part
/// of the name. Public so `verify.dart` can restate the `base_item_ref`
/// contract without re-implementing the transform.
String? baseItemName(Object? slug) {
  if (slug is! String || slug.trim().isEmpty) return null;
  final i = slug.indexOf('_');
  final bare = titleCase(i < 0 ? slug : slug.substring(i + 1));
  return bare.isEmpty ? null : (_baseItemAlias[bare] ?? bare);
}

/// Map all magic items in a document into [pack].
///
/// [knownBaseItems] is `name → category slug` for every base item a
/// `base_item_ref` may target; anything outside it emits no ref, because an
/// unresolvable softRef is a `dangling-soft-ref` gate violation.
void mapMagicItems({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> items,
  Map<String, String> knownBaseItems = const {},
}) {
  for (final it in items) {
    final name = (it['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;

    final desc = (it['desc'] as String?)?.trim() ?? '';
    final attune = it['requires_attunement'] == true;
    final attrs = <String, dynamic>{
      'requires_attunement': attune,
      'is_cursed': false,
      'activation': 'None',
      'effects': desc,
      'is_sentient': false,
    };

    final catRaw = (it['category'] as String?)?.trim().toLowerCase() ?? '';
    final cat = norm.lookupRef(
        'magic-item-category', _categoryAlias[catRaw] ?? catRaw,
        context: name);
    if (cat != null) attrs['magic_category_ref'] = cat;

    final rarRaw = (it['rarity'] as String?)?.trim() ?? '';
    if (rarRaw.isNotEmpty) {
      final rar = norm.lookupRef('rarity', rarRaw, context: name);
      if (rar != null) attrs['rarity_ref'] = rar;
    }

    final attuneDetail = (it['attunement_detail'] as String?)?.trim() ?? '';
    if (attune && attuneDetail.isNotEmpty) {
      attrs['attunement_prereq'] = attuneDetail;
    }

    // Base item (audit L3). Upstream keeps the link in two columns, one per
    // kind; a row never fills both.
    final baseName = baseItemName(it['weapon'] ?? it['armor']);
    final baseSlug = baseName == null ? null : knownBaseItems[baseName];
    if (baseSlug != null) {
      attrs['base_item_ref'] = softRef(baseSlug, baseName!);
    }

    final cost = _numOf(it['cost']);
    if (cost != null && cost > 0) attrs['cost_gp'] = cost;
    final weight = _numOf(it['weight']);
    if (weight != null && weight > 0) attrs['weight_lb'] = weight;

    pack.add(packEntity(
      slug: 'magic-item',
      name: name,
      description: desc,
      source: source,
      attributes: attrs,
    ));
  }
}

double? _numOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}
