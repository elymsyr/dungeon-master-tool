import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_claim_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../../data/network/character_claim_service.dart';
import '../../../domain/entities/character.dart';
import '../../theme/dm_tool_colors.dart';

/// Player character tab. Flow:
/// 1. If the player hasn't claimed a character yet, the screen leads with
///    the "Available to claim" list of DM-published characters.
/// 2. Once claimed, the player's own character(s) move to the top as
///    editable cards; the claim pool stays visible below as long as it has
///    entries (so a player can claim additional characters if the DM
///    publishes more).
class PlayerCharacterTab extends ConsumerWidget {
  const PlayerCharacterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final activeWorld = ref.watch(activeCampaignProvider);
    final auth = ref.watch(authProvider);
    final charactersAsync = ref.watch(characterListProvider);
    final screen = getScreenType(context);
    final maxWidth = switch (screen) {
      ScreenType.desktop => 720.0,
      ScreenType.tablet => 640.0,
      ScreenType.phone => double.infinity,
    };

    return Container(
      color: palette.tabBg,
      child: Column(
        children: [
          _Header(palette: palette, activeWorld: activeWorld),
          Expanded(
            child: charactersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e',
                      style: TextStyle(color: palette.dangerBtnBg)),
                ),
              ),
              data: (all) {
                // ownerId == auth.uid → player's own characters.
                // ownerId == null is intentionally excluded here — those
                // are DM-created characters that show up under the
                // "Available to claim" pool until a player claims them.
                final mine = all
                    .where((c) =>
                        c.worldName == activeWorld &&
                        auth?.uid != null &&
                        c.ownerId == auth!.uid)
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      padding: EdgeInsets.all(
                          screen == ScreenType.phone ? 12 : 20),
                      children: [
                        if (mine.isNotEmpty) ...[
                          _SectionHeader(
                            palette: palette,
                            icon: Icons.person,
                            title: 'Your Character${mine.length > 1 ? 's' : ''}',
                          ),
                          const SizedBox(height: 8),
                          for (final c in mine) ...[
                            _CharacterRow(palette: palette, character: c),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 16),
                        ],
                        const _AvailableForClaimSection(),
                        if (mine.isEmpty)
                          _EmptyState(
                            palette: palette,
                            poolMayBeEmpty: true,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DmToolColors palette;
  final String? activeWorld;
  const _Header({required this.palette, required this.activeWorld});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 18, color: palette.tabActiveText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeWorld == null
                  ? 'Your Characters'
                  : 'Characters · $activeWorld',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton.icon(
            onPressed: () => context.push('/character/new'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final DmToolColors palette;
  final IconData icon;
  final String title;
  const _SectionHeader({
    required this.palette,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.tabIndicator),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.tabActiveText,
            )),
      ],
    );
  }
}

/// Shown when player has not claimed anything. The pool may also be empty —
/// in that case, prompt the player to ask the DM to publish a character.
class _EmptyState extends ConsumerWidget {
  final DmToolColors palette;
  final bool poolMayBeEmpty;
  const _EmptyState({required this.palette, required this.poolMayBeEmpty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
    final poolAsync = worldId == null
        ? const AsyncValue<List<ClaimPoolRow>>.data([])
        : ref.watch(claimPoolProvider(worldId));
    final poolEmpty = poolAsync.valueOrNull?.isEmpty ?? true;
    if (!poolMayBeEmpty || !poolEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1,
                size: 56, color: palette.sidebarLabelSecondary),
            const SizedBox(height: 12),
            Text(
              'No characters yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Ask your DM to make a character available for claim, or create a new one of your own.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Available-to-claim section. DM-published characters show up here; the
/// player can claim them to take ownership and unlock editing.
class _AvailableForClaimSection extends ConsumerWidget {
  const _AvailableForClaimSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final worldId =
        ref.watch(activeCampaignIdProvider).valueOrNull;
    if (worldId == null) return const SizedBox.shrink();
    final poolAsync = ref.watch(claimPoolProvider(worldId));
    return poolAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (pool) {
        if (pool.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              palette: palette,
              icon: Icons.inventory_2,
              title: 'Available to claim',
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 8),
              child: Text(
                'Your DM has published these characters. Claim one to make it yours.',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
            for (final row in pool) ...[
              _ClaimCard(row: row, palette: palette),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _ClaimCard extends ConsumerStatefulWidget {
  final ClaimPoolRow row;
  final DmToolColors palette;
  const _ClaimCard({required this.row, required this.palette});

  @override
  ConsumerState<_ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends ConsumerState<_ClaimCard> {
  bool _busy = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(characterClaimServiceProvider);
      if (svc == null) return;
      await svc.claim(widget.row.characterId);
      ref.invalidate(claimPoolProvider(widget.row.worldId));
      ref.invalidate(characterListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Character claimed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    var displayName = widget.row.templateName;
    try {
      final payload = widget.row.payloadJson;
      final nameMatch = RegExp(r'"name":\s*"([^"]+)"').firstMatch(payload);
      if (nameMatch != null) displayName = nameMatch.group(1)!;
    } catch (_) {}
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardAccent.withValues(alpha: 0.08),
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: palette.featureCardAccent.withValues(alpha: 0.2),
            child: Icon(Icons.person_outline,
                color: palette.tabActiveText, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    ),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(widget.row.templateName,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.sidebarLabelSecondary,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _claim,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 16),
            label: const Text('Claim'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 36),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterRow extends StatelessWidget {
  final DmToolColors palette;
  final Character character;
  const _CharacterRow({required this.palette, required this.character});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: palette.br,
      onTap: () => context.push('/character/${character.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(color: palette.featureCardBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: palette.featureCardAccent.withValues(alpha: 0.2),
              child: Icon(Icons.person,
                  color: palette.tabActiveText, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(character.entity.name.isEmpty
                      ? '(Unnamed)'
                      : character.entity.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText,
                      )),
                  const SizedBox(height: 2),
                  Text(character.templateName,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.sidebarLabelSecondary,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: palette.sidebarLabelSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
