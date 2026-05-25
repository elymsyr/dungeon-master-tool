import 'package:flutter/material.dart';

import '../../theme/dm_tool_colors.dart';
import 'world_map_notifier.dart';

/// Result from [AddWaypointDialog].
class AddWaypointResult {
  final String label;
  final bool copyPins;
  final bool copyTimelinePins;
  const AddWaypointResult({
    required this.label,
    required this.copyPins,
    required this.copyTimelinePins,
  });
}

/// Dialog for adding a new era waypoint.
class AddWaypointDialog extends StatefulWidget {
  final DmToolColors palette;

  const AddWaypointDialog({super.key, required this.palette});

  @override
  State<AddWaypointDialog> createState() => _AddWaypointDialogState();
}

class _AddWaypointDialogState extends State<AddWaypointDialog> {
  final _labelCtrl = TextEditingController();
  bool _copyPins = false;
  bool _copyTimeline = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Add Waypoint',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelCtrl,
              autofocus: true,
              style: TextStyle(fontSize: 12, color: p.uiFloatingText),
              decoration: InputDecoration(
                labelText: 'Name (number, date or text)',
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: p.uiFloatingText.withValues(alpha: 0.6),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            _check('Copy map pins', _copyPins, (v) {
              setState(() => _copyPins = v ?? false);
            }),
            _check('Copy timeline pins', _copyTimeline, (v) {
              setState(() => _copyTimeline = v ?? false);
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TextStyle(color: p.uiFloatingText)),
        ),
        ElevatedButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(
              context,
              AddWaypointResult(
                label: label,
                copyPins: _copyPins,
                copyTimelinePins: _copyTimeline,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool?> onChanged) {
    final p = widget.palette;
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(value: value, onChanged: onChanged),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 11, color: p.uiFloatingText)),
      ],
    );
  }
}

/// Dialog for deleting a waypoint with merge strategy selection.
class DeleteWaypointDialog extends StatefulWidget {
  final DmToolColors palette;
  final String waypointLabel;

  const DeleteWaypointDialog({
    super.key,
    required this.palette,
    required this.waypointLabel,
  });

  @override
  State<DeleteWaypointDialog> createState() => _DeleteWaypointDialogState();
}

class _DeleteWaypointDialogState extends State<DeleteWaypointDialog> {
  EraMergeStrategy _strategy = EraMergeStrategy.merge;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Delete: ${widget.waypointLabel}',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: RadioGroup<EraMergeStrategy>(
        groupValue: _strategy,
        onChanged: (v) => setState(() => _strategy = v ?? _strategy),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _radio(EraMergeStrategy.merge, 'Merge both segments'),
            _radio(EraMergeStrategy.keepLeft, 'Keep left, discard right'),
            _radio(EraMergeStrategy.keepRight, 'Keep right, discard left'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TextStyle(color: p.uiFloatingText)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
          onPressed: () => Navigator.pop(context, _strategy),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _radio(EraMergeStrategy value, String label) {
    final p = widget.palette;
    return RadioListTile<EraMergeStrategy>(
      value: value,
      title: Text(label,
          style: TextStyle(fontSize: 12, color: p.uiFloatingText)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Dialog to pick which era to copy a pin to.
class CopyToEraDialog extends StatelessWidget {
  final DmToolColors palette;
  final List<String> eraNames;
  final int currentEraIndex;

  const CopyToEraDialog({
    super.key,
    required this.palette,
    required this.eraNames,
    required this.currentEraIndex,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final options = <int>[];
    for (int i = 0; i < eraNames.length; i++) {
      if (i != currentEraIndex) options.add(i);
    }

    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Copy to...',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((i) {
            return ListTile(
              dense: true,
              title: Text(eraNames[i],
                  style:
                      TextStyle(fontSize: 12, color: p.uiFloatingText)),
              onTap: () => Navigator.pop(context, i),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Dialog to rename a waypoint.
class RenameWaypointDialog extends StatefulWidget {
  final DmToolColors palette;
  final String currentLabel;

  const RenameWaypointDialog({
    super.key,
    required this.palette,
    required this.currentLabel,
  });

  @override
  State<RenameWaypointDialog> createState() => _RenameWaypointDialogState();
}

class _RenameWaypointDialogState extends State<RenameWaypointDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentLabel);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Rename Waypoint',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: TextStyle(fontSize: 12, color: p.uiFloatingText),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          labelText: 'Label',
          labelStyle: TextStyle(
            fontSize: 11,
            color: p.uiFloatingText.withValues(alpha: 0.6),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TextStyle(color: p.uiFloatingText)),
        ),
        ElevatedButton(
          onPressed: () {
            final label = _ctrl.text.trim();
            if (label.isNotEmpty) Navigator.pop(context, label);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
