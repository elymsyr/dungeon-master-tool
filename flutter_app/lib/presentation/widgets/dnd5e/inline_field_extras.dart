import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/edit_mode_provider.dart';
import '../../theme/dm_tool_colors.dart';
import 'entity_link_chip.dart';

/// Yes/No inline toggle. Read-only tap is a no-op; edit-mode tap flips the
/// value. Used for flags like Ritual, Concentration, Attunement Required.
class InlineBoolField extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onCommit;
  final String trueLabel;
  final String falseLabel;

  const InlineBoolField({
    required this.value,
    required this.onCommit,
    this.trueLabel = 'Yes',
    this.falseLabel = 'No',
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final editMode = ref.watch(editModeProvider);
    final label = Text(value ? trueLabel : falseLabel);
    if (!editMode) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: palette.padXs),
        child: label,
      );
    }
    return InkWell(
      onTap: () => onCommit(!value),
      borderRadius: BorderRadius.circular(palette.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: palette.padXs, vertical: palette.padXs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
            ),
            SizedBox(width: palette.gap6),
            label,
          ],
        ),
      ),
    );
  }
}

/// Inline dropdown for a fixed option set. Renders the current label; in
/// edit mode, tap opens a menu to pick a new value.
class InlineEnumField<T> extends ConsumerWidget {
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onCommit;

  const InlineEnumField({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onCommit,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final editMode = ref.watch(editModeProvider);
    final label = Text(labelOf(value));
    if (!editMode) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: palette.padXs),
        child: label,
      );
    }
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: '',
      onSelected: onCommit,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(value: o, child: Text(labelOf(o))),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: palette.padXs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: label),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// A single option surfaced by a [CatalogPicker] — `id` is persisted,
/// `name` is shown.
class CatalogOption {
  final String id;
  final String name;
  const CatalogOption({required this.id, required this.name});
}

/// Inline catalog reference. Read-mode renders an [EntityLinkChip] that
/// navigates to the referenced entity on tap. Edit-mode tap opens a
/// searchable picker over [options]; picking commits the new id via
/// [onCommit]. If [onClear] is supplied, the picker exposes a "Clear"
/// affordance for optional references.
class InlineCatalogRelationField extends ConsumerWidget {
  final String value;
  final List<CatalogOption> options;
  final ValueChanged<String> onCommit;
  final VoidCallback? onClear;
  final String placeholder;

  const InlineCatalogRelationField({
    required this.value,
    required this.options,
    required this.onCommit,
    this.onClear,
    this.placeholder = 'Choose…',
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final editMode = ref.watch(editModeProvider);

    Widget body;
    if (value.isEmpty) {
      body = Text(
        placeholder,
        style: TextStyle(
          color: Theme.of(context).hintColor,
          fontStyle: FontStyle.italic,
        ),
      );
    } else {
      final option = _lookup(value);
      body = EntityLinkChip(
        entityId: value,
        displayLabel: option?.name,
      );
    }

    if (!editMode) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: palette.padXs),
        child: body,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: body),
        SizedBox(width: palette.gap4),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 16,
          icon: const Icon(Icons.edit),
          tooltip: 'Change',
          onPressed: () => _openPicker(context),
        ),
      ],
    );
  }

  CatalogOption? _lookup(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDialog<_PickerResult>(
      context: context,
      builder: (_) => _CatalogPickerDialog(
        options: options,
        initialId: value,
        allowClear: onClear != null,
      ),
    );
    if (picked == null) return;
    if (picked.cleared) {
      onClear?.call();
    } else if (picked.id != null && picked.id != value) {
      onCommit(picked.id!);
    }
  }
}

class _PickerResult {
  final String? id;
  final bool cleared;
  const _PickerResult.pick(this.id) : cleared = false;
  const _PickerResult.clear()
      : id = null,
        cleared = true;
}

class _CatalogPickerDialog extends StatefulWidget {
  final List<CatalogOption> options;
  final String initialId;
  final bool allowClear;

  const _CatalogPickerDialog({
    required this.options,
    required this.initialId,
    required this.allowClear,
  });

  @override
  State<_CatalogPickerDialog> createState() => _CatalogPickerDialogState();
}

/// Inline nullable integer field. Empty string commits as null; non-empty
/// commits as int. Read mode renders `emptyLabel` when null.
class InlineNullableIntField extends ConsumerStatefulWidget {
  final int? value;
  final ValueChanged<int?> onCommit;
  final String emptyLabel;
  final bool allowNegative;

  const InlineNullableIntField({
    required this.value,
    required this.onCommit,
    this.emptyLabel = '—',
    this.allowNegative = false,
    super.key,
  });

  @override
  ConsumerState<InlineNullableIntField> createState() =>
      _InlineNullableIntFieldState();
}

