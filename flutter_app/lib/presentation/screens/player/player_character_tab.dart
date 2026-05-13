import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_claim_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../data/network/character_claim_service.dart';
import '../../../domain/entities/character.dart';
import '../../theme/dm_tool_colors.dart';

/// Player'ın karakter sekmesi. DM sidebar'ı yerine geçer — sadece
/// `ownerId == myUid` filtreli karakterler. Layout: tam ekran scroll'lu
/// liste; öğeye tıklayınca character editor'a route eder (mevcut
/// `/character/:id`).
class PlayerCharacterTab extends ConsumerWidget {
  const PlayerCharacterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final activeWorld = ref.watch(activeCampaignProvider);
    final auth = ref.watch(authProvider);
    final charactersAsync = ref.watch(characterListProvider);

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
                // ownerId == auth.uid → player's own characters
                // ownerId == null → legacy local characters created before
                // the ownerId backfill; player tab is local-only so showing
                // them here is safe (each device has its own DB).
                final scoped = all
                    .where((c) =>
                        c.worldName == activeWorld &&
                        (c.ownerId == auth?.uid || c.ownerId == null))
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _AvailableForClaimSection(),
                    if (scoped.isEmpty)
                      _EmptyState(palette: palette)
                    else
                      ...scoped.expand((c) => [
                            _CharacterRow(palette: palette, character: c),
                            const SizedBox(height: 8),
                          ]),
                  ],
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
                  : 'Your Characters · $activeWorld',
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

class _EmptyState extends StatelessWidget {
  final DmToolColors palette;
  const _EmptyState({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
            Text(
              'Create a new character or claim one your DM has made available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: palette.sidebarLabelSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Available for claim" listesi. DM `markAvailable` ile bir karakteri
/// havuza atınca burada belirir; oyuncu "Claim" ile sahiplenir.
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
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.featureCardAccent.withValues(alpha: 0.08),
            borderRadius: palette.br,
            border: Border.all(color: palette.featureCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2,
                      size: 16, color: palette.tabIndicator),
                  const SizedBox(width: 6),
                  Text('Available characters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText,
                      )),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Your DM has made these characters available. '
                'Claim one to add it to your characters.',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...pool.map((row) => _ClaimRow(row: row)),
            ],
          ),
        );
      },
    );
  }
}

class _ClaimRow extends ConsumerStatefulWidget {
  final ClaimPoolRow row;
  const _ClaimRow({required this.row});

  @override
  ConsumerState<_ClaimRow> createState() => _ClaimRowState();
}

class _ClaimRowState extends ConsumerState<_ClaimRow> {
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
    final palette = Theme.of(context).extension<DmToolColors>()!;
    // payload_json'dan basit isim çıkarımı. parse hatasında templateName fallback.
    var displayName = widget.row.templateName;
    try {
      final payload = widget.row.payloadJson;
      final nameMatch = RegExp(r'"name":\s*"([^"]+)"').firstMatch(payload);
      if (nameMatch != null) displayName = nameMatch.group(1)!;
    } catch (_) {}
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.person_outline,
              size: 16, color: palette.sidebarLabelSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$displayName · ${widget.row.templateName}',
                style: TextStyle(fontSize: 13, color: palette.tabActiveText),
                overflow: TextOverflow.ellipsis),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _claim,
            icon: _busy
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 14),
            label: const Text('Claim'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 30),
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

