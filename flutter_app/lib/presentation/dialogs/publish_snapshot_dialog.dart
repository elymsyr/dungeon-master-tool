import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/marketplace_listing_provider.dart';
import '../../core/utils/world_languages.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/tag_input.dart';

/// Owner-side: collects metadata for a brand-new immutable snapshot. Each
/// invocation always produces a *new* listing — there is no "edit existing"
/// path. If the local item already has a lineage, the new snapshot joins
/// it and supersedes the previous current; the user can override that with
/// the "Start fresh lineage" toggle to publish an independent listing.
///
/// Returns the freshly published [MarketplaceListing] on success, or null
/// when the user cancels / no-op publish is detected.
Future<MarketplaceListing?> showPublishSnapshotDialog({
  required BuildContext context,
  required String itemType,
  required String localId,
  required String defaultTitle,
  String? defaultDescription,
  required bool hasExistingLineage,
}) {
  return showDialog<MarketplaceListing?>(
    context: context,
    builder: (_) => _PublishSnapshotDialog(
      itemType: itemType,
      localId: localId,
      defaultTitle: defaultTitle,
      defaultDescription: defaultDescription,
      hasExistingLineage: hasExistingLineage,
    ),
  );
}

class _PublishSnapshotDialog extends ConsumerStatefulWidget {
  final String itemType;
  final String localId;
  final String defaultTitle;
  final String? defaultDescription;
  final bool hasExistingLineage;

  const _PublishSnapshotDialog({
    required this.itemType,
    required this.localId,
    required this.defaultTitle,
    this.defaultDescription,
    required this.hasExistingLineage,
  });

  @override
  ConsumerState<_PublishSnapshotDialog> createState() =>
      _PublishSnapshotDialogState();
}

class _PublishSnapshotDialogState
    extends ConsumerState<_PublishSnapshotDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _changelogCtrl;
  String? _language;
  List<String> _tags = const [];
  bool _freshLineage = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.defaultTitle);
    _descCtrl = TextEditingController(text: widget.defaultDescription ?? '');
    _changelogCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _changelogCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final l10n = L10n.of(context)!;
    final missing = <String>[];
    if (_titleCtrl.text.trim().isEmpty) missing.add(l10n.publishDialogTitleLabel);
    if (_descCtrl.text.trim().isEmpty) {
      missing.add(l10n.publishDialogDescriptionLabel);
    }
    if (_language == null || _language!.isEmpty) {
      missing.add(l10n.publishDialogLanguageLabel);
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.publishDialogMissingFields(missing.join(', '))),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final listing = await ref
          .read(marketplaceListingNotifierProvider.notifier)
          .publishSnapshot(
            itemType: widget.itemType,
            localId: widget.localId,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            language: _language,
            tags: _tags,
            changelog: _changelogCtrl.text.trim().isEmpty
                ? null
                : _changelogCtrl.text.trim(),
            freshLineage: _freshLineage,
          );
      if (!mounted) return;
      Navigator.pop(context, listing);
    } on NoChangesSinceLastSnapshotException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publishDialogNoChanges)),
      );
      Navigator.pop(context, null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publishDialogFailed('$e'))),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return AlertDialog(
      title: Text(l10n.publishSnapshotDialogHeading),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ImmutabilityNotice(
                hasExistingLineage: widget.hasExistingLineage,
                palette: palette,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.publishDialogTitleLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n.publishDialogDescriptionLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _language,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  labelText: l10n.publishDialogLanguageLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: worldLanguages
                    .map((lang) => DropdownMenuItem(
                          value: lang.code,
                          child: Text(
                            lang.native,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _language = v),
              ),
              const SizedBox(height: 10),
              TagInput(
                tags: _tags,
                label: l10n.publishDialogTagsLabel,
                hint: l10n.publishDialogTagsHint,
                onChanged: (v) => setState(() => _tags = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _changelogCtrl,
                maxLines: 2,
                maxLength: 280,
                decoration: InputDecoration(
                  labelText: l10n.publishDialogChangelogLabel,
                  hintText: l10n.publishDialogChangelogHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 13),
              ),
              if (widget.hasExistingLineage) ...[
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: _freshLineage,
                  onChanged: (v) => setState(() => _freshLineage = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  dense: true,
                  title: Text(
                    l10n.publishDialogFreshLineage,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    l10n.publishDialogFreshLineageHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, null),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _publish,
          child: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.publishDialogPublish),
        ),
      ],
    );
  }
}

class _ImmutabilityNotice extends StatelessWidget {
  final bool hasExistingLineage;
  final DmToolColors palette;
  const _ImmutabilityNotice({
    required this.hasExistingLineage,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final body = hasExistingLineage
        ? l10n.publishDialogImmutabilityNoticeExisting
        : l10n.publishDialogImmutabilityNoticeNew;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline,
              size: 16, color: palette.featureCardAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              body,
              style: TextStyle(fontSize: 11, color: palette.tabActiveText),
            ),
          ),
        ],
      ),
    );
  }
}
