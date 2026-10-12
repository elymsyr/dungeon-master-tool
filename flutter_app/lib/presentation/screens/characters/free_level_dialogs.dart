import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/services/free_grants.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../theme/markdown_theme.dart';
import '../../widgets/srd_text.dart';

/// The free level system's dialogs (docs/free-template/DESIGN.md §11.4–
/// §11.7): the level up pick, the summary, the levels, and the offer to
/// take back cards nothing grants any more.

String _name(BuildContext context, Map<String, Entity> entities, String id) {
  final e = entities[id];
  return e == null ? id : srdName(context, e);
}

/// One pick per separate category (DESIGN §11.4): a card it holds goes up
/// by one, or a new one joins at level 1. A category with one card has it
/// picked (V13). Null when cancelled.
Future<({Map<String, String> picked, Map<String, String> added})?>
showFreeLevelUpDialog(
  BuildContext context,
  WidgetRef ref, {
  required int from,
  required List<LevelUpGroup> groups,
  required Map<String, Entity> entities,
}) => showDialog(
  context: context,
  builder: (_) => _LevelUpDialog(
    ref: ref,
    from: from,
    groups: groups,
    entities: entities,
  ),
);

/// The "new card" choice of a group.
const _newCard = '';

class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({
    required this.ref,
    required this.from,
    required this.groups,
    required this.entities,
  });

  final WidgetRef ref;
  final int from;
  final List<LevelUpGroup> groups;
  final Map<String, Entity> entities;

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog> {
  /// Category slug → picked card id, or [_newCard].
  late final Map<String, String> _pick = {
    for (final g in widget.groups)
      if (g.cards.length == 1) g.category.slug: g.cards.single.id,
  };

  bool get _ready => widget.groups.every((g) => _pick[g.category.slug] != null);

  Future<void> _continue() async {
    final picked = <String, String>{};
    final added = <String, String>{};
    for (final g in widget.groups) {
      final p = _pick[g.category.slug]!;
      if (p != _newCard) {
        picked[g.category.slug] = p;
        continue;
      }
      final ids = await showEntitySelectorDialog(
        context: context,
        ref: widget.ref,
        allowedTypes: [g.category.slug],
        excludeIds: [for (final c in g.cards) c.id],
        includeBuiltinSrd: true,
        extraEntities: widget.entities.values.toList(),
      );
      final id = ids?.firstOrNull;
      if (id == null || !mounted) return;
      added[g.category.slug] = id;
    }
    if (mounted) Navigator.pop(context, (picked: picked, added: added));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    return AlertDialog(
      title: Text(l10n.freeLevelUpTitle(widget.from, widget.from + 1)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.groups.isEmpty) Text(l10n.freeLevelUpNone),
              for (final g in widget.groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    l10n.freeLevelUpPick(g.category.name),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                RadioGroup<String>(
                  groupValue: _pick[g.category.slug],
                  onChanged: (v) {
                    if (v != null) setState(() => _pick[g.category.slug] = v);
                  },
                  child: Column(
                    children: [
                      for (final c in g.cards)
                        RadioListTile<String>(
                          key: ValueKey('lu_${c.id}'),
                          dense: true,
                          value: c.id,
                          title: Text(_name(context, widget.entities, c.id)),
                          secondary: Text('${c.level} → ${c.level + 1}'),
                        ),
                      RadioListTile<String>(
                        key: ValueKey('lu_new_${g.category.slug}'),
                        dense: true,
                        value: _newCard,
                        title: Text(l10n.freeLevelUpNew(g.category.name)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          key: const ValueKey('lu_continue'),
          onPressed: _ready ? _continue : null,
          child: Text(l10n.btnContinue),
        ),
      ],
    );
  }
}

/// What a change granted (DESIGN §11.4's summary): cards added, what came
/// into the Pool, rows to read, resources, cards with nowhere to go.
Future<void> showGrantSummaryDialog(
  BuildContext context, {
  required String title,
  required GrantSummary summary,
  required Map<String, Entity> entities,
  Map<String, String> listLabels = const {},
}) {
  final l10n = L10n.of(context)!;
  final palette = Theme.of(context).extension<DmToolColors>()!;
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: palette.sidebarLabelSecondary,
      ),
    ),
  );
  String name(String id) => _name(context, entities, id);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.isEmpty) Text(l10n.freeSummaryNothing),
              if (summary.added.isNotEmpty) ...[
                heading(l10n.freeSummaryAdded),
                for (final g in summary.added)
                  Text(
                    '• ${name(g.cardId)} → ${listLabels[g.listKey] ?? g.listKey}',
                  ),
              ],
              if (summary.toPool.isNotEmpty) ...[
                heading(l10n.freeSummaryPool),
                for (final e in summary.toPool)
                  Text(
                    '• ${e.cardId != null ? name(e.cardId!) : e.item.label} '
                    '(${l10n.freeGrantedFromCard(name(e.fromId))})',
                  ),
              ],
              if (summary.reads.isNotEmpty) ...[
                heading(l10n.freeSummaryReads),
                for (final r in summary.reads)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: MarkdownBody(
                      data: '**${name(r.cardId)} ${r.level}:** ${r.text}',
                      styleSheet: dmMarkdownStyle(ctx),
                    ),
                  ),
              ],
              if (summary.resources.isNotEmpty) ...[
                heading(l10n.freeSummaryResources),
                for (final r in summary.resources)
                  Text('• ${r.name}   ${r.from ?? '—'} → ${r.to ?? '—'}'),
              ],
              if (summary.homeless.isNotEmpty) ...[
                heading(l10n.freeSummaryHomeless),
                for (final id in summary.homeless) Text('• ${name(id)}'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('summary_done'),
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.btnDone),
        ),
      ],
    ),
  );
}

