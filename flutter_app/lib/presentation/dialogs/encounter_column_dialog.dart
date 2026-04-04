import 'package:flutter/material.dart';

import '../../domain/entities/schema/encounter_config.dart';

/// Available combat_stats subfield keys.
const _availableSubFields = [
  ('initiative', 'Init'),
  ('hp', 'HP'),
  ('max_hp', 'Max HP'),
  ('ac', 'AC'),
  ('speed', 'Speed'),
  ('cr', 'CR'),
  ('xp', 'XP'),
];

/// Dialog for configuring encounter table columns.
class EncounterColumnDialog extends StatefulWidget {
  final List<EncounterColumnConfig> columns;

  const EncounterColumnDialog({required this.columns, super.key});

  /// Show the dialog and return updated columns, or null if cancelled.
  static Future<List<EncounterColumnConfig>?> show(
    BuildContext context,
    List<EncounterColumnConfig> columns,
  ) {
    return showDialog<List<EncounterColumnConfig>>(
      context: context,
      builder: (_) => EncounterColumnDialog(columns: columns),
    );
  }

  @override
  State<EncounterColumnDialog> createState() => _EncounterColumnDialogState();
}

class _EncounterColumnDialogState extends State<EncounterColumnDialog> {
  late List<_ColumnEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.columns
        .map((c) => _ColumnEntry(
              subFieldKey: c.subFieldKey,
              label: c.label,
              editable: c.editable,
              showButtons: c.showButtons,
              width: c.width,
              enabled: true,
            ))
        .toList();
  }

  List<String> get _usedKeys => _entries.map((e) => e.subFieldKey).toList();

  void _addColumn(String key, String label) {
    setState(() {
      _entries.add(_ColumnEntry(
        subFieldKey: key,
        label: label,
        editable: false,
        showButtons: false,
        width: 60,
        enabled: true,
      ));
    });
  }

  void _removeColumn(int index) {
    setState(() => _entries.removeAt(index));
  }

  List<EncounterColumnConfig> _buildResult() {
    return _entries
        .where((e) => e.enabled)
        .map((e) => EncounterColumnConfig(
              subFieldKey: e.subFieldKey,
              label: e.label,
              editable: e.editable,
              showButtons: e.showButtons,
              width: e.width,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final unused = _availableSubFields
        .where((f) => !_usedKeys.contains(f.$1))
        .toList();

    return AlertDialog(
      title: const Text('Configure Columns'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Column list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _entries.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _entries.removeAt(oldIndex);
                    _entries.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Card(
                    key: ValueKey(entry.subFieldKey),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                          const SizedBox(width: 4),
                          Checkbox(
                            value: entry.enabled,
                            onChanged: (v) => setState(() => entry.enabled = v ?? true),
                            visualDensity: VisualDensity.compact,
                          ),
                          // Label
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: TextEditingController(text: entry.label),
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Label',
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              ),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (v) => entry.label = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Width
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: TextEditingController(text: entry.width.toString()),
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'W',
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              ),
                              style: const TextStyle(fontSize: 12),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => entry.width = int.tryParse(v) ?? entry.width,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Editable toggle
                          Tooltip(
                            message: 'Editable',
                            child: FilterChip(
                              label: const Text('Edit', style: TextStyle(fontSize: 10)),
                              selected: entry.editable,
                              onSelected: (v) => setState(() => entry.editable = v),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // ShowButtons toggle
                          Tooltip(
                            message: '+/- Buttons',
                            child: FilterChip(
                              label: const Text('+/-', style: TextStyle(fontSize: 10)),
                              selected: entry.showButtons,
                              onSelected: (v) => setState(() => entry.showButtons = v),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed: () => _removeColumn(index),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Add button
            if (unused.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PopupMenuButton<(String, String)>(
                  onSelected: (item) => _addColumn(item.$1, item.$2),
                  itemBuilder: (_) => unused
                      .map((f) => PopupMenuItem(
                            value: f,
                            child: Text(f.$2, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, size: 16),
                      SizedBox(width: 4),
                      Text('Add Column', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _buildResult()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColumnEntry {
  final String subFieldKey;
  String label;
  bool editable;
  bool showButtons;
  int width;
  bool enabled;

  _ColumnEntry({
    required this.subFieldKey,
    required this.label,
    required this.editable,
    required this.showButtons,
    required this.width,
    required this.enabled,
  });
}
