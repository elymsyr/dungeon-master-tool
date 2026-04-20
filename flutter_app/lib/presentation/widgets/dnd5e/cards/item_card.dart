import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/item/item.dart';
import '../../../../domain/dnd5e/item/item_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../entity_link_chip.dart';
import '../inline_field.dart';
import '_body_cache.dart';

final _itemCache = BodyCache<(Item, Map<String, Object?>)>();

/// Typed renderer for a Tier 2 `Item` row (sealed: Weapon/Armor/Shield/Gear/
/// Tool/Ammunition/MagicItem). Name + description are inline editable;
/// variant-specific fields remain read-only in this pass.
class ItemCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const ItemCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<ItemCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant ItemCard old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) {
      _effectiveId = widget.entityId;
    }
  }

  Future<void> _save({
    required String name,
    required Map<String, Object?> body,
    required String itemType,
    required String? rarityId,
  }) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) return;
    final writtenId = await saveEditedEntity(
      db: ref.read(appDatabaseProvider),
      currentId: _effectiveId,
      categorySlug: 'item',
      activeCampaignId: campaignId,
      name: name,
      bodyJson: body,
      extras: {'itemType': itemType, 'rarityId': rarityId},
    );
    if (!mounted) return;
    if (writtenId != _effectiveId) {
      setState(() => _effectiveId = writtenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(itemRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading item…'),
      error: (e, _) => CardPlaceholder('Failed to load item: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Item "$_effectiveId" not found');
        }
        final Item item;
        final Map<String, Object?> body;
        try {
          final cacheKey =
              '${row.id}|${row.updatedAt.millisecondsSinceEpoch}';
          final decoded = _itemCache.getOrCompute(cacheKey, () {
            final b = (jsonDecode(row.bodyJson) as Map)
                .cast<String, Object?>();
            final i = itemFromEntry(
              CatalogEntry(
                  id: row.id, name: row.name, bodyJson: row.bodyJson),
            );
            return (i, b);
          });
          item = decoded.$1;
          body = decoded.$2;
        } catch (e) {
          return CardPlaceholder('Invalid item body: $e');
        }
        return _ItemBody(
          item: item,
          name: row.name,
          body: body,
          itemType: row.itemType,
          rarityId: row.rarityId,
          categoryColor: widget.categoryColor,
          onSave: _save,
        );
      },
    );
  }
}

class _ItemBody extends StatelessWidget {
  final Item item;
  final String name;
  final Map<String, Object?> body;
  final String itemType;
  final String? rarityId;
  final Color categoryColor;
  final Future<void> Function({
    required String name,
    required Map<String, Object?> body,
    required String itemType,
    required String? rarityId,
  }) onSave;

  const _ItemBody({
    required this.item,
    required this.name,
    required this.body,
    required this.itemType,
    required this.rarityId,
    required this.categoryColor,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final rarity = _localSlug(item.rarityId);
    return CardShell(
      title: name,
      subtitle: '${_capitalize(itemType)} • ${_capitalize(rarity)}',
      categoryColor: categoryColor,
      tags: [
        CardTag(_capitalize(itemType)),
        if (rarityId != null && rarityId!.isNotEmpty)
          EntityLinkChip(
            entityId: rarityId!,
            displayLabel: _capitalize(rarity),
          )
        else
          CardTag(_capitalize(rarity)),
        CardTag(_costText(item.costCp)),
        if (item.weightLb > 0) CardTag('${_trim(item.weightLb)} lb'),
      ],
      children: [
        CardFieldGroup(title: 'Identity', children: [
          CardFieldGrid(columns: 2, fields: [
            CardField(
              label: 'Name',
              child: InlineTextField(
                value: name,
                style: Theme.of(context).textTheme.titleMedium,
                onCommit: (v) => onSave(
                  name: v,
                  body: body,
                  itemType: itemType,
                  rarityId: rarityId,
                ),
              ),
            ),
            CardField(
                label: 'Type',
                child: InlineTextField(
                  value: itemType,
                  onCommit: (v) => onSave(
                    name: name,
                    body: body,
                    itemType: v.isEmpty ? 'gear' : v,
                    rarityId: rarityId,
                  ),
                )),
            CardField(
                label: 'Rarity',
                child: InlineTextField(
                  value: rarityId ?? '',
                  placeholder: '—',
                  onCommit: (v) => onSave(
                    name: name,
                    body: body,
                    itemType: itemType,
                    rarityId: v.isEmpty ? null : v,
                  ),
                )),
            CardField(label: 'Cost', child: Text(_costText(item.costCp))),
          ]),
        ]),
        if (item.weightLb > 0)
          CardFieldGroup(title: 'Physical', children: [
            CardKeyValue('Weight', '${_trim(item.weightLb)} lb'),
          ]),
        CardFieldGroup(title: 'Variant', children: [
          ..._variantLines(item),
        ]),
      ],
    );
  }

  List<Widget> _variantLines(Item item) {
    switch (item) {
      case Weapon w:
        return [
          CardKeyValue('Category', '${w.category.name} ${w.type.name}'),
          _KeyLinkRow(
            label: 'Damage',
            prefix: '${w.damage} ',
            ids: [w.damageTypeId],
          ),
          if (w.versatileDamage != null)
            CardKeyValue('Versatile', w.versatileDamage!.toString()),
          if (w.range != null)
            CardKeyValue(
                'Range', '${w.range!.normal}/${w.range!.long} ft.'),
          if (w.propertyIds.isNotEmpty)
            _KeyLinkRow(label: 'Properties', ids: w.propertyIds),
          if (w.masteryId != null)
            _KeyLinkRow(label: 'Mastery', ids: [w.masteryId!]),
        ];
      case Armor a:
        return [
          _KeyLinkRow(label: 'Category', ids: [a.categoryId]),
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
          if (g.description.isNotEmpty) Text(g.description),
        ];
      case Tool t:
        return [
          if (t.proficiencyId != null)
            _KeyLinkRow(label: 'Proficiency', ids: [t.proficiencyId!]),
        ];
      case Ammunition am:
        return [
          CardKeyValue('Per Stack', '${am.quantityPerStack}'),
        ];
      case MagicItem m:
        return [
          if (m.baseItemId != null)
            _KeyLinkRow(label: 'Base Item', ids: [m.baseItemId!]),
          CardKeyValue(
              'Attunement', m.requiresAttunement ? 'Required' : 'No'),
          if (m.effects.isNotEmpty)
            Text('${m.effects.length} effect(s)'),
        ];
    }
  }
}

/// Label + `prefix` + wrapped row of [EntityLinkChip]s.
class _KeyLinkRow extends StatelessWidget {
  final String label;
  final String? prefix;
  final Iterable<String> ids;
  const _KeyLinkRow({required this.label, required this.ids, this.prefix});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (prefix != null && prefix!.isNotEmpty) Text(prefix!),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final id in ids) EntityLinkChip(entityId: id),
              ],
            ),
          ),
        ],
      ),
    );
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
