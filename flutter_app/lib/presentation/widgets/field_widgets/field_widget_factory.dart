import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../dialogs/entity_selector_dialog.dart';

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
      FieldType.integer => _IntegerFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.enum_ => _EnumFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.relation => _RelationFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged, entities: entities, ref: ref),
      FieldType.statBlock => _StatBlockFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.combatStats => _CombatStatsFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
      FieldType.dice => _DiceFieldWidget(schema: schema, value: value, readOnly: readOnly, onChanged: onChanged),
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
          isDense: true,
        ),
        child: Row(
          children: [
            if (hasValue) ...[
              const Icon(Icons.link, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(linkedName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
              if (!readOnly)
                InkWell(
                  onTap: () => onChanged(''),
                  child: const Icon(Icons.close, size: 14),
                ),
            ] else ...[
              Expanded(
                child: Text(
                  'None',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (!readOnly)
              IconButton(
                icon: const Icon(Icons.search, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
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
              ),
          ],
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