/// V12: these labelled cards are granted by nothing any more; true when
/// the player takes them out.
Future<bool> confirmRemoveGranted(
  BuildContext context, {
  required List<String> ids,
  required Map<String, Entity> entities,
}) async {
  final l10n = L10n.of(context)!;
  final names = [for (final id in ids) _name(context, entities, id)];
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.freeRemoveGrantedTitle),
      content: Text(l10n.freeRemoveGrantedBody(names.join(', '))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          key: const ValueKey('remove_granted'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.btnRemove),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// The main level and each own card's level in a separate category, set by
/// hand (DESIGN §11.7); null when cancelled. Lowering one offers to take
/// back what the lost rows granted (the caller's [settleGrants]).
Future<Map<String, dynamic>?> showFreeLevelsDialog(
  BuildContext context, {
  required Map<String, dynamic> fields,
  required GrantContext ctx,
}) => showDialog(
  context: context,
  builder: (_) => _LevelsDialog(fields: fields, ctx: ctx),
);

class _LevelsDialog extends StatefulWidget {
  const _LevelsDialog({required this.fields, required this.ctx});

  final Map<String, dynamic> fields;
  final GrantContext ctx;

  @override
  State<_LevelsDialog> createState() => _LevelsDialogState();
}

class _LevelsDialogState extends State<_LevelsDialog> {
  late int? _main = mainLevelOf(widget.ctx.carrier, widget.fields);
  late final Map<String, int> _cards = {
    for (final g in levelUpGroups(widget.fields, widget.ctx))
      for (final c in g.cards) c.id: c.level,
  };

  Map<String, dynamic> _result() {
    final out = Map<String, dynamic>.from(widget.fields);
    final levelField = levelFieldOf(widget.ctx.carrier);
    if (levelField != null && _main != null) out[levelField.fieldKey] = _main;
    out[cardLevelsKey] = {...cardLevelsOf(widget.fields), ..._cards};
    return out;
  }

  Widget _number(String key, String label, int? value, ValueChanged<int> on) =>
      TextFormField(
        key: ValueKey(key),
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (t) {
          final n = int.tryParse(t.trim());
          if (n != null && n > 0) setState(() => on(n));
        },
      );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final entities = widget.ctx.entities;
    return AlertDialog(
      title: Text(l10n.freeLevelsTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _number(
                'levels_main',
                l10n.freeMainLevel,
                _main,
                (n) => _main = n,
              ),
              for (final e in _cards.entries)
                _number(
                  'levels_${e.key}',
                  _name(context, entities, e.key),
                  e.value,
                  (n) => _cards[e.key] = n,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          key: const ValueKey('levels_save'),
          onPressed: () => Navigator.pop(context, _result()),
          child: Text(l10n.btnSave),
        ),
      ],
    );
  }
}
