import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/services/free_field_styles.dart' show RestEffect;
import '../../../domain/services/free_grants.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/templates/template_settings_forms.dart'
    show styleSettingsFor;
import '../../screens/templates/template_styles.dart' show styleIcon, styleLabel;
import '../../theme/dm_tool_colors.dart';
import '../../theme/markdown_theme.dart';
import '../srd_text.dart';
import 'entity_link.dart';
import 'field_widget_factory.dart' show FieldWidgetFactory;

/// Card widgets of the free level system (docs/free-template/DESIGN.md
/// §8.4 Level table, §8.5 Grants): each card fills in what it grants. The
/// shapes and the engine are in `free_grants.dart`; the Pool's widget is
/// `PoolFieldWidget`.

/// Grants (DESIGN §8.5): the items this card passes to its carrier.
class GrantHolderFieldWidget extends StatelessWidget {
  const GrantHolderFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  @override
  Widget build(BuildContext context) {
    final items = grantItemsOf(value);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            GrantItemList(
              items: items,
              readOnly: readOnly,
              entities: entities,
              ref: ref,
              onChanged: (l) => onChanged([for (final i in l) i.toJson()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Level table (DESIGN §8.4): rows of level · text · grants. [reachedLevel]
/// marks the rows the character it is looked at from has reached (§11.8).
class LevelTableFieldWidget extends StatelessWidget {
  const LevelTableFieldWidget({
    super.key,
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
    this.reachedLevel,
  });

  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final int? reachedLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final rows = levelRowsOf(value);
    void put(List<LevelRow> next) =>
        onChanged([for (final r in next) r.toJson()]);
    void replace(int i, LevelRow r) => put([...rows]..[i] = r);

    String nextId() {
      final used = {for (final r in rows) r.id};
      var n = rows.length + 1;
      while (used.contains('r$n')) {
        n++;
      }
      return 'r$n';
    }

    Widget row(int i, LevelRow r) {
      final reached = reachedLevel != null && r.level <= reachedLevel!;
      return Container(
        key: ValueKey('lt_${r.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          borderRadius: palette.br,
          border: Border(
            left: BorderSide(
              color: reached
                  ? palette.featureCardAccent
                  : palette.featureCardBorder,
              width: 3,
            ),
          ),
          color: reached
              ? palette.featureCardAccent.withValues(alpha: 0.06)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (readOnly)
                  Text(
                    l10n.freeSheetLevel(r.level),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                else
                  SizedBox(
                    width: 84,
                    child: TextFormField(
                      key: ValueKey('lt_${r.id}_level'),
                      initialValue: '${r.level}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: l10n.tplStyleLevel,
                      ),
                      onChanged: (t) {
                        final n = int.tryParse(t.trim());
                        if (n != null && n > 0) {
                          replace(
                            i,
                            LevelRow(
                              id: r.id,
                              level: n,
                              text: r.text,
                              items: r.items,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                if (reached) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: l10n.freeLevelReached,
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: palette.featureCardAccent,
                    ),
                  ),
                ],
                const Spacer(),
                if (!readOnly)
                  IconButton(
                    tooltip: l10n.btnDelete,
                    icon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => put([...rows]..removeAt(i)),
                  ),
              ],
            ),
            if (readOnly && r.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: MarkdownBody(
                  data: r.text,
                  styleSheet: dmMarkdownStyle(context),
                ),
              )
            else if (!readOnly)
              TextFormField(
                key: ValueKey('lt_${r.id}_text'),
                initialValue: r.text,
                minLines: 1,
                maxLines: 6,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.freeLevelText,
                ),
                onChanged: (t) => replace(
                  i,
                  LevelRow(id: r.id, level: r.level, text: t, items: r.items),
                ),
              ),
            const SizedBox(height: 4),
            GrantItemList(
              items: r.items,
              readOnly: readOnly,
              entities: entities,
              ref: ref,
              hideEmpty: true,
              onChanged: (l) => replace(
                i,
                LevelRow(id: r.id, level: r.level, text: r.text, items: l),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (rows.isEmpty && readOnly)
              Text(
                l10n.noItemsLinked,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            for (final (i, r) in rows.indexed) row(i, r),
            if (!readOnly)
              TextButton.icon(
                key: const ValueKey('lt_add_row'),
                onPressed: () => put([
                  ...rows,
                  LevelRow(
                    id: nextId(),
                    level: rows.isEmpty ? 1 : rows.last.level + 1,
                  ),
                ]),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.freeLevelRowAdd),
              ),
          ],
        ),
      ),
    );
  }
}

/// A list of grant items: read, or edited (add, change, delete, reorder).
class GrantItemList extends StatelessWidget {
  const GrantItemList({
    super.key,
    required this.items,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
    this.hideEmpty = false,
  });

  final List<GrantItem> items;
  final bool readOnly;
  final ValueChanged<List<GrantItem>> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  /// A Level table row says nothing when it grants nothing.
  final bool hideEmpty;

  List<EntityCategorySchema> get _categories =>
      ref?.read(worldSchemaProvider).categories ?? const [];

  Future<void> _edit(BuildContext context, GrantItem item, int? index) async {
    final next = await showDialog<GrantItem>(
      context: context,
      builder: (_) => _GrantItemDialog(
        item: item,
        categories: _categories,
        entities: entities,
        ref: ref,
      ),
    );
    if (next == null) return;
    onChanged(index == null ? [...items, next] : ([...items]..[index] = next));
  }

  void _move(int i, int to) {
    final l = [...items];
    l.insert(to, l.removeAt(i));
    onChanged(l);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final muted = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.outline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty && !hideEmpty && readOnly)
          Text(l10n.freeGrantsEmpty, style: muted),
        for (final (i, item) in items.indexed)
          Row(
            key: ValueKey('gi_${item.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _itemView(context, item)),
              if (!readOnly) ...[
                IconButton(
                  tooltip: l10n.btnEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _edit(context, item, i),
                ),
                if (items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: i > 0 ? () => _move(i, i - 1) : null,
                  ),
                IconButton(
                  tooltip: l10n.btnDelete,
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged([...items]..removeAt(i)),
                ),
              ],
            ],
          ),
        if (!readOnly)
          PopupMenuButton<GrantItem>(
            key: const ValueKey('gi_add'),
            tooltip: l10n.btnAdd,
            onSelected: (item) => _edit(context, item, null),
            itemBuilder: (_) {
              final id = nextGrantItemId(items);
              PopupMenuItem<GrantItem> entry(
                GrantItem item,
                IconData icon,
                String label,
              ) => PopupMenuItem(
                value: item,
                child: Row(
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 10),
                    Text(label),
                  ],
                ),
              );
              return [
                entry(
                  GrantItem(id: id, kind: GrantKind.card),
                  Icons.style_outlined,
                  l10n.freeGrantCard,
                ),
                entry(
                  GrantItem(id: id, kind: GrantKind.resource),
                  Icons.battery_5_bar_outlined,
                  l10n.tplStyleResource,
                ),
                for (final t in grantItemStyles)
                  entry(
                    GrantItem(
                      id: id,
                      kind: GrantKind.style,
                      style: t,
                      label: styleLabel(l10n, t),
                    ),
                    styleIcon(t),
                    styleLabel(l10n, t),
                  ),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 18),
                  const SizedBox(width: 6),
                  Text(l10n.freeGrantAdd),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _itemView(BuildContext context, GrantItem item) {
    final l10n = L10n.of(context)!;
    final small = TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.outline,
    );
    switch (item.kind) {
      case GrantKind.card:
        final id = _cardIdIn(item.card, entities);
        final entity = id == null ? null : entities?[id];
        final name = entity != null
            ? srdName(context, entity)
            : (item.card is Map ? '${(item.card as Map)['name'] ?? ''}' : '?');
        final target = item.targets.isEmpty
            ? null
            : [
                for (final MapEntry(:key, :value) in item.targets.entries)
                  _targetLabel(_categories, key, value, L10n.of(context)!),
              ].join(', ');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              const Icon(Icons.style_outlined, size: 14),
              EntityLink(
                targetId: entity == null ? null : id,
                ref: ref,
                entities: entities,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (target != null) Text('→ $target', style: small),
            ],
          ),
        );
      case GrantKind.resource:
        String rest(RestEffect e) => switch (e) {
          RestEffect.fill => l10n.tplRestFill,
          RestEffect.empty => l10n.tplRestEmpty,
          RestEffect.keep => l10n.tplRestKeep,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              const Icon(Icons.battery_5_bar_outlined, size: 14),
              Text(
                '${item.name} · ${l10n.freeMax} ${item.max ?? '—'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${l10n.tplRestShort}: ${rest(item.short)} · '
                '${l10n.tplRestLong}: ${rest(item.long)}',
                style: small,
              ),
            ],
          ),
        );
      case GrantKind.style:
        return FieldWidgetFactory.create(
          schema: item.asField(),
          value: item.value,
          readOnly: true,
          onChanged: (_) {},
          entities: entities,
          ref: ref,
        );
    }
  }
}

