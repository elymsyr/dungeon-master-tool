import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/social_providers.dart';
import '../../domain/entities/game_listing.dart';
import '../l10n/app_localizations.dart';

/// Bir game listing'e başvuru dialog'u. Kullanıcı zorunlu mesaj yazar ve
/// gönderir; başarılı olursa provider invalidate edilir.
class ApplyListingDialog extends ConsumerStatefulWidget {
  final GameListing listing;
  const ApplyListingDialog({super.key, required this.listing});

  static Future<bool?> show(BuildContext context, {required GameListing listing}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ApplyListingDialog(listing: listing),
    );
  }

  @override
  ConsumerState<ApplyListingDialog> createState() => _ApplyListingDialogState();
}

class _ApplyListingDialogState extends ConsumerState<ApplyListingDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final busy = ref.watch(listingApplicationProvider) is AsyncLoading;
    final canSubmit = _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(l10n.listingApplyTitle(widget.listing.title)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: TextField(
          controller: _ctrl,
          maxLines: 5,
          maxLength: 1000,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.listingApplyMessage,
            hintText: l10n.listingApplyHint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.btnCancel),
        ),
        FilledButton(
          onPressed: (!canSubmit || busy)
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final ok = await ref.read(listingApplicationProvider.notifier).apply(
                        listingId: widget.listing.id,
                        message: _ctrl.text.trim(),
                      );
                  if (!mounted) return;
                  navigator.pop(ok);
                },
          child: Text(l10n.listingApply),
        ),
      ],
    );
  }
}
