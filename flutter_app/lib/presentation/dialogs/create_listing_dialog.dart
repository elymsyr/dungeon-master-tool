import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/social_providers.dart';
import '../../core/utils/world_languages.dart';
import '../l10n/app_localizations.dart';
import '../widgets/tag_input.dart';

/// Yeni oyun ilanı oluşturma dialog'u. Title + description + system + seats
/// + schedule + language + tags toplar ve [GameListingComposerNotifier]
/// üzerinden yayınlar.
class CreateListingDialog extends ConsumerStatefulWidget {
  const CreateListingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const CreateListingDialog(),
    );
  }

  @override
  ConsumerState<CreateListingDialog> createState() => _CreateListingDialogState();
}

class _CreateListingDialogState extends ConsumerState<CreateListingDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _systemCtrl = TextEditingController(text: 'D&D 5e');
  final _seatsCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();
  String? _language;
  List<String> _tags = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _systemCtrl.dispose();
    _seatsCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _titleCtrl.text.trim().length >= 3;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final busy = ref.watch(gameListingComposerProvider) is AsyncLoading;
    return AlertDialog(
      title: Text(l10n.createListingTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.listingTitleLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.listingDescriptionLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _systemCtrl,
                decoration: InputDecoration(
                  labelText: l10n.listingSystemLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _language,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.listingLanguageLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.marketplaceFilterAny),
                  ),
                  ...worldLanguages.map(
                    (lang) => DropdownMenuItem(
                      value: lang.code,
                      child: Text(lang.native, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _language = v),
              ),
              const SizedBox(height: 10),
              TagInput(
                tags: _tags,
                label: l10n.listingTagsLabel,
                hint: l10n.listingTagsHint,
                onChanged: (v) => setState(() => _tags = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _seatsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.listingSeatsLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _scheduleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.listingScheduleLabel,
                  border: const OutlineInputBorder(),
                ),
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
          onPressed: (!_canSubmit || busy)
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final ok = await ref.read(gameListingComposerProvider.notifier).create(
                        title: _titleCtrl.text.trim(),
                        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                        system: _systemCtrl.text.trim().isEmpty ? null : _systemCtrl.text.trim(),
                        seatsTotal: int.tryParse(_seatsCtrl.text.trim()),
                        schedule: _scheduleCtrl.text.trim().isEmpty ? null : _scheduleCtrl.text.trim(),
                        gameLanguage: _language,
                        tags: _tags,
                      );
                  if (!mounted) return;
                  if (ok) navigator.pop();
                },
          child: Text(l10n.listingPostAction),
        ),
      ],
    );
  }
}
