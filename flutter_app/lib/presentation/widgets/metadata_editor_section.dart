import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Kart metadata'sı için shared editor: cover image + name + description + tags.
/// Worlds / Packages / Templates / Characters settings dialog'larında aynı
/// görünümü sağlar.
///
/// Değer değişikliklerini parent'a [onChanged] ile bildirir — parent
/// mutable state'i kendisi tutar (freezed copyWith veya data map mutasyonu).
class MetadataEditorSection extends StatefulWidget {
  final String name;
  final String description;
  final List<String> tags;
  final String coverImagePath;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<List<String>> onTagsChanged;
  final ValueChanged<String> onCoverChanged;

  /// Show the name field (hidden when name editing is handled elsewhere,
  /// e.g. Worlds where campaign rename is a heavier operation).
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
  State<MetadataEditorSection> createState() => _MetadataEditorSectionState();
}

class _MetadataEditorSectionState extends State<MetadataEditorSection> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _tagCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _descCtrl = TextEditingController(text: widget.description);
    _tagCtrl = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant MetadataEditorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && _nameCtrl.text != widget.name) {
      _nameCtrl.text = widget.name;
    }
    if (oldWidget.description != widget.description &&
        _descCtrl.text != widget.description) {
      _descCtrl.text = widget.description;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _coverPreview(palette),
        const SizedBox(height: 12),
        if (widget.showNameField) ...[
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              isDense: true,
            ),
            onChanged: widget.onNameChanged,
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _descCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Description',
            isDense: true,
            alignLabelWithHint: true,
          ),
          onChanged: widget.onDescriptionChanged,
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Tags',
            isDense: true,
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.tags.map((t) => Chip(
                    label: Text(t, style: const TextStyle(fontSize: 11)),
                    deleteIconColor: palette.sidebarLabelSecondary,
                    onDeleted: () {
                      final updated = [...widget.tags]..remove(t);
                      widget.onTagsChanged(updated);
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  )),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _tagCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: '+ add tag',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (v) {
                    final tag = v.trim();
                    if (tag.isEmpty) return;
                    if (widget.tags.contains(tag)) {
                      _tagCtrl.clear();
                      return;
                    }
                    widget.onTagsChanged([...widget.tags, tag]);
                    _tagCtrl.clear();
                  },
                ),
              ),
            ],
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
        height: 140,
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
                      size: 32, color: palette.sidebarLabelSecondary),
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
