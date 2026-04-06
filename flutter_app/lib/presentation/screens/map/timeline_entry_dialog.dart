import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/map_data.dart';
import '../../theme/dm_tool_colors.dart';

/// Dialog for creating / editing a timeline pin.
///
/// Returns a [TimelinePin] on save, or null on cancel.
class TimelineEntryDialog extends StatefulWidget {
  final DmToolColors palette;
  final TimelinePin? existing; // null = create mode
  /// Entity id → display name, used to show chips for linked entities.
  final Map<String, String> entityNames;

  const TimelineEntryDialog({
    super.key,
    required this.palette,
    this.existing,
    this.entityNames = const {},
  });

  @override
  State<TimelineEntryDialog> createState() => _TimelineEntryDialogState();
}

class _TimelineEntryDialogState extends State<TimelineEntryDialog> {
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
              // Linked entities (view / remove only)
              if (_selectedEntityIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Entities',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.uiFloatingText.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                ..._selectedEntityIds.map((eid) {
                  final name = widget.entityNames[eid] ?? eid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.uiFloatingText,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(
                              () => _selectedEntityIds.remove(eid)),
                          child: Icon(Icons.close,
                              size: 14,
                              color: palette.uiFloatingText
                                  .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
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
