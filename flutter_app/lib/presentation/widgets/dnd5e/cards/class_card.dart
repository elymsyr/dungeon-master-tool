import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/dnd5e/content/copy_on_write_helper.dart';
import '../../../../application/providers/campaign_provider.dart';
import '../../../../application/providers/edit_mode_provider.dart';
import '../../../../application/providers/typed_content_provider.dart';
import '../../../../data/database/database_provider.dart';
import '../../../../domain/dnd5e/character/caster_kind.dart';
import '../../../../domain/dnd5e/character/character_class.dart';
import '../../../../domain/dnd5e/character/character_class_json_codec.dart';
import '../../../../domain/dnd5e/core/ability.dart';
import '../../../../domain/dnd5e/core/die.dart';
import '../../../../domain/dnd5e/package/catalog_entry.dart';
import '../card_shell.dart';
import '../inline_field.dart';
import '../inline_field_extras.dart';

/// Typed renderer for a `CharacterClass` progression row.
class ClassCard extends ConsumerStatefulWidget {
  final String entityId;
  final Color categoryColor;

  const ClassCard({
    required this.entityId,
    required this.categoryColor,
    super.key,
  });

  @override
  ConsumerState<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends ConsumerState<ClassCard> {
  late String _effectiveId = widget.entityId;

  @override
  void didUpdateWidget(covariant ClassCard old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) {
      _effectiveId = widget.entityId;
    }
  }

  Future<void> _save(String name, Map<String, Object?> body) async {
    final campaignId = ref.read(activeCampaignIdProvider);
    if (campaignId == null) return;
    final writtenId = await saveEditedEntity(
      db: ref.read(appDatabaseProvider),
      currentId: _effectiveId,
      categorySlug: 'class',
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
    final async = ref.watch(classProgressionRowProvider(_effectiveId));
    return async.when(
      loading: () => const CardPlaceholder('Loading class…'),
      error: (e, _) => CardPlaceholder('Failed to load class: $e'),
      data: (row) {
        if (row == null) {
          return CardPlaceholder('Class "$_effectiveId" not found');
        }
        final CharacterClass cc;
        final Map<String, Object?> body;
        try {
          body = (jsonDecode(row.bodyJson) as Map).cast<String, Object?>();
          cc = characterClassFromEntry(
            CatalogEntry(id: row.id, name: row.name, bodyJson: row.bodyJson),
          );
        } catch (e) {
          return CardPlaceholder('Invalid class body: $e');
        }
        return _ClassBody(
          cc: cc,
          name: row.name,
          body: body,
          categoryColor: widget.categoryColor,
          onSave: _save,
        );
      },
    );
  }
}

class _ClassBody extends ConsumerWidget {
  final CharacterClass cc;
  final String name;
  final Map<String, Object?> body;
  final Color categoryColor;
  final Future<void> Function(String, Map<String, Object?>) onSave;

  const _ClassBody({
    required this.cc,
    required this.name,
    required this.body,
    required this.categoryColor,
    required this.onSave,
  });

  List<Map<String, Object?>> _featureTable() {
    final raw = body['featureTable'];
    if (raw is! List) return <Map<String, Object?>>[];
    return [
      for (final e in raw)
        if (e is Map) e.cast<String, Object?>(),
    ];
  }

