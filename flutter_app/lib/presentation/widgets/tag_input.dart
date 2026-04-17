import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/global_tags_provider.dart';
import '../../application/services/tag_moderation.dart';

/// Plain comma-separated tag input with inline global-tag autocomplete.
/// Kullanıcı virgül yazdıkça veya submit ettikçe tag listesi güncellenir;
/// aynı anda altta açılan bir Material overlay global tag önerileri gösterir.
/// Davranış `metadata_editor_section._tagsField` ile bire bir aynıdır.
class TagInput extends ConsumerStatefulWidget {
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
  ConsumerState<TagInput> createState() => _TagInputState();
}

class _TagInputState extends ConsumerState<TagInput> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.tags.join(', '));
  }

  @override
  void didUpdateWidget(covariant TagInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final joined = widget.tags.join(', ');
    // Parent'tan gelen değişiklikleri yakala — yalnızca inline düzenleme
    // sırasında controller metnini ezme.
    if (!_focus.hasFocus && _ctrl.text != joined) {
      _ctrl.text = joined;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parts = raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    String? err;
    final accepted = <String>[];
    for (final p in parts) {
      if (accepted.length >= widget.maxTags) break;
      final reason = TagModeration.validate(p);
      if (reason != null) {
        err = '"$p": $reason';
        continue;
      }
      if (!accepted.contains(p)) accepted.add(p);
    }
    setState(() => _error = err);
    widget.onChanged(accepted);
  }

  @override
  Widget build(BuildContext context) {
    final globalTags = ref.watch(globalTagsProvider);
    return RawAutocomplete<String>(
      focusNode: _focus,
      textEditingController: _ctrl,
      optionsBuilder: (TextEditingValue value) {
        final text = value.text;
        final lastComma = text.lastIndexOf(',');
        final current =
            (lastComma >= 0 ? text.substring(lastComma + 1) : text)
                .trim()
                .toLowerCase();
        if (current.isEmpty) return const Iterable<String>.empty();
        final already =
            text.split(',').map((s) => s.trim().toLowerCase()).toSet();
        return globalTags
            .where((t) =>
                t.toLowerCase().contains(current) &&
                !already.contains(t.toLowerCase()))
            .take(8);
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint ?? 'comma, separated, tags',
            errorText: _error,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: _commit,
          onSubmitted: (_) {
            onSubmit();
            _commit(controller.text);
          },
        );
      },
      onSelected: (option) {
        final text = _ctrl.text;
        final lastComma = text.lastIndexOf(',');
        final head =
            lastComma >= 0 ? '${text.substring(0, lastComma + 1)} ' : '';
        final replaced = '$head$option, ';
        _ctrl.value = TextEditingValue(
          text: replaced,
          selection: TextSelection.collapsed(offset: replaced.length),
        );
        _commit(replaced);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child:
                          Text(opt, style: const TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
