import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/admin_notifications_provider.dart';
import '../../../application/providers/promoted_links_provider.dart';
import '../../../data/datasources/remote/promoted_links_remote_ds.dart';
import '../../../domain/entities/app_notification.dart';
import '../../dialogs/support_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';

/// Admin tab: add / remove the support dialog's "Promoted" links.
class PromotedLinksAdminTab extends ConsumerWidget {
  const PromotedLinksAdminTab({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, PromotedLink p) async {
    final l10n = L10n.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.promotedDeleteConfirm(p.label)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.btnCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.btnDelete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(promotedLinksDataSourceProvider).delete(p.id);
      if (p.imagePath != null) {
        await ref
            .read(adminNotificationsDataSourceProvider)
            .removeImages([p.imagePath!]);
      }
      ref.invalidate(promotedLinksProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context)!.hubErrorGeneric('$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final async = ref.watch(promotedLinksProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(promotedLinksProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.supportPromoted,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText)),
              ),
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _PromotedLinkDialog(),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.btnAdd),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(l10n.hubErrorGeneric('$e'),
                style: TextStyle(color: palette.dangerBtnBg)),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.promotedEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.sidebarLabelSecondary)),
                  )
                : Column(
                    children: [
                      for (final p in items) ...[
                        Row(
                          children: [
                            Expanded(
                              child: SupportLinkTile(
                                  link: SupportLink.promoted(p, accent)),
                            ),
                            if (p.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                    DateFormat('yyyy-MM-dd HH:mm')
                                        .format(p.createdAt!),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: palette.sidebarLabelSecondary)),
                              ),
                            IconButton(
                              tooltip: l10n.btnDelete,
                              icon: Icon(Icons.delete_outline,
                                  size: 20, color: palette.dangerBtnBg),
                              onPressed: () => _delete(context, ref, p),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PromotedLinkDialog extends ConsumerStatefulWidget {
  const _PromotedLinkDialog();

  @override
  ConsumerState<_PromotedLinkDialog> createState() =>
      _PromotedLinkDialogState();
}

class _PromotedLinkDialogState extends ConsumerState<_PromotedLinkDialog> {
  final _label = TextEditingController();
  final _url = TextEditingController();
  PlatformFile? _image;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // FileType.image: Linux portal globs are case-sensitive (see composer).
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final f = res?.files.singleOrNull;
    if (!mounted || f?.bytes == null) return;
    final l10n = L10n.of(context)!;
    final ext = f!.extension ?? f.name.split('.').last;
    setState(() {
      if (notificationImageMime(ext) == null) {
        _error = l10n.notifImageUnsupported;
      } else if (f.bytes!.length > kNotificationImageMaxBytes) {
        _error = l10n.notifImageTooLarge;
      } else {
        _image = f;
        _error = null;
      }
    });
  }

  Future<void> _save() async {
    final l10n = L10n.of(context)!;
    final label = _label.text.trim();
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (label.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      setState(() => _error = l10n.promotedInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final images = ref.read(adminNotificationsDataSourceProvider);
    ({String path, String url})? up;
    try {
      if (_image != null) {
        final ext = _image!.extension ?? _image!.name.split('.').last;
        up = await images.uploadImage(_image!.bytes!, ext, 'promoted');
      }
      await ref.read(promotedLinksDataSourceProvider).create(
          label: label, url: url, imageUrl: up?.url, imagePath: up?.path);
      ref.invalidate(promotedLinksProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (up != null) await images.removeImages([up.path]);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.hubErrorGeneric('$e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return AlertDialog(
      title: Text(l10n.supportPromoted),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _label,
              maxLength: 80,
              decoration: InputDecoration(labelText: l10n.promotedName),
            ),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'URL', hintText: 'https://'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_image!.bytes!,
                        width: 36, height: 36, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(l10n.promotedPickIcon),
                ),
                if (_image != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _saving ? null : () => setState(() => _image = null),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: palette.dangerBtnBg)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.btnSave),
        ),
      ],
    );
  }
}
