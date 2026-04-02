import 'package:flutter/material.dart';

import '../../../domain/entities/schema/field_schema.dart';

/// Schema-driven field widget factory.
/// Her FieldType için uygun widget döndürür.
class FieldWidgetFactory {
  static Widget create({
    required FieldSchema schema,
    required dynamic value,
    required bool readOnly,
    required ValueChanged<dynamic> onChanged,
  }) {
    return switch (schema.fieldType) {
      FieldType.text => _TextFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.textarea => _TextAreaFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.integer => _IntegerFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.enum_ => _EnumFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.relation => _RelationFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.statBlock => _StatBlockFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.combatStats => _CombatStatsFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.actionList => _ActionListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.spellList => _SpellListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.boolean_ => _BooleanFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.tagList => _TagListFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
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
class _RelationFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _RelationFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final linkedId = value?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: linkedId,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: schema.label,
          hintText: 'Entity ID (${schema.validation.allowedTypes?.join(", ") ?? "any"})',
          isDense: true,
          suffixIcon: const Icon(Icons.link, size: 18),
        ),
        onChanged: (v) => onChanged(v),
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
    const fields = [
      ('hp', 'HP'),
      ('max_hp', 'Max HP'),
      ('ac', 'AC'),
      ('speed', 'Speed'),
      ('initiative', 'Init'),
      ('cr', 'CR'),
      ('xp', 'XP'),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schema.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fields.map((f) {
                return SizedBox(
                  width: 80,
                  child: TextFormField(
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
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ACTION LIST (Traits, Actions, Reactions, Legendary) ---
class _ActionListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _ActionListFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = (value is List) ? List<Map<String, dynamic>>.from((value as List).map((e) => Map<String, dynamic>.from(e as Map))) : <Map<String, dynamic>>[];

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
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () {
                      items.add({'name': '', 'desc': ''});
                      onChanged(items);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No ${schema.label.toLowerCase()}', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              ),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          TextFormField(
                            initialValue: item['name']?.toString() ?? '',
                            readOnly: readOnly,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Name',
                              border: UnderlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) {
                              items[i]['name'] = v;
                              onChanged(List<Map<String, dynamic>>.from(items));
                            },
                          ),
                          TextFormField(
                            initialValue: item['desc']?.toString() ?? '',
                            readOnly: readOnly,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Description',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (v) {
                              items[i]['desc'] = v;
                              onChanged(List<Map<String, dynamic>>.from(items));
                            },
                          ),
                        ],
                      ),
                    ),
                    if (!readOnly)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          items.removeAt(i);
                          onChanged(List<Map<String, dynamic>>.from(items));
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

// --- SPELL LIST ---
class _SpellListFieldWidget extends StatelessWidget {
  final FieldSchema schema;
  final dynamic value;
  final bool readOnly;
  final ValueChanged<dynamic> onChanged;

  const _SpellListFieldWidget({required this.schema, required this.value, required this.readOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final spellIds = (value is List) ? List<String>.from(value as List) : <String>[];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${schema.label} (${spellIds.length})', style: Theme.of(context).textTheme.titleSmall)),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () {
                      // TODO: Spell selector dialog
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (spellIds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No spells linked', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
              ),
            ...spellIds.map((id) => ListTile(
                  dense: true,
                  title: Text(id, style: const TextStyle(fontSize: 12)),
                  trailing: readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: () {
                            spellIds.remove(id);
                            onChanged(List<String>.from(spellIds));
                          },
                        ),
                )),
          ],
        ),
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
    return SwitchListTile(
      title: Text(schema.label, style: const TextStyle(fontSize: 13)),
      value: value == true,
      onChanged: readOnly ? null : (v) => onChanged(v),
      dense: true,
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
                onPressed: () {
                  // TODO: Tag input dialog
                },
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