/// [raw] (an id or a soft ref) as a card id in [entities].
String? _cardIdIn(Object? raw, Map<String, Entity>? entities) =>
    entities == null ? null : entityLinkTarget(raw, entities);

/// The categories that can carry a card of [slug] — a list takes it, or
/// it falls to their Pool — each with its lists that take it.
List<(EntityCategorySchema, List<FieldSchema>)> _carriersFor(
  List<EntityCategorySchema> categories,
  String slug,
) => [
  for (final c in categories)
    if (carrierListsOf(c).where((f) => listTakes(f, slug)).toList()
        case final lists when lists.isNotEmpty || poolFieldOf(c) != null)
      (c, lists),
];

/// "Category › list" for a target.
String _targetLabel(
  List<EntityCategorySchema> categories,
  String slug,
  String key,
  L10n l10n,
) {
  final c = categories.where((c) => c.slug == slug).firstOrNull;
  final f = c == null
      ? null
      : carrierListsOf(c).where((f) => f.fieldKey == key).firstOrNull;
  final to = key == noGrantTarget
      ? l10n.freeGrantTargetNone
      : f?.label ?? key;
  return '${c?.name ?? slug} › $to';
}

/// Sets up one grant item (DESIGN §8.5): a card and its list, a resource,
/// or another style with its settings and value.
class _GrantItemDialog extends StatefulWidget {
  const _GrantItemDialog({
    required this.item,
    required this.categories,
    this.entities,
    this.ref,
  });

