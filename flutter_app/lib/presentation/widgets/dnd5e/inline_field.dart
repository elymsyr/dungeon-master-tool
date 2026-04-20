import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Inline editable text cell used by typed cards. Renders as a plain text
/// line that becomes a `TextField` on tap; commits (via [onCommit]) when
/// the user loses focus or presses Enter. Multi-line fields stay as a
/// `TextFormField` with a subtle underline and no floating label so the
/// paper look is preserved.
class InlineTextField extends StatefulWidget {
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
  State<InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<InlineTextField> {
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
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;
    if (_editing) {
      return TextField(
        controller: _ctrl,
        focusNode: _focus,
        maxLines: widget.maxLines,
        minLines: 1,
        style: baseStyle,
        textAlign: widget.textAlign,
        onSubmitted: (_) => _commit(),
        decoration: const InputDecoration(
          isDense: true,
          border: UnderlineInputBorder(),
          focusedBorder: UnderlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 4),
        ),
      );
    }
    final display = widget.value.trim().isEmpty
        ? (widget.placeholder ?? '—')
        : widget.value;
    final muted = widget.value.trim().isEmpty;
    return InkWell(
      onTap: _startEdit,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        width: double.infinity,
        child: Text(
          display,
          textAlign: widget.textAlign,
          style: baseStyle?.copyWith(
            color: muted ? theme.hintColor : baseStyle.color,
            fontStyle: muted ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
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
