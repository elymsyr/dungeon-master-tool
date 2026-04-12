import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Virgül veya enter ile tag eklemeye izin veren küçük text input.
/// Girilen tag'ler küçük harfe çevrilir ve trim edilir; boş/mükerrer
/// tag'ler sessizce atlanır. Chip'e tıklanınca kaldırılır.
class TagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String? label;
  final String? hint;
  final int maxTags;

  const TagInput({
    super.key,
    required this.tags,
    required this.onChanged,
    this.label,
    this.hint,
    this.maxTags = 10,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parts = raw
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty);
    final next = <String>[...widget.tags];
    for (final p in parts) {
      if (next.length >= widget.maxTags) break;
      if (!next.contains(p)) next.add(p);
    }
    widget.onChanged(next);
    _ctrl.clear();
  }

  void _remove(String tag) {
    final next = [...widget.tags]..remove(tag);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.tags
                    .map((t) => InputChip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => _remove(t),
                          backgroundColor: palette.featureCardBg,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
            ),
            onSubmitted: (v) {
              _commit(v);
              _focus.requestFocus();
            },
            onChanged: (v) {
              if (v.endsWith(',')) _commit(v);
            },
          ),
        ],
      ),
    );
  }
}