  final GrantItem item;
  final List<EntityCategorySchema> categories;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  @override
  State<_GrantItemDialog> createState() => _GrantItemDialogState();
}

class _GrantItemDialogState extends State<_GrantItemDialog> {
  late GrantItem _item = widget.item;

  static const _settled = {
    FieldType.enum_,
    FieldType.table,
    FieldType.statTable,
  };

  Entity? get _card {
    final id = _cardIdIn(_item.card, widget.entities);
    return id == null ? null : widget.entities?[id];
  }

  bool get _ready => switch (_item.kind) {
    GrantKind.card => _item.card != null,
    GrantKind.resource => _item.name.trim().isNotEmpty,
    GrantKind.style => true,
  };

  Future<void> _pickCard() async {
    final ref = widget.ref;
    if (ref == null) return;
    final picked = await showEntitySelectorDialog(
      context: context,
      ref: ref,
      includeBuiltinSrd: true,
      extraEntities: widget.entities?.values.toList() ?? const [],
    );
    final id = picked?.firstOrNull;
    if (id == null || !mounted) return;
    setState(() => _item = _item.copyWith(card: () => id, targets: const {}));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final item = _item;
    final children = switch (item.kind) {
      GrantKind.card => _cardForm(l10n),
      GrantKind.resource => _resourceForm(l10n),
      GrantKind.style => _styleForm(l10n),
    };
    return AlertDialog(
      title: Text(switch (item.kind) {
        GrantKind.card => l10n.freeGrantCard,
        GrantKind.resource => l10n.tplStyleResource,
        GrantKind.style => styleLabel(l10n, item.style ?? FieldType.text),
      }),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          key: const ValueKey('gi_save'),
          onPressed: _ready ? () => Navigator.pop(context, _item) : null,
          child: Text(l10n.btnSave),
        ),
      ],
    );
  }

  List<Widget> _cardForm(L10n l10n) {
    final card = _card;
    final carriers = card == null
        ? const <(EntityCategorySchema, List<FieldSchema>)>[]
        : _carriersFor(widget.categories, card.categorySlug);
    return [
      OutlinedButton.icon(
        key: const ValueKey('gi_pick_card'),
        onPressed: _pickCard,
        icon: const Icon(Icons.style_outlined, size: 18),
        label: Text(
          card != null
              ? srdName(context, card)
              : (_item.card is Map
                    ? '${(_item.card as Map)['name'] ?? ''}'
                    : l10n.freeGrantPickCard),
        ),
      ),
      // Per carrier category its own list (a feat may go to a monster
      // and to a player).
      if (card != null) ...[
        const SizedBox(height: 12),
        Text(
          l10n.freeGrantTarget,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        // No list takes it (built-in has two "Action"s: the Tier 0 lookup
        // and Tier 1 content): say why instead of an empty section.
        if (carriers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.freeGrantNoTarget,
              key: const ValueKey('gi_no_target'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        for (final (c, lists) in carriers)
          DropdownButtonFormField<String?>(
            key: ValueKey('gi_target_${c.slug}'),
            initialValue:
                _item.targets[c.slug] == noGrantTarget ||
                    lists.any((f) => f.fieldKey == _item.targets[c.slug])
                ? _item.targets[c.slug]
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: c.name),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  lists.isEmpty
                      ? l10n.tplStylePool
                      : l10n.freeGrantTargetAuto,
                ),
              ),
              for (final f in lists)
                DropdownMenuItem(
                  value: f.fieldKey,
                  child: Text(f.label, overflow: TextOverflow.ellipsis),
                ),
              DropdownMenuItem(
                value: noGrantTarget,
                child: Text(l10n.freeGrantTargetNone),
              ),
            ],
            onChanged: (v) => setState(
              () => _item = _item.copyWith(
                targets: {
                  for (final e in _item.targets.entries)
                    if (e.key != c.slug) e.key: e.value,
                  c.slug: ?v,
                },
              ),
            ),
          ),
      ],
    ];
  }

  List<Widget> _resourceForm(L10n l10n) {
    final rests = {
      RestEffect.fill: l10n.tplRestFill,
      RestEffect.empty: l10n.tplRestEmpty,
      RestEffect.keep: l10n.tplRestKeep,
    };
    Widget rest(String label, RestEffect value, ValueChanged<RestEffect> on) =>
        DropdownButtonFormField<RestEffect>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final e in rests.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => on(v));
          },
        );
    return [
      TextFormField(
        key: const ValueKey('gi_res_name'),
        initialValue: _item.name,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.tplName),
        onChanged: (t) => setState(() => _item = _item.copyWith(name: t)),
      ),
      TextFormField(
        key: const ValueKey('gi_res_max'),
        initialValue: _item.max?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: l10n.freeMax,
          helperText: l10n.freeGrantMaxOpen,
        ),
        onChanged: (t) => setState(
          () => _item = _item.copyWith(max: () => int.tryParse(t.trim())),
        ),
      ),
      const SizedBox(height: 8),
      rest(
        l10n.tplRestShort,
        _item.short,
        (v) => _item = _item.copyWith(short: v),
      ),
      rest(l10n.tplRestLong, _item.long, (v) => _item = _item.copyWith(long: v)),
    ];
  }

  List<Widget> _styleForm(L10n l10n) {
    final field = _item.asField();
    return [
      TextFormField(
        key: const ValueKey('gi_style_label'),
        initialValue: _item.label,
        decoration: InputDecoration(labelText: l10n.tplFieldLabel),
        onChanged: (t) => setState(() => _item = _item.copyWith(label: t)),
      ),
      const SizedBox(height: 8),
      if (_settled.contains(field.fieldType))
        ...styleSettingsFor(
          context,
          field,
          (f) => setState(
            () => _item = _item.copyWith(
              config: () => {
                ...?f.styleConfig,
                if (f.validation.allowedValues != null)
                  'options': f.validation.allowedValues,
              },
            ),
          ),
          categories: widget.categories,
        ),
      const SizedBox(height: 8),
      FieldWidgetFactory.create(
        schema: field,
        value: _item.value,
        readOnly: false,
        onChanged: (v) => setState(() => _item = _item.copyWith(value: () => v)),
        entities: widget.entities,
        ref: widget.ref,
      ),
    ];
  }
}
