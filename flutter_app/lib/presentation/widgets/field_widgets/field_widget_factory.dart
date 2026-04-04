import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../dialogs/entity_selector_dialog.dart';
import '../../theme/dm_tool_colors.dart';

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
  }) {
    // isList → genel liste widget'ı
    if (schema.isList) {
      if (schema.fieldType == FieldType.relation) {
        return _ReferenceListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref, computedMode: computedMode);
      }
      return _GenericListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged);
    }

    return switch (schema.fieldType) {
      FieldType.text => _TextFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.textarea => _TextAreaFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.markdown => _MarkdownFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref),
      FieldType.integer => _IntegerFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.enum_ => _EnumFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.relation => _RelationFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref),
      FieldType.statBlock => _StatBlockFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.combatStats => _CombatStatsFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.dice => _DiceFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.boolean_ => _BooleanFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.tagList => _TagListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.date => _DateFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.image => _ImageFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.file => _FileFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      _ => _TextFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
    };
  }
}

// --- TEXT ---
class _TextFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _TextFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${schema.fieldKey}_text_$value'),
        initialValue: value?.toString() ?? '',
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: schema.label,
          hintText: schema.placeholder.isNotEmpty ? schema.placeholder : null,
          isDense: true,
        ),
        onChanged: (v) => onChanged(v),
      ),
    );
  }
}

// --- TEXTAREA ---
class _TextAreaFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _TextAreaFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${schema.fieldKey}_area_$value'),
        initialValue: value?.toString() ?? '',
        readOnly: readOnly,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
        ),
        onChanged: (v) => onChanged(v),
      ),
    );
  }
}

// --- MARKDOWN ---
class _MarkdownFieldWidget extends StatefulWidget {
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
  State<_MarkdownFieldWidget> createState() => _MarkdownFieldWidgetState();
}

class _MarkdownFieldWidgetState extends State<_MarkdownFieldWidget> {
  bool _isPreview = false;
  late TextEditingController _controller;
  final _focusNode = FocusNode();
  OverlayEntry? _mentionOverlay;
  String _mentionQuery = '';
  int _mentionStart = -1;

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
    _focusNode.dispose();
    _dismissMentionOverlay();
    super.dispose();
  }

  void _dismissMentionOverlay() {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
  }

  void _onTextChanged(String text) {
    widget.onChanged(text);

    // Check for @mention trigger
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos <= 0) {
      _dismissMentionOverlay();
      return;
    }

    // Find the last @ before cursor
    final beforeCursor = text.substring(0, cursorPos);
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      final query = beforeCursor.substring(atIndex + 1);
      // Only show if no space before @ (or @ is at start) and query has no newlines
      if (!query.contains('\n') && query.length < 30) {
        _mentionStart = atIndex;
        _mentionQuery = query.toLowerCase();
        _showMentionOverlay();
        return;
      }
    }
    _dismissMentionOverlay();
  }

  void _showMentionOverlay() {
    _dismissMentionOverlay();
    final entities = widget.entities;
    if (entities == null || entities.isEmpty) return;

    final filtered = entities.values
        .where((e) => e.name.toLowerCase().contains(_mentionQuery))
        .take(8)
        .toList();
    if (filtered.isEmpty) {
      return;
    }

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);

    _mentionOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: offset.dx,
        top: offset.dy + renderBox.size.height,
        width: renderBox.size.width.clamp(200, 400),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final entity = filtered[i];
                return ListTile(
                  dense: true,
                  title: Text(entity.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(entity.categorySlug, style: const TextStyle(fontSize: 10)),
                  onTap: () => _insertMention(entity.id, entity.name),
                );
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_mentionOverlay!);
  }

  void _insertMention(String entityId, String entityName) {
    _dismissMentionOverlay();
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final mention = '@[$entityName](entity:$entityId)';
    final newText = text.substring(0, _mentionStart) + mention + text.substring(cursorPos);
    _controller.text = newText;
    final newCursor = _mentionStart + mention.length;
    _controller.selection = TextSelection.collapsed(offset: newCursor);
    widget.onChanged(newText);
  }

  MarkdownStyleSheet _styleSheet(DmToolColors? palette) {
    return MarkdownStyleSheet(
      p: TextStyle(fontSize: 13, color: palette?.htmlText),
      h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette?.htmlHeader),
      h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette?.htmlHeader),
      h3: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette?.htmlHeader),
      code: TextStyle(fontSize: 12, backgroundColor: palette?.htmlCodeBg),
      a: TextStyle(color: palette?.htmlLink),
      listBullet: TextStyle(fontSize: 13, color: palette?.htmlText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();

    if (widget.readOnly) {
      final text = widget.value?.toString() ?? '';
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.schema.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette?.tabText)),
            const SizedBox(height: 4),
            MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: _styleSheet(palette),
              onTapLink: (text, href, title) {
                // Handle entity: links
                if (href != null && href.startsWith('entity:')) {
                  // Entity navigation could be handled here
                }
              },
            ),
          ],
        ),
      );
    }

    // Edit mode with toggle
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Edit/Preview toggle
          Row(
            children: [
              Text(widget.schema.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette?.tabText)),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Edit', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: true, label: Text('Preview', style: TextStyle(fontSize: 11))),
                ],
                selected: {_isPreview},
                onSelectionChanged: (v) => setState(() => _isPreview = v.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_isPreview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: palette?.featureCardBorder ?? Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              constraints: const BoxConstraints(minHeight: 100),
              child: _controller.text.isEmpty
                  ? Text('Nothing to preview', style: TextStyle(color: palette?.sidebarLabelSecondary, fontSize: 12, fontStyle: FontStyle.italic))
                  : MarkdownBody(
                      data: _controller.text,
                      selectable: true,
                      styleSheet: _styleSheet(palette),
                      onTapLink: (text, href, title) {
                        if (href != null && href.startsWith('entity:')) {
                          // Entity navigation
                        }
                      },
                    ),
            )
          else
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 4,
              decoration: InputDecoration(
                hintText: 'Markdown supported. Use @ to mention entities.',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onTextChanged,
            ),
        ],
      ),
    );
  }
}