class _InlineNullableIntFieldState
    extends ConsumerState<InlineNullableIntField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value?.toString() ?? '');
    _focus = FocusNode();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant InlineNullableIntField old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _editing) _commit();
  }

  void _commit() {
    final raw = _ctrl.text.trim();
    setState(() => _editing = false);
    if (raw.isEmpty) {
      if (widget.value != null) widget.onCommit(null);
      return;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    if (!widget.allowNegative && parsed < 0) return;
    if (parsed != widget.value) widget.onCommit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<DmToolColors>()!;
    final editMode = ref.watch(editModeProvider);
    if (!editMode && _editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editing) _commit();
      });
    }
    if (_editing && editMode) {
      return TextField(
        controller: _ctrl,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              widget.allowNegative ? RegExp(r'-?[0-9]*') : RegExp(r'[0-9]*')),
        ],
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          isDense: true,
          border: const UnderlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: palette.padXs),
        ),
      );
    }
    final empty = widget.value == null;
    final text = Padding(
      padding: EdgeInsets.symmetric(vertical: palette.padXs),
      child: Text(
        empty ? widget.emptyLabel : widget.value!.toString(),
        style: empty
            ? TextStyle(
                color: theme.hintColor, fontStyle: FontStyle.italic)
            : null,
      ),
    );
    if (!editMode) return text;
    return InkWell(
      onTap: () {
        setState(() => _editing = true);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _focus.requestFocus());
      },
      borderRadius: BorderRadius.circular(palette.radiusSm),
      child: text,
    );
  }
}

/// Edit-mode chip list of arbitrary string ids (no catalog picker). Read
/// mode renders ids as clickable [EntityLinkChip]s; edit mode adds delete
/// per chip + a "+" button that prompts for a new id via a text dialog.
class InlineStringListField extends ConsumerWidget {
  final List<String> ids;
  final ValueChanged<List<String>> onCommit;
  final String addLabel;

  const InlineStringListField({
    required this.ids,
    required this.onCommit,
    this.addLabel = 'Add id',
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final editMode = ref.watch(editModeProvider);
    final children = <Widget>[];
    for (final id in ids) {
      if (!editMode) {
        children.add(EntityLinkChip(entityId: id));
      } else {
        children.add(InputChip(
          label: Text(id.contains(':') ? id.split(':').last : id),
          onDeleted: () =>
              onCommit([for (final x in ids) if (x != id) x]),
          visualDensity: VisualDensity.compact,
        ));
      }
    }
    if (editMode) {
      children.add(ActionChip(
        avatar: const Icon(Icons.add, size: 14),
        label: Text(addLabel),
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          final picked = await _promptForId(context);
          if (picked != null && picked.isNotEmpty && !ids.contains(picked)) {
            onCommit([...ids, picked]);
          }
        },
      ));
    }
    if (children.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: palette.padXs),
        child: Text('—',
            style: TextStyle(
                color: Theme.of(context).hintColor,
                fontStyle: FontStyle.italic)),
      );
    }
    return Wrap(
      spacing: palette.gap4,
      runSpacing: palette.gap4,
      children: children,
    );
  }

  Future<String?> _promptForId(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add reference id'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. srd:rage-1',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// Edit-mode chip list of catalog ids. Read mode renders as clickable
/// [EntityLinkChip]s; edit mode adds a delete button per chip + a "+" to
/// open the catalog picker.
class InlineCatalogChipListField extends ConsumerWidget {
  final List<String> ids;
  final List<CatalogOption> options;
  final ValueChanged<List<String>> onCommit;
  final String addLabel;

  const InlineCatalogChipListField({
    required this.ids,
    required this.options,
    required this.onCommit,
    this.addLabel = 'Add',
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final editMode = ref.watch(editModeProvider);
    final children = <Widget>[];
    for (final id in ids) {
      if (!editMode) {
        children.add(EntityLinkChip(entityId: id));
      } else {
        children.add(InputChip(
          label: Text(id.contains(':') ? id.split(':').last : id),
          onDeleted: () =>
              onCommit([for (final x in ids) if (x != id) x]),
          visualDensity: VisualDensity.compact,
        ));
      }
    }
    if (editMode) {
      children.add(ActionChip(
        avatar: const Icon(Icons.add, size: 14),
        label: Text(addLabel),
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          final picked = await showDialog<_PickerResult>(
            context: context,
            builder: (_) => _CatalogPickerDialog(
              options: [for (final o in options) if (!ids.contains(o.id)) o],
              initialId: '',
              allowClear: false,
            ),
          );
          if (picked?.id != null) onCommit([...ids, picked!.id!]);
        },
      ));
    }
    if (children.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: palette.padXs),
        child: Text('—',
            style: TextStyle(
                color: Theme.of(context).hintColor,
                fontStyle: FontStyle.italic)),
      );
    }
    return Wrap(
      spacing: palette.gap4,
      runSpacing: palette.gap4,
      children: children,
    );
  }
}

class _CatalogPickerDialogState extends State<_CatalogPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((o) {
      if (_query.isEmpty) return true;
      return o.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  hintText: 'Search…',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final o = filtered[i];
                  final selected = o.id == widget.initialId;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    title: Text(o.name),
                    trailing: selected
                        ? const Icon(Icons.check, size: 16)
                        : null,
                    onTap: () => Navigator.of(context)
                        .pop(_PickerResult.pick(o.id)),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  if (widget.allowClear)
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear'),
                      onPressed: () => Navigator.of(context)
                          .pop(const _PickerResult.clear()),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
