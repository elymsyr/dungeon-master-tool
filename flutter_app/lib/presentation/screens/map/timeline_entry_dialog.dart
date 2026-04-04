import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/entity_provider.dart';
import '../../../domain/entities/map_data.dart';
import '../../theme/dm_tool_colors.dart';

/// Dialog for creating / editing a timeline pin.
///
/// Returns a [TimelinePin] on save, or null on cancel.
class TimelineEntryDialog extends ConsumerStatefulWidget {
  final DmToolColors palette;
  final TimelinePin? existing; // null = create mode

  const TimelineEntryDialog({
    super.key,
    required this.palette,
    this.existing,
  });

  @override
  ConsumerState<TimelineEntryDialog> createState() =>
      _TimelineEntryDialogState();
}

class _TimelineEntryDialogState extends ConsumerState<TimelineEntryDialog> {
  late TextEditingController _dayCtrl;
  late TextEditingController _noteCtrl;
  late List<String> _selectedEntityIds;
  late String _color;

  static const _presetColors = [
    '#42a5f5', '#ef5350', '#66bb6a', '#ffa726', '#ab47bc',
    '#26c6da', '#ec407a', '#8d6e63', '#78909c', '#ffee58',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _dayCtrl = TextEditingController(text: '${e?.day ?? 1}');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _selectedEntityIds = List<String>.from(e?.entityIds ?? []);
    _color = e?.color ?? '#42a5f5';
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final entities = ref.watch(entityProvider);
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: palette.uiFloatingBg,
      title: Text(
        isEdit ? 'Edit Timeline Entry' : 'Add Timeline Entry',
        style: TextStyle(fontSize: 14, color: palette.uiFloatingText),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day
              TextField(
                controller: _dayCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 12, color: palette.uiFloatingText),
                decoration: InputDecoration(
                  labelText: 'Day',
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: palette.uiFloatingText.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: palette.uiFloatingBorder),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Note
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                style: TextStyle(fontSize: 12, color: palette.uiFloatingText),
                decoration: InputDecoration(
                  labelText: 'Note',
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: palette.uiFloatingText.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: palette.uiFloatingBorder),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Entity selection
              Text(
                'Entities',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.uiFloatingText.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              _buildEntityChips(palette, entities),
              const SizedBox(height: 12),

              // Color
              Text(
                'Color',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.uiFloatingText.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presetColors.map((hex) {
                  final c = Color(
                      int.parse(hex.replaceAll('#', 'FF'), radix: 16));
                  final isActive = _color == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isActive
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: palette.uiFloatingText)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _buildEntityChips(
      DmToolColors palette, Map<String, dynamic> entities) {
    if (entities.isEmpty) {
      return Text(
        'No entities available',
        style: TextStyle(
            fontSize: 10,
            color: palette.uiFloatingText.withValues(alpha: 0.4)),
      );
    }

    // Show selected + a button to add more
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ..._selectedEntityIds.map((eid) {
          final entity = entities[eid];
          final name = entity != null ? (entity.name as String? ?? eid) : eid;
          return Chip(
            label: Text(name,
                style: TextStyle(
                    fontSize: 10, color: palette.uiFloatingText)),
            deleteIcon: Icon(Icons.close, size: 14),
            onDeleted: () => setState(
                () => _selectedEntityIds.remove(eid)),
            backgroundColor: palette.uiFloatingBg,
            side: BorderSide(color: palette.uiFloatingBorder),
          );
        }),
        ActionChip(
          label: Text('+ Add Entity',
              style: TextStyle(
                  fontSize: 10, color: palette.tabIndicator)),
          onPressed: () => _showEntitySelector(entities),
          backgroundColor: palette.uiFloatingBg,
          side: BorderSide(color: palette.tabIndicator.withValues(alpha: 0.4)),
        ),
      ],
    );
  }

  void _showEntitySelector(Map<String, dynamic> entities) {
    final available = entities.entries
        .where((e) => !_selectedEntityIds.contains(e.key))
        .toList();
    if (available.isEmpty) return;

    final palette = widget.palette;
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.uiFloatingBg,
        title: Text('Select Entity',
            style: TextStyle(
                fontSize: 14, color: palette.uiFloatingText)),
        content: SizedBox(
          width: 300,
          height: 300,
          child: ListView.builder(
            itemCount: available.length,
            itemBuilder: (_, i) {
              final entry = available[i];
              final entity = entry.value;
              final name = entity.name as String? ?? entry.key;
              final type = entity.type as String? ?? '';
              return ListTile(
                dense: true,
                title: Text(name,
                    style: TextStyle(
                        fontSize: 12, color: palette.uiFloatingText)),
                subtitle: type.isNotEmpty
                    ? Text(type,
                        style: TextStyle(
                            fontSize: 10,
                            color: palette.uiFloatingText
                                .withValues(alpha: 0.5)))
                    : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              );
            },
          ),
        ),
      ),
    ).then((eid) {
      if (eid != null && !_selectedEntityIds.contains(eid)) {
        setState(() => _selectedEntityIds.add(eid));
      }
    });
  }

  void _save() {
    final day = int.tryParse(_dayCtrl.text) ?? 1;
    final existing = widget.existing;
    final result = TimelinePin(
      id: existing?.id ?? '', // caller will assign new ID if needed
      x: existing?.x ?? 0,
      y: existing?.y ?? 0,
      day: day,
      note: _noteCtrl.text,
      entityIds: _selectedEntityIds,
      sessionId: existing?.sessionId,
      parentIds: existing?.parentIds ?? [],
      color: _color,
    );
    Navigator.pop(context, result);
  }
}