// --- INTEGER ---
class _IntegerFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _IntegerFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${schema.fieldKey}_int_$value'),
        initialValue: value?.toString() ?? '',
        readOnly: readOnly,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
        ),
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(currentVal) ? currentVal : null,
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: readOnly ? null : (v) => onChanged(v),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: schema.label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
          children: [
            if (hasValue) ...[
              const Icon(Icons.link, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(linkedName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              if (!readOnly)
                InkWell(
                  onTap: () => onChanged(''),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14),
                  ),
                ),
            ] else ...[
              Expanded(
                child: Text(
                  'None',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (!readOnly)
              InkWell(
                borderRadius: BorderRadius.circular(12),
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
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.search, size: 16),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

// --- STAT BLOCK (STR/DEX/CON/INT/WIS/CHA) ---
class _StatBlockFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _StatBlockFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final stats = (value is Map) ? Map<String, dynamic>.from(value as Map) : <String, dynamic>{};
    const keys = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: keys.map((key) {
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
                          key: ValueKey('sb_${key}_$val'),
                          initialValue: val.toString(),
                          readOnly: readOnly,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            stats[key] = int.tryParse(v) ?? 10;
                            onChanged(Map<String, dynamic>.from(stats));
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
class _CombatStatsFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _CombatStatsFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final stats = (value is Map) ? Map<String, dynamic>.from(value as Map) : <String, dynamic>{};

    // subFields varsa ondan al, yoksa default
    final fields = schema.subFields.isNotEmpty
        ? schema.subFields.map((sf) => (sf['key'] ?? '', sf['label'] ?? sf['key'] ?? '')).toList()
        : const [('hp', 'HP'), ('max_hp', 'Max HP'), ('ac', 'AC'), ('speed', 'Speed'), ('initiative', 'Init'), ('cr', 'CR'), ('xp', 'XP')];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Satıra sığan alan sayısını hesapla (min 80px per field + 8px gap)
                final cols = (constraints.maxWidth / 88).floor().clamp(1, fields.length);
                final rows = <Widget>[];
                for (var i = 0; i < fields.length; i += cols) {
                  final rowFields = fields.sublist(i, (i + cols).clamp(0, fields.length));
                  rows.add(Padding(
                    padding: EdgeInsets.only(bottom: i + cols < fields.length ? 8 : 0),
                    child: Row(
                      children: rowFields.map((f) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: f != rowFields.last ? 8 : 0),
                            child: TextFormField(
                              key: ValueKey('cs_${f.$1}_${stats[f.$1]}'),
                              initialValue: stats[f.$1]?.toString() ?? '',
                              readOnly: readOnly,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: f.$2,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              ),
                              onChanged: (v) {
                                stats[f.$1] = v;
                                onChanged(Map<String, dynamic>.from(stats));
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
          ],
        ),
      ),
    );
  }
}

// --- GENERIC LIST — herhangi tipin listesi (text list, integer list, image list...) ---
class _GenericListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _GenericListFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = (value is List) ? List<String>.from(value.map((e) => e.toString())) : <String>[];
    final typeName = schema.fieldType.name;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${schema.label} (${items.length})', style: Theme.of(context).textTheme.titleSmall)),
                Text(typeName, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () {
                      items.add('');
                      onChanged(List<String>.from(items));
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
                        initialValue: entry.value,
                        readOnly: readOnly,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(isDense: true, filled: false, border: InputBorder.none),
                        keyboardType: schema.fieldType == FieldType.integer ? TextInputType.number : null,
                        onChanged: (v) {
                          items[i] = v;
                          onChanged(List<String>.from(items));
                        },
                      ),
                    ),
                    if (!readOnly)
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          items.removeAt(i);
                          onChanged(List<String>.from(items));
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
class _ReferenceListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;
  final Map<String, Entity>? entities;
  final WidgetRef? ref;
  final bool computedMode; // true = add/remove yok, equip sadece equipped kaynaklar için

  const _ReferenceListFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged, this.entities, this.ref, this.computedMode = false});

  @override
  Widget build(BuildContext context) {
    // Değer iki formatta olabilir:
    // 1) List<String> — basit ID listesi (equip yok)
    // 2) List<Map> — [{id: 'xxx', equipped: true}, ...] (equip var)
    final items = _parseItems(value);
    final targetTypes = schema.validation.allowedTypes?.join(', ') ?? 'any';
    final showEquip = schema.hasEquip;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${schema.label} (${items.length})', style: Theme.of(context).textTheme.titleSmall)),
                Text('→ $targetTypes', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
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
                          items.add({'id': id, 'equipped': false});
                        }
                        onChanged(_serializeItems(items, showEquip));
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No items linked', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              ),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isEquipped = item['equipped'] == true;

              return Padding(
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
                          return IconButton(
                            icon: Icon(
                              isEquipped ? Icons.shield : Icons.shield_outlined,
                              size: 16,
                              color: sourceDisabled
                                  ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                                  : isEquipped
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                            ),
                            tooltip: sourceDisabled
                                ? 'Source not equipped'
                                : isEquipped ? 'Equipped' : 'Not equipped',
                            onPressed: sourceDisabled ? null : () {
                              items[i] = {...item, 'equipped': !isEquipped};
                              onChanged(_serializeItems(items, showEquip || computedMode));
                            },
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          );
                        }),
                      ),
                    ],
                    const Icon(Icons.link, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _resolveEntityName(item['id']?.toString() ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              decoration: (showEquip || computedMode) && !isEquipped ? TextDecoration.lineThrough : null,
                              color: (showEquip || computedMode) && !isEquipped
                                  ? Theme.of(context).colorScheme.outline
                                  : null,
                            ),
                          ),
                          if (computedMode && item['from'] != null)
                            Text(
                              'from ${item['from']}',
                              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.outline),
                            ),
                        ],
                      ),
                    ),
                    if (!readOnly && !computedMode)
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
    return SwitchListTile(
      title: Text(schema.label, style: const TextStyle(fontSize: 13)),
      value: value == true,
      onChanged: readOnly ? null : (v) => onChanged(v),
      dense: true,
    );
  }
}

