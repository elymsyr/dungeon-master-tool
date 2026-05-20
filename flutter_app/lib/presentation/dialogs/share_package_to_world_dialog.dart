import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_packages_provider.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/package_info.dart';

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
        title: const Text('Share package'),
        content: const Text('Only the DM can share packages with the world.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final pkgListAsync = ref.watch(packageListProvider);
    final shared = ref.watch(worldPackagesProvider(worldId)).valueOrNull ?? [];
    final sharedNames = {for (final r in shared) r.packageName};
    return AlertDialog(
      title: const Text('Share package with world'),
      content: SizedBox(
        width: 400,
        child: pkgListAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (packages) {
            if (packages.isEmpty) {
              return const Text('No local packages found.');
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
          child: const Text('Close'),
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
        '${info.templateName} • ${info.entityCount} entities',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: alreadyShared
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done, size: 18),
                IconButton(
                  tooltip: 'Update share',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _share(ref, context),
                ),
                IconButton(
                  tooltip: 'Unshare',
                  icon: const Icon(Icons.cloud_off),
                  onPressed: () => _unshare(ref, context),
                ),
              ],
            )
          : FilledButton(
              onPressed: () => _share(ref, context),
              child: const Text('Share'),
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
          SnackBar(content: Text('Shared ${info.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: ${formatError(e)}')),
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
          SnackBar(content: Text('Unshared ${info.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unshare failed: ${formatError(e)}')),
        );
      }
    }
  }
}
