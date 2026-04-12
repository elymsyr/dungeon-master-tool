import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/item_visibility_provider.dart';
import '../../core/config/supabase_config.dart';
import '../dialogs/publish_item_dialog.dart';
import '../theme/dm_tool_colors.dart';

/// World/template/package settings dialog'larında public/private switch.
/// `itemType` 'world' | 'template' | 'package'.
/// `localId` yerel kayıttaki uuid (campaign name, schemaId, package name).
class VisibilityToggleRow extends ConsumerWidget {
  final String itemType;
  final String localId;
  final String title;
  final String? description;

  const VisibilityToggleRow({
    super.key,
    required this.itemType,
    required this.localId,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseConfig.isConfigured) return const SizedBox.shrink();
    final auth = ref.watch(authProvider);
    if (auth == null) return const SizedBox.shrink();

    final palette = Theme.of(context).extension<DmToolColors>()!;
    final visibility = ref.watch(itemVisibilityProvider((itemType: itemType, localId: localId)));
    final notifierState = ref.watch(itemVisibilityNotifierProvider);
    final busy = notifierState is AsyncLoading;

    return visibility.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Visibility error: $e',
          style: TextStyle(fontSize: 11, color: palette.dangerBtnBg)),
      data: (shared) {
        final isPublic = shared?.isPublic ?? false;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            border: Border.all(color: palette.featureCardBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(isPublic ? Icons.public : Icons.lock_outline,
                  size: 18, color: isPublic ? palette.featureCardAccent : palette.sidebarLabelSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isPublic ? 'Public' : 'Private',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
                    Text(
                      isPublic
                          ? 'Visible on your profile to all users.'
                          : 'Only you can see this.',
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isPublic,
                onChanged: busy
                    ? null
                    : (v) async {
                        final notifier = ref.read(itemVisibilityNotifierProvider.notifier);
                        if (v) {
                          final result = await PublishItemDialog.show(
                            context,
                            title: title,
                            itemTypeLabel: _itemTypeLabel(itemType),
                            initialDescription: shared?.description ?? description,
                            initialLanguage: shared?.language,
                            initialTags: shared?.tags,
                          );
                          if (result == null) return;
                          await notifier.publish(
                            itemType: itemType,
                            localId: localId,
                            title: title,
                            description: result.description,
                            language: result.language,
                            tags: result.tags,
                          );
                        } else {
                          await notifier.unpublish(itemType: itemType, localId: localId);
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  String _itemTypeLabel(String type) {
    switch (type) {
      case 'world':
        return 'World';
      case 'template':
        return 'Template';
      case 'package':
        return 'Package';
    }
    return type;
  }
}
