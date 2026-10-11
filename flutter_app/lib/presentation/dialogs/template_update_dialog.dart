import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/template_provider.dart';
import '../../domain/services/free_template.dart';
import '../l10n/app_localizations.dart';

/// Free template update check (docs/free-template/ROADMAP.md Faz 3): when the
/// open world's template changed since the world last took it, asks Update /
/// Ignore / never for this world. Built-in worlds never prompt (B2); a deleted
/// template never prompts (V2). Card data is untouched either way (D17).
Future<void> offerTemplateUpdate(BuildContext context, WidgetRef ref) async {
  final world = ref.read(worldSchemaProvider);
  if (!isFreeTemplate(world)) return;
  final campaign = ref.read(activeCampaignProvider.notifier);
  final data = campaign.data;
  if (data == null) return;
  final template = pendingTemplateUpdate(
    world,
    await ref.read(userTemplatesProvider.future),
    dismissedHash: data['template_dismissed_hash'] as String?,
    muted: data['template_updates_muted'] == true,
  );
  if (template == null) return;
  if (!context.mounted) return;
  final choice = await _ask(context, template.name);
  switch (choice) {
    case 'update':
      await campaign.applyTemplateUpdate(template);
    case 'mute':
      await campaign.muteTemplateUpdates();
    default:
      await campaign.dismissTemplateUpdate(freeTemplateContentHash(template));
  }
}

Future<String?> _ask(BuildContext context, String templateName) {
  var doNotShowAgain = false;
  final l10n = L10n.of(context)!;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l10n.templateDriftTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.templateDriftBody(templateName)),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: doNotShowAgain,
              onChanged: (v) =>
                  setDialogState(() => doNotShowAgain = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                l10n.templateDriftDoNotShowAgain,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, doNotShowAgain ? 'mute' : 'ignore'),
            child: Text(l10n.templateDriftIgnore),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'update'),
            child: Text(l10n.templateDriftUpdate),
          ),
        ],
      ),
    ),
  );
}
