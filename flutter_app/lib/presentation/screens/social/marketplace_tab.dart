import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/social_providers.dart';
import '../../theme/dm_tool_colors.dart';
import 'social_shell.dart';

/// Marketplace — tüm kullanıcıların public shared_items'ları. Tip filtresi
/// ile world/template/package arasında seçim yapılabilir.
class MarketplaceTab extends ConsumerWidget {
  const MarketplaceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final entries = ref.watch(marketplaceProvider);
    final filter = ref.watch(marketplaceFilterProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(marketplaceProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          _FilterBar(
            currentFilter: filter,
            onChanged: (v) => ref.read(marketplaceFilterProvider.notifier).state = v,
            palette: palette,
          ),
          const SizedBox(height: 20),
          entries.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => SocialCard(
              child: Text('Could not load marketplace: $e',
                  style: TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const SocialEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Nothing published yet',
                  subtitle: 'Public worlds, templates and packages will show up here.\nMake one of your items public from its settings to share it.',
                );
              }
              return Column(
                children: [
                  for (final e in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MarketplaceCard(entry: e),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String currentFilter;
  final ValueChanged<String> onChanged;
  final DmToolColors palette;
  const _FilterBar({
    required this.currentFilter,
    required this.onChanged,
    required this.palette,
  });

  static const _filters = [
    ('all', 'All'),
    ('world', 'Worlds'),
    ('template', 'Templates'),
    ('package', 'Packages'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _filters.map((f) {
        final isActive = f.$1 == currentFilter;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(f.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? palette.featureCardAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? palette.featureCardAccent : palette.featureCardBorder,
              ),
            ),
            child: Text(
              f.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : palette.tabText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  final MarketplaceEntry entry;
  const _MarketplaceCard({required this.entry});

  IconData get _typeIcon => switch (entry.item.itemType) {
        'world' => Icons.public,
        'template' => Icons.description_outlined,
        'package' => Icons.inventory_2_outlined,
        _ => Icons.folder_outlined,
      };

  String get _typeLabel => switch (entry.item.itemType) {
        'world' => 'World',
        'template' => 'Template',
        'package' => 'Package',
        _ => 'Item',
      };

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final ownerName = entry.ownerUsername ?? 'unknown';

    return SocialCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.featureCardAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon, size: 22, color: palette.featureCardAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.featureCardAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: palette.featureCardAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (entry.item.description != null && entry.item.description!.isNotEmpty) ...[
                  Text(
                    entry.item.description!,
                    style: TextStyle(fontSize: 12, color: palette.tabText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.push('/profile/${entry.item.ownerId}'),
                      child: Text(
                        '@$ownerName',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.featureCardAccent,
                        ),
                      ),
                    ),
                    Text(' · ',
                        style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                    Text(
                      DateFormat.yMMMd().format(entry.item.updatedAt.toLocal()),
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                    Text(' · ',
                        style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
                    Text(
                      '${(entry.item.sizeBytes / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
