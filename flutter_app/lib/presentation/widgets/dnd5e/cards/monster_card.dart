import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/core/ability.dart';
import '../../../../domain/dnd5e/core/ability_scores.dart';
import '../../../../domain/dnd5e/monster/monster.dart';
import '../../../../domain/dnd5e/monster/monster_json_codec.dart';
import '../../../../domain/dnd5e/monster/stat_block.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../entity_link_chip.dart';
import '../inline_field.dart';

/// Typed renderer for a Tier 2 `Monster` row. Shows stat block summary +
/// action blocks (actions / bonus / reactions / legendary). Name + flavor
/// description are inline editable; editing SRD-owned rows forks into the
/// active campaign via [saveEditedEntity].
class MonsterCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const MonsterCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<MonsterCard> createState() => _MonsterCardState();
}

class _MonsterCardState extends ConsumerState<MonsterCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant MonsterCard old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) {
      _effectiveId = widget.entityId;
    }
  }

  Future<void> _save({
    required String name,
    required Map<String, Object?> body,
  }) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) return;
    final writtenId = await saveEditedEntity(
      db: ref.read(appDatabaseProvider),
      currentId: _effectiveId,
      categorySlug: 'monster',
      activeCampaignId: campaignId,
      name: name,
      bodyJson: body,
    );
    if (!mounted) return;
    if (writtenId != _effectiveId) {
      setState(() => _effectiveId = writtenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(monsterRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading monster…'),
      error: (e, _) => CardPlaceholder('Failed to load monster: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Monster "$_effectiveId" not found');
        }
        final Monster monster;
        final Map<String, Object?> body;
        try {
          body =
              (jsonDecode(row.statBlockJson) as Map).cast<String, Object?>();
          monster = monsterFromEntry(
            CatalogEntry(
                id: row.id, name: row.name, bodyJson: row.statBlockJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid monster body: $e');
        }
        return _MonsterBody(
          monster: monster,
          name: row.name,
          body: body,
          categoryColor: widget.categoryColor,
          onSave: _save,
        );
      },
    );
  }
}

class _MonsterBody extends StatelessWidget {
  final Monster monster;
  final String name;
  final Map<String, Object?> body;
  final Color categoryColor;
  final Future<void> Function({
    required String name,
    required Map<String, Object?> body,
  }) onSave;

