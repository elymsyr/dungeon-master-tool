// Map v2 Open5e `MagicItem.json` rows onto the app's `magic-item` package
// entity. (Mundane SRD weapons/armor/adventuring-gear are intentionally not
// imported — they duplicate built-in content 1:1 and carry no unique value.
// Magic weapons/armor/shields from sources like Vault of Magic ARE captured
// here, mapped to the Weapons/Armor magic-item categories.)
//
// Depth = stats + descriptive text: category, rarity, attunement, cost, weight
// plus the full effect markdown. The base-item link (`base_item_ref`) is not
// emitted — magic-item packages ship no base weapon/armor entities to point at.
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';

import '../loaders.dart';
import '../normalize.dart';
import '../refgraph.dart';

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

/// Map all magic items in a document into [pack].
void mapMagicItems({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> items,
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
