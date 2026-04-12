import 'package:flutter/material.dart';

import '../../core/utils/world_languages.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/tag_input.dart';

class PublishItemResult {
  final String description;
  final String language;
  final List<String> tags;
  const PublishItemResult({
    required this.description,
    required this.language,
    required this.tags,
  });
}

/// Bir world/template/package'ı marketplace'e publish ederken kullanıcıdan
/// description, dil ve tag ister. Sadece bu üçü doluyken onay aktiftir.
class PublishItemDialog extends StatefulWidget {
  final String title;
  final String? initialDescription;
  final String? initialLanguage;
  final List<String>? initialTags;
  final String itemTypeLabel; // 'World' / 'Template' / 'Package'

  const PublishItemDialog({
    super.key,
    required this.title,
    required this.itemTypeLabel,
    this.initialDescription,
    this.initialLanguage,
    this.initialTags,
  });

  static Future<PublishItemResult?> show(
    BuildContext context, {
    required String title,
    required String itemTypeLabel,
    String? initialDescription,
    String? initialLanguage,
    List<String>? initialTags,
  }) {
    return showDialog<PublishItemResult>(
      context: context,
      builder: (_) => PublishItemDialog(
        title: title,
        itemTypeLabel: itemTypeLabel,
        initialDescription: initialDescription,
        initialLanguage: initialLanguage,
        initialTags: initialTags,
      ),
    );
  }

  @override
  State<PublishItemDialog> createState() => _PublishItemDialogState();
}

class _PublishItemDialogState extends State<PublishItemDialog> {
  late final TextEditingController _descCtrl;
  String? _language;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');
    _language = widget.initialLanguage;
    _tags = [...?widget.initialTags];
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _descCtrl.text.trim().isNotEmpty &&
      _language != null &&
      _language!.isNotEmpty &&
      _tags.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return AlertDialog(
      title: Text(l10n.publishDialogTitle(widget.itemTypeLabel, widget.title)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.publishDialogHelp,
                style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.publishDialogDescriptionLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _language,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.publishDialogLanguageLabel,
                  border: const OutlineInputBorder(),
                ),
                items: worldLanguages
                    .map((lang) => DropdownMenuItem(
                          value: lang.code,
                          child: Text(lang.native, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _language = v),
              ),
              const SizedBox(height: 12),
              TagInput(
                tags: _tags,
                label: l10n.publishDialogTagsLabel,
                hint: l10n.publishDialogTagsHint,
                onChanged: (v) => setState(() => _tags = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.pop(
                    context,
                    PublishItemResult(
                      description: _descCtrl.text.trim(),
                      language: _language!,
                      tags: _tags,
                    ),
                  )
              : null,
          child: Text(l10n.publishDialogPublish),
        ),
      ],
    );
  }
}
