import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/item/item.dart';
import '../../../../domain/dnd5e/item/item_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../editors/entity_editor_dialog.dart';

/// Typed renderer for a Tier 2 `Item` row (sealed: Weapon/Armor/Shield/Gear/
/// Tool/Ammunition/MagicItem). Dispatches on runtime case for category-specific
/// fields.
class ItemCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const ItemCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading item…'),
      error: (e, _) => CardPlaceholder('Failed to load item: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Item "$entityId" not found');
        }
        final Item item;
        try {
          item = itemFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid item body: $e');
        }
        return _ItemBody(
          item: item,
          categoryColor: categoryColor,
          itemType: row.itemType,
          entityId: entityId,
        );
      },
    );
  }
}

class _ItemBody extends StatelessWidget {
  final Item item;
  final Color categoryColor;
  final String itemType;
  final String entityId;

  const _ItemBody({
    required this.item,
    required this.categoryColor,
    required this.itemType,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context) {
    final rarity = _localSlug(item.rarityId);
    return CardShell(
      title: item.name,
      subtitle: '${_capitalize(itemType)} • ${_capitalize(rarity)}',
      categoryColor: categoryColor,
      onEdit: () => showEntityEditor(
        context: context,
        entityId: entityId,
        categorySlug: 'item',
      ),
      tags: [
        CardTag(_capitalize(itemType)),
        CardTag(_capitalize(rarity)),
        CardTag(_costText(item.costCp)),
        if (item.weightLb > 0) CardTag('${_trim(item.weightLb)} lb'),
      ],
      children: [
        ..._variantLines(item),
      ],
    );
  }

  List<Widget> _variantLines(Item item) {
    switch (item) {
      case Weapon w:
        return [
          CardKeyValue('Category',
              '${w.category.name} ${w.type.name}'),
          CardKeyValue('Damage',
              '${w.damage} ${_localSlug(w.damageTypeId)}'),
          if (w.versatileDamage != null)
            CardKeyValue('Versatile', w.versatileDamage!.toString()),
          if (w.range != null)
            CardKeyValue(
                'Range', '${w.range!.normal}/${w.range!.long} ft.'),
          if (w.propertyIds.isNotEmpty)
            CardKeyValue('Properties',
                w.propertyIds.map(_localSlug).join(', ')),
          if (w.masteryId != null)
            CardKeyValue('Mastery', _localSlug(w.masteryId!)),
        ];
      case Armor a:
        return [
          CardKeyValue('Category', _localSlug(a.categoryId)),
          CardKeyValue('Base AC', '${a.baseAc}'),
          if (a.strengthRequirement != null)
            CardKeyValue('Strength', 'Str ${a.strengthRequirement}'),
        ];
      case Shield _:
        return const [
          CardKeyValue('AC Bonus', '+2'),
        ];
      case Gear g:
        return [
          if (g.description.isNotEmpty)
            CardSection(title: 'DESCRIPTION', child: Text(g.description)),
        ];
      case Tool t:
        return [
          if (t.proficiencyId != null)
            CardKeyValue('Proficiency', _localSlug(t.proficiencyId!)),
        ];
      case Ammunition am:
        return [
          CardKeyValue('Per Stack', '${am.quantityPerStack}'),
        ];
      case MagicItem m:
        return [
          if (m.baseItemId != null)
            CardKeyValue('Base Item', _localSlug(m.baseItemId!)),
          CardKeyValue(
              'Attunement', m.requiresAttunement ? 'Required' : 'No'),
          if (m.effects.isNotEmpty)
            CardSection(
              title: 'EFFECTS',
              child: Text('${m.effects.length} effect(s)'),
            ),
        ];
    }
  }
}

String _costText(int cp) {
  if (cp == 0) return '—';
  if (cp % 10000 == 0) return '${cp ~/ 10000} pp';
  if (cp % 100 == 0) return '${cp ~/ 100} gp';
  if (cp % 10 == 0) return '${cp ~/ 10} sp';
  return '$cp cp';
}

String _localSlug(String id) {
  final idx = id.indexOf(':');
  return idx < 0 ? id : id.substring(idx + 1);
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _trim(double v) =>
    v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);
