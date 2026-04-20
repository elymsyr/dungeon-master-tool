import 'package:flutter/material.dart';

import '../../../../domain/dnd5e/character/character.dart';
import '../../../../domain/dnd5e/core/ability.dart';
import '../../../theme/dm_tool_colors.dart';

/// Typed read-only character sheet view. Doc 32 layout — three-tab shell
/// (Stats / Combat / Personal) driven by a typed [Character] model. Full
/// editing + creation wizard lands in follow-up work (Doc 10); this scaffold
/// ships so the router can route typed player IDs at the DatabaseScreen
/// dispatcher.
class Dnd5eCharacterSheetView extends StatelessWidget {
  final Character character;

  const Dnd5eCharacterSheetView({required this.character, super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: palette.tabActiveBg,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(character.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(
                        character.classLevels
                            .map((cl) =>
                                '${_local(cl.classId)} ${cl.level}')
                            .join(' / '),
                        style: TextStyle(
                            color: palette.sidebarLabelSecondary,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _HpChip(character: character),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Stats'),
              Tab(text: 'Combat'),
              Tab(text: 'Personal'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _StatsTab(character: character),
                _CombatTab(character: character),
                _PersonalTab(character: character),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HpChip extends StatelessWidget {
  final Character character;
  const _HpChip({required this.character});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('HP ${character.hp.current} / ${character.hp.max}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final Character character;
  const _StatsTab({required this.character});

  @override
  Widget build(BuildContext context) {
    final ab = character.abilities;
    final rows = [
      ('Strength', ab.byAbility(Ability.strength).value),
      ('Dexterity', ab.byAbility(Ability.dexterity).value),
      ('Constitution', ab.byAbility(Ability.constitution).value),
      ('Intelligence', ab.byAbility(Ability.intelligence).value),
      ('Wisdom', ab.byAbility(Ability.wisdom).value),
      ('Charisma', ab.byAbility(Ability.charisma).value),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (name, score) in rows)
          ListTile(
            dense: true,
            title: Text(name),
            trailing: Text('$score (${_mod(score)})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _CombatTab extends StatelessWidget {
  final Character character;
  const _CombatTab({required this.character});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          dense: true,
          title: const Text('Hit Points'),
          trailing: Text('${character.hp.current} / ${character.hp.max}'),
        ),
        ListTile(
          dense: true,
          title: const Text('Hit Dice'),
          trailing: Text(character.hitDice.toString()),
        ),
        ListTile(
          dense: true,
          title: const Text('Proficiency Bonus'),
          trailing: Text('+${character.proficiencyBonus}'),
        ),
        ListTile(
          dense: true,
          title: const Text('Exhaustion'),
          trailing: Text('${character.exhaustion.level}'),
        ),
        ListTile(
          dense: true,
          title: const Text('Conditions'),
          trailing: Text(character.activeConditionIds.isEmpty
              ? '—'
              : character.activeConditionIds.map(_local).join(', ')),
        ),
      ],
    );
  }
}

class _PersonalTab extends StatelessWidget {
  final Character character;
  const _PersonalTab({required this.character});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          dense: true,
          title: const Text('Species'),
          trailing: Text(_local(character.speciesId)),
        ),
        if (character.lineageId != null)
          ListTile(
            dense: true,
            title: const Text('Lineage'),
            trailing: Text(_local(character.lineageId!)),
          ),
        ListTile(
          dense: true,
          title: const Text('Background'),
          trailing: Text(_local(character.backgroundId)),
        ),
        ListTile(
          dense: true,
          title: const Text('Alignment'),
          trailing: Text(_local(character.alignmentId)),
        ),
        ListTile(
          dense: true,
          title: const Text('XP'),
          trailing: Text('${character.experiencePoints}'),
        ),
        if (character.featIds.isNotEmpty)
          ListTile(
            dense: true,
            title: const Text('Feats'),
            subtitle: Text(character.featIds.map(_local).join(', ')),
          ),
        if (character.languageIds.isNotEmpty)
          ListTile(
            dense: true,
            title: const Text('Languages'),
            subtitle: Text(character.languageIds.map(_local).join(', ')),
          ),
      ],
    );
  }
}

String _mod(int score) {
  final m = (score - 10) ~/ 2;
  return m >= 0 ? '+$m' : '$m';
}

String _local(String id) {
  final idx = id.indexOf(':');
  return idx < 0 ? id : id.substring(idx + 1);
}
