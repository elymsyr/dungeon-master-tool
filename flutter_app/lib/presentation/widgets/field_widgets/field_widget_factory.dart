import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/media_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/dnd5e_constants.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/rule_v2.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../dialogs/media_gallery_dialog.dart';
import '../../theme/dm_tool_colors.dart';
import '../markdown_text_area.dart';

/// Schema-driven field widget factory.
/// Her FieldType için uygun widget döndürür.
class FieldWidgetFactory {
  static Widget create({
    required FieldSchema schema,
    required dynamic value,
    required bool readOnly,
    required ValueChanged<dynamic> onChanged,
    Map<String, Entity>? entities,
    WidgetRef? ref,
    bool computedMode = false,
    Map<String, ItemStyle> itemStyles = const {},
    Map<String, String> equipGates = const {},
    /// Aynı entity'deki diğer field değerleri — proficiencyTable gibi
    /// cross-field lookup (stat_block, proficiency_bonus) gereksinimleri için.
    Map<String, dynamic>? entityFields,
    /// Inline-list rendering: relation lists collapse to a single comma-separated
    /// row instead of a Card with per-row entries. Used in grouped multi-column
    /// layouts where the tall Card breaks row alignment.
    bool compact = false,
  }) {
    // Media directory — image field'ları için galeri desteği.
    final mediaDir = ref?.read(mediaDirectoryProvider);

    // isList → genel liste widget'ı
    if (schema.isList) {
      if (schema.fieldType == FieldType.relation) {
        if (compact) {
          return _InlineRelationListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref);
        }
        return _ReferenceListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref, computedMode: computedMode, itemStyles: itemStyles, equipGates: equipGates);
      }
      if (schema.fieldType == FieldType.image) {
        return _ImageFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, mediaDir: mediaDir);
      }
      return _GenericListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged);
    }

    return switch (schema.fieldType) {
      FieldType.text => _TextFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.textarea => _TextAreaFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities),
      FieldType.markdown => _MarkdownFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref),
      FieldType.integer => _IntegerFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.enum_ => _EnumFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.relation => _RelationFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref),
      FieldType.statBlock => _StatBlockFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.combatStats => _CombatStatsFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.conditionStats => _CombatStatsFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.dice => _DiceFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.boolean_ => _BooleanFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.slot => _SlotFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entityFields: entityFields, ruleDriven: computedMode),
      FieldType.levelTable => _LevelTableFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.levelTextTable => _LevelTextTableFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.proficiencyTable => _ProficiencyTableFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entityFields: entityFields),
      FieldType.tagList => _TagListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.date => _DateFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.image => _ImageFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, mediaDir: mediaDir),
      FieldType.file => _FileFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.pdf => _PdfFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, ref: ref),
      _ => _TextFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
    };
  }
}

/// Unified field row: fixed-width bold label on left, value/input on right.
/// Keeps every scalar field aligned at the same baseline. Always renders even
/// when the value is empty.
class _LabeledFieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  final CrossAxisAlignment alignment;

  static const double labelWidth = 140;

  const _LabeledFieldRow({
    required this.label,
    required this.child,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: alignment,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 1),
              child: Text(
                '$label:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette?.srdInk ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

TextStyle _fieldValueStyle(BuildContext context) {
  final palette = Theme.of(context).extension<DmToolColors>();
  return TextStyle(fontSize: 13, color: palette?.srdInk ?? Theme.of(context).colorScheme.onSurface);
}

TextStyle _fieldEmptyStyle(BuildContext context) {
  return TextStyle(
    fontSize: 13,
    fontStyle: FontStyle.italic,
    color: Theme.of(context).colorScheme.outline,
  );
}

// --- TEXT ---
class _TextFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _TextFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  State<_TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<_TextFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _TextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.value?.toString() ?? '';
    if (widget.readOnly && text.isEmpty) return const SizedBox.shrink();
    return _LabeledFieldRow(
      label: widget.schema.label,
      child: widget.readOnly
          ? Text(text, style: _fieldValueStyle(context))
          : TextFormField(
              key: ValueKey('${widget.schema.fieldKey}_text'),
              controller: _controller,
              style: _fieldValueStyle(context),
              decoration: InputDecoration(
                hintText: widget.schema.placeholder.isNotEmpty ? widget.schema.placeholder : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              onChanged: (v) => widget.onChanged(v),
            ),
    );
  }
}

// --- TEXTAREA (with markdown view + @mention) ---
class _TextAreaFieldWidget extends ConsumerStatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;

  const _TextAreaFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged, this.entities});

  @override
  ConsumerState<_TextAreaFieldWidget> createState() => _TextAreaFieldWidgetState();
}

class _TextAreaFieldWidgetState extends ConsumerState<_TextAreaFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _TextAreaFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final inkColor = palette?.srdInk ?? Theme.of(context).colorScheme.onSurface;
    final headingColor = palette?.srdHeadingRed ?? Theme.of(context).colorScheme.primary;
    final text = widget.value?.toString() ?? '';
    if (widget.readOnly && text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.schema.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: headingColor)),
          const SizedBox(height: 4),
          MarkdownTextArea(
            key: ValueKey('${widget.schema.fieldKey}_area'),
            controller: _controller,
            readOnly: widget.readOnly,
            maxLines: widget.readOnly ? null : 4,
            textStyle: TextStyle(fontSize: 13, color: inkColor),
            decoration: InputDecoration(
              hintText: 'Markdown supported (@ to mention)',
              hintStyle: TextStyle(color: palette?.srdSubtitle, fontSize: 12, fontStyle: FontStyle.italic),
              isDense: true,
            ),
            onChanged: (v) => widget.onChanged(v),
          ),
        ],
      ),
    );
  }
}

// --- MARKDOWN (with edit/preview toggle + @mention) ---
class _MarkdownFieldWidget extends ConsumerStatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const _MarkdownFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  @override
  ConsumerState<_MarkdownFieldWidget> createState() => _MarkdownFieldWidgetState();
}

