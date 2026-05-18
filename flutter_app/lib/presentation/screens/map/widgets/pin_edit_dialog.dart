import 'package:flutter/material.dart';

import '../../../../domain/entities/map_data.dart';
import '../../../theme/dm_tool_colors.dart';

/// Curated icon set the user can choose from when overriding a pin's icon.
/// Mirrors `_iconFromName` in world_map_screen.dart — only public material
/// names appear here so the override persists across rebuilds.
const List<(String, IconData)> kPinIconChoices = [
  ('location_on', Icons.location_on),
  ('location_pin', Icons.location_pin),
  ('person_pin', Icons.person_pin),
  ('person', Icons.person),
  ('pets', Icons.pets),
  ('colorize', Icons.colorize),
  ('shield', Icons.shield),
  ('castle', Icons.castle),
  ('forest', Icons.forest),
  ('home', Icons.home),
  ('flag', Icons.flag),
  ('event', Icons.event),
  ('map', Icons.map),
  ('directions_boat', Icons.directions_boat),
  ('inventory_2', Icons.inventory_2),
  ('backpack', Icons.backpack),
  ('diamond', Icons.diamond),
  ('auto_fix_high', Icons.auto_fix_high),
  ('auto_awesome', Icons.auto_awesome),
  ('stars', Icons.stars),
  ('history_edu', Icons.history_edu),
  ('workspaces', Icons.workspaces),
  ('diversity_3', Icons.diversity_3),
  ('fork_right', Icons.fork_right),
  ('build', Icons.build),
  ('flash_on', Icons.flash_on),
  ('cruelty_free', Icons.cruelty_free),
  ('album', Icons.album),
  ('location_city', Icons.location_city),
];

const List<String> kPinColorChoices = [
  '#42a5f5',
  '#ef5350',
  '#66bb6a',
  '#ffa726',
  '#ab47bc',
  '#26c6da',
  '#ec407a',
  '#8d6e63',
  '#78909c',
  '#ffee58',
];

/// Centered, theme-aware dialog editing label / note / color / icon override
/// for a single [MapPin]. Returns the updated pin or null if cancelled.
class PinEditDialog extends StatefulWidget {
  final MapPin pin;
  final DmToolColors palette;
  final bool allowDelete;

  const PinEditDialog({
    super.key,
    required this.pin,
    required this.palette,
    this.allowDelete = false,
  });

  static Future<PinEditResult?> show(
    BuildContext context,
    MapPin pin,
    DmToolColors palette, {
    bool allowDelete = false,
  }) {
    return showDialog<PinEditResult>(
      context: context,
      builder: (_) => PinEditDialog(
        pin: pin,
        palette: palette,
        allowDelete: allowDelete,
      ),
    );
  }

  @override
  State<PinEditDialog> createState() => _PinEditDialogState();
}

class PinEditResult {
  final MapPin? pin; // null = delete
  const PinEditResult.update(MapPin this.pin);
  const PinEditResult.delete() : pin = null;
}

class _PinEditDialogState extends State<PinEditDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _noteCtrl;
  late String _color;
  late String _iconName;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.pin.label);
    _noteCtrl = TextEditingController(text: widget.pin.note);
    _color = widget.pin.color;
    final iconOverride = widget.pin.style['icon'];
    _iconName = iconOverride is String ? iconOverride : '';
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final style = Map<String, dynamic>.from(widget.pin.style);
    if (_iconName.isEmpty) {
      style.remove('icon');
    } else {
      style['icon'] = _iconName;
    }
    final updated = widget.pin.copyWith(
      label: _labelCtrl.text.trim(),
      note: _noteCtrl.text,
      color: _color,
      style: style,
    );
    Navigator.of(context).pop(PinEditResult.update(updated));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final labelStyle = TextStyle(
      fontSize: 11,
      color: palette.uiFloatingText.withValues(alpha: 0.6),
    );
    final fieldStyle = TextStyle(fontSize: 12, color: palette.uiFloatingText);

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: labelStyle,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: palette.cbr,
            borderSide: BorderSide(color: palette.uiFloatingBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: palette.cbr,
            borderSide: BorderSide(color: palette.uiFloatingBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: palette.cbr,
            borderSide:
                BorderSide(color: palette.featureCardAccent, width: 1.5),
          ),
        );

    return AlertDialog(
      backgroundColor: palette.uiFloatingBg,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      title: Text(
        'Edit Pin',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: palette.uiFloatingText,
        ),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelCtrl,
                style: fieldStyle,
                decoration: deco('Label'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                style: fieldStyle,
                minLines: 2,
                maxLines: 4,
                decoration: deco('Note'),
              ),
              const SizedBox(height: 14),
              Text('Color', style: labelStyle),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kPinColorChoices.map((hex) {
                  final c = Color(
                    int.parse(hex.replaceAll('#', 'FF'), radix: 16),
                  );
                  final active = _color == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: active
                            ? Border.all(
                                color: palette.uiFloatingText, width: 2)
                            : Border.all(
                                color: palette.uiFloatingBorder, width: 1),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text('Icon', style: labelStyle),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _iconChip(
                    name: '',
                    icon: Icons.refresh,
                    active: _iconName.isEmpty,
                    tooltip: 'Use category default',
                  ),
                  ...kPinIconChoices.map(
                    (e) => _iconChip(
                      name: e.$1,
                      icon: e.$2,
                      active: _iconName == e.$1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      actions: [
        if (widget.allowDelete)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const PinEditResult.delete()),
            child: Text(
              'Delete',
              style: TextStyle(color: palette.dangerBtnBg),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: palette.uiFloatingText),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: palette.primaryBtnBg,
            foregroundColor: palette.primaryBtnText,
            shape: RoundedRectangleBorder(borderRadius: palette.br),
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _iconChip({
    required String name,
    required IconData icon,
    required bool active,
    String? tooltip,
  }) {
    final palette = widget.palette;
    final chip = GestureDetector(
      onTap: () => setState(() => _iconName = name),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active
              ? palette.featureCardAccent.withValues(alpha: 0.25)
              : palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(
            color: active ? palette.featureCardAccent : palette.uiFloatingBorder,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Icon(icon, size: 18, color: palette.uiFloatingText),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}