  const _MonsterBody({
    required this.monster,
    required this.name,
    required this.body,
    required this.categoryColor,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final sb = monster.stats;
    return CardShell(
      title: name,
      subtitle:
          '${_localSlug(sb.sizeId)} ${_localSlug(sb.typeId)}${sb.alignmentId == null ? '' : ', ${_localSlug(sb.alignmentId!)}'}',
      categoryColor: categoryColor,
      tags: [
        CardTag('CR ${sb.cr.canonical}'),
        CardTag('AC ${sb.armorClass}'),
        CardTag('HP ${sb.hitPoints}'),
      ],
      children: [
        CardFieldGroup(title: 'Identity', children: [
          CardFieldGrid(columns: 2, fields: [
            CardField(
              label: 'Name',
              child: InlineTextField(
                value: name,
                style: Theme.of(context).textTheme.titleMedium,
                onCommit: (v) => onSave(name: v, body: body),
              ),
            ),
            CardField(label: 'CR', child: Text(sb.cr.canonical)),
            CardField(
                label: 'Size',
                child: EntityLinkChip(entityId: sb.sizeId)),
            CardField(
                label: 'Type',
                child: EntityLinkChip(entityId: sb.typeId)),
          ]),
        ]),
        CardFieldGroup(title: 'Combat', children: [
          CardFieldGrid(columns: 3, fields: [
            CardField(label: 'Armor Class', child: Text('${sb.armorClass}')),
            CardField(label: 'Hit Points', child: Text('${sb.hitPoints}')),
            CardField(label: 'Speed', child: Text(_speedText(sb.speeds))),
          ]),
        ]),
        CardFieldGroup(title: 'Abilities', children: [
          _AbilityRow(abilities: sb.abilities),
        ]),
        if (sb.savingThrows.isNotEmpty ||
            sb.damageResistanceIds.isNotEmpty ||
            sb.damageImmunityIds.isNotEmpty ||
            sb.conditionImmunityIds.isNotEmpty ||
            sb.languageIds.isNotEmpty)
          CardFieldGroup(title: 'Resistances & Traits', children: [
            if (sb.savingThrows.isNotEmpty)
              CardKeyValue(
                'Saving Throws',
                sb.savingThrows.entries
                    .map((e) => '${_ability(e.key)} ${e.value.name}')
                    .join(', '),
              ),
            if (sb.damageResistanceIds.isNotEmpty)
              _LabeledLinkRow(
                label: 'Resistances',
                ids: sb.damageResistanceIds,
              ),
            if (sb.damageImmunityIds.isNotEmpty)
              _LabeledLinkRow(
                label: 'Immunities',
                ids: sb.damageImmunityIds,
              ),
            if (sb.conditionImmunityIds.isNotEmpty)
              _LabeledLinkRow(
                label: 'Condition Immunities',
                ids: sb.conditionImmunityIds,
              ),
            if (sb.languageIds.isNotEmpty)
              _LabeledLinkRow(
                label: 'Languages',
                ids: sb.languageIds,
              ),
          ]),
        if (monster.actions.isNotEmpty)
          CardFieldGroup(title: 'Actions', children: [
            for (final a in monster.actions)
              _ActionLine(name: a.name, description: a.description),
          ]),
        if (monster.bonusActions.isNotEmpty)
          CardFieldGroup(title: 'Bonus Actions', children: [
            for (final a in monster.bonusActions)
              _ActionLine(name: a.name, description: a.description),
          ]),
        if (monster.reactions.isNotEmpty)
          CardFieldGroup(title: 'Reactions', children: [
            for (final a in monster.reactions)
              _ActionLine(name: a.name, description: a.description),
          ]),
        if (monster.legendaryActions.isNotEmpty)
          CardFieldGroup(title: 'Legendary Actions', children: [
            Text('Slots: ${monster.legendaryActionSlots}'),
            for (final a in monster.legendaryActions)
              _ActionLine(name: a.name, description: a.description),
          ]),
        CardFieldGroup(title: 'Description', children: [
          InlineTextField(
            value: monster.description,
            maxLines: 12,
            placeholder: 'No description yet — tap to add…',
            onCommit: (v) =>
                onSave(name: name, body: {...body, 'description': v}),
          ),
        ]),
      ],
    );
  }
}

class _AbilityRow extends StatelessWidget {
  final AbilityScores abilities;
  const _AbilityRow({required this.abilities});

  @override
  Widget build(BuildContext context) {
    String mod(int score) {
      final m = (score - 10) ~/ 2;
      final s = m >= 0 ? '+$m' : '$m';
      return '$score ($s)';
    }

    final entries = [
      ('STR', abilities.byAbility(Ability.strength).value),
      ('DEX', abilities.byAbility(Ability.dexterity).value),
      ('CON', abilities.byAbility(Ability.constitution).value),
      ('INT', abilities.byAbility(Ability.intelligence).value),
      ('WIS', abilities.byAbility(Ability.wisdom).value),
      ('CHA', abilities.byAbility(Ability.charisma).value),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (label, score) in entries)
          Column(
            children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(mod(score), style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}

/// Label + wrapped row of [EntityLinkChip]s — used for resistances /
/// immunities / language lists so every referenced id becomes a tappable,
/// hoverable link to the other panel.
class _LabeledLinkRow extends StatelessWidget {
  final String label;
  final Iterable<String> ids;
  const _LabeledLinkRow({required this.label, required this.ids});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
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

class _ActionLine extends StatelessWidget {
  final String name;
  final String description;
  const _ActionLine({required this.name, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$name. ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
            TextSpan(text: description),
          ],
        ),
      ),
    );
  }
}

String _speedText(MonsterSpeeds s) {
  final parts = <String>['${s.walk} ft.'];
  if (s.fly != null) parts.add('fly ${s.fly}${s.hover ? ' (hover)' : ''}');
  if (s.swim != null) parts.add('swim ${s.swim}');
  if (s.climb != null) parts.add('climb ${s.climb}');
  if (s.burrow != null) parts.add('burrow ${s.burrow}');
  return parts.join(', ');
}

String _ability(Ability a) => switch (a) {
      Ability.strength => 'STR',
      Ability.dexterity => 'DEX',
      Ability.constitution => 'CON',
      Ability.intelligence => 'INT',
      Ability.wisdom => 'WIS',
      Ability.charisma => 'CHA',
    };

String _localSlug(String id) {
  final idx = id.indexOf(':');
  return idx < 0 ? id : id.substring(idx + 1);
}