  Map<String, Object?> _withFeatureTable(List<Map<String, Object?>> rows) {
    final out = <String, Object?>{...body};
    final sorted = [...rows]
      ..sort((a, b) =>
          ((a['level'] as int?) ?? 0).compareTo((b['level'] as int?) ?? 0));
    if (sorted.isEmpty) {
      out.remove('featureTable');
    } else {
      out['featureTable'] = sorted;
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = _featureTable();
    return CardShell(
      title: name,
      subtitle:
          'Hit Die ${cc.hitDie.name} • ${_casterLabel(cc.casterKind)}',
      categoryColor: categoryColor,
      tags: [
        CardTag('HD ${cc.hitDie.name}'),
        CardTag(_casterLabel(cc.casterKind)),
        if (cc.spellcastingAbility != null)
          CardTag(_ability(cc.spellcastingAbility!)),
      ],
      children: [
        CardFieldGroup(title: 'Identity', children: [
          CardFieldGrid(columns: 2, fields: [
            CardField(
              label: 'Name',
              child: InlineTextField(
                value: name,
                style: Theme.of(context).textTheme.titleMedium,
                onCommit: (v) => onSave(v, body),
              ),
            ),
            CardField(
              label: 'Hit Die',
              child: InlineEnumField<Die>(
                value: cc.hitDie,
                options: const [Die.d6, Die.d8, Die.d10, Die.d12],
                labelOf: (d) => d.notation,
                onCommit: (v) =>
                    onSave(name, {...body, 'hitDie': v.name}),
              ),
            ),
            CardField(
              label: 'Caster',
              child: InlineEnumField<CasterKind>(
                value: cc.casterKind,
                options: CasterKind.values,
                labelOf: _casterLabel,
                onCommit: (v) =>
                    onSave(name, {...body, 'casterKind': v.name}),
              ),
            ),
            CardField(
              label: 'Spellcasting Ability',
              child: _NullableAbilityField(
                value: cc.spellcastingAbility,
                onCommit: (v) {
                  final out = <String, Object?>{...body};
                  if (v == null) {
                    out.remove('spellcastingAbility');
                  } else {
                    out['spellcastingAbility'] = v.name;
                  }
                  onSave(name, out);
                },
              ),
            ),
          ]),
          _SavingThrowsPickerRow(
            selected: cc.savingThrows,
            onCommit: (next) {
              final out = <String, Object?>{...body};
              if (next.isEmpty) {
                out.remove('savingThrows');
              } else {
                out['savingThrows'] =
                    next.map((a) => a.name).toList();
              }
              onSave(name, out);
            },
          ),
        ]),
        _LevelProgressionGroup(
          rows: rows,
          onCommit: (next) => onSave(name, _withFeatureTable(next)),
        ),
        CardFieldGroup(title: 'Description', children: [
          InlineTextField(
            value: cc.description,
            maxLines: 12,
            placeholder: 'No description yet — tap to add…',
            onCommit: (v) => onSave(name, {...body, 'description': v}),
          ),
        ]),
      ],
    );
  }
}

/// Picks any subset of `Ability.values` as checkbox chips. Commits the
/// resulting list in canonical ability order.
class _SavingThrowsPickerRow extends ConsumerWidget {
  final List<Ability> selected;
  final ValueChanged<List<Ability>> onCommit;
  const _SavingThrowsPickerRow({
    required this.selected,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    final set = selected.toSet();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 120,
            child: Text('Saving Throws: ',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in Ability.values)
                  FilterChip(
                    label: Text(_ability(a)),
                    selected: set.contains(a),
                    visualDensity: VisualDensity.compact,
                    onSelected: !editMode
                        ? null
                        : (on) {
                            final next = <Ability>[
                              for (final x in Ability.values)
                                if ((x == a ? on : set.contains(x))) x
                            ];
                            onCommit(next);
                          },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NullableAbilityField extends ConsumerWidget {
  final Ability? value;
  final ValueChanged<Ability?> onCommit;
  const _NullableAbilityField({
    required this.value,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    final label = value == null ? '—' : _ability(value!);
    if (!editMode) return Text(label);
    return PopupMenuButton<Ability?>(
      initialValue: value,
      tooltip: '',
      onSelected: onCommit,
      itemBuilder: (_) => [
        const PopupMenuItem<Ability?>(value: null, child: Text('None')),
        for (final a in Ability.values)
          PopupMenuItem<Ability?>(value: a, child: Text(_ability(a))),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

class _LevelProgressionGroup extends ConsumerWidget {
  final List<Map<String, Object?>> rows;
  final ValueChanged<List<Map<String, Object?>>> onCommit;
  const _LevelProgressionGroup({
    required this.rows,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    if (rows.isEmpty && !editMode) return const SizedBox.shrink();
    return CardFieldGroup(title: 'Level Progression', children: [
      for (var i = 0; i < rows.length; i++)
        _LevelRow(
          index: i,
          row: rows[i],
          onUpdate: (updated) {
            final next = [for (final r in rows) {...r}];
            next[i] = updated;
            onCommit(next);
          },
          onDelete: () {
            final next = [for (final r in rows) {...r}];
            next.removeAt(i);
            onCommit(next);
          },
        ),
      if (editMode)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add level row'),
            onPressed: () {
              final usedLevels = {
                for (final r in rows)
                  if (r['level'] is int) r['level'] as int
              };
              var nextLevel = 1;
              while (usedLevels.contains(nextLevel) && nextLevel <= 20) {
                nextLevel++;
              }
              final next = [
                for (final r in rows) {...r},
                {'level': nextLevel, 'featureIds': <String>[]}
              ];
              onCommit(next);
            },
          ),
        ),
    ]);
  }
}

class _LevelRow extends ConsumerWidget {
  final int index;
  final Map<String, Object?> row;
  final ValueChanged<Map<String, Object?>> onUpdate;
  final VoidCallback onDelete;
  const _LevelRow({
    required this.index,
    required this.row,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider);
    final level = (row['level'] as int?) ?? 1;
    final ids = <String>[
      if (row['featureIds'] is List)
        for (final e in row['featureIds'] as List)
          if (e is String) e
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: editMode
                ? InlineIntField(
                    value: level,
                    onCommit: (v) => onUpdate({...row, 'level': v}),
                  )
                : Text('Lv $level',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: InlineStringListField(
              ids: ids,
              addLabel: 'Add feature',
              onCommit: (next) {
                final out = <String, Object?>{...row};
                if (next.isEmpty) {
                  out.remove('featureIds');
                } else {
                  out['featureIds'] = next;
                }
                onUpdate(out);
              },
            ),
          ),
          if (editMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              tooltip: 'Delete level row',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

String _casterLabel(CasterKind k) => switch (k) {
      CasterKind.none => 'Non-caster',
      CasterKind.full => 'Full Caster',
      CasterKind.half => 'Half Caster',
      CasterKind.third => '1/3 Caster',
      CasterKind.pact => 'Pact Magic',
    };

String _ability(Ability a) => switch (a) {
      Ability.strength => 'STR',
      Ability.dexterity => 'DEX',
      Ability.constitution => 'CON',
      Ability.intelligence => 'INT',
      Ability.wisdom => 'WIS',
      Ability.charisma => 'CHA',
    };