// --- IMAGE GALLERY ---
class _ImageFieldWidget extends StatefulWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _ImageFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  State<_ImageFieldWidget> createState() => _ImageFieldWidgetState();
}

class _ImageFieldWidgetState extends State<_ImageFieldWidget> {
  int _currentIndex = 0;

  List<String> get _images {
    if (widget.value is List) return List<String>.from(widget.value as List);
    if (widget.value is String && (widget.value as String).isNotEmpty) return [widget.value as String];
    return [];
  }

  Future<void> _pickImages() async {
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
                          errorBuilder: (_, __, ___) => Container(
                            color: palette?.canvasBg ?? Colors.grey.shade800,
                            child: Center(child: Icon(Icons.broken_image, color: palette?.sidebarLabelSecondary)),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
        ),
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
                  );
                  if (result != null && result.trim().isNotEmpty) {
                    final newTags = result.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                    onChanged([...tags, ...newTags]);
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${schema.fieldKey}_date_$value'),
        initialValue: parsed != null
            ? '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}'
            : dateStr,
        readOnly: true,
        decoration: InputDecoration(
          labelText: schema.label,
          isDense: true,
          suffixIcon: readOnly
              ? null
              : IconButton(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  onPressed: () async {
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
                ),
        ),
      ),
    );
  }
}

// --- DICE (zar notasyonu: 2d6, 1d20+5, 3d8+2) ---
class _DiceFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _DiceFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('${schema.fieldKey}_dice_$value'),
        initialValue: value?.toString() ?? '',
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: schema.label,
          hintText: 'e.g. 2d6+3',
          isDense: true,
          prefixIcon: const Icon(Icons.casino, size: 18),
        ),
        onChanged: (v) => onChanged(v),
      ),
    );
  }
}

