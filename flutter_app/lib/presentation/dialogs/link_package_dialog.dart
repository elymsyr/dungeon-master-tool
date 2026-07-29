import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/package_link_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/services/srd_core_package_bootstrap.dart';
import '../../domain/entities/package_info.dart';
import '../../domain/entities/package_link.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Manages one package's outgoing links — the package-level counterpart to the
/// world's [ImportPackageDialog].
///
/// Linking does NOT copy: the two packages stay separate stores. The linked
/// package's entities are overlaid read-only into this package's category
/// lists (`packageReferenceOverlayProvider`) and follow it into any world it is
/// imported into. Removing a link never touches either package's content.
class LinkPackageDialog extends ConsumerWidget {
  final String packageName;

  const LinkPackageDialog({super.key, required this.packageName});

  static Future<void> show(BuildContext context, String packageName) {
    return showDialog<void>(
      context: context,
      builder: (_) => LinkPackageDialog(packageName: packageName),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final statusAsync = ref.watch(packageLinkStatusProvider(packageName));
    final closureAsync =
        ref.watch(packageLinkClosureProvider(packageName));
    final packagesAsync = ref.watch(packageListProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.link, size: 20, color: palette.featureCardAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.packageLinksTitle)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: statusAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('$e'),
          data: (status) {
            final packages = packagesAsync.valueOrNull ?? const <PackageInfo>[];
            // Everything the closure pulls in, minus the direct links and this
            // package itself = the indirect (transitive) dependencies.
            final closure = closureAsync.valueOrNull ?? const <String>[];
            final directNames = {for (final p in status.resolved) p.name};
            final indirect = closure
                .where((n) => n != packageName && !directNames.contains(n))
                .toList();
            // Linkable: every other local package that isn't already linked
            // (directly or transitively). The built-in SRD pack is excluded —
            // it is already overlaid into every package unconditionally.
            final linkable = packages
                .map((p) => p.name)
                .where((n) =>
                    n != packageName &&
                    n != srdCorePackageName &&
                    !directNames.contains(n) &&
                    !indirect.contains(n))
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.packageLinksHint,
                    style: TextStyle(
                        fontSize: 12, color: palette.sidebarLabelSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (status.isEmpty && indirect.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.packageLinksNone,
                        style: TextStyle(
                            fontSize: 12,
                            color: palette.sidebarLabelSecondary),
                      ),
                    )
                  else ...[
                    _SectionLabel(
                        label: l10n.packageLinksSection, palette: palette),
                    for (final target in status.resolved)
                      _LinkedRow(
                        title: target.name,
                        palette: palette,
                        onRemove: () => _remove(
                          context,
                          ref,
                          PackageLink(
                              packageId: target.id, name: target.name),
                        ),
                      ),
                    // Dangling: the target was deleted, or arrived with a
                    // package this device never installed (marketplace
                    // download). Shown so the user can clean it up.
                    for (final link in status.dangling)
                      _LinkedRow(
                        title: link.label,
                        subtitle: l10n.packageLinksMissing,
                        missing: true,
                        palette: palette,
                        onRemove: () => _remove(context, ref, link),
                      ),
                    // Pulled in by a link's own links — not removable here,
                    // you unlink the direct parent instead.
                    for (final name in indirect)
                      _LinkedRow(
                        title: name,
                        subtitle: l10n.packageLinksIndirect(packageName),
                        palette: palette,
                        onRemove: null,
                      ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: palette.featureCardBorder),
                  const SizedBox(height: 12),
                  _SectionLabel(
                      label: l10n.packageLinksAvailableSection,
                      palette: palette),
                  if (linkable.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.noPackages,
                        style: TextStyle(
                            fontSize: 12,
                            color: palette.sidebarLabelSecondary),
                      ),
                    ),
                  for (final name in linkable)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title:
                          Text(name, style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_link, size: 18),
                        tooltip: l10n.packageLinksTitle,
                        onPressed: () => _add(context, ref, name),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.btnClose),
        ),
      ],
    );
  }

  Future<void> _add(
      BuildContext context, WidgetRef ref, String targetName) async {
    final ok = await addPackageLink(ref, packageName, targetName);
    if (!context.mounted || ok) return;
    // The only user-visible reason an add is refused: it would make the two
    // packages link each other. (Duplicates are filtered out of the list.)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context)!.packageLinksCycle(targetName))),
    );
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, PackageLink link) async {
    await removePackageLink(ref, packageName, link);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final DmToolColors palette;
  const _SectionLabel({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.sidebarLabelSecondary,
        ),
      ),
    );
  }
}

class _LinkedRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool missing;
  final DmToolColors palette;

  /// Null for transitive links — they are removed by unlinking their parent.
  final VoidCallback? onRemove;

  const _LinkedRow({
    required this.title,
    required this.palette,
    required this.onRemove,
    this.subtitle,
    this.missing = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        missing ? Icons.link_off : Icons.link,
        size: 18,
        color: missing ? palette.dangerBtnBg : palette.featureCardAccent,
      ),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: missing
                    ? palette.dangerBtnBg
                    : palette.sidebarLabelSecondary,
              ),
            ),
      trailing: onRemove == null
          ? null
          : IconButton(
              icon: const Icon(Icons.link_off, size: 18),
              onPressed: onRemove,
            ),
    );
  }
}
