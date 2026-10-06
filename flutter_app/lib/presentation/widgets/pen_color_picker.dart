import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Pen palette shared by the mind map and battle map draw tools.
const List<Color> kPenColors = [
  Color(0xFFEF5350),
  Color(0xFFFFA726),
  Color(0xFFFFEE58),
  Color(0xFF66BB6A),
  Color(0xFF42A5F5),
  Color(0xFFAB47BC),
  Color(0xFFEC407A),
  Color(0xFF8D6E63),
  Color(0xFFFFFFFF),
  Color(0xFF212121),
];

/// Color list menu at [position] plus a "custom" entry opening HSV sliders.
/// Null when dismissed.
Future<Color?> pickPenColor(
  BuildContext context, {
  required RelativeRect position,
  required Color current,
  required DmToolColors palette,
}) async {
  final picked = await showMenu<Object>(
    context: context,
    position: position,
    color: palette.uiFloatingBg,
    constraints: const BoxConstraints(minWidth: 48, maxWidth: 48),
    items: [
      for (final c in kPenColors)
        PopupMenuItem<Object>(
          value: c,
          height: 36,
          padding: EdgeInsets.zero,
          child: Center(child: PenSwatch(color: c, selected: c == current)),
        ),
      PopupMenuItem<Object>(
        value: 'custom',
        height: 36,
        padding: EdgeInsets.zero,
        child: Center(
          child: Tooltip(
            message: L10n.of(context)!.mindMapCustomColor,
            child: Icon(Icons.palette_outlined,
                size: 20, color: palette.uiFloatingText),
          ),
        ),
      ),
    ],
  );
  if (picked is Color) return picked;
  if (picked == 'custom' && context.mounted) {
    return showDialog<Color>(
      context: context,
      builder: (_) => _CustomColorDialog(initial: current, palette: palette),
    );
  }
  return null;
}

/// Toolbar button showing [color]'s swatch; tapping opens [pickPenColor]
/// under the button and writes the choice back into [color]. With [label]
/// the swatch gets a caption under it, like the labelled tool buttons.
class PenColorButton extends StatelessWidget {
  final ValueNotifier<Color> color;
  final DmToolColors palette;
  final String tooltip;
  final String? label;
  final double swatchSize;

  /// Fixed width, to line up with neighbouring labelled buttons.
  final double? width;

  const PenColorButton({
    required this.color,
    required this.palette,
    required this.tooltip,
    this.label,
    this.swatchSize = 22,
    this.width,
    super.key,
  });

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final picked = await pickPenColor(
      context,
      position: RelativeRect.fromRect(
          rect.translate(0, rect.height), Offset.zero & overlay.size),
      current: color.value,
      palette: palette,
    );
    if (picked != null) color.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: palette.br,
        child: Container(
          width: width,
          padding: label == null
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<Color>(
                valueListenable: color,
                builder: (_, c, _) => PenSwatch(color: c, size: swatchSize),
              ),
              if (label != null) ...[
                const SizedBox(height: 2),
                Text(
                  label!,
                  style: TextStyle(fontSize: 9, color: palette.tabText),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PenSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final double size;
  const PenSwatch({
    required this.color,
    this.selected = false,
    this.size = 22,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: selected
          ? Icon(Icons.check,
              size: 14,
              color: color.computeLuminance() > 0.5
                  ? Colors.black
                  : Colors.white)
          : null,
    );
  }
}

/// Free color pick — HSV sliders over a live preview.
class _CustomColorDialog extends StatefulWidget {
  final Color initial;
  final DmToolColors palette;
  const _CustomColorDialog({required this.initial, required this.palette});

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Widget _slider(String label, double value, double max,
      HSVColor Function(double) apply) {
    final text = TextStyle(color: widget.palette.uiFloatingText, fontSize: 12);
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: text)),
        Expanded(
          child: Slider(
            value: value,
            max: max,
            activeColor: _hsv.toColor(),
            onChanged: (v) => setState(() => _hsv = apply(v)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = widget.palette;
    return AlertDialog(
      backgroundColor: palette.uiFloatingBg,
      title: Text(l10n.mindMapCustomColor,
          style: TextStyle(color: palette.uiFloatingText, fontSize: 14)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: _hsv.toColor(),
                borderRadius: palette.cbr,
                border: Border.all(color: palette.uiFloatingBorder),
              ),
            ),
            const SizedBox(height: 12),
            _slider(l10n.colorHue, _hsv.hue, 360, _hsv.withHue),
            _slider(l10n.colorSaturation, _hsv.saturation, 1,
                _hsv.withSaturation),
            _slider(l10n.colorBrightness, _hsv.value, 1, _hsv.withValue),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel,
              style: TextStyle(color: palette.uiFloatingText)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _hsv.toColor()),
          child: Text(l10n.btnSave),
        ),
      ],
    );
  }
}
