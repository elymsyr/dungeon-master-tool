import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/installed_packages_provider.dart';
import '../../../core/constants.dart' show appVersion;
import '../../theme/dm_tool_colors.dart';

/// About + Attributions screen — discharges the CC BY 4.0 obligation for
/// the bundled SRD Core package and any user-installed packages by listing
/// each one with its name, version, author, license, and (optional)
/// description.
///
/// Reads `installed_packages` via [installedAttributionsProvider] so the
/// list updates the moment a new package finishes importing.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final attributionsAsync = ref.watch(installedAttributionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('About & Attributions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _appHeader(context, palette),
                const SizedBox(height: 32),
                Text(
                  'Installed packages',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: palette.tabActiveText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Each package below is redistributed under the license '
                  'shown. Copy a row to share attribution verbatim.',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.sidebarLabelSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                attributionsAsync.when(
                  data: (rows) => rows.isEmpty
                      ? _emptyState(palette)
                      : Column(
                          children: rows
                              .map((row) =>
                                  _AttributionCard(row: row, palette: palette))
                              .toList(),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Text(
                    'Failed to load attributions: $e',
                    style: TextStyle(color: palette.dangerBtnBg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _appHeader(BuildContext context, DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dungeon Master Tool',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: palette.tabActiveText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version $appVersion',
          style: TextStyle(
            fontSize: 12,
            color: palette.sidebarLabelSecondary,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(DmToolColors palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'No packages installed yet.',
        style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
      ),
    );
  }
}

class _AttributionCard extends StatelessWidget {
  final InstalledPackageAttribution row;
  final DmToolColors palette;

  const _AttributionCard({required this.row, required this.palette});

  String _attributionLine() {
    final author = row.authorName.isEmpty ? 'Unknown author' : row.authorName;
    final license = row.sourceLicense.isEmpty ? 'No license declared'
        : row.sourceLicense;
    return '${row.name} v${row.version} — $author. $license.';
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _attributionLine()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attribution copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final installedAt =
        DateFormat.yMMMd().add_Hm().format(row.installedAt.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.br,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.tabActiveText,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy, size: 16, color: palette.tabText),
                tooltip: 'Copy attribution',
                onPressed: () => _copy(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _kv('Version', row.version),
          _kv('Author', row.authorName.isEmpty ? '—' : row.authorName),
          _kv('License',
              row.sourceLicense.isEmpty ? '—' : row.sourceLicense),
          _kv('Game system', row.gameSystemId),
          _kv('Slug', row.packageIdSlug),
          _kv('Installed', installedAt),
          if (row.description != null && row.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.description!,
              style: TextStyle(
                fontSize: 12,
                color: palette.tabText,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.tabText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