class _MarkdownFieldWidgetState extends ConsumerState<_MarkdownFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _MarkdownFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newText = widget.value?.toString() ?? '';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final inkColor = palette?.srdInk ?? Theme.of(context).colorScheme.onSurface;
    final headingColor = palette?.srdHeadingRed ?? Theme.of(context).colorScheme.primary;

    if (widget.readOnly) {
      final text = widget.value?.toString() ?? '';
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.schema.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: headingColor)),
            const SizedBox(height: 4),
            MarkdownTextArea(
              controller: _controller,
              readOnly: true,
              textStyle: TextStyle(fontSize: 13, color: inkColor),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.schema.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: headingColor)),
          const SizedBox(height: 4),
          MarkdownTextArea(
            controller: _controller,
            minLines: 4,
            textStyle: TextStyle(fontSize: 13, color: inkColor),
            decoration: InputDecoration(
              hintText: 'Markdown supported. Use @ to mention entities.',
              hintStyle: TextStyle(color: palette?.srdSubtitle, fontSize: 12, fontStyle: FontStyle.italic),
              isDense: true,
            ),
            onChanged: (v) => widget.onChanged(v),
          ),
        ],
      ),
    );
  }
}

// --- INTEGER ---
class _IntegerFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _IntegerFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  State<_IntegerFieldWidget> createState() => _IntegerFieldWidgetState();
}

class _IntegerFieldWidgetState extends State<_IntegerFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _IntegerFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.value;
    final hasValue = raw != null && raw.toString().isNotEmpty;
    if (widget.readOnly && !hasValue) return const SizedBox.shrink();
    return _LabeledFieldRow(
      label: widget.schema.label,
      child: widget.readOnly
          ? Text(raw.toString(), style: _fieldValueStyle(context))
          : TextFormField(
              key: ValueKey('${widget.schema.fieldKey}_int'),
              controller: _controller,
              keyboardType: TextInputType.number,
              style: _fieldValueStyle(context),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
            ),
    );
  }
}

// --- ENUM (Dropdown) ---
class _EnumFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _EnumFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = schema.validation.allowedValues ?? [];
    final currentVal = value?.toString();
    final hasValue = currentVal != null && currentVal.isNotEmpty;

    if (readOnly && !hasValue) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      child: readOnly
          ? Text(currentVal!, style: _fieldValueStyle(context))
          : DropdownButtonFormField<String>(
              initialValue: options.contains(currentVal) ? currentVal : null,
              isDense: true,
              isExpanded: true,
              iconSize: 18,
              style: _fieldValueStyle(context),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => onChanged(v),
            ),
    );
  }
}

