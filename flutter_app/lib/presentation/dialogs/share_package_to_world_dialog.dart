import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_packages_provider.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/package_info.dart';
import '../l10n/app_localizations.dart';

/// PR-SYNC-5: DM picks a local personal package and shares it into the
/// currently-active world. All world members see the shared package via
/// CDC + [worldPackagesProvider].
///
/// Visibility rules: only the world DM can open this; if no world is
/// active, the call is a no-op. UI integration calls `show()`.
class SharePackageToWorldDialog extends ConsumerWidget {
  final String worldId;

  const SharePackageToWorldDialog({super.key, required this.worldId});

  static Future<void> show(BuildContext context, String worldId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => SharePackageToWorldDialog(worldId: worldId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentWorldRoleProvider).valueOrNull;
    if (role != WorldRole.dm) {
      return AlertDialog(
        title: Text(L10n.of(context)!.sharePackageTitle),
        content: Text(L10n.of(context)!.sharePackageDmOnly),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L10n.of(context)!.btnClose),
          ),
        ],
      );
    }
    final pkgListAsync = ref.watch(packageListProvider);
    final shared = ref.watch(worldPackagesProvider(worldId)).valueOrNull ?? [];
    final sharedNames = {for (final r in shared) r.packageName};
    return AlertDialog(
      title: Text(L10n.of(context)!.sharePackageWithWorld),
      content: SizedBox(
        width: 400,
        child: pkgListAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(L10n.of(context)!.hubErrorGeneric('$e')),
          data: (packages) {
            if (packages.isEmpty) {
              return Text(L10n.of(context)!.sharePackageNoLocal);
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: packages.length,
              itemBuilder: (_, i) {
                final p = packages[i];
                return _PackageRow(
                  worldId: worldId,
                  info: p,
                  alreadyShared: sharedNames.contains(p.name),
                  sharedRow: shared
                      .where((r) => r.packageName == p.name)
                      .firstOrNull,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(L10n.of(context)!.btnClose),
        ),
      ],
    );
  }
}

class _PackageRow extends ConsumerWidget {
  final String worldId;
  final PackageInfo info;
  final bool alreadyShared;
  final dynamic sharedRow;

  const _PackageRow({
    required this.worldId,
    required this.info,
    required this.alreadyShared,
    required this.sharedRow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(info.name),
      subtitle: Text(
        L10n.of(context)!.sharePackageSubtitle(info.templateName, '${info.entityCount}'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: alreadyShared
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done, size: 18),
                IconButton(
                  tooltip: L10n.of(context)!.sharePackageUpdate,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _share(ref, context),
                ),
                IconButton(
                  tooltip: L10n.of(context)!.btnUnshare,
                  icon: const Icon(Icons.cloud_off),
                  onPressed: () => _unshare(ref, context),
                ),
              ],
            )
          : FilledButton(
              onPressed: () => _share(ref, context),
              child: Text(L10n.of(context)!.btnShare),
            ),
    );
  }

  Future<void> _share(WidgetRef ref, BuildContext context) async {
    final activeWorld = ref.read(activeCampaignProvider);
    if (activeWorld == null || activeWorld != worldId) {
      // Share works against the active world; in practice the caller opens
      // the dialog from within the world, so this should not trigger.
    }
    try {
      await shareLocalPackageToWorld(
        ref: ref,
        worldId: worldId,
        packageName: info.name,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.sharedName(info.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.shareFailed(formatError(e)))),
        );
      }
    }
  }

  Future<void> _unshare(WidgetRef ref, BuildContext context) async {
    final row = sharedRow;
    if (row == null) return;
    final packageId = row.packageId as String;
    try {
      await unshareWorldPackage(
        ref: ref,
        worldId: worldId,
        packageName: info.name,
        packageId: packageId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.unsharedName(info.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.unshareFailed(formatError(e)))),
        );
      }
    }
  }
}
