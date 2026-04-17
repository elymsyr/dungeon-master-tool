import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/global_tags_provider.dart';
import '../../application/services/tag_moderation.dart';
import '../theme/dm_tool_colors.dart';

/// Kart metadata'sı için shared editor: cover image + name + description + tags.
/// Worlds / Packages / Templates / Characters settings dialog'larında aynı
/// görünümü sağlar. Tag alanı düz yazı (virgülle ayrılır), global tag
/// havuzundan autocomplete önerir ve moderation ile zararlı içerik engellenir.
class MetadataEditorSection extends ConsumerStatefulWidget {
  final String name;
  final String description;
  final List<String> tags;
  final String coverImagePath;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<List<String>> onTagsChanged;
  final ValueChanged<String> onCoverChanged;

  /// Name alanını gizle — entity_card gibi başka bir yerde isim düzenleniyorsa.
  final bool showNameField;

  const MetadataEditorSection({
    super.key,
    required this.name,
    required this.description,
    required this.tags,
    required this.coverImagePath,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onTagsChanged,
    required this.onCoverChanged,
    this.showNameField = true,
  });

  @override
  ConsumerState<MetadataEditorSection> createState() =>
      _MetadataEditorSectionState();
}

class _MetadataEditorSectionState
    extends ConsumerState<MetadataEditorSection> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _tagsCtrl;
  final FocusNode _tagsFocus = FocusNode();
  String? _tagsError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _descCtrl = TextEditingController(text: widget.description);
    _tagsCtrl = TextEditingController(text: widget.tags.join(', '));
  }

  @override
  void didUpdateWidget(covariant MetadataEditorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && !_nameCtrl.selection.isValid) {
      _nameCtrl.text = widget.name;
    }
    if (oldWidget.description != widget.description &&
        !_descCtrl.selection.isValid) {
      _descCtrl.text = widget.description;
    }
    if (oldWidget.tags.join(',') != widget.tags.join(',') &&
        !_tagsFocus.hasFocus) {
      _tagsCtrl.text = widget.tags.join(', ');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _tagsFocus.dispose();
    super.dispose();
  }

  /// Parse + validate + commit tag string.
  void _commitTags(String raw) {
    final parts = raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    String? error;
    final accepted = <String>[];
    for (final p in parts) {
      final reason = TagModeration.validate(p);
      if (reason != null) {
        error = '"$p": $reason';
        continue;
      }
      if (!accepted.contains(p)) accepted.add(p);
    }
    setState(() => _tagsError = error);
    widget.onTagsChanged(accepted);
  }

  /// Unified content padding — all input rows share the same internal
  /// padding so their visible heights match. Top padding is slightly
  /// taller than bottom so the caret sits comfortably below the label.
  static const EdgeInsets _inputPadding =
      EdgeInsets.fromLTRB(12, 14, 12, 12);

  InputDecoration _deco({
    required String labelText,
    String? hintText,
    String? errorText,
  }) =>
      InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        contentPadding: _inputPadding,
        isDense: false,
        alignLabelWithHint: true,
      );

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final globalTags = ref.watch(globalTagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _coverPreview(palette),
        const SizedBox(height: 12),
        if (widget.showNameField) ...[
          TextField(
            controller: _nameCtrl,
            decoration: _deco(labelText: 'Name'),
            onChanged: widget.onNameChanged,
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _descCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: _deco(labelText: 'Description'),
          onChanged: widget.onDescriptionChanged,
        ),
        const SizedBox(height: 8),
        _tagsField(palette, globalTags),
      ],
    );
  }

  Widget _tagsField(DmToolColors palette, Set<String> globalTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RawAutocomplete<String>(
          focusNode: _tagsFocus,
          textEditingController: _tagsCtrl,
          optionsBuilder: (TextEditingValue value) {
            // Kullanıcının yazdığı son parçayı al (virgülden sonra).
            final text = value.text;
            final lastComma = text.lastIndexOf(',');
            final current = (lastComma >= 0
                    ? text.substring(lastComma + 1)
                    : text)
                .trim()
                .toLowerCase();
            if (current.isEmpty) return const Iterable<String>.empty();
            final already = text
                .split(',')
                .map((s) => s.trim().toLowerCase())
                .toSet();
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
              decoration: _deco(
                labelText: 'Tags',
                hintText: 'comma, separated, tags',
                errorText: _tagsError,
              ),
              onChanged: _commitTags,
              onSubmitted: (_) {
                onSubmit();
                _commitTags(controller.text);
              },
            );
          },
          onSelected: (option) {
            final text = _tagsCtrl.text;
            final lastComma = text.lastIndexOf(',');
            final head = lastComma >= 0
                ? '${text.substring(0, lastComma + 1)} '
                : '';
            final replaced = '$head$option, ';
            _tagsCtrl.value = TextEditingValue(
              text: replaced,
              selection: TextSelection.collapsed(offset: replaced.length),
            );
            _commitTags(replaced);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: 360, maxHeight: 200),
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
                          child: Text(opt,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (globalTags.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Type tags separated by commas. Suggestions appear as you type.',
              style: TextStyle(
                fontSize: 10,
                color: palette.sidebarLabelSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _coverPreview(DmToolColors palette) {
    final hasImage = widget.coverImagePath.isNotEmpty &&
        File(widget.coverImagePath).existsSync();

    return InkWell(
      onTap: _pickCover,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: palette.featureCardBorder),
          image: hasImage
              ? DecorationImage(
                  image: FileImage(File(widget.coverImagePath)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: hasImage
            ? Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => widget.onCoverChanged(''),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 36, color: palette.sidebarLabelSecondary),
                  const SizedBox(height: 4),
                  Text('Add cover image',
                      style: TextStyle(
                          fontSize: 12,
                          color: palette.sidebarLabelSecondary)),
                ],
              ),
      ),
    );
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.firstOrNull?.path;
    if (path != null) widget.onCoverChanged(path);
  }
}
