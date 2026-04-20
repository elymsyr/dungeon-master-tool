import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/typed_content_provider.dart';
import '../../../../domain/dnd5e/core/ability.dart';
import '../../../../domain/dnd5e/core/ability_scores.dart';
import '../../../../domain/dnd5e/monster/monster.dart';
import '../../../../domain/dnd5e/monster/stat_block.dart';
import '../../../../domain/dnd5e/monster/monster_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../editors/entity_editor_dialog.dart';

/// Typed renderer for a Tier 2 `Monster` row. Shows stat block summary +
/// action blocks (actions / bonus / reactions / legendary).
class MonsterCard extends ConsumerWidget {
  final String entityId;
  final Color categoryColor;

  const MonsterCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monsterRowProvider(entityId));
    return async.when(
      loading: () => const CardPlaceholder('Loading monster…'),
      error: (e, _) => CardPlaceholder('Failed to load monster: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Monster "$entityId" not found');
        }
        final Monster monster;
        try {
          monster = monsterFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.statBlockJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid monster body: $e');
        }
        return _MonsterBody(
            monster: monster,
            categoryColor: categoryColor,
            entityId: entityId);
      },
    );
  }
}

class _MonsterBody extends StatelessWidget {
  final Monster monster;
  final Color categoryColor;
  final String entityId;

  const _MonsterBody(
      {required this.monster,
      required this.categoryColor,
      required this.entityId});

  @override
  Widget build(BuildContext context) {
    final sb = monster.stats;
    return CardShell(
      title: monster.name,
      subtitle:
          '${_localSlug(sb.sizeId)} ${_localSlug(sb.typeId)}${sb.alignmentId == null ? '' : ', ${_localSlug(sb.alignmentId!)}'}',
      categoryColor: categoryColor,
      onEdit: () => showEntityEditor(
        context: context,
        entityId: entityId,
        categorySlug: 'monster',
      ),
      tags: [
        CardTag('CR ${sb.cr.canonical}'),
        CardTag('AC ${sb.armorClass}'),
        CardTag('HP ${sb.hitPoints}'),
      ],
      children: [
        CardKeyValue(
          'Speed',
          _speedText(sb.speeds),
        ),
        const SizedBox(height: 8),
        _AbilityRow(abilities: sb.abilities),
        if (sb.savingThrows.isNotEmpty)
          CardKeyValue(
            'Saving Throws',
            sb.savingThrows.entries
                .map((e) => '${_ability(e.key)} ${e.value.name}')
                .join(', '),
          ),
        if (sb.damageResistanceIds.isNotEmpty)
          CardKeyValue(
            'Resistances',
            sb.damageResistanceIds.map(_localSlug).join(', '),
          ),
        if (sb.damageImmunityIds.isNotEmpty)
          CardKeyValue(
            'Immunities',
            sb.damageImmunityIds.map(_localSlug).join(', '),
          ),
        if (sb.conditionImmunityIds.isNotEmpty)
          CardKeyValue(
            'Condition Immunities',
            sb.conditionImmunityIds.map(_localSlug).join(', '),
          ),
        if (sb.languageIds.isNotEmpty)
          CardKeyValue(
            'Languages',
            sb.languageIds.map(_localSlug).join(', '),
          ),
        if (monster.actions.isNotEmpty)
          CardSection(
            title: 'ACTIONS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in monster.actions)
                  _ActionLine(name: a.name, description: a.description),
              ],
            ),
          ),
        if (monster.bonusActions.isNotEmpty)
          CardSection(
            title: 'BONUS ACTIONS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in monster.bonusActions)
                  _ActionLine(name: a.name, description: a.description),
              ],
            ),
          ),
        if (monster.reactions.isNotEmpty)
          CardSection(
            title: 'REACTIONS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in monster.reactions)
                  _ActionLine(name: a.name, description: a.description),
              ],
            ),
          ),
        if (monster.legendaryActions.isNotEmpty)
          CardSection(
            title: 'LEGENDARY ACTIONS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Slots: ${monster.legendaryActionSlots}'),
                for (final a in monster.legendaryActions)
                  _ActionLine(name: a.name, description: a.description),
              ],
            ),
          ),
        if (monster.description.isNotEmpty)
          CardSection(
            title: 'DESCRIPTION',
            child: Text(monster.description),
          ),
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
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(mod(score), style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
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
