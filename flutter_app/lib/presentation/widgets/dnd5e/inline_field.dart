import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/edit_mode_provider.dart';
import '../../theme/dm_tool_colors.dart';

/// Inline editable text cell used by typed cards. Renders as a plain text
/// line; becomes a `TextField` on tap when the global [editModeProvider]
/// is on. Commits (via [onCommit]) when the user loses focus or presses
/// Enter. With edit mode off, tap is a no-op and the text renders as
/// read-only (no hover affordance, no ripple).
class InlineTextField extends ConsumerStatefulWidget {
  final String value;
  final ValueChanged<String> onCommit;
  final TextStyle? style;
  final int? maxLines;
  final String? placeholder;
  final TextAlign textAlign;

  const InlineTextField({
    required this.value,
    required this.onCommit,
    this.style,
    this.maxLines = 1,
    this.placeholder,
    this.textAlign = TextAlign.start,
    super.key,
  });

  @override
  ConsumerState<InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends ConsumerState<InlineTextField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant InlineTextField old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _editing) _commit();
  }

  void _commit() {
    final next = _ctrl.text;
    setState(() => _editing = false);
    if (next != widget.value) widget.onCommit(next);
  }

  void _startEdit() {
    setState(() => _editing = true);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<DmToolColors>()!;
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;
    final editMode = ref.watch(editModeProvider);
    // If edit mode flips off mid-edit, commit and drop to read-only.
    if (!editMode && _editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editing) _commit();
      });
    }
    if (_editing && editMode) {
      return TextField(
        controller: _ctrl,
        focusNode: _focus,
        maxLines: widget.maxLines,
        minLines: 1,
        style: baseStyle,
        textAlign: widget.textAlign,
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          isDense: true,
          border: const UnderlineInputBorder(),
          focusedBorder: const UnderlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: palette.padXs),
        ),
      );
    }
    final display = widget.value.trim().isEmpty
        ? (widget.placeholder ?? '—')
        : widget.value;
    final muted = widget.value.trim().isEmpty;
    final text = Container(
      padding: EdgeInsets.symmetric(vertical: palette.padXs),
      width: double.infinity,
      child: Text(
        display,
        textAlign: widget.textAlign,
        style: baseStyle?.copyWith(
          color: muted ? theme.hintColor : baseStyle.color,
          fontStyle: muted ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
    if (!editMode) return text;
    return InkWell(
      onTap: _startEdit,
      borderRadius: BorderRadius.circular(palette.radiusSm),
      child: text,
    );
  }
}

/// Inline editable integer cell — reuses [InlineTextField] but restricts
/// input to digits (optional leading minus) and converts to int on commit.
/// Invalid input keeps the previous value.
class InlineIntField extends StatelessWidget {
  final int value;
  final ValueChanged<int> onCommit;
  final TextStyle? style;
  final bool allowNegative;
  final TextAlign textAlign;

  const InlineIntField({
    required this.value,
    required this.onCommit,
    this.style,
    this.allowNegative = false,
    this.textAlign = TextAlign.start,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InlineTextField(
      value: value.toString(),
      style: style,
      textAlign: textAlign,
      onCommit: (raw) {
        final parsed = int.tryParse(raw.trim());
        if (parsed == null) return;
        if (!allowNegative && parsed < 0) return;
        onCommit(parsed);
      },
    );
  }
}

/// Non-inline primitive: restricted to digit inputs. Useful inside forms
/// where a dedicated digit keyboard is wanted.
final _digitsOnly = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];
List<TextInputFormatter> digitsOnly() => _digitsOnly;