// --- RELATION (Entity Reference) ---
// --- SINGLE RELATION — entity adı gösteren + selector dialog ---
class _RelationFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const _RelationFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged, this.entities, this.ref});

  @override
  Widget build(BuildContext context) {
    final linkedId = value?.toString() ?? '';
    final linkedName = (linkedId.isNotEmpty && entities != null) ? entities![linkedId]?.name ?? linkedId : '';
    final hasValue = linkedId.isNotEmpty;

    if (readOnly && !hasValue) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      child: Row(
        children: [
          Expanded(
            child: hasValue
                ? Text(linkedName, style: _fieldValueStyle(context), overflow: TextOverflow.ellipsis)
                : Text('—', style: _fieldEmptyStyle(context)),
          ),
          if (!readOnly && hasValue)
            InkWell(
              onTap: () => onChanged(''),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          if (!readOnly)
            InkWell(
              onTap: () async {
                if (ref == null) return;
                final result = await showEntitySelectorDialog(
                  context: context,
                  ref: ref!,
                  allowedTypes: schema.validation.allowedTypes,
                );
                if (result != null && result.isNotEmpty) {
                  onChanged(result.first);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.search, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// --- STAT BLOCK (STR/DEX/CON/INT/WIS/CHA) ---
class _StatBlockFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _StatBlockFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  State<_StatBlockFieldWidget> createState() => _StatBlockFieldWidgetState();
}

class _StatBlockFieldWidgetState extends State<_StatBlockFieldWidget> {
  static const _keys = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
  final Map<String, TextEditingController> _controllers = {};

  Map<String, dynamic> get _stats =>
      (widget.value is Map) ? Map<String, dynamic>.from(widget.value as Map) : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final stats = _stats;
    for (final key in _keys) {
      _controllers[key] = TextEditingController(text: (stats[key] ?? 10).toString());
    }
  }

  @override
  void didUpdateWidget(covariant _StatBlockFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final stats = _stats;
      for (final key in _keys) {
        final newText = (stats[key] ?? 10).toString();
        final ctrl = _controllers[key]!;
        if (ctrl.text != newText) {
          ctrl.text = newText;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: _keys.map((key) {
                final val = stats[key] ?? 10;
                final mod = ((val is int ? val : 10) - 10) ~/ 2;
                final modStr = mod >= 0 ? '+$mod' : '$mod';

                return Expanded(
                  child: Column(
                    children: [
                      Text(key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 44,
                        child: TextFormField(
                          key: ValueKey('sb_$key'),
                          controller: _controllers[key],
                          readOnly: widget.readOnly,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            final updated = Map<String, dynamic>.from(stats);
                            updated[key] = int.tryParse(v) ?? 10;
                            widget.onChanged(updated);
                          },
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(modStr, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- COMBAT STATS (HP, AC, Speed, etc.) ---
class _CombatStatsFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _CombatStatsFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  State<_CombatStatsFieldWidget> createState() => _CombatStatsFieldWidgetState();
}

class _CombatStatsFieldWidgetState extends State<_CombatStatsFieldWidget> {
  final Map<String, TextEditingController> _controllers = {};

  Map<String, dynamic> get _stats =>
      (widget.value is Map) ? Map<String, dynamic>.from(widget.value as Map) : <String, dynamic>{};

  List<(String, String, String)> get _fields => widget.schema.subFields.isNotEmpty
      ? widget.schema.subFields.map((sf) => (sf['key'] ?? '', sf['label'] ?? sf['key'] ?? '', sf['type'] ?? 'text')).toList()
      : const [('hp', 'HP', 'integer'), ('max_hp', 'Max HP', 'integer'), ('ac', 'AC', 'integer'), ('speed', 'Speed', 'text'), ('initiative', 'Init', 'integer'), ('cr', 'CR', 'text'), ('xp', 'XP', 'integer')];

  @override
  void initState() {
    super.initState();
    final stats = _stats;
    for (final f in _fields) {
      _controllers[f.$1] = TextEditingController(text: stats[f.$1]?.toString() ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant _CombatStatsFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final stats = _stats;
      for (final f in _fields) {
        final newText = stats[f.$1]?.toString() ?? '';
        final ctrl = _controllers[f.$1];
        if (ctrl != null && ctrl.text != newText) {
          ctrl.text = newText;
        } else if (ctrl == null) {
          _controllers[f.$1] = TextEditingController(text: newText);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final fields = _fields;
    final gridFields = fields.where((f) => f.$3 != 'textarea').toList();
    final textareaFields = fields.where((f) => f.$3 == 'textarea').toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (gridFields.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = (constraints.maxWidth / 88).floor().clamp(1, gridFields.length);
                  final rows = <Widget>[];
                  for (var i = 0; i < gridFields.length; i += cols) {
                    final rowFields = gridFields.sublist(i, (i + cols).clamp(0, gridFields.length));
                    rows.add(Padding(
                      padding: EdgeInsets.only(bottom: i + cols < gridFields.length ? 8 : 0),
                      child: Row(
                        children: rowFields.map((f) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: f != rowFields.last ? 8 : 0),
                              child: TextFormField(
                                key: ValueKey('cs_${f.$1}'),
                                controller: _controllers[f.$1],
                                readOnly: widget.readOnly,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: f.$2,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                ),
                                onChanged: (v) {
                                  final updated = Map<String, dynamic>.from(stats);
                                  updated[f.$1] = v;
                                  widget.onChanged(updated);
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ));
                  }
                  return Column(children: rows);
                },
              ),
            // Textarea sub-fields rendered full-width below the grid (markdown + @mention)
            ...textareaFields.map((f) {
              final ctrl = _controllers[f.$1];
              final p = Theme.of(context).extension<DmToolColors>();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p?.tabText)),
                    const SizedBox(height: 4),
                    MarkdownTextArea(
                      key: ValueKey('cs_${f.$1}'),
                      controller: ctrl!,
                      readOnly: widget.readOnly,
                      maxLines: widget.readOnly ? null : 3,
                      textStyle: TextStyle(fontSize: 13, color: p?.htmlText),
                      decoration: InputDecoration(
                        hintText: '@ to mention entities',
                        isDense: true,
                        alignLabelWithHint: true,
                      ),
                      onChanged: (v) {
                        final updated = Map<String, dynamic>.from(stats);
                        updated[f.$1] = v;
                        widget.onChanged(updated);
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- GENERIC LIST — herhangi tipin listesi (text list, integer list, image list...) ---
class _GenericListFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _GenericListFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  State<_GenericListFieldWidget> createState() => _GenericListFieldWidgetState();
}

class _GenericListFieldWidgetState extends State<_GenericListFieldWidget> {
  final List<TextEditingController> _controllers = [];

  List<String> get _items =>
      (widget.value is List) ? List<String>.from((widget.value as List).map((e) => e.toString())) : <String>[];

  @override
  void initState() {
    super.initState();
    _syncControllers(_items);
  }

  @override
  void didUpdateWidget(covariant _GenericListFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncControllers(_items);
    }
  }

  void _syncControllers(List<String> items) {
    // Adjust controller list length
    while (_controllers.length < items.length) {
      _controllers.add(TextEditingController());
    }
    while (_controllers.length > items.length) {
      _controllers.removeLast().dispose();
    }
    // Update text for controllers whose text differs
    for (var i = 0; i < items.length; i++) {
      if (_controllers[i].text != items[i]) {
        _controllers[i].text = items[i];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final typeName = widget.schema.fieldType.name;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${widget.schema.label} (${items.length})', style: Theme.of(context).textTheme.titleSmall)),
                Text(typeName, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                if (!widget.readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () {
                      final updated = List<String>.from(items)..add('');
                      widget.onChanged(updated);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No items', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              ),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('${i + 1}.', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${widget.schema.fieldKey}_list_$i'),
                        controller: _controllers.length > i ? _controllers[i] : null,
                        readOnly: widget.readOnly,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(isDense: true, filled: false, border: InputBorder.none),
                        keyboardType: widget.schema.fieldType == FieldType.integer ? TextInputType.number : null,
                        onChanged: (v) {
                          final updated = List<String>.from(items);
                          updated[i] = v;
                          widget.onChanged(updated);
                        },
                      ),
                    ),
                    if (!widget.readOnly)
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          final updated = List<String>.from(items)..removeAt(i);
                          widget.onChanged(updated);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- REFERENCE LIST — equip destekli kategori referans listesi ---
class _ReferenceListFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool computedMode; // true = add/remove yok, equip sadece equipped kaynaklar için
  final Map<String, ItemStyle> itemStyles;
  final Map<String, String> equipGates;

  const _ReferenceListFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged, this.entities, this.ref, this.computedMode = false, this.itemStyles = const {}, this.equipGates = const {}});

  @override
  State<_ReferenceListFieldWidget> createState() => _ReferenceListFieldWidgetState();
}

class _ReferenceListFieldWidgetState extends State<_ReferenceListFieldWidget> {
  bool _showAllSources = false;

  FieldSchema get schema => widget.schema;
  dynamic get value => widget.value;
  bool get readOnly => widget.readOnly;
  ValueChanged<dynamic> get onChanged => widget.onChanged;
  Map<String, Entity>? get entities => widget.entities;
  WidgetRef? get ref => widget.ref;
  bool get computedMode => widget.computedMode;
  Map<String, ItemStyle> get itemStyles => widget.itemStyles;
  Map<String, String> get equipGates => widget.equipGates;

  @override
  Widget build(BuildContext context) {
    // Değer iki formatta olabilir:
    // 1) List<String> — basit ID listesi (equip yok)
    // 2) List<Map> — [{id: 'xxx', equipped: true, source: 'manual'|'rule:<id>'}, ...]
    final items = _parseItems(value);
    final targetTypes = schema.validation.allowedTypes?.join(', ') ?? 'any';
    final showEquip = schema.hasEquip;
    final hasRuleSourced = items.any((i) {
      final src = i['source']?.toString() ?? 'manual';
      return src != 'manual';
    });
    final filterActive = schema.showSourceFilter && hasRuleSourced;
    // (origIndex, item) pairs — origIndex used for in-place mutation,
    // avoids O(N²) items.indexOf during render.
    final visibleItems = <MapEntry<int, Map<String, dynamic>>>[];
    for (var idx = 0; idx < items.length; idx++) {
      final it = items[idx];
      if (filterActive && !_showAllSources && it['equipped'] != true) continue;
      visibleItems.add(MapEntry(idx, it));
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${schema.label} (${visibleItems.length}${filterActive ? '/${items.length}' : ''})', style: Theme.of(context).textTheme.titleSmall)),
                Flexible(
                  child: Text(
                    '→ $targetTypes',
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (filterActive)
                  IconButton(
                    tooltip: _showAllSources ? 'Showing all sources' : 'Showing only equipped',
                    icon: Icon(
                      _showAllSources ? Icons.visibility : Icons.visibility_off,
                      size: 16,
                      color: _showAllSources
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    onPressed: () => setState(() => _showAllSources = !_showAllSources),
                    visualDensity: VisualDensity.compact,
                  ),
                if (!readOnly && !computedMode)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () async {
                      if (ref == null) return;
                      final existingIds = items.map((e) => e['id']?.toString() ?? '').toList();
                      final result = await showEntitySelectorDialog(
                        context: context,
                        ref: ref!,
                        allowedTypes: schema.validation.allowedTypes,
                        multiSelect: true,
                        excludeIds: existingIds,
                      );
                      if (result != null) {
                        for (final id in result) {
                          items.add({'id': id, 'equipped': false, 'source': 'manual'});
                        }
                        onChanged(_serializeItems(items, showEquip));
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (visibleItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  filterActive && !_showAllSources
                      ? 'No equipped items — toggle to see all sources'
                      : 'No items linked',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                ),
              ),
            ...visibleItems.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isEquipped = item['equipped'] == true;
              final itemId = item['id']?.toString() ?? '';
              final source = item['source']?.toString() ?? 'manual';
              final isRuleSourced = source != 'manual';
              final style = itemStyles[itemId];
              final gateReason = equipGates[itemId];
              final isGated = gateReason != null && gateReason.isNotEmpty;

              Widget itemRow = Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    // Equip toggle
                    if (showEquip || computedMode) ...[
                      SizedBox(
                        width: 28,
                        child: Builder(builder: (context) {
                          // Computed mode: kaynak not equipped → disabled
                          final sourceActive = item['_sourceActive'] != false;
                          final sourceDisabled = computedMode && !sourceActive;
                          // Gate: equip koşulu sağlanmıyorsa toggle devre dışı
                          final gateDisabled = isGated && !isEquipped;
                          final disabled = sourceDisabled || gateDisabled;
                          return IconButton(
                            icon: Icon(
                              isEquipped ? Icons.shield : Icons.shield_outlined,
                              size: 16,
                              color: disabled
                                  ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                                  : isEquipped
                                      ? (isGated ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary)
                                      : Theme.of(context).colorScheme.outline,
                            ),
                            tooltip: gateDisabled
                                ? gateReason
                                : sourceDisabled
                                    ? 'Source not equipped'
                                    : isGated && isEquipped
                                        ? 'Warning: $gateReason'
                                        : isEquipped ? 'Equipped' : 'Not equipped',
                            onPressed: disabled ? null : () {
                              items[i] = {...item, 'equipped': !isEquipped};
                              onChanged(_serializeItems(items, showEquip || computedMode));
                            },
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          );
                        }),
                      ),
                    ],
                    // Gate warning icon — item equipped ama koşul sağlanmıyor
                    if (isGated && isEquipped)
                      Tooltip(
                        message: gateReason,
                        child: Icon(Icons.warning_amber, size: 14, color: Theme.of(context).colorScheme.error),
                      ),
                    const Icon(Icons.link, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _resolveEntityName(itemId),
                            style: TextStyle(
                              fontSize: 12,
                              decoration: style?.strikethrough == true || ((showEquip || computedMode) && !isEquipped)
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: style?.color != null
                                  ? _parseHexColor(style!.color!)
                                  : (showEquip || computedMode) && !isEquipped
                                      ? Theme.of(context).colorScheme.outline
                                      : null,
                            ),
                          ),
                          if (computedMode && item['from'] != null)
                            Text(
                              'from ${item['from']}',
                              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.outline),
                            ),
                          if (isRuleSourced && (computedMode || _showAllSources))
                            Text(
                              'from rule',
                              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic),
                            ),
                          if (style?.tooltip != null)
                            Text(
                              style!.tooltip!,
                              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.error, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                    if (!readOnly && !computedMode && !isRuleSourced)
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          items.removeAt(i);
                          onChanged(_serializeItems(items, showEquip));
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              );

              // Faded style — reduced opacity
              if (style?.faded == true) {
                itemRow = Opacity(opacity: 0.4, child: itemRow);
              }

              return itemRow;
            }),
          ],
        ),
      ),
    );
  }

  String _resolveEntityName(String id) {
    if (id.isEmpty) return '';
    return entities?[id]?.name ?? id;
  }

  /// Değeri [{id, equipped}] formatına parse et.
  List<Map<String, dynamic>> _parseItems(dynamic value) {
    if (value is! List) return [];
    return value.map<Map<String, dynamic>>((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      if (e is String) return {'id': e, 'equipped': false};
      return {'id': e.toString(), 'equipped': false};
    }).toList();
  }

  /// Kaydetme formatına çevir — equip yoksa basit ID listesi, varsa map listesi.
  dynamic _serializeItems(List<Map<String, dynamic>> items, bool withEquip) {
    if (!withEquip) return items.map((e) => e['id']).toList();
    return items;
  }

  /// Hex renk kodunu Color'a çevir (ör. '#FF0000' → Color).
  static Color? _parseHexColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

/// Inline relation-list — single-row "Label: name1, name2, name3" rendering
/// for grouped multi-column layouts where the full Card form breaks alignment.
/// Edit mode shows compact chips with × + a "+" add button.
class _InlineRelationListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;

  const _InlineRelationListFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entities,
    this.ref,
  });

  List<String> _parseIds(dynamic v) {
    if (v is! List) return const [];
    return v.map<String>((e) {
      if (e is String) return e;
      if (e is Map) return (e['id']?.toString() ?? '');
      return e.toString();
    }).where((s) => s.isNotEmpty).toList();
  }

  String _name(String id) => entities?[id]?.name ?? id;

  @override
  Widget build(BuildContext context) {
    final ids = _parseIds(value);

    if (readOnly) {
      final names = ids.map(_name).where((s) => s.isNotEmpty).toList();
      if (names.isEmpty) return const SizedBox.shrink();
      return _LabeledFieldRow(
        label: schema.label,
        child: Text(names.join(', '), style: _fieldValueStyle(context)),
      );
    }

    return _LabeledFieldRow(
      label: schema.label,
      alignment: CrossAxisAlignment.start,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final id in ids)
            InputChip(
              label: Text(_name(id), style: const TextStyle(fontSize: 11)),
              onDeleted: () {
                final next = List<String>.from(ids)..remove(id);
                onChanged(next);
              },
              deleteIcon: const Icon(Icons.close, size: 14),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Add',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () async {
              if (ref == null) return;
              final result = await showEntitySelectorDialog(
                context: context,
                ref: ref!,
                allowedTypes: schema.validation.allowedTypes,
                multiSelect: true,
                excludeIds: ids,
              );
              if (result != null && result.isNotEmpty) {
                onChanged([...ids, ...result]);
              }
            },
          ),
        ],
      ),
    );
  }
}

// --- BOOLEAN ---
class _BooleanFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _BooleanFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final checked = value == true;
    if (readOnly && !checked) return const SizedBox.shrink();
    return _LabeledFieldRow(
      label: schema.label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: checked,
            onChanged: readOnly ? null : (v) => onChanged(v == true),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

// --- SLOT ---
/// Row of checkbox "pips" for spell slots, ammo, charges, hit dice, etc.
/// Value is stored as `{count, filled}` so it round-trips cleanly through
/// the entity's `Map<String, dynamic> fields`. Users can resize the row at
/// any time via the +/- buttons; a refill button in the corner clears every
/// filled pip in one tap.
class _SlotFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  /// Kural slot count'u sağlıyorsa, entity'nin kendi alanındaki states
  /// bilgisi buradan okunur. States kullanıcı taplamalarıyla düzenlenir,
  /// count rule-driven olduğu için değiştirilemez.
  final Map<String, dynamic>? entityFields;
  final bool ruleDriven;

  const _SlotFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entityFields,
    this.ruleDriven = false,
  });

  ({int count, List<bool> states}) get _parsed {
    // Rule-driven: value bir sayı (count), states entity'nin orijinal
    // alanından okunur. Length count'a pad/trunc edilir.
    if (ruleDriven && value is num) {
      final count = (value as num).toInt().clamp(0, 99);
      List<bool> raw = const [];
      final own = entityFields?[schema.fieldKey];
      if (own is Map) {
        if (own['states'] is List) {
          raw = (own['states'] as List).map((e) => e == true).toList();
        } else if (own['filled'] is num) {
          final filled = (own['filled'] as num).toInt().clamp(0, count);
          raw = List.generate(count, (i) => i < filled);
        }
      }
      final states = List.generate(count, (i) => i < raw.length && raw[i]);
      return (count: count, states: states);
    }
    if (value is Map) {
      final m = value as Map;
      final count = (m['count'] as num?)?.toInt().clamp(0, 99) ?? 0;
      if (m.containsKey('states') && m['states'] is List) {
        final raw = (m['states'] as List).map((e) => e == true).toList();
        final states = List.generate(count, (i) => i < raw.length && raw[i]);
        return (count: count, states: states);
      }
      final filled = (m['filled'] as num?)?.toInt().clamp(0, count) ?? 0;
      return (count: count, states: List.generate(count, (i) => i < filled));
    }
    return (count: 0, states: []);
  }

  void _write({required int count, required List<bool> states}) {
    onChanged({'count': count, 'states': states});
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = _parsed;
    final count = state.count;
    final states = state.states;
    final anyFilled = states.any((s) => s);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  schema.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (ruleDriven)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Count is set by a rule',
                    child: Icon(Icons.auto_fix_high, size: 14, color: palette.srdSubtitle),
                  ),
                ),
              if (!readOnly && !ruleDriven) ...[
                IconButton(
                  tooltip: 'Remove slot',
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: count == 0
                      ? null
                      : () => _write(count: count - 1, states: states.sublist(0, count - 1)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                IconButton(
                  tooltip: 'Add slot',
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: count >= 99
                      ? null
                      : () => _write(count: count + 1, states: [...states, false]),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
              if (!readOnly || ruleDriven)
                IconButton(
                  tooltip: 'Refill',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: !anyFilled
                      ? null
                      : () => _write(count: count, states: List.filled(count, false)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (count == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No slots — tap + to add',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.srdSubtitle,
                ),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < count; i++)
                  _SlotPip(
                    filled: states[i],
                    color: palette.featureCardAccent,
                    borderRadius: palette.br,
                    onTap: () {
                      final newStates = [...states];
                      newStates[i] = !newStates[i];
                      _write(count: count, states: newStates);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SlotPip extends StatelessWidget {
  final bool filled;
  final Color color;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const _SlotPip({
    required this.filled,
    required this.color,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: borderRadius,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
    );
  }
}

// --- LEVEL TABLE — level → value progression tablosu ---
/// Satır satır (level, value) editörü. Storage: `Map<String, num>`
/// (int key'ler JSON uyumu için string olarak saklanır).
class _LevelTableFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _LevelTableFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  List<MapEntry<int, num>> get _rows {
    if (value is! Map) return [];
    final m = value as Map;
    final entries = <MapEntry<int, num>>[];
    for (final e in m.entries) {
      final k = int.tryParse(e.key.toString());
      if (k == null) continue;
      final v = e.value is num ? e.value as num : num.tryParse(e.value.toString());
      if (v == null) continue;
      entries.add(MapEntry(k, v));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  void _write(List<MapEntry<int, num>> rows) {
    final out = <String, num>{};
    for (final r in rows) {
      out[r.key.toString()] = r.value;
    }
    onChanged(out);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(schema.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Add row',
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final nextLevel = rows.isEmpty ? 1 : rows.last.key + 1;
                      _write([...rows, MapEntry(nextLevel, 0)]);
                    },
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('No levels — tap + to add', style: TextStyle(fontSize: 11, color: palette.srdSubtitle)),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 2),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text('Level', style: TextStyle(fontSize: 10, color: palette.srdSubtitle))),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Value', style: TextStyle(fontSize: 10, color: palette.srdSubtitle))),
                  ],
                ),
              ),
              ...rows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_lvl_${row.key}_$i'),
                          initialValue: row.key.toString(),
                          readOnly: readOnly,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          onChanged: (v) {
                            final newLevel = int.tryParse(v);
                            if (newLevel == null) return;
                            final updated = [...rows];
                            updated[i] = MapEntry(newLevel, row.value);
                            _write(updated);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_val_${row.key}_$i'),
                          initialValue: row.value.toString(),
                          readOnly: readOnly,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          onChanged: (v) {
                            final newVal = num.tryParse(v);
                            if (newVal == null) return;
                            final updated = [...rows];
                            updated[i] = MapEntry(row.key, newVal);
                            _write(updated);
                          },
                        ),
                      ),
                      if (!readOnly)
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final updated = [...rows]..removeAt(i);
                            _write(updated);
                          },
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// --- LEVEL TEXT TABLE ---
class _LevelTextTableFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _LevelTextTableFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  List<MapEntry<int, String>> get _rows {
    if (value is! Map) return [];
    final m = value as Map;
    final entries = <MapEntry<int, String>>[];
    for (final e in m.entries) {
      final k = int.tryParse(e.key.toString());
      if (k == null) continue;
      entries.add(MapEntry(k, e.value?.toString() ?? ''));
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  void _write(List<MapEntry<int, String>> rows) {
    final out = <String, String>{};
    for (final r in rows) {
      out[r.key.toString()] = r.value;
    }
    onChanged(out);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(schema.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Add row',
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final nextLevel = rows.isEmpty ? 1 : rows.last.key + 1;
                      _write([...rows, MapEntry(nextLevel, '')]);
                    },
                  ),
              ],
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('No rows — tap + to add', style: TextStyle(fontSize: 11, color: palette.srdSubtitle)),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 2),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text('Level', style: TextStyle(fontSize: 10, color: palette.srdSubtitle))),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Description', style: TextStyle(fontSize: 10, color: palette.srdSubtitle))),
                  ],
                ),
              ),
              ...rows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_lvl_${row.key}_$i'),
                          initialValue: row.key.toString(),
                          readOnly: readOnly,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          onChanged: (v) {
                            final newLevel = int.tryParse(v);
                            if (newLevel == null) return;
                            final updated = [...rows];
                            updated[i] = MapEntry(newLevel, row.value);
                            _write(updated);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('${schema.fieldKey}_txt_${row.key}_$i'),
                          initialValue: row.value,
                          readOnly: readOnly,
                          maxLines: null,
                          minLines: 1,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
                          onChanged: (v) {
                            final updated = [...rows];
                            updated[i] = MapEntry(row.key, v);
                            _write(updated);
                          },
                        ),
                      ),
                      if (!readOnly)
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final updated = [...rows]..removeAt(i);
                            _write(updated);
                          },
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// --- IMAGE GALLERY ---
class _ImageFieldWidget extends ConsumerStatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final String? mediaDir;

  const _ImageFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged, this.mediaDir});

  @override
  ConsumerState<_ImageFieldWidget> createState() => _ImageFieldWidgetState();
}

class _ImageFieldWidgetState extends ConsumerState<_ImageFieldWidget> {
  int _currentIndex = 0;

  List<String> get _images {
    if (widget.value is List) return List<String>.from(widget.value as List);
    if (widget.value is String && (widget.value as String).isNotEmpty) return [widget.value as String];
    return [];
  }

  Future<void> _pickImages() async {
    final mediaDir = widget.mediaDir;
    if (mediaDir != null && mediaDir.isNotEmpty) {
      final campaignId = ref.read(mediaCampaignIdProvider);
      final selected = await MediaGalleryDialog.show(
        context,
        mediaDir: mediaDir,
        campaignId: campaignId,
        allowMultiple: true,
      );
      if (selected == null || selected.isEmpty) return;
      widget.onChanged([..._images, ...selected]);
      return;
    }
    // Fallback: doğrudan dosya seçici
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final newPaths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
    widget.onChanged([..._images, ...newPaths]);
  }

  void _removeImage(int index) {
    final updated = List<String>.from(_images)..removeAt(index);
    if (_currentIndex >= updated.length && updated.isNotEmpty) {
      _currentIndex = updated.length - 1;
    }
    widget.onChanged(updated);
  }

  void _showFullScreen(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (_currentIndex >= images.length) _currentIndex = images.isEmpty ? 0 : images.length - 1;

    final palette = Theme.of(context).extension<DmToolColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.schema.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Column(
          children: [
            if (images.isNotEmpty) ...[
              // Image display with navigation
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _showFullScreen(context, images[_currentIndex]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(images[_currentIndex]),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          cacheWidth: 600,
                          errorBuilder: (_, _, _) => Container(
                            color: palette?.canvasBg ?? Colors.grey.shade800,
                            child: Center(child: Icon(Icons.broken_image, color: palette?.srdSubtitle)),
                          ),
                        ),
                      ),
                    ),
                    // Navigation arrows
                    if (images.length > 1) ...[
                      Positioned(
                        left: 4,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white70),
                          onPressed: () => setState(() => _currentIndex = (_currentIndex - 1).clamp(0, images.length - 1)),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white70),
                          onPressed: () => setState(() => _currentIndex = (_currentIndex + 1).clamp(0, images.length - 1)),
                        ),
                      ),
                    ],
                    // Counter badge
                    if (images.length > 1)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${images.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Action buttons
            if (!widget.readOnly)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (images.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _removeImage(_currentIndex),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Remove', style: TextStyle(fontSize: 12)),
                    ),
                  TextButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                    label: const Text('Add Image', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- FILE (PDF) ---
class _FileFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _FileFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final files = (value is List) ? List<String>.from(value as List) : <String>[];
    final palette = Theme.of(context).extension<DmToolColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Column(
          children: [
            if (files.isNotEmpty)
              ...files.asMap().entries.map((entry) {
                final i = entry.key;
                final path = entry.value;
                final fileName = path.split('/').last.split('\\').last;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf, size: 20, color: palette?.tokenBorderHostile ?? Colors.red),
                  title: Text(fileName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  trailing: readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final updated = List<String>.from(files)..removeAt(i);
                            onChanged(updated);
                          },
                        ),
                );
              }),
            if (!readOnly)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final allowed = schema.validation.allowedExtensions;
                    final result = await FilePicker.platform.pickFiles(
                      type: allowed != null && allowed.isNotEmpty ? FileType.custom : FileType.any,
                      allowedExtensions: allowed != null && allowed.isNotEmpty ? allowed : null,
                      allowMultiple: true,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final newPaths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
                    onChanged([...files, ...newPaths]);
                  },
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Add File', style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- PDF ---
class _PdfFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final WidgetRef? ref;

  const _PdfFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged, this.ref});

  @override
  Widget build(BuildContext context) {
    final files = (value is List) ? List<String>.from(value as List) : <String>[];
    final palette = Theme.of(context).extension<DmToolColors>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Column(
          children: [
            if (files.isNotEmpty)
              ...files.asMap().entries.map((entry) {
                final i = entry.key;
                final path = entry.value;
                final fileName = path.split('/').last.split('\\').last;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf, size: 20, color: palette?.tokenBorderHostile ?? Colors.red),
                  title: Text(fileName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  onTap: () {
                    if (ref != null) {
                      ref!.read(pdfNavigationProvider.notifier).state = path;
                    } else {
                      Process.run('xdg-open', [path]);
                    }
                  },
                  onLongPress: () => Process.run('xdg-open', [path]),
                  trailing: readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            final updated = List<String>.from(files)..removeAt(i);
                            onChanged(updated);
                          },
                        ),
                );
              }),
            if (!readOnly)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      allowMultiple: true,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final newPaths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
                    onChanged([...files, ...newPaths]);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Add PDF', style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- TAG LIST ---
class _TagListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _TagListFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tags = (value is List) ? List<String>.from(value as List) : <String>[];

    if (readOnly && tags.isEmpty) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      alignment: CrossAxisAlignment.start,
      child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      deleteIcon: readOnly ? null : const Icon(Icons.close, size: 14),
                      onDeleted: readOnly
                          ? null
                          : () {
                              tags.remove(tag);
                              onChanged(List<String>.from(tags));
                            },
                      visualDensity: VisualDensity.compact,
                    )),
                if (!readOnly)
                  ActionChip(
                    label: const Icon(Icons.add, size: 14),
                    onPressed: () async {
                      final controller = TextEditingController();
                      final result = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Add Tag'),
                          content: TextField(
                            controller: controller,
                            autofocus: true,
                            decoration: const InputDecoration(hintText: 'Tag name (comma separated)'),
                            onSubmitted: (v) => Navigator.of(ctx).pop(v),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Add')),
                          ],
                        ),
                      ).whenComplete(controller.dispose);
                      if (result != null && result.trim().isNotEmpty) {
                        final newTags = result.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                        onChanged([...tags, ...newTags]);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
    );
  }
}

// --- DATE ---
class _DateFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _DateFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dateStr = value?.toString() ?? '';
    DateTime? parsed;
    try {
      if (dateStr.isNotEmpty) parsed = DateTime.parse(dateStr);
    } catch (_) {}
    final display = parsed != null
        ? '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}'
        : dateStr;
    final hasValue = display.isNotEmpty;

    if (readOnly && !hasValue) return const SizedBox.shrink();

    return _LabeledFieldRow(
      label: schema.label,
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasValue ? display : '—',
              style: hasValue ? _fieldValueStyle(context) : _fieldEmptyStyle(context),
            ),
          ),
          if (!readOnly)
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsed ?? DateTime.now(),
                  firstDate: DateTime(1000),
                  lastDate: DateTime(9999),
                );
                if (picked != null) {
                  onChanged(picked.toIso8601String().split('T').first);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.calendar_today, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

// --- PROFICIENCY TABLE (skills / saving throws) ---
/// Her satır `{name, ability, proficient, expertise, misc}`.
/// Toplam bonus `entityFields` varsa runtime'da hesaplanır:
///   `ability_mod + PB * (proficient ? 1 : 0) + PB * (expertise ? 1 : 0) + misc`
/// `stat_block` ve `proficiency_bonus` diğer field'lardan okunur.
class _ProficiencyTableFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, dynamic>? entityFields;

  const _ProficiencyTableFieldWidget({
    required this.schema,
    required this.value,
    required this.readOnly,
    required this.onChanged,
    this.entityFields,
  });

  List<Map<String, dynamic>> get _rows {
    if (value is Map && (value as Map)['rows'] is List) {
      final list = (value as Map)['rows'] as List;
      if (list.isNotEmpty) {
        return list
            .map<Map<String, dynamic>>(
                (r) => Map<String, dynamic>.from(r as Map))
            .toList();
      }
    }
    // Fallback: schema-provided default rows (preset skills / saves) when
    // the entity's stored value is missing/empty. Lets cards filled before
    // defaults landed still render the canonical row list.
    final dv = schema.defaultValue;
    if (dv is Map && dv['rows'] is List) {
      return (dv['rows'] as List)
          .map<Map<String, dynamic>>(
              (r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    return const [];
  }

  int? _abilityScore(String ability) {
    final sb = entityFields?['stat_block'];
    if (sb is! Map) return null;
    final v = sb[ability];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  int _proficiencyBonus() {
    final pb = entityFields?['proficiency_bonus'];
    if (pb is int) return pb;
    if (pb is num) return pb.toInt();
    final parsed = int.tryParse(pb?.toString() ?? '');
    if (parsed != null) return parsed;
    // Fallback: level'dan türet.
    final cs = entityFields?['combat_stats'];
    int level = 1;
    if (cs is Map) {
      final lv = cs['level'];
      level = (lv is int) ? lv : int.tryParse(lv?.toString() ?? '') ?? 1;
    }
    return proficiencyBonusForLevel(level);
  }

  void _updateRow(int index, Map<String, dynamic> patch) {
    final rows = _rows;
    rows[index] = {...rows[index], ...patch};
    onChanged({'rows': rows});
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final pb = _proficiencyBonus();
    final outline = Theme.of(context).colorScheme.outline;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(schema.label, style: Theme.of(context).textTheme.titleSmall)),
                if (entityFields != null)
                  Text('PB +$pb', style: TextStyle(fontSize: 11, color: outline)),
              ],
            ),
            const SizedBox(height: 6),
            // Header
            Row(
              children: [
                const SizedBox(width: 24), // prof
                const SizedBox(width: 24), // exp
                Expanded(flex: 4, child: Text('Skill', style: TextStyle(fontSize: 10, color: outline))),
                SizedBox(width: 34, child: Text('Abil', style: TextStyle(fontSize: 10, color: outline))),
                SizedBox(width: 44, child: Text('Misc', style: TextStyle(fontSize: 10, color: outline), textAlign: TextAlign.center)),
                SizedBox(width: 40, child: Text('Total', style: TextStyle(fontSize: 10, color: outline), textAlign: TextAlign.right)),
              ],
            ),
            const Divider(height: 8),
            if (rows.isEmpty)
              Text('No rows', style: TextStyle(color: outline, fontSize: 12))
            else
              ...rows.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                final name = row['name']?.toString() ?? '';
                final ability = row['ability']?.toString() ?? '';
                final proficient = row['proficient'] == true;
                final expertise = row['expertise'] == true;
                final misc = (row['misc'] is int)
                    ? row['misc'] as int
                    : int.tryParse(row['misc']?.toString() ?? '') ?? 0;

                final score = _abilityScore(ability);
                final mod = score != null ? abilityModifier(score) : null;
                final total = (mod ?? 0) +
                    (proficient ? pb : 0) +
                    (expertise ? pb : 0) +
                    misc;
                final totalStr = entityFields != null && mod != null
                    ? (total >= 0 ? '+$total' : '$total')
                    : '—';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      _ProfDot(
                        active: proficient,
                        tooltip: 'Proficient',
                        onTap: readOnly ? null : () => _updateRow(i, {'proficient': !proficient}),
                      ),
                      _ProfDot(
                        active: expertise,
                        doubled: true,
                        tooltip: 'Expertise',
                        onTap: readOnly ? null : () => _updateRow(i, {'expertise': !expertise}),
                      ),
                      Expanded(flex: 4, child: Text(name, style: const TextStyle(fontSize: 12))),
                      SizedBox(width: 34, child: Text(ability, style: TextStyle(fontSize: 10, color: outline))),
                      SizedBox(
                        width: 44,
                        child: TextFormField(
                          key: ValueKey('pt_${schema.fieldKey}_${i}_misc'),
                          initialValue: misc == 0 ? '' : misc.toString(),
                          readOnly: readOnly,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            border: InputBorder.none,
                            hintText: '0',
                          ),
                          onChanged: (v) => _updateRow(i, {'misc': int.tryParse(v) ?? 0}),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          totalStr,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: proficient || expertise
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ProfDot extends StatelessWidget {
  final bool active;
  final bool doubled;
  final String tooltip;
  final VoidCallback? onTap;

  const _ProfDot({
    required this.active,
    required this.tooltip,
    this.doubled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Container(
              width: doubled ? 14 : 12,
              height: doubled ? 14 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? color : Colors.transparent,
                border: Border.all(
                  color: active ? color : Theme.of(context).colorScheme.outline,
                  width: doubled ? 2 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- DICE (zar notasyonu: 2d6, 1d20+5, 3d8+2) ---
class _DiceFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _DiceFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  State<_DiceFieldWidget> createState() => _DiceFieldWidgetState();
}

class _DiceFieldWidgetState extends State<_DiceFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _DiceFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && oldWidget.value != widget.value) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${widget.schema.fieldKey}_dice'),
        controller: _controller,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          labelText: widget.schema.label,
          hintText: 'e.g. 2d6+3',
          isDense: true,
          prefixIcon: const Icon(Icons.casino, size: 18),
        ),
        onChanged: (v) => widget.onChanged(v),
      ),
    );
  }
}

