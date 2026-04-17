import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/social_providers.dart';
import '../../core/utils/world_languages.dart';
import '../../domain/entities/game_listing.dart';
import '../l10n/app_localizations.dart';
import '../widgets/tag_input.dart';

/// Oyun ilanı oluşturma + düzenleme dialog'u. [existing] null ise create
/// akışı; dolu ise prefilled edit akışı. Başlık + submit buton metni iki
/// modda farklıdır; alanlar aynıdır.
class CreateListingDialog extends ConsumerStatefulWidget {
  final GameListing? existing;

  const CreateListingDialog({super.key, this.existing});

  static Future<void> show(BuildContext context, {GameListing? existing}) {
    return showDialog<void>(
      context: context,
      builder: (_) => CreateListingDialog(existing: existing),
    );
  }

  @override
  ConsumerState<CreateListingDialog> createState() => _CreateListingDialogState();
}

class _CreateListingDialogState extends ConsumerState<CreateListingDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _seatsCtrl;
  late final TextEditingController _scheduleCtrl;
  String? _language;
  List<String> _tags = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _seatsCtrl = TextEditingController(
        text: e?.seatsTotal != null ? '${e!.seatsTotal}' : '');
    _scheduleCtrl = TextEditingController(text: e?.schedule ?? '');
    _language = e?.gameLanguage;
    _tags = List<String>.from(e?.tags ?? const <String>[]);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
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
      title: Text(_isEdit ? l10n.editListingTitle : l10n.createListingTitle),
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
                  final notifier =
                      ref.read(gameListingComposerProvider.notifier);
                  final title = _titleCtrl.text.trim();
                  final description = _descCtrl.text.trim().isEmpty
                      ? null
                      : _descCtrl.text.trim();
                  final seatsTotal = int.tryParse(_seatsCtrl.text.trim());
                  final schedule = _scheduleCtrl.text.trim().isEmpty
                      ? null
                      : _scheduleCtrl.text.trim();
                  final ok = _isEdit
                      ? await notifier.update(
                          listingId: widget.existing!.id,
                          title: title,
                          description: description,
                          seatsTotal: seatsTotal,
                          schedule: schedule,
                          gameLanguage: _language,
                          tags: _tags,
                        )
                      : await notifier.create(
                          title: title,
                          description: description,
                          seatsTotal: seatsTotal,
                          schedule: schedule,
                          gameLanguage: _language,
                          tags: _tags,
                        );
                  if (!mounted) return;
                  if (ok) navigator.pop();
                },
          child: Text(
              _isEdit ? l10n.btnSaveChanges : l10n.listingPostAction),
        ),
      ],
    );
  }
}
