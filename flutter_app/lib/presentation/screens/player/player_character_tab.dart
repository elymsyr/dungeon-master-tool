import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_claim_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../application/providers/world_characters_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../../../domain/entities/character.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/online_world_widgets.dart';

/// Player character tab. World'deki tüm karakterler 3 bölümde:
///   1. **Your Characters** — owner_id == self.uid, editable.
///   2. **Available to Claim** — owner_id == null, claim button.
///   3. **Other Players' Characters** — owner_id != null && != self.uid,
///      read-only tile (RLS izin verir, edit policy player'ı engeller).
///
/// Roster yukarıda yatay strip olarak görünür → join/leave anlık.
class PlayerCharacterTab extends ConsumerWidget {
  const PlayerCharacterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final activeWorld = ref.watch(activeCampaignProvider);
    final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
    final auth = ref.watch(authProvider);
    final selfUid = auth?.uid;
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
          if (worldId != null)
            MembersStrip(worldId: worldId, palette: palette),
          Expanded(
            child: worldId == null
                ? _EmptyState(palette: palette, message: 'Open a world to see characters.')
                : _CharacterList(
                    palette: palette,
                    worldId: worldId,
                    selfUid: selfUid,
                    maxWidth: maxWidth,
                    screen: screen,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CharacterList extends ConsumerWidget {
  final DmToolColors palette;
  final String worldId;
  final String? selfUid;
  final double maxWidth;
  final ScreenType screen;
  const _CharacterList({
    required this.palette,
    required this.worldId,
    required this.selfUid,
    required this.maxWidth,
    required this.screen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldCharsAsync = ref.watch(worldCharactersProvider(worldId));
    return worldCharsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e',
              style: TextStyle(color: palette.dangerBtnBg)),
        ),
      ),
      data: (rows) {
        final mine = <WorldCharacterRow>[];
        final unclaimed = <WorldCharacterRow>[];
        final others = <WorldCharacterRow>[];
        for (final r in rows) {
          if (r.ownerId == null) {
            unclaimed.add(r);
          } else if (selfUid != null && r.ownerId == selfUid) {
            mine.add(r);
          } else {
            others.add(r);
          }
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.all(screen == ScreenType.phone ? 12 : 20),
              children: [
                if (mine.isNotEmpty) ...[
                  _SectionHeader(
                    palette: palette,
                    icon: Icons.person,
                    title: 'Your Character${mine.length > 1 ? 's' : ''}',
                  ),
                  const SizedBox(height: 8),
                  for (final r in mine) ...[
                    _OwnedRow(palette: palette, row: r),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
                if (unclaimed.isNotEmpty) ...[
                  _SectionHeader(
                    palette: palette,
                    icon: Icons.inventory_2,
                    title: 'Available to Claim',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 26, bottom: 8, top: 4),
                    child: Text(
                      'Unclaimed characters in this world. Claim one to make it yours.',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                  ),
                  for (final r in unclaimed) ...[
                    _ClaimCard(row: r, palette: palette),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
                if (others.isNotEmpty) ...[
                  _SectionHeader(
                    palette: palette,
                    icon: Icons.group,
                    title: "Other Players' Characters",
                  ),
                  const SizedBox(height: 8),
                  for (final r in others) ...[
                    _OtherRow(palette: palette, row: r),
                    const SizedBox(height: 8),
                  ],
                ],
                if (rows.isEmpty)
                  _EmptyState(
                    palette: palette,
                    message:
                        'No characters in this world yet. The DM can publish one to share, or create your own.',
                  ),
              ],
            ),
          ),
        );
      },
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

class _EmptyState extends StatelessWidget {
  final DmToolColors palette;
  final String message;
  const _EmptyState({required this.palette, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1,
                size: 56, color: palette.sidebarLabelSecondary),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
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

String _displayNameFor(WorldCharacterRow row) {
  try {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is Map<String, dynamic>) {
      final entity = decoded['entity'];
      if (entity is Map && entity['name'] is String) {
        final n = entity['name'] as String;
        if (n.isNotEmpty) return n;
      }
      final flat = decoded['name'];
      if (flat is String && flat.isNotEmpty) return flat;
    }
  } catch (_) {}
  return row.templateName.isNotEmpty ? row.templateName : '(Unnamed)';
}

class _OwnedRow extends StatelessWidget {
  final DmToolColors palette;
  final WorldCharacterRow row;
  const _OwnedRow({required this.palette, required this.row});

  @override
  Widget build(BuildContext context) {
    final name = _displayNameFor(row);
    return InkWell(
      borderRadius: palette.br,
      onTap: () => context.push('/character/${row.id}'),
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
              backgroundColor:
                  palette.featureCardAccent.withValues(alpha: 0.2),
              child: Icon(Icons.person,
                  color: palette.tabActiveText, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText,
                      )),
                  const SizedBox(height: 2),
                  Text(row.templateName,
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

class _OtherRow extends StatelessWidget {
  final DmToolColors palette;
  final WorldCharacterRow row;
  const _OtherRow({required this.palette, required this.row});

  @override
  Widget build(BuildContext context) {
    final name = _displayNameFor(row);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg.withValues(alpha: 0.6),
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: palette.sidebarDivider,
            child: Icon(Icons.lock_outline,
                color: palette.sidebarLabelSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.tabActiveText,
                    )),
                const SizedBox(height: 2),
                Text(
                  '${row.templateName} · Owned by another player',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends ConsumerStatefulWidget {
  final WorldCharacterRow row;
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
      final selfUid = ref.read(authProvider)?.uid;
      final result = await svc.claim(widget.row.id);
      // CDC update_at bump tüm client'lara owner_id değişimini yayar; bu
      // client'ta optimistik patch atalım — UI hemen "Your" section'a kayar.
      ref
          .read(worldCharactersProvider(result.worldId).notifier)
          .applyMirror(widget.row.copyWith(
            ownerId: selfUid,
            updatedAt: DateTime.now(),
          ));
      // Local Drift'i seed et — payload world_characters.payload_json'da
      // duruyor, parse edip ownerId güncelle. Sonrasında applyMirror disk
      // + state'i atomik patch eder, _mirrorPush online-world implicit
      // sync'ini tetikler (kullanıcı tarafına ek "Make Online" gerek yok).
      try {
        final decoded = jsonDecode(widget.row.payloadJson);
        if (decoded is Map<String, dynamic>) {
          final character = Character.fromJson(decoded).copyWith(
            ownerId: selfUid,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          );
          await ref
              .read(characterListProvider.notifier)
              .applyMirror(character);
          // Char artık self-owned + online world → personal sync push.
          await ref
              .read(characterListProvider.notifier)
              .ensureOnline(character.id);
        }
      } catch (e) {
        debugPrint('claim local seed error: $e');
      }
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
    final displayName = _displayNameFor(widget.row);
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
            backgroundColor:
                palette.featureCardAccent.withValues(alpha: 0.2),
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
