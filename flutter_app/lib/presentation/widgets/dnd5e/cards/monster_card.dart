import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/edit_mode_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/core/ability.dart';
import '../../../../domain/dnd5e/core/ability_scores.dart';
import '../../../../domain/dnd5e/core/proficiency.dart';
import '../../../../domain/dnd5e/monster/monster.dart';
import '../../../../domain/dnd5e/monster/monster_json_codec.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../inline_field.dart';
import '../inline_field_extras.dart';
import '_body_cache.dart';

final _monsterCache = BodyCache<(Monster, Map<String, Object?>)>();

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
          final cacheKey =
              '${row.id}|${row.updatedAt.millisecondsSinceEpoch}';
          final decoded = _monsterCache.getOrCompute(cacheKey, () {
            final b = (jsonDecode(row.statBlockJson) as Map)
                .cast<String, Object?>();
            final m = monsterFromEntry(
              CatalogEntry(
                  id: row.id, name: row.name, bodyJson: row.statBlockJson),
            );
            return (m, b);
          });
          monster = decoded.$1;
          body = decoded.$2;
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

class _MonsterBody extends ConsumerWidget {
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

  Map<String, Object?> _patchStats(Map<String, Object?> updates) {
    final stats = (body['stats'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final merged = {...stats, ...updates};
    merged.removeWhere((_, v) => v == null);
    return {...body, 'stats': merged};
  }

  Map<String, Object?> _patchSpeeds(Map<String, Object?> updates) {
    final stats = (body['stats'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final speeds = (stats['speeds'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final merged = {...speeds, ...updates};
    merged.removeWhere((_, v) => v == null);
    return {...body, 'stats': {...stats, 'speeds': merged}};
  }

  Map<String, Object?> _patchAbilities(Map<String, Object?> updates) {
    final stats = (body['stats'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final ab = (stats['abilities'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    return {
      ...body,
      'stats': {...stats, 'abilities': {...ab, ...updates}},
    };
  }

  List<Map<String, Object?>> _rawList(
      Map<String, Object?> body, String key) {
    final raw = body[key];
    if (raw is! List) return <Map<String, Object?>>[];
    return [
      for (final e in raw)
        if (e is Map) e.cast<String, Object?>(),
    ];
  }

  Map<String, Object?> _patchListField(
      String key, List<Map<String, Object?>> next) {
    final out = <String, Object?>{...body};
    if (next.isEmpty) {
      out.remove(key);
    } else {
      out[key] = next;
    }
    return out;
  }

  Map<String, Object?> _patchSavingThrows(Ability a, Proficiency p) {
    final stats = (body['stats'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final saves = (stats['savingThrows'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final merged = {...saves};
    if (p == Proficiency.none) {
      merged.remove(a.name);
    } else {
      merged[a.name] = p.name;
    }
    final newStats = {...stats};
    if (merged.isEmpty) {
      newStats.remove('savingThrows');
    } else {
      newStats['savingThrows'] = merged;
    }
    return {...body, 'stats': newStats};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb = monster.stats;

    List<CatalogOption> optionsFrom<T extends dynamic>(
            AsyncValue<List<T>> async) =>
        async.maybeWhen(
          data: (list) => [
            for (final e in list)
              CatalogOption(
                id: (e as dynamic).id as String,
                name: (e as dynamic).name as String,
              )
          ],
          orElse: () => const <CatalogOption>[],
        );

    final sizeOptions = optionsFrom(ref.watch(allSizesProvider));
    final typeOptions = optionsFrom(ref.watch(allCreatureTypesProvider));
    final alignmentOptions =
        optionsFrom(ref.watch(allAlignmentsProvider));
    final damageTypeOptions = optionsFrom(ref.watch(allDamageTypesProvider));
    final conditionOptions = optionsFrom(ref.watch(allConditionsProvider));
    final languageOptions = optionsFrom(ref.watch(allLanguagesProvider));

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
            CardField(
              label: 'CR',
              child: InlineTextField(
                value: sb.cr.canonical,
                onCommit: (v) {
                  if (v.trim().isEmpty) return;
                  onSave(
                      name: name,
                      body: _patchStats({'cr': v.trim()}));
                },
              ),
            ),
            CardField(
              label: 'Size',
              child: InlineCatalogRelationField(
                value: sb.sizeId,
                options: sizeOptions,
                onCommit: (v) =>
                    onSave(name: name, body: _patchStats({'sizeId': v})),
              ),
            ),
            CardField(
              label: 'Type',
              child: InlineCatalogRelationField(
                value: sb.typeId,
                options: typeOptions,
                onCommit: (v) =>
                    onSave(name: name, body: _patchStats({'typeId': v})),
              ),
            ),
            CardField(
              label: 'Alignment',
              child: InlineCatalogRelationField(
                value: sb.alignmentId ?? '',
                options: alignmentOptions,
                placeholder: 'Unaligned',
                onClear: () => onSave(
                  name: name,
                  body: _patchStats({'alignmentId': null}),
                ),
                onCommit: (v) => onSave(
                  name: name,
                  body: _patchStats({'alignmentId': v}),
                ),
              ),
            ),
          ]),
        ]),
        CardFieldGroup(title: 'Combat', children: [
          CardFieldGrid(columns: 3, fields: [
            CardField(
              label: 'Armor Class',
              child: InlineIntField(
                value: sb.armorClass,
                onCommit: (v) => onSave(
                    name: name, body: _patchStats({'armorClass': v})),
              ),
            ),
            CardField(
              label: 'Hit Points',
              child: InlineIntField(
                value: sb.hitPoints,
                onCommit: (v) => onSave(
                    name: name, body: _patchStats({'hitPoints': v})),
              ),
            ),
            CardField(
              label: 'Walk Speed (ft)',
              child: InlineIntField(
                value: sb.speeds.walk,
                onCommit: (v) => onSave(
                    name: name, body: _patchSpeeds({'walk': v})),
              ),
            ),
          ]),
          CardFieldGrid(columns: 5, fields: [
            CardField(
              label: 'Fly',
              child: InlineNullableIntField(
                value: sb.speeds.fly,
                onCommit: (v) => onSave(
                    name: name, body: _patchSpeeds({'fly': v})),
              ),
            ),
            CardField(
              label: 'Swim',
              child: InlineNullableIntField(
                value: sb.speeds.swim,
                onCommit: (v) => onSave(
                    name: name, body: _patchSpeeds({'swim': v})),
              ),
            ),
            CardField(
              label: 'Climb',
              child: InlineNullableIntField(
                value: sb.speeds.climb,
                onCommit: (v) => onSave(
                    name: name, body: _patchSpeeds({'climb': v})),
              ),
            ),
            CardField(
              label: 'Burrow',
              child: InlineNullableIntField(
                value: sb.speeds.burrow,
                onCommit: (v) => onSave(
                    name: name, body: _patchSpeeds({'burrow': v})),
              ),
            ),
            CardField(
              label: 'Hover',
              child: InlineBoolField(
                value: sb.speeds.hover,
                onCommit: (v) => onSave(
                  name: name,
                  body: _patchSpeeds({'hover': v ? true : null}),
                ),
              ),
            ),
          ]),
        ]),
        CardFieldGroup(title: 'Abilities', children: [
          _AbilityRow(
            abilities: sb.abilities,
            onCommit: (key, v) =>
                onSave(name: name, body: _patchAbilities({key: v})),
          ),
        ]),
        CardFieldGroup(title: 'Saving Throws', children: [
          _SavingThrowsRow(
            saves: sb.savingThrows,
            onCommit: (a, p) =>
                onSave(name: name, body: _patchSavingThrows(a, p)),
          ),
        ]),
        CardFieldGroup(title: 'Resistances & Traits', children: [
          _LabeledField(
            label: 'Damage Resistances',
            child: InlineCatalogChipListField(
              ids: sb.damageResistanceIds.toList(),
              options: damageTypeOptions,
              onCommit: (ids) => onSave(
                name: name,
                body: _patchStats({
                  'damageResistanceIds': ids.isEmpty ? null : ids,
                }),
              ),
            ),
          ),
          _LabeledField(
            label: 'Damage Immunities',
            child: InlineCatalogChipListField(
              ids: sb.damageImmunityIds.toList(),
              options: damageTypeOptions,
              onCommit: (ids) => onSave(
                name: name,
                body: _patchStats({
                  'damageImmunityIds': ids.isEmpty ? null : ids,
                }),
              ),
            ),
          ),
          _LabeledField(
            label: 'Damage Vulnerabilities',
            child: InlineCatalogChipListField(
              ids: sb.damageVulnerabilityIds.toList(),
              options: damageTypeOptions,
              onCommit: (ids) => onSave(
                name: name,
                body: _patchStats({
                  'damageVulnerabilityIds': ids.isEmpty ? null : ids,
                }),
              ),
            ),
          ),
          _LabeledField(
            label: 'Condition Immunities',
            child: InlineCatalogChipListField(
              ids: sb.conditionImmunityIds.toList(),
              options: conditionOptions,
              onCommit: (ids) => onSave(
                name: name,
                body: _patchStats({
                  'conditionImmunityIds': ids.isEmpty ? null : ids,
                }),
              ),
            ),
          ),
          _LabeledField(
            label: 'Languages',
            child: InlineCatalogChipListField(
              ids: sb.languageIds.toList(),
              options: languageOptions,
              onCommit: (ids) => onSave(
                name: name,
                body: _patchStats({
                  'languageIds': ids.isEmpty ? null : ids,
                }),
              ),
            ),
          ),
        ]),
        _ActionsGroup(
          title: 'Actions',
          bodyKey: 'actions',
          entries: _rawList(body, 'actions'),
          onSave: (next) => onSave(
              name: name, body: _patchListField('actions', next)),
        ),
        _ActionsGroup(
          title: 'Bonus Actions',
          bodyKey: 'bonusActions',
          entries: _rawList(body, 'bonusActions'),
          onSave: (next) => onSave(
              name: name, body: _patchListField('bonusActions', next)),
        ),
        _ActionsGroup(
          title: 'Reactions',
          bodyKey: 'reactions',
          entries: _rawList(body, 'reactions'),
          onSave: (next) => onSave(
              name: name, body: _patchListField('reactions', next)),
        ),
        _LegendaryGroup(
          slots: monster.legendaryActionSlots,
          entries: _rawList(body, 'legendaryActions'),
          onSlotsCommit: (v) => onSave(
            name: name,
            body: v <= 0
                ? (<String, Object?>{...body}..remove('legendaryActionSlots'))
                : {...body, 'legendaryActionSlots': v},
          ),
          onListCommit: (next) => onSave(
            name: name,
            body: _patchListField('legendaryActions', next),
          ),
        ),
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
  final void Function(String jsonKey, int score) onCommit;
  const _AbilityRow({required this.abilities, required this.onCommit});

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('STR', 'str', abilities.byAbility(Ability.strength).value),
      ('DEX', 'dex', abilities.byAbility(Ability.dexterity).value),
      ('CON', 'con', abilities.byAbility(Ability.constitution).value),
      ('INT', 'int', abilities.byAbility(Ability.intelligence).value),
      ('WIS', 'wis', abilities.byAbility(Ability.wisdom).value),
      ('CHA', 'cha', abilities.byAbility(Ability.charisma).value),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (label, key, score) in entries)
          Expanded(
            child: Column(
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(
                  width: 48,
                  child: InlineIntField(
                    value: score,
                    textAlign: TextAlign.center,
                    onCommit: (v) => onCommit(key, v),
                  ),
                ),
                Text(_modLabel(score),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  static String _modLabel(int score) {
    final m = (score - 10) ~/ 2;
    return m >= 0 ? '+$m' : '$m';
  }
}

/// Six-ability saving-throw proficiency row — per-ability popup cycles
/// through [Proficiency.values] (none/half/full/expertise).
class _SavingThrowsRow extends StatelessWidget {
  final Map<Ability, Proficiency> saves;
  final void Function(Ability, Proficiency) onCommit;
  const _SavingThrowsRow({required this.saves, required this.onCommit});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final a in Ability.values)
          _SaveToggle(
            label: _abilityShort(a),
            value: saves[a] ?? Proficiency.none,
            onCommit: (p) => onCommit(a, p),
          ),
      ],
    );
  }
}

class _SaveToggle extends ConsumerWidget {
  final String label;
  final Proficiency value;
  final ValueChanged<Proficiency> onCommit;
  const _SaveToggle({
    required this.label,
    required this.value,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    final displayText = '$label: ${_proficiencyLabel(value)}';
    if (!editMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(displayText),
      );
    }
    return PopupMenuButton<Proficiency>(
      initialValue: value,
      tooltip: '',
      onSelected: onCommit,
      itemBuilder: (_) => [
        for (final p in Proficiency.values)
          PopupMenuItem(value: p, child: Text(_proficiencyLabel(p))),
      ],
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayText),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  static String _proficiencyLabel(Proficiency p) => switch (p) {
        Proficiency.none => '—',
        Proficiency.half => '½',
        Proficiency.full => 'prof',
        Proficiency.expertise => 'exp',
      };
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text('$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Editable list of monster-action JSON maps. Each entry's name +
/// description are inline editable; delete removes the entry; the group
/// hides entirely when the list is empty unless edit mode is on.
class _ActionsGroup extends ConsumerWidget {
  final String title;
  final String bodyKey;
  final List<Map<String, Object?>> entries;
  final ValueChanged<List<Map<String, Object?>>> onSave;

  const _ActionsGroup({
    required this.title,
    required this.bodyKey,
    required this.entries,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    if (entries.isEmpty && !editMode) return const SizedBox.shrink();
    return CardFieldGroup(title: title, children: [
      for (var i = 0; i < entries.length; i++)
        _ActionEditRow(
          entry: entries[i],
          onNameCommit: (v) {
            final next = _cloneEntries(entries);
            next[i] = {...next[i], 'name': v};
            onSave(next);
          },
          onDescCommit: (v) {
            final next = _cloneEntries(entries);
            final m = {...next[i]};
            if (v.isEmpty) {
              m.remove('description');
            } else {
              m['description'] = v;
            }
            next[i] = m;
            onSave(next);
          },
          onDelete: () {
            final next = _cloneEntries(entries)..removeAt(i);
            onSave(next);
          },
        ),
      if (editMode)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text('Add $title entry'),
            onPressed: () {
              final next = _cloneEntries(entries)
                ..add({'t': 'special', 'name': 'New $title'});
              onSave(next);
            },
          ),
        ),
    ]);
  }

  static List<Map<String, Object?>> _cloneEntries(
          List<Map<String, Object?>> src) =>
      [for (final e in src) {...e}];
}

class _LegendaryGroup extends ConsumerWidget {
  final int slots;
  final List<Map<String, Object?>> entries;
  final ValueChanged<int> onSlotsCommit;
  final ValueChanged<List<Map<String, Object?>>> onListCommit;

  const _LegendaryGroup({
    required this.slots,
    required this.entries,
    required this.onSlotsCommit,
    required this.onListCommit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    if (entries.isEmpty && slots == 0 && !editMode) {
      return const SizedBox.shrink();
    }
    return CardFieldGroup(title: 'Legendary Actions', children: [
      Row(
        children: [
          const Text('Slots: ',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(
            width: 48,
            child: InlineIntField(
              value: slots,
              onCommit: onSlotsCommit,
            ),
          ),
        ],
      ),
      for (var i = 0; i < entries.length; i++)
        _ActionEditRow(
          entry: entries[i],
          onNameCommit: (v) {
            final next = _ActionsGroup._cloneEntries(entries);
            next[i] = {...next[i], 'name': v};
            onListCommit(next);
          },
          onDescCommit: (v) {
            final next = _ActionsGroup._cloneEntries(entries);
            final m = {...next[i]};
            if (v.isEmpty) {
              m.remove('description');
            } else {
              m['description'] = v;
            }
            next[i] = m;
            onListCommit(next);
          },
          onDelete: () {
            final next = _ActionsGroup._cloneEntries(entries)
              ..removeAt(i);
            onListCommit(next);
          },
        ),
      if (editMode)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Legendary entry'),
            onPressed: () {
              final next = _ActionsGroup._cloneEntries(entries)
                ..add({
                  'name': 'New Legendary Action',
                  'inner': {'t': 'special', 'name': 'New Legendary Action'},
                });
              onListCommit(next);
            },
          ),
        ),
    ]);
  }
}

class _ActionEditRow extends ConsumerWidget {
  final Map<String, Object?> entry;
  final ValueChanged<String> onNameCommit;
  final ValueChanged<String> onDescCommit;
  final VoidCallback onDelete;

  const _ActionEditRow({
    required this.entry,
    required this.onNameCommit,
    required this.onDescCommit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    final name = (entry['name'] as String?) ?? '';
    final desc = (entry['description'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InlineTextField(
                  value: name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                  onCommit: onNameCommit,
                ),
              ),
              if (editMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
            ],
          ),
          InlineTextField(
            value: desc,
            maxLines: 8,
            placeholder: 'No description — tap to add…',
            onCommit: onDescCommit,
          ),
        ],
      ),
    );
  }
}

String _abilityShort(Ability a) => switch (a) {
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
